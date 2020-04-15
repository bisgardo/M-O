# File containing the tested function.
source ../handler/enter-leave.sh

# For utility functions only.
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
	local name="$1"
	local var="$2"
	local val="$3"
	local expected_on_enter="$4"
	local expected_on_leave="$5"
	
	# Print to stderr to prevent it from going through pipe.
	errcho -n "Test: Overriding '$var' with '$val' ($name)"
	
	local on_enter
	local on_leave
	MO_override_var "$var" "$val" - -
	
	local left_err
	local right_err
	[ "$on_enter" = "$expected_on_enter" ] || left_err="Expected on_enter \"$expected_on_enter\" but was \"$on_enter\""
	[ "$on_leave" = "$expected_on_leave" ] || right_err="Expected on_leave \"$expected_on_leave\" but was \"$on_leave\""
	
	if [ -n "$left_err" ] || [ -n "$right_err" ]; then
		errcho '- FAIL:'
		[ -n "$left_err" ] && errcho "- $left_err"
		[ -n "$right_err" ] && errcho "- $right_err"
		return 1
	fi
	
	errcho ' - OK!'
}

# TESTS: Set VAR to value "new" #

(
	# On enter: No existing value to store in temp var.
	expected_on_enter="unset TMP; export VAR='new'"
	# On leave: No old value in temp var to restore from.
	expected_on_leave="unset VAR"
	test_override_var 'neither VAR nor TMP set' VAR new "$expected_on_enter" "$expected_on_leave"
)

(
	VAR=old
	# On enter: Store existing value in temp var.
	expected_on_enter="TMP='old'; VAR='new'"
	# On leave: No old value in temp var to restore from.
	expected_on_leave="unset VAR"
	test_override_var 'VAR set' VAR new "$expected_on_enter" "$expected_on_leave"
)

(
	TMP=older
	# On enter: No existing value to store in temp var.
	expected_on_enter="unset TMP; export VAR='new'" # TODO Back up TMP.
	# On leave: Restore value from temp var.
	expected_on_leave="VAR='older'; unset TMP"
	test_override_var 'TMP set' VAR new "$expected_on_enter" "$expected_on_leave"
)

(
	VAR=old
	TMP=older
	# On enter: Store existing value in temp var.
	expected_on_enter="TMP='old'; VAR='new'" # TODO Back up TMP.
	# On leave: Restore value from temp var.
	expected_on_leave="VAR='older'; unset TMP"
	test_override_var 'VAR and TMP set' VAR new  "$expected_on_enter" "$expected_on_leave"
)
