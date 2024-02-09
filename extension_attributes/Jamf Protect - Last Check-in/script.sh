#!/bin/sh

#Jamf Protect Location
jamfProtectBinaryLocation="/usr/local/bin/protectctl"

if [ -f "$jamfProtectBinaryLocation" ]; then
    plist=$($jamfProtectBinaryLocation info --plist)
    xpath="/plist/dict/date[preceding-sibling::key='LastCheckin'][1]/text()"
    rawLastCheckin=$(/bin/echo $plist | /usr/bin/xpath -e "${xpath}" 2>/dev/null)
    jamfProtectLastCheckin=$(/bin/date -j -f "%Y-%m-%dT%H:%M:%SZ" "$rawLastCheckin" "+%Y-%m-%d %H:%M:%S")
else
	jamfProtectLastCheckin="Protect binary not found"
fi

echo "<result>$jamfProtectLastCheckin</result>"