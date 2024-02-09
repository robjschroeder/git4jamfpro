#!/bin/bash


mgtAdmin="jamfadmin"

jamfAdminToken=$(sysadminctl -secureTokenStatus $mgtAdmin 2>&1 | awk '{print$7}')


if [[ $jamfAdminToken == ENABLED ]]; then
	echo "Admin has a token"
 	result="YES"

else
	result="NO"

fi

echo "<result>$result</result>"