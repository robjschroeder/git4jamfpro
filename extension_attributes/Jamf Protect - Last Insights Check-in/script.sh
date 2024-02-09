#!/bin/sh

#Jamf Protect Location
jamfProtectBinaryLocation="/usr/local/bin/protectctl"

if [ -f "$jamfProtectBinaryLocation" ]; then
	plist=$($jamfProtectBinaryLocation info --plist)
	xpath="/plist/dict/date[preceding-sibling::key='LastInsightsSync'][1]/text()"
    rawInsightsSync=$(/bin/echo $plist | /usr/bin/xpath -e "${xpath}" 2>/dev/null)
    jamfProtectInfoInsightsSync=$(/bin/date -j -f "%Y-%m-%dT%H:%M:%SZ" "$rawInsightsSync" "+%Y-%m-%d %H:%M:%S")
else
	jamfProtectInfoInsightsSync="Protect binary not found"
fi

echo "<result>$jamfProtectInfoInsightsSync</result>"