Zebrunner Device Farm (iOS agent)
==================

Feel free to support the development with a [**donation**](https://www.paypal.com/donate?hosted_button_id=JLQ4U468TWQPS) for the next improvements.

<p align="center">
  <a href="https://zebrunner.com/"><img alt="Zebrunner" src="https://github.com/zebrunner/zebrunner/raw/master/docs/img/zebrunner_intro.png"></a>
</p>

## Software prerequisites
* Install npm 8.3.0 or higher
  `npm install -g npm@8.3.0`
* Install [nvm](https://github.com/nvm-sh/nvm) version manager
  > NVM required to organize automatic switch between nodes
* Using NVM install node v17.1.0 and make it default `nvm alias default 17`
* Install Appium v1.22.3, optionally install opencv module to be able to support [find by image](https://zebrunner.github.io/carina/automation/mobile/#how-to-use-find-by-image-strategy) strategy
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
* Download v1.0.106+ go ios utility [go-ios-mac.zip](https://github.com/danielpaulus/go-ios/releases/download/v1.0.106/go-ios-mac.zip) and put into `/usr/local/bin`

### Patch appium
* Clone Zebrunner Appium and patch sources:
  ```
  git clone https://github.com/zebrunner/appium.git
  cd appium
  export APPIUM_HOME=/usr/local/lib/node_modules/appium
  cp -R -v ./files/mcloud/* ${APPIUM_HOME}/
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

### Prepare WebDriverAgent.ipa file

You need an Apple Developer account to sign in and build **WebDriverAgent**.

1. Open **WebDriverAgent.xcodeproj** in Xcode.
2. Ensure a team is selected before building the application. To do this, go to *Targets* and select each target (one at a time). There should be a field for assigning team certificates to the target.
3. Remove your **WebDriverAgent** folder from *DerivedData* and run *Clean build folder* (just in case).
4. Build the application by selecting the *WebDriverAgentRunner* target and build for *Generic iOS Device*. Run *Product -> Build for testing*. This will create a *Products/Debug-iphoneos* in the specified project directory.  
 *Example*: **/Users/$USER/Library/Developer/Xcode/DerivedData/WebDriverAgent-dzxbpamuepiwamhdbyvyfkbecyer/Build/Products/Debug-iphoneos**
5. Go to the "Products/Debug-iphoneos" directory and run:
 **mkdir Payload**
6. Copy the WebDriverAgentRunner-Runner.app to the Payload directory:
 **cp -r WebDriverAgentRunner-Runner.app Payload**
7. Finally, zip up the project as an *.ipa file:
 **zip -r WebDriverAgent.ipa ./Payload**
   > Make sure to specify relative `./Payload` to archive only Payload folder content
8. Get the WebDriverAgent.ipa file and put it onto the mcloud-ios host

## iOS-agent setup
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

* Reboot physical device and connect to your MacOS server.

* Execute setup procedure
```
./zebrunner.sh setup
```

* Provide the required arguments during the setup

* <b>Important!</b> Everytime you create new Simulator(s) via XCode, you have to add a new line into devices.txt to whitelist and repeat `./zebrunner.sh setup` command to authorize.
  > It is enough to execute setup command at once after generating multiple simulators

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
