#!/bin/sh

#Jamf Connect 2.0 Location
 jamfConnectLocation="/Applications/Jamf Connect.app"
 
 jamfConnectVersion=$(defaults read "$jamfConnectLocation"/Contents/Info.plist "CFBundleShortVersionString" || echo "Does not exist")
echo "jamfConnectVersion"
echo "<result>$jamfConnectVersion</result>"