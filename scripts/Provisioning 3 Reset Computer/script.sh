#!/bin/sh
########################################################################################################
#
#	MIT License
#
#	Copyright (c) 2020 Jamf Open Source Community
#
#	Permission is hereby granted, free of charge, to any person obtaining a copy
#	of this software and associated documentation files (the "Software"), to deal
#	in the Software without restriction, including without limitation the rights
#	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#	copies of the Software, and to permit persons to whom the Software is
#	furnished to do so, subject to the following conditions:
#
#	The above copyright notice and this permission notice shall be included in all
#	copies or substantial portions of the Software.
#
#	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
#	SOFTWARE.
#
####################################################################################################
#Mount the DMG containing the staged macOS installer app
hdiutil attach -nobrowse /private/var/macOSInstaller/InstallMacOS.dmg
#Get the version of macOS on the target version
macOSVersion=$(/usr/bin/sw_vers -productVersion)
echo "macOS Version $macOSVersion"
#Get version of the staged macOS Installer app
installerOSVersion=$(/usr/libexec/PlistBuddy -c "Print Payload\ Image\ Info:version" /Volumes/InstallMacOS/Install\ macOS\ *.app/Contents/SharedSupport/InstallInfo.plist)
echo "Installer Version $installerOSVersion"
#If the installer and target computer are on different versions, the computer must first be upgraded
if [[ "$macOSVersion" != "$installerOSVersion" ]]; then
echo "Preparing to upgrade the computer. This may take a little while."
#Get the exact name of the current installer (Yay future proofing!)
installerName=$(ls /Volumes/InstallMacOS | grep "Install macOS")
echo "Running from path /Volumes/InstallMacOS/$installerName"
#Launch a full screen Jamf Helper window to prevent the user from making any further changes to their computer
"/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper" -windowType fs -title "macOS Upgrade" -heading "Starting..." -description "The upgrade process has started. It will take about 10-15 minutes for the beginning processes to finish and then your computer will automatically restart." -icon /Volumes/InstallMacOS/Install\ macOS\ *.app/Contents/Resources/DarkProductPageIcon.icns -timeout 900 -countdown -countdownPrompt "Computer will restart in approximately: " -alignCountdown center &
jamfHelperPID=$!
#Run upgrade via the startosinstall binary
/usr/bin/nohup /Volumes/InstallMacOS/"$installerName"/Contents/Resources/startosinstall --agreetolicense --forcequitapps --pidtosignal $jamfHelperPID &
exit
fi
#If the versions match, initiate Erase-Install
echo "Preparing to erase the computer, this may take a little while..."
#Get the exact name of the current installer (Yay future proofing!)
installerName=$(ls /Volumes/InstallMacOS | grep "Install macOS")
echo "Running from path /Volumes/InstallMacOS/$installerName"
#Launch a full screen Jamf Helper window to prevent the user from making any further changes to their computer
"/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper" -windowType fs -title "macOS Wipe/Install" -heading "Starting..." -description "The wipe/install process has started. It will take about 10-15 minutes for the beginning processes to finish and then your computer will automatically restart." -icon /Volumes/InstallMacOS/Install\ macOS\ *.app/Contents/Resources/DarkProductPageIcon.icns -timeout 900 -countdown -countdownPrompt "Computer will restart in approximately: " -alignCountdown center &
jamfHelperPID=$!
#Initiate erase-install via the startosinstall binary
/usr/bin/nohup /Volumes/InstallMacOS/"$installerName"/Contents/Resources/startosinstall --eraseinstall --newvolumename "Macintosh HD" --agreetolicense --forcequitapps --pidtosignal $jamfHelperPID &
exit 0
