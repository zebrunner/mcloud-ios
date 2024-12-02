Zebrunner Device Farm (iOS agent)
Temporary solution to start WebDriverAgent on iOS 17+
==================

Feel free to support the development with a [**donation**](https://www.paypal.com/donate?hosted_button_id=JLQ4U468TWQPS) for the next improvements.

<p align="center">
  <a href="https://zebrunner.com/"><img alt="Zebrunner" src="https://github.com/zebrunner/zebrunner/raw/master/docs/img/zebrunner_intro.png"></a>
</p>

## Software prerequisites
* Sign WebDriverAgent using your Dev Apple certificate and install WebDriverAgent on each device manually
  * Open in XCode <i>APPIUM_HOME</i>/node_modules/appium-webdriveragent/WebDriverAgent.xcodeproj
  * Choose WebDriverAgentRunner and your device(s)
  * Choose your dev certificate
  * `Product -> Test`. When WDA installed and started successfully `Product -> Stop`
* Download v1.0.117+ go ios utility [go-ios-mac.zip](https://github.com/danielpaulus/go-ios/releases/download/v1.0.117/go-ios-mac.zip) and put into `/usr/local/bin`
  > Make sure to unblock it as it goes from not identified developer

## iOS-agent setup
* Clone mcloud-ios repo
```
git clone --single-branch --branch ios17 https://github.com/zebrunner/mcloud-ios.git
cd mcloud-ios
```

* Update devices.txt registering all whitelisted devices and simulators
```
# DEVICE NAME    |  UDID                                    | WDA_BUNDLE_ID                               |  WDA_SOURCES_PATH
iPhone_7         | 48ert45492kjdfhgj896fea31c175f7ab97cbc19 | com.facebook.WebDriverAgentRunner.xctrunner | /Users/username/WebDriverAgent-5.11.0
Phone_X1         | 7643aa9bd1638255f48ca6beac4285cae4f6454g | com.facebook.WebDriverAgentRunner.xctrunner | /Users/username/WebDriverAgent-5.11.0
```
  > Specify uvalid bundle id and path to the WebDriverAgent sources

* Execute setup procedure
```
./zebrunner.sh setup
```

* Setup user [auto-login](https://support.apple.com/en-us/HT201476) for your current user to enable LaunchAgents loading on reboot

* Execute `./zebrunner.sh` to see all available actions

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
