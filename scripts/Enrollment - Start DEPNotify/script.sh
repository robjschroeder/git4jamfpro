#!/usr/bin/env sh

####################################################################################################
#
# This Insight Software is provided by Insight on an "AS IS" basis.
#
# INSIGHT MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION THE IMPLIED 
# WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY, AND FITNESS FOR A PARTICULAR # PURPOSE, 
# REGARDING THE INSIGHT SOFTWARE OR ITS USE AND OPERATION ALONE OR IN COMBINATION WITH YOUR 
# PRODUCTS.
#
# IN NO EVENT SHALL INSIGHT BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL OR CONSEQUENTIAL 
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, 
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION, 
# MODIFICATION AND/OR DISTRIBUTION OF THE INSIGHT SOFTWARE, HOWEVER, CAUSED AND WHETHER UNDER 
# THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE), STRICT LIABILITY OR OTHERWISE, EVEN IF INSIGHT 
# HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
####################################################################################################
#
# Start DEPNotify Script
#
# Author: Alex Fajerman (alex.fajerman@insight.com)
# Creation date: 2022-03-04
# Last modified date: 2022-06-28
#
####################################################################################################
#
# DESCRIPTION
#
# Master script for DEPNotify used for Mac enrollments in Jamf.
#
####################################################################################################

####################################################################################################
# VARIABLES
####################################################################################################
# General
Version=5.2
Here=$(/usr/bin/dirname "$0")
ScriptName=$(/usr/bin/basename "$0" | /usr/bin/awk -F "." '{print $1}')

