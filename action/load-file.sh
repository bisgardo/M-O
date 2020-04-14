# The file containing enter/leave actions
# TODO This should be a search path. Could be extended with abs path as alternative way of defining default actions.
export MO_FILENAME="${MO_FILENAME:-.M-O}"

# Arg 1: dir
# Arg 2: event
# Arg 3: action
_MO_action_load_file() {
	local -r file="$dir/$MO_FILENAME"
	[ -f "$file" ] && source "$file"
}

MO_ACTION="_MO_action_load_file;$MO_ACTION"
