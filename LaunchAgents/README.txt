Follow below steps to setup automatic services startup/shutdown for connected and disconnected devices

1. Update each plist script in LaunchAgents folder using 
- actual path for "WorkingDirectory" property
- actual user name for "UserName" property
- actual group name for "GroupName" property

2. Copy all launch agent plist scripts into the $HOME/Library/LaunchAgents
 - syncAppium.plist
 - syncDevices.plist
 - syncSTF.plist
 - syncWDA.plist

3. Load scripts one by one:
launchctl load ~/Library/LaunchAgents/syncDevices.plist
launchctl load ~/Library/LaunchAgents/syncWDA.plist
launchctl load ~/Library/LaunchAgents/syncAppium.plist
launchctl load ~/Library/LaunchAgents/syncSTF.plist

Note: It is recommended to load in appropriate order as above

4. You can analyze agents logs using:
tail -f ./logs/agents.log