# Local System Info
CurrentUser=$(scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ { print $3 }')
SystemArch=$(/usr/bin/arch)
SerialNumber=$(/usr/sbin/ioreg -c IOPlatformExpertDevice -d 2 | /usr/bin/awk '/IOPlatformSerialNumber/ { gsub(/\"/, ""); print $NF;}')

# Log File
EnrollmentLogFile="$ScriptName-$(date +"%Y-%m-%d").log"

# Answer File
AnswerFile="/Library/Managed Preferences/com.insight.answer.plist"

####################################################################################################
# JAMF BUILT-IN VARIABLES VALIDATION
####################################################################################################
# Fullscreen Mode
if [[ "$4" != "" ]]; then
	Fullscreen="$4"
else
	Fullscreen=true
fi

# No Sleep / Caffeinate Mode
if [[ "$5" != "" ]]; then
	EnableNoSleep="$5"
else
	EnableNoSleep=true
fi

####################################################################################################
# ANSWER FILE FUNCTIONS, CONTROL & VARIABLES
####################################################################################################
CheckAnswerFile() {
	# Checks for the answer file. If it doesn't exist after 30 seconds, exits with error 1.
	
	Counter=0
	FailCount=30
	/bin/echo "Checking for answer file at ${AnswerFile}"
	while [[ ! -e "${AnswerFile}"  ]]; do
		/bin/sleep 1
		Counter=$((Counter + 1))
		if [[ "$Counter" = "$FailCount" ]]; then
			/bin/echo "Waited $FailCount seconds for $AnswerFile, aborting with exit 1" "ERROR"
			exit 1
		fi
	done
	/bin/echo "Answer file found, proceeding"
}

GetAnswer() {
	# Returns a single value from the answer file.
	#
	# NOTES
	# - Other variables in this script can be called from the value in the answer file
	# - Special character such as ; need to be escaped with a preceeding \ (ex: \;)
	#
	# PARAMETERS
	# $1 = Section and optional subsection(s)
	# - Example: OrgInfo
	# $2 = Value to parse
	# - Example: OrgName
	#
	# USAGE
	# Example: OrgName=$(GetAnswer "OrgInfo" "OrgName")
	
	eval echo $(/usr/libexec/PlistBuddy -c "print :$1:$2" "$AnswerFile")
}

GetList() {
	# Return a list of values from an array in the answer file.
	#
	# NOTES
	# - Values in the array cannot contain variables
	# - The variable called must be an array (see example below)
	#
	# PARAMETERS
	# $1 = Section and optional subsection(s)
	# - Example: EnrollmentScript:Policies
	# $2 = List to parse
	# - Example: PoliciesList
	#
	# USAGE
	# Example: PoliciesList=($(GetList "EnrollmentScript:Policies" "PoliciesList"))
	
	declare -a List=($(/usr/libexec/PlistBuddy -c "print :$1:$2" "$AnswerFile" | sed -e 1d -e '$d'))
	for i in "${List[@]}"; do
		echo "${i[0]}" | awk '{print substr($0,5)}'
	done
}

# Checks for the answer file.
CheckAnswerFile

# Sets the internal field separator to newline so answer file variables are properly parsed.
IFS=$'\n'

# Organization Info
OrgName=$(GetAnswer "OrgInfo" "OrgName")
JamfURL=$(GetAnswer "OrgInfo" "JamfURL")

# Logging
EnrollmentLogPath=$(GetAnswer "EnrollmentScript:Logging" "EnrollmentLogPath")

# Jamf Binary
JamfBinary=$(GetAnswer "EnrollmentScript:JamfBinary" "JamfBinary")
JamfBinaryPath=$(GetAnswer "EnrollmentScript:JamfBinary" "JamfBinaryPath")

# DEPNotify - Install Info
DEPNotifyInstallPolicy=$(GetAnswer "EnrollmentScript:DEPNotify:InstallInfo" "DEPNotifyInstallPolicy")
DEPNotifyPath=$(GetAnswer "EnrollmentScript:DEPNotify:InstallInfo" "DEPNotifyPath")
DEPNotifyApp=$(GetAnswer "EnrollmentScript:DEPNotify:InstallInfo" "DEPNotifyApp")

# DEPNotify - PreStage Files
DEPNotifyScriptsPath=$(GetAnswer "EnrollmentScript:DEPNotify:PreStageInfo" "DEPNotifyScriptsPath")
DEPNotifyEnrollmentStartScript=$(GetAnswer "EnrollmentScript:DEPNotify:PreStageInfo" "DEPNotifyEnrollmentStartScript")
DEPNotifyEnrollmentInstallerError=$(GetAnswer "EnrollmentScript:DEPNotify:PreStageInfo" "DEPNotifyEnrollmentInstallerError")
DEPNotifyEnrollmentInstallerOut=$(GetAnswer "EnrollmentScript:DEPNotify:PreStageInfo" "DEPNotifyEnrollmentInstallerOut")
DEPNotifyLaunchDaemonPath=$(GetAnswer "EnrollmentScript:DEPNotify:PreStageInfo" "DEPNotifyLaunchDaemonPath")
DEPNotifyLaunchDaemonFile=$(GetAnswer "EnrollmentScript:DEPNotify:PreStageInfo" "DEPNotifyLaunchDaemonFile")

# DEPNotify - Temp Files
DEPNotifyTmpPath=$(GetAnswer "EnrollmentScript:DEPNotify:TempFiles" "DEPNotifyTmpPath")
DEPNotifyLogFile=$(GetAnswer "EnrollmentScript:DEPNotify:TempFiles" "DEPNotifyLogFile")
DEPNotifyDebugLogFile=$(GetAnswer "EnrollmentScript:DEPNotify:TempFiles" "DEPNotifyDebugLogFile")
DEPNotifyNewPlist=$(GetAnswer "EnrollmentScript:DEPNotify:TempFiles" "DEPNotifyNewPlist")
DEPNotifyDoneBOM=$(GetAnswer "EnrollmentScript:DEPNotify:TempFiles" "DEPNotifyDoneBOM")
DEPNotifyLogoutBOM=$(GetAnswer "EnrollmentScript:DEPNotify:TempFiles" "DEPNotifyLogoutBOM")
DEPNotifyRestartBOM=$(GetAnswer "EnrollmentScript:DEPNotify:TempFiles" "DEPNotifyRestartBOM")
DEPNotifyAgreeBOM=$(GetAnswer "EnrollmentScript:DEPNotify:TempFiles" "DEPNotifyAgreeBOM")
DEPNotifyRegistrationDoneBOM=$(GetAnswer "EnrollmentScript:DEPNotify:TempFiles" "DEPNotifyRegistrationDoneBOM")

# Error Screen Branding
ErrorBannerTitle=$(GetAnswer "EnrollmentScript:ErrorControl" "ErrorBannerTitle")
ErrorMainText=$(GetAnswer "EnrollmentScript:ErrorControl" "ErrorMainText")
ErrorStatus=$(GetAnswer "EnrollmentScript:ErrorControl" "ErrorStatus")

# Computer Naming
EnableSetComputerName=$(GetAnswer "EnrollmentScript:ComputerNaming" "EnableSetComputerName")
ComputerNamePrefix=$(GetAnswer "EnrollmentScript:ComputerNaming" "ComputerNamePrefix")
EnableCustomComputerName=$(GetAnswer "EnrollmentScript:ComputerNaming" "EnableCustomComputerName")
CustomComputerNamesList=($(GetList "EnrollmentScript:ComputerNaming" "CustomComputerNamesList"))
CustomComputerSerialsList=($(GetList "EnrollmentScript:ComputerNaming" "CustomComputerSerialsList"))

# Appearance And Branding
PolicyDefaultIcon=$(GetAnswer "EnrollmentScript:AppearanceAndBranding" "PolicyDefaultIcon")
EnableCustomIcon=$(GetAnswer "EnrollmentScript:AppearanceAndBranding" "EnableCustomIcon")
CustomIconLocation=$(GetAnswer "EnrollmentScript:AppearanceAndBranding" "CustomIconLocation")
CustomIconDownloadPath=$(GetAnswer "EnrollmentScript:AppearanceAndBranding" "CustomIconDownloadPath")
CustomIconDownloadFile=$(GetAnswer "EnrollmentScript:AppearanceAndBranding" "CustomIconDownloadFile")
BannerTitle=$(GetAnswer "EnrollmentScript:AppearanceAndBranding" "BannerTitle")
MainText=$(GetAnswer "EnrollmentScript:AppearanceAndBranding" "MainText")
InitialStartStatus=$(GetAnswer "EnrollmentScript:AppearanceAndBranding" "InitialStartStatus")
InstallCompleteText=$(GetAnswer "EnrollmentScript:AppearanceAndBranding" "InstallCompleteText")
StatusTextAlignment=$(GetAnswer "EnrollmentScript:AppearanceAndBranding" "StatusTextAlignment")

# Help Bubble
EnableHelpBubble=$(GetAnswer "EnrollmentScript:HelpBubble" "EnableHelpButton")
HelpContactName=$(GetAnswer "EnrollmentScript:HelpBubble" "HelpContactName")
HelpContactInfo=$(GetAnswer "EnrollmentScript:HelpBubble" "HelpContactInfo")
HelpBubbleTitle=$(GetAnswer "EnrollmentScript:HelpBubble" "HelpBubbleTitle")
HelpBubbleBody=$(GetAnswer "EnrollmentScript:HelpBubble" "HelpBubbleBody")

# Policies
PoliciesList=($(GetList "EnrollmentScript:Policies" "PoliciesList"))

# Jamf Connect
ResetJamfConnectLogin=$(GetAnswer "EnrollmentScript:JamfConnect" "ResetJamfConnectLogin")

# Stub Files
EnableCreateStubFiles=$(GetAnswer "EnrollmentScript:StubFiles" "EnableCreateStubFiles")
StubFilesList=($(GetList "EnrollmentScript:StubFiles" "StubFilesList"))

# Jamf Recon
UpdateUsernameInventoryRecord=$(GetAnswer "EnrollmentScript:JamfRecon" "UpdateUsernameInventoryRecord")

# Script Completion
RestartWhenDone=$(GetAnswer "EnrollmentScript:ScriptCompletion" "RestartWhenDone")

# Script Completion - Restart
CompletionRestartButtonText=$(GetAnswer "EnrollmentScript:ScriptCompletion:Restart" "CompletionRestartButtonText")
CompletionRestartMainText=$(GetAnswer "EnrollmentScript:ScriptCompletion:Restart" "CompletionRestartMainText")
EnableMDMRestart=$(GetAnswer "EnrollmentScript:ScriptCompletion:Restart" "EnableMDMRestart")
MDMRestartCommandPolicy=$(GetAnswer "EnrollmentScript:ScriptCompletion:Restart" "MDMRestartCommandPolicy")
EnableRestartTimer=$(GetAnswer "EnrollmentScript:ScriptCompletion:Restart" "EnableRestartTimer")
RestartTimer=$(GetAnswer "EnrollmentScript:ScriptCompletion:Restart" "RestartTimer")
RestartTimerText=$(GetAnswer "EnrollmentScript:ScriptCompletion:Restart" "RestartTimerText")

# Script Completion - Quit
CompletionQuitButtonText=$(GetAnswer "EnrollmentScript:ScriptCompletion:Quit" "CompletionQuitButtonText")
CompletionQuitMainText=$(GetAnswer "EnrollmentScript:ScriptCompletion:Quit" "CompletionQuitMainText")

####################################################################################################
# FUNCTIONS
####################################################################################################
GetTimestamp() {
	# Timestamp function. Used to echo the date/time to the DEPNotify debug log file.
	
	if [[ $1 == "START" ]]; then
		TimestampInfo="START"
	elif [[ $1 == "INFO" ]]; then
		TimestampInfo="INFO"
	elif [[ $1 == "WARN" ]]; then
		TimestampInfo="WARN"
	elif [[ $1 == "ERROR" ]]; then
		TimestampInfo="ERROR"
	elif [[ $1 == "DEBUG" ]]; then
		TimestampInfo="DEBUG"
	elif [[ $1 == "FINISH" ]]; then
		TimestampInfo="FINISH"
	elif [[ $1 == "TEST" ]]; then
		TimestampInfo="TEST"
	else
		TimestampInfo="INFO"
	fi
	echo $(date +"[[%b %d, %Y %Z %T $TimestampInfo]]: ")
}

Logging() {
	# Logging function. Used to write actions to the enrollment log file.
	#
	# PARAMETERS
	# $1 = Text to write to the log
	# - Example: This is a test
	# $2 = (optional) Info level for the log entry; default is INFO
	# - Example: WARN
	#
	# USAGE
	# Example: Logging "This is a test" "WARN"
	
	
	if [[ $2 == "START" ]]; then
		LogInfo="START"
	elif [[ $2 == "INFO" ]]; then
		LogInfo="INFO"
	elif [[ $2 == "WARN" ]]; then
		LogInfo="WARN"
	elif [[ $2 == "ERROR" ]]; then
		LogInfo="ERROR"
	elif [[ $2 == "DEBUG" ]]; then
		LogInfo="DEBUG"
	elif [[ $2 == "FINISH" ]]; then
		LogInfo="FINISH"
	elif [[ $1 == "TEST" ]]; then
		LogInfo="TEST"
	else
		LogInfo="INFO"
	fi
	printf "$(date +"[[%b %d, %Y %Z %T $LogInfo]]: ")$1\n" >> "$EnrollmentLogPath/$EnrollmentLogFile"
}

GetCurrentUser() {
	# Return the current user's username.
	
	/bin/echo "show State:/Users/ConsoleUser" | /usr/sbin/scutil | /usr/bin/awk '/Name :/ && ! /loginwindow/ {print $3}'
}

GetCurrentUserUID() {
	# Return the current user's UID.
	
	/bin/echo $(/usr/bin/dscl . -list /Users UniqueID | /usr/bin/grep "$(GetCurrentUser)" | /usr/bin/awk '{print $2}' | /usr/bin/sed -e 's/^[ \t]*//')
}

GetRealName() {
	# Returns the current user's real name.
	
	/bin/echo $(id -P $(GetCurrentUser) | cut -d : -f 8)
}

LoggingHeader() {
	# Creates the enrollment log header.
	
	Logging "" "START"
	Logging "--- START DEVICE ENROLLMENT LOG ---" "START"
	Logging "" "START"
	Logging "$ScriptName Version $Version" "START"
	Logging "Answer File: $AnswerFile"
	Logging "" "START"
}

LoggingFooter() {
	# Creates the enrollment log footer.
	
	Logging "" "FINISH"
	Logging "--- FINISH DEVICE ENROLLMENT LOG ---" "FINISH"
	Logging "" "FINISH"
}

GetTimerNoun() {
	# Prettified return for printing out "1 second" or ">1 seconds".
	
	if [[ $1 == 1 ]]; then
		echo "$1 second"
	else
		echo "$1 seconds"
	fi
}

ValidateTrueFalseFlags() {
	# Validates true/false flags that are set in this script's parameters in the Jamf policy.
	
	if [[ "$Fullscreen" != true ]] && [[ "$Fullscreen" != false ]]; then
		/bin/echo "$(GetTimestamp "DEBUG") Fullscreen configuration not set properly. Currently set to $Fullscreen. Please update to true or false." >> "$DEPNotifyTmpPath/$DEPNotifyDebugLogFile"
		Logging "Fullscreen configuration not set properly. Currently set to $Fullscreen. Please update to true or false." "DEBUG"
		exit 1
	fi
	
	if [[ "$EnableNoSleep" != true ]] && [[ "$EnableNoSleep" != false ]]; then
		/bin/echo "$(GetTimestamp "DEBUG") Enable No Sleep configuration not set properly. Currently set to $EnableNoSleep. Please update to true or false." >> "$DEPNotifyTmpPath/$DEPNotifyDebugLogFile"
		Logging "Enable No Sleep configuration not set properly. Currently set to $EnableNoSleep. Please update to true or false." "DEBUG"
		exit 1
	fi
}

GetSetupAssistantProcess() {
	# Waits for Setup Assisant to finish before continuing.
	
	ProcessName="Setup Assistant"
	SetupAssistantProcess=""
	SleepTimer=5
	Logging "Checking to see if $ProcessName is running"
	
	while [[ $SetupAssistantProcess != "" ]]; do
		Logging "$ProcessName still running  PID: $SetupAssistantProcess"
		Logging "Sleeping $(GetTimerNoun $SleepTimer)"
		/bin/sleep $SleepTimer
		SetupAssistantProcess=$(/usr/bin/pgrep -l "$ProcessName")
	done
	Logging "$ProcessName finished"
}

WaitForCurrentUser() {
	# Checks the current user's UID and username; if UID is less than 501 or the username is blank, loops and waits until the user is logged in. Once the UID is equal to or greater than 501 or the username is present, this script proceeds. This is to prevent a scenario where a system account such as SetupAssistant is still doing stuff and DEPNotify tries to start.
	
	CurrentUserUID=$(GetCurrentUserUID)
	while [[ $CurrentUserUID -lt 501 || $(GetCurrentUser) == "" ]]; do
		Logging "User is not logged in, waiting"
		/bin/sleep 5
		CurrentUserUID=$(GetCurrentUserUID)
	done
	Logging "Current user: $(GetCurrentUser) with UID $(GetCurrentUserUID)"
}

GetFinderProcess() {
	# Checks to see if the Finder is running yet. If it is, continue. Nice for instances where the user is not setting up a username during the Setup Assistant process.
	
	Logging "Checking to see if the Finder process is running"
	FinderProcess=$(/usr/bin/pgrep -l "Finder" 2>/dev/null)
	Response=$?
	Logging "Finder PID: $FinderProcess"
	while [[ $Response -ne 0 ]]; do
		Logging "Finder PID not found. Assuming device is sitting at the login window"
		/bin/sleep 1
		FinderProcess=$(/usr/bin/pgrep -l "Finder" 2>/dev/null)
		Response=$?
		if [[ $FinderProcess != "" ]]; then
			Logging "Finder PID: $FinderProcess"
		fi
	done
}

CheckForAppleSilicon() {
	# Checks the CPU architecture and installs Rosetta2 if the Mac is on Apple Silicon.
	
	Logging "Checking for Apple Silicon"
	if [[ "$SystemArch" == "arm64" ]]; then
		Logging "Running on Apple Silicon"
		Logging "Installing Rosetta 2 for compatibility with Intel-based apps"
		/usr/sbin/softwareupdate --install-rosetta --agree-to-license
	else
		Logging "Not on Apple Silicon, skipping Rosetta 2"
	fi
}

CheckForDEPNotify() {
	# Checks to ensure that DEPNotify is installed before moving on to the next step
	# If it is not installed, attempts to reinstall it by downloading and installing it via Jamf policy.
	# If DEPNotify cannot be installed via policy, this script will exit after 30 seconds of waiting.
	
	Counter=0
	FailCount=30
	WaitTimer=5
	Logging "Making sure DEPNotify is installed"
	while [[ ! -e "${DEPNotifyPath}/${DEPNotifyApp}" ]]; do
		Logging "DEPNotify has not been installed yet"
		if [[ ! -e "${DEPNotifyPath}/${DEPNotifyApp}" ]] && [[ "$Counter" -eq $WaitTimer ]]; then
			# If DEPNotify is not installed, attempt to install it via Jamf policy
			
			Logging "Waited $(GetTimerNoun $WaitTimer) for DEPNotify"
			Logging "Downloading and installing DEPNotify via Jamf policy ${DEPNotifyInstallPolicy}"
			"$JamfBinaryPath/$JamfBinary" policy -event "${DEPNotifyInstallPolicy}"
		fi
		Logging "Waiting $(GetTimerNoun 1) before checking again"
		/bin/sleep 1
		Counter=$((Counter + 1))
		if [[ "$Counter" = "$FailCount" ]]; then
			Logging "We waited $(GetTimerNoun $FailCount), it did not install, aborting with exit 1" "ERROR"
			exit 1
		fi
	done
	Logging "Found DEPNotify at ${DEPNotifyPath}/${DEPNotifyApp}"
}

CheckForDEPNotifyBOMs() {
	# Checks and Warnings if BOM files exist.
	
	Logging "Script testing check"
	if [[ (-f "$DEPNotifyTmpPath/$DEPNotifyLogFile" || -f "$DEPNotifyTmpPath/$DEPNotifyDoneBOM") ]]; then
		/bin/echo "$(GetTimestamp "ERROR") Config files were found in /var/tmp. Letting user know and exiting." >> "$DEPNotifyTmpPath/$DEPNotifyDebugLogFile"
		mv "$DEPNotifyTmpPath/$DEPNotifyLogFile" "$DEPNotifyTmpPath/depnotify_old.log"
		/bin/echo "Command: MainTitle: $ErrorBannerTitle" >> "$DEPNotifyTmpPath/$DEPNotifyLogFile"
		/bin/echo "Command: MainText: $ErrorMainText" >> "$DEPNotifyTmpPath/$DEPNotifyLogFile"
		/bin/echo "Status: $ErrorStatus" >> "$DEPNotifyTmpPath/$DEPNotifyLogFile"
		sudo -u "$(GetCurrentUser)" open -a "${DEPNotifyPath}/${DEPNotifyApp}" --args -path "$DEPNotifyTmpPath/$DEPNotifyLogFile"
		/bin/sleep 5
		exit 1
	fi
}

GeneratePlistConfig() {
	# Creates the .plist for DEPNotify to use for various extra settings.
	
	DEPNotifyConfigPlist="/Users/$(GetCurrentUser)/Library/Preferences/menu.nomad.DEPNotify.plist"
	Logging "DEPNotify preferences file will be stored at $DEPNotifyConfigPlist"
	
	# Writes settings for status text alignment.
	Logging "Plist Setting: Setting statusTextAlignment to $StatusTextAlignment"
	defaults write "$DEPNotifyConfigPlist" statusTextAlignment "$StatusTextAlignment"
	
	# Writes settings for the help bubble.
	if [[ "$EnableHelpBubble" == true ]]; then
		Logging "Plist Setting: Setting help bubble options"
		defaults write "$DEPNotifyConfigPlist" helpBubble -array-add "$HelpBubbleTitle"
		defaults write "$DEPNotifyConfigPlist" helpBubble -array-add "$HelpBubbleBody"
	fi
	
	# Sets ownership and permissions of the .plist.
	Logging "Setting ownership and permissions of $DEPNotifyConfigPlist"
	chown "$(GetCurrentUser)":staff "$DEPNotifyConfigPlist"
	chmod 600 "$DEPNotifyConfigPlist"
}

SetComputerName() {
	# Sets the computer name. EnableSetComputerName must be set to true in the answer file; otherwise, no name is set.
	#
	# If EnableSetComputerName is true, the following logic applies:
	# - EnableCustomComputerName
	#		false: Set the name to PrefixSerialNumber
	#		true: Check the CustomComputerSerialsList and CustomComputerNamesList arrays for a match and rename if found

	if [[ $EnableSetComputerName == true ]]; then
		# Setting a custom name.
		if [[ $EnableCustomComputerName == true ]]; then
			Logging "Custom naming enabled, checking Mac serial number $SerialNumber"
		
			# Check the list of known serials for a match.
			for i in "${!CustomComputerSerialsList[@]}"; do
				if [[ " ${CustomComputerSerialsList[$i]} " =~ " $SerialNumber " ]]; then
					Logging "Serial $SerialNumber found in custom names list"
					MatchFound=true
					break
				else
					MatchFound=false
				fi
			done
			
			if [[ $MatchFound == true ]]; then
				# Mac SN is in the list, checking to see if there's a corresponding name.
				if [[ ${CustomComputerNamesList[$i]} = "" ]]; then
					Logging "Serial/name match not found"
					MacName="$ComputerNamePrefix$SerialNumber"
				else
					MacName="${CustomComputerNamesList[$i]}"
					Logging "Serial/name match found ($SerialNumber, $MacName)"
				fi
			else
				# Mac SN not matched, using the default naming scheme.
				Logging "No match, defaulting to $ComputerNamePrefix$SerialNumber"
				MacName="$ComputerNamePrefix$SerialNumber"
			fi
		else
			Logging "Custom Mac naming not enabled, setting name to $ComputerNamePrefix$SerialNumber"
			MacName="$ComputerNamePrefix$SerialNumber"
		fi
		Logging "Setting computer name to $MacName"
		
		# Set the computer name using scutil.
		/usr/sbin/scutil --set ComputerName "$MacName"
		/usr/sbin/scutil --set LocalHostName "$MacName"
		/usr/sbin/scutil --set HostName "$MacName"
	
		# Set the computer name using Jamf binary.
		"$JamfBinaryPath/$JamfBinary" setComputerName -name "$MacName"
		Return="$?"
	
		if [[ "$Return" -ne 0 ]]; then
			# Naming failed.
			Logging "Failed to set computer name with Jamf name command"
			ReturnCode="$Return"
		fi
	
		# Flush DNS cache.
		dscacheutil -flushcache
	else
		Logging "Not setting the computer name"
	fi
}

CustomBranding() {
	# Sets up branding for the DEPNotify window.
	
	Logging "Setting up branding for banner image, banner title and main text"
	if [[ "$EnableCustomIcon" == true ]]; then
		Logging "Using a custom icon"
		if [[ $CustomIconLocation = http* ]]; then
			Logging "Icon location is a URL"
			if [[ ! -d "$CustomIconDownloadPath" ]]; then
				Logging "$CustomIconDownloadPath not found, creating"
				mkdir -p "$CustomIconDownloadPath"
			fi
			Logging "Grabbing icon from $CustomIconLocation"
			curl -L -o "$CustomIconDownloadPath/$CustomIconDownloadFile" $CustomIconLocation
			if [[ -s "$CustomIconDownloadPath/$CustomIconDownloadFile" ]]; then
				Logging "Custom icon successfully dowloaded to $CustomIconDownloadPath/$CustomIconDownloadFile"
				PolicyDefaultIcon="$CustomIconDownloadPath/$CustomIconDownloadFile"
			else
				Logging "File is empty, deleting and using default $PolicyDefaultIcon"
				sudo rm -f "${CustomIconPath}/${CustomIconFile}"
			fi
		elif [[ $CustomIconLocation = /* ]]; then
			Logging "Icon is local"
			PolicyDefaultIcon="$CustomIconLocation"
		else
			Logging "Custom icon location is invalid, using $PolicyDefaultIcon"
		fi
	else
		Logging "Not using a custom icon, using $PolicyDefaultIcon"
	fi
	/bin/echo "Command: Image: $PolicyDefaultIcon" >> "$DEPNotifyTmpPath/$DEPNotifyLogFile"
	/bin/echo "Command: MainTitle: $BannerTitle" >> "$DEPNotifyTmpPath/$DEPNotifyLogFile"
	/bin/echo "Command: MainText: $MainText" >> "$DEPNotifyTmpPath/$DEPNotifyLogFile"
}

LaunchDEPNotify() {
	# Opens the DEPNotiy app after initial configuration.
	
	Logging "Removing the quarantine bit from the DEPNotify app"
	sudo xattr -r -d com.apple.quarantine "${DEPNotifyPath}/${DEPNotifyApp}"
	Logging "Opening DEPNotify as user $(GetCurrentUser)"
	if [[ "$Fullscreen" == true ]]; then
		sudo -u "$(GetCurrentUser)" /usr/bin/open -a "${DEPNotifyPath}/${DEPNotifyApp}" --args -path "$DEPNotifyTmpPath/$DEPNotifyLogFile" -fullScreen
	elif [[ "$Fullscreen" == false ]]; then
		sudo -u "$(GetCurrentUser)" /usr/bin/open -a "${DEPNotifyPath}/${DEPNotifyApp}" --args -path "$DEPNotifyTmpPath/$DEPNotifyLogFile"
	fi
}

GetDEPNotifyProcess() {
	# Grab sthe DEPNotify PID and caffeinates it.
	
	DEPNotifyProcess=$(pgrep -l "DEPNotify" | cut -d " " -f1)
	until [[ "$DEPNotifyProcess" != "" ]]; do
		Logging "Waiting for DEPNotify to start to gather the process ID"
		/bin/echo "$(GetTimestamp) Waiting for DEPNotify to start to gather the process ID" >> "$DEPNotifyTmpPath/$DEPNotifyDebugLogFile"
		/bin/sleep 1
		DEPNotifyProcess=$(pgrep -l "DEPNotify" | cut -d " " -f1)
	done
	if [[ "$EnableNoSleep" == true ]]; then
		Logging "Caffeinating DEPNotify process (PID: $DEPNotifyProcess)"
		caffeinate -disu -w "$DEPNotifyProcess" &
	fi
}

PrettyPause() {
	# Adds an initial status text and a brief pause for prettiness.
	
	/bin/echo "Status: $InitialStartStatus" >> "$DEPNotifyTmpPath/$DEPNotifyLogFile"
	/bin/sleep 3
}

GenerateStatusBar() {
	# Sets up the status bar.
	
	# Increments the status counter by 1 to account for the Jamf recon that runs at the end of this script.
	AdditionalOptionsCounter=1
	AdditionalOptionsCounter=$((AdditionalOptionsCounter++))
	
	# Checks the policy array and adds the count from the additional options above.
	PoliciesListLength="$((${#PoliciesList[@]} + AdditionalOptionsCounter))"
	/bin/echo "Command: Determinate: $PoliciesListLength" >> "$DEPNotifyTmpPath/$DEPNotifyLogFile"
}

RunJamfPolicies() {
	# Installs policies by looping through the policy array.
	
	Logging "--- START POLICIES ---"
	Logging "Preparing to run Jamf policies"
	for policy in "${PoliciesList[@]}"; do
		PolicyStatus=$(/bin/echo "$policy" | cut -d ',' -f1)
		PolicyType=$(/bin/echo "$policy" | cut -d ',' -f2)
		PolicyName=$(/bin/echo "$policy" | cut -d ',' -f3)
		PolicyIcon=$(/bin/echo "$policy" | cut -d ',' -f4)
		Logging "-------------------------"
		Logging "Calling policy $PolicyStatus"
		Logging "Policy type is: $PolicyType"
		/bin/echo "Status: $PolicyStatus" >> "$DEPNotifyTmpPath/$DEPNotifyLogFile"
		if [[ "$PolicyIcon" = "" ]] || [[ ! -f "$PolicyIcon" ]]; then
			# Icon path/file is either not set or not found; set to PolicyDefaultIcon.
			/bin/echo "Command: Image: $PolicyDefaultIcon" >> "$DEPNotifyTmpPath/$DEPNotifyLogFile"
		else
			# Icon found
			/bin/echo "Command: Image: $PolicyIcon" >> "$DEPNotifyTmpPath/$DEPNotifyLogFile"
		fi
		if [[ $PolicyType = "event" ]]; then
			"$JamfBinaryPath/$JamfBinary" policy -event "$PolicyName" | /usr/bin/sed -e "s/^/$(GetTimestamp) /" | /usr/bin/tee -a "$EnrollmentLogPath/$EnrollmentLogFile" >/dev/null 2>&1
		elif [[ $PolicyType = "id" ]]; then
			"$JamfBinaryPath/$JamfBinary" policy -id "$PolicyName" | /usr/bin/sed -e "s/^/$(GetTimestamp) /" | /usr/bin/tee -a "$EnrollmentLogPath/$EnrollmentLogFile" >/dev/null 2>&1
		else
			Logging "Invalid policy type or no policy type specified"
		fi
	done
	Logging "--- END POLICIES ---"
}

CheckJamfConnectLoginWindow() {
	# Resets the login window to macOS default if ResetJamfConnectLogin is true and Jamf Connect is installed.

	if [[ "$ResetJamfConnectLogin" == true ]]; then
		if [[ -e "$AuthchangerBinary" ]]; then
			Logging "Invoking Jamf Connect authchanger and resetting login window to macOS default"
			"$AuthchangerBinary" -reset
		else
			Logging "ResetJamfConnectLogin is set to true but authchanger binary not found at $AutchangerBinary"
		fi
	fi
}

CreateStubFiles() {
	# Create stub files based on the StubFilesList array.
	
	Logging "Stub Files Creation"
	if [[ "$EnableCreateStubFiles" == true ]]; then
		for File in "${StubFilesList[@]}"; do
			Logging "Creating stub file $File"
			/usr/bin/touch "${File}"
		done
	fi
}

JamfCheckIn() {
	# Forces the Mac to check in to Jamf and submit inventory.
	
	/bin/echo "Status: Submitting device inventory to Jamf" >> "$DEPNotifyTmpPath/$DEPNotifyLogFile"
	if [[ "$UpdateUsernameInventoryRecord" == true ]]; then
		Logging "Submitting device inventory to Jamf and updating the Mac's record with username and real name info"
		"$JamfBinaryPath/$JamfBinary" recon -endUsername "$(GetCurrentUser)" -realname "$(GetRealName)"
	else
		Logging "Submitting device inventory to Jamf"
		"$JamfBinaryPath/$JamfBinary" recon
	fi
}

ScriptCompletion() {
	# Sets script completion text, button and restart behaviors.

	/bin/echo "Status: $InstallCompleteText" >> "$DEPNotifyTmpPath/$DEPNotifyLogFile"
	if [[ "$RestartWhenDone" == true ]]; then
		if [[ "$EnableRestartTimer" == true ]]; then
			Logging "Script Completion: Automatic Restart with $(GetTimerNoun $RestartTimer) delay"
			/bin/echo "Command: MainText: $RestartTimerText" >> "$DEPNotifyTmpPath/$DEPNotifyLogFile"
			Timer=$RestartTimer
			until [[ $Timer = 0 ]]; do
				if [[ $Timer = 1 ]]; then
					/bin/echo "Status: Restarting in $(GetTimerNoun $Timer)" >> "$DEPNotifyTmpPath/$DEPNotifyLogFile"
					/bin/sleep 1
				else
					/bin/echo "Status: Restarting in $(GetTimerNoun $Timer)" >> "$DEPNotifyTmpPath/$DEPNotifyLogFile"
					/bin/sleep 1
				fi
				Timer=$((Timer-1))
			done
			touch "$DEPNotifyTmpPath/$DEPNotifyDoneBOM"
			/bin/echo "Command: Quit" >> "$DEPNotifyTmpPath/$DEPNotifyLogFile"
		else
			Logging "Script Completion: Restart with Button"
			touch "$DEPNotifyTmpPath/$DEPNotifyDoneBOM"
			/bin/echo "Command: MainText: $CompletionRestartMainText" >> "$DEPNotifyTmpPath/$DEPNotifyLogFile"
			/bin/echo "Command: ContinueButton: $CompletionRestartButtonText" >> "$DEPNotifyTmpPath/$DEPNotifyLogFile"
		fi
		Logging "Setting up restart behavior"
		if [[ "$EnableMDMRestart" == true ]]; then
			Logging "Restart Command: Jamf policy $MDMRestartCommandPolicy"
		else
			Logging "Restart Command: shutdown -r now"
		fi
	else
		Logging "Script Completion: Quit Button with Label"
		touch "$DEPNotifyTmpPath/$DEPNotifyDoneBOM"
		/bin/echo "Command: MainText: $CompletionQuitMainText" >> "$DEPNotifyTmpPath/$DEPNotifyLogFile"
		/bin/echo "Command: ContinueButton: $CompletionQuitButtonText" >> "$DEPNotifyTmpPath/$DEPNotifyLogFile"
	fi
}

DEPNotifyCleanup() {
	# Removes the files and directories left behind by DEPNotify once the Mac setup is complete.
	
	Logging "--- START DEPNOTIFY CLEANUP ---"

	# Waits for the DEPNotify window to close.
	while [[ ! -f "$DEPNotifyTmpPath/$DEPNotifyLogoutBOM" ]] || [[ ! -f "$DEPNotifyTmpPath/$DEPNotifyDoneBOM" ]]; do
		Logging "DEPNotify Cleanup: Waiting for Completion file"
		Logging "DEPNotify Cleanup: The user has not closed the DEPNotify window"
		Logging "DEPNotify Cleanup: Waiting $(GetTimerNoun 1)"
		/bin/sleep 1
		if [[ -f "$DEPNotifyTmpPath/$DEPNotifyDoneBOM" ]]; then
			Logging "DEPNotify Cleanup: Found $DEPNotifyTmpPath/$DEPNotifyDoneBOM"
			break
		fi
		if [[ -f "$DEPNotifyTmpPath/$DEPNotifyLogoutBOM" ]]; then
			Logging "DEPNotify Cleanup: Found $DEPNotifyTmpPath/$DEPNotifyLogoutBOM"
			break
		fi
	done
	
	# Removes the DEPNotify LaunchDaemon.
	if [[ -e "$DEPNotifyLaunchDaemonPath/$DEPNotifyLaunchDaemonFile" ]]; then
		Logging "DEPNotify Cleanup: Removing LaunchDaemon"
		launchctl bootout system "$DEPNotifyLaunchDaemonPath/$DEPNotifyLaunchDaemonFile"
		/bin/rm -R "$DEPNotifyLaunchDaemonPath/$DEPNotifyLaunchDaemonFile"
	else
		Logging "DEPNotify Cleanup: LaunchDaemon not installed"
	fi
		
	# Loops through and remove all files associated with DEPNotify.	
	for i in \
		"$DEPNotifyPath/$DEPNotifyApp" \
		"$DEPNotifyScriptsPath/$DEPNotifyEnrollmentStartScript" \
		"$DEPNotifyScriptsPath/$DEPNotifyEnrollmentInstallerError" \
		"$DEPNotifyScriptsPath/$DEPNotifyEnrollmentInstallerOut" \
		"$DEPNotifyTmpPath/$DEPNotifyLogFile" \
		"$DEPNotifyTmpPath/$DEPNotifyDebugLogFile" \
		"/Users/$(GetCurrentUser)/Library/Preferences/$DEPNotifyNewPlist" \
		"$DEPNotifyTmpPath/$DEPNotifyDoneBOM" \
		"$DEPNotifyTmpPath/$DEPNotifyLogoutBOM" \
		"$DEPNotifyTmpPath/$DEPNotifyRestartBOM" \
		"$DEPNotifyTmpPath/$DEPNotifyAgreeBOM" \
		"$DEPNotifyTmpPath/$DEPNotifyRegistrationDoneBOM"; do
			Logging "Checking for $i"
			if [[ -e "$i" ]] || [[ -d "$i" ]]; then
				# Removes DEPNotify objects if they exist.
				Logging "DEPNotify Cleanup: Attempting to remove $i"
				/bin/rm -R "$i"
				Return="$?"
				if [[ "$Return" -ne 0 ]]; then
					# Logs that an error occured while removing an object.
					Logging "DEPNotify Cleanup: Unable to remove $i" "ERROR"
					return "$Return"
				fi
			else
				# File or directory not found.				
				Logging "DEPNotify Cleanup: $i not found" "INFO"
			fi
		done
	Logging "--- END DEPNOTIFY CLEANUP ---"
}

RestartCommand() {
	# Performs an MDM command restart if RestartWhenDone is true.
	# If EnableMDMRestart is set, calls the specified policy to perform the MDM restart; otherwise, performs a regular restart.
	
	if [[ "$RestartWhenDone" == true ]]; then
		if [[ "$EnableMDMRestart" == true ]]; then
			"$JamfBinaryPath/$JamfBinary" policy -event "$MDMRestartCommandPolicy"
		else
			sudo shutdown -r now
		fi
	fi
}

####################################################################################################
# MAIN
####################################################################################################
LoggingHeader
CheckForAppleSilicon
ValidateTrueFalseFlags
GetSetupAssistantProcess
WaitForCurrentUser
GetFinderProcess
CheckForDEPNotify
CheckForDEPNotifyBOMs
GeneratePlistConfig
SetComputerName
CustomBranding
LaunchDEPNotify
GetDEPNotifyProcess
GenerateStatusBar
PrettyPause
RunJamfPolicies
CheckJamfConnectLoginWindow
CreateStubFiles
JamfCheckIn
ScriptCompletion
DEPNotifyCleanup
LoggingFooter
RestartCommand

exit 0	# Success
exit 1	# Failure