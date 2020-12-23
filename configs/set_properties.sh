#!/bin/bash

BASEDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )/../" && pwd )
. ${BASEDIR}/.env

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

