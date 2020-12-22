#!/bin/bash

BASEDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )/../" && pwd )

# STF master host settings
export PROVIDER_NAME=iMac-Developer.local
export STF_PUBLIC_HOST=stage.qaprosoft.com
export STF_PRIVATE_HOST=192.168.88.95
# iSTF node address (it should be private ip address accessible from STF master host)
export STF_NODE_HOST=192.168.88.96

export RETHINKDB_PORT_28015_TCP="tcp://${STF_PUBLIC_HOST}:28015"

export WEBSOCKET_PROTOCOL=ws
export WEB_PROTOCOL=http

# selenium hub settings
export hubHost=stage.qaprosoft.com
export hubPort=4446

export automation_name=XCUITest
export appium_home=/usr/local/lib/node_modules/appium

export devices=${BASEDIR}/devices.txt
export configFolder=${BASEDIR}/configs
export logFolder=${BASEDIR}/logs
export metaDataFolder=${BASEDIR}/metaData

if [ ! -d "${BASEDIR}/logs" ]; then
    mkdir "${BASEDIR}/logs"
fi

if [ ! -d "${BASEDIR}/metaData" ]; then
    mkdir "${BASEDIR}/metaData"
fi

# udid position in devices.txt to be able to read by sync scripts
export udid_position=4

