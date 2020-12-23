#!/bin/bash

BASEDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )/../" && pwd )

# STF master host settings
export STF_MASTER_HOST=stage.qaprosoft.com
# iSTF node address (it should be private ip address accessible from STF master host)
export STF_NODE_HOST=192.168.88.96

export RETHINKDB_PORT_28015_TCP="tcp://${STF_MASTER_HOST}:28015"

export WEBSOCKET_PROTOCOL=ws
export WEB_PROTOCOL=http

# selenium hub settings
export hubHost=stage.solvd.com
export hubPort=4446


export automation_name=XCUITest
export appium_home=export appium_home=/usr/local/lib/node_modules/appium

export devices=${BASEDIR}/devices.txt
export configFolder=${BASEDIR}/configs
export logFolder=${BASEDIR}/logs
export metaDataFolder=${BASEDIR}/metaData

if [ ! -d "${BASEDIR}/logs" ]; then
    mkdir -p "${BASEDIR}/logs/backup"
fi

if [ ! -d "${BASEDIR}/metaData" ]; then
    mkdir "${BASEDIR}/metaData"
fi

# udid position in devices.txt to be able to read by sync scripts
export udid_position=4

