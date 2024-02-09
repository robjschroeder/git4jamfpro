#!/bin/bash

# Script to prompt user to rename computer

currCompName=$(scutil --get ComputerName)

newCompName=$(osascript << EOF
	text returned of (display dialog "Current computer name: $currCompName\n\nEnter the new name of your computer for Active Directory/n/nNote: Less than 15 characters" default answer "ComputerName" buttons {"OK"} default button 1)
EOF)

echo "User entered: $newCompName"

# Set new computer name locally
scutil --set ComputerName "$newCompName"
#
scutil --set HostName "$newCompName"
#
scutil --set LocalHostName "$newCompName"

exit 0