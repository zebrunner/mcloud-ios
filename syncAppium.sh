#!/bin/bash

BASEDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
. ${BASEDIR}/configs/set_properties.sh

echo `date +"%T"` Sync Appium script started

connectedDevices=${metaDataFolder}/connectedDevices.txt
connectedSimulators=${metaDataFolder}/connectedSimulators.txt

while read -r line
do
  udid=`echo $line | cut -d '|' -f ${udid_position}`
  #to trim spaces around. Do not remove!
  udid=$(echo $udid)
  if [[ "$udid" = "UDID" ]]; then
    continue
  fi
  . ${BASEDIR}/configs/getDeviceArgs.sh $udid

  appium=`ps -ef | grep $appium_home/build/lib/main.js  | grep $udid`

  physical=`cat ${connectedDevices} | grep $udid`
  simulator=`cat ${connectedSimulators} | grep $udid`
  device="$physical$simulator"
  #echo device: $device

  wda=${metaDataFolder}/ip_${udid}.txt
  #echo wda: $wda
  
  if [[ -n "$appium" && ! -f "$wda" ]]; then
    echo "Stopping Appium process as no WebDriverAgent process detected. ${udid} device name : ${name}"
    ${BASEDIR}/stopAppium.sh $udid &
    continue
  fi

  if [[ -n "$device" && -f "$wda" && -z "$appium" ]]; then
    ${BASEDIR}/startAppium.sh $udid &
  elif [[ -z "$device" &&  -n "$appium" ]]; then
    #double check for the case when connctedDevices.txt in sync and empty
    device=`/usr/local/bin/ios-deploy -c -t 5 | grep ${udid}`
    if [[ -z "${device}" ]]; then
      echo "Appium will be stopped: ${udid} - device name : ${name}"
      echo device: $device
      echo appium: $appium
      ${BASEDIR}/stopAppium.sh $udid &
    fi
  fi
done < ${devices}

