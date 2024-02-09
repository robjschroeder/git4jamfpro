#!/bin/bash

if [[ ! -f /private/var/macOSInstaller/installerVersion.txt ]]; then
echo "<result>Not Installed</result>"
else
echo "<result>$(cat /private/var/macOSInstaller/installerVersion.txt)</result>"
fi