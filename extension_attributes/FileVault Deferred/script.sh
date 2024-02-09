#!/bin/bash

fdesetupStatus=$(fdesetup status)

if [[ $fdesetupStatus == *"Deferred enablement appears to be active"* ]]; then
	echo "Deferred enablement active"
 	result="YES"

else
	echo "Deferred enablement not active"
	result="NO"

fi

echo "<result>$result</result>"