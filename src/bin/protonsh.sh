#!/bin/bash

set -Ee
set -o pipefail

if [ -r ~/.config/protonsh ]
then
	source ~/.config/protonsh
fi

shell="${SHELL:-/bin/bash}"
declare -a prefixes

declare -A loglevels
loglevels[ERROR]=0
loglevels[WARN]=1
loglevels[INFO]=2
loglevels[DEBUG]=3

LOGLEVEL=${LOGLEVEL:-"WARN"}
loglevel=${loglevels[${LOGLEVEL}]}

log_err()
{
	if [ $loglevel -ge ${loglevels["ERROR"]} ]
	then
		_log_stmt "ERROR:" "$@"
	fi
}

log_warn()
{
	if [ $loglevel -ge ${loglevels["WARN"]} ]
	then
		_log_stmt "WARN:" "$@"
	fi
}

log_info()
{
	if [ $loglevel -ge ${loglevels["INFO"]} ]
	then
		_log_stmt "INFO:" "$@"
	fi
}

log_dbg()
{
	if [ $loglevel -ge ${loglevels["DEBUG"]} ]
	then
		_log_stmt "DEBUG:" "$@"
	fi
}

_log_stmt()
{
	local prefix fmt
	prefix="$1"
	fmt="$2"
	shift 2
	# shellcheck disable=SC2059
	>&2 printf "$prefix $fmt\n" "$@"
}

# $1: message
# $2: exit code (default: 1)
die()
{
	log_err "$1"
	exit "${2:-1}"
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

# shellcheck source=../fun/steamlib.sh
if ! . "${STEAMLIB:-/usr/share/protonsh/steamlib}"
then
	echo "Could not load steamlib functions/constants!"
	exit 1
fi

if [ -z "$STEAMAPPS_DIRS" ]
then
	steam_find_libraries
else
	echo "Using environment override ${STEAMAPPS_DIRS[*]} as SteamApps dir"
fi

# Sanity checks: at this point, $STEAMAPPS_DIRS should point to valid dirs...
for appDir in "${STEAMAPPS_DIRS[@]}"
do
	if [ ! -d "$appDir" ]
	then
		die "SteamApps dir $appDir is not a directory!" 3
	fi
done

# ... and they should undoubtly contain a compatdata dir...
for appDir in "${STEAMAPPS_DIRS[@]}"
do
	if temp="$(find "$appDir" -maxdepth 1 -type d  -iname compatdata)"
	then
		STEAM_APPS_COMPATDATA_DIRS+=("$temp")
		foundCompat=1
	else
		log_warn "No compatdata dir found inside $appDir!"
	fi
done
if [ -z "$foundCompat" ]
then
	die "No compatdata dir found inside any steamapps dir in library!"
fi

echo "List of proton prefixes found in Steam:"
I=0
declare -a removed_apps
for appDir in "${STEAM_APPS_COMPATDATA_DIRS[@]}"
do
	prefixes+=( "$appDir"/* )
done
prefixesLen="${#prefixes}"
numDigit="${#prefixesLen}"

for prefix in "${prefixes[@]}"
do
	if [ -d "$prefix/pfx" ]
	then
		prefixes[$I]="$prefix"
		appID="${prefix##*/}"
		if appName="$(steam_get_appName "$appID")"
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
	appName="$(steam_get_appName "$appID")"
else
	die "Not a valid prefix choice! ($CHOICE)"
fi

steam_search_compat_tools

echo "List of proton versions installed in Steam:"
if ! steamSelVer="$(steam_print_compat_proton_version "$appCompatData")"
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
	if [ "$steamSelVer" ] && steam_proton_version_matches "$PROTON_VERSION" "$steamSelVer"
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
