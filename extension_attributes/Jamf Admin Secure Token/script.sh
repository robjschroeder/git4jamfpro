#!/bin/bash

declare -a secureTokens
declare -a delete

mgtAdmin="jamfadmin"


secureTokens=($(fdesetup list -extended | awk '{print $4}'))

echo ${secureTokens[@]}

delete+=(USER)
delete+=(Record)

echo ${delete[@]}

for i in ${delete[@]}; do
secureTokens=( ${secureTokens[@]/$i} )
done

echo ${secureTokens[@]}

if [[ " ${secureTokens[@]} " =~ " ${mgtAdmin} " ]]

then

	result='YES'

else 
	result='NO'

fi


echo "<result>$result</result>"