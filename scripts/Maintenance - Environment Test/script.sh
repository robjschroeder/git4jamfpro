#!/bin/bash

# Create a JET report and upload to the computer's inventory record in Jamf Pro

# API Credentials:
apiUsername="$4"
apiPassword="$5"
apiURL=$(defaults read /Library/Preferences/com.jamfsoftware.jamf.plist jss_url | sed s'/.$//')

rm -rf /Users/Shared/Mac*

# Creating a script to combine JET and MEU
#
# Created 09.12.2022 @robjschroeder

##################################################
# Using the JET as a template

##################################################

# Get Computer Information
computerName=$(/usr/sbin/scutil --get ComputerName | /usr/bin/sed 's/’//')
computerModel=$(/usr/sbin/sysctl -n hw.model)
computerSerial=$(/usr/sbin/system_profiler SPHardwareDataType | awk '/Serial/ {print $NF}')
macOSVersion=$(/usr/bin/sw_vers -productVersion)
macOSBuild=$(echo $(/usr/bin/awk '/SOFTWARE LICENSE AGREEMENT FOR macOS/' '/System/Library/CoreServices/Setup Assistant.app/Contents/Resources/en.lproj/OSXSoftwareLicense.rtf' | /usr/bin/awk -F 'macOS ' '{print $NF}' | /usr/bin/tr -d '\\') build $(/usr/bin/sw_vers -buildVersion))
# MacBook Pro computers with TouchBar (2016 and 2017) that contain Apple T1 chip
# Intel-based Mac computers that contain the Apple T2 Chip
# All Silicon Macs
if [[ $(/usr/bin/arch) == 'arm64' ]]; then
	secureEnclave="True"
elif [[ $(/usr/sbin/system_profiler SPiBridgeDataType | awk '/Model Name:/') =~ "T2"  ]]; then
	secureEnclave="True"
elif [[ $(/usr/sbin/system_profiler SPHardwareDataType | awk '/Model Identifier/{print $3}') =~ ^(MacBookPro13,2|MacBookPro13,3|MacBookPro14,2|MacBookPro14,3)$ ]];then
	secureEnclave="True"
else
	secureEnclave="False"
fi

# Network Information
activeInterface=$(/sbin/route get google.com | /usr/bin/grep interface | /usr/bin/awk '{print $2}')
activeService=$(/usr/sbin/networksetup -listnetworkserviceorder | /usr/bin/grep $activeInterface | /usr/bin/awk '{print $3}' | /usr/bin/sed 's/.$//')
SSID=$(/usr/sbin/networksetup -getairportnetwork $activeInterface | /usr/bin/cut -c 24-)
#dnsServers=($(/usr/sbin/networksetup -getdnsservers $activeService))
#searchDomains=$(/usr/sbin/networksetup -getsearchdomains $activeService)
macOSDefaultHostsFile=$(cat <<EOF
##
# Host Database
#
# localhost is used to configure the loopback interface
# when the system is booting.  Do not change this entry.
##
127.0.0.1       localhost
255.255.255.255 broadcasthost
::1             localhost
EOF
)
macOSHostFile=$(cat /etc/hosts)
if [[ $(echo ${macOSDefaultHostsFile}) == $(echo ${macOSHostFile}) ]]; then
	hostFileModified="False"
else
	hostFileModified="True"
fi
localIP=$(ipconfig getifaddr $activeInterface)
#if [[ $(/usr/sbin/scutil --proxy | grep "HTTPEnable" | awk '{print $NF}') == "0" ]]; then
#	proxyEnabled="False"
#else
#	proxyEnabled="True"
#fi
publicIP=$(/usr/bin/curl -s ifconfig.me | /usr/bin/sed 's/.$//')
publicDNS=$(/usr/bin/nslookup $publicIP | /usr/bin/awk '/name =/' | /usr/bin/awk '{print $NF}' | /usr/bin/sed 's/.$//')

