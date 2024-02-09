#!/bin/sh

#Define Variables
user=`ls -l /dev/console | cut -d " " -f4`
plist=com.apple.menuextra.clock
loc=/Users/$user/Library/Preferences


#Make change to plist ran as logged in user

echo "Running script as $user"
su "$user" -c "defaults write $loc/$plist DateFormat 'EEE d MMM hh:mm:ss'"
echo "Reading plist $plist"
echo `defaults read $loc/$plist DateFormat`

#Kill SystemUIServer

su "$user" -c "killall -KILL SystemUIServer"

exit 0