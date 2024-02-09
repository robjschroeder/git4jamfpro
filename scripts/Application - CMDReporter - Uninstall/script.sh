#!/bin/bash

GUI_USER=$(who | grep console | grep -v '_mbsetupuser' | awk '{print $1}')
GUI_UID=$(id -u "$GUI_USER")

# LaunchDaemon
/bin/launchctl unload "/Library/LaunchDaemons/com.cmdsec.cmdReporter.plist"
/bin/rm "/Library/LaunchDaemons/com.cmdsec.cmdReporter.plist"

/bin/launchctl bootout "gui/$GUI_UID" "/Library/LaunchAgents/com.cmdsec.cmdReporterHelper.plist"
/bin/rm "/Library/LaunchAgents/com.cmdsec.cmdReporterHelper.plist"

# Double check proc killed
/usr/bin/killall cmdReporter
/usr/bin/killall cmdReporterHelper

# Binary
/bin/rm /usr/local/bin/cmdReporter
/bin/rm /usr/local/bin/cmdReporterHelper
/bin/rm -r /Applications/cmdReporter.app

# Logs
/bin/rm -f /var/log/cmdReporter.*

# Unlock audit control files
chflags nouchg /etc/security/audit_class
chflags nouchg /etc/security/audit_control
chflags nouchg /etc/security/audit_event
chflags nouchg /etc/security/audit_user
chflags nouchg /etc/security/audit_warn

# Restore audit_control file
if [[ -e /etc/security/audit_control.backup ]]; then
    if [[ -e /etc/security/audit_control.backup ]]; then
        #statements
        # Change audit control file back to values before cmdReporter install
        /bin/rm /etc/security/audit_control
        /bin/cp /etc/security/audit_control.backup /etc/security/audit_control
        /bin/rm -f /etc/security/audit_control.backup
    fi
    # Reload the audit config
    /usr/sbin/audit -s
fi