APPLE_URL_ARRAY=(
	#Device setup
	"albert.apple.com,443,TCP,Device Setup Hosts"
	"captive.apple.com,80,TCP"
	"captive.apple.com,443,TCP"
	"gs.apple.com,443,TCP"
	"humb.apple.com,443,TCP"
	"static.ips.apple.com,80,TCP"
	"static.ips.apple.com,443,TCP"
	"sq-device.apple.com,443,TCP"
	"tbsc.apple.com,443,TCP"
	"time-ios.apple.com,123,UDP"
	"time.apple.com,123,UDP"
	"time-macos.apple.com,123,UDP"

	#Device Apple Push Notifications
	"1-courier.push.apple.com,5223,TCP - non-proxied,Device Push Notification Hosts"
	"1-courier.push.apple.com,443,TCP - non-proxied"
	"2-courier.push.apple.com,5223,TCP - non-proxied"
	"2-courier.push.apple.com,443,TCP - non-proxied"
	"3-courier.push.apple.com,5223,TCP - non-proxied"
	"3-courier.push.apple.com,443,TCP - non-proxied"
	"4-courier.push.apple.com,5223,TCP - non-proxied"
	"4-courier.push.apple.com,443,TCP - non-proxied"
	"5-courier.push.apple.com,5223,TCP - non-proxied"
	"5-courier.push.apple.com,443,TCP - non-proxied"
	"6-courier.push.apple.com,5223,TCP - non-proxied"
	"6-courier.push.apple.com,443,TCP - non-proxied"
	"7-courier.push.apple.com,5223,TCP - non-proxied"
	"7-courier.push.apple.com,443,TCP - non-proxied"
	"8-courier.push.apple.com,5223,TCP - non-proxied"
	"8-courier.push.apple.com,443,TCP - non-proxied"
	"9-courier.push.apple.com,5223,TCP - non-proxied"
	"9-courier.push.apple.com,443,TCP - non-proxied"
	"10-courier.push.apple.com,5223,TCP - non-proxied"
	"10-courier.push.apple.com,443,TCP - non-proxied"
	"11-courier.push.apple.com,5223,TCP - non-proxied"
	"11-courier.push.apple.com,443,TCP - non-proxied"
	"12-courier.push.apple.com,5223,TCP - non-proxied"
	"12-courier.push.apple.com,443,TCP - non-proxied"
	"13-courier.push.apple.com,5223,TCP - non-proxied"
	"13-courier.push.apple.com,443,TCP - non-proxied"
	"14-courier.push.apple.com,5223,TCP - non-proxied"
	"14-courier.push.apple.com,443,TCP - non-proxied"
	"15-courier.push.apple.com,5223,TCP - non-proxied"
	"15-courier.push.apple.com,443,TCP - non-proxied"
	"16-courier.push.apple.com,5223,TCP - non-proxied"
	"16-courier.push.apple.com,443,TCP - non-proxied"
	"17-courier.push.apple.com,5223,TCP - non-proxied"
	"17-courier.push.apple.com,443,TCP - non-proxied"
	"18-courier.push.apple.com,5223,TCP - non-proxied"
	"18-courier.push.apple.com,443,TCP - non-proxied"
	"19-courier.push.apple.com,5223,TCP - non-proxied"
	"19-courier.push.apple.com,443,TCP - non-proxied"
	"20-courier.push.apple.com,5223,TCP - non-proxied"
	"20-courier.push.apple.com,443,TCP - non-proxied"
	"21-courier.push.apple.com,5223,TCP - non-proxied"
	"21-courier.push.apple.com,443,TCP - non-proxied"	
	"22-courier.push.apple.com,5223,TCP - non-proxied"
	"22-courier.push.apple.com,443,TCP - non-proxied"
	"23-courier.push.apple.com,5223,TCP - non-proxied"
	"23-courier.push.apple.com,443,TCP - non-proxied"
	"24-courier.push.apple.com,5223,TCP - non-proxied"
	"24-courier.push.apple.com,443,TCP - non-proxied"
	"25-courier.push.apple.com,5223,TCP - non-proxied"
	"25-courier.push.apple.com,443,TCP - non-proxied"
	"26-courier.push.apple.com,5223,TCP - non-proxied"
	"26-courier.push.apple.com,443,TCP - non-proxied"
	"27-courier.push.apple.com,5223,TCP - non-proxied"
	"27-courier.push.apple.com,443,TCP - non-proxied"
	"28-courier.push.apple.com,5223,TCP - non-proxied"
	"28-courier.push.apple.com,443,TCP - non-proxied"
	"29-courier.push.apple.com,5223,TCP - non-proxied"
	"29-courier.push.apple.com,443,TCP - non-proxied"
	"30-courier.push.apple.com,5223,TCP - non-proxied"
	"30-courier.push.apple.com,443,TCP - non-proxied"
	"31-courier.push.apple.com,5223,TCP - non-proxied"
	"31-courier.push.apple.com,443,TCP - non-proxied"
	"32-courier.push.apple.com,5223,TCP - non-proxied"
	"32-courier.push.apple.com,443,TCP - non-proxied"
	"33-courier.push.apple.com,5223,TCP - non-proxied"
	"33-courier.push.apple.com,443,TCP - non-proxied"
	"34-courier.push.apple.com,5223,TCP - non-proxied"
	"34-courier.push.apple.com,443,TCP - non-proxied"
	"35-courier.push.apple.com,5223,TCP - non-proxied"
	"35-courier.push.apple.com,443,TCP - non-proxied"
	"36-courier.push.apple.com,5223,TCP - non-proxied"
	"36-courier.push.apple.com,443,TCP - non-proxied"
	"37-courier.push.apple.com,5223,TCP - non-proxied"
	"37-courier.push.apple.com,443,TCP - non-proxied"
	"38-courier.push.apple.com,5223,TCP - non-proxied"
	"38-courier.push.apple.com,443,TCP - non-proxied"
	"39-courier.push.apple.com,5223,TCP - non-proxied"
	"39-courier.push.apple.com,443,TCP - non-proxied"
	"40-courier.push.apple.com,5223,TCP - non-proxied"
	"40-courier.push.apple.com,443,TCP - non-proxied"
	"41-courier.push.apple.com,5223,TCP - non-proxied"
	"41-courier.push.apple.com,443,TCP - non-proxied"
	"42-courier.push.apple.com,5223,TCP - non-proxied"
	"42-courier.push.apple.com,443,TCP - non-proxied"
	"43-courier.push.apple.com,5223,TCP - non-proxied"
	"43-courier.push.apple.com,443,TCP - non-proxied"
	"44-courier.push.apple.com,5223,TCP - non-proxied"
	"44-courier.push.apple.com,443,TCP - non-proxied"
	"45-courier.push.apple.com,5223,TCP - non-proxied"
	"45-courier.push.apple.com,443,TCP - non-proxied"
	"46-courier.push.apple.com,5223,TCP - non-proxied"
	"46-courier.push.apple.com,443,TCP - non-proxied"
	"47-courier.push.apple.com,5223,TCP - non-proxied"
	"47-courier.push.apple.com,443,TCP - non-proxied"
	"48-courier.push.apple.com,5223,TCP - non-proxied"
	"48-courier.push.apple.com,443,TCP - non-proxied"
	"49-courier.push.apple.com,5223,TCP - non-proxied"
	"49-courier.push.apple.com,443,TCP - non-proxied"
	"50-courier.push.apple.com,5223,TCP - non-proxied"
	"50-courier.push.apple.com,443,TCP - non-proxied"



	#On-Prem Jamf Pro Push Notification Hosts
	"gateway.push.apple.com,2195,TCP - non-proxied,On-Prem Jamf Pro Apple Push - Binary Protocol"
	"feedback.push.apple.com,2196,TCP - non-proxied"

	#On-Prem Jamf Pro Push Notification Hosts - HTTP/2 Provider 
	"api.push.apple.com,443,TCP,On-Prem Jamf Pro Apple Push  - HTTP/2 Provider"
	"api.push.apple.com,2197,TCP"
	
	#Device Management
	"deviceenrollment.apple.com,443,TCP,Device Management and Enrollment"
	"deviceservices-external.apple.com,443,TCP"
	"gdmf.apple.com,443,TCP"
	"identity.apple.com,443,TCP"
	"iprofiles.apple.com,443,TCP"
	"mdmenrollment.apple.com,443,TCP"
	"setup.icloud.com","443","TCP"
	"vpp.itunes.apple.com,443,TCP"
	
	#Apple School Manager and Apple Business Manager
	"school.apple.com,443,TCP,Apple School Manager and Apple Business Manager"
	"school.apple.com,80,TCP"
	"ws.school.apple.com,443,TCP"
	"ws-ee-maidsvc.icloud.com,443,TCP"
	"ws-ee-maidsvc.icloud.com,80,TCP"
	"business.apple.com,443,TCP"
	"business.apple.com,80,TCP"
	"ws.business.apple.com,443,TCP"
	#"isu.apple.com,443,TCP" Last checked November 2021 unreachable
	#"isu.apple.com,80,TCP" Last checked November 2021 unreachable
	
	#Software updates
	"appldnld.apple.com,80,TCP,Software Updates Hosts"
	"configuration.apple.com,443,TCP"
	"gg.apple.com,80,TCP"
	"gg.apple.com,443,TCP"
	"gnf-mdn.apple.com,443,TCP"
	"gnf-mr.apple.com,443,TCP"
	"gs.apple.com,80,TCP"
	"gs.apple.com,443,TCP"
	"ig.apple.com,443,TCP"
	"mesu.apple.com,80,TCP"
	"mesu.apple.com,443,TCP"
	"ns.itunes.apple.com,443,TCP"
	"oscdn.apple.com,80,TCP"
	"oscdn.apple.com,443,TCP"
	"osrecovery.apple.com,80,TCP"
	"osrecovery.apple.com,443,TCP"
	"skl.apple.com,443,TCP"
	"swcdn.apple.com,80,TCP"
	"swdist.apple.com,443,TCP"
	"swdownload.apple.com,80,TCP"
	"swdownload.apple.com,443,TCP"
	#"swpost.apple.com,80,TCP" Last checked November 2021 unreachable
	"swscan.apple.com,443,TCP"
	"updates-http.cdn-apple.com,80,TCP"
	"updates.cdn-apple.com,443,TCP"
	"xp.apple.com,443,TCP"

	#App Store
	"itunes.apple.com,443,TCP,Apple App Store Hosts"
	"itunes.apple.com,80,TCP"
	"apps.apple.com,443,TCP"
	"api.apps.apple.com,443,TCP"
	"s.mzstatic.com,443,TCP"
	"apps.mzstatic.com,443,TCP"
	"ppq.apple.com,443,TCP"
	"ns.itunes.apple.com,443,TCP"
	"init.itunes.apple.com,443,TCP"
	"affiliate.itunes.apple.com,443,TCP"
	"analytics.itunes.apple.com,443,TCP"

	#Carrier updates
	"appldnld.apple.com.edgesuite.net,80,TCP,Carrier updates"
	
	#Content Caching
	"lcdn-registration.apple.com,443,TCP,Content Caching"
	"suconfig.apple.com,443,TCP"
	"xp-cdn.apple.com,443,TCP"
	"lcdn-locator.apple.com,443,TCP"
	"serverstatus.apple.com,443,TCP"
	
	#Apple Developer
	"register.appattest.apple.com,443,TCP,Apple Developer"
	"data.appattest.apple.com,443,TCP"
	"register-development.appattest.apple.com,443,TCP"
	"data-development.appattest.apple.com,443,TCP"
	
	#Feedback Assistant
	"bpapi.apple.com,443,TCP,Feedback Assistant"
	"cssubmissions.apple.com,443,TCP"
	"fba.apple.com,443,TCP"
	
	#Apple diagnostics
	"diagassets.apple.com,443,TCP,Apple diagnostics"
	
	#DNS Resolution
	#currently unable to be validated for certificates due to openssl on macOS not supporting TLS 1.3
	#"doh.dns.apple.com,443,TCP,Domain Name System resolution"

	#Certificate validation
	"certs.apple.com,80,TCP,Certificate Validation Hosting"
	"certs.apple.com,443,TCP"
	"crl.apple.com,80,TCP"
	"crl.entrust.net,80,TCP"
	"crl3.digicert.com,80,TCP"
	"crl4.digicert.com,80,TCP"
	"ocsp.apple.com,80,TCP"
	"ocsp.digicert.cn,80,TCP"
	"ocsp.digicert.com,80,TCP"
	"ocsp.entrust.net,80,TCP"
	"ocsp2.apple.com,443,TCP"
	"valid.apple.com,443,TCP"
	
	#Apple ID
	"appleid.apple.com,443,TCP,Apple ID"
	"appleid.cdn-apple.com,443,TCP"
	"idmsa.apple.com,443,TCP"
	"gsa.apple.com,443,TCP"
	
	#iCloud
	"api.apple-cloudkit.com,443,TCP,iCloud"
	"setup.apple-cloudkit.com,443,TCP"
	"cdn.apple-livephotoskit.com,443,TCP"
	"idmsaapz-mdn.apzones.com,443,TCP"
	
	#Additional Content
	"audiocontentdownload.apple.com,80,TCP,Additional Content"
	"audiocontentdownload.apple.com,443,TCP"
	"devimages-cdn.apple.com,80,TCP"
	"devimages-cdn.apple.com,443,TCP"
	"download.developer.apple.com,80,TCP"
	"download.developer.apple.com,443,TCP"
	"playgrounds-assets-cdn.apple.com,443,TCP"
	"playgrounds-cdn.apple.com,443,TCP"
	"sylvan.apple.com,80,TCP"
	"sylvan.apple.com,443,TCP"

	#Jamf Hosts
	"jamf.com,443,TCP,Jamf Services"
	"www.jamfcloud.com,443,TCP"
	"use1-jcdsdownloads.services.jamfcloud.com,443,TCP"
	"use1-jcds.services.jamfcloud.com,443,TCP"
	"euc1-jcdsdownloads.services.jamfcloud.com,443,TCP"
	"euc1-jcds.services.jamfcloud.com,443,TCP"
	"euw2-jcdsdownloads.services.jamfcloud.com,443,TCP"
	"euw2-jcds.services.jamfcloud.com,443,TCP"
	"apse2-jcdsdownloads.services.jamfcloud.com,443,TCP"
	"apse2-jcds.services.jamfcloud.com,443,TCP"
	"apne1-jcdsdownloads.services.jamfcloud.com,443,TCP"
	"apne1-jcds.services.jamfcloud.com,443,TCP"
	
	#Jamf Protect Hosts
	"a3bwx220ks5p1x-ats.iot.us-east-1.amazonaws.com,443,TCP,Jamf Protect"
	"a3bwx220ks5p1x-ats.iot.us-east-1.amazonaws.com,8883,TCP"
	"shared-jamf-jpt-generic-packages.s3.amazonaws.com,443,TCP"
	"prod-use1-jamf-jpt-configs.s3.amazonaws.com,443,TCP"
	"a3bwx220ks5p1x-ats.iot.eu-west-2.amazonaws.com,443,TCP"
	"a3bwx220ks5p1x-ats.iot.eu-west-2.amazonaws.com,8883,TCP"
	"prod-euw2-jamf-jpt-configs.s3.amazonaws.com,443,TCP"
	"a3bwx220ks5p1x-ats.iot.eu-central-1.amazonaws.com,443,TCP"
	"a3bwx220ks5p1x-ats.iot.eu-central-1.amazonaws.com,8883,TCP"
	"prod-euc1-jamf-jpt-configs.s3.amazonaws.com,443,TCP"
	"a3bwx220ks5p1x-ats.iot.ap-northeast-1.amazonaws.com,443,TCP"
	"a3bwx220ks5p1x-ats.iot.ap-northeast-1.amazonaws.com,8883,TCP"
	"prod-apne1-jamf-jpt-configs.s3.amazonaws.com,443,TCP"
	"a3bwx220ks5p1x-ats.iot.ap-southeast-2.amazonaws.com,443,TCP"
	"a3bwx220ks5p1x-ats.iot.ap-southeast-2.amazonaws.com,8883,TCP"
	"prod-apse2-jamf-jpt-configs.s3.amazonaws.com,443,TCP"
	
)

NL=$'\n'

#Combine default list and imported list into 1 Array
FULL_ARRAY=()

for LINE in "${APPLE_URL_ARRAY[@]}"; do
	FULL_ARRAY+=("$LINE")
done


####################################################################################################
# 
# FUNCTIONS
#
####################################################################################################


####################################################################################################
# FILE FUNCTION
###
# Create a file into which we will save the Report ###
#default location is /Users/Sahred, with current users Desktop as fallback
function CreateEmptyReportFile () {
	echo "[step] Creating the report file "
	CURRENT_USER=$(/bin/ls -l /dev/console | awk '/ / { print $3 }')
	USER_HOME="/Users/${CURRENT_USER}"
	FOLDER="/Users/Shared"
	if [[ ! -d "${FOLDER}" ]]; then
		FOLDER="${USER_HOME}/Desktop"
		if [[ ! -d "${FOLDER}" ]]; then
			echo "[error] I wasn't able to locate the /Users/Shared or your desktop folder : \"${FOLDER}\""
			exit 1
		fi
	fi
	REPORT_FILE_NAME="Mac Environment Test [$(/bin/date +"%Y-%m-%dT%H%M")].html"
	REPORT_PATH="${FOLDER}/${REPORT_FILE_NAME}"
	touch "${REPORT_PATH}"
	if [[ ! -f "${REPORT_PATH}" ]]; then
		echo "[error] I wasn't able to create a results file : \"${REPORT_PATH}\""
		exit 1
	fi
}

####################################################################################################
# HTML FORMATTING FUNCTIONS
####################################################################################################

