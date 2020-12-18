#!/bin/bash

devicePattern=$1
#echo devicePattern: $devicePattern

BASEDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

. ${BASEDIR}/configs/getDeviceArgs.sh $devicePattern

if [ "${device_ip}" == "" ]; then
  echo "Unable to detect ${name} device ip address! No sense to start Appium!" >> "${BASEDIR}/logs/${name}_appium.log"
  exit -1
fi

echo "Starting appium: ${udid} - device name : ${name}"


${BASEDIR}/configs/configgen.sh $udid > ${BASEDIR}/metaData/$udid.json

newWDA=false
#TODO: investigate if tablet should be registered separately, what about tvOS

nohup node ${appium_home}/build/lib/main.js -p ${appium_port} --log-timestamp --device-name "${name}" --automation-name=XCUItest --udid $udid \
  --tmp "${BASEDIR}/tmp/AppiumData/${udid}" \
  --default-capabilities \
  '{"mjpegServerPort": '${mjpeg_port}', "webkitDebugProxyPort": '${iwdp_port}', "clearSystemFiles": "false", "webDriverAgentUrl":"'http://${device_ip}:${wda_port}'", "derivedDataPath":"'${BASEDIR}/tmp/DerivedData/${udid}'", "preventWDAAttachments": "true", "simpleIsVisibleCheck": "true", "wdaLocalPort": "'$wda_port'", "usePrebuiltWDA": "true", "useNewWDA": "'$newWDA'", "platformVersion": "'$os_version'", "automationName":"'${automation_name}'", "deviceName":"'$name'" }' \
   --nodeconfig ./metaData/$udid.json >> "${BASEDIR}/logs/${name}_appium.log" 2>&1 &
