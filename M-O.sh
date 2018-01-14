# Implementation of M-O.

#########
# STATE #
#########

# State variables control the execution of M-O and keep track of changes between
# updates. The variables are initialized to themselves (with expected default values)
# to ensure that re-registering is a no-op.

# TODO Let state variables have names that are less likely to get overwritten by accident.

# The directory that was the current directory (symlinks resolved)
# the last time that _MO_update() was called.
# Is not exported to ensure that subshells build their state from scratch.
MO_CUR_DIR="$MO_CUR_DIR"

# The file containing enter/leave actions
export MO_FILENAME="${MO_FILENAME:-.M-O}"

# Log level: 1+: action info, 2+: event info.
export MO_LOG_LEVEL="${MO_LOG_LEVEL:-0}"

######################
# PRINTING FUNCTIONS #
######################

# TODO Try to write with printf such that echo can be aliased
#      (cannot use `command echo` because that doesn't work with color codes in zsh).

 # Print a M-O head as a prefix for a echoed message.
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

# Print an angry M-O head as a prefix for a errchoed message.
_MO_echo_angry_head() {
	# Bold foreground and black background.
	echo -ne "\033[1;40m"
	
	# "[": Bold white foreground on black background.
	echo -ne "\033[97m["
	# "--": Bold red foreground on black background.
	echo -ne "\033[31m><"
	# "]": Bold white foreground on default background.
	echo -ne "\033[97m]"
	# Reset.
	echo -en "\033[0m"
}

