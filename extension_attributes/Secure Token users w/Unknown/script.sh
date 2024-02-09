#!/bin/bash

# 24/02/2020 - F. Abeloos aka Travelling Tech Guy
# travellingtechguy.eu

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

secureTokensList=$(join , ${secureTokens[@]})

echo $secureTokensList

#Check if No Cryptocragic Users

cryptoUsers=$(diskutil apfs listcryptousers /)

if [[ $cryptoUsers == *"No cryptographic users"* ]]; then
	echo "No Secure Token Holders"
 	result="No Secure Token Holders"

elif [ $secureTokensList =="" ]; then

	echo "Unknown Secure Token Holders"
	result="Unknown Secure Token Holders"

else

	result=$secureTokensList
	
fi

echo "<result>$result</result>"