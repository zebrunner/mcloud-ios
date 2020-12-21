#!/bin/bash
devicePattern=$1
#echo devicePattern: $devicePattern

kill_processes()
{
  processes_pids=$1
  if [ "${processes_pids}" != "" ]; then
	echo processes_pids: $processes_pids
	kill -9 $processes_pids
  fi
}

BASEDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

. ${BASEDIR}/configs/getDeviceArgs.sh $devicePattern

deviceName=${name}
deviceUdid=${udid}

echo Killing WDA process for ${deviceName}
if [ "${deviceUdid}" != "" ]; then
	if ps -eaf | grep ${deviceUdid} | grep 'WebDriverAgent' | grep -v grep; then
		export pids=`ps -eaf | grep ${deviceUdid} | grep 'WebDriverAgent' | grep -v grep | awk '{ print $2 }'`
		kill_processes $pids
		rm -f ${metaDataFolder}/ip_${udid}.txt
	fi
else
	echo "Skipping WDA kill as device doesn't exist"
fi



