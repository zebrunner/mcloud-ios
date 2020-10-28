#!/bin/bash
devicePattern=$1
#echo devicePattern: $devicePattern

BASEDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

. ${BASEDIR}/configs/getDeviceArgs.sh $devicePattern

if [ "${udid}" != "" ]; then
	kill -9 `ps -eaf | grep ${udid} | grep 'ios-device' | grep -v grep | awk '{ print $2 }'`
fi



