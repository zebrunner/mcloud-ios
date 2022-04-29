#!/bin/bash

export NODE_TLS_REJECT_UNAUTHORIZED=0

BASEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd ${BASEDIR}

MCLOUD_SERVICE=com.zebrunner.mcloud
export CHECK_APP_SIZE_OPTIONALLY=true

if [ -f backup/settings.env ]; then
  source backup/settings.env
fi

if [ -f .env ]; then
  source .env
fi

export devices=${BASEDIR}/devices.txt
export metaDataFolder=${BASEDIR}/metaData

if [ ! -d "${BASEDIR}/logs/backup" ]; then
    mkdir -p "${BASEDIR}/logs/backup"
fi

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
    which ios-deploy > /dev/null
    if [ ! $? -eq 0 ]; then
      echo_warning "Unable to proceed as ios-deploy utility is missed!"
      exit -1
    fi

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
    if [ ! -d stf ]; then
      git clone -b 2.1.1 --single-branch https://github.com/zebrunner/stf.git
      cd stf
    else
      cd stf
      git pull
    fi

    echo
    confirm "Rebuild STF sources?" "Confirm?" "y"
    if [[ $? -eq 1 ]]; then
      echo "Building iSTF component..."
      nvm use v8
      npm install
      npm link --force
    fi
    cd "${BASEDIR}"

    # setup LaunchAgents
    if [ ! -d $HOME/Library/LaunchAgents ]; then
      mkdir -p $HOME/Library/LaunchAgents
    fi
    cp LaunchAgents/syncZebrunner.plist $HOME/Library/LaunchAgents/syncZebrunner.plist
    replace $HOME/Library/LaunchAgents/syncZebrunner.plist "working_dir_value" "${BASEDIR}"
    replace $HOME/Library/LaunchAgents/syncZebrunner.plist "user_value" "$USER"

    echo ""
    echo_warning "Make sure to register your devices and simulators in devices.txt!"

    syncSimulators
    # export all ZBR* variables to save user input
    export_settings

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

    # remove configuration files and LaunchAgents plist(s)
    git checkout -- devices.txt
    rm .env
    rm backup/settings.env

    rm -f $HOME/Library/LaunchAgents/syncZebrunner.plist

    echo "Removing devices metadata and STF"
    rm -rf stf
    rm -f ./metaData/*.env
    rm -f ./metaData/*.json
  }

  start() {
    if [ ! -f backup/settings.env ]; then
      echo_warning "You have to setup services in advance using: ./zebrunner.sh setup"
      echo_telegram
      exit -1
    fi

    print_banner

    udid=$1
    if [ ! -z $udid ]; then
      # unblock this particular device from automatic startup
      rm -rf ./tmp/frozen-$udid

      . ./configs/getDeviceArgs.sh $udid
      echo "Starting MCloud services for $DEVICE_NAME udid: $DEVICE_UDID..."
      start-wda $udid
      start-appium $udid
      start-stf $udid
      return 0
    fi

    # unblock all devices for automatic startup
    rm -rf ./tmp/frozen*

    load
    echo "Starting MCloud services..."
    # initiate kickstart of the syncZebrunner without any pause. It should execute start-services function asap
    launchctl kickstart gui/$UID/$MCLOUD_SERVICE
    echo "Use 'tail -f ./logs/agents.log' to control startup process."
  }

  start-services() {
    syncDevices
    syncServices
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
     '{"mjpegServerPort": '${MJPEG_PORT}', "webkitDebugProxyPort": '${iwdp_port}', "clearSystemFiles": "false", "webDriverAgentUrl":"'http://${WDA_HOST}:${WDA_PORT}'", "derivedDataPath":"'${BASEDIR}/tmp/DerivedData/${udid}'", "preventWDAAttachments": "true", "simpleIsVisibleCheck": "true", "wdaLocalPort": "'$WDA_PORT'", "usePrebuiltWDA": "true", "useNewWDA": "'$newWDA'", "platformVersion": "'$PLATFORM_VERSION'", "automationName":"'${AUTOMATION_NAME}'", "deviceName":"'$name'" }' \
      --nodeconfig ./metaData/$udid.json >> "${APPIUM_LOG}" 2>&1 &
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

    # Specify pretty old node v8.17.0 as current due to the STF dependency
    nvm use v8.17.0

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
      --appium-port ${appium_port} \
      --connect-sub tcp://${STF_MASTER_HOST}:7250 --connect-push tcp://${STF_MASTER_HOST}:7270 --no-cleanup >> "${STF_LOG}" 2>&1 &

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

    #backup current wda log to be able to analyze failures if any
    if [[ -f "${WDA_LOG}" ]]; then
      mv "${WDA_LOG}" "logs/backup/wda_${name}_`date +"%T"`.log"
    fi

    echo Starting WDA: ${name}, udid: ${udid}, WDA_PORT: ${WDA_PORT}, MJPEG_PORT: ${MJPEG_PORT}
    echo "Use 'tail -f ./logs/wda_${name}.log' to see WDA startup logs"
    scheme=WebDriverAgentRunner

    if [ "$DEVICETYPE" == "tvOS" ]; then
      scheme=WebDriverAgentRunner_tvOS
    fi

    if [ ! -d "${APPIUM_HOME}/node_modules/appium-webdriveragent/WebDriverAgent.xcodeproj" ]; then
      echo_warning "${APPIUM_HOME}/node_modules/appium-webdriveragent/WebDriverAgent.xcodeproj is missed!"
      return 0
    fi

    nohup /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -project ${APPIUM_HOME}/node_modules/appium-webdriveragent/WebDriverAgent.xcodeproj \
      -derivedDataPath "${BASEDIR}/tmp/DerivedData/${udid}" \
      -scheme $scheme -destination id=$udid USE_PORT=$WDA_PORT MJPEG_SERVER_PORT=$MJPEG_PORT test > "${WDA_LOG}" 2>&1 &

    verifyWDAStartup "${WDA_LOG}" 300 >> "${WDA_LOG}"
    if [[ $? = 0 ]]; then
      # WDA was started successfully!
      # parse ip address from log file line:
      # 2020-07-13 17:15:15.295128+0300 WebDriverAgentRunner-Runner[5660:22940482] ServerURLHere->http://192.168.88.127:20001<-ServerURLHere

      WDA_HOST=`grep "ServerURLHere->" "${WDA_LOG}" | cut -d ':' -f 5`
      # remove forward slashes
      WDA_HOST="${WDA_HOST//\//}"
      # put IP address into the metadata file
      echo "export WDA_HOST=${WDA_HOST}" > ${WDA_ENV}
      echo "export WDA_PORT=${WDA_PORT}" >> ${WDA_ENV}
      echo "export MJPEG_PORT=${MJPEG_PORT}" >> ${WDA_ENV}
    else
      echo "WDA is not started successfully!"
      rm -fv "${WDA_ENV}"
      stop-wda $udid
    fi
  }

  stop() {
    if [ ! -f backup/settings.env ]; then
      echo_warning "You have to setup services in advance using: ./zebrunner.sh setup"
      echo_telegram
      exit -1
    fi

    udid=$1
    if [ ! -z $udid ]; then
      . ./configs/getDeviceArgs.sh $udid
      echo "Stopping MCloud services for $DEVICE_NAME udid: $DEVICE_UDID..."
      stop-stf $udid
      stop-appium $udid
      stop-wda $udid

      mkdir -p ./tmp/frozen-$udid

      return 0
    fi


    echo "Stopping MCloud services..."

    launchctl list $MCLOUD_SERVICE > /dev/null 2>&1
    if [ $? -eq 0 ]; then
      unload
    fi

    stop-stf
    stop-appium
    stop-wda

    pkill -f zebrunner.sh
    # clean logs
    echo "Removing logs..."
    rm -fv ./logs/*.log
    rm -fv ./logs/backup/*.log
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
      . ./configs/getDeviceArgs.sh $udid
      rm -fv "${WDA_ENV}"
    else
      export pids=`ps -eaf | grep xcodebuild | grep 'WebDriverAgent' | grep -v grep | grep -v stop-wda | awk '{ print $2 }'`
      rm -fv ${metaDataFolder}/*.env
    fi
    #echo pids: $pids

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
      rm -fv ${metaDataFolder}/${udid}.json
    else 
      export pids=`ps -eaf | grep 'appium' | grep -v grep | grep -v stop-appium | grep -v '/stf' | grep -v '/usr/share/maven' | grep -v 'WebDriverAgent' | awk '{ print $2 }'`
      rm -fv ${metaDataFolder}/*.json
    fi
    #echo pids: $pids

    kill_processes $pids
  }

  down() {
    if [ ! -f backup/settings.env ]; then
      echo_warning "You have to setup services in advance using: ./zebrunner.sh setup"
      echo_telegram
      exit -1
    fi

    udid=$1
    if [ ! -z $udid ]; then
      . ./configs/getDeviceArgs.sh $udid
      stop $udid

      # clean metadata
      echo "Removing temp Appium/WebDriverAgent data for $udid"
      rm -rf ./tmp/AppiumData/$udid
      rm -rf ./tmp/DerivedData/$udid

      mkdir -p ./tmp/frozen-$udid

      return 0
    fi


    stop

    # clean metadata
    echo "Removing temp Appium/WebDriverAgent data..."
    rm -rf ./tmp/*
  }

  load() {
    launchctl list $MCLOUD_SERVICE > /dev/null 2>&1
    if [ $? -eq 0 ]; then
      echo_warning "syncZebrunner services already loaded!"
    else
      echo "Loading syncZebrunner services..."
      launchctl load $HOME/Library/LaunchAgents/syncZebrunner.plist
    fi
  }

  unload() {
    launchctl list $MCLOUD_SERVICE > /dev/null 2>&1
    if [ ! $? -eq 0 ]; then
      echo_warning "syncZebrunner services already unloaded!"
    else
      echo "Unloading syncZebrunner services..."
      launchctl unload $HOME/Library/LaunchAgents/syncZebrunner.plist
    fi
  }

  status() {
    if [ ! -f backup/settings.env ]; then
      echo_warning "You have to setup services in advance using: ./zebrunner.sh setup"
      echo_telegram
      exit -1
    fi

    echo
    launchctl list $MCLOUD_SERVICE > /dev/null 2>&1
    if [ $? -eq 0 ]; then
      echo "syncZebrunner services status - LOADED"
    else
      echo "syncZebrunner services status - UNLOADED"
    fi
    echo

    echo "TODO: #78 implement extended status call for iOS devices and simulators"
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
    cp $HOME/Library/LaunchAgents/syncZebrunner.plist backup/syncZebrunner.plist
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

    down

    echo "Starting Devices Farm iOS agent restore..."
    cp backup/devices.txt devices.txt
    cp backup/syncZebrunner.plist $HOME/Library/LaunchAgents/syncZebrunner.plist
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
          status              Status of the syncZebrunner services
          setup               Setup Devices Farm iOS agent
          authorize-simulator Authorize whitelisted simulators
          load                Load LaunchAgents Zebrunner syncup services
          unload              Unload LaunchAgents Zebrunner syncup services
          start [udid]        Start Device Farm iOS agent services [all or for exact device by udid]
          stop [udid]         Stop Device Farm iOS agent services and remove logs [all or for exact device by udid]
          restart [udid]      Restart Device Farm iOS agent services [all or for exact device by udid]
          down [udid]         Stop Device Farm iOS agent services, remove logs and Appium/WDA temp data [all or for exact device by udid]
          shutdown            Destroy Device Farm iOS agent completely
          backup              Backup Device Farm iOS agent services
          restore             Restore Device Farm iOS agent services
          version             Version of Device Farm iOS agent"
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
    xcrun simctl list --json > ${SIMULATORS}
    echo `date +"%T"` Sync Simulators script finished
  }

  syncServices() {
    echo `date +"%T"` Sync MCloud Services script started

    # verify one by one connected devices and authorized simulators
    while read -r line
    do
      udid=`echo $line | cut -d '|' -f ${udid_position}`
      #to trim spaces around. Do not remove!
      udid=$(echo $udid)
      if [[ "$udid" = "UDID" ]]; then
        continue
      fi
      if [[ -d ./tmp/frozen-$udid ]]; then
        continue
      fi

      . ${BASEDIR}/configs/getDeviceArgs.sh $udid

      ########## WDA SERVICES ##########
      # unable to reuse WDA_HOST/WDA_PORT and status call as service might not be started
      # how about verify start-wda shell script as well?
      wda=`ps -ef | grep xcodebuild | grep $udid | grep WebDriverAgent`

      #echo device: $device
      #echo wda: $wda

      if [[ -n "$device" &&  -z "$wda" ]]; then
        # simultaneous WDA launch is not supported by Xcode!
        # error: error: accessing build database "/Users/../Library/Developer/Xcode/DerivedData/WebDriverAgent-../XCBuildData/build.db": database is locked
        # Possibly there are two concurrent builds running in the same filesystem location.
        start-wda $udid
        start-session $udid
      elif [[ -z "$device" &&  -n "$wda" ]]; then
        #double check for the case when connctedDevices.txt in sync and empty
        device=`/usr/local/bin/ios-deploy -c -t 5 | grep ${udid}`
        if [[ -z "${device}" ]]; then
          echo "WDA will be stopped: ${udid} - device name : ${name}"
          stop-wda $udid &
        fi
      fi

      ########## APPIUM SERVICES ##########
      appium=`ps -ef | grep ${APPIUM_HOME}/build/lib/main.js  | grep $udid`

      wda=${WDA_ENV}
      if [[ -n "$appium" && ! -f "$wda" ]]; then
        echo "Stopping Appium process as no WebDriverAgent process detected. ${udid} device name : ${name}"
        stop-appium $udid &
        #continue
      fi

      if [[ -n "$device" && -f "$wda" && -z "$appium" ]]; then
        start-appium $udid &
      elif [[ -z "$device" &&  -n "$appium" ]]; then
        #double check for the case when connctedDevices.txt in sync and empty
        device=`/usr/local/bin/ios-deploy -c -t 5 | grep ${udid}`
        if [[ -z "${device}" ]]; then
          echo "Appium will be stopped: ${udid} - device name : ${name}"
          stop-appium $udid &
        fi
      fi

      device="$physical$simulator"
      #echo device: $device

      stf=`ps -eaf | grep ${udid} | grep 'ios-device' | grep -v grep`
      wda=${WDA_ENV}
      if [[ -n "$stf" && ! -f "$wda" ]]; then
        echo "Stopping STF process as no WebDriverAgent process detected. ${udid} device name : ${name}"
        stop-stf $udid &
        #continue
      fi

      if [[ -n "$device" && -f "$wda" && -z "$stf" ]]; then
        start-stf $udid &
      elif [[ -z "$device" && -n "$stf" ]]; then
        #double check for the case when connctedDevices.txt in sync and empty
        device_status=`/usr/local/bin/ios-deploy -c -t 5 | grep ${udid}`
        if [[ -z "${device_status}" ]]; then
          echo "The iSTF ios-device will be stopped: ${udid} device name : ${name}"
          stop-stf $udid &
        fi
      fi

    done < ${devices}
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
    load)
        load
        ;;
    unload)
        unload
        ;;
    start)
        start $2
        ;;
    start-services)
        start-services
        ;;
    stop)
        stop $2
        ;;
    restart)
        stop $2
        start $2
        ;;
    down)
        down $2
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
    status)
        status
        ;;
    version)
        version
        ;;
    *)
        echo_help
        exit 1
        ;;
esac

