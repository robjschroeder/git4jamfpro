#!/bin/bash

# Set Variables

application="$4"

# Close the application
echo "Closing $application"
pkill "$application"

# Remove application from /Applications/
echo "Removeing $application from /Applications"
rm -rf "/Applications/$application".app

exit 0