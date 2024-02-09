#!/bin/sh
# Adding some comments here as a test to see if this gets pushed
topicID=`/usr/sbin/system_profiler SPConfigurationProfileDataType | awk '/Topic/{ print $NF }' | sed 's/[";]//g'`

if [ $topicID == "" ]; then
	echo "<result>No Push Cert</result>"
else
	echo "<result>$topicID</result>"
fi