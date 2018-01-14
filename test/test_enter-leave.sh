#!/usr/bin/env bash

# SETUP AND MOCK #
source ../M-O.sh
if [ "$?" != 0 ]; then
	>&2 echo "Error loading library"
	exit 1
fi

_MO_handle_action() {
	local -r dir="$1"
	local -r file="$2"
	local -r event="$3"
	
	echo "$event $dir"
}

# TEST FUNCTIONS #

error() {
	>&2 echo
	>&2 echo "$@"
	exit 1
}

assert_dir() {
	local dir="$1"
	if [ "$MO_CUR_DIR" != "$dir" ]; then
		error "Expected MO_CUR_DIR to be '$dir' but was '$MO_CUR_DIR'"
	fi
}

assert_out() {
	local input
	for line in "$@"; do
		read input
		if [ "$line" != "$input" ]; then
			error "Expected line '$line' but was '$input'"
		fi
	done
	read input
	if [ -n "$input" ]; then
		error "Extra input: '$input'"
	fi
	
	>&2 echo '- OK!'
}

test_update() {
	local from="$1"
	local to="$2"
	
	# Print to stderr to prevent it from going through pipe.
	>&2 echo -n "Test: From '$from' to '$to' "
	
	local MO_CUR_DIR="$from"
	_MO_update "$to"
assert_dir "${to%/}"
}

# TERMINOLOGY
# - level 0: /
# - level 1: /x
# - level 2: /x/y

# TESTS #

# Stay on level 0.
test_update ''     ''      | assert_out
test_update ''     '/'     | assert_out

# Stay on level 1.
test_update '/x'   '/x'    | assert_out
test_update '/x'   '/x/'   | assert_out

# Stay on level 2.
test_update '/x/y' '/x/y'  | assert_out
test_update '/x/y' '/x/y/' | assert_out

# From level 0 to 1.
test_update ''     '/a'    | assert_out 'enter /a'
test_update ''     '/a/'   | assert_out 'enter /a'

# From level 0 to 2.
test_update ''     '/a/b'  | assert_out 'enter /a' 'enter /a/b'
test_update ''     '/a/b/' | assert_out 'enter /a' 'enter /a/b'

# From level 1 to 0.
test_update '/x'   ''      | assert_out 'leave /x'
test_update '/x'   '/'     | assert_out 'leave /x'

# From level 1 to 1.
test_update '/x'   '/a'    | assert_out 'leave /x'   'enter /a'
test_update '/x'   '/a/'   | assert_out 'leave /x'   'enter /a'

# From level 1 to 2.
test_update '/x'   '/a/b'  | assert_out 'leave /x'   'enter /a' 'enter /a/b'
test_update '/x'   '/a/b/' | assert_out 'leave /x'   'enter /a' 'enter /a/b'

# From level 2 to 0.
test_update '/x/y' ''      | assert_out 'leave /x/y' 'leave /x'
test_update '/x/y' '/'     | assert_out 'leave /x/y' 'leave /x'

# From level 2 to 1.
test_update '/x/y' '/a'    | assert_out 'leave /x/y' 'leave /x' 'enter /a'
test_update '/x/y' '/a/'   | assert_out 'leave /x/y' 'leave /x' 'enter /a'

# From level 2 to 2 (via 0).
test_update '/x/y' '/a/b'  | assert_out 'leave /x/y' 'leave /x' 'enter /a' 'enter /a/b'
test_update '/x/y' '/a/b/' | assert_out 'leave /x/y' 'leave /x' 'enter /a' 'enter /a/b'

# From level 2 to 2 (via 1).
test_update '/x/y' '/x/b'  | assert_out 'leave /x/y' 'enter /x/b'
test_update '/x/y' '/x/b/' | assert_out 'leave /x/y' 'enter /x/b'

# TODO Test action logic [4]
# * File with no actions [1]
# * File with only onEnter or onLeave [2]
# * File with both actions [1]
