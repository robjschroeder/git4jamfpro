#!/bin/bash

# Creates a LaunchDaemon and script to run a Jamf Recon
# at next reboot. (Based on script by @dan-snelson)
#
# Created 08.29.2022 @robjschroeder
﻿
##################################################
# Variables -- edit as needed

scriptVersion="1.0"
plistDomain="$4"
plistLabel="$5"
plistLabel="$plistDomain.$plistLabel"
timestamp=$( /bin/date '+%Y-%m-%d-%H%M%S' )

#
##################################################

echo "Recon at Reboot (${scriptVersion})"

echo "Create the LaunchDaemon ..."

/bin/echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
<plist version=\"1.0\">
    <dict>
        <key>Label</key>
        <string>${plistLabel}</string>
        <key>ProgramArguments</key>
        <array>
            <string>/bin/sh</string>
            <string>/private/var/tmp/reconAtReboot.bash</string>
        </array>
        <key>RunAtLoad</key>
        <true/>
    </dict>
</plist>" > /Library/LaunchDaemons/$plistLabel.plist

echo "Set LaunchDaemon file permissions ..."

/usr/sbin/chown root:wheel /Library/LaunchDaemons/$plistLabel.plist
/bin/chmod 644 /Library/LaunchDaemons/$plistLabel.plist
/bin/chmod +x /Library/LaunchDaemons/$plistLabel.plist

echo "Create reboot script ..."

cat << '==endOfScript==' > /private/var/tmp/reconAtReboot.bash
#!/bin/bash

# Run Jamf Recon at reboot
#
# Created 08.29.2022 @robjschroeder
﻿
##################################################
# Variables -- edit as needed

scriptVersion="1.0"
plistDomain="$4"
plistLabel="$5"
plistLabel="$plistDomain.$plistLabel"
timestamp=$( /bin/date '+%Y-%m-%d-%H%M%S' )
scriptResult=""

#
##################################################
# Functions -- do not edit below here

jssConnectionStatus () {

    scriptResult+="Check for Jamf Pro server connection; "

    unset jssStatus
    jssStatus=$( /usr/local/bin/jamf checkJSSConnection 2>&1 | /usr/bin/tr -d '\n' )

    case "${jssStatus}" in

        *"The JSS is available."        )   jssAvailable="yes" ;;
        *"No such file or directory"    )   jssAvailable="not installed" ;;
        *                               )   jssAvailable="unknown" ;;

    esac

}

echo "Starting Recon at Reboot (${scriptVersion}) at $timestamp" >> /private/var/tmp/$plistLabel.log

# Hard-coded sleep of 25 seconds for auto-launched applications to start
sleep "25"

jssConnectionStatus

counter=1

until [[ "${jssAvailable}" == "yes" ]] || [[ "${counter}" -gt "10" ]]; do
    scriptResult+="Check ${counter} of 10: Jamf Pro server NOT reachable; waiting to re-check; "
    sleep "30"
    jssConnectionStatus
    ((counter++))
done

if [[ "${jssAvailable}" == "yes" ]]; then

    echo "Jamf Pro server is available, proceeding; " >> /private/var/tmp/$plistLabel.log

    scriptResult+="Resuming Recon at Reboot; "

    scriptResult+="Updating inventory; "

    /usr/local/bin/jamf recon

else

    scriptResult+="Jamf Pro server is NOT available; exiting."

fi

# Delete launchd plist

scriptResult+="Delete $plistLabel.plist; "
/bin/rm -fv /Library/LaunchDaemons/$plistLabel.plist

# Delete script

scriptResult+="Delete script; "
/bin/rm -fv /private/var/tmp/reconAtReboot.bash

# Exit

scriptResult+="End-of-line."

echo "${scriptResult}" >> /private/var/tmp/$plistLabel.log

exit 0
==endOfScript==

echo "Set script file permissions ..."
/usr/sbin/chown root:wheel /private/var/tmp/reconAtReboot.bash
/bin/chmod 644 /private/var/tmp/reconAtReboot.bash
/bin/chmod +x /private/var/tmp/reconAtReboot.bash

echo "Create Log File at /private/var/tmp/$plistLabel.log ..."
touch /private/var/tmp/$plistLabel.log
echo "Created $plistLabel.log on $timestamp" > /private/var/tmp/$plistLabel.log

# Exit

echo "LaunchDaemon and Script created."

exit 0