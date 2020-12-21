#!/bin/bash

BASEDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
. ${BASEDIR}/configs/set_properties.sh


echo Killing WDA processes...
if ps -eaf | grep 'WebDriverAgent' | grep -v grep | grep -v '/stf' | grep -v '/usr/share/maven' ; then
	kill -9 `ps -eaf | grep 'WebDriverAgent' | grep -v grep | grep -v '/stf' | grep -v '/usr/share/maven' | awk '{ print $2 }'`
fi

# explicitly remove all metadata files with detected ip addresses
rm -f ${metaDataFolder}/ip_*.txt

