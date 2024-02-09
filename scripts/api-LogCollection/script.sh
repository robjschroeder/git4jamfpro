#!/bin/bash

# Retrieve sysdiagnose and jamf log from local computer
# then upload to Jamf Pro in the computer's inventory record
#
# Created: 4.29.2022 @ Robjschroeder

# User Variables, parameters set in Jamf Pro
jamfProAPIUsername="$4"
jamfProAPIPassword="$5"
jamfProURL=$(defaults read /Library/Preferences/com.jamfsoftware.jamf.plist jss_url | sed s'/.$//')

## System Variables
mySerial=$( system_profiler SPHardwareDataType | grep Serial |  awk '{print $NF}' )
currentUser=$( stat -f%Su /dev/console )
compHostName=$( scutil --get LocalHostName )
timeStamp=$( date '+%Y-%m-%d-%H-%M-%S' )
osMajor=$(/usr/bin/sw_vers -productVersion | awk -F . '{print $1}')
osMinor=$(/usr/bin/sw_vers -productVersion | awk -F . '{print $2}')

## Create Sysdiagnose

# Cleanup - Remove all sysdiagnose files found in /private/var/tmp before running main script.
/bin/rm -rf /private/var/tmp/sysdiagnose*

#Run the sysdiagnose in the background without user interaction
/usr/bin/sysdiagnose -u &

#Wait until the sysdiagnose file is located in /private/var/tmp before continuing with the script

until [ -f /private/var/tmp/sysdiagnose* ]
do
	sleep 5
done
echo "Sysdiagnose file found. Uploading the sysdiagnose file to the Jamf Pro Server....."

# Get the name of the sysdiagnose file
sysdiagnoseFile=$(/bin/ls /private/var/tmp | grep sysdiagnose)

# Create Zip file with Sysdiagnose and Jamf Log
fileName=$compHostName-$currentUser-$timeStamp.zip
zip /private/tmp/$fileName /private/var/tmp/$sysdiagnoseFile /var/log/jamf.log

# Generate A Bearer Token for Jamf Pro API
# Encode Credentials
encodedCredentials=$( printf "${jamfProAPIUsername}:${jamfProAPIPassword}" | /usr/bin/iconv -t ISO-8859-1 | /usr/bin/base64 -i - )
# Generate an auth token
authToken=$( /usr/bin/curl ${jamfProURL}/uapi/auth/tokens \
		--silent \
		--request POST \
		--header "Authorization: Basic ${encodedCredentials}" 
)
# Parse authToken for token, omit expiration
token=$( /usr/bin/awk -F \" '{ print $4 }' <<< "${authToken}" | /usr/bin/xargs )


## Get Jamf Pro Computer ID
if [[ "$osMajor" -ge 11 ]]; then
	jamfProID=$( curl --request GET \
	--url ${jamfProURL}/JSSResource/computers/serialnumber/$mySerial/subset/general \
	--header 'Accept: application/xml' \
	--header "Authorization: Bearer ${token}" | xpath -e "//computer/general/id/text()" )

elif [[ "$osMajor" -eq 10 && "$osMinor" -gt 12 ]]; then
	jamfProID=$( curl --request GET \
	--silent \
	--url ${jamfProURL}/JSSResource/computers/serialnumber/$mySerial/subset/general \
	--header 'Accept: application/xml' \
	--header "Authorization: Bearer ${token}" | xpath "//computer/general/id/text()" )
fi

# Upload the file
curl --request POST \
	--url ${jamfProURL}/JSSResource/fileuploads/computers/id/$jamfProID \
    --header "Authorization: Bearer ${token}" \
	--form name=@/private/tmp/$fileName

#Check to status of the file upload
uploadStatus=$?

#Use Jamf Helper to display message to user
if [ $uploadStatus != 0 ]; then
	echo "The sysdiagnose file FAILED to upload successfully to your computer record on the Jamf Pro Server.  Please contact the IT Department for assistance."
else
	echo "The sysdiagnose file was uploaded successfully to your computer record on the Jamf Pro Server."
	rm /private/tmp/$fileName
fi

#Use upload exit status to exit the script with 0 for success or 1 for failure.
if [ $uploadStatus != 0 ]; then
	exit 1
else
	exit 0
fi