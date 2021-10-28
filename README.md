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
* Sign WebDriverAgent using your Dev Apple certificate and install WebDriverAgent on each device manually
  * Open in XCode <i>APPIUM_HOME</i>/node_modules/appium-webdriveragent/WebDriverAgent.xcodeproj
  * Choose WebDriverAgentRunner and your device(s)
  * Choose your dev certificate
  * `Product -> Test`. When WDA installed and started successfully `Product -> Stop`
* Install ffmpeg for video recording capabilities
  `brew install ffmpeg`
* Install zeromq
  `brew install zeromq`
* Install cmake to be able to compile jpeg-turbo: https://cmake.org/install

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

* Provide the required arguments during the setup

* <b>Important!</b> Everytime you create new Simulator(s) via XCode, you have to add a new line into devices.txt to whitelist and run `authorize-simulator` command to authorize
```
./zebrunner.sh authorize-simulator
```
  > It is enough to run `./zebrunner.sh authorize-simulator` command at once after generating multiple simulators

* Setup user [auto-login](https://support.apple.com/en-us/HT201476) for your current user to enable LaunchAgents loading on reboot

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
