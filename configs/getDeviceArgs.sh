#!/bin/bash

# IMPORTANT!!! don't do echo as it corrupt appium json generator!

udid=$1

if [ "$udid" == "" ]; then
  exit -1
fi

BASEDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )/../" && pwd )
devices=${BASEDIR}/devices.txt


name=`cat ${devices} | grep "$udid" | cut -d '|' -f 1`
export name=$(echo $name)

DEVICE_NAME=`cat ${devices} | grep "$udid" | cut -d '|' -f 1`
export DEVICE_NAME=$(echo $DEVICE_NAME)

DEVICE_UDID=`cat ${devices} | grep "$udid" | cut -d '|' -f 2`
export DEVICE_UDID=$(echo $DEVICE_UDID)

device_wda_bundle_id=`cat ${devices} | grep "$udid" | cut -d '|' -f 3`
export device_wda_bundle_id=$(echo $device_wda_bundle_id)

device_wda_home=`cat ${devices} | grep "$udid" | cut -d '|' -f 4`
export device_wda_home=$(echo $device_wda_home)

export DEVICE_LOG="logs/${name}.log"

export WDA_ENV="${metaDataFolder}/${name}.env"
if [ -f "${WDA_ENV}" ]; then
  . ${WDA_ENV}
fi

#reset to generate new value per udid
export simulator=
export physical=

export DEVICETYPE='Phone'
export PLATFORM_NAME=iOS

  # verify if physical device is connected
  ios list | grep $udid > /dev/null 2>&1
  if [[ $? -eq 0 ]]; then
    export physical=$DEVICE_NAME
  fi

  if [[ -r ${BASEDIR}/metaData/device-$udid.json ]]; then
    deviceClass=$(cat ${BASEDIR}/metaData/device-$udid.json | jq -r ".DeviceClass")
    if [ "$deviceClass" = "iPad" ]; then
      export DEVICETYPE='Tablet'
    fi
    if [ "$deviceClass" = "AppleTV" ]; then
      export DEVICETYPE='tvOS'
    fi
  fi

export device="$physical$simulator"
#echo device: $device


