#!/bin/bash

  print_banner() {
  echo "
███████╗███████╗██████╗ ██████╗ ██╗   ██╗███╗   ██╗███╗   ██╗███████╗██████╗      ██████╗███████╗
╚══███╔╝██╔════╝██╔══██╗██╔══██╗██║   ██║████╗  ██║████╗  ██║██╔════╝██╔══██╗    ██╔════╝██╔════╝
  ███╔╝ █████╗  ██████╔╝██████╔╝██║   ██║██╔██╗ ██║██╔██╗ ██║█████╗  ██████╔╝    ██║     █████╗
 ███╔╝  ██╔══╝  ██╔══██╗██╔══██╗██║   ██║██║╚██╗██║██║╚██╗██║██╔══╝  ██╔══██╗    ██║     ██╔══╝
███████╗███████╗██████╔╝██║  ██║╚██████╔╝██║ ╚████║██║ ╚████║███████╗██║  ██║    ╚██████╗███████╗
╚══════╝╚══════╝╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═══╝╚═╝  ╚═══╝╚══════╝╚═╝  ╚═╝     ╚═════╝╚══════╝
"

  }

  setup() {
    print_banner

    # load ./backup/settings.env if exist to declare ZBR* vars from previous run!
    if [[ -f backup/settings.env ]]; then
      source backup/settings.env
    fi

    export ZBR_MCLOUD_IOS_VERSION=1.0
    echo TODO: implement configuration steps

    export ZBR_MCLOUD_IOS_AGENT=1
    # export all ZBR* variables to save user input
    export_settings
  }

  shutdown() {
    if [ ! -f backup/settings.env ]; then
      echo_warning "You have to setup MCloud iOS slave in advance using: ./zebrunner.sh setup"
      echo_telegram
      exit -1
    fi

    echo_warning "Shutdown will erase all settings and data for \"${BASEDIR}\"!"
    confirm "" "      Do you want to continue?" "n"
    if [[ $? -eq 0 ]]; then
      exit
    fi

    print_banner

    # unload LaunchAgents scripts
    launchctl unload $HOME/Library/LaunchAgents/syncWDA.plist
    launchctl unload $HOME/Library/LaunchAgents/syncSTF.plist
    launchctl unload $HOME/Library/LaunchAgents/syncAppium.plist
    launchctl unload $HOME/Library/LaunchAgents/syncDevices.plist

    # Stop existing services: WebDriverAgent, SmartTestFarm and Appium
    stop

    # remove configuration files and LaunchAgents plist(s)
    rm -f devices.txt

    rm -f $HOME/Library/LaunchAgents/syncWDA.plist
    rm -f $HOME/Library/LaunchAgents/syncSTF.plist
    rm -f $HOME/Library/LaunchAgents/syncAppium.plist
    rm -f $HOME/Library/LaunchAgents/syncDevices.plist
  }

  start() {
    if [ ! -f backup/settings.env ]; then
      echo_warning "You have to setup services in advance using: ./zebrunner.sh setup"
      echo_telegram
      exit -1
    fi

    print_banner

    #-------------- START EVERYTHING ------------------------------
    if [[ $ZBR_MCLOUD_IOS_AGENT -eq 1 ]]; then
      # load LaunchAgents scripts
      echo HOME: $HOME
      ls -la $HOME/Library/LaunchAgents/syncDevices.plist
      launchctl load $HOME/Library/LaunchAgents/syncDevices.plist
      launchctl load $HOME/Library/LaunchAgents/syncWDA.plist
      launchctl load $HOME/Library/LaunchAgents/syncSTF.plist
      launchctl load $HOME/Library/LaunchAgents/syncAppium.plist
    else
      echo TODO: implement just start by services
    fi
  }

  start-appium() {
    udid=$1
    if [ "$udid" == "" ]; then
      echo_warning "You have to provide device udid: ./zebrunner.sh start-appium udid"
      echo_telegram
      exit -1
    fi
    #echo udid: $udid

    . ./configs/getDeviceArgs.sh $udid

    if [ "${device_ip}" == "" ]; then
      echo "Unable to start Appium for '${name}' as it's ip address not detected!" >> "logs/appium_${name}.log"
      exit -1
    fi
    echo "Starting appium: ${udid} - device name : ${name}"

    ./configs/configgen.sh $udid > ${BASEDIR}/metaData/$udid.json

    newWDA=false
    #TODO: investigate if tablet should be registered separately, what about tvOS

    nohup node ${appium_home}/build/lib/main.js -p ${appium_port} --log-timestamp --device-name "${name}" --automation-name=XCUItest --udid $udid \
      --tmp "${BASEDIR}/tmp/AppiumData/${udid}" \
      --default-capabilities \
     '{"mjpegServerPort": '${mjpeg_port}', "webkitDebugProxyPort": '${iwdp_port}', "clearSystemFiles": "false", "webDriverAgentUrl":"'http://${device_ip}:${wda_port}'", "derivedDataPath":"'${BASEDIR}/tmp/DerivedData/${udid}'", "preventWDAAttachments": "true", "simpleIsVisibleCheck": "true", "wdaLocalPort": "'$wda_port'", "usePrebuiltWDA": "true", "useNewWDA": "'$newWDA'", "platformVersion": "'$os_version'", "automationName":"'${automation_name}'", "deviceName":"'$name'" }' \
      --nodeconfig ./metaData/$udid.json >> "logs/appium_${name}.log" 2>&1 &

    #TODO: remove below workaround to the sessionId: null value
    sleep 10
    curl -H 'Content-type: application/json' -X POST http://${STF_NODE_HOST}:${appium_port}/wd/hub/session -d '{"capabilities": {"alwaysMatch": {"platformName": "iOS", "bundleId": "com.apple.calculator"}}}'

  }

  start-stf() {
    udid=$1
    if [ "$udid" == "" ]; then
      echo_warning "You have to provide device udid: ./zebrunner.sh start-stf udid"
      echo_telegram
      exit -1
    fi
    #echo udid: $udid
    . configs/getDeviceArgs.sh $udid

    if [ "${device_ip}" == "" ]; then
      echo "Unable to start STF for '${name}' as it's ip address not detected!" >> "logs/stf_${name}.log"
      exit -1
    fi

    echo "Starting iSTF ios-device: ${udid} device name : ${name}"

    # Specify pretty old node v8.17.0 as current due to the STF dependency
    export NVM_DIR="$HOME/.nvm"
    [ -s "/usr/local/opt/nvm/nvm.sh" ] && . "/usr/local/opt/nvm/nvm.sh"  # This loads nvm
    nvm use v8.17.0

    STF_BIN=`which stf`
    #echo STF_BIN: $STF_BIN

    STF_CLI=`echo "${STF_BIN//bin\/stf/lib/node_modules/@devicefarmer/stf/lib/cli}"`
    echo STF_CLI: $STF_CLI

    nohup node $STF_CLI ios-device --serial ${udid} \
      --device-name ${name} \
      --device-type ${type} \
      --provider ${PROVIDER_NAME} --screen-port ${stf_screen_port} --connect-port ${mjpeg_port} --public-ip ${STF_PUBLIC_HOST} --group-timeout 3600 \
      --storage-url ${WEB_PROTOCOL}://${STF_PUBLIC_HOST}/ --screen-jpeg-quality 40 --screen-ping-interval 30000 \
      --screen-ws-url-pattern ${WEBSOCKET_PROTOCOL}://${STF_PUBLIC_HOST}/d/${STF_NODE_HOST}/${udid}/${stf_screen_port}/ \
      --boot-complete-timeout 60000 --mute-master never \
      --connect-app-dealer tcp://${STF_PRIVATE_HOST}:7160 --connect-dev-dealer tcp://${STF_PRIVATE_HOST}:7260 \
      --wda-host ${device_ip} --wda-port ${wda_port} \
      --appium-host ${STF_NODE_HOST} --appium-port ${appium_port} --proxy-appium-port ${proxy_appium_port} \
      --connect-sub tcp://${STF_PRIVATE_HOST}:7250 --connect-push tcp://${STF_PRIVATE_HOST}:7270 --no-cleanup >> "logs/stf_${name}.log" 2>&1 &

  }

  start-wda() {
    udid=$1
    if [ "$udid" == "" ]; then
      echo_warning "You have to provide device udid: ./zebrunner.sh start-wda udid"
      echo_telegram
      exit -1
    fi
    #echo udid: $udid

    . ./configs/getDeviceArgs.sh $udid

    #backup current wda log to be able to analyze failures if any
    if [[ -f logs/wda_${name}.log ]]; then
      mv logs/wda_${name}.log backup/wda_${name}_`date +"%T"`.log
    fi

    echo Starting WDA: ${name}, udid: ${udid}, wda_port: ${wda_port}, mjpeg_port: ${mjpeg_port}
    nohup /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -project ${appium_home}/node_modules/appium-webdriveragent/WebDriverAgent.xcodeproj \
      -derivedDataPath "${BASEDIR}/tmp/DerivedData/${udid}" \
      -scheme WebDriverAgentRunner -destination id=$udid USE_PORT=$wda_port MJPEG_SERVER_PORT=$mjpeg_port test > "logs/wda_${name}.log" 2>&1 &

    verifyWDAStartup "logs/wda_${name}.log" 120 >> "logs/wda_${name}.log"
    if [[ $? = 0 ]]; then
      # WDA was started successfully!
      # parse ip address from log file line:
      # 2020-07-13 17:15:15.295128+0300 WebDriverAgentRunner-Runner[5660:22940482] ServerURLHere->http://192.168.88.127:20001<-ServerURLHere

      ip=`grep "ServerURLHere->" "logs/wda_${name}.log" | cut -d ':' -f 5`
      # remove forward slashes
      ip="${ip//\//}"
      # put IP address into the metadata file
      echo "${ip}" > ${metaDataFolder}/ip_${udid}.txt
    else
      # WDA is not started successfully!
      rm -f ${metaDataFolder}/ip_${udid}.txt
    fi

  }

  stop() {
    if [ ! -f backup/settings.env ]; then
      echo_warning "You have to setup services in advance using: ./zebrunner.sh setup"
      echo_telegram
      exit -1
    fi

    stop-wda
    stop-stf
    stop-appium
  }

  stop-wda() {
    if [ ! -f backup/settings.env ]; then
      echo_warning "You have to setup services in advance using: ./zebrunner.sh setup"
      echo_telegram
      exit -1
    fi

    udid=$1
    #echo udid: $udid
    if [ "$udid" != "" ]; then
      export pids=`ps -eaf | grep ${udid} | grep xcodebuild | grep 'WebDriverAgent' | grep -v grep | grep -v stop-wda | awk '{ print $2 }'`
      rm -f ${metaDataFolder}/ip_${udid}.txt
    else
      export pids=`ps -eaf | grep xcodebuild | grep 'WebDriverAgent' | grep -v grep | grep -v stop-wda | awk '{ print $2 }'`
      rm -f ${metaDataFolder}/ip_*.txt
    fi
    echo pids: $pids

    kill_processes $pids
  }

  stop-stf() {
    if [ ! -f backup/settings.env ]; then
      echo_warning "You have to setup services in advance using: ./zebrunner.sh setup"
      echo_telegram
      exit -1
    fi

    udid=$1
    #echo udid: $udid
    if [ "$udid" != "" ]; then
      export pids=`ps -eaf | grep ${udid} | grep 'ios-device' | grep 'stf' | grep -v grep | grep -v stop-stf | awk '{ print $2 }'`
    else
      export pids=`ps -eaf | grep 'ios-device' | grep 'stf' | grep -v grep | grep -v stop-stf | awk '{ print $2 }'`
    fi
    #echo pids: $pids

    kill_processes $pids
  }

  stop-appium() {
    if [ ! -f backup/settings.env ]; then
      echo_warning "You have to setup services in advance using: ./zebrunner.sh setup"
      echo_telegram
      exit -1
    fi

    udid=$1
    #echo udid: $udid
    if [ "$udid" != "" ]; then
      export pids=`ps -eaf | grep ${udid} | grep 'appium' | grep -v grep | grep -v stop-appium | grep -v '/stf' | grep -v '/usr/share/maven' | grep -v 'WebDriverAgent' | awk '{ print $2 }'`
    else 
      export pids=`ps -eaf | grep 'appium' | grep -v grep | grep -v stop-appium | grep -v '/stf' | grep -v '/usr/share/maven' | grep -v 'WebDriverAgent' | awk '{ print $2 }'`
    fi
    #echo pids: $pids

    kill_processes $pids
  }


  restart() {
    if [ ! -f backup/settings.env ]; then
      echo_warning "You have to setup services in advance using: ./zebrunner.sh setup"
      echo_telegram
      exit -1
    fi

    down
    start
  }

  down() {
    if [ ! -f backup/settings.env ]; then
      echo_warning "You have to setup services in advance using: ./zebrunner.sh setup"
      echo_telegram
      exit -1
    fi

    # unload LaunchAgents scripts
    launchctl unload $HOME/Library/LaunchAgents/syncWDA.plist
    launchctl unload $HOME/Library/LaunchAgents/syncSTF.plist
    launchctl unload $HOME/Library/LaunchAgents/syncAppium.plist
    launchctl unload $HOME/Library/LaunchAgents/syncDevices.plist

    stop
  }

  backup() {
    if [ ! -f backup/settings.env ]; then
      echo_warning "You have to setup services in advance using: ./zebrunner.sh setup"
      echo_telegram
      exit -1
    fi

#    confirm "" "      Your services will be stopped. Do you want to do a backup now?" "n"
#    if [[ $? -eq 0 ]]; then
#      exit
#    fi

    print_banner

    cp devices.txt ./backup/devices.txt
    cp $HOME/Library/LaunchAgents/syncWDA.plist ./backup/syncWDA.plist
    cp $HOME/Library/LaunchAgents/syncSTF.plist ./backup/syncSTF.plist
    cp $HOME/Library/LaunchAgents/syncAppium.plist ./backup/syncAppium.plist
    cp $HOME/Library/LaunchAgents/syncDevices.plist ./backup/syncDevices.plist

    echo "Backup for Device Farm iOS slave was successfully finished."

#    echo_warning "Your services needs to be started after backup."
#    confirm "" "      Start now?" "y"
#    if [[ $? -eq 1 ]]; then
#      start
#    fi

  }

  restore() {
    if [ ! -f backup/settings.env ]; then
      echo_warning "You have to setup services in advance using: ./zebrunner.sh setup"
      echo_telegram
      exit -1
    fi

    confirm "" "      Your services will be stopped and current data might be lost. Do you want to do a restore now?" "n"
    if [[ $? -eq 0 ]]; then
      exit
    fi

    print_banner
    down
    cp ./backup/devices.txt devices.txt
    cp ./backup/syncWDA.plist $HOME/Library/LaunchAgents/syncWDA.plist
    cp ./backup/syncSTF.plist $HOME/Library/LaunchAgents/syncSTF.plist
    cp ./backup/syncAppium.plist $HOME/Library/LaunchAgents/syncAppium.plist
    cp ./backup/syncDevices.plist $HOME/Library/LaunchAgents/syncDevices.plist

    echo_warning "Your services needs to be started after restore."
    confirm "" "      Start now?" "y"
    if [[ $? -eq 1 ]]; then
      start
    fi

  }

  version() {
    if [ ! -f backup/settings.env ]; then
      echo_warning "You have to setup services in advance using: ./zebrunner.sh setup"
      echo_telegram
      exit -1
    fi

    source backup/settings.env

    echo "MCloud Device Farm: ${ZBR_MCLOUD_IOS_VERSION}"
  }

  export_settings() {
    export -p | grep "ZBR" > backup/settings.env
  }

  confirm() {
    local message=$1
    local question=$2
    local isEnabled=$3

    if [[ "$isEnabled" == "1" ]]; then
      isEnabled="y"
    fi
    if [[ "$isEnabled" == "0" ]]; then
      isEnabled="n"
    fi

    while true; do
      if [[ ! -z $message ]]; then
        echo "$message"
      fi

      read -p "$question y/n [$isEnabled]:" response
      if [[ -z $response ]]; then
        if [[ "$isEnabled" == "y" ]]; then
          return 1
        fi
        if [[ "$isEnabled" == "n" ]]; then
          return 0
        fi
      fi

      if [[ "$response" == "y" || "$response" == "Y" ]]; then
        return 1
      fi

      if [[ "$response" == "n" ||  "$response" == "N" ]]; then
        return 0
      fi

      echo "Please answer y (yes) or n (no)."
      echo
    done
  }

  kill_processes()
  {
    processes_pids=$*
    if [ "${processes_pids}" != "" ]; then
     echo processes_pids to kill: $processes_pids
     kill -9 $processes_pids
    fi
  }

  verifyWDAStartup() {

    ## FUNCTION:     verifyStartup
    ## DESCRITION:   verify if WDA component started per device/simolator
    ## PARAMETERS:
    ##         $1 - Path to log file for startup verification
    ##         $2 - String to find in startup log (startup indicator)
    ##         $3 - Counter. (Startup verification max duration) = (Counter) x (10 seconds)

    STARTUP_LOG=$1
    STARTUP_COUNTER=$2

    STARTUP_INDICATOR="ServerURLHere->"
    FAIL_INDICATOR=" TEST FAILED "
    UNSUPPORTED_INDICATOR="Unable to find a destination matching the provided destination specifier"

    COUNTER=0
    while [  $COUNTER -lt $STARTUP_COUNTER ];
    do
      sleep 1
      if [[ -r ${STARTUP_LOG} ]]
      then
        # verify that WDA is supported for device/simulator
        grep "${UNSUPPORTED_INDICATOR}" ${STARTUP_LOG} > /dev/null
        if [[ $? = 0 ]]
        then
          echo "ERROR! WDA does not support ${name}!"
          return -1
        fi

        # verify that WDA failed
        grep "${FAIL_INDICATOR}" ${STARTUP_LOG} > /dev/null
        if [[ $? = 0 ]]
        then
          echo "ERROR! WDA failed on ${name} in ${COUNTER} seconds!"
          return -1
        fi

       grep "${STARTUP_INDICATOR}" ${STARTUP_LOG} > /dev/null
        if [[ $? = 0 ]]
        then
          echo "WDA started successfully on ${name} within ${COUNTER} seconds."
          return 0
        else
          echo "WDA not started yet on ${name}. waiting ${COUNTER} sec..."
        fi

      else
        echo "ERROR! Cannot read from ${STARTUP_LOG}. File has not appeared yet!"
      fi
      let COUNTER=COUNTER+1
    done

    echo "ERROR! WDA not started on ${name} within ${STARTUP_COUNTER} seconds!"
    return -1
  }

  echo_warning() {
    echo "
      WARNING! $1"
  }

  echo_telegram() {
    echo "
      For more help join telegram channel: https://t.me/zebrunner
      "
  }

  echo_help() {
    echo "
      Usage: ./zebrunner.sh [option]
      Flags:
          --help | -h    Print help
      Arguments:
          setup              Setup Device Farm iOS slave
          start              Start Device Farm iOS slave services
          start-appium udid  Start Appium service by device udid
          stop               Stop Device Farm iOS slave services
          stop-appium [udid] Stop Appium services [all or for exact device by udid]
          stop-stf [udid]    Stop STF services [all or for exact device by udid]
          stop-wda [udid]    Stop WebDriverAgent services [all or for exact device by udid]
          restart            Restart Device Farm iOS slave services
          down               Stop Device Farm iOS slave services and disable LaunchAgent services
          shutdown           Destroy Device Farm iOS slave completely
          backup             Backup Device Farm iOS slave services
          restore            Restore Device Farm iOS slave services
          version            Version of Device Farm iOS slave"
      echo_telegram
      exit 0
  }

BASEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd ${BASEDIR}

if [[ -f backup/settings.env ]]; then
  source backup/settings.env
fi

. configs/set_properties.sh


case "$1" in
    setup)
        setup
        ;;
    start)
        start
        ;;
    start-appium)
        start-appium $2
        ;;
    start-stf)
        start-stf $2
        ;;
    start-wda)
        start-wda $2
        ;;
    stop)
        stop
        ;;
    stop-appium)
        stop-appium $2
        ;;
    stop-stf)
        stop-stf $2
        ;;
    stop-wda)
        stop-wda $2
        ;;
    restart)
        restart
        ;;
    down)
        down
        ;;
    shutdown)
        shutdown
        ;;
    backup)
        backup
        ;;
    restore)
        restore
        ;;
    version)
        version
        ;;
    *)
        echo "Invalid option detected: $1"
        echo_help
        exit 1
        ;;
esac

