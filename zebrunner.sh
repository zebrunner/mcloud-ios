#!/bin/bash

BASEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd ${BASEDIR}

source ${BASEDIR}/.env

if [[ -f backup/settings.env ]]; then
  source backup/settings.env
fi

export devices=${BASEDIR}/devices.txt
export metaDataFolder=${BASEDIR}/metaData

if [ ! -d "${BASEDIR}/logs/backup" ]; then
    mkdir -p "${BASEDIR}/logs/backup"
fi

if [ ! -d "${BASEDIR}/metaData" ]; then
    mkdir "${BASEDIR}/metaData"
fi

# udid position in devices.txt to be able to read by sync scripts
export udid_position=4

export connectedDevices=${metaDataFolder}/connectedDevices.txt
export connectedSimulators=${metaDataFolder}/connectedSimulators.txt



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

    syncSimulators

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
    launchctl unload $HOME/Library/LaunchAgents/syncZebrunner.plist

    # Stop existing services: WebDriverAgent, SmartTestFarm and Appium
    stop

    # remove configuration files and LaunchAgents plist(s)
    rm -f devices.txt

    rm -f $HOME/Library/LaunchAgents/syncZebrunner.plist
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
      # load LaunchAgents script so all services will be started automatically
      launchctl load $HOME/Library/LaunchAgents/syncZebrunner.plist
    else
      syncDevices
      syncWDA
      syncAppium
      syncSTF
    fi
  }

  start-services() {
    syncDevices
    syncWDA
    syncAppium
    syncSTF
  }

  start-appium() {
    udid=$1
    if [ "$udid" == "" ]; then
      syncAppium
      return 0
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

    nohup node ${APPIUM_HOME}/build/lib/main.js -p ${appium_port} --log-timestamp --device-name "${name}" --udid $udid \
      --tmp "${BASEDIR}/tmp/AppiumData/${udid}" \
      --default-capabilities \
     '{"mjpegServerPort": '${mjpeg_port}', "webkitDebugProxyPort": '${iwdp_port}', "clearSystemFiles": "false", "webDriverAgentUrl":"'http://${device_ip}:${wda_port}'", "derivedDataPath":"'${BASEDIR}/tmp/DerivedData/${udid}'", "preventWDAAttachments": "true", "simpleIsVisibleCheck": "true", "wdaLocalPort": "'$wda_port'", "usePrebuiltWDA": "true", "useNewWDA": "'$newWDA'", "platformVersion": "'$os_version'", "automationName":"'${AUTOMATION_NAME}'", "deviceName":"'$name'" }' \
      --nodeconfig ./metaData/$udid.json >> "logs/appium_${name}.log" 2>&1 &
  }

  start-stf() {
    udid=$1
    if [ "$udid" == "" ]; then
      syncSTF
      return 0
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
      --provider ${STF_NODE_HOST} \
      --screen-port ${stf_screen_port} --connect-port ${mjpeg_port} --public-ip ${STF_MASTER_HOST} --group-timeout 3600 \
      --storage-url ${WEB_PROTOCOL}://${STF_MASTER_HOST}/ --screen-jpeg-quality 40 --screen-ping-interval 30000 \
      --screen-ws-url-pattern ${WEBSOCKET_PROTOCOL}://${STF_MASTER_HOST}/d/${STF_NODE_HOST}/${udid}/${stf_screen_port}/ \
      --boot-complete-timeout 60000 --mute-master never \
      --connect-app-dealer tcp://${STF_MASTER_HOST}:7160 --connect-dev-dealer tcp://${STF_MASTER_HOST}:7260 \
      --wda-host ${device_ip} --wda-port ${wda_port} \
      --appium-host ${STF_NODE_HOST} --appium-port ${appium_port} --proxy-appium-port ${proxy_appium_port} \
      --connect-sub tcp://${STF_MASTER_HOST}:7250 --connect-push tcp://${STF_MASTER_HOST}:7270 --no-cleanup >> "logs/stf_${name}.log" 2>&1 &

  }

  start-wda() {
    udid=$1
    if [ "$udid" == "" ]; then
      syncWDA
      retun 0
    fi
    #echo udid: $udid

    . ./configs/getDeviceArgs.sh $udid

    #backup current wda log to be able to analyze failures if any
    if [[ -f logs/wda_${name}.log ]]; then
      mv logs/wda_${name}.log logs/backup/wda_${name}_`date +"%T"`.log
    fi

    echo Starting WDA: ${name}, udid: ${udid}, wda_port: ${wda_port}, mjpeg_port: ${mjpeg_port}
    nohup /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -project ${APPIUM_HOME}/node_modules/appium-webdriveragent/WebDriverAgent.xcodeproj \
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

    stop-stf
    stop-appium
    stop-wda
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

    if [[ $ZBR_MCLOUD_IOS_AGENT -eq 1 ]]; then
      # unload LaunchAgents scripts
      launchctl unload $HOME/Library/LaunchAgents/syncZebrunner.plist
    fi

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
    cp $HOME/Library/LaunchAgents/syncZebrunner.plist ./backup/syncZebrunner.plist

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
    cp ./backup/syncZebrunner.plist $HOME/Library/LaunchAgents/syncZebrunner.plist

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
          setup               Setup Device Farm iOS slave
          start               Start Device Farm iOS slave services
          start-appium [udid] Start Appium services [all or for exact device by udid]
          start-stf [udid]    Start STF services [all or for exact device by udid]
          start-wda [udid]    Start WDA services [all or for exact device by udid]
          stop                Stop Device Farm iOS slave services
          stop-appium [udid]  Stop Appium services [all or for exact device by udid]
          stop-stf [udid]     Stop STF services [all or for exact device by udid]
          stop-wda [udid]     Stop WebDriverAgent services [all or for exact device by udid]
          restart             Restart Device Farm iOS slave services
          down                Stop Device Farm iOS slave services and disable LaunchAgent services
          shutdown            Destroy Device Farm iOS slave completely
          backup              Backup Device Farm iOS slave services
          restore             Restore Device Farm iOS slave services
          version             Version of Device Farm iOS slave"
      echo_telegram
      exit 0
  }

  syncDevices() {
    echo `date +"%T"` Sync Devices script started
    devicesFile=${metaDataFolder}/connectedDevices.txt
    /usr/local/bin/ios-deploy -c -t 3 > ${connectedDevices}
  }

  syncSimulators() {
    echo `date +"%T"` Sync Simulators script started
    simulatorsFile=${metaDataFolder}/connectedSimulators.txt
    # xcrun xctrace list devices - this command can not be used because it returns physical devices as well
    xcrun simctl list | grep -v "Unavailable" | grep -v "unavailable" > ${simulatorsFile}
  }

  syncWDA() {
    echo `date +"%T"` Sync WDA script started
    # use-case when on-demand manual "./zebrunner.sh start-wda" is running!
    isRunning=`ps -ef | grep start-wda | grep -v grep`
    #echo isRunning: $isRunning

    if [[ -n "$isRunning" ]]; then
      echo WebDriverAgent is being starting already. Skip sync operation!
      return 0
    fi

    # verify one by one connected devices and authorized simulators
    while read -r line
    do
      udid=`echo $line | cut -d '|' -f ${udid_position}`
      #to trim spaces around. Do not remove!
      udid=$(echo $udid)
      if [ "$udid" = "UDID" ]; then
        continue
      fi
      . ${BASEDIR}/configs/getDeviceArgs.sh $udid

      #wda check is only for approach with syncWda.sh and usePrebuildWda=true
      wda=`ps -ef | grep xcodebuild | grep $udid | grep WebDriverAgent`

      physical=`cat ${connectedDevices} | grep $udid`
      simulator=`cat ${connectedSimulators} | grep $udid`
      device="$physical$simulator"
      #echo device: $device

      if [[ -n "$device" &&  -z "$wda" ]]; then
        # simultaneous WDA launch is not supported by Xcode!
        # error: error: accessing build database "/Users/../Library/Developer/Xcode/DerivedData/WebDriverAgent-../XCBuildData/build.db": database is locked
        # Possibly there are two concurrent builds running in the same filesystem location.
        ${BASEDIR}/zebrunner.sh start-wda $udid
      elif [[ -z "$device" &&  -n "$wda" ]]; then
        #double check for the case when connctedDevices.txt in sync and empty
        device=`/usr/local/bin/ios-deploy -c -t 5 | grep ${udid}`
        if [[ -z "${device}" ]]; then
          echo "WDA will be stopped: ${udid} - device name : ${name}"
          ${BASEDIR}/zebrunner.sh stop-wda $udid &
        fi
      fi
    done < ${devices}
  }

  syncAppium() {
    echo `date +"%T"` Sync Appium script started

    while read -r line
    do
      udid=`echo $line | cut -d '|' -f ${udid_position}`
      #to trim spaces around. Do not remove!
      udid=$(echo $udid)
      if [[ "$udid" = "UDID" ]]; then
        continue
      fi
      . ${BASEDIR}/configs/getDeviceArgs.sh $udid

      appium=`ps -ef | grep ${APPIUM_HOME}/build/lib/main.js  | grep $udid`

      physical=`cat ${connectedDevices} | grep $udid`
      simulator=`cat ${connectedSimulators} | grep $udid`
      device="$physical$simulator"
      #echo device: $device

      wda=${metaDataFolder}/ip_${udid}.txt
      #echo wda: $wda

      if [[ -n "$appium" && ! -f "$wda" ]]; then
        echo "Stopping Appium process as no WebDriverAgent process detected. ${udid} device name : ${name}"
        ${BASEDIR}/zebrunner.sh stop-appium $udid &
        continue
      fi

      if [[ -n "$device" && -f "$wda" && -z "$appium" ]]; then
        ${BASEDIR}/zebrunner.sh start-appium $udid &
      elif [[ -z "$device" &&  -n "$appium" ]]; then
        #double check for the case when connctedDevices.txt in sync and empty
        device=`/usr/local/bin/ios-deploy -c -t 5 | grep ${udid}`
        if [[ -z "${device}" ]]; then
          echo "Appium will be stopped: ${udid} - device name : ${name}"
          ${BASEDIR}/zebrunner.sh stop-appium $udid &
        fi
      fi
    done < ${devices}
  }

  syncSTF() {
    echo `date +"%T"` Sync STF script started

    while read -r line
    do
      udid=`echo $line | cut -d '|' -f ${udid_position}`
      #to trim spaces around. Do not remove!
      udid=$(echo $udid)
      if [ "$udid" = "UDID" ]; then
        continue
      fi
      . ${BASEDIR}/configs/getDeviceArgs.sh $udid

      physical=`cat ${connectedDevices} | grep $udid`
      simulator=`cat ${connectedSimulators} | grep $udid`

      if [[ -n "$simulator" ]]; then
        # https://github.com/zebrunner/stf/issues/168
        # simulators temporary unavailable in iSTF
        continue
      fi

      device="$physical$simulator"
      #echo device: $device

      stf=`ps -eaf | grep ${udid} | grep 'ios-device' | grep -v grep`
      wda=${metaDataFolder}/ip_${udid}.txt
      if [[ -n "$stf" && ! -f "$wda" ]]; then
        echo "Stopping STF process as no WebDriverAgent process detected. ${udid} device name : ${name}"
        ${BASEDIR}/zebrunner.sh stop-stf $udid &
        continue
      fi

      if [[ -n "$device" && -f "$wda" && -z "$stf" ]]; then
        ${BASEDIR}/zebrunner.sh start-stf $udid &
      elif [[ -z "$device" && -n "$stf" ]]; then
        #double check for the case when connctedDevices.txt in sync and empty
        device_status=`/usr/local/bin/ios-deploy -c -t 5 | grep ${udid}`
        if [[ -z "${device_status}" ]]; then
          echo "The iSTF ios-device will be stopped: ${udid} device name : ${name}"
          ${BASEDIR}/zebrunner.sh stop-stf $udid &
        fi
      fi
    done < ${devices}
  }




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
    start-services)
        start-services
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
    authorize-simulator)
        syncSimulators
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

