#!/bin/bash
# Common function/utilies used in shunit2 tests.

# Wrap command execution to obtain output and status variables. This runs a
# command in a subshell.
# If VERBOSE_TEST is defined, the output is also sent to stdout
execcmd() {
	local stderr_file
	stderr_file="$(mktemp -p "${SHUNIT_TMPDIR}")"
	stdout="$("$@" 2>"$stderr_file")"
	status=$?
	stderr="$(cat "$stderr_file")"
	rm "$stderr_file"
	if [ "$VERBOSE_TEST" ]
	then
		echo "stdout: $stdout"
		echo "stderr: $stderr"
		echo "status: $status"
	fi
}

# Wrap command execution to obtain output and status variables. This runs the
# given commands using eval.
# If VERBOSE_TEST is defined, the output is also sent to stdout
evalcmd() {
	local output_file
	output_file="$(mktemp -p "${SHUNIT_TMPDIR}")"
	eval "$@" > "$output_file" 2>&1
	output="$(cat "$output_file")"
	rm "$output_file"
	status=$?
	if [ "$VERBOSE_TEST" ]
	then
		echo "$output"
	fi
}
