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
#If the installer app isn't there, exit with a failure so the policy can try again tomorrow
if (ls /Applications | grep "Install macOS"); then
	echo "The installer app exists, continuing on..."
	else
		echo "The installer app either didn't download successfully or it got deleted before this policy could run. Ending..."
		exit 1
fi
#If the macOSInstaller directory does not exist in /private/var, create it
if [[ ! -d /private/var/macOSInstaller ]]; then
	echo "Directory does not exist, creating..."
	mkdir -p /private/var/macOSInstaller
	fi
#If there's an older version of the DMG, delete it
if [[ -f /private/var/macOSInstaller/InstallMacOS.dmg ]]; then
	echo "Previous dmg file exists, deleting..."
	rm -rf /private/var/macOSInstaller/InstallMacOS.dmg
	fi 
#Move the installer app from Applications to /private/var/macOSInstaller
echo "Moving installer..."
mv -f /Applications/Install\ macOS\ *.app /private/var/macOSInstaller
#Save the version number of the installer app to a text file for the extension attribute to read
echo "Saving version to file..."
installerOSVersion=$(/usr/libexec/PlistBuddy -c "Print Payload\ Image\ Info:version" /private/var/macOSInstaller/Install\ macOS\ *.app/Contents/SharedSupport/InstallInfo.plist)
echo "$installerOSVersion" > /private/var/macOSInstaller/installerVersion.txt
#Move to staging folder
cd /private/var/macOSInstaller
#Package up the installer app into a DMG
echo "Creating DMG of Installer..."
hdiutil create -fs HFS+ -srcfolder /private/var/macOSInstaller/Install\ macOS\ *.app -volname "InstallMacOS" "InstallMacOS.dmg"
#Delete the original to save space
echo "Deleting original..."
rm -rf /private/var/macOSInstaller/Install\ macOS\ *.app
