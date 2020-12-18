#!/bin/bash

devicePattern=$1
#echo devicePattern: $devicePattern

BASEDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

. ${BASEDIR}/configs/getDeviceArgs.sh $devicePattern

if [ "${device_ip}" == "" ]; then
  echo "Unable to detect ${name} device ip address! No sense to start STF!" >> "${BASEDIR}/logs/${name}_stf.log"
  exit -1
fi

echo "Starting iSTF ios-device: ${udid} device name : ${name}"

# Specify pretty old node v8.17.0 as current due to the STF dependency
export NVM_DIR="$HOME/.nvm"
[ -s "/usr/local/opt/nvm/nvm.sh" ] && . "/usr/local/opt/nvm/nvm.sh"  # This loads nvm
nvm use v8.17.0

STF_BIN=`which stf`
#echo STF_BIN: $STF_BIN

STF_CLI=`echo "${STF_BIN//bin\/stf/lib/node_modules/@devicefarmer/stf/lib/cli}"`
echo STF_CLI: $STF_CLI

nohup node $STF_CLI ios-device --serial ${udid} \
	--device-name ${name} \
	--device-type ${type} \
	--provider ${PROVIDER_NAME} --screen-port ${stf_screen_port} --connect-port ${mjpeg_port} --public-ip ${STF_PUBLIC_HOST} --group-timeout 3600 \
	--storage-url ${WEB_PROTOCOL}://${STF_PUBLIC_HOST}/ --screen-jpeg-quality 40 --screen-ping-interval 30000 \
	--screen-ws-url-pattern ${WEBSOCKET_PROTOCOL}://${STF_PUBLIC_HOST}/d/${STF_NODE_HOST}/${udid}/${stf_screen_port}/ \
	--boot-complete-timeout 60000 --mute-master never \
	--connect-app-dealer tcp://${STF_PRIVATE_HOST}:7160 --connect-dev-dealer tcp://${STF_PRIVATE_HOST}:7260 \
	--wda-host ${device_ip} --wda-port ${wda_port} \
	--appium-host ${STF_NODE_HOST} --appium-port ${appium_port} --proxy-appium-port ${proxy_appium_port} \
	--connect-sub tcp://${STF_PRIVATE_HOST}:7250 --connect-push tcp://${STF_PRIVATE_HOST}:7270 --no-cleanup >> "${BASEDIR}/logs/${name}_stf.log" 2>&1 &
