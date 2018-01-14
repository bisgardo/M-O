#!/usr/bin/env bash

# SETUP AND MOCK #
source ../M-O.sh
if [ "$?" != 0 ]; then
	>&2 echo "Error loading library"
	exit 1
fi

MO_tmp_var_name() {
	echo "TMP"
}

# TEST FUNCTIONS #

errcho() {
	>&2 echo "$@"
}

test_override_var() {
	local old="$1"
	local new="$2"
	local expected_on_enter="$3"
	local expected_on_leave="$4"
	
	# Print to stderr to prevent it from going through pipe.
	>&2 echo -n "Test: Overriding '$old' with '$new' "
	
	local on_enter
	local on_leave
	MO_override_var "$old" "$new" - -
	
	local left_err
	local right_err
	[ "$on_enter" = "$expected_on_enter" ] || left_err="Expected on_enter <$expected_on_enter> but was <$on_enter>"
	[ "$on_leave" = "$expected_on_leave" ] || right_err="Expected on_leave <$expected_on_leave> but was <$on_leave>"
	
	if [ -n "$left_err" -o -n "$right_err" ]; then
		errcho
		[ -n "$left_err" ] && errcho $left_err
		[ -n "$right_err" ] && errcho $right_err
		return 1
	fi
	
	errcho '- OK!'
}

# TESTS #

(
	VAR=old
	test_override_var VAR new "TMP='old'; VAR='new'" "VAR=''; unset TMP"
)

(
	VAR=old
	TMP=older
	test_override_var VAR new "TMP='old'; VAR='new'" "VAR='older'; unset TMP"
)
