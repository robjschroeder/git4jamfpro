#!/usr/bin/env bash

################# Load Script variables in Memory ####################

## Power Check Variables

POWERSTATUS=$(pmset -g ps | awk -F "'" '{print $2}' |  sed '/^$/d')
AC="AC Power"

## Show power status before proceeding
echo $POWERSTATUS

## Battery Power Level
BATTERY_LEVEL=$(pmset -g batt | awk '{print $3}' | tr -sc '[:digit:]' '[ *]')
BATTERY_LEVEL_PERCENTAGE=15

#################### Script Logic ####################################


if [[ "$POWERSTATUS" = "$AC" || "$BATTERY_LEVEL" -ge "$BATTERY_LEVEL_PERCENTAGE" ]]; then
	 
        ## The system is plugged into AC Power or Battery percentage is greater than 15%
        echo "The system power check PASSED and the upgrade will proceed now..."
       
	    ## Download all updates in the background
        /usr/sbin/softwareupdate --download --all --background
        echo "all updates have been downloaded"
         
        ## Alert Users of system updates applying wthin 20 mins
        echo "sending notice to save and close work"
        /usr/local/bin/jamf policy -event system-updates-notice-20-mins
        #sleep 1200

        ## Apply System Updates and Reboot
        echo "The updates will be installed, and the system will be rebooted as a result"
        echo "${POWERSTATUS}"
        echo "${BATTERY_LEVEL}"
        softwareupdate -i -a
        
        ## reboot system after two minutes
        sleep 10
        echo "Rebooting system now..."
        shutdown -r +1

     exit 0

else 

	echo "This system is not plugged into AC Power and will not attempt to download updates in the background"
	echo "${POWERSTATUS}"
        echo "${BATTERY_LEVEL}"
        echo "Send user notice of missed updates"
        /usr/local/bin/jamf policy -event macos-missed-updates-notification
    
     exit 1
fi