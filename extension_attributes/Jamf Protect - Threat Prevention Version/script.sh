#!/bin/sh

#Jamf Protect Location
jamfProtectBinaryLocation="/usr/local/bin/protectctl"

if [ -f "$jamfProtectBinaryLocation" ]; then
    plist=$($jamfProtectBinaryLocation info --plist)
    jamfProtectThreatPreventionVersion=$(/usr/libexec/PlistBuddy -c "Print Monitors:execAuth:stats:signatureFeed:version" /dev/stdin <<<"$plist")
else
	jamfProtectThreatPreventionVersion="Protect binary not found"
fi

echo "<result>$jamfProtectThreatPreventionVersion</result>"