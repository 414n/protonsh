#!/bin/bash

if [ -r ~/.config/protonsh ]
then
	source ~/.config/protonsh
fi

shell="${SHELL:-/bin/bash}"
declare -a PREFIXES

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

# $1: appID
# $2: fieldName
get_appmanifest_field()
{
	grep -m1 "$2" "$STEAM_APPS_DIR/appmanifest_${1}.acf" | sed -ne 's/^.*"'$2'"[[:space:]]*"\([[:print:]]*\)"[[:space:]]*$/\1/p'
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
for PREFIX in "$STEAM_APPS_COMPATDATA_DIR"/*
do
	PREFIXES[$I]="$PREFIX"
	appID="${PREFIX##*/}"
	appName="$(get_appName "$appID")"
	printf "%s) %s\t%s\n" "$I" "$appID" "$appName"
	I=$((I+1))
done
echo -n "Choice? "
read -r CHOICE
if get_menu_choice "$CHOICE" 0 "$I"
then
	wineprefix="${PREFIXES[$menu_choice]}/pfx"
	appID="${PREFIXES[$menu_choice]##*/}"
	appName="$(get_appName "$appID")"
else
	die "Not a valid prefix choice! ($CHOICE)"
fi

search_compat_tools

echo "List of proton versions installed in Steam:"
I=0
for PROTON_VERSION in "${compatibilityToolsLoc[@]}"
do
	PROTON_VERSIONS[$I]="$PROTON_VERSION"
	versionName="${PROTON_VERSION##*/}"
	echo "$I) $versionName"
	I=$((I+1))
done
echo -n "Choice? "
read -r CHOICE
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
	override_p PS1 "\[\033[38;5;14m\]${appName} ($appID)\[$(tput sgr0)\]\n\\_\[$(tput sgr0)\]\[\033[38;5;10m\]${versionName}\[$(tput sgr0)\] \\$ \[$(tput sgr0)\]"
	override_p PATH "${protonVersion}/dist/bin:${protonVersion}:${PATH}"
	print_blink "Type 'exit' or CTRL+D to close this shell"
	(cd "$wineprefix" && exec "$shell" --noprofile --norc )
else
	die "Not a valid Proton version choice! ($CHOICE)"
fi
