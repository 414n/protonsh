#!/bin/bash

shell="${SHELL:-/bin/bash}"
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

# $1: variable name
# $2: overridden value
override_p()
{
	print_override "$1" "$2"
	export "$1"="$2"
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
	winearch="$(awk -F= '/^#arch/ {print $2}' "$wineprefix/system.reg")"
	echo "Chosen: $(get_appName "$appID") with $protonVersion"
	echo "Launching shell $shell inside $wineprefix using"
	override_p WINEPREFIX "$wineprefix"
	override_p WINEARCH "${winearch:-win32}"
	override_p LD_LIBRARY_PATH "$LD_LIBRARY_PATH:$protonVersion/lib:$protonVersion/lib64"
	override_p STEAM_COMPAT_DATA_PATH "$wineprefix"
	override_p SteamGameId "$appID"
	override_p SteamAppId "$appID"
	override_p STEAM_COMPAT_CLIENT_INSTALL_PATH "$HOME/.local/share/Steam"
	override_p PS1 '\[Proton\]>'
	override_p PATH "${protonVersion}/dist/bin:${protonVersion}:${PATH}"
	(cd "$wineprefix" && exec "$shell" -i )
fi
