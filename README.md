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

## Health monitor and auto-reboot

Long regression runs on a host with several simulators, Appium servers, Docker
containers and native screen recording gradually exhaust RAM/swap until the host
becomes unresponsive and drops off the grid/STF. A background health monitor
(`health-monitor.sh`, installed as the `ZebrunnerHealthMonitor` LaunchAgent
during `./zebrunner.sh setup`) prevents this:

1. It samples memory/swap pressure on an interval.
2. When the host stays unhealthy for several samples it enters **drain** mode:
   new sessions are blocked (idle Appium nodes are killed so the grid stops
   routing to them) while sessions already in progress are allowed to finish.
3. Once there are no active sessions **and** all screen recording/transcoding is
   done, it reboots the host. After reboot every service auto-starts via the
   existing LaunchAgents, so a well-timed reboot restores a clean environment.

The drain flag is boot-time-aware, so a flag left over from before the reboot is
automatically ignored and services are never blocked from starting afterwards.

Configuration (in `.env`):

| Variable | Default | Meaning |
| --- | --- | --- |
| `HEALTH_ENABLED` | `true` | Master switch for the monitor |
| `HEALTH_CHECK_INTERVAL` | `60` | Seconds between samples |
| `HEALTH_MIN_UPTIME_MIN` | `30` | Grace period after boot before it may act |
| `HEALTH_UNHEALTHY_STREAK` | `3` | Consecutive unhealthy samples before draining |
| `HEALTH_SWAP_USED_MAX_MB` | `6144` | Swap used ≥ this ⇒ unhealthy (`0` disables) |
| `HEALTH_MEM_FREE_MIN_PCT` | `8` | Available RAM ≤ this % ⇒ unhealthy (`0` disables) |
| `HEALTH_DRAIN_TIMEOUT` | `1800` | Force reboot after draining this long (stuck session safety valve) |
| `HEALTH_REBOOT_CMD` | `/usr/bin/touch ${BASEDIR}/metaData/.reboot-request` | How the monitor triggers a reboot |

Reboot without sudo (recommended):

The monitor runs as a user LaunchAgent and does **not** perform the reboot
itself — it only writes a reboot-request flag once the host is drained. A
separate root job (`scheduled-reboot.sh`, invoked from a root crontab or
LaunchDaemon every minute) consumes that flag and runs `/sbin/shutdown -r now`
as root. Because that job is already privileged, no passwordless sudo is needed
for the agent. `scheduled-reboot.sh` also keeps a nightly maintenance reboot as a
time-based safety net.

* Install `scheduled-reboot.sh` in your existing root scheduler, e.g. root crontab:

  ```
  * * * * * /path/to/mcloud-ios/scheduled-reboot.sh >/dev/null 2>&1
  ```

Prerequisites:

* Auto-login must be enabled (see above) so LaunchAgents reload after the reboot.
* The root scheduler running `scheduled-reboot.sh` must be in place (as above).

Alternative (no root job): set `HEALTH_REBOOT_CMD="sudo /sbin/shutdown -r now"`
and grant passwordless sudo for `shutdown` via `/etc/sudoers.d/zebrunner-reboot`
(add with `sudo visudo -f`):

  ```
  <your-user> ALL=(root) NOPASSWD: /sbin/shutdown
  ```

Manual controls / observability:

* `./zebrunner.sh health` — print current memory/swap health and drain state
* `./zebrunner.sh drain` — manually drain and reboot once the host is idle
* `./zebrunner.sh undrain` — cancel a pending drain
* Monitor activity is logged to `logs/health-monitor.log`

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
