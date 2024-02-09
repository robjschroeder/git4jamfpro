#!/bin/bash

computer_name=$(scutil --get ComputerName)
serial_number=$(ioreg -rd1 -c IOPlatformExpertDevice | awk -F'"' '/IOPlatformSerialNumber/{print $4}')

if [ "$computer_name" == "$serial_number" ]; then
	result="True"
else
	result="False"
fi

echo "<result>$result</result>"