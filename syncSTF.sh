#!/bin/bash
BASEDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
. ${BASEDIR}/configs/set_properties.sh

echo `date +"%T"` Sync STF script started

connectedDevices=${metaDataFolder}/connectedDevices.txt
connectedSimulators=${metaDataFolder}/connectedSimulators.txt

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
