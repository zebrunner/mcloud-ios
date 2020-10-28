#!/bin/bash
BASEDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
. ${BASEDIR}/configs/set_properties.sh

echo `date +"%T"` Sync STF script started

logFile=${metaDataFolder}/connectedDevices.txt

while read -r line
do
        udid=`echo $line | cut -d '|' -f ${udid_position}`
        #to trim spaces around. Do not remove!
        udid=$(echo $udid)
        if [ "$udid" = "UDID" ]; then
            continue
        fi
       . ${BASEDIR}/configs/getDeviceArgs.sh $udid

        simulator=`echo $line | grep simul`

        if [[ -n "$simulator" ]]; then
#                device=${name}
		# simulators temporary unavailable in iSTF
		continue
        else
                device=`cat ${logFile} | grep $udid`
        fi

        stf=`ps -eaf | grep ${udid} | grep 'ios-device' | grep -v grep`
	wda=`ps -ef | grep xcodebuild | grep $udid | grep WebDriverAgent`
        if [[ -n "$stf" && -z "$wda" ]]; then
                echo "Stopping STF process. Wda is crashed or not started but STF process exists. ${udid} device name : ${name}"
                ${BASEDIR}/stopSTF.sh $udid &
                continue
        fi

        if [[ -n "$device" && -n "$wda" && -z "$stf" ]]; then
                ${BASEDIR}/startSTF.sh $udid &
        elif [[ -z "$device" && -n "$stf" ]]; then
		device_status=`/usr/local/bin/ios-deploy -c -t 5 | grep ${udid}`
		if [[ -z "${device_status}" ]]; then
			echo "The iSTF ios-device will be stopped: ${udid} device name : ${name}"
            		${BASEDIR}/stopSTF.sh $udid &
        	fi
        fi
done < ${devices}
