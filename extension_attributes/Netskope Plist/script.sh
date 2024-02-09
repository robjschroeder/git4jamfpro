#!/bin/bash

if [ -f "/Library/Managed Preferences/com.netskope.client.Netskope.plist" ]; then
	echo "<result>Yes</result>"
else
    echo "<result>No</result>"
fi
    