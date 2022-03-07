#!/bin/bash

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

appium_port=`cat ${devices} | grep "$udid" | cut -d '|' -f 3`
export appium_port=$(echo $appium_port)

WDA_PORT=`cat ${devices} | grep "$udid" | cut -d '|' -f 4`
export WDA_PORT=$(echo $WDA_PORT)

MJPEG_PORT=`cat ${devices} | grep "$udid" | cut -d '|' -f 5`
export MJPEG_PORT=$(echo $MJPEG_PORT)

iwdp_port=`cat ${devices} | grep "$udid" | cut -d '|' -f 6`
export iwdp_port=$(echo $iwdp_port)

stf_screen_port=`cat ${devices} | grep "$udid" | cut -d '|' -f 7`
export stf_screen_port=$(echo $stf_screen_port)

proxy_appium_port=`cat ${devices} | grep "$udid" | cut -d '|' -f 8`
export proxy_appium_port=$(echo $proxy_appium_port)

proxy_port=`cat ${devices} | grep "$udid" | cut -d '|' -f 9`
export proxy_port=$(echo $proxy_port)

if [ -z $proxy_port ]; then
  # #105 made 9000 as default proxy port if nothing provided in devices.txt
  export proxy_port=9000
fi

export APPIUM_LOG="logs/appium_${name}.log"
export STF_LOG="logs/stf_${name}.log"
export WDA_LOG="logs/wda_${name}.log"

export WDA_ENV="${metaDataFolder}/${name}.env"
if [ -f "${WDA_ENV}" ]; then
  . ${WDA_ENV}
fi
