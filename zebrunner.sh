#!/bin/bash

BASEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd ${BASEDIR}

export CHECK_APP_SIZE_OPTIONALLY=true

source .env

export devices=${BASEDIR}/devices.txt
export metaDataFolder=${BASEDIR}/metaData

if [ ! -d "${BASEDIR}/metaData" ]; then
    mkdir -p "${BASEDIR}/metaData"
fi

# udid position in devices.txt to be able to read by sync scripts
export udid_position=2

  print_banner() {
  echo "Zebrunner CE"

  }

  setup() {
    print_banner

    # software prerequisites check like appium, xcode etc

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

    export ZBR_MCLOUD_IOS_VERSION=2.4.5

    # unload Devices Manager script if any to avoid restarts during setup
    if [[ -r $HOME/Library/LaunchAgents/ZebrunnerDevicesManager.plist ]]; then
      launchctl unload $HOME/Library/LaunchAgents/ZebrunnerDevicesManager.plist > /dev/null 2>&1
    fi

    echo 

    cd "${BASEDIR}"

    # register devices manager to manage attach/reboot actions
    cp LaunchAgents/ZebrunnerDevicesManager.plist $HOME/Library/LaunchAgents/ZebrunnerDevicesManager.plist
    replace $HOME/Library/LaunchAgents/ZebrunnerDevicesManager.plist "working_dir_value" "${BASEDIR}"
    replace $HOME/Library/LaunchAgents/ZebrunnerDevicesManager.plist "user_value" "$USER"
    # load asap to be able to start services after whitelisted device connect

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

      setup-device $udid
    done < ${devices}

    echo_warning "Your services needs to be restarted using './zebrunner.sh restart'!"

  }

  shutdown() {
    echo_warning "Shutdown will erase all settings and data for \"${BASEDIR}\"!"
    confirm "" "      Do you want to continue?" "n"
    if [[ $? -eq 0 ]]; then
      exit
    fi

    print_banner

    stop

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


    rm -f $HOME/Library/LaunchAgents/ZebrunnerDevicesManager.plist

    # remove configuration files and LaunchAgents plist(s)
    git checkout -- devices.txt

  }

  setup-device() {
    udid=$1

    . ./configs/getDeviceArgs.sh $udid

    if [ -r $HOME/Library/LaunchAgents/syncZebrunner_$udid.plist ]; then
      # unload explicitly in advance in case it is secondary etc setup
      launchctl unload $HOME/Library/LaunchAgents/syncZebrunner_$udid.plist > /dev/null 2>&1
    fi

    # save device info json into the metadata for detecting device class type from file (#171 move iOS device type detection onto the setup level)
    ios info --udid=$udid > ${BASEDIR}/metaData/device-$udid.json

    echo $udid
    cp LaunchAgents/syncZebrunner.plist $HOME/Library/LaunchAgents/syncZebrunner_$udid.plist
    replace $HOME/Library/LaunchAgents/syncZebrunner_$udid.plist "working_dir_value" "${BASEDIR}"
    replace $HOME/Library/LaunchAgents/syncZebrunner_$udid.plist "user_value" "$USER"
    replace $HOME/Library/LaunchAgents/syncZebrunner_$udid.plist "udid_value" "$udid"

    # to load syncup recovery script run:
    #   launchctl load $HOME/Library/LaunchAgents/syncZebrunner_$udid.plist > /dev/null 2>&1
    # to initiate recovery run:
    #   launchctl kickstart gui/${UID}/com.zebrunner.mcloud.${UDID}
    # to unload recovery script run:
    #   launchctl unload $HOME/Library/LaunchAgents/syncZebrunner_$udid.plist > /dev/null 2>&1

  }

  on-usb-update() {
    read
    while true
    do
	#process $REPLY
	#The new line content is in the variable $REPLY
        #echo REPLY: $REPLY

        # message on device connect
	# {"MessageType":"Attached","DeviceID":27,"Properties":{"ConnectionSpeed":480000000,"ConnectionType":"USB","DeviceID":27,"LocationID":336592896,"ProductID":4776,"SerialNumber":"b09fa26acc4c3f777e9b8b49e3348b7243f862b5"}}

	# message on device disconnect
	# {"MessageType":"Detached","DeviceID":27,"Properties":{"ConnectionSpeed":0,"ConnectionType":"","DeviceID":0,"LocationID":0,"ProductID":0,"SerialNumber":""}}

        # parse MessageType
        action=`echo $REPLY | jq -r ".MessageType"`
        #echo "action: $action"

	if [[ "$action" == "Attached" ]]; then
          echo REPLY: $REPLY
          # parse udid and start services
          udid=`echo $REPLY | jq -r ".Properties.SerialNumber"`
          . ./configs/getDeviceArgs.sh $udid

          status-device $udid
          if [ $? -eq 0 ]; then
            echo "do nothing as state is valid (healthy or starting) for $DEVICE_NAME ($DEVICE_UDID)"
            return 0
          fi

          echo "$DEVICE_NAME ($DEVICE_UDID): Start services for attached device."
          # TODO: we explicitly do stop because ios listen return historical line for last connected device. in this case we will restart services.
          # in future let's try to operate with real-time messages and do only start! As variant do status in advance and skip if already healthy.
          stop-device $udid

          # #208: start processes not as a child of existing one: https://stackoverflow.com/questions/20338162/how-can-i-launch-a-new-process-that-is-not-a-child-of-the-original-process
          # only in this case appium has access to webview content. Otherwise, such issue occur:
          #     "An unknown server-side error occurred while processing the command. Original error: Could not navigate to webview! Err: Failed to receive any data within the timeout: 5000"
          #( start-device $udid & )
          ( ${BASEDIR}/zebrunner.sh start $udid & )
        fi

        read
    done
  }

  listen() {
    # do analysis of ios listen output and organize automatic start/stop for connected/disconnected device
    ios listen | on-usb-update
  }

  start() {
    if [ ! -f $HOME/Library/LaunchAgents/ZebrunnerDevicesManager.plist ]; then
      echo_warning "You have to setup services in advance using: ./zebrunner.sh setup"
      echo_telegram
      exit -1
    fi

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

      # #208: start processes not as a child of existing one: https://stackoverflow.com/questions/20338162/how-can-i-launch-a-new-process-that-is-not-a-child-of-the-original-process
      # only in this case appium has access to webview content. Otherwise, such issue occur:
      #     "An unknown server-side error occurred while processing the command. Original error: Could not navigate to webview! Err: Failed to receive any data within the timeout: 5000"
      #( start-device $udid & ) 
      ( ${BASEDIR}/zebrunner.sh start $udid & )
    done < ${devices}

    launchctl load $HOME/Library/LaunchAgents/ZebrunnerDevicesManager.plist > /dev/null 2>&1

    echo "Verify startup status using './zebrunner.sh status'"
    exit 0
  }

  start-device() {
    if [ ! -f $HOME/Library/LaunchAgents/ZebrunnerDevicesManager.plist ]; then
      echo_warning "You have to setup services in advance using: ./zebrunner.sh setup"
      echo_telegram
      exit -1
    fi

    udid=$1

    . ./configs/getDeviceArgs.sh $udid

    if [ -n "$device" ]; then
      echo "$DEVICE_NAME ($DEVICE_UDID)" >> ${DEVICE_LOG} 2>&1
      #load recovery service script
      launchctl load $HOME/Library/LaunchAgents/syncZebrunner_$udid.plist > /dev/null 2>&1
      launchctl list | grep com.zebrunner.mcloud.$udid > /dev/null 2>&1
      if [ $? -eq 1 ]; then
        echo_warning "LaunchAgent recovery script is not loaded for $DEVICE_NAME udid: $DEVICE_UDID!" >> ${DEVICE_LOG} 2>&1
        return 1
      fi

      start-wda $udid >> ${DEVICE_LOG} 2>&1
      if [ $? -eq 1 ]; then
        echo_warning "WDA is not started for $DEVICE_NAME udid: $DEVICE_UDID!" >> ${DEVICE_LOG} 2>&1
        exit 1
      fi

    else 
      echo "$DEVICE_NAME ($DEVICE_UDID) is disconnected!" >> ${DEVICE_LOG} 2>&1
    fi
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
    schema=WebDriverAgentRunner

    if [ "$DEVICETYPE" == "tvOS" ]; then
      schema=WebDriverAgentRunner_tvOS
    fi

    if [ -n "$physical" ]; then
      #Start the WDA service on the device using the WDA bundleId
      echo "[$(date +'%d/%m/%Y %H:%M:%S')] Starting WebDriverAgent application on port $WDA_PORT"
      echo TODO: replace by xcodebuild
      echo ios runwda --bundleid=$device_wda_bundle_id --testrunnerbundleid=$device_wda_bundle_id --xctestconfig=${schema}.xctest \
        --env USE_PORT=$WDA_PORT --env MJPEG_SERVER_PORT=$MJPEG_PORT --env UITEST_DISABLE_ANIMATIONS=YES --udid $udid &

      /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -project ${device_wda_home}/WebDriverAgent.xcodeproj -derivedDataPath "${BASEDIR}/tmp/DerivedData/${udid}" \
        -scheme $schema -destination id=$udid USE_PORT=$WDA_PORT MJPEG_SERVER_PORT=$MJPEG_PORT test

      echo xcrun devicectl device process launch -e '{"USE_PORT": "8100", "MJPEG_SERVER_PORT": "8101", "UITEST_DISABLE_ANIMATIONS": "YES"}' --device $udid $device_wda_bundle_id
      echo xcrun devicectl device process launch -e '{"USE_PORT": "8100", "MJPEG_SERVER_PORT": "8101", "UITEST_DISABLE_ANIMATIONS": "YES"}' --device $udid $device_wda_bundle_id

    fi

    echo "export WDA_HOST=${WDA_HOST}" > ${WDA_ENV}
    echo "export WDA_PORT=${WDA_PORT}" >> ${WDA_ENV}
    echo "export MJPEG_PORT=${MJPEG_PORT}" >> ${WDA_ENV}

    return 0
  }

  recover() {
    udid=$1
    if [ "$udid" == "" ]; then
      echo_warning "Unable to check WDA without device udid!"
      return 0
    fi
    #echo udid: $udid

    . ./configs/getDeviceArgs.sh $udid
    #echo device: $device
    if [[ -z $device ]]; then
      # there is no sense to restart services as device is disconnected
      echo "[$(date +'%d/%m/%Y %H:%M:%S')] Stop services for $DEVICE_NAME ($DEVICE_UDID)"
      stop-device $udid >> ${DEVICE_LOG} 2>&1 &
    else
      echo "[$(date +'%d/%m/%Y %H:%M:%S')] Recover services for $DEVICE_NAME ($DEVICE_UDID)"
      #obligatory reset logs to analyze wda startup correctly
      stop-wda $udid >> ${DEVICE_LOG} 2>&1 &
      sleep 1

      # #208: start processes not as a child of existing one: https://stackoverflow.com/questions/20338162/how-can-i-launch-a-new-process-that-is-not-a-child-of-the-original-process
      # only in this case appium has access to webview content. Otherwise, such issue occur:
      #     "An unknown server-side error occurred while processing the command. Original error: Could not navigate to webview! Err: Failed to receive any data within the timeout: 5000"
      #( start-device $udid & )
      ( ${BASEDIR}/zebrunner.sh start $udid & )
    fi
  }

  stop() {
    if [ ! -f $HOME/Library/LaunchAgents/ZebrunnerDevicesManager.plist ]; then
      echo_warning "You have to setup services in advance using: ./zebrunner.sh setup"
      echo_telegram
      exit -1
    fi

    echo "Stopping MCloud services..."

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

    launchctl unload $HOME/Library/LaunchAgents/ZebrunnerDevicesManager.plist > /dev/null 2>&1

    wait
    echo "MCloud services stopped."

  }

  stop-device() {
    if [ ! -f $HOME/Library/LaunchAgents/ZebrunnerDevicesManager.plist ]; then
      echo_warning "You have to setup services in advance using: ./zebrunner.sh setup"
      echo_telegram
      exit -1
    fi

    udid=$1
    . ./configs/getDeviceArgs.sh $udid

    echo "$DEVICE_NAME ($DEVICE_UDID)"
    launchctl unload $HOME/Library/LaunchAgents/syncZebrunner_$udid.plist > /dev/null 2>&1
    stop-wda $udid >> ${DEVICE_LOG} 2>&1
  }


  stop-wda() {
    if [ ! -f $HOME/Library/LaunchAgents/ZebrunnerDevicesManager.plist ]; then
      echo_warning "You have to setup services in advance using: ./zebrunner.sh setup"
      echo_telegram
      exit -1
    fi

    udid=$1
    #echo udid: $udid

    if [ ! -n "$simulator" ]; then
      echo TODO: kill wda processes based on below example
      #xcrun devicectl device info processes --device 00008101-000308620121001E | grep WebDriver
      #xcrun devicectl device process signal --pid 2542 --signal SIGTERM --device 00008101-000308620121001E


      #echo ios kill $WDA_BUNDLE_ID --udid=$udid
      #export pids=`ps -eaf | grep ${udid} | grep ios | grep 'runwda' | grep $WDA_PORT | grep -v grep | awk '{ print $2 }'`
      ##echo "ios ruwda pid: $pids"
      #kill_processes $pids

      ## kill ios forward proxy requests
      #export pids=`ps -eaf | grep ${udid} | grep ios | grep 'forward' | grep -v grep | awk '{ print $2 }'`
      ##echo "ios forward pid: $pids"
      #kill_processes $pids

    fi

    . ./configs/getDeviceArgs.sh $udid
    rm -fv "${WDA_ENV}"

  }

  status() {
    if [ ! -f $HOME/Library/LaunchAgents/ZebrunnerDevicesManager.plist ]; then
      echo_warning "You have to setup services in advance using: ./zebrunner.sh setup"
      echo_telegram
      exit -1
    fi

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
      # verify if recovery script is loaded otherwise device services are stopped!
      launchctl list | grep $DEVICE_UDID | grep "com.zebrunner.mcloud" > /dev/null 2>&1
      if [ $? -eq 1 ]; then
        echo "$DEVICE_NAME ($DEVICE_UDID) is stopped."
        return 1
      fi

      ps -ef | grep zebrunner.sh | grep start | grep $udid > /dev/null 2>&1
      if [ $? -eq 0 ]; then
        echo "$DEVICE_NAME ($DEVICE_UDID) is starting."
        return 0
      fi

      #Hit the Appium status URL to see if it is available
      #  --max-time 10     (how long each retry will wait)
      #  --retry 5         (it will retry 5 times)
      #  --retry-delay 0   (an exponential backoff algorithm)
      #  --retry-max-time  (total time before it's considered failed)
      if curl --max-time 10 -Is "http://localhost:$appium_port/wd/hub/status-wda" | head -1 | grep -q '200 OK'
      then
        echo "$DEVICE_NAME ($DEVICE_UDID) is healthy."
        return 0
      else
        echo "$DEVICE_NAME ($DEVICE_UDID) is unhealthy!"
        return 1
      fi
    else
      echo "$DEVICE_NAME ($DEVICE_UDID) is disconnected!"
      return 1
    fi

    return 1

  }

  backup() {
    if [ ! -f $HOME/Library/LaunchAgents/ZebrunnerDevicesManager.plist ]; then
      echo_warning "You have to setup services in advance using: ./zebrunner.sh setup"
      echo_telegram
      exit -1
    fi

    echo "Starting Devices Farm iOS agent backup..."
    cp devices.txt backup/devices.txt
    cp $HOME/Library/LaunchAgents/ZebrunnerDevicesManager.plist $HOME/Library/LaunchAgents/ZebrunnerDevicesManager.plist.bak
    echo "Backup Devices Farm iOS agent finished."

  }

  restore() {
    if [ ! -f $HOME/Library/LaunchAgents/ZebrunnerDevicesManager.plist.bak ]; then
      echo_warning "You have to backup services in advance using: ./zebrunner.sh backup"
      echo_telegram
      exit -1
    fi

    confirm "" "      Your services will be stopped and current data might be lost. Do you want to do a restore now?" "n"
    if [[ $? -eq 0 ]]; then
      exit
    fi

    stop

    echo "Starting Devices Farm iOS agent restore..."
    cp backup/devices.txt devices.txt
    cp $HOME/Library/LaunchAgents/ZebrunnerDevicesManager.plist.bak $HOME/Library/LaunchAgents/ZebrunnerDevicesManager.plist

    echo "Restore Devices Farm iOS agent finished."

    echo_warning "Your services needs to be started after restore."
    confirm "" "      Start now?" "y"
    if [[ $? -eq 1 ]]; then
      start
    fi
  }

  version() {
    if [ ! -f $HOME/Library/LaunchAgents/ZebrunnerDevicesManager.plist ]; then
      echo_warning "You have to setup services in advance using: ./zebrunner.sh setup"
      echo_telegram
      exit -1
    fi

    echo "MCloud Device Farm: ${ZBR_MCLOUD_IOS_VERSION}"
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
        echo -e "$message"
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
    FAIL_INDICATOR="Failed running WDA"
    UNSUPPORTED_INDICATOR="Unable to find a destination matching the provided destination specifier"

    COUNTER=0
    while [[  $COUNTER -lt $STARTUP_COUNTER ]];
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
         start-device $2
        fi
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
    listen)
        listen
        ;;
    version)
        version
        ;;
    *)
        echo_help
        exit 1
        ;;
esac

