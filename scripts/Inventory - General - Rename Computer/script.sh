#!/bin/bash

##################################################################################################################
# This script is intended to rename a computer locally and then will update the name of the computer in Jamf Pro
# to reflect that new name, specifically a defined prefix in variable $4 followed by the serial number
#
# Update the varible for the Prefix in the policy or in the script here to your defined prefix
##################################################################################################################
#
# Created by Robert Schroeder @ Jamf
# Version 1.0 - 6.08.2021
#
##################################################################################################################
#
##################################################################################################################
# Set Variables
##################################################################################################################
prefix=$4

oldcomputername=`scutil --get ComputerName`
##################################################################################################################
# Get serial number of machine
##################################################################################################################
serial1=`ioreg -l | awk '/IOPlatformSerialNumber/ { print $4;}'`

serial=`sed -e 's/^"//' -e 's/"$//' <<<"$serial1"`
##################################################################################################################
# Generate the new name for the computer
##################################################################################################################
computerName=$prefix-$serial
##################################################################################################################
# Set the computer name locally
##################################################################################################################
scutil --set ComputerName $computerName

scutil --set HostName $computerName

scutil --set LocalHostName $computerName
##################################################################################################################
# Set the computer name in Jamf to reflect what is set locally on the computer
##################################################################################################################
/usr/local/bin/jamf setComputerName -name $computerName
/usr/local/bin/jamf recon

echo "Computer name has been changed from $oldcomputername to $computerName"

exit 0