#!/bin/bash

devicePattern=$1
#echo devicePattern: $devicePattern

BASEDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

. ${BASEDIR}/configs/getDeviceArgs.sh $devicePattern

verifyStartup() {

  ## FUNCTION:     verifyStartup
  ## DESCRITION:   verify if WDA component started per device/simolator
  ## PARAMETERS:
  ##         $1 - Path to log file for startup verification
  ##         $2 - String to find in startup log (startup indicator)
  ##         $3 - Counter. (Startup verification max duration) = (Counter) x (10 seconds)

  STARTUP_LOG=$1
  STARTUP_COUNTER=$2

  STARTUP_INDICATOR="ServerURLHere->"
  FAIL_INDICATOR=" TEST FAILED "
  UNSUPPORTED_INDICATOR="Unable to find a destination matching the provided destination specifier"


  COUNTER=0
  while [  $COUNTER -lt $STARTUP_COUNTER ];
  do
    sleep 1
    if [[ -r ${STARTUP_LOG} ]]
    then
      # verify that WDA is supported for device/simulator
      grep "${UNSUPPORTED_INDICATOR}" ${STARTUP_LOG} > /dev/null
      if [[ $? = 0 ]]
      then
        echo "ERROR! WDA does not support ${name}!"
        return -1
      fi

      # verify that WDA failed
      grep "${FAIL_INDICATOR}" ${STARTUP_LOG} > /dev/null
      if [[ $? = 0 ]]
      then
        echo "ERROR! WDA failed on ${name} in ${COUNTER} seconds!"
        return -1
      fi

      grep "${STARTUP_INDICATOR}" ${STARTUP_LOG} > /dev/null
      if [[ $? = 0 ]]
      then
        echo "WDA started successfully on ${name} within ${COUNTER} seconds."
        return 0
      else
        echo "WDA not started yet on ${name}. waiting ${COUNTER} sec..."
      fi

    else
      echo "ERROR! Cannot read from ${STARTUP_LOG}. File has not appeared yet!"
    fi
    let COUNTER=COUNTER+1
  done

  echo "ERROR! WDA not started on ${name} within ${STARTUP_COUNTER} seconds!"
  return -1
}


#backup current wda log to be able to analyze failures if any
if [[ -f ${BASEDIR}/logs/${name}_wda.log ]]; then
  mv ${BASEDIR}/logs/${name}_wda.log ${BASEDIR}/backup/${name}_wda_`date +"%T"`.log
fi

echo Starting WDA: ${name}, udid: ${udid}, wda_port: ${wda_port}, mjpeg_port: ${mjpeg_port}
nohup /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -project ${appium_home}/node_modules/appium-webdriveragent/WebDriverAgent.xcodeproj \
      -derivedDataPath "${BASEDIR}/tmp/DerivedData/${udid}" \
      -scheme WebDriverAgentRunner -destination id=$udid USE_PORT=$wda_port MJPEG_SERVER_PORT=$mjpeg_port test > "${BASEDIR}/logs/${name}_wda.log" 2>&1 &

verifyStartup "${BASEDIR}/logs/${name}_wda.log" 120 >> "${BASEDIR}/logs/${name}_wda.log"
if [[ $? = 0 ]]; then
  # WDA was started successfully!
  # parse ip address from log file line:
  # 2020-07-13 17:15:15.295128+0300 WebDriverAgentRunner-Runner[5660:22940482] ServerURLHere->http://192.168.88.127:20001<-ServerURLHere

  ip=`grep "ServerURLHere->" "${BASEDIR}/logs/${name}_wda.log" | cut -d ':' -f 5`
  # remove forward slashes
  ip="${ip//\//}"
  # put IP address into the metadata file
  echo "${ip}" > ${metaDataFolder}/ip_${udid}.txt

else 
  # WDA is not started successfully!
  rm -f ${metaDataFolder}/ip_${udid}.txt
fi