# Print a curious M-O head as a prefix for a errchoed message.
_MO_echo_curious_head() {
	# Bold foreground and black background.
	echo -ne "\033[1;40m"
	
	# "[": Bold white foreground on black background.
	echo -ne "\033[97m["
	# "--": Bold red foreground on black background.
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
		echo " $msg"
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

# Arg 1: dir
# Arg 2: event
# Arg 3: action
# Print a M-O message for an action to be executed.
_MO_echo_action() {
	# TODO Use e.g. MO_LOG_LEVEL for controlling amount of output with high
	#      granularity (up to and including variable dump).
	local -r dir="$1"
	local -r event="$2"
	local -r action="$3"
	
	# TODO Extract and reuse other places where the same format is used.
	# Replace $HOME prefix by '~' in $dir.
	MO_echo "($event ${dir/#"$HOME"/~})"
	
	if [ "$MO_LOG_LEVEL" -ge 1 ]; then
		MO_echo "Executing action: $action"
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
	if [ "$result" != '/' ]; then
		command echo "$result"
	fi
}

_MO_eval_action() {
	if [ -z "$MO_DEBUG" ]; then
		eval $@ || MO_errcho "Failed evaluating command: $@"
	else
		MO_debucho "Evaluate command: $@"
	fi
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

###########################################
# UPDATE AND ACTION EVALUTATION FUNCTIONS #
###########################################

# Arg 1: dir
# Arg 2: event
# Arg 3: action
_MO_handle_action() {
	# API defines the following stable variables: dir, file, event, on_enter, on_leave, func, and action.
	local -r dir="$1"
	local -r file="$2"
	local -r event="$3"
	
	# TODO Consider moving the rest of function to plugin/extension structure.
	#      This is only one of several reasonable ways of handling such an event
	#      (others being "default actions" and file per event).
	#      We might as well allow user code to customize it; adding features per subtree!
	#      The must be a code implementation that enables variable override/recovery, though.
	
	if [ ! -d "$dir" ]; then
		MO_errcho "$event event in non-existent dir '$dir'"
	fi
	
	# Exposed variables. Note that even unused variables must be declared
	# in order to prevent leakage from local (i.e. function) scope.
	local on_enter=''
	local on_leave=''
	
	if [ -n "$_MO_handle_action_begin" ]; then
		eval ${_MO_handle_action_begin} # No quoting.
	fi
	
	if [ -f "$file" ]; then
		source "$file"
	fi
	
	local -r func="on_$event"
	local -r action="$(eval command echo "\$$func")" # Like "${!func}" but works in both bash and zsh.
	
	if [ -n "$action" ]; then
		_MO_echo_action "$dir" "$event" "$action"
		_MO_eval_action ${action} # No quoting.
	elif [ "$MO_LOG_LEVEL" -ge 2 ]; then
		MO_echo "($event $dir)"
	fi
	
	if [ -n "$_MO_handle_action_end" ]; then
		eval ${_MO_handle_action_end} # No quoting.
	fi
}

# TODO API should just be to call handler with the exposed variables.
#      The rest should be put into an extension - and it should be possible to
#      have multiple handlers! Another handler strategy than the current one would
#      also be to register a "leave" func instead of reading it from the .M-O file.

# Arg 1: dir
_MO_enter() {
	local -r dir="${1%/}"
	_MO_handle_action "$dir" "$dir/$MO_FILENAME" 'enter'
	MO_CUR_DIR="$dir"
}

# Arg 1: dir
_MO_leave() {
	local -r dir="${1%/}"
	_MO_handle_action "$dir" "$dir/$MO_FILENAME" 'leave'
	MO_CUR_DIR="$(_MO_dirname "$dir")"
}

# Arg 1: target_dir (new directory)
_MO_update() {
	local -r target_dir="${1%/}"
	local -r x=$?
	
	# Common case.
	if [ "$MO_CUR_DIR" = "$target_dir" ]; then
		if [ "$MO_LOG_LEVEL" -ge 1 ]; then
			MO_echo "(staying in $MO_CUR_DIR)"
		fi
		return $x
	fi
	
	if [ -n "$_MO_update_begin" ]; then
		eval $_MO_update_begin
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
	
	if [ -n "$_MO_update_end" ]; then
		eval $_MO_update_end
	fi
	
	return $?
}

###################
# EXTENSION HOOKS #
###################

# _MO_update_begin:        For running code before update.
# _MO_update_end:          For running code after update.
# _MO_handle_action_begin: For running code before action handling.
# _MO_handle_action_end:   For running code after action handling.

#####################
# REGISTER FUNCTION #
#####################

# Function to be invoked for each prompt.
_MO_prompt_command() {
	_MO_update "$(pwd -P)"
}

############################
# ACTION UTILITY FUNCTIONS #
############################

_MO_join_stmts() {
	local -r left="$1"
	local -r right="$2"
	
	local sep=''
	if [ -n "$left" -a -n "$right" ]; then
		sep='; '
	fi
	
	command echo "$left$sep$right"
}

# TODO Add print capabilities to functions below.

# Arg 1: enter_stmt ("enter" statement)
# Arg 2: leave_stmt ("leave" statement)
# Extend the return variables by prepending enter_stmt to on_enter and appending leave_stmt to on_leave.
MO_extend_action() {
	local -r enter_stmt="$1"
	local -r leave_stmt="$2"
	
	on_enter="$(_MO_join_stmts "$on_enter" "$enter_stmt")"
	on_leave="$(_MO_join_stmts "$leave_stmt" "$on_leave")"
}

# Arg 1: enter_stmt ("enter" statement)
# Arg 2: leave_stmt ("leave" statement)
# Extend the return variables by appending enter_stmt to on_enter and
# prepending leave_stmt to on_leave.
MO_inject_action() {
	local -r enter_stmt="$1"
	local -r leave_stmt="$2"
	
	on_enter="$(_MO_join_stmts "$enter_stmt" "$on_enter")"
	on_leave="$(_MO_join_stmts "$on_leave" "$leave_stmt")"
}

# Arg 1: enter_stmt ("enter" statement)
# Arg 2: leave_stmt ("leave" statement)
# Extend the return variables by prepending enter_stmt to on_enter and
# leave_stmt to on_leave.
MO_prepend_action() {
	local -r enter_stmt="$1"
	local -r leave_stmt="$2"
	
	on_enter="$(_MO_join_stmts "$enter_stmt" "$on_enter")"
	on_leave="$(_MO_join_stmts "$leave_stmt" "$on_leave")"
}

# Arg 1: enter_stmt ("enter" statement)
# Arg 2: leave_stmt ("leave" statement)
# Extend the return variables by appending enter_stmt to on_enter and
# leave_stmt to on_leave.
MO_append_action() {
	local -r enter_stmt="$1"
	local -r leave_stmt="$2"
	
	on_enter="$(_MO_join_stmts "$enter_stmt" "$on_enter")"
	on_leave="$(_MO_join_stmts "$on_leave" "$leave_stmt")"
}

# TODO Move to helpers (though it is more generic than the other ones...).

# TODO On boot time, check if md5 is installed and print warning if it isn't.
#      Maybe even let this function default to a simpler/slower version.
MO_tmp_var_name() {
	local -r var="$1"
	local -r input="$2"
	
	command echo "${var}_MO_$(command echo "$input" | md5)"
}

# Arg 1: var (variable to override)
# Arg 2: val (value that var is set to for the duration of the override)
# Arg 3: enter_msg (message to output on enter)
MO_override_var() {
	local -r var="$1"
	local -r val="$2"
	
	local enter_msg="$3"
	local leave_msg="$4"
	
	# Allow caller to set tmp by defining it in _mo_tmp_var_name.
	local tmp="$_mo_tmp_var_name"
	[ -n "$tmp" ] || tmp="$(MO_tmp_var_name "$var" "$dir")"
	
	# Since all local variables are lower case by convention, requiring that
	# overridden variable isn't purely lower case ensures that such
	# collisions cannot happen.
	if [ "$(echo "$var" | tr '[:upper:]' '[:lower:]')" = "$var" ]; then
		MO_errcho "Cannot override purely lower case variable '$var'"
		return 1
	fi
	if [ "$(echo "$tmp" | tr '[:upper:]' '[:lower:]')" = "$tmp" ]; then
		MO_errcho "Cannot back up '$var' in purely lower case variable '$tmp'"
		return 1
	fi
	
	local -r var_val="$(eval command echo "\$$var")" # Like "${!var}" but works in both bash and zsh.
	local -r tmp_val="$(eval command echo "\$$tmp")" # Like "${!tmp}" but works in both bash and zsh.
	
	# TODO Only override if var_val is set.
	local enter_stmt="$tmp='$var_val'; $var='$val'"
	# TODO If tmp isn't set, unset $var instead.
	local leave_stmt="$var='$tmp_val'; unset $tmp"
	
	[ -z "$enter_msg" ] && enter_msg="Overriding $var='$val'"
	[ -z "$leave_msg" ] && leave_msg="Restoring $var='$tmp_val'"
	
	# Prepend any message to actions.
	[ "$enter_msg" = '-' ] || enter_stmt="MO_echo \"$enter_msg\"; $enter_stmt"
	[ "$leave_msg" = '-' ] || leave_stmt="MO_echo \"$leave_msg\"; $leave_stmt"
	
	# TODO Save some kind of entry such that the override chain of variables can be listed.
	
	MO_extend_action "$enter_stmt" "$leave_stmt"
}
