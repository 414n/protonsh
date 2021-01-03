#!/bin/bash

set -Ee
set -o pipefail

if [ -r ~/.config/protonsh ]
then
	source ~/.config/protonsh
fi

shell="${SHELL:-/bin/bash}"
declare -a prefixes

# $1: message
# $2: exit code (default: 1)
die()
{
	echo "$1"
	exit "${2:-1}"
}

# Search for the SteamApps directory on the system in well-known locations,
# such as ~/.steam/steam/.
# If a match is found, the STEAM_APPS_DIR environment variable is set,
# otherwise the script exits with an error.
# If the STEAM_APPS_DIR is already set to a value, this function will exit with
# an error.
# Arguments:
# none
# Exported vars:
# - STEAM_APPS_DIR, if a valid SteamApps directory is found
find_steamapps_dir()
{
	local result
	if [ "$STEAM_APPS_DIR" ]
	then
		die "STEAM_APPS_DIR is already set to $STEAM_APPS_DIR! You should not be here!" 1
	fi

	if [ -d "$HOME/.steam" ] && [ -h "$HOME/.steam/steam" ]
	then
		result="$(find "$HOME/.steam/steam/" -maxdepth 1 -type d -iname steamapps)"
	fi
	#TODO: search in other well-known but currently unknown locations

	if [ "$result" ]
	then
		echo "Autodetected SteamApps dir in $result"
		export STEAM_APPS_DIR="$result"
	else
		die "Could not determine SteamApps dir (not found under ~/.steam/steam/). Please override STEAM_APPS_DIR before launching the script" 2
	fi
}

# Parse a field from the manifest file of the given application ID.
# Arguments:
# $1: appID
# $2: fieldName
# Returns:
# 0 - all ok
# 1 - if manifest file does not exist
get_appmanifest_field()
{
	local manifest="$STEAM_APPS_DIR/appmanifest_${1}.acf"
	if [ -e "$manifest" ]
	then
		grep -m1 "$2" "$manifest" | sed -ne 's/^.*"'$2'"[[:space:]]*"\([[:print:]]*\)"[[:space:]]*$/\1/p'
	else
		return 1
	fi
}

# $1: appID
get_appName()
{
	get_appmanifest_field "$1" name
}

# $1: variable name
# $2: overridden value
print_override()
{
	printf '\t%s\n' "$1=$2"
}

# $1: variable name
# $2: overridden value
override_p()
{
	print_override "$1" "$2"
	export "$1"="$2"
}

# $1: user input
# $2: choice min (inclusive)
# $3: choice max (exclusive)
get_menu_choice()
{
	local input min max
	input="$1"
	min="$2"
	max="$3"
	unset menu_choice
	case $1 in
		''|*[!0-9]*)
			return 1
			;;
		*)
			if [ "$input" -ge "$min" ] && [ "$input" -lt "$max" ]
			then
				export menu_choice="$input"
				return 0
			else
				return 1
			fi
			;;
	esac
}

# $1: message
print_blink()
{
	echo -e "\e[5;93m$1\e[m"
}

