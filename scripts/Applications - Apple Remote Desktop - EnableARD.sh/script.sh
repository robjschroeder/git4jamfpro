#!/bin/bash
###################################################################################################
#
#   enableARD.sh Ashley Stonham <reddrop>
#   v1.0 - 06/12/2016
#
#   Enables ARD for specified users and optionally configures for 
#   directory based authentication.
#
#
###################################################################################################

ADMINUSER="$4";
ADMINGROUP="$5";
DEFAULTADMIN="jamfpro";
KICKSTART="/System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart";



createARDAdminGroup() {
    dscl . -read /Groups/ard_admin  > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "Creating group ard_admin";
        dseditgroup -o create -r "ARD Admins" ard_admin;
    else
        echo "Group ard_admin already exists";
    fi
}


addAdminGroupToARD_admin() {
        echo "Adding $ADMINGROUP to ard_admin";
        SAVEIFS=$IFS
        IFS=$(echo -en "\n\b")
        ADMINGROUPS=$(echo "$ADMINGROUP" | tr "," "\n");
        for AGROUP in $ADMINGROUPS; do
            echo "GROUP; $AGROUP";
            dseditgroup -o edit -a "$AGROUP" -t group ard_admin;
        done
        IFS=$SAVEIFS
}


if [ "$ADMINUSER" == "" ]; then
    echo "No admin user specified";
    ADMINUSER="$DEFAULTADMIN";
else
    ADMINUSER="$ADMINUSER,$DEFAULTADMIN";
fi


echo "Clearing ARD Settings"
$KICKSTART -uninstall -settings


#ENABLE ARD FOR DEFAULT ADMINS
$KICKSTART -configure -allowAccessFor -specifiedUsers
$KICKSTART -configure -users $ADMINUSER -access -on -privs  -all


if [ "$ADMINGROUP" == "" ]; then
        echo "No admin group specified skipping directory authentication config";
        $KICKSTART -configure -clientopts -setreqperm -reqperm yes
else
    createARDAdminGroup;
    addAdminGroupToARD_admin;
    $KICKSTART -configure -users ard_admin -access -on -privs -all
    $KICKSTART -configure -clientopts -setreqperm -reqperm yes -setdirlogins -dirlogins yes
fi

$KICKSTART -activate -restart -agent

exit 0;