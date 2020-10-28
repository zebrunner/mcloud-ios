#!/bin/bash
BASEDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
. ${BASEDIR}/configs/set_properties.sh

echo `date +"%T"` Sync WDA script started

logFile=${metaDataFolder}/connectedDevices.txt

# use-case when on-demand manual startWDA.sh is running!
isRunning=`ps -ef | grep startWDA.sh | grep -v grep`
#echo isRunning: $isRunning

if [[ -n "$isRunning" ]]; then
  echo WebDriverAgent is being starting already. Skip sync operation!
  exit 0
fi

while read -r line
do
        udid=`echo $line | cut -d '|' -f ${udid_position}`
        #to trim spaces around. Do not remove!
        udid=$(echo $udid)
        if [ "$udid" = "UDID" ]; then
            continue
        fi
        simulator=`echo $line | grep simul`
       . ${BASEDIR}/configs/getDeviceArgs.sh $udid

        #wda check is only for approach with syncWda.sh and usePrebuildWda=true
        wda=`ps -ef | grep xcodebuild | grep $udid | grep WebDriverAgent`

        if [[ -n "$simulator" ]]; then
                device=${name}
        else
                device=`cat ${logFile} | grep $udid`
        fi

        if [[ -n "$device" &&  -z "$wda" ]]; then
		echo "Starting wda: ${udid}"
		# simultaneous WDA launch is not supported by Xcode!
		# error: error: accessing build database "/Users/../Library/Developer/Xcode/DerivedData/WebDriverAgent-../XCBuildData/build.db": database is locked 
		# Possibly there are two concurrent builds running in the same filesystem location.
                ${BASEDIR}/startWDA.sh $udid
        elif [[ -z "$device" &&  -n "$wda" ]]; then
		echo "WDA should be stopped automatically: ${udid}"
        fi
done < ${devices}