function GenerateReportHTML () {
/bin/cat << EOF >> "${REPORT_PATH}"
<html>
	<head>  
		<style type="text/css">
			body { background-color:#444444;font-family:Helvetica,Arial,sans-serif;margin:20px; }
			h1 { margin-top:1em;margin-bottom:0.2em;color:#9eb8d5 }
			h2 { margin-top:1em;margin-bottom:0.2em;color:#37bb9a }
			h3 { margin-top:0.8em;margin-bottom:0.2em;color:#e8573f }
			p { margin-top:0.2em;margin-bottom:0.2em;padding: 0 0 0 1px;color:white }
			.tg    { border-collapse:collapse;border-spacing:0;border-color:#9ABAD9;width: 900px; }
			.tg td { font-family:monospace;font-size:14px;padding:10px 20px;border-style:solid;border-width:0px;overflow:hidden;word-break:normal;border-top-width:1px;border-bottom-width:1px;border-color:#9ABAD9;color:#444;background-color:#EBF5FF; }
			.tg th { font-family:Arial, sans-serif;font-size:14px;font-weight:normal;padding:10px 20px;border-style:solid;border-width:0px;overflow:hidden;word-break:normal;border-top-width:1px;border-bottom-width:1px;border-color:#9ABAD9;color:#fff;background-color:#409cff; }
			.tg .tg-0lax { text-align:left;vertical-align:top }
			.tg2    { border-collapse:collapse;border-spacing:0;border-color:#9ABAD9;width: auto; }
			.tg2 td { font-family:monospace;font-size:14px;padding:10px 20px;border-style:solid;border-width:0px;overflow:hidden;word-break:normal;border-top-width:1px;border-bottom-width:1px;border-color:#9ABAD9;color:#444;background-color:#EBF5FF;vertical-align: top; }
			.tg2 th { font-family:Arial, sans-serif;font-size:14px;font-weight:normal;padding:10px 20px;border-style:solid;border-width:0px;overflow:hidden;word-break:normal;border-top-width:1px;border-bottom-width:1px;border-color:#9ABAD9;color:#fff;background-color:#409cff; }
			.bottom-table { margin-top: 1cm; border: none; border-spacing: 20px 0;}
			a:link { color: white;}
			a:visited { color: lightgreen;}
			a:hover { color: hotpink;}
			a:active { color: blue;}
		</style>
	</head>

	<body>
		<h1>Environment Tests</h1>
		<p>Date: $(/bin/date +"%a %d %b %Y %R")</p>

				<h2>Client Details</h2>
		<p>Computer Name: $(/usr/sbin/scutil --get ComputerName | /usr/bin/sed 's/’//')</p>
		<p>macOS Model: $(/usr/sbin/sysctl -n hw.model)</p>
		<p>macOS Version: $(/usr/bin/sw_vers -productVersion), $(/usr/bin/awk '/SOFTWARE LICENSE AGREEMENT FOR macOS/' '/System/Library/CoreServices/Setup Assistant.app/Contents/Resources/en.lproj/OSXSoftwareLicense.rtf' | /usr/bin/awk -F 'macOS ' '{print $NF}' | /usr/bin/tr -d '\\') build $(/usr/bin/sw_vers -buildVersion)</p>
		<p>Mac Serial: $computerSerial</p>
		<p>Secure Enclave: $secureEnclave</p>

		<h2>Client Network Details</h2>
		<p>Public IP: $publicIP</p>
		<p>Public DNS: $publicDNS</p>
		<p>Local IP: $localIP</p>
		<p>Active Interface: $activeInterface</p>
		<p>Active Service: $activeService</p>
		<p>SSID: $SSID</p>
		<p>Modified Hosts File: $hostFileModified</p>
EOF
}

function createShareReport () {
/bin/cat << EOF >> "${REPORT_PATH}"  
		<table class="bottom-table">
			<tr>
				<td style=“padding-right:15px;”>
					<img src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACgAAAAYCAYAAACIhL/AAAAMSWlDQ1BJQ0MgUHJvZmlsZQAASImVVwdUU8kanltSSWiBCEgJvYkivUgJoUUQkCrYCEkgocSYEETsLMsquBZUREBd0VURRdcCyFqxl0Wx94cFFWVdLNhQeZMCuu557533nzNzv/zzz/eXzJ07A4BOLU8qzUV1AciT5MviI0JYE1LTWKRHAAEUoAs8AYXHl0vZcXHRAMrg8+/y9hq0hnLZRcn1z/H/KnoCoZwPABIHcYZAzs+DeC8AeAlfKssHgOgD9dYz8qVKPAliAxkMEGKpEmepcYkSZ6hxlcomMZ4D8XYAyDQeT5YFgHYL1LMK+FmQR/sGxK4SgVgCgA4Z4kC+iCeAOBLiEXl505QY2gGHjG94sv7GmTHEyeNlDWF1Liohh4rl0lzezP+zHP9b8nIVgz7sYKOJZJHxypxh3W7kTItSYhrEPZKMmFiI9SF+Lxao7CFGqSJFZJLaHjXlyzmwZoAJsauAFxoFsSnE4ZLcmGiNPiNTHM6FGK4QtFCcz03UzF0olIclaDhrZdPiYwdxpozD1sxt5MlUfpX2xxU5SWwN/w2RkDvI/6ZIlJiijhmjFoiTYyDWhpgpz0mIUttgNkUiTsygjUwRr4zfBmI/oSQiRM2PTcmUhcdr7GV58sF8sYUiMTdGg6vzRYmRGp7tfJ4qfiOIW4QSdtIgj1A+IXowF4EwNEydO3ZRKEnS5It1SvND4jVzX0lz4zT2OFWYG6HUW0FsKi9I0MzFA/PhglTz4zHS/LhEdZx4RjZvbJw6HrwQRAMOCAUsoIAtA0wD2UDc3tPcA3+pR8IBD8hAFhACF41mcEaKakQC+wRQBP6ESAjkQ/NCVKNCUAD1n4e06t4FZKpGC1QzcsBjiPNAFMiFvxWqWZIhb8ngEdSI/+GdD2PNhU059k8dG2qiNRrFIC9LZ9CSGEYMJUYSw4mOuAkeiPvj0bAPhs0N98F9B6P9ak94TOggPCBcJXQSbk4VF8u+y4cFxoFO6CFck3PGtznjdpDVEw/BAyA/5MaZuAlwwT2gJzYeBH17Qi1HE7ky+++5/5bDN1XX2FFcKShlGCWY4vD9TG0nbc8hFmVNv62QOtaMobpyhka+98/5ptIC+Iz63hJbiO3BTmFHsTPYAawZsLDDWAt2HjuoxEOr6JFqFQ16i1fFkwN5xP/wx9P4VFZS7trg2u36ST2WLyxU7o+AM006UybOEuWz2HDnF7K4Ev7IESw3VzdXAJTfEfU29Zqp+j4gzLNfdcUFAAQ4DgwMHPiqi/YFYC/cR6ndX3UOcI/TtgDg9EK+Qlag1uHKjgCoQAe+UcbAHFgDB5iPG/AC/iAYhIGxIBYkglQwBVZZBNezDMwAs8ECUArKwTKwClSD9WAj2Ap2gN2gGRwAR8FJcA5cBFfBbbh6usBz0Avegn4EQUgIHWEgxogFYos4I26IDxKIhCHRSDySiqQjWYgEUSCzkR+QcqQCqUY2IPXIb8h+5ChyBulAbiL3kW7kFfIRxVAaaoCaoXboKNQHZaNRaCI6Gc1Cp6NFaAm6BK1C69DtaBN6FD2HXkU70edoHwYwLYyJWWIumA/GwWKxNCwTk2FzsTKsEqvDGrFW+D9fxjqxHuwDTsQZOAt3gSs4Ek/C+fh0fC6+GK/Gt+JN+HH8Mn4f78W/EOgEU4IzwY/AJUwgZBFmEEoJlYTNhH2EE/Bt6iK8JRKJTKI90Ru+janEbOIs4mLiWuJO4hFiB/EhsY9EIhmTnEkBpFgSj5RPKiWtIW0nHSZdInWR3pO1yBZkN3I4OY0sIReTK8nbyIfIl8hPyP0UXYotxY8SSxFQZlKWUjZRWikXKF2Ufqoe1Z4aQE2kZlMXUKuojdQT1DvU11paWlZavlrjtcRa87WqtHZpnda6r/WBpk9zonFok2gK2hLaFtoR2k3aazqdbkcPpqfR8+lL6PX0Y/R79PfaDO2R2lxtgfY87RrtJu1L2i90KDq2OmydKTpFOpU6e3Qu6PToUnTtdDm6PN25ujW6+3Wv6/bpMfRG68Xq5ekt1tumd0bvqT5J304/TF+gX6K/Uf+Y/kMGxrBmcBh8xg+MTYwTjC4DooG9Adcg26DcYIdBu0Gvob6hh2GyYaFhjeFBw04mxrRjcpm5zKXM3cxrzI/DzIaxhwmHLRrWOOzSsHdGw42CjYRGZUY7ja4afTRmGYcZ5xgvN242vmuCmziZjDeZYbLO5IRJz3CD4f7D+cPLhu8efssUNXUyjTedZbrR9Lxpn5m5WYSZ1GyN2TGzHnOmebB5tvlK80Pm3RYMi0ALscVKi8MWz1iGLDYrl1XFOs7qtTS1jLRUWG6wbLfst7K3SrIqttppddeaau1jnWm90rrNutfGwmaczWybBptbthRbH1uR7WrbU7bv7OztUux+smu2e2pvZM+1L7JvsL/jQHcIcpjuUOdwxZHo6OOY47jW8aIT6uTpJHKqcbrgjDp7OYud1zp3jCCM8B0hGVE34roLzYXtUuDS4HJ/JHNk9Mjikc0jX4yyGZU2avmoU6O+uHq65rpucr09Wn/02NHFo1tHv3JzcuO71bhdcae7h7vPc29xf+nh7CH0WOdxw5PhOc7zJ882z89e3l4yr0avbm8b73TvWu/rPgY+cT6LfU77EnxDfOf5HvD94Ofll++32+8vfxf/HP9t/k/H2I8Rjtk05mGAVQAvYENAZyArMD3wl8DOIMsgXlBd0INg62BB8ObgJ2xHdjZ7O/tFiGuILGRfyDuOH2cO50goFhoRWhbaHqYflhRWHXYv3Co8K7whvDfCM2JWxJFIQmRU5PLI61wzLp9bz+0d6z12ztjjUbSohKjqqAfRTtGy6NZx6Lix41aMuxNjGyOJaY4FsdzYFbF34+zjpsf9Pp44Pm58zfjH8aPjZ8efSmAkTE3YlvA2MSRxaeLtJIckRVJbsk7ypOT65HcpoSkVKZ0TRk2YM+FcqkmqOLUljZSWnLY5rW9i2MRVE7smeU4qnXRtsv3kwslnpphMyZ1ycKrOVN7UPemE9JT0bemfeLG8Ol5fBjejNqOXz+Gv5j8XBAtWCrqFAcIK4ZPMgMyKzKdZAVkrsrpFQaJKUY+YI64Wv8yOzF6f/S4nNmdLzkBuSu7OPHJeet5+ib4kR3J8mvm0wmkdUmdpqbRzut/0VdN7ZVGyzXJEPlnekm8AD+znFQ6KHxX3CwILagrez0iesadQr1BSeH6m08xFM58UhRf9OgufxZ/VNtty9oLZ9+ew52yYi8zNmNs2z3peybyu+RHzty6gLshZ8Eexa3FF8ZsfUn5oLTErmV/y8MeIHxtKtUtlpdd/8v9p/UJ8oXhh+yL3RWsWfSkTlJ0tdy2vLP+0mL/47M+jf676eWBJ5pL2pV5L1y0jLpMsu7Y8aPnWCr2KooqHK8ataFrJWlm28s2qqavOVHpUrl9NXa1Y3VkVXdWyxmbNsjWfqkXVV2tCanbWmtYuqn23VrD20rrgdY3rzdaXr//4i/iXGxsiNjTV2dVVbiRuLNj4eFPyplO/+vxav9lkc/nmz1skWzq3xm89Xu9dX7/NdNvSBrRB0dC9fdL2iztCd7Q0ujRu2MncWb4L7FLsevZb+m/Xdkftbtvjs6dxr+3e2n2MfWVNSNPMpt5mUXNnS2pLx/6x+9ta/Vv3/T7y9y0HLA/UHDQ8uPQQ9VDJoYHDRYf7jkiP9BzNOvqwbWrb7WMTjl05Pv54+4moE6dPhp88dop96vDpgNMHzvid2X/W52zzOa9zTec9z+/7w/OPfe1e7U0XvC+0XPS92NoxpuPQpaBLRy+HXj55hXvl3NWYqx3Xkq7duD7peucNwY2nN3NvvrxVcKv/9vw7hDtld3XvVt4zvVf3L8d/7ez06jx4P/T++QcJD24/5D98/kj+6FNXyWP648onFk/qn7o9PdAd3n3x2cRnXc+lz/t7Sv/U+7P2hcOLvX8F/3W+d0Jv10vZy4FXi18bv97yxuNNW19c3723eW/735W9N36/9YPPh1MfUz4+6Z/xifSp6rPj59YvUV/uDOQNDEh5Mp7qKIDBhmZmAvBqCwD0VAAYF+H5YaL6nqcSRH03VSHwn7D6LqgSLwAa4UN5XOccAWAXbHaw0YMBUB7VE4MB6u4+1DQiz3R3U3PR4I2H8H5g4LUZAKRWAD7LBgb61w4MfN4Eg70JwJHp6vulUojwbvCLhxJdYhbOB9/JvwGteX6xjLd3cAAAAAlwSFlzAAAWJQAAFiUBSVIk8AAAAgNpVFh0WE1MOmNvbS5hZG9iZS54bXAAAAAAADx4OnhtcG1ldGEgeG1sbnM6eD0iYWRvYmU6bnM6bWV0YS8iIHg6eG1wdGs9IlhNUCBDb3JlIDUuNC4wIj4KICAgPHJkZjpSREYgeG1sbnM6cmRmPSJodHRwOi8vd3d3LnczLm9yZy8xOTk5LzAyLzIyLXJkZi1zeW50YXgtbnMjIj4KICAgICAgPHJkZjpEZXNjcmlwdGlvbiByZGY6YWJvdXQ9IiIKICAgICAgICAgICAgeG1sbnM6ZXhpZj0iaHR0cDovL25zLmFkb2JlLmNvbS9leGlmLzEuMC8iCiAgICAgICAgICAgIHhtbG5zOnRpZmY9Imh0dHA6Ly9ucy5hZG9iZS5jb20vdGlmZi8xLjAvIj4KICAgICAgICAgPGV4aWY6UGl4ZWxZRGltZW5zaW9uPjk4PC9leGlmOlBpeGVsWURpbWVuc2lvbj4KICAgICAgICAgPGV4aWY6UGl4ZWxYRGltZW5zaW9uPjExODwvZXhpZjpQaXhlbFhEaW1lbnNpb24+CiAgICAgICAgIDx0aWZmOk9yaWVudGF0aW9uPjE8L3RpZmY6T3JpZW50YXRpb24+CiAgICAgIDwvcmRmOkRlc2NyaXB0aW9uPgogICA8L3JkZjpSREY+CjwveDp4bXBtZXRhPgqMkK2UAAAGRElEQVRIDW1XS4scVRQ+9erumc4MTmYcZyLEETWJECeGEAlDotFEjVFIJEgQFPEXZCWCK0UXgoJkEVe6MuA2EhMCQoyLYKJIFqILXxAYNCbT8+ie6ld1V/l9595bXT3mDn3r3PP4znfuq2o8QXvr/TNHRiqVc9VqtRyFUQaVJ8LHcLOGYaVXcEeUZP+PUyi1DVA5HDTEGHuW9BIvjuNOq9k6/tG7py55p975+Pmp6ekLnu8HnXY7RfPVmdGOUWbRHWLOIXfQBL5vQvv91CQkAGPzIjDOoayg2DYZVL7npeVKxU/Tfn9leeloGJXL5/ppGnTbrRQJfM9noMXxIWiCAu7ACgkOmDEPTw9iI25qUWPVEUlV70nmMIgJaK1NU5g8CgcED3loyxDRbDbTUqkU+H74lR9FUaXfS1IwI1TeFEiXy4blFgrQqRod8viBJ7WVdTn+0rNy4thzUluNBejqYjoTzFIGjQBo+gAtnWWj40T1sQxRqVwJ/cDPwMOQs84msghmNAatqM8k9ENZWq3Loaf2yZN7dqhjrdaQb769KlMTY9Lr9y2LYhxlS5ARuUjB+GVpBppBhiXHxJM99KjDOjiwIpBD4dP8UJwsrzVk985H5PD+x6XeiGW1vi7PLMzLnvntsK3rTLqkAyYOy5KxeABWbMMDswZuoa4iNwcbnhpajM83sTqgM8YA5JJuTx6am5U3Th6VS5d/lK2zE3SSm38vy2snj0g9Xpdb/9YkikLRg5MvsUvgFp15nU4hdOszF5aWBvzI1IpGMGrrjoebVUqetDtdWby9goEvV67/Kp988bWMlCP9nT57Qb6DjgUv3l6VdjfRA2LyFHA1rcs9wC9eVaESILFhAeAMdHo+zYAwCfbV1vtn5NDCbuliFjuNZTk4/yD2W6plHJifk9bakszNTsm2B2blj5u3ZPGf2xKFPDhDoFqEIbQhny6tiCGoPMzy2kXWGFcTIZ2cIgGX9/UTR2S0UpJmqyWbqlXdezh5ivQwSB09fADXTizV0RFZaHXkwzNngVlEMqCq4RazhAjAhTf5cAhZUAYHjw52D9LoCDlI90xxB5dLvi7l51+el+s//y6T41VZvLMme3c9Snw5f+WG3PjlL6nVY9k3v03efPVFKYeBLnWAe9bwJCKbnZICSWrc7gz1DCBCCdinCTS9I8p4c9jhC5Ipugj338SmERnHr7y6rhisv1wKVJemmG3scryd8HOEiAs5H+aCmZXcZARdYiZ3Te9LNyg+XSAqorvr+cbAnWXnwSXL9E3CIujsfHk0dfaKuJAZpRQ0PB9BiSUucBv2dLkINlQB3GyQgTIDLn3gB/TWGabWKx40yLoKNJCo0ioiOGIWnEBo5h40sunhx4qVBGMIZMtWfWFMG114emcmx+Xi5e8V4z7IvV4fYYVkun1QRRbYKLo6O8gzDdG0AIXRrnCKB0om1cyqciBOpdbcmaBc5igKcEEvqb5SikxNQ67EcTOXh+dCPiFDMXrNUDNM21AyOuNv7VwjRTIeeBVJKQhxWHyQFBkbxezQBQPaQpDG91FOQo186+uKOH0hf1Flo0J+5tj5NSoMGc/9ozjQqswnsfhDx7/VRlN+W7wjU+Ojgk82GowdjgHeMMuwb5nerL5q0HW8Cwt4DBqT2xFEe804jU1AyA0xGqIMkYoHAjP38gsHZf/enXhD4DodCmBRniS9nkxPTaov4TQLusHedHvP2IwPtwGb6UNSAdaAoUMy9oIrgXmvedLsJHL56k/y2PY52TJzr/oMle3g4M8vHvo2212plFgIPV0ShNrMrj6ujGvQZd7bH3yahWGIfY5v3wFN6wNn3XMuBE+L3YhbUm92VMEwhXXYUCiUDR8fLQu/sq0XnoVm8dRGf2vCpKVJr++HzWbcntg8WUmSbor96Bv/4d6MLA1Essp7xqoygVfc3VueBmaecrxN7Hva+RtMO8KAVz2RbZZ+FJWCtbWl9TBuxcdG2qMXK5VK0EsS7nQl6WpxqQZTbzT9FPfchmwKrsrc4jxsYpveRuZ0aEWInlfMHP6zDNqtVi3pdJ8Obly78ueOXU/8gE/zV7DxI/xron458kaBuZmHTWV0mNW8qVgYF/2HnfKRCgjhken1en6jUZe1lZVjn51+79p/XcDo2s0p78EAAAAASUVORK5CYII=" />
				</td>
				<td style=color:white; >
					Want to share this report? Use the share button in the upper-right corner of your Safari window or email the saved file (${REPORT_PATH}").
				</td>
			</tr>
		</table>
	</body>
</html>
EOF
}
####################################################################################################
# PROXY INFO FUNCTIONS
####################################################################################################

function CreateProxyTable () {
	

/bin/cat << EOF >> "${REPORT_PATH}"  
		<h2>Proxy Settings</h2>
		<table class="tg">
			<tr>
				<th>Interface</th>
				<th>Auto Proxy Discovery</th>
				<th>Auto Proxy Config</th>
				<th>Web Proxy</th>
				<th>Secure Web Proxy</th>
				<th>FTP Proxy</th>
				<th>Socks Proxy</th>
				<th>Streaming Proxy</th>
				<th>Gopher Proxy</th>
				<th>Proxy Bypass Domains</th>
				<th>Static DNS Servers</th>
				<th>Static Search Domains</th>
			</tr>
			${PROXY_INFO_TABLE_ROWS}
		</table>
EOF
}

#### Local macOS Additional Network information ###
function CalculateProxyInfoTableRows () {

	echo "[step] Getting proxy config info..."
	PROXY_INFO_TABLE_ROWS=''

	#Build Array of network interfaces, replacing a " " with "_" it will be removed during the Loop
	ALL_INTERFACE_NAMES=$(/usr/sbin/networksetup -listallnetworkservices | /usr/bin/tail -n +2 | sed -e 's/ /_/g')
	
	for INTERFACE_NAME in ${ALL_INTERFACE_NAMES};
	do
		INTERFACE_NAME_NO_UNDERSCORE=$(echo ${INTERFACE_NAME} | sed -e 's/_/ /g') # Replace _ with a space for readability
		echo "  > Checking proxy on ${INTERFACE_NAME_NO_UNDERSCORE}"
		AUTO_PROXY=$(/usr/sbin/networksetup -getproxyautodiscovery "${INTERFACE_NAME_NO_UNDERSCORE}")
		AUTO_PROXY_URL=$(/usr/sbin/networksetup -getautoproxyurl "${INTERFACE_NAME_NO_UNDERSCORE}")
		WEB_PROXY=$(/usr/sbin/networksetup -getwebproxy "${INTERFACE_NAME_NO_UNDERSCORE}")
		SECURE_WEB_PROXY=$(/usr/sbin/networksetup -getsecurewebproxy "${INTERFACE_NAME_NO_UNDERSCORE}")
		FTP_PROXY=$(/usr/sbin/networksetup -getftpproxy "${INTERFACE_NAME_NO_UNDERSCORE}")
		SOCKS_PROXY=$(/usr/sbin/networksetup -getsocksfirewallproxy "${INTERFACE_NAME_NO_UNDERSCORE}")
		STREAMING_PROXY=$(/usr/sbin/networksetup -getstreamingproxy "${INTERFACE_NAME_NO_UNDERSCORE}")
		GOPHER_PROXY=$(/usr/sbin/networksetup -getgopherproxy "${INTERFACE_NAME_NO_UNDERSCORE}")
		PROXY_BYPASS_DOMAINS=$(/usr/sbin/networksetup -getproxybypassdomains "${INTERFACE_NAME_NO_UNDERSCORE}")
		PROXY_BYPASS_DOMAINS="${PROXY_BYPASS_DOMAINS//$'\n'/<br />}"  # Domain lists can have newlines... convert to html <br>
		DNS_SERVERS=$(/usr/sbin/networksetup -getdnsservers "${INTERFACE_NAME_NO_UNDERSCORE}")
		SEARCH_DOMAINS=$(/usr/sbin/networksetup -getsearchdomains "${INTERFACE_NAME_NO_UNDERSCORE}")


		if [[ ${AUTO_PROXY} == *"Auto Proxy Discovery: Off"* ]]; then
			AUTO_PROXY_STATUS='<td style="color: green;">Off</td>'
			else
			AUTO_PROXY_STATUS='<td style="color: red;">On</td>'
		fi
		if [[ ${AUTO_PROXY_URL} == *"Enabled: No"* ]]; then
			AUTO_PROXY_URL_STATUS='<td style="color: green;">Off</td>'
			else
			AUTO_PROXY_URL_STATUS=$(/usr/sbin/networksetup -getautoproxyurl "${INTERFACE_NAME_NO_UNDERSCORE}" | awk 'NR==1' | awk '{print $2}')
			AUTO_PROXY_URL_STATUS="<td style=\"color: red\">${AUTO_PROXY_URL_STATUS}</td>"
		fi
		if [[ ${WEB_PROXY} == *"Enabled: No"* ]]; then
			WEB_PROXY_STATUS='<td style="color: green;">Off</td>'
			else
			WEB_PROXY_URL=$(/usr/sbin/networksetup -getwebproxy "${INTERFACE_NAME_NO_UNDERSCORE}" | awk 'NR==2'| awk '{print $2}')
			WEB_PROXY_PORT=$(/usr/sbin/networksetup -getwebproxy "${INTERFACE_NAME_NO_UNDERSCORE}" | awk 'NR==3'| awk '{print $2}')
			WEB_PROXY_STATUS="<td style=\"color: red\">${WEB_PROXY_URL}:${WEB_PROXY_PORT}</td>"
		fi
		if [[ ${SECURE_WEB_PROXY} == *"Enabled: No"* ]]; then
			SECURE_WEB_PROXY_STATUS='<td style="color: green;">Off</td>'
			else
			SECURE_WEB_PROXY_URL=$(/usr/sbin/networksetup -getwebproxy "${INTERFACE_NAME_NO_UNDERSCORE}" | awk 'NR==2'| awk '{print $2}')
			SECURE_WEB_PROXY_PORT=$(/usr/sbin/networksetup -getwebproxy "${INTERFACE_NAME_NO_UNDERSCORE}" | awk 'NR==3'| awk '{print $2}')
			SECURE_WEB_PROXY_STATUS="<td style=\"color: red\">${SECURE_WEB_PROXY_URL}:${SECURE_WEB_PROXY_PORT}</td>"
		fi
		if [[ ${FTP_PROXY} == *"Enabled: No"* ]]; then
			FTP_PROXY_STATUS='<td style="color: green;">Off</td>'
			else
			FTP_PROXY_URL=$(/usr/sbin/networksetup -getwebproxy "${INTERFACE_NAME_NO_UNDERSCORE}" | awk 'NR==2'| awk '{print $2}')
			FTP_PROXY_PORT=$(/usr/sbin/networksetup -getwebproxy "${INTERFACE_NAME_NO_UNDERSCORE}" | awk 'NR==3'| awk '{print $2}')
			FTP_PROXY_STATUS="<td style=\"color: red\">${FTP_PROXY_URL}:${FTP_PROXY_PORT}</td>"
		fi
		if [[ ${SOCKS_PROXY} == *"Enabled: No"* ]]; then
			SOCKS_PROXY_STATUS='<td style="color: green;">Off</td>'
			else
			SOCKS_PROXY_URL=$(/usr/sbin/networksetup -getwebproxy "${INTERFACE_NAME_NO_UNDERSCORE}" | awk 'NR==2'| awk '{print $2}')
			SOCKS_PROXY_PORT=$(/usr/sbin/networksetup -getwebproxy "${INTERFACE_NAME_NO_UNDERSCORE}" | awk 'NR==3'| awk '{print $2}')
			SOCKS_PROXY_STATUS="<td style=\"color: red\">${SOCKS_PROXY_URL}:${SOCKS_PROXY_PORT}</td>"
		fi
		if [[ ${STREAMING_PROXY} == *"Enabled: No"* ]]; then
			STREAMING_PROXY_STATUS='<td style="color: green;">Off</td>'
			else
			STREAMING_PROXY_URL=$(/usr/sbin/networksetup -getwebproxy "${INTERFACE_NAME_NO_UNDERSCORE}" | awk 'NR==2'| awk '{print $2}')
			STREAMING_PROXY_PORT=$(/usr/sbin/networksetup -getwebproxy "${INTERFACE_NAME_NO_UNDERSCORE}" | awk 'NR==3'| awk '{print $2}')
			STREAMING_PROXY_STATUS="<td style=\"color: red\">${STREAMING_PROXY_URL}:${STREAMING_PROXY_PORT}</td>"
		fi
		if [[ ${GOPHER_PROXY} == *"Enabled: No"* ]]; then
			GOPHER_PROXY_STATUS='<td style="color: green;">Off</td>'
			else
			GOPHER_PROXY_URL=$(/usr/sbin/networksetup -getwebproxy "${INTERFACE_NAME_NO_UNDERSCORE}" | awk 'NR==2'| awk '{print $2}')
			GOPHER_PROXY_PORT=$(/usr/sbin/networksetup -getwebproxy "${INTERFACE_NAME_NO_UNDERSCORE}" | awk 'NR==3'| awk '{print $2}')
			GOPHER_PROXY_STATUS="<td style=\"color: red\">${GOPHER_PROXY_URL}:${GOPHER_PROXY_PORT}</td>"
		fi
		if [[ ${PROXY_BYPASS_DOMAINS} == *"There aren't any bypass domains set"* ]]; then
			PROXY_BYPASS_DOMAINS_STATUS='<td style="color: green;">Off</td>'
			else
			PROXY_BYPASS_DOMAINS_STATUS="<td style=\"color: black\">${PROXY_BYPASS_DOMAINS}</td>"
		fi
		if [[ ${DNS_SERVERS} == *"There aren't any DNS Servers set"* ]]; then
			DNS_SERVERS_STATUS='<td style="color: green;">Off</td>'
			else
			DNS_SERVERS_STATUS="<td style=\"color: red\">${DNS_SERVERS}</td>"
		fi
		if [[ ${SEARCH_DOMAINS} == *"There aren't any Search Domains set"* ]]; then
			SEARCH_DOMAINS_STATUS='<td style="color: green;">Off</td>'
			else
			SEARCH_DOMAINS_STATUS="<td style=\"color: red\">${SEARCH_DOMAINS}</td>"
		fi
		PROXY_INFO_TABLE_ROWS+="      <tr>
				<td>${INTERFACE_NAME_NO_UNDERSCORE}${IS_ACTIVE_INTERFACE}</td>
				${AUTO_PROXY_STATUS}
				${AUTO_PROXY_URL_STATUS}
				${WEB_PROXY_STATUS}
				${SECURE_WEB_PROXY_STATUS}
				${FTP_PROXY_STATUS}
				${SOCKS_PROXY_STATUS}
				${STREAMING_PROXY_STATUS}
				${GOPHER_PROXY_STATUS}
				${PROXY_BYPASS_DOMAINS_STATUS}
				${DNS_SERVERS_STATUS}
				${SEARCH_DOMAINS_STATUS}
			</tr>"
		done
}


####################################################################################################
# Current Interface Proxy details
####################################################################################################

function getProxyAddress () {

	#Set PROXY HOST and PORT variables to be empty before checks
	PROXY_HOST=""
	PROXY_PORT=""
	
	#Get Any and All proxy settings from current active interface
	PROXY_DATA_LOCATION="/tmp/Current_Proxy"
	PROXY_DATA=$(/usr/sbin/scutil --proxy > ${PROXY_DATA_LOCATION})
	
	#Detect which setting is enabled
	AUTO_PROXY_DISCOVERY_STATUS=$(/bin/cat ${PROXY_DATA_LOCATION} | /usr/bin/grep ProxyAutoDiscoveryEnable | /usr/bin/awk '{print $3}')
	AUTO_PROXY_CONFIGURATION_STATUS=$(/bin/cat ${PROXY_DATA_LOCATION}| /usr/bin/grep ProxyAutoConfigEnable | /usr/bin/awk '{print $3}')
	SECURE_WEB_PROXY_STATUS=$(/bin/cat ${PROXY_DATA_LOCATION} | /usr/bin/grep HTTPSEnable | /usr/bin/awk '{print $3}')
	WEB_PROXY_STATUS=$(/bin/cat ${PROXY_DATA_LOCATION} | /usr/bin/grep HTTPEnable | /usr/bin/awk '{print $3}')

	
	#If Auto Proxy Discovery is Enabled then query and get prosy host and port
	if [[ ${PROXY_HOST} == "" ]] && [[ ${PROXY_PORT} == "" ]] && [[ ${AUTO_PROXY_DISCOVERY_STATUS} == "1" ]]; then
		AUTO_PROXY_DISCOVERY_URL=$(/bin/cat ${PROXY_DATA_LOCATION} | /usr/bin/grep ProxyAutoConfigURLString | /usr/bin/awk '{print $3}')
		#test URL default is http://wpad/wpad.dat if not resolving then setting to empty
		AUTO_PROXY_DISCOVERY_URL_STATUS=$(/usr/bin/curl -Is ${AUTO_PROXY_DISCOVERY_URL} | /usr/bin/head -n 1)
		if [[ ${AUTO_PROXY_DISCOVERY_URL_STATUS} == "HTTP/1.1 200 OK" ]]; then
			#Pac url is contactable, lets parse it for proxy host and port
			AUTO_PROXY_DISCOVERY_URL_CONTENT=$(/usr/bin/curl ${AUTO_PROXY_DISCOVERY_URL})
			#Get Proxy Host
			PROXY_HOST=$(echo ${AUTO_PROXY_DISCOVERY_URL}_CONTENT | /usr/bin/grep PROXY | /usr/bin/tail -n 1 | /usr/bin/awk '{print $3}' | /usr/bin/tr -d "';" | /usr/bin/cut -d: -f1)
			#Get Proxy Port
			PROXY_PORT=$(echo ${AUTO_PROXY_DISCOVERY_URL}_CONTENT | /usr/bin/grep PROXY | /usr/bin/tail -n 1 | /usr/bin/awk '{print $3}' | /usr/bin/tr -d "';" | /usr/bin/cut -d: -f2)
		else
			PROXY_HOST=""
			PROXY_PORT=""
			
		fi
	fi
	
	#If Auto Proxy Configuration is Enabled then query and get prosy host and port
	if [[ ${PROXY_HOST} == "" ]] && [[ ${PROXY_PORT} == "" ]] && [[ ${AUTO_PROXY_CONFIGURATION_STATUS} == "1" ]]; then
	
		AUTO_PROXY_DISCOVERY_URL=$(/bin/cat ${PROXY_DATA_LOCATION} | /usr/bin/grep ProxyAutoConfigURLString | /usr/bin/awk '{print $3}')
		#test URL default is http://wpad/wpad.dat if not resolving then setting to empty
		AUTO_PROXY_DISCOVERY_URL_STATUS=$(/usr/bin/curl -Is ${AUTO_PROXY_DISCOVERY_URL} | /usr/bin/head -n 1)
		if [[ ${AUTO_PROXY_DISCOVERY_URL_STATUS} =~ "HTTP" ]]; then
			#Pac url is contactable, lets parse it for proxy host and port
			#Get Proxy Host
			PROXY_HOST=$(/usr/bin/curl ${AUTO_PROXY_DISCOVERY_URL} | /usr/bin/grep 'PROXY' | /usr/bin/tail -n 1 | /usr/bin/awk '{print $3}' | /usr/bin/tr -d "';" | /usr/bin/cut -d: -f1)
			#Get Proxy Port
			PROXY_PORT=$(/usr/bin/curl ${AUTO_PROXY_DISCOVERY_URL} | /usr/bin/grep 'PROXY' | /usr/bin/tail -n 1 | /usr/bin/awk '{print $3}' | /usr/bin/tr -d "';" | /usr/bin/cut -d: -f2)
		else
			PROXY_HOST=""
			PROXY_PORT=""
			
		fi
	fi
	
	#If Secure Web Proxy is Enabled then query and get proxy host and port
	if [[ ${PROXY_HOST} == "" ]] && [[ ${PROXY_PORT} == "" ]] && [[ $SECURE_WEB_PROXY_STATUS == "1" ]]; then
		#extract Host and port from scutil
		PROXY_HOST=$(/bin/cat ${PROXY_DATA_LOCATION} | /usr/bin/grep HTTPProxy | /usr/bin/awk '{print $3}')
		PROXY_PORT=$(/bin/cat ${PROXY_DATA_LOCATION} | /usr/bin/grep HTTPPort | /usr/bin/awk '{print $3}')
	fi
	
	#If Web Proxy is Enabled then query and get proxy host and port
	if [[ ${PROXY_HOST} == "" ]] && [[ ${PROXY_PORT} == "" ]] && [[ $WEB_PROXY_STATUS == "1" ]]; then
		#extract Host and port from scutil
		PROXY_HOST=$(/bin/cat ${PROXY_DATA_LOCATION} | /usr/bin/grep HTTPProxy | /usr/bin/awk '{print $3}')
		PROXY_PORT=$(/bin/cat ${PROXY_DATA_LOCATION} | /usr/bin/grep HTTPPort | /usr/bin/awk '{print $3}')
	fi
	
}

####################################################################################################
# NETWORK CHECK FUNCTIONS
####################################################################################################
### Get HOSTNAME Connection Status ###
function CalculateHostInfoTables () {
	echo "[step] Checking Apple Hosts..."
	lastCategory="zzzNone"  # Some fake category so we recognize that the first host is the start of a new category
	firstServer="yes"       # Flag for the first host so we don't try to close the preceding table -- there won't be one. 
	HOST_TEST_TABLES=''    # This is the var we will insert into the HTML
	for SERVER in "${FULL_ARRAY[@]}"; do
		#split the record info fields
		HOSTNAME=$(echo ${SERVER} | cut -d ',' -f1)
		PORT=$(echo ${SERVER} | cut -d ',' -f2)
		PROTOCOL=$(echo ${SERVER} | cut -d ',' -f3)
		CATEGORY=$(echo ${SERVER} | cut -d ',' -f4)
		# We have categories of hosts... enrollment, software update, etc. We'll put them in separate tables
		# If the category for this host is different than the last one and is not blank...
		if [[ "${lastCategory}" != "${CATEGORY}" ]] && [[ ! -z "${CATEGORY}" ]]; then
			# If this is not the first server, close up the table from the previous category before moving on to the next. 
			echo "Starting Category : ${CATEGORY}"
			if [[ "${firstServer}" != "yes" ]]; then
				#We've already started the table html so no need to do it again.  
				HOST_TEST_TABLES+="    </table>${NL}"
			fi
			firstServer="no"
			lastCategory="${CATEGORY}"
			HOST_TEST_TABLES+="    <h3>${CATEGORY}</h3>${NL}"
			HOST_TEST_TABLES+="    <table class=\"tg\">${NL}"
			HOST_TEST_TABLES+="      <tr><th width=\"40%\">HOSTNAME</th><th width=\"50%\">Reverse DNS</th><th width=\"10%\">IP Address</th><th width=\"10%\">Port</th><th width=\"10%\">Protocol</th><th width=\"10%\">Accessible</th><th width=\"20%\">SSL Error</th></tr>${NL}"
		fi # End of table start and end logic.

		echo "  > Checking connectivity to : ${HOSTNAME} ${PORT} ${PROTOCOL}"

		# Now print the info for this host...
		#Perform Host nslookup to get reported IP
		IP_ADDRESS=$(/usr/bin/nslookup ${HOSTNAME} | /usr/bin/grep "Address:" | /usr/bin/awk '{print$2}' | /usr/bin/tail -1)
		
		
		#Get Reverse DNS record
		REVERSE_DNS=$(/usr/bin/dig -x ${IP_ADDRESS} +short | /usr/bin/sed 's/.$//')
		
		# Using nc, if proxy defined then adding in proxy flag
		if [[ ${PROTOCOL} == "TCP" ]]; then
			#Check if Proxy set
			if [[ ${PROXY_HOST} == "" ]] && [[ ${PROXY_PORT} == "" ]];then
				#no proxy set
				STATUS=$(/usr/bin/nc -z -G 3 ${HOSTNAME} ${PORT} 2>&1 | /usr/bin/awk '{print $7}')	
			else
				STATUS=$(/usr/bin/nc -z -G 3 -x ${PROXY_HOST}:${PROXY_PORT} -X connect ${HOSTNAME} ${PORT} 2>&1 | /usr/bin/awk '{print $7}')
			fi
			
		elif [[ ${PROTOCOL} == "TCP - non-proxied" ]]; then
			#for non proxy aware urls we will be using netcat aka nc
			STATUS=$(/usr/bin/nc -z -G 3 ${HOSTNAME} ${PORT} 2>&1 | /usr/bin/awk '{print $7}')
		else    
			# UDP goes direct... not proxied. 
			STATUS=$(/usr/bin/nc -u -z -G 3 ${HOSTNAME} ${PORT} 2>&1 | /usr/bin/awk '{print $7}')

		fi
		
		#Based on Status will set Availability Value
		if [[ ${STATUS} =~ "succeeded" ]]; then
			AVAILBILITY="succeeded"
		
		else
			AVAILBILITY="failed"
		fi


		if [[ "${AVAILBILITY}" == "succeeded" ]]; then
			AVAILBILITY_STATUS='<td style="color: green;">Available</td>'
			#Test for SSL Inspection
			if [[ ${PORT} == "80" ]]; then
				#http traffic no ssl inspection issues
				SSL_STATUS='<td style="color: green;">N/A</td>'
			else
				if [[ ${PROTOCOL} == "TCP" ]]; then                
					if [[ ${PROXY_HOST} == "" ]] && [[ ${PROXY_PORT} == "" ]];then
						CERT_STATUS=$(echo | /usr/bin/openssl s_client -showcerts -connect "${HOSTNAME}:${PORT}" -servername "${HOSTNAME}" 2>/dev/null | /usr/bin/openssl x509 -noout -issuer )
						
					else
						CERT_STATUS=$(echo | /usr/bin/openssl s_client -showcerts -proxy "${PROXY_HOST}:${PROXY_PORT}" -connect "${HOSTNAME}:${PORT}" -servername "${HOSTNAME}" 2>/dev/null | /usr/bin/openssl x509 -noout -issuer)
					fi

					if [[ ${CERT_STATUS} != *"Apple Inc"* ]] && [[ "${CERT_STATUS}" != *"Akamai Technologies"* ]] && [[ "${CERT_STATUS}" != *"Amazon"* ]] && [[ "${CERT_STATUS}" != *"DigiCert"* ]] && [[ "${CERT_STATUS}" != *"Microsoft"* ]] && [[ "${CERT_STATUS}" != *"COMODO"* ]] && [[ "${CERT_STATUS}" != *"QuoVadis"* ]]; then
						
						SSL_ISSUER=$(echo ${CERT_STATUS} | awk -F'O=|/OU' '{print $2}')
						
						if [[ ${HOSTNAME} == *"jcdsdownloads.services.jamfcloud.com" ]];then
							SSL_STATUS='<td style="color: green;">N/A</td>'
						else	
							SSL_STATUS="<td style=\"color: red;\">Unexpected Certificate: ${SSL_ISSUER}</td>"
						fi
						
					else	
						
						SSL_STATUS='<td style="color: green;">Successful</td>'
					fi
				else
					SSL_STATUS='<td style="color: green;">N/A</td>'
				fi
			fi
		else
			# nc did not connect. There is no point in trying the SSL cert subject test. 
			AVAILBILITY_STATUS='<td style="color: red;">Unavailable</td>'
			SSL_STATUS='<td style="color: black;">Not checked</td>'
		fi

		# Done. Stick the row of info into the HTML var...
		HOST_TEST_TABLES+="        <tr><td>${HOSTNAME}</td><td>${REVERSE_DNS}</td><td>${IP_ADDRESS}</td><td>${PORT}</td><td>${PROTOCOL}</td>${AVAILBILITY_STATUS}${SSL_STATUS}</tr>${NL}"
	done
	# Close up the html for the final table
	HOST_TEST_TABLES+="    </table>${NL}"
}

#Create NetworkCheck table
function createNetworkCheckTable () {
/bin/cat << EOF >> "${REPORT_PATH}"  
		<p />
		<h2>Server Connectivity Tests</h2>
		<p>Network access to the following hostnames are required for enrolling, installing, restoring or updating Apple OSs. We will test the ability to reach these services from this device. We will also check SSL certificate subjects to see if any proxies may be replacing them. Many Apple services use certificate pinning to prevent SSL interception.</p>
		<p>
			<u>References:</u> <a href="https://support.apple.com/en-us/HT210060" style="color:white;">Use Apple products on enterprise networks</a> / <a href="https://support.apple.com/en-us/HT201999" style="color:white;">About macOS, iOS, and iTunes server host connections</a> / <a href="https://www.jamf.com/jamf-nation/articles/34" style="color:white;">Network Ports Used by Jamf Pro</a> /
			<a href="https://www.jamf.com/jamf-nation/articles/409" style="color:white;">Permitting Inbound/Outbound Traffic with Jamf Cloud</a>
			
		</p>
${HOST_TEST_TABLES}
EOF
}

####################################################################################################
# ADDITIONAL CHECK FUNCTIONS
####################################################################################################

#Running Additional Checks
function createAdditionalChecksHTML () {
/bin/cat << EOF >> "${REPORT_PATH}"
		<h2>Other Information and Settings</h2>
		<table class="tg2">
			<tr>
				<th>Test</th>
				<th>Answer</th>
				<th>Follow-up</th>
				<th>References</th>
			</tr>
			<tr>
				<td>APNS apsctl Status</td>
				${APSCTL_STATUS}
				<td>Apple Push Notifications should be accessible. </td>
				<td><a href="https://support.apple.com/en-us/HT203609" style="color:black;">If your clients aren't getting Apple push notifications</a></td>
			</tr>
			<tr>
				<td>Root User Status</td>
				${ROOT_USER_STATUS}
				<td>The root user is not intended for routine use, if enabled, steps should be taken to disable</td>
				<td><a href="https://support.apple.com/en-us/HT204012" style="color:black;">How to enable and disable the root user</a></td>
			</tr>
			<tr>
				<td>SIP Status</td>
				${SIP_STATUS}
				<td>SIP is a security feature of macOS if disabled it is recommended to re-enable</td>
				<td><a href="https://support.apple.com/en-us/HT204899" style="color:black;">About System Integrity Protection on your Mac</a></td>
			</tr>
			<tr>
				<td>Gatekeeper Status</td>
				${GATEKEEPER_STATUS}
				<td>If GateKeeper is disabled it opens your machine to malicious content</td>
				<td><a href="https://support.apple.com/guide/deployment-reference-macos/gatekeeper-and-runtime-protection-apd02b925e38" style="color:black;">About GateKeeper on your Mac</a></td>
			</tr>
			<tr>
				<td>Gatekeeper Configuration</td>
				${MDM_GATEKEEPER_CONFIGURATION_STATUS}
				<td>Determines if GateKeeper is managed by MDM.</td>
				<td><a href="https://support.apple.com/guide/deployment-reference-macos/gatekeeper-and-runtime-protection-apd02b925e38" style="color:black;">About Gatekeeper on your Mac</a></td>
			</tr>
			<tr>
				<td>Firewall Status</td>
				${FIREWALL_STATUS}
				<td>Determines status of Firewall</td>
				<td><a href="https://support.apple.com/guide/deployment/security-privacy-payload-settings-dep61dc030/web" style="color:black;">Security & Privacy MDM payload settings for Apple devices</a></td>
			</tr>
			<tr>
				<td>Firewall Configuration</td>
				${MDM_FIREWALL_CONFIGURATION_STATUS}
				<td>Determines if the built-in firewall is managed by MDM.</td>
				<td><a href="https://support.apple.com/guide/deployment/security-privacy-payload-settings-dep61dc030/web" style="color:black;">Security & Privacy MDM payload settings for Apple devices</a></td>
			</tr>
			<tr>
				<td>FileVault Status</td>
				${FILEVAULT_STATUS}
				<td>If FileVault is not enabled the device is not encrypted</td>
				<td><a href="https://support.apple.com/en-us/HT204837" style="color:black;">Use FileVault to encrypt your Mac</a></td>
			</tr>
			<tr>
				<td>FileVault Recovery Key Escrow Configuration</td>
				${MDM_PRK_ESCROW_STATUS}
				<td>Determines if MDM is configured to escrow FileVault recovery keys.</td>
				<td><a href="https://support.apple.com/en-us/HT204837" style="color:black;">Use FileVault to encrypt your Mac</a></td>
			</tr>
			<tr>
				<td>Legacy Software Update Server Status</td>
				${LEGACY_SWUS_STATUS}
				<td>If a legacy software update server configuration was deployed to this Mac</td>
				<td>Use Apple Software Update Servers</td>
			</tr>
			<tr>
				<td>Active Directory Domain</td>
				${AD_STATUS}
				<td>If binding is used, discuss modern authentication and no-bind approaches.</td>
				<td><a href="https://www.jamf.com/products/jamf-connect/" style="color:black;">About NoMAD and Jamf Connect</a></td>
			</tr>
			<tr>
				<td>Content Cache</td>
				${CONTENT_CACHE_STATUS}
				<td>If none is available, discuss how Apple content caching improves user experience and reduces WAN traffic.</td>
				<td><a href="https://support.apple.com/en-au/guide/mac-help/mchl9388ba1b/10.15/mac/10.15" style="color:black;">What is content caching on Mac?</a></td>
			</tr>
			<tr>
				<td>MDM Enrollment</td>
				${ADE_ENROLLED_STATUS}
				<td>Determines if the Mac was deployed via Automated Device Enrollment.</td>
				<td><a href="https://docs.jamf.com/10.41.0/jamf-pro/documentation/Automated_Device_Enrollment_Integration.html" style="color:black;">Automated Device Enrollment Integration</a></td>
			</tr>
			<tr>
				<td>MDM Enrollment Type</td>
				${MDM_ENROLLED_STATUS}
				<td>Determines if the device is enrolled in an MDM.</td>
				<td><a href="https://support.apple.com/guide/deployment/intro-to-apple-device-enrollment-types-dep08f54fcf6/web" style="color:black;">Automated Device Enrollment Integration</a></td>
			</tr>
			<tr>
				<td>MDM Server URL</td>
				${MDM_SERVER_URL}
				<td>Displays URL of MDM server in which this Mac is enrolled.</td>
				<td>MDM Server</td>
			</tr>
			<tr>
				<td>Automatic Login Configuration</td>
				${MDM_LOGIN_CONFIGURATION_STATUS}
				<td>Determines if automatic login is managed by MDM.</td>
				<td><a href="https://support.apple.com/guide/deployment/login-window-payload-settings-dep2a822b29/web" style="color:black;">Login Window MDM payload settings for Apple devices</a></td>
			</tr>
			<tr>
				<td>Bootstrap Token</td>
				${BOOTSTRAP_TOKEN_STATUS}
				<td>Determines if a bootstrap token has been deployed to this Mac computer.</td>
				<td><a href="https://support.apple.com/guide/deployment/use-secure-and-bootstrap-tokens-dep24dbdcf9e/web" style="color:black;">Use secure token, bootstrap token, and volume ownership in deployments</a></td>
			</tr>
			<tr>
				<td>Guest Account Configuration</td>
				${MDM_GUEST_CONFIGURATION_STATUS}
				<td>Determines if guest account settings are managed with MDM.</td>
				<td><a href="https://support.apple.com/guide/deployment/login-window-payload-settings-dep2a822b29/web" style="color:black;">Login Window MDM payload settings for Apple devices</a></td>
			</tr>
			<tr>
				<td>Screen Saver Idle Time Configuration</td>
				${MDM_SCREENSAVER_IDLE_TIME_STATUS}
				<td>Determines if screen saver idle time is managed by MDM.</td>
				<td><a href="https://developer.apple.com/documentation/devicemanagement/screensaver" style="color:black;">Screensaver MDM Payload</a></td>
			</tr>
			<tr>
				<td>Launch Daemons</td>
				<td>${LAUNCH_DAEMONS_STATUS}</td>
				<td>Verify that all are expected and needed.</td>
				<td><a href="https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/Introduction.html" style="color:black;">About Daemons and Services</a></td>
			</tr>
			<tr>
				<td>Third-Party System Extensions</td>
				<td>${KEXT_STATUS}</td>
				<td>Discuss upgrades or replacement solutions that decrease reliance on kernel extensions.</td>
				<td><a href="https://developer.apple.com/support/kernel-extensions/" style="color:black;">Deprecated Kernel Extensions and System Extension Alternatives</a></td>
			</tr>
		</table>
EOF
}

function calculateAdditionalChecks () {
	#this function is used to populate information into the Addtional Checks Report
	
	#apsctl Status
	APSCTL_STATUS_CHECK=$(/System/Library/PrivateFrameworks/ApplePushService.framework/apsctl status | /usr/bin/grep "connected to server hostname:")
		if [[ ${APSCTL_STATUS_CHECK} =~ "courier.push.apple.com" ]]; then
			APSCTL_STATUS='<td style="color: green;">Connected</td>'
		else
			APSCTL_STATUS='<td style="color: red;">Unavailable</td>'
		fi
	
	#Root User Status
	ROOT_USER_CHECK=$(/usr/bin/dscl . -read /Users/root AuthenticationAuthority 2>&1 | /usr/bin/grep -c "No such key")
		if [[ ${ROOT_USER_CHECK} == "1" ]]; then
			ROOT_USER_STATUS='<td style="color: green;">Disabled</td>'
		else
			ROOT_USER_STATUS='<td style="color: red;">Enabled</td>'
		fi
	#SIP Status
	SIP_STATUS_CHECK=$(/usr/bin/csrutil status | /usr/bin/awk '{print $5}' | /usr/bin/tr -d '.')
		if [[ ${SIP_STATUS_CHECK} == "enabled" ]]; then
			SIP_STATUS='<td style="color: green;">Enabled</td>'
		else
			SIP_STATUS='<td style="color: red;">Disabled</td>'
		fi
	#Gatekeeper
	GATEKEEPER_STATUS_CHECK=$(/usr/sbin/spctl --status | /usr/bin/awk '/assessments/ {print $2}')
		if [[ ${GATEKEEPER_STATUS_CHECK} == "enabled" ]]; then
			GATEKEEPER_STATUS='<td style="color: green;">Enabled</td>'
		else
			GATEKEEPER_STATUS='<td style="color: red;">Disabled</td>'
		fi
	
	#FileVault Status
	FILEVAULT_STATUS_CHECK=$(/usr/bin/fdesetup status | /usr/bin/awk '{print $3}' | /usr/bin/tr -d .)
		if [[ ${FILEVAULT_STATUS_CHECK} == "On" ]]; then
			FILEVAULT_STATUS='<td style="color: green;">Enabled</td>'
		else
			FILEVAULT_STATUS='<td style="color: red;">Disabled</td>'
		fi
	
	#MDM FileVault Key Escrow Configuration
	MDM_PRK_ESCROW_CONFIGURATION_CHECK=$(profiles -P -o  stdout | grep "com.apple.security.FDERecoveryKeyEscrow")
	if [[ -z $MDM_PRK_ESCROW_CONFIGURATION_CHECK ]]; then
		MDM_PRK_ESCROW_STATUS='<td style="color: red;">FileVault key escrow is unmanaged</td>'
	else
		MDM_PRK_ESCROW_STATUS='<td style="color: green;">FileVault key escrow configuration found</td>'
	fi
	
	#Active Directory Domain
	AD_STATUS_CHECK=$(/usr/sbin/dsconfigad -show | /usr/bin/grep 'Active Directory Domain' | /usr/bin/awk '{print $5}')
		if [[ -z ${AD_STATUS_CHECK} ]];then
			AD_STATUS='<td style="color: green;">Not Bound</td>'
		else
			AD_STATUS="<td style=\"color: black\">${AD_STATUS_CHECK}</td>"
		fi
	
	#Content Cache report
	CONTENT_CACHE_CHECK=$(/usr/bin/AssetCacheLocatorUtil 2>&1 | /usr/bin/grep "guid" | /usr/bin/awk '{print$4}' | /usr/bin/sed -e 's/^\(.*\):.*$/\1/' -e 's/^/,/' | /usr/bin/sort -u | /usr/bin/sed 's/,//')
		if [[ -z ${CONTENT_CACHE_CHECK} ]];then
			CONTENT_CACHE_STATUS='<td style="color: black;">None</td>'
		else
			CONTENT_CACHE_STATUS="<td style=\"color: green\">${CONTENT_CACHE_CHECK}</td>"
		fi
	
	#Launch Daemons
	LAUNCH_DAEMONS_STATUS=$(/bin/launchctl list | /usr/bin/grep -v com.apple. | /usr/bin/cut -f3 | /usr/bin/sed 's|$|<br>|g' | /usr/bin/awk NR\>1)
	
	#Third-Party System Extensions
	KEXT_STATUS=$(/usr/sbin/kextstat | /usr/bin/grep -v com.apple | /usr/bin/awk '{print $6}' | /usr/bin/sed 's|$|<br>|g' | /usr/bin/awk NR\>1 )
	
	#MDM Gatekeep Configuration
	MDM_GATEKEEPER_CONFIGURATION_CHECK=$(profiles -P -o stdout | grep "com.apple.systempolicy.control")
	if [[ -z $MDM_GATEKEEPER_CONFIGURATION_CHECK ]];then
		MDM_GATEKEEPER_CONFIGURATION_STATUS='<td style="color: red;">Gatekeeper is unmanaged</td>'
	else
		MDM_GATEKEEPER_CONFIGURATION_STATUS='<td style="color: green;">A Gatekeeper profile has been found</td>'
	fi
	
	#Legacy Software Update Servers
	LEGACY_SWUS_CHECK=$(/usr/bin/defaults read /Library/Preferences/com.apple.SoftwareUpdate.plist CatalogURL)
	if [[ -z $LEGACY_SWUS_CHECK ]];then
		LEGACY_SWUS_STATUS='<td style="color: green;">None</td>'
	else
		LEGACY_SWUS_STATUS="<td style=\"color: red\">${LEGACY_SWUS_CHECK}</td>"
	fi
	
	#ADE Enabled
	ADE_ENROLLED_CHECK=$(profiles status -type enrollment | awk '/Enrolled via DEP:/{print $NF}')
	if [[ $ADE_ENROLLED_CHECK == "Yes" ]];then
		ADE_ENROLLED_STATUS='<td style="color: green;">Automated device enrollment is enabled.</td>'
	else
		ADE_ENROLLED_STATUS='<td style="color: red;">Automated device enrollment is not enabled</td>'
	fi
	
	#Enrolled into MDM Check
	MDM_ENROLLED_CHECK=$(profiles status -type enrollment | awk '/MDM enrollment:/{print $3, $4, $5}')
	if [[ $MDM_ENROLLED_CHECK == "Yes (User Approved)" ]]; then
		MDM_ENROLLED_STATUS="<td style=\"color: green\">$MDM_ENROLLED_CHECK</td>"
	else
		MDM_ENROLLED_STATUS='<td style="color: red;">No</td>'
	fi
	
	#MDM Server URL
	MDM_SERVER_URL=$(profiles status -type enrollment | awk '/MDM server:/{print $NF}' | sed 's|^http[s]://||g' | sed 's/\/.*//')
	MDM_SERVER_URL="<td style=\"color: black\">$MDM_SERVER_URL</td>"
	
	#MDM Controlled AutoLogin
	MDM_LOGIN_CONFIGURATION_CHECK=$(profiles -P -o stdout | grep "com.apple.login.mcx.DisableAutoLoginClient")
	if [[ -z $MDM_LOGIN_CONFIGURATION_CHECK ]]; then
		MDM_LOGIN_CONFIGURATION_STATUS='<td style="color: red;">Automatic login is unmanaged</td>'
	else
		MDM_LOGIN_CONFIGURATION_STATUS='<td style="color: green;">An automatic login profile has been found</td>'
	fi
	
	#Bootstrap Token
	BOOTSTRAP_TOKEN_CHECK=$(profiles status -type bootstraptoken | awk '/Bootstrap Token escrowed to server:/{print $NF}')
	if [[ $BOOTSTRAP_TOKEN_CHECK == "YES" ]]; then
		BOOTSTRAP_TOKEN_STATUS='<td style="color: green;">Bootstrap token escrowed to MDM server</td>'
	else
		BOOTSTRAP_TOKEN_STATUS='<td style="color: red;">Bootstrap token not escrowed to MDM server</td>'
	fi
	
	FIREWALL_CHECK=$(/usr/bin/defaults read /Library/Preferences/com.apple.alf globalstate)
	if [[ $FIREWALL_CHECK == "0" ]]; then
		FIREWALL_STATUS='<td style="color: red;">Disabled</td>'
	else
		FIREWALL_STATUS='<td style="color: green;">Enabled</td>'
	fi
	
	MDM_FIREWALL_CONFIGURATION_CHECK=$(profiles -P -o stdout | grep "com.apple.security.firewall")
	if [[ -z $MDM_FIREWALL_CONFIGURATION_CHECK ]]; then
		MDM_FIREWALL_CONFIGURATION_STATUS='<td style="color: red;">Firewall is unmanaged</td>'
	else
		MDM_FIREWALL_CONFIGURATION_STATUS='<td style="color: green;">A Firewall profile has been found</td>'
	fi
	
	#MDM Guest Profile Configuration
	MDM_GUEST_CONFIGURATION_CHECK=$(profiles -P -o stdout | grep 'DisableGuestAccount')
	if [[ -z $MDM_GUEST_CONFIGURATION_CHECK ]]; then
		MDM_GUEST_CONFIGURATION_STATUS='<td style="color: red;">Guest accounts are unmanaged</td>'
	else
		MDM_GUEST_CONFIGURATION_STATUS='<td style="color: green;">A guest profile configuration has been found</td>'
	fi
	
	#MDM Idle Time Configuration (Screensaver)
	MDM_SCREENSAVER_IDLE_TIME_CHECK=$(profiles -P -o stdout | grep "loginWindowIdleTime")
	if [[ -z $MDM_SCREENSAVER_IDLE_TIME_CHECK ]]; then
		MDM_SCREENSAVER_IDLE_TIME_STATUS='<td style="color: red;">Screensaver idle time is not managed</td>'
	else
		MDM_SCREENSAVER_IDLE_TIME_STATUS='<td style="color: red;">A screensaver idle time profile has been found</td>'
	fi
}


######################################################
# WHERE THE MAGIC HAPPENS
######################################################
#display status 
echo "[start] Starting tests"
echo "[step] Requesting network interface info..."

#used as a variable for populating local network data
sysProfilerNetworkData=$(/usr/sbin/system_profiler SPNetworkDataType 2> /dev/null)

######################################################
# WHERE THE FUNCTIONS ARE CALLLED
######################################################
#Functions are named as such, calculate 
#creates the blank HTML File
CreateEmptyReportFile
#add in HTML formatting
GenerateReportHTML

#calculates the proxy settings on the device
CalculateProxyInfoTableRows
#adds proxy table with headers and content from previous function to report
CreateProxyTable
#get active interface proxy details for network query
getProxyAddress
echo "[Info] Reported Proxy Host is ${PROXY_HOST}:${PROXY_PORT}"

#calculate the network connectivity 
CalculateHostInfoTables
#inserts the network connectivity information to the report
createNetworkCheckTable
#calculate additional check values
calculateAdditionalChecks
#Adds additional checks table
createAdditionalChecksHTML
#puts the share icon and path at the bottom of the report
createShareReport

#clean up Proxy File
/bin/rm ${PROXY_DATA_LOCATION}

#open -a "Safari" "${REPORT_PATH}"
echo '[Done] Environment Checks Complete'
echo "[acknowledgement] Host listings provided by Apple, Inc. (Public KB)"
echo "[acknowledgement] Icon plane by Juan Garces from the Noun Project, licensed under Create Commons (cc)"

#Get the serial number of the mac running this script.
serialNumber=$(system_profiler SPHardwareDataType | awk '/Serial Number/{print $4}')

#Use the API to get Computer ID
computerID=$(curl -su "$apiUsername":"$apiPassword" -H "Accept: application/xml" "$apiURL"/JSSResource/computers/serialnumber/"$serialNumber" | xmllint --xpath 'computer/general/id/text()' -)


fileToUpload=$(/bin/ls /Users/Shared/ | grep Mac)

# Need to upload ${REPORT_PATH}
fileToUpload=$(/bin/ls /Users/Shared | grep Mac)
#command to upload to Jamf Pro Server
curl -sfku "$apiUsername":"$apiPassword" "$apiURL"/JSSResource/fileuploads/computers/id/$computerID -F name=@/Users/Shared/"$fileToUpload" -X POST

#Check to status of the file upload
uploadStatus=$?

#Use Jamf Helper to display message to user
if [ $uploadStatus != 0 ]; then
	/usr/local/bin/jamf displayMessage -message "The sysdiagnose file FAILED to upload successfully to your computer record on the Jamf Pro Server.  Please contact the IT Department for assistance."
else
	/usr/local/bin/jamf displayMessage -message "The sysdiagnose file was uploaded successfully to your computer record on the Jamf Pro Server."
fi

#Use upload exit status to exit the script with 0 for success or 1 for failure.

if [ $uploadStatus != 0 ]; then
	exit 1
else
	exit 0
fi