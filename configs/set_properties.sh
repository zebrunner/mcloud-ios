#!/bin/bash

BASEDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )/../" && pwd )

# MCloud STF master host settings
export STF_MASTER_HOST=stage.qaprosoft.com
export RETHINKDB_PORT_28015_TCP="tcp://${STF_MASTER_HOST}:28015"

# MCloud Selenim Grid settings:
export HUB_HOST=${STF_MASTER_HOST}
export HUB_PORT=4446

# MCloud iOS STF node host settings
export STF_NODE_HOST=192.168.88.96

export APPIUM_HOME=/usr/local/lib/node_modules/appium
export AUTOMATION_NAME=XCUITest

export WEBSOCKET_PROTOCOL=ws
export WEB_PROTOCOL=http

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

