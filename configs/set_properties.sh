#!/bin/bash

BASEDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )/../" && pwd )

# STF master host settings
export STF_MASTER_HOST=stage.qaprosoft.com
# iSTF node address (it should be private ip address accessible from STF master host)
export STF_NODE_HOST=192.168.88.96

export RETHINKDB_PORT_28015_TCP="tcp://${STF_MASTER_HOST}:28015"

export WEBSOCKET_PROTOCOL=ws
export WEB_PROTOCOL=http

# Zebrunner Device Farm Selenim hub settings: https://github.com/zebrunner/mcloud-grid
export HUB_HOST=stage.qaprosoft.com
export HUB_PORT=4446

export APPIUM_HOME=/usr/local/lib/node_modules/appium

export automation_name=XCUITest

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

