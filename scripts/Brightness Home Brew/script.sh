#!/bin/sh

consoleuser=$(ls -l /dev/console | cut -d " " -f4)

su - "${consoleuser}" -c 'git clone https://github.com/nriley/brightness.git'

sleep 1

su - "${consoleuser}" -c 'cd brightness'

make clean

make && make install
