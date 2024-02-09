#!/bin/sh

username="admin"
newPassword="jamf1234"
oldPassword="_This1sTh3W4y_"


/usr/bin/dscl . passwd /Users/$username "$oldPassword" "$newPassword"

status=$?



if [ $status == 0 ]; then

echo "Password was changed successfully."

elif [ $status != 0 ]; then

echo "An error was encountered while attempting to change the password. /usr/bin/dscl exited $status."

fi



exit $status
