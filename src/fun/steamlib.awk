#!/usr/bin/awk -f
# Short program to parse a single field from steam manifest files
# (appmanifest_APPID.acf).
# Parameters:
# - inputPattern: variable that holds the pattern to match in the manifest
#	file.
function ltrim(s) { sub(/^[ \t\r\n]+/, "", s); return s }
function rtrim(s) { sub(/[ \t\r\n]+$/, "", s); return s }
function trim(s)  { return rtrim(ltrim(s)); }
$0 ~ inputPattern {
	$1=""
	gsub("\"","",$0)
	print trim($0)
}

