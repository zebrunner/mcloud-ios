Zebrunner Device Farm (iOS slave)
==================

Feel free to support the development with a [**donation**](https://www.paypal.com/donate?hosted_button_id=JLQ4U468TWQPS) for the next improvements.

<p align="center">
  <a href="https://zebrunner.com/"><img alt="Zebrunner" src="https://github.com/zebrunner/zebrunner/raw/master/docs/img/zebrunner_intro.png"></a>
</p>

## Software prerequisites
* Install XCode 11.2+
* Install [nvm](https://github.com/nvm-sh/nvm) version manager
  > NVM required to organize automatic switch between nodes
* Using NVM install v8.17.0 and the latest Appium compatible node version
  > 8.x node is still required by OpenSTF!
* Make the latest node as default one, for example:
  `nvm alias default 14`
* Install Appium, optionally install opencv module to be able to support [find by image](https://zebrunner.github.io/carina/automation/mobile/#how-to-use-find-by-image-strategy) strategy
* Sign WebDriverAgent using your Dev Apple certificate and install WebDriverAgent on each device manually
  * Open in XCode <i>APPIUM_HOME</i>/node_modules/appium-webdriveragent/WebDriverAgent.xcodeproj
  * Choose WebDriverAgentRunner and your device(s)
  * Choose your dev certificate
  * `Product -> Test`. When WDA installed and started successfully `Product -> Stop`
* Install ffmpeg for video recording capabilities
  `brew install ffmpeg`
* Install zeromq
  `brew install zeromq`
* Install jq
  `brew install jq`
* Install cmake to be able to compile jpeg-turbo: https://cmake.org/install
* Download go ios utility [go-ios-mac.zip](https://github.com/danielpaulus/go-ios/releases/latest/download/go-ios-mac.zip) and put into `/usr/local/bin`

## iOS-slave setup
* Clone mcloud-ios repo
```
git clone --single-branch --branch master https://github.com/zebrunner/mcloud-ios.git
cd mcloud-ios
```

* Update devices.txt registering all whitelisted devices and simulators
```
# DEVICE NAME    | UDID                                     |APPIUM|  WDA  | MJPEG | IWDP  | STF_SCREEN | PROXY_APPIUM
iPhone_7         | 48ert45492kjdfhgj896fea31c175f7ab97cbc19 | 4841 | 20001 | 20002 | 20003 |  7701      |  7702
Phone_X1         | 7643aa9bd1638255f48ca6beac4285cae4f6454g | 4842 | 20011 | 20022 | 20023 |  7711      |  7712
```

  > Specify unique port numbers per each service. Those ports should be accessible from MCloud master host

* Execute setup procedure
```
./zebrunner.sh setup
```

* Provide the required arguments during the setup

* <b>Important!</b> Everytime you create new Simulator(s) via XCode, you have to add a new line into devices.txt to whitelist and run `authorize-simulator` command to authorize
```
./zebrunner.sh authorize-simulator
```
  > It is enough to run `./zebrunner.sh authorize-simulator` command at once after generating multiple simulators

* Setup user [auto-login](https://support.apple.com/en-us/HT201476) for your current user to enable LaunchAgents loading on reboot

### Patch appium to enable video recordings (to be automated in v2.1)
* Clone Zebrunner Appium and patch sources:
  ```
  git clone https://github.com/zebrunner/appium.git
  cd appium
  export APPIUM_HOME=/usr/local/lib/node_modules/appium
  cp -R -v ./files/mcloud/* ${APPIUM_HOME}/node_modules
  ```
* Generate symlinks to shell scripts:
  ```
  ln -s $HOME/tools/appium/files/concat-video-recordings.sh /opt/
  ln -s $HOME/tools/appium/files/reset-logs.sh /opt/
  ln -s $HOME/tools/appium/files/start-capture-artifacts.sh /opt/
  ln -s $HOME/tools/appium/files/stop-capture-artifacts.sh /opt/
  ln -s $HOME/tools/appium/files/upload-artifacts.sh /opt/
  ```
* Install aws cli: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
* Configure aws using your s3 access and secret keys, region etc
  ```
  aws configure
  ```
* Restart services using `./zebrunner.sh restart`

## Documentation and free support
* [Zebrunner PRO](https://zebrunner.com)
* [Zebrunner CE](https://zebrunner.github.io/community-edition)
* [Zebrunner Reporting](https://zebrunner.com/documentation)
* [Carina Guide](http://zebrunner.github.io/carina)
* [Demo Project](https://github.com/zebrunner/carina-demo)
* [Telegram Channel](https://t.me/zebrunner)

## License
Code - [Apache Software License v2.0](http://www.apache.org/licenses/LICENSE-2.0)

Documentation and Site - [Creative Commons Attribution 4.0 International License](http://creativecommons.org/licenses/by/4.0/deed.en_US)
