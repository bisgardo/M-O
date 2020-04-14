# The file containing enter/leave actions
export MO_FILENAME="${MO_FILENAME:-.M-O}"

# Arg 1: dir
# Arg 2: event
# Arg 3: action
_MO_handle_file_action() {
	local -r file="$dir/$MO_FILENAME"
	[ -f "$file" ] && source "$file"
}

MO_ACTION="_MO_handle_file_action;$MO_ACTION"
