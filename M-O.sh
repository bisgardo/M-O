# Implementation of M-O.

#########
# STATE #
#########

# State variables control the execution of M-O and keep track of changes between
# updates. The variables are initialized to themselves (with expected default values)
# to ensure that re-registering is a no-op.

# The directory that was the current directory (symlinks resolved)
# the last time that _MO_update() was called.
# Is not exported to ensure that subshells build their state from scratch.
MO_CUR_DIR="$MO_CUR_DIR"

# The command that's being evaluated before the shell shows the prompt.
# It serves basically the same purpose as PROMPT_COMMAND,
# but works across shells and adds customizability.
# Is not exported to ensure that subshells build their state from scratch.
MO_PROMPT_COMMAND='_MO_update "$(pwd -P)"'

# Event handlers.
# Are not exported to ensure that subshells build their state from scratch.
MO_ENTER_HANDLER="$MO_ENTER_HANDLER"
MO_LEAVE_HANDLER="$MO_LEAVE_HANDLER"

# Log level: 1+: action info, 2+: event info.
export MO_LOG_LEVEL="${MO_LOG_LEVEL:-0}"

#####################
# REGISTER FUNCTION #
#####################

# TODO Remove function - doesn't serve any real purpose anymore.

# Function to be invoked for each prompt.
_MO_prompt_command() {
	eval ${MO_PROMPT_COMMAND}
}

#######################################
# UPDATE AND EVENT EMITTING FUNCTIONS #
#######################################

# Arg 1: target_dir (new directory)
_MO_update() {
	local -r target_dir="${1%/}"
	# TODO Verify that this makes sense/makes a difference.
	local -r x=$?
	
	# Common case.
	if [ "$MO_CUR_DIR" = "$target_dir" ]; then
		MO_log 1 "(staying in $MO_CUR_DIR)"
		return $x
	fi
	
	# Traverse from $old_dir up the tree ("leaving" directories on the way)
	# until $MO_CUR_DIR is an ancestor (i.e. prefix) of $target_dir.
	until _MO_is_ancestor "$MO_CUR_DIR" "$target_dir"; do
		_MO_leave "$MO_CUR_DIR"
	done
	
	# Relative path from $MO_CUR_DIR to $target_dir.
	local -r relative_path="${target_dir#"$MO_CUR_DIR"}"
	
	if [ -n "$relative_path" ]; then
		local dir
		while read -d'/' dir; do
			_MO_enter "$MO_CUR_DIR/$dir"
		done <<< "${relative_path#/}"
		_MO_enter "$MO_CUR_DIR/$dir"
	fi
	
	return $?
}

# Arg 1: dir
_MO_enter() {
	# TODO Only trim slash if necessary.
	local -r dir="${1%/}"
	local -r event='enter'
	eval ${MO_ENTER_HANDLER}
	MO_CUR_DIR="$dir"
}

# Arg 1: dir
_MO_leave() {
	# TODO Only trim slash if necessary.
	local -r dir="${1%/}"
	local -r event='leave'
	eval ${MO_LEAVE_HANDLER}
	MO_CUR_DIR="$(_MO_dirname "$dir")"
}

######################
# PRINTING FUNCTIONS #
######################

# TODO Try to write with printf such that echo can be aliased
#      (cannot use `command echo` because that doesn't work with color codes in zsh). (<- but how about `builtin echo`?)

 # Print a M-O head as a prefix for an echo message.
_MO_echo_head() {
	# Bold foreground and black background.
	echo -ne "\033[1;40m"
	
	# "[": Bold white foreground on black background.
	echo -ne "\033[97m["
	# "--": Bold yellow foreground on black background.
	echo -ne "\033[33m--"
	# "]": Bold white foreground on default background.
	echo -ne "\033[97m]"
	# Reset.
	echo -en "\033[0m"
}

