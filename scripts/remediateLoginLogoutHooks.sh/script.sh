#!/bin/bash

irplayBook=/usr/local/irplaybook
mkdir -p $irplayBook
chmod 755 $irplayBook

/usr/bin/tee /usr/local/irplaybook/Script.sh<<"EOF"
#!/bin/bash
set -x
PID=$$
#Remove Jamf Protect Extension Attribute
rm /Library/Application\ Support/JamfProtect/groups/protect-LoginHook
if [ -f /var/tmp/depnotify.log ]; then
rm /var/tmp/depnotify.log
fi
# DEP Notify for Jamf Protect
if [ -f "/Applications/Utilities/DEPNotify.app/Contents/MacOS/DEPNotify" ]; then
/Applications/Utilities/DEPNotify.app/Contents/MacOS/DEPNotify &
else
echo "DEP Notify Not Present.. Exiting"
exit 1;
fi

#Icon
echo "Command: Image: /System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/AlertStopIcon.icns" >> /var/tmp/depnotify.log

#Title
echo "Command: MainTitle: Jamf Protect Remediation" >> /var/tmp/depnotify.log
#Main Text Body
echo "Command: MainText: Jamf Protect has detected malicious activity on this computer.\n\nYou may resume using your Mac once the malicious incident has been isolated.\n\n If this screen remains for longer than five minutes, please call the IT Department using the number on the back of your ID badge." >> /var/tmp/depnotify.log
#Status Message
echo "Status: Remediation in progress..." >> /var/tmp/depnotify.log
echo "Command: DeterminateManualStep" >> /var/tmp/depnotify.log
sleep 4
defaults delete /var/root/Library/Preferences/com.apple.loginwindow LoginHook
defaults delete /var/root/Library/Preferences/com.apple.loginwindow LogoutHook
echo "Status: " >> /var/tmp/depnotify.log
echo "Command: DeterminateManualStep: 1" >> /var/tmp/depnotify.log
#echo "Command: DeterminateManualStep" >> /var/tmp/depnotify.log
# Optional sleeps...
#Completed Title
echo "Command: MainTitle: Remediation Complete" >> /var/tmp/depnotify.log
#Completed Icon
echo "Command: Image: /Library/Application Support/JamfProtect/JamfProtect.app/Contents/Resources/AppIcon.icns" >> /var/tmp/depnotify.log
#Completed Text Body
echo "Command: MainText: The malicious element was isolated. Thank you for your patience.\n\nAs a reminder, your security is of the utmost importance. If you receive any unusual emails or phone calls asking for your username, password, or any other requests, please call the IT Department using the number on the back of your ID badge." >> /var/tmp/depnotify.log
#sleep 5
#echo "Command: DeterminateManualStep" >> /var/tmp/depnotify.log
#echo "Status: " >> /var/tmp/depnotify.log
sleep 3
#echo "Command: ContinueButton: Continue" >> /var/tmp/depnotify.log
echo "Command: Quit: Remediation Complete" >> /var/tmp/depnotify.log
#echo "Command: Quit" >> /var/tmp/depnotify.log
rm /var/tmp/depnotify.log
#Remove Jamf Protect Extension Attribute
#rm /Library/Application\ Support/JamfProtect/groups/*
#Remove DEPNotify.app
pkill DEPNotify
rm -R /Applications/Utilities/DEPNotify.app
#kill $PID
#Remove remediation artifacts
rm /Library/LaunchDaemons/com.jamfsoftware.task.irplaybook.plist
rm "$0"
rm -rf /usr/local/irplaybook
launchctl bootout system/com.jamfsoftware.task.irplaybook
exit 0
EOF

chmod 755 "$irplayBook/Script.sh"

jamf scheduledTask -command "/usr/local/jamf/bin/jamf runScript -script Script.sh -path /usr/local/irplaybook" -name irplaybook -runAtLoad true
exit 0