search_compat_tools()
{
	shopt -s nullglob

	compatibilityToolsLoc=(\
		"$STEAM_APPS_DIR"/common/Proton* \
		/usr/share/steam/compatibilitytools.d/* \
		/usr/local/share/steam/compatibilitytools.d/* \
		"$HOME"/.steam/root/compatibilitytools.d/*
	)
	if [ "$STEAM_EXTRA_COMPAT_TOOLS_PATHS" ]
	then
		declare -a extraLocs appendLocs
		IFS=':' read -r -a extraLocs <<< "$STEAM_EXTRA_COMPAT_TOOLS_PATHS"
		for loc in "${extraLocs[@]}"
		do
			if compgen -G "$loc/*"
			then
				appendLocs+=( "$loc"/* )
			fi
		done
		if [ "${#appendLocs[*]}" -gt 0 ]
		then
			compatibilityToolsLoc=("${compatibilityToolsLoc[@]}" "${appendLocs[@]}")
		fi
	fi
	shopt -u nullglob
}

# Print Proton version used for the compatdata dir of the selected appID.
# This is done by parsing the version from a specific line in the
# compatdata/config_info file or, lacking that, from the compatdata/version
# file. 
# $1 - app compat data dir
print_compat_proton_version()
{
	local compatDir="$1"
	local default
	# Try 1: use config_info file, if present
	if [ -e "$compatDir/config_info" ]
	then
		default="$(head -n1 "$compatDir"/config_info)"
		# default="${default##*compatibilitytools.d/}"
		# default="${default##*common/}"
		# default="${default%%/dist*}"
	# Try 2: use version file, if present
	elif [ -e "$compatDir/version" ]
	then
		default="$(head -n1 "$compatDir/version")"
	fi
	if [ "$default" ]
	then
		echo "$default"
	else
		return 1
	fi
}

# Arguments:
# $1: proton dir
# $2: version string to match against
proton_version_matches()
{
	local proton_dir="$1"
	local matchStr="$2"
	local proton_version_file="$proton_dir/version"
	local proton_proton_file="$proton_dir/proton"
	if [ -z "$proton_dir" ]
	then
		die "null Proton dir supplied!"
	fi
	if [ -z "$matchStr" ]
	then
		die "no version string to match against!"
	fi
	if [ ! -d "$proton_dir" ]
	then
		die "Proton directory $proton_dir does not exist or is not a directory!"
	fi
	
	# 1st try: let's match against the second field of the version file
	if versionStr="$(awk '{print $2}' "$proton_version_file")"
	then
		[ "$matchStr" = "$versionStr" ] && return 0
	fi
	# 2nd try: let's match against the CURRENT_PREFIX_VERSION variable value in the proton exe
	if protonStr="$(grep CURRENT_PREFIX_VERSION= "$proton_proton_file")"
	then
		protonStr="${protonStr##*=}"
		protonStr="${protonStr//\"/}"
	# if protonStr="$(awk -F= '/CURRENT_PREFIX_VERSION=/ {gsub("\"",""); print $2}' "$proton_proton_file")"
	# then
		[ "$matchStr" = "$protonStr" ] && return 0
	fi
	# No matches T_T
	return 1
}

if [ -z "$STEAM_APPS_DIR" ]
then
	find_steamapps_dir
else
	echo "Using environment override $STEAM_APPS_DIR as SteamApps dir"
fi

# Sanity checks: at this point, $STEAM_APPS_DIR should point to a valid dir...
if [ ! -d "$STEAM_APPS_DIR" ]
then
	die "SteamApps dir $STEAM_APPS_DIR is not a directory!" 3
fi

# ... and it should undoubtly contain a compatdata dir...
if temp="$(find "$STEAM_APPS_DIR" -type d -maxdepth 1 -iname compatdata)"
then
	STEAM_APPS_COMPATDATA_DIR="$temp"
else
	die "No compatdata dir found inside $STEAM_APPS_DIR!" 4
fi

echo "List of proton prefixes found in Steam:"
I=0
declare -a removed_apps
prefixes=( "$STEAM_APPS_COMPATDATA_DIR"/* )
prefixesLen="${#prefixes}"
numDigit="${#prefixesLen}"

for prefix in "${prefixes[@]}"
do
	if [ -d "$prefix/pfx" ]
	then
		prefixes[$I]="$prefix"
		appID="${prefix##*/}"
		if appName="$(get_appName "$appID")"
		then
			printf "%${numDigit}d) %s\t%s\n" "$I" "$appID" "$appName"
			I=$((I+1))
		else
			removed_apps+=( "$appID" )
		fi
	fi
done
if [ "${#removed_apps[*]}" -gt 1 ]
then
	echo "warn: error parsing manifest for several appIDs (${removed_apps[*]}). Leftovers prefixes after uninstall?"
fi
echo -n "Choice? "
read -r CHOICE
if get_menu_choice "$CHOICE" 0 "$I"
then
	appCompatData="${prefixes[$menu_choice]}"
	wineprefix="$appCompatData/pfx"
	appID="${appCompatData##*/}"
	appName="$(get_appName "$appID")"
else
	die "Not a valid prefix choice! ($CHOICE)"
fi

search_compat_tools

echo "List of proton versions installed in Steam:"
if ! steamSelVer="$(print_compat_proton_version "$appCompatData")"
then
	echo "warn: could not determine current Proton version selected in Steam for $appName ($appID)"
fi
pfxSelStr="  <---- Prefix version detected"
pfxSelIdx=-1
I=0
for PROTON_VERSION in "${compatibilityToolsLoc[@]}"
do
	PROTON_VERSIONS[$I]="$PROTON_VERSION"
	versionName="${PROTON_VERSION##*/}"
	if [ "$steamSelVer" ] && proton_version_matches "$PROTON_VERSION" "$steamSelVer"
	then
		echo "$I) $versionName $pfxSelStr"
		pfxSelIdx="$I"
	else
		echo "$I) $versionName"
	fi
	I=$((I+1))
done
if [ "$pfxSelIdx" -gt 0 ]
then
	echo -n "Choice? [$pfxSelIdx] "
else
	echo -n "Choice? "
fi
read -r CHOICE
if [ -z "$CHOICE" ]
then
	CHOICE="$pfxSelIdx"
fi
if get_menu_choice "$CHOICE" 0 "$I"
then
	protonVersion="${PROTON_VERSIONS[$menu_choice]}"
	winearch="$(awk -F= '/^#arch/ {print $2}' "$wineprefix/system.reg")"
	echo "Chosen: $appName with $protonVersion"
	echo "Launching shell $shell inside $wineprefix using"
	override_p WINEPREFIX "$wineprefix"
	override_p WINEARCH "${winearch:-win32}"
	override_p LD_LIBRARY_PATH "$LD_LIBRARY_PATH:$protonVersion/dist/lib:$protonVersion/dist/lib64"
	override_p STEAM_COMPAT_DATA_PATH "$wineprefix"
	override_p SteamGameId "$appID"
	override_p SteamAppId "$appID"
	override_p STEAM_COMPAT_CLIENT_INSTALL_PATH "$HOME/.local/share/Steam"
	#override_p PS1 "\[$appName@$versionName\]$ "
	override_p PS1 "\[\033[38;5;14m\]${appName} ($appID)\[$(tput sgr0)\]\n\\_\[$(tput sgr0)\]\[\033[38;5;10m\]${protonVersion##*/}\[$(tput sgr0)\] \\$ \[$(tput sgr0)\]"
	override_p PATH "${protonVersion}/dist/bin:${protonVersion}:${PATH}"
	print_blink "Type 'exit' or CTRL+D to close this shell"
	(cd "$wineprefix" && exec "$shell" --noprofile --norc )
else
	die "Not a valid Proton version choice! ($CHOICE)"
fi
