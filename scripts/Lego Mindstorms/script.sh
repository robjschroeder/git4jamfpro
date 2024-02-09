#!/bin/bash

#Download Lego Mindstorms DMG to /tmp
curl https://education.lego.com/_/downloads/EV3_1.50_Global.dmg -o /tmp/legomindstorms.dmg

#Mount DMG
hdiutil attach /tmp/legomindstorms.dmg -nobrowse
sleep 5
# Move .app to /Applicaitons/
rsync -aPz "/Volumes/EV3 Classroom 1.5.0/EV3 Classroom.app" /Applications/
sleep 5
# Detach
hdiutil detach /Volumes/EV3\ Classroom\ 1.5.0/
sleep 5
# Cleanup

rm -r /tmp/legomindstorms.dmg

exit 0