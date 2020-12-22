#!/bin/bash

  print_banner() {
  echo "
███████╗███████╗██████╗ ██████╗ ██╗   ██╗███╗   ██╗███╗   ██╗███████╗██████╗      ██████╗███████╗
╚══███╔╝██╔════╝██╔══██╗██╔══██╗██║   ██║████╗  ██║████╗  ██║██╔════╝██╔══██╗    ██╔════╝██╔════╝
  ███╔╝ █████╗  ██████╔╝██████╔╝██║   ██║██╔██╗ ██║██╔██╗ ██║█████╗  ██████╔╝    ██║     █████╗
 ███╔╝  ██╔══╝  ██╔══██╗██╔══██╗██║   ██║██║╚██╗██║██║╚██╗██║██╔══╝  ██╔══██╗    ██║     ██╔══╝
███████╗███████╗██████╔╝██║  ██║╚██████╔╝██║ ╚████║██║ ╚████║███████╗██║  ██║    ╚██████╗███████╗
╚══════╝╚══════╝╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═══╝╚═╝  ╚═══╝╚══════╝╚═╝  ╚═╝     ╚═════╝╚══════╝
"

  }

  setup() {
    print_banner

    # load ./backup/settings.env if exist to declare ZBR* vars from previous run!
    if [[ -f backup/settings.env ]]; then
      source backup/settings.env
    fi

    export ZBR_MCLOUD_IOS_VERSION=1.0
    echo TODO: implement configuration steps

    export ZBR_MCLOUD_IOS_AGENT=1
    # export all ZBR* variables to save user input
    export_settings
  }

  shutdown() {
    if [ ! -f backup/settings.env ]; then
      echo_warning "You have to setup MCloud iOS slave in advance using: ./zebrunner.sh setup"
      echo_telegram
      exit -1
    fi

    echo_warning "Shutdown will erase all settings and data for \"${BASEDIR}\"!"
    confirm "" "      Do you want to continue?" "n"
    if [[ $? -eq 0 ]]; then
      exit
    fi

    print_banner

    # unload LaunchAgents scripts
    launchctl unload $HOME/Library/LaunchAgents/syncWDA.plist
    launchctl unload $HOME/Library/LaunchAgents/syncSTF.plist
    launchctl unload $HOME/Library/LaunchAgents/syncAppium.plist
    launchctl unload $HOME/Library/LaunchAgents/syncDevices.plist

    # Stop existing services: WebDriverAgent, SmartTestFarm and Appium
    stop

    # remove configuration files and LaunchAgents plist(s)
    rm -f devices.txt

    rm -f $HOME/Library/LaunchAgents/syncWDA.plist
    rm -f $HOME/Library/LaunchAgents/syncSTF.plist
    rm -f $HOME/Library/LaunchAgents/syncAppium.plist
    rm -f $HOME/Library/LaunchAgents/syncDevices.plist
  }

  start() {
    if [ ! -f backup/settings.env ]; then
      echo_warning "You have to setup services in advance using: ./zebrunner.sh setup"
      echo_telegram
      exit -1
    fi

    print_banner

    #-------------- START EVERYTHING ------------------------------
    if [[ $ZBR_MCLOUD_IOS_AGENT -eq 1 ]]; then
      # load LaunchAgents scripts
      echo HOME: $HOME
      ls -la $HOME/Library/LaunchAgents/syncDevices.plist
      launchctl load $HOME/Library/LaunchAgents/syncDevices.plist
      launchctl load $HOME/Library/LaunchAgents/syncWDA.plist
      launchctl load $HOME/Library/LaunchAgents/syncSTF.plist
      launchctl load $HOME/Library/LaunchAgents/syncAppium.plist
    else
      echo TODO: implement just start by services
    fi
  }

  stop() {
    if [ ! -f backup/settings.env ]; then
      echo_warning "You have to setup services in advance using: ./zebrunner.sh setup"
      echo_telegram
      exit -1
    fi

    stop-wda
    stop-stf
    stop-appium

  }

  stop-wda() {
    if [ ! -f backup/settings.env ]; then
      echo_warning "You have to setup services in advance using: ./zebrunner.sh setup"
      echo_telegram
      exit -1
    fi

    udid=$1
    #echo udid: $udid
    if [ "$udid" != "" ]; then
      export pids=`ps -eaf | grep ${udid} | grep xcodebuild | grep 'WebDriverAgent' | grep -v grep | grep -v stop-wda | awk '{ print $2 }'`
      rm -f ${metaDataFolder}/ip_${udid}.txt
    else
      export pids=`ps -eaf | grep xcodebuild | grep 'WebDriverAgent' | grep -v grep | grep -v stop-wda | awk '{ print $2 }'`
    fi
    #echo pids: $pids

    kill_processes $pids
  }

  stop-stf() {
    if [ ! -f backup/settings.env ]; then
      echo_warning "You have to setup services in advance using: ./zebrunner.sh setup"
      echo_telegram
      exit -1
    fi

    udid=$1
    #echo udid: $udid
    if [ "$udid" != "" ]; then
      export pids=`ps -eaf | grep ${udid} | grep 'ios-device' | grep 'stf' | grep -v grep | grep -v stop-stf | awk '{ print $2 }'`
    else
      export pids=`ps -eaf | grep 'ios-device' | grep 'stf' | grep -v grep | grep -v stop-stf | awk '{ print $2 }'`
    fi
    #echo pids: $pids

    kill_processes $pids
  }

  stop-appium() {
    if [ ! -f backup/settings.env ]; then
      echo_warning "You have to setup services in advance using: ./zebrunner.sh setup"
      echo_telegram
      exit -1
    fi

    udid=$1
    #echo udid: $udid
    if [ "$udid" != "" ]; then
      export pids=`ps -eaf | grep ${udid} | grep 'appium' | grep -v grep | grep -v stop-appium | grep -v '/stf' | grep -v '/usr/share/maven' | grep -v 'WebDriverAgent' | awk '{ print $2 }'`
    else 
      export pids=`ps -eaf | grep 'appium' | grep -v grep | grep -v stop-appium | grep -v '/stf' | grep -v '/usr/share/maven' | grep -v 'WebDriverAgent' | awk '{ print $2 }'`
    fi
    #echo pids: $pids

    kill_processes $pids
  }


  restart() {
    if [ ! -f backup/settings.env ]; then
      echo_warning "You have to setup services in advance using: ./zebrunner.sh setup"
      echo_telegram
      exit -1
    fi

    down
    start
  }

  down() {
    if [ ! -f backup/settings.env ]; then
      echo_warning "You have to setup services in advance using: ./zebrunner.sh setup"
      echo_telegram
      exit -1
    fi

    # unload LaunchAgents scripts
    launchctl unload $HOME/Library/LaunchAgents/syncWDA.plist
    launchctl unload $HOME/Library/LaunchAgents/syncSTF.plist
    launchctl unload $HOME/Library/LaunchAgents/syncAppium.plist
    launchctl unload $HOME/Library/LaunchAgents/syncDevices.plist

    stop
  }

  backup() {
    if [ ! -f backup/settings.env ]; then
      echo_warning "You have to setup services in advance using: ./zebrunner.sh setup"
      echo_telegram
      exit -1
    fi

#    confirm "" "      Your services will be stopped. Do you want to do a backup now?" "n"
#    if [[ $? -eq 0 ]]; then
#      exit
#    fi

    print_banner

    cp devices.txt ./backup/devices.txt
    cp $HOME/Library/LaunchAgents/syncWDA.plist ./backup/syncWDA.plist
    cp $HOME/Library/LaunchAgents/syncSTF.plist ./backup/syncSTF.plist
    cp $HOME/Library/LaunchAgents/syncAppium.plist ./backup/syncAppium.plist
    cp $HOME/Library/LaunchAgents/syncDevices.plist ./backup/syncDevices.plist

    echo "Backup for Device Farm iOS slave was successfully finished."

#    echo_warning "Your services needs to be started after backup."
#    confirm "" "      Start now?" "y"
#    if [[ $? -eq 1 ]]; then
#      start
#    fi

  }

  restore() {
    if [ ! -f backup/settings.env ]; then
      echo_warning "You have to setup services in advance using: ./zebrunner.sh setup"
      echo_telegram
      exit -1
    fi

    confirm "" "      Your services will be stopped and current data might be lost. Do you want to do a restore now?" "n"
    if [[ $? -eq 0 ]]; then
      exit
    fi

    print_banner
    down
    cp ./backup/devices.txt devices.txt
    cp ./backup/syncWDA.plist $HOME/Library/LaunchAgents/syncWDA.plist
    cp ./backup/syncSTF.plist $HOME/Library/LaunchAgents/syncSTF.plist
    cp ./backup/syncAppium.plist $HOME/Library/LaunchAgents/syncAppium.plist
    cp ./backup/syncDevices.plist $HOME/Library/LaunchAgents/syncDevices.plist

    echo_warning "Your services needs to be started after restore."
    confirm "" "      Start now?" "y"
    if [[ $? -eq 1 ]]; then
      start
    fi

  }

  version() {
    if [ ! -f backup/settings.env ]; then
      echo_warning "You have to setup services in advance using: ./zebrunner.sh setup"
      echo_telegram
      exit -1
    fi

    source backup/settings.env

    echo "MCloud Device Farm: ${ZBR_MCLOUD_IOS_VERSION}"
  }

  export_settings() {
    export -p | grep "ZBR" > backup/settings.env
  }

  confirm() {
    local message=$1
    local question=$2
    local isEnabled=$3

    if [[ "$isEnabled" == "1" ]]; then
      isEnabled="y"
    fi
    if [[ "$isEnabled" == "0" ]]; then
      isEnabled="n"
    fi

    while true; do
      if [[ ! -z $message ]]; then
        echo "$message"
      fi

      read -p "$question y/n [$isEnabled]:" response
      if [[ -z $response ]]; then
        if [[ "$isEnabled" == "y" ]]; then
          return 1
        fi
        if [[ "$isEnabled" == "n" ]]; then
          return 0
        fi
      fi

      if [[ "$response" == "y" || "$response" == "Y" ]]; then
        return 1
      fi

      if [[ "$response" == "n" ||  "$response" == "N" ]]; then
        return 0
      fi

      echo "Please answer y (yes) or n (no)."
      echo
    done
  }

  kill_processes()
  {
    processes_pids=$*
    if [ "${processes_pids}" != "" ]; then
     echo processes_pids to kill: $processes_pids
     kill -9 $processes_pids
    fi
  }

  echo_warning() {
    echo "
      WARNING! $1"
  }

  echo_telegram() {
    echo "
      For more help join telegram channel: https://t.me/zebrunner
      "
  }

  echo_help() {
    echo "
      Usage: ./zebrunner.sh [option]
      Flags:
          --help | -h    Print help
      Arguments:
          setup              Setup Device Farm iOS slave
          start              Start Device Farm iOS slave services
          stop               Stop Device Farm iOS slave services
          stop-appium [udid] Stop Appium services [all or for exact device by udid]
          stop-stf [udid]    Stop STF services [all or for exact device by udid]
          stop-wda [udid]    Stop WebDriverAgent services [all or for exact device by udid]
          restart            Restart Device Farm iOS slave services
          down               Stop Device Farm iOS slave services and disable LaunchAgent services
          shutdown           Destroy Device Farm iOS slave completely
          backup             Backup Device Farm iOS slave services
          restore            Restore Device Farm iOS slave services
          version            Version of Device Farm iOS slave"
      echo_telegram
      exit 0
  }

BASEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd ${BASEDIR}

if [[ -f backup/settings.env ]]; then
  source backup/settings.env
fi

. configs/set_properties.sh


case "$1" in
    setup)
        setup
        ;;
    start)
        start
        ;;
    stop)
        stop
        ;;
    stop-appium)
        stop-appium $2
        ;;
    stop-stf)
        stop-stf $2
        ;;
    stop-wda)
        stop-wda $2
        ;;
    restart)
        restart
        ;;
    down)
        down
        ;;
    shutdown)
        shutdown
        ;;
    backup)
        backup
        ;;
    restore)
        restore
        ;;
    version)
        version
        ;;
    *)
        echo "Invalid option detected: $1"
        echo_help
        exit 1
        ;;
esac