# Print an angry M-O head as a prefix for a errcho message.
_MO_echo_angry_head() {
	# Bold foreground and black background.
	echo -ne "\033[1;40m"
	
	# "[": Bold white foreground on black background.
	echo -ne "\033[97m["
	# "><": Bold red foreground on black background.
	echo -ne "\033[31m><"
	# "]": Bold white foreground on default background.
	echo -ne "\033[97m]"
	# Reset.
	echo -en "\033[0m"
}

# Print a curious M-O head as a prefix for a debucho message.
_MO_echo_curious_head() {
	# Bold foreground and black background.
	echo -ne "\033[1;40m"
	
	# "[": Bold white foreground on black background.
	echo -ne "\033[97m["
	# "==": Bold red foreground on black background.
	echo -ne "\033[36m=="
	# "]": Bold white foreground on default background.
	echo -ne "\033[97m]"
	# Reset.
	echo -en "\033[0m"
}

# Print a message prefixed with a M-O head prefix.
MO_echo() {
	local -r msg="$@"
	if [ -n "$msg" ]; then
		_MO_echo_head
		>&2 echo " $msg"
	fi
}

# Print a message prefixed with an angry M-O head prefix.
MO_errcho() {
	local -r msg="$@"
	if [ -n "$msg" ]; then
		_MO_echo_angry_head
		>&2 echo " $msg"
	fi
}

# Print a message prefixed with a curious M-O head prefix.
MO_debucho() {
	local -r msg="$@"
	if [ -n "$msg" ]; then
		_MO_echo_curious_head
		>&2 echo " $msg"
	fi
}

MO_log() {
	local -r level="$1"
	local -r msg="$2"
	
	[ "$MO_LOG_LEVEL" -ge "$level" ] &&
		if [ "$level" -eq 0 ]; then
			MO_echo "$msg"
		elif [ "$level" -gt 0 ]; then
			MO_debucho "$msg"
		else
			MO_errcho "$msg"
		fi
}

####################
# HELPER FUNCTIONS #
####################

# Arg 1: dir
# Print the dirname of dir unless it's '/'.
_MO_dirname() {
	local -r dir="$1"
	local -r result="$(dirname "$dir")"
	[ "$result" != '/' ] && builtin echo "$result"
}

# Arg 1: ancestor
# Arg 2: descendant
_MO_is_ancestor() {
	local -r ancestor="${1%/}/"
	local -r descendant="${2%/}/"
	
	# $descendant with the (literal) prefix $ancestor removed.
	local suffix="${descendant#"$ancestor"}"
	
	# If $ancestor is a (non-empty) prefix, then
	# $suffix will be different from $descendant.
	[ "$suffix" != "$descendant" ]
}

#####################
# UTILITY FUNCTIONS #
#####################

# Utility function which aren't needed in this file, but defined here to ensure their availability throughout the pro

# TODO Move these functions to separate utility project:

join_stmts() {
	local -r left="$1"
	local -r right="$2"
	
	local sep=''
	[ -n "$left" ] && [ -n "$right" ] && sep='; '

	builtin echo "$left$sep$right"
}
export -f join_stmts

# From 'https://stackoverflow.com/a/13864829/883073'.
is_set() {
	declare -p "$1" &>/dev/null
}
export -f is_set

dereference() {
	local -r var="$1"
	eval builtin echo "\$$var" # Like "${!var}" but works in both bash and zsh.
}
export -f dereference

# Generalization of quote from bash-completion to multiple arguments:
# For each argument, escape all single quotes and surround it with single quotes.
# Output all the results joined by single space.
# This ensures that the output can be used in both echo and eval correctly.
# The function behaves identically to the original quote function for exactly one argument.
# 
# If no or multiple arguments are 
# Minor incompatibility with the original quote function:
# If no inputs are provided, this function produces no output.
# The original one prints a quoted empty string.
quote() {
	local p
	for v in "$@"; do
		local q="${v//\'/\'\\\'\'}"
		printf "$p'%s'" "$q"
		p=' '
	done
}
export -f quote
