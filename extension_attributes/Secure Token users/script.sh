#!/bin/bash

declare -a secureTokens
declare -a delete


secureTokens=($(fdesetup list -extended | awk '{print $4}'))

#echo ${secureTokens[@]}

delete+=(USER)
delete+=(Record)

#echo ${delete[@]}

for i in ${delete[@]}; do
secureTokens=( "${secureTokens[@]/$i}" )
done

#echo ${secureTokens[@]}

function join { local IFS="$1"; shift; echo "$*"; }

result=$(join , ${secureTokens[@]})

echo "<result>$result</result>"