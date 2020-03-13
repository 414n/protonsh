#!/bin/bash

if [ -r ~/.config/protonsh ]
then
	source ~/.config/protonsh
fi

shell="${SHELL:-/bin/bash}"
STEAM_APPS_DIR="${STEAM_APPS_DIR:-$HOME/.steam/steam/SteamApps}"
declare -a PREFIXES

# $1: message
# $2: exit code (default: 1)
die()
{
	echo "$1"
	exit "${2:-1}"
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
# $2: choice min
# $3: choice max
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
			if [ "$input" -ge "$min" ] && [ "$input" -le "$max" ]
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

echo "List of proton prefixes found in Steam:"
I=0
for PREFIX in "$STEAM_APPS_DIR"/compatdata/*
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

echo "List of proton versions installed in Steam:"
I=0
for PROTON_VERSION in "$STEAM_APPS_DIR"/common/Proton*
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
	override_p PS1 "\[\e[1;36m${appName}\[\e[0m\n\_\[\e[1;32m${versionName}\[\e[0m \$ "
	override_p PATH "${protonVersion}/dist/bin:${protonVersion}:${PATH}"
	print_blink "Type 'exit' or CTRL+D to close this shell"
	(cd "$wineprefix" && exec "$shell" --noprofile --norc )
else
	die "Not a valid Proton version choice! ($CHOICE)"
fi
