#!/bin/bash

#

/usr/bin/expect<<EOF

 

spawn firmwarepasswd -delete

expect {

 

"Enter password:" {

        send "$4\r"

        exp_continue

    }

 

}

EOF

echo "Firmware Password Has Been Removed"

echo "Now sleep"

sleep 5

echo "Initiating Reboot. . ."

reboot