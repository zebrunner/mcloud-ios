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

export simulator=$(cat ${SIMULATORS} | jq -r ".devices[][] | select (.udid==\"$udid\" and .isAvailable==true) | .name")
if [[ -n $simulator ]]; then
  # detect DEVICE_TYPE to be able to override for Tablet and AppleTV

  export simulatorType=$(cat ${SIMULATORS} | jq -r ".devices[][] | select (.udid==\"$udid\" and .isAvailable==true) | .deviceTypeIdentifier")
  #echo simulatorType: $simulatorType

  # define valid DEVICETYPE using $simulatorType
  # Phone: com.apple.CoreSimulator.SimDeviceType.iPhone-13-Pro
  # Tablet: com.apple.CoreSimulator.SimDeviceType.iPad-Pro-12-9-inch-5th-generation
  # tvOS: com.apple.CoreSimulator.SimDeviceType.Apple-TV-4K-2nd-generation-1080p
  #TODO: define strategy for 'Apple Watch' com.apple.CoreSimulator.SimDeviceType.Apple-Watch-38mm
  if [[ "$simulatorType" == *iPad* ]]; then
    export DEVICETYPE='Tablet'
  fi
  if [[ "$simulatorType" == *Apple-TV* ]]; then
    export DEVICETYPE='tvOS'
  fi
else
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
fi

export device="$physical$simulator"
#echo device: $device


