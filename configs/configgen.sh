#!/bin/bash

udid=$1

BASEDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )/../" && pwd )
. ${BASEDIR}/configs/getDeviceArgs.sh $udid
. ${BASEDIR}/.env


HUB_HOST=ua-ecomm.zebrunner.farm
HUB_PORT=4446
STF_NODE_HOST=82.214.177.186

DEVICENAME=${name}
DEVICEPLATFORM=MAC
DEVICEOS=ios
DEVICEUDID=${udid}
cat << EndOfMessage
{
  "capabilities":
      [
        {
          "maxInstances": 1,
          "platform":"${DEVICEPLATFORM}",
          "platformVersion":"*",
	  "deviceName": "${DEVICENAME}",
          "deviceType": "${DEVICETYPE}",
          "platformName":"${DEVICEOS}",
	  "udid": "${DEVICEUDID}"
        }
      ],
  "configuration":
  {
    "proxy": "com.zebrunner.mcloud.grid.MobileRemoteProxy",
    "url":"http://${HUB_HOST}:${HUB_PORT}/wd/hub",
    "port": ${device_appium_port},
    "host": "${STF_NODE_HOST}",
    "hubPort": ${HUB_PORT},
    "hubHost": "${HUB_HOST}",
    "timeout": 180,
    "maxSession": 1,
    "register": true,
    "registerCycle": 5000,
    "automationName": "XCUITest",
    "downPollingLimit": 10
  }
}
EndOfMessage
