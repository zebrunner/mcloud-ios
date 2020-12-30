Zebrunner Device Farm (iOS slave)
==================

* It is built on the top of [OpenSTF](https://github.com/openstf) with supporting iOS devices remote control.

## Contents
* [Software prerequisites](#software-prerequisites)
* [iSTF components setup](#istf-components-setup)
* [iOS-slave setup](#ios-slave-setup)
* [Setup sync scripts via Launch Agents for Appium, WDA and STF services](#setup-sync-scripts-via-launch-agents-for-appium-wda-and-stf-services)
* [License](#license)

## Software prerequisites
* Install XCode 11.2+
* Install [nvm](https://github.com/nvm-sh/nvm) version manager
  > NVM required to organize automatic switch between nodes
* Using NVM install v8.17.0 and latest Appium compatible node version
  > 8.x node is still required by OpenSTF!
* Sign WebDriverAgent using your Dev Apple certificate and install WebDriverAgent on each device manually
  * Open in XCode <i>APPIUM_HOME</i>/node_modules/appium-webdriveragent/WebDriverAgent.xcodeproj
  * Choose WebDriverAgentRunner and your device(s)
  * Choose your dev certificate
  * `Product -> Test`. When WDA installed and started successfully `Product -> Stop`

## iOS-slave setup
* Clone mcloud-ios repo
```
git clone --single-branch --branch master https://github.com/zebrunner/mcloud-ios.git
cd mcloud-ios
```

* Update devices.txt registering all whitelisted devices and simulators
```
# DEVICE NAME    | TYPE      | VERSION| UDID                                     |APPIUM|  WDA  | MJPEG | IWDP  | STF_SCREEN | PROXY_APPIUM
iPhone_7         | phone     | 12.3.1 | 48ert45492kjdfhgj896fea31c175f7ab97cbc19 | 4841 | 20001 | 20002 | 20003 |  7701      |  7702
Phone_X1         | phone     | 12.3.1 | 7643aa9bd1638255f48ca6beac4285cae4f6454g | 4842 | 20011 | 20022 | 20023 |  7711      |  7712
```

  > Specify unique port numbers per each service. Those ports should be accessible from MCloud master host

* Execute setup procedure
```
./zebrunner.sh setup
```

* Provide required arguments during setup

* <b>Important!</b> Everytime you create new Simulator(s) via XCode you have to run `authorize-simulator` command to authorize it and add new line into devices.txt to whitelist
```
./zebrunner.sh authorize-simulator
```
  > it is enough to run `./zebrunner.sh authorize-simulator` command at once after generating multiply simulators

## License
Code - [Apache Software License v2.0](http://www.apache.org/licenses/LICENSE-2.0)

Documentation and Site - [Creative Commons Attribution 4.0 International License](http://creativecommons.org/licenses/by/4.0/deed.en_US)
