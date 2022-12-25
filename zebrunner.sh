#!/bin/bash

BASEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd ${BASEDIR}

export CHECK_APP_SIZE_OPTIONALLY=true

if [ -f backup/settings.env ]; then
  source backup/settings.env
fi

if [ -f .env ]; then
  source .env
fi

export devices=${BASEDIR}/devices.txt
export metaDataFolder=${BASEDIR}/metaData

if [ ! -d "${BASEDIR}/metaData" ]; then
    mkdir -p "${BASEDIR}/metaData"
fi

# udid position in devices.txt to be able to read by sync scripts
export udid_position=2

export connectedDevices=${metaDataFolder}/connectedDevices.txt

export SIMULATORS=${metaDataFolder}/simulators.txt

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

    # software prerequisites check like appium, xcode etc

    #TODO: seema like not needed if ipa/app build on different hosts    
    which xcodebuild > /dev/null
    if [ ! $? -eq 0 ]; then
      echo_warning "Unable to proceed as XCode application is missed!"
      exit -1
    fi

    which git > /dev/null
    if [ ! $? -eq 0 ]; then
      echo_warning "Unable to proceed as git is missed!"
      exit -1
    fi

    which ffmpeg > /dev/null
    if [ ! $? -eq 0 ]; then
      echo_warning "Unable to proceed as ffmpeg is missed!"
      exit -1
    fi

    which ios > /dev/null
    if [ ! $? -eq 0 ]; then
      echo_warning "Unable to proceed as ios is missed (go-ios)!"
      exit -1
    fi

    which jq > /dev/null
    if [ ! $? -eq 0 ]; then
      echo_warning "Unable to proceed as jq is missed!"
      exit -1
    fi

    which cmake > /dev/null
    if [ ! $? -eq 0 ]; then
      # soft dependency as appium might not be registered in PATH
      echo_warning "cmake is not detected! It is recommended to install for compatibility!"
    fi

    which appium > /dev/null
    if [ ! $? -eq 0 ]; then
      # soft dependency as appium might not be registered in PATH
      echo_warning "Appium is not detected! Interrupt setup if you don't have it installed!"
    fi

    echo ""
    echo_warning "Make sure to register your devices and simulators in devices.txt!"

    echo

    # load default interactive installer settings
    source backup/settings.env.original

    # load ./backup/settings.env if exist to declare ZBR* vars from previous run!
    if [[ -f backup/settings.env ]]; then
      source backup/settings.env
    fi

    export ZBR_MCLOUD_IOS_VERSION=2.0

    # Setup MCloud master host settings: protocol, hostname and port
    echo "MCloud SmartTestFarm Settings"
    local is_confirmed=0

    while [[ $is_confirmed -eq 0 ]]; do
      read -p "Master host protocol [$ZBR_MCLOUD_PROTOCOL]: " local_protocol
      if [[ ! -z $local_protocol ]]; then
        ZBR_MCLOUD_PROTOCOL=$local_protocol
      fi

      read -p "Master host address [$ZBR_MCLOUD_HOSTNAME]: " local_hostname
      if [[ ! -z $local_hostname ]]; then
        ZBR_MCLOUD_HOSTNAME=$local_hostname
      fi

      read -p "Master host port [$ZBR_MCLOUD_PORT]: " local_port
      if [[ ! -z $local_port ]]; then
        ZBR_MCLOUD_PORT=$local_port
      fi

      confirm "MCloud STF URL: $ZBR_MCLOUD_PROTOCOL://$ZBR_MCLOUD_HOSTNAME:$ZBR_MCLOUD_PORT/stf" "Continue?" "y"
      is_confirmed=$?
    done

    export ZBR_MCLOUD_PROTOCOL=$ZBR_MCLOUD_PROTOCOL
    export ZBR_MCLOUD_HOSTNAME=$ZBR_MCLOUD_HOSTNAME
    export ZBR_MCLOUD_PORT=$ZBR_MCLOUD_PORT

    echo 

    echo "MCloud iOS Agent Settings"
    local is_confirmed=0
    while [[ $is_confirmed -eq 0 ]]; do
      read -p "Current node host address [$ZBR_MCLOUD_NODE_HOSTNAME]: " local_hostname
      if [[ ! -z $local_hostname ]]; then
        ZBR_MCLOUD_NODE_HOSTNAME=$local_hostname
      fi

      read -p "Current node name [$ZBR_MCLOUD_NODE_NAME]: " local_name
      if [[ ! -z $local_name ]]; then
        ZBR_MCLOUD_NODE_NAME=$local_name
      fi
      confirm "Node host address: $ZBR_MCLOUD_NODE_HOSTNAME; Node name: $ZBR_MCLOUD_NODE_NAME" "Continue?" "y"
      is_confirmed=$?
    done
    export ZBR_MCLOUD_NODE_HOSTNAME=$ZBR_MCLOUD_NODE_HOSTNAME
    export ZBR_MCLOUD_NODE_NAME=$ZBR_MCLOUD_NODE_NAME

    echo 

    local is_confirmed=0
    while [[ $is_confirmed -eq 0 ]]; do
      read -p "Appium path [$ZBR_MCLOUD_APPIUM_PATH]: " local_value
      if [[ ! -z $local_value ]]; then
        ZBR_MCLOUD_APPIUM_PATH=$local_value
      fi
      confirm "Appium path: $ZBR_MCLOUD_APPIUM_PATH" "Continue?" "y"
      is_confirmed=$?
    done
    export ZBR_MCLOUD_APPIUM_PATH=$ZBR_MCLOUD_APPIUM_PATH

    echo
    confirm "S3 storage for storing video and log artifacts." "Enable?" "y"
    if [[ $? -eq 1 ]]; then
      set_storage_settings
    fi

    cp .env.original .env
    replace .env "stf_master_host_value" "$ZBR_MCLOUD_HOSTNAME"
    replace .env "STF_MASTER_PORT=80" "STF_MASTER_PORT=$ZBR_MCLOUD_PORT"
    replace .env "node_host_value" "$ZBR_MCLOUD_NODE_HOSTNAME"
    replace .env "node_name_value" "$ZBR_MCLOUD_NODE_NAME"
    replace .env "appium_path_value" "$ZBR_MCLOUD_APPIUM_PATH"

    if [ "$ZBR_MCLOUD_PROTOCOL" == "https" ]; then
      replace .env "WEBSOCKET_PROTOCOL=ws" "WEBSOCKET_PROTOCOL=wss"
      replace .env "WEB_PROTOCOL=http" "WEB_PROTOCOL=https"
    fi

    echo
    echo "Pull STF updates:"
    stf_branch=2.4
    if [ ! -d stf ]; then
      git clone https://github.com/zebrunner/stf.git
      cd stf
      git -c advice.detachedHead=false checkout ${stf_branch}
    else
      cd stf
      git pull origin ${stf_branch}
    fi

    echo
    confirm "Rebuild STF sources?" "Confirm?" "y"
    if [[ $? -eq 1 ]]; then
      echo "Building iSTF component..."
      nvm use v17.1.0
      npm install
      npm link --force
    fi
    cd "${BASEDIR}"

    syncSimulators
    # export all ZBR* variables to save user input
    export_settings


    local is_confirmed=0
    while [[ $is_confirmed -eq 0 ]]; do
      read -p "WebDriverAgent.ipa path [$ZBR_MCLOUD_WDA_PATH]: " local_value
      if [[ ! -z $local_value ]]; then
        ZBR_MCLOUD_WDA_PATH=$local_value
      fi
      confirm "WebDriverAgent.ipa: $ZBR_MCLOUD_WDA_PATH" "Continue?" "y"
      is_confirmed=$?
    done
    export ZBR_MCLOUD_WDA_PATH=$ZBR_MCLOUD_WDA_PATH

    #Configure LaunchAgent service per each device for fast recovery
    while read -r line
    do
      udid=`echo $line | cut -d '|' -f ${udid_position}`
      #to trim spaces around. Do not remove!
      udid=$(echo $udid)
      #echo "udid: $udid"
      if [[ "$udid" = "UDID" ]]; then
        continue
      fi

      if [ -r $HOME/Library/LaunchAgents/syncZebrunner_$udid.plist ]; then
        # unload explicitly in advance in case it is secondary etc setup
        launchctl unload $HOME/Library/LaunchAgents/syncZebrunner_$udid.plist > /dev/null 2>&1
      fi
      prepare-device $udid

      cp LaunchAgents/syncZebrunner.plist $HOME/Library/LaunchAgents/syncZebrunner_$udid.plist
      replace $HOME/Library/LaunchAgents/syncZebrunner_$udid.plist "working_dir_value" "${BASEDIR}"
      replace $HOME/Library/LaunchAgents/syncZebrunner_$udid.plist "user_value" "$USER"
      replace $HOME/Library/LaunchAgents/syncZebrunner_$udid.plist "udid_value" "$udid"

      # load syncup script to restart service and recover device at any failure
      launchctl load $HOME/Library/LaunchAgents/syncZebrunner_$udid.plist > /dev/null 2>&1
    done < ${devices}

    echo
    echo "MCloud agent services will be started automatically soon for connected devices..."

  }

  shutdown() {
    if [ ! -f backup/settings.env ]; then
      echo_warning "You have to setup MCloud iOS agent in advance using: ./zebrunner.sh setup"
      echo_telegram
      exit -1
    fi

    echo_warning "Shutdown will erase all settings and data for \"${BASEDIR}\"!"
    confirm "" "      Do you want to continue?" "n"
    if [[ $? -eq 0 ]]; then
      exit
    fi

    print_banner

    down

    # Unload ad remove customized LaunchAgents
    while read -r line
    do
      udid=`echo $line | cut -d '|' -f ${udid_position}`
      #to trim spaces around. Do not remove!
      udid=$(echo $udid)
      #echo "udid: $udid"
      if [[ "$udid" = "UDID" ]]; then
        continue
      fi

      #unload explicitly in advance in case it is secondary etc setup
      launchctl unload $HOME/Library/LaunchAgents/syncZebrunner_$udid.plist > /dev/null 2>&1
      rm -f $HOME/Library/LaunchAgents/syncZebrunner_$udid.plist
    done < ${devices}


    # remove configuration files and LaunchAgents plist(s)
    git checkout -- devices.txt
    rm .env
    rm backup/settings.env

    echo "Removing devices metadata and STF"
    rm -rf stf
    rm -f ./metaData/*.env
    rm -f ./metaData/*.json
  }

  prepare-device() {
    udid=$1

    . ./configs/getDeviceArgs.sh $udid

    # mount developer images, unistall existing wda, install fresh one. start, test and stop
    # for simulators informa about prerequisites to build and install wda manually

    if [ -n "$device" ]; then
      if [ -n "$physical" ]; then
        echo "$DEVICE_NAME ($DEVICE_UDID)"
        ios image auto --udid=$udid
        stop-wda $udid
        ios uninstall $WDA_BUNDLEID --udid=$udid
        ios install --path=$ZBR_MCLOUD_WDA_PATH --udid=$udid

        start-wda $udid
        if [ $? -eq 0 ]; then
          echo "$DEVICE_NAME ($DEVICE_UDID): WebDriverAgent is OK."
        else
          echo_warning "$DEVICE_NAME ($DEVICE_UDID): WebDriverAgent is not started!"
          return -1
        fi
        stop-wda $udid > ${DEVICE_LOG} 2>&1
      else
        echo_warning "$DEVICE_NAME ($DEVICE_UDID): WebDriverAgent on simulator should be installed in advance via XCode!"
      fi
    else
      echo_warning "$DEVICE_NAME ($DEVICE_UDID) is disconnected now! Connect and repeat setup."
    fi

  }

  start() {
    if [ ! -f backup/settings.env ]; then
      echo_warning "You have to setup services in advance using: ./zebrunner.sh setup"
      echo_telegram
      exit -1
    fi

    ios list > ${connectedDevices}
    # verify one by one connected devices and authorized simulators
    while read -r line
    do
      udid=`echo $line | cut -d '|' -f ${udid_position}`
      #to trim spaces around. Do not remove!
      udid=$(echo $udid)
      #echo "udid: $udid"
      if [[ "$udid" = "UDID" ]]; then
        continue
      fi

      start-device $udid &
    done < ${devices}

    echo "Waiting while services are up&running..."
    echo

    wait
    echo

    status
  }

  start-device() {
    if [ ! -f backup/settings.env ]; then
      echo_warning "You have to setup services in advance using: ./zebrunner.sh setup"
      echo_telegram
      exit -1
    fi

    udid=$1

    . ./configs/getDeviceArgs.sh $udid

    if [ -n "$device" ]; then
      echo "$DEVICE_NAME ($DEVICE_UDID)"
      start-wda $udid > ${DEVICE_LOG} 2>&1
      if [ $? -eq 1 ]; then
        echo_warning "WDA is not started for $DEVICE_NAME udid: $DEVICE_UDID!"
        exit -1
      fi
      start-appium $udid >> ${DEVICE_LOG} 2>&1
      start-stf $udid >> ${DEVICE_LOG} 2>&1

    else 
      echo "$DEVICE_NAME ($DEVICE_UDID) is disconnected!"
    fi
  }


  start-appium() {
    udid=$1
    if [ "$udid" == "" ]; then
      echo_warning "Unable to start Appium without device udid!"
      return 0
    fi
    #echo udid: $udid

    . ./configs/getDeviceArgs.sh $udid

    if [ "${WDA_HOST}" == "" ]; then
      echo_warning "Unable to start Appium for '${name}' as Device IP not detected!"
      exit -1
    fi

    echo "Starting appium: ${udid} - device name : ${name}"

    ./configs/configgen.sh $udid > ${BASEDIR}/metaData/$udid.json

    newWDA=false

    export BUCKET=$ZBR_STORAGE_BUCKET
    export TENANT=$ZBR_STORAGE_TENANT
    export APPIUM_APPS_DIR=${BASEDIR}/tmp/appium-apps
    export APPIUM_APP_WAITING_TIMEOUT=600

    nohup node ${APPIUM_HOME}/build/lib/main.js -p ${appium_port} --log-no-colors --log-timestamp --device-name "${name}" --udid $udid \
      --session-override \
      --tmp "${BASEDIR}/tmp/AppiumData/${udid}" \
      --default-capabilities \
     '{"mjpegServerPort": '${MJPEG_PORT}', "webkitDebugProxyPort": '${iwdp_port}', "clearSystemFiles": "false", "webDriverAgentUrl":"'http://${WDA_HOST}:${WDA_PORT}'", "preventWDAAttachments": "true", "simpleIsVisibleCheck": "true", "wdaLocalPort": "'$WDA_PORT'", "usePrebuiltWDA": "true", "useNewWDA": "'$newWDA'", "platformVersion": "'$PLATFORM_VERSION'", "automationName":"'${AUTOMATION_NAME}'", "deviceName":"'$name'" }' \
      --nodeconfig ./metaData/$udid.json &
  }

  start-stf() {
    udid=$1
    if [ "$udid" == "" ]; then
      echo_warning "Unable to start STF without device udid!"
      return 0
    fi
    #echo udid: $udid
    . configs/getDeviceArgs.sh $udid

    if [ "${WDA_HOST}" == "" ]; then
      echo "Unable to start STF for '${name}' as it's ip address not detected!"
      exit -1
    fi

    echo "Starting iSTF ios-device: ${udid} device name : ${name}"

    # Specify concrete supported v17.1.0 node for STF
    nvm use v17.1.0

    STF_BIN=`which stf`
    #echo STF_BIN: $STF_BIN

    STF_CLI=`echo "${STF_BIN//bin\/stf/lib/node_modules/@devicefarmer/stf/lib/cli}"`
    #echo STF_CLI: $STF_CLI

    export ZMQ_TCP_KEEPALIVE=1
    export ZMQ_TCP_KEEPALIVE_IDLE=600

    nohup node $STF_CLI ios-device --serial ${udid} \
      --device-name ${name} \
      --device-type ${DEVICETYPE} \
      --provider ${STF_NODE_NAME} --host ${STF_NODE_HOST} \
      --screen-port ${stf_screen_port} --connect-port ${MJPEG_PORT} --public-ip ${STF_MASTER_HOST} --group-timeout 3600 \
      --storage-url ${WEB_PROTOCOL}://${STF_MASTER_HOST}:${STF_MASTER_PORT}/ --screen-jpeg-quality 30 --screen-ping-interval 30000 \
      --screen-ws-url-pattern ${WEBSOCKET_PROTOCOL}://${STF_MASTER_HOST}:${STF_MASTER_PORT}/d/${STF_NODE_HOST}/${udid}/${stf_screen_port}/ \
      --boot-complete-timeout 60000 --mute-master never \
      --connect-app-dealer tcp://${STF_MASTER_HOST}:7160 --connect-dev-dealer tcp://${STF_MASTER_HOST}:7260 \
      --wda-host ${WDA_HOST} --wda-port ${WDA_PORT} \
      --connect-sub tcp://${STF_MASTER_HOST}:7250 --connect-push tcp://${STF_MASTER_HOST}:7270 --no-cleanup &

  }

  start-session() {
    # start WDA session correctly generating obligatory snapshot for default 'com.apple.springboard' application.
    udid=$1

    if [[ ! -f ${WDA_ENV} ]]; then
      echo "Unable to start 1st session as WDA is not started yet!"
      return 0
    fi

    echo "Starting 1st WDA session for $DEVICE_NAME udid: $DEVICE_UDID..."
    . ./configs/getDeviceArgs.sh $udid

    echo "ip: ${WDA_HOST}; port: ${WDA_PORT}"

    # start new WDA session with default 60 sec snapshot timeout
    sessionFile=${metaDataFolder}/tmp_${udid}.txt
    curl --silent --location --request POST "http://${WDA_HOST}:${WDA_PORT}/session" --header 'Content-Type: application/json' --data-raw '{"capabilities": {}}' > ${sessionFile}

    # example of the session startup output
    #{
    #  "value" : {
    #    "sessionId" : "B281FDBB-74FA-4DAC-86EC-CD77AD3EAD73",
    #    "capabilities" : {
    #      "device" : "iphone",
    #      "browserName" : " ",
    #      "sdkVersion" : "15.2",
    #      "CFBundleIdentifier" : "com.apple.springboard"
    #    }
    #  },
    #  "sessionId" : "B281FDBB-74FA-4DAC-86EC-CD77AD3EAD73"
    #}

    cat ${sessionFile}

    export bundleId=$(cat ${sessionFile} | jq -r ".value.capabilities.CFBundleIdentifier")
    echo bundleId: $bundleId

    export sessionId=$(cat ${sessionFile} | jq -r ".sessionId")
    echo sessionId: $sessionId

    export PLATFORM_VERSION=$(cat ${sessionFile} | jq -r ".value.capabilities.sdkVersion")
    echo PLATFORM_VERSION: $PLATFORM_VERSION

    expectedAppId=com.apple.springboard
    if [[ "$DEVICETYPE" == "tvOS" ]]; then
      expectedAppId=com.apple.PineBoard
    fi

    if [[ "$bundleId" != "$expectedAppId" ]]; then
      echo  "Activating $expectedAppId app forcibly..."
      curl --silent --location --request POST "http://${WDA_HOST}:${WDA_PORT}/session/$sessionId/wda/apps/launch" --header 'Content-Type: application/json' --data-raw '{"bundleId": "${expectedAppId}"}'
      sleep 1
      curl --silent --location --request POST "http://${WDA_HOST}:${WDA_PORT}/session" --header 'Content-Type: application/json' --data-raw '{"capabilities": {}}'
    fi
    rm -f ${sessionFile}

  }

  start-wda() {
    udid=$1
    if [ "$udid" == "" ]; then
      echo_warning "Unable to start WDA without device udid!"
      return 0
    fi
    #echo udid: $udid

    . ./configs/getDeviceArgs.sh $udid

    echo Starting WDA: ${name}, udid: ${udid}, WDA_PORT: ${WDA_PORT}, MJPEG_PORT: ${MJPEG_PORT}
    scheme=WebDriverAgentRunner

    #if [ "$DEVICETYPE" == "tvOS" ]; then
    #  scheme=WebDriverAgentRunner_tvOS
    #fi

    if [ -n "$physical" ]; then
      #TODO: move install WDA ipa onto the setup state
#       ios image auto --basedir=./DeveloperDiskImages --udid=$DEVICE_UDID
#      echo "[$(date +'%d/%m/%Y %H:%M:%S')] Installing WDA application on device"
#      #TODO: use path to ipa from env var!
#      ios install --path=./WebDriverAgent.ipa --udid=$DEVICE_UDID

#      echo "[$(date +'%d/%m/%Y %H:%M:%S')] Killing existing WebDriverAgent application if any"
#      ios kill $WDA_BUNDLEID --udid=$udid > /dev/null 2>&1

      #Start the WDA service on the device using the WDA bundleId
      echo "[$(date +'%d/%m/%Y %H:%M:%S')] Starting WebDriverAgent application on port $WDA_PORT"
      ios runwda --bundleid=$WDA_BUNDLEID --testrunnerbundleid=$WDA_BUNDLEID --xctestconfig=WebDriverAgentRunner.xctest \
	--env USE_PORT=$WDA_PORT --env MJPEG_SERVER_PORT=$MJPEG_PORT --env UITEST_DISABLE_ANIMATIONS=YES --udid $udid &
    else
      #TODO: investigate an option to install from WebDriverAgent.ipa using `xcrun simctl install ${udid} *.app`!!!
      #for simulators continue to build WDA

      export SIMCTL_CHILD_USE_PORT=$WDA_PORT
      export SIMCTL_CHILD_MJPEG_SERVER_PORT=$MJPEG_PORT
      export SIMCTL_CHILD_UITEST_DISABLE_ANIMATIONS=YES

      xcrun simctl launch --console --terminate-running-process ${udid} com.facebook.WebDriverAgentRunner.xctrunner &
    fi

    verifyWDAStartup "${DEVICE_LOG}" ${WDA_WAIT_TIMEOUT}
    if [[ ! $? = 0 ]]; then
      echo "WDA is not started successfully!"
      rm -fv "${WDA_ENV}"
      stop-wda $udid
      return 1
    fi

    if [ -n "$physical" ]; then
      # #148: ios: reuse proxy for redirecting wda requests through appium container
      ios forward $WDA_PORT $WDA_PORT --udid=$udid > /dev/null 2>&1 &
      ios forward $MJPEG_PORT $MJPEG_PORT --udid=$udid > /dev/null 2>&1 &
    fi

    echo "export WDA_HOST=${WDA_HOST}" > ${WDA_ENV}
    echo "export WDA_PORT=${WDA_PORT}" >> ${WDA_ENV}
    echo "export MJPEG_PORT=${MJPEG_PORT}" >> ${WDA_ENV}

    return 0
  }

  check-device() {
    udid=$1
    if [ "$udid" == "" ]; then
      echo_warning "Unable to check WDA without device udid!"
      return 0
    fi
    #echo udid: $udid

    . ./configs/getDeviceArgs.sh $udid
    echo "Keeping WDA MJPEG connection until it is alive..."
    echo "Press Ctrl-C to stop listening"

    nc localhost ${MJPEG_PORT}
    echo "Connection to WDA $MJPEG_PORT is closed."

    # as only connection corrupted restart wda and stf services
    echo "Restarting WDA and STF service for $name..."
    start-wda $udid >> ${DEVICE_LOG} 2>&1 &
    start-stf $udid >> ${DEVICE_LOG} 2>&1 &
  }

  recover() {
    udid=$1
    if [ "$udid" == "" ]; then
      echo_warning "Unable to check WDA without device udid!"
      return 0
    fi
    #echo udid: $udid

    . ./configs/getDeviceArgs.sh $udid
    echo "Recovering services for $DEVICE_NAME ($DEVICE_UDID)"
    start-wda $udid >> ${DEVICE_LOG} 2>&1 &
    start-appium $udid >> ${DEVICE_LOG} 2>&1 &
    start-stf $udid >> ${DEVICE_LOG} 2>&1 &
  }

  stop() {
    if [ ! -f backup/settings.env ]; then
      echo_warning "You have to setup services in advance using: ./zebrunner.sh setup"
      echo_telegram
      exit -1
    fi

    echo "Stopping MCloud services..."

    #export pids=`ps -eaf | grep ios | grep 'listen' | grep -v grep | awk '{ print $2 }'`
    #kill_processes $pids

    # verify one by one connected devices and authorized simulators
    while read -r line
    do
      udid=`echo $line | cut -d '|' -f ${udid_position}`
      #to trim spaces around. Do not remove!
      udid=$(echo $udid)
      #echo "udid: $udid"
      if [[ "$udid" = "UDID" ]]; then
        continue
      fi

      stop-device $udid &
    done < ${devices}

    wait
    echo "MCloud services stopped."

  }

  stop-device() {
    if [ ! -f backup/settings.env ]; then
      echo_warning "You have to setup services in advance using: ./zebrunner.sh setup"
      echo_telegram
      exit -1
    fi

    udid=$1
    . ./configs/getDeviceArgs.sh $udid

    if [ -n "$device" ]; then
      echo "$DEVICE_NAME ($DEVICE_UDID)"
      stop-appium $udid >> ${DEVICE_LOG} 2>&1
      stop-wda $udid >> ${DEVICE_LOG} 2>&1
      # wda should be stopped before stf to mark device disconnected asap
      stop-stf $udid >> ${DEVICE_LOG} 2>&1
    else
      echo "$DEVICE_NAME ($DEVICE_UDID) is disconnected!"
    fi

  }


  stop-wda() {
    if [ ! -f backup/settings.env ]; then
      echo_warning "You have to setup services in advance using: ./zebrunner.sh setup"
      echo_telegram
      exit -1
    fi

    udid=$1
    #echo udid: $udid

    if [ -n "$physical" ]; then
      ios kill $WDA_BUNDLEID --udid=$udid
      # ios runwda --bundleid=com.facebook.WebDriverAgentRunner.xctrunner --testrunnerbundleid=com.facebook.WebDriverAgentRunner.xctrunner --xctestconfig=WebDriverAgentRunner.xctest --env USE_PORT=<WDA_PORT
      #   --env MJPEG_SERVER_PORT=<MJPEG_PORT> --env UITEST_DISABLE_ANIMATIONS=YES --udid <udid>
      export pids=`ps -eaf | grep ${udid} | grep ios | grep 'runwda' | grep $WDA_PORT | grep -v grep | awk '{ print $2 }'`
      echo "ios ruwda pid: $pids"
      kill_processes $pids

      # kill ios forward proxy requests
      export pids=`ps -eaf | grep ${udid} | grep ios | grep 'forward' | grep -v grep | awk '{ print $2 }'`
      #echo "ios forward pid: $pids"
      kill_processes $pids
    else
      xcrun simctl terminate $udid com.facebook.WebDriverAgentRunner.xctrunner
    fi

    . ./configs/getDeviceArgs.sh $udid
    rm -fv "${WDA_ENV}"

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
      rm -fv ${metaDataFolder}/${udid}.json
    else 
      export pids=`ps -eaf | grep 'appium' | grep -v grep | grep -v stop-appium | grep -v '/stf' | grep -v '/usr/share/maven' | grep -v 'WebDriverAgent' | awk '{ print $2 }'`
      rm -fv ${metaDataFolder}/*.json
    fi
    #echo pids: $pids

    kill_processes $pids
  }

  status() {
    if [ ! -f backup/settings.env ]; then
      echo_warning "You have to setup services in advance using: ./zebrunner.sh setup"
      echo_telegram
      exit -1
    fi


    ios list > ${connectedDevices}
    # verify one by one connected devices and authorized simulators
    while read -r line
    do
      udid=`echo $line | cut -d '|' -f ${udid_position}`
      #to trim spaces around. Do not remove!
      udid=$(echo $udid)
      #echo "udid: $udid"
      if [[ "$udid" = "UDID" ]]; then
        continue
      fi

      status-device $udid &
    done < ${devices}

    wait
  }

  status-device() {
    udid=$1

    . ./configs/getDeviceArgs.sh $udid

    if [ -n "$device" ]; then
      #Hit the Appium status URL to see if it is available
      if curl -Is "http://localhost:$appium_port/wd/hub/status-wda" | head -1 | grep -q '200 OK'
      then
        echo "$DEVICE_NAME ($DEVICE_UDID) is healthy."
      else
        echo "$DEVICE_NAME ($DEVICE_UDID) is unhealthy!"
      fi
    else
      echo "$DEVICE_NAME ($DEVICE_UDID) is disconnected!"
    fi

  }

  backup() {
    if [ ! -f backup/settings.env ]; then
      echo_warning "You have to setup services in advance using: ./zebrunner.sh setup"
      echo_telegram
      exit -1
    fi

    echo "Starting Devices Farm iOS agent backup..."
    cp .env backup/.env
    cp backup/settings.env backup/settings.env.bak
    cp devices.txt backup/devices.txt
    cp ${SIMULATORS} ${SIMULATORS}.bak

    cp -R stf stf.bak

    echo "Backup Devices Farm iOS agent finished."

  }

  restore() {
    if [ ! -f backup/settings.env.bak ]; then
      echo_warning "You have to backup services in advance using: ./zebrunner.sh backup"
      echo_telegram
      exit -1
    fi

    confirm "" "      Your services will be stopped and current data might be lost. Do you want to do a restore now?" "n"
    if [[ $? -eq 0 ]]; then
      exit
    fi

    # restore .env and settings.env earlier to execute down correctly
    cp backup/.env .env
    cp backup/settings.env.bak backup/settings.env

    stop

    echo "Starting Devices Farm iOS agent restore..."
    cp backup/devices.txt devices.txt
    cp ${SIMULATORS}.bak ${SIMULATORS}

    rm -rf stf
    cp -R stf.bak stf

    echo "Restore Devices Farm iOS agent finished."

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
     #echo processes_pids to kill: $processes_pids
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

    STARTUP_INDICATOR="ServerURLHere-"
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
          status [udid]       Status of the Device Farm iOS agent services [all or for exact device by udid]
          setup               Setup Devices Farm iOS agent
          start [udid]        Start Device Farm iOS agent services [all or for exact device by udid]
          stop [udid]         Stop Device Farm iOS agent services and remove logs [all or for exact device by udid]
          restart [udid]      Restart Device Farm iOS agent services [all or for exact device by udid]
          shutdown            Destroy Device Farm iOS agent completely
          backup              Backup Device Farm iOS agent services
          restore             Restore Device Farm iOS agent services
          version             Version of Device Farm iOS agent"
      echo_telegram
      exit 0
  }

  syncSimulators() {
    echo
    echo `date +"%T"` Sync Simulators script started
    xcrun simctl list --json > ${SIMULATORS}
    echo `date +"%T"` Sync Simulators script finished
    echo
  }

  replace() {
    #TODO: https://github.com/zebrunner/zebrunner/issues/328 organize debug logging for setup/replace
    file=$1
    #echo "file: $file"
    content=$(<$file) # read the file's content into
    #echo "content: $content"

    old=$2
    #echo "old: $old"

    new=$3
    #echo "new: $new"
    content=${content//"$old"/$new}

    #echo "content: $content"

    printf '%s' "$content" >$file    # write new content to disk
  }

set_storage_settings() {
  ## AWS S3 compatible storage
  local is_confirmed=0
  #TODO: provide a link to documentation howto create valid S3 bucket
  echo
  echo "AWS S3 storage"
  while [[ $is_confirmed -eq 0 ]]; do
    read -r -p "Bucket [$ZBR_STORAGE_BUCKET]: " local_bucket
    if [[ ! -z $local_bucket ]]; then
      ZBR_STORAGE_BUCKET=$local_bucket
    fi

    read -r -p "[Optional] Tenant [$ZBR_STORAGE_TENANT]: " local_value
    if [[ ! -z $local_value ]]; then
      ZBR_STORAGE_TENANT=$local_value
    fi

    echo "Bucket: $ZBR_STORAGE_BUCKET"
    echo "Tenant: $ZBR_STORAGE_TENANT"
    confirm "" "Continue?" "y"
    is_confirmed=$?
  done

  export ZBR_STORAGE_BUCKET=$ZBR_STORAGE_BUCKET
  export ZBR_STORAGE_TENANT=$ZBR_STORAGE_TENANT
}


if [ ! -d "$HOME/.nvm" ]; then
  echo_warning "NVM must be installed as prerequisites!"
  exit -1
fi

#load NVM into the bash path
export NVM_DIR="$HOME/.nvm"
[ -s "/usr/local/opt/nvm/nvm.sh" ] && . "/usr/local/opt/nvm/nvm.sh"  # This loads nvm
[ -s "/usr/local/opt/nvm/etc/bash_completion.d/nvm" ] && . "/usr/local/opt/nvm/etc/bash_completion.d/nvm"  # This loads nvm bash_completion

[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

case "$1" in
    setup)
        setup
        ;;
    start)
        if [ -z $2 ]; then
          start
        else
         start-device $2
        fi
        ;;
    stop)
        if [ -z $2 ]; then
          stop
        else
         stop-device $2
        fi
        ;;
    restart)
        if [ -z $2 ]; then
          stop
          start
        else
         stop-device $2
         start-device
        fi
        ;;
    check-device)
        check-device $2
        ;;
    recover)
        recover $2
        ;;
    start-stf)
        start-stf $2
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
    status)
        if [ -z $2 ]; then
          status
        else
         status-device $2
        fi
        ;;
    version)
        version
        ;;
    *)
        echo_help
        exit 1
        ;;
esac

