#!/bin/bash

udid=$1

BASEDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )/../" && pwd )
. ${BASEDIR}/configs/getDeviceArgs.sh $udid
. ${BASEDIR}/.env


DEVICENAME=${name}
DEVICETYPE=${type}
DEVICEVERSION=${os_version}
DEVICEPLATFORM=MAC
DEVICEOS=iOS
DEVICEUDID=${udid}
PROXY_PORT=${proxy_port}
cat << EndOfMessage
{
  "capabilities":
      [
        {
          "browserName": "safari",
          "version":"${DEVICEVERSION}",
          "maxInstances": 1,
          "platform":"${DEVICEPLATFORM}",
	  "deviceName": "${DEVICENAME}",
          "deviceType": "${DEVICETYPE}",
          "platformName":"${DEVICEOS}",
          "platformVersion":"${DEVICEVERSION}",
          "proxy_port":"${PROXY_PORT}",
	  "udid": "${DEVICEUDID}"
        }
      ],
  "configuration":
  {
    "proxy": "com.zebrunner.mcloud.grid.MobileRemoteProxy",
    "url":"http://${HUB_HOST}:${HUB_PORT}/wd/hub",
    "port": ${appium_port},
    "host": "${STF_NODE_HOST}",
    "hubPort": ${HUB_PORT},
    "hubHost": "${HUB_HOST}",
    "timeout": 180,
    "maxSession": 1,
    "register": true,
    "registerCycle": 5000,
    "automationName": "${AUTOMATION_NAME}",
    "downPollingLimit": 10
  }
}
EndOfMessage
