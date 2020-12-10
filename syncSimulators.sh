#!/bin/bash

# 10-DEC-2020
# To setup automatic services startup for iOS simulators we are going to use xcrun utility
# All registered simulators should be placed into connectedSimulators.txt metadata file.
# Generated metafile could be used by other sync scripts to start/stop services for each iOS simulator

BASEDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
. ${BASEDIR}/configs/set_properties.sh

echo `date +"%T"` Sync Simulators script started

simulatorsFile=${metaDataFolder}/connectedSimulators.txt
# xcrun xctrace list devices - this command can not be used because it returns physical devices as well
xcrun simctl list | grep -v "Unavailable" | grep -v "unavailable" > ${simulatorsFile}

