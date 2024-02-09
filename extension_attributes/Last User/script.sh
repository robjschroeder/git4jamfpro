#!/bin/sh
lastUser=`defaults read /Library/Preferences/com.apple.loginwindow lastUserName`

if [ $lastUser == "" ]; then
	echo "<result>No logins</result>"
else
	echo "<result>$lastUser</result>"
fiOn Error Resume Next

Dim objComputers
Dim strComputers

Set objComputers= GetObject("winmgmts:").Instancesof("Win32_ComputerSystem")

For each Computer in objComputers
strComputers = Computer.UserName
Next

WScript.Echo "<result>" & strComputers & "</result>"