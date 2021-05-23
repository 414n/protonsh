#!/bin/bash
# tests for steamlib script

oneTimeSetUp() {
	export SHARED_FUNCS="$(realpath ../fun/steamlib.sh)"
	export STEAMAWK="$(realpath ../fun/steamlib.awk)"
	# export PATH="stubs:$PATH"
	# shellcheck source=../fun/steamlib.sh
	. "$SHARED_FUNCS"
	export CWD="$PWD"
	# export VERBOSE_TEST=1
}

setUp() {
	# shellcheck source=./tests_common.sh
	. "$CWD/tests_common.sh"
}

tearDown() {
	unset output
	unset stderr
	unset stdout
	unset status
}

test_get_appmanifest_no_params()
{
	execcmd steam_get_appmanifest_field
	assertFalse "Did not error out on missing all params ($status)!; $stdout" "$status"
	execcmd steam_get_appmanifest_field 123
	assertFalse "Did not error out on missing field name param ($status)!; $stdout" "$status"
}

test_missing_appmanifest()
{
	export STEAMAPPS_DIRS=("$CWD/testFiles")
	execcmd steam_get_appmanifest_field 9999999 name
	assertFalse "Did not error out on non-existant manifest file ($status)!; $stdout" "$status"
}
teststeam_get_appmanifest_field()
{
	export STEAMAPPS_DIRS=("$CWD/testFiles")
	execcmd steam_get_appmanifest_field 591960 name
	assertTrue "Could not parse name field from manifest ($status)!; $stdout" "$status"
	assertEquals "Animation Throwdown: The Quest for Cards" "$stdout"
}


. shunit2-2.1.8/shunit2