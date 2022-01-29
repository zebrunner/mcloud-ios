#!/bin/bash

udid=$1

if [ "$udid" == "" ]; then
  exit -1
fi

BASEDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )/../" && pwd )
devices=${BASEDIR}/devices.txt


name=`cat ${devices} | grep "$udid" | cut -d '|' -f 1`
export name=$(echo $name)

type=`cat ${devices} | grep "$udid" | cut -d '|' -f 2`
export type=$(echo $type)

os_version=`cat ${devices} | grep "$udid" | cut -d '|' -f 3`
export os_version=$(echo $os_version)

# no need to read udid as it is provided as required argument

appium_port=`cat ${devices} | grep "$udid" | cut -d '|' -f 5`
export appium_port=$(echo $appium_port)

wda_port=`cat ${devices} | grep "$udid" | cut -d '|' -f 6`
export wda_port=$(echo $wda_port)

mjpeg_port=`cat ${devices} | grep "$udid" | cut -d '|' -f 7`
export mjpeg_port=$(echo $mjpeg_port)

iwdp_port=`cat ${devices} | grep "$udid" | cut -d '|' -f 8`
export iwdp_port=$(echo $iwdp_port)

stf_screen_port=`cat ${devices} | grep "$udid" | cut -d '|' -f 9`
export stf_screen_port=$(echo $stf_screen_port)

proxy_appium_port=`cat ${devices} | grep "$udid" | cut -d '|' -f 10`
export proxy_appium_port=$(echo $proxy_appium_port)

ip=""
if [[ -f "${metaDataFolder}/ip_${udid}.txt" ]]; then
  ip=`cat ${metaDataFolder}/ip_${udid}.txt`
fi
export ip=$(echo $ip)

session_ip=""
if [[ -f "${metaDataFolder}/session_${udid}.txt" ]]; then
  session_ip=`cat ${metaDataFolder}/session_${udid}.txt`
fi
export session_ip=$(echo $session_ip)


export APPIUM_LOG="logs/appium_${name}.log"
export STF_LOG="logs/stf_${name}.log"
