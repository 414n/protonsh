#!/bin/bash

# Search for the SteamApps directory on the system in Steam library paths.
# If a match is found, the STEAMAPPS_DIRS environment variable is set,
# otherwise the script exits with an error.
# If the STEAMAPPS_DIRS is already set to a value, this function will exit with
# an error.
# Arguments:
# none
# Exported vars:
# - STEAMAPPS_DIRS, if valid SteamApps directories are found
steam_find_libraries()
{
	local result tmp default
	log_dbg "steam_find_libraries: start"
	if [ "$STEAMAPPS_DIRS" ]
	then
		die "STEAMAPPS_DIRS is already set to $STEAMAPPS_DIRS! You should not be here!" 1
	fi

	for candidate in "$HOME/.steam/steam/" "$(awk '/BaseInstallFolder_/ {gsub("\"","", $2); print $2}' "$HOME/.steam/steam/config/config.vdf")"
	do
		log_dbg "evaluating $candidate"
		if [ -d "$candidate" ]
		then
			if tmp="$(find "$candidate" -maxdepth 1 -type d -iname steamapps)" && [ "$tmp" ]
			then
				log_dbg "found steamapps dir $tmp"
				result+=("$tmp")
			fi
		fi
	done

	if [ "${#result[*]}" -gt 0 ]
	then
		log_dbg "Found ${#result[*]} steamapps dirs: ${result[*]}"
		STEAMAPPS_DIRS=("${result[@]}")
	fi
	log_dbg "steam_find_libraries: end"
}


# Parse a field from the manifest file of the given application ID.
# Arguments:
# $1: appID
# $2: fieldName
# Returns:
# 0 - all ok
# 1 - if manifest file does not exist
steam_get_appmanifest_field()
{
	local manifest appID fieldName
	if [ -z "$1" ] || [ -z "$2" ]
	then
		return 1
	fi
	appID="$1"
	fieldName="$2"
	if manifest="$(find "${STEAMAPPS_DIRS[@]}" -maxdepth 1 -name "appmanifest_${appID}.acf")" && [ "$manifest" ]
	then
		awk -f "${STEAMAWK}" -v inputPattern="\"$fieldName\"" "$manifest"
	else
		return 1
	fi

	#grep -m1 "$2" \{\} | sed -ne 's/^.*"'$2'"[[:space:]]*"\([[:print:]]*\)"[[:space:]]*$/\1/p' \;
	# local manifest
	# for appDir in "${STEAMAPPS_DIRS[@]}"
	# do
	#	manifest="$appDir/appmanifest_${1}.acf"
	#	if [ -e "$manifest" ]
	#	then
	#		grep -m1 "$2" "$manifest" | sed -ne 's/^.*"'$2'"[[:space:]]*"\([[:print:]]*\)"[[:space:]]*$/\1/p'
	#	else
	#		return 1
	#	fi
	# done
}


# $1: appID
steam_get_appName()
{
	steam_get_appmanifest_field "$1" name
}

steam_search_compat_tools()
{
	shopt -s nullglob

	compatibilityToolsLoc=(\
		/usr/share/steam/compatibilitytools.d/Proton* \
		/usr/local/share/steam/compatibilitytools.d/Proton* \
		"$HOME"/.steam/root/compatibilitytools.d/Proton*
	)
	for app in "${STEAMAPPS_DIRS[@]}"
	do
		compatibilityToolsLoc+=("$app"/common/Proton*)
	done

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
steam_print_compat_proton_version()
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
steam_proton_version_matches()
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