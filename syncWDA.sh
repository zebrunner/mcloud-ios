#!/bin/bash

BASEDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
. ${BASEDIR}/configs/set_properties.sh

echo `date +"%T"` Sync WDA script started

# use-case when on-demand manual "./zebrunner.sh start-wda" is running!
isRunning=`ps -ef | grep start-wda | grep -v grep`
#echo isRunning: $isRunning

if [[ -n "$isRunning" ]]; then
  echo WebDriverAgent is being starting already. Skip sync operation!
  exit 0
fi


connectedDevices=${metaDataFolder}/connectedDevices.txt
connectedSimulators=${metaDataFolder}/connectedSimulators.txt

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
