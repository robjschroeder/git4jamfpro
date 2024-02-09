#!/usr/bin/env bash

#Jamf Protect Install Type
jamfProtectBinaryLocation="/usr/local/bin/protectctl"

if [ -f "$jamfProtectBinaryLocation" ]; then
	jamfProtectInstallType=$(sudo "$jamfProtectBinaryLocation" info | awk -F 'Install Type: ' '{print $2}' | xargs)
else
	jamfProtectInstallType="Protect binary not found"
fi

echo "<result>$jamfProtectInstallType</result>"