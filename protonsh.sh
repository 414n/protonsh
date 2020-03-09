#!/bin/bash

shell="${SHELL:-/bin/sh}"
declare -a PREFIXES

# $1: appID
# $2: fieldName
get_appmanifest_field()
{
	grep -m1 "$2" ~/.steam/steam/SteamApps/"appmanifest_${1}.acf" | sed -ne 's/^.*"'$2'"[[:space:]]*"\([[:print:]]*\)"[[:space:]]*$/\1/p'
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

echo "List of proton prefixes found in Steam:"
I=0
for PREFIX in ~/.steam/steam/SteamApps/compatdata/*
do
	PREFIXES[$I]="$PREFIX"
	appID="${PREFIX##*/}"
	appName="$(get_appName "$appID")"
	printf "%s) %s\t%s\n" "$I" "$appID" "$appName"
	I=$((I+1))
done
echo -n "Choice? "
read -r CHOICE
if [ "$CHOICE" -le "$I" ]
then
	wineprefix="${PREFIXES[$CHOICE]}/pfx"
	appID="${PREFIXES[$CHOICE]##*/}"
fi
echo "List of proton versions installed in Steam:"
I=0
for PROTON_VERSION in ~/.steam/steam/SteamApps/common/Proton*
do
	PROTON_VERSIONS[$I]="$PROTON_VERSION"
	versionName="${PROTON_VERSION##*/}"
	echo "$I) $versionName"
	I=$((I+1))
done
echo -n "Choice? "
read -r CHOICE
if [ "$CHOICE" -le "$I" ]
then
	protonVersion="${PROTON_VERSIONS[$CHOICE]}"
	winearch="$(awk -F= '/^#arch/ {print $2}' $wineprefix/system.reg)"
	echo "Chosen: $(get_appName "$appID") with $protonVersion"
	echo "Launching shell $shell inside $wineprefix using"
	print_override WINEPREFIX "$wineprefix"
	print_override WINEARCH "$winearch"
	print_override LD_LIBRARY_PATH "$LD_LIBRARY_PATH:$protonVersion/lib:$protonVersion/lib64"
	print_override STEAM_COMPAT_DATA_PATH "$wineprefix"
	print_override SteamGameId "$appID"
	print_override SteamAppId "$appID"
	print_override STEAM_COMPAT_CLIENT_INSTALL_PATH "$HOME/.local/share/Steam"
	print_override 'wine' "$protonVersion/proton/dist/bin/wine"
	print_override 'proton' "$protonVersion/proton"
	export WINEPREFIX="$wineprefix"
	export WINEARCH="${winearch:-win32}"
	export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:$protonVersion/lib:$protonVersion/lib64"
	export STEAM_COMPAT_DATA_PATH="$wineprefix"
	export SteamGameId="$appID"
	export SteamAppId="$appID"
	export STEAM_COMPAT_CLIENT_INSTALL_PATH="$HOME/.local/share/Steam"
	export PS1='\[Proton\]>'
	export PATH="${protonVersion}/dist/bin:${protonVersion}:${PATH}"
	(cd "$wineprefix" && exec "$shell" -i )
fi
