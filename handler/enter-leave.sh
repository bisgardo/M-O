# The command that's being evaluated when M-O enters or leaves a directory.
# The exposed variables 'dir' and 'event' contain the current directory and 'enter'/'leave', respectively.
# Actions are intended to register themselves by extending this variable.
MO_ACTION=''

_MO_handle_event() {
	local on_enter=''
	local on_leave=''

	eval ${MO_ACTION}

	local -r func="on_$event"
	local -r action="$(dereference "$func")"

	if [ -n "$action" ]; then
		_MO_echo_action "$dir" "$event" "$action"
		_MO_eval_action ${action} # No quoting.
	elif [ "$MO_LOG_LEVEL" -ge 2 ]; then
		MO_echo "($event $dir)"
	fi
}

MO_ENTER_HANDLER="_MO_handle_event;$MO_ENTER_HANDLER"
MO_LEAVE_HANDLER="_MO_handle_event;$MO_LEAVE_HANDLER"

####################
# HELPER FUNCTIONS #
####################

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

# Arg 1: dir
# Arg 2: event
# Arg 3: action
# Print a M-O message for an action to be executed.
_MO_echo_action() {
	local -r dir="$1"
	local -r event="$2"
	local -r action="$3"

	if [ ! -d "$dir" ]; then
		MO_errcho "$event event in non-existent dir '$dir'"
		return 1
	fi
	if [ "$MO_LOG_LEVEL" -ge 1 ]; then
		MO_echo "Executing action: $action"
    fi
}


###############################
# ACTION DEFINITION FUNCTIONS #
###############################

# TODO Add print capabilities to functions below.

# Arg 1: enter_stmt ("enter" statement)
# Arg 2: leave_stmt ("leave" statement)
# Extend the return variables by appending enter_stmt to on_enter and prepending leave_stmt to on_leave.
MO_action_extend() {
	local -r enter_stmt="$1"
	local -r leave_stmt="$2"

	on_enter="$(join_stmts "$on_enter" "$enter_stmt")"
	on_leave="$(join_stmts "$leave_stmt" "$on_leave")"
}

# Arg 1: enter_stmt ("enter" statement)
# Arg 2: leave_stmt ("leave" statement)
# Inject the return variables by prepending enter_stmt to on_enter and appending leave_stmt to on_leave.
MO_action_inject() {
	local -r enter_stmt="$1"
	local -r leave_stmt="$2"

	on_enter="$(join_stmts "$enter_stmt" "$on_enter")"
	on_leave="$(join_stmts "$on_leave" "$leave_stmt")"
}

# Arg 1: enter_stmt ("enter" statement)
# Arg 2: leave_stmt ("leave" statement)
# Extend the return variables by prepending enter_stmt to on_enter and
# leave_stmt to on_leave.
MO_prepend_action() {
	local -r enter_stmt="$1"
	local -r leave_stmt="$2"

	on_enter="$(join_stmts "$enter_stmt" "$on_enter")"
	on_leave="$(join_stmts "$leave_stmt" "$on_leave")"
}

# Arg 1: enter_stmt ("enter" statement)
# Arg 2: leave_stmt ("leave" statement)
# Extend the return variables by appending enter_stmt to on_enter and
# leave_stmt to on_leave.
MO_append_action() {
	local -r enter_stmt="$1"
	local -r leave_stmt="$2"

	on_enter="$(join_stmts "$enter_stmt" "$on_enter")"
	on_leave="$(join_stmts "$on_leave" "$leave_stmt")"
}

# TODO Modularize such that the implementation of this can be swapped out with one that uses array (as stack of values).

MO_tmp_var_name() {
	local -r var="$1"
	local -r dir="$2"

	builtin echo "${var}_MO_${#dir}"
}

# Register actions to set and restore a given variable on enter and leave, respectively.
# Note that the concrete values assigned to on_enter and on_leave depend on the current environment:
# In particular, when entering, the value computed for on_leave is not the same as when actually leaving.
# This means that the action cannot just be stored somewhere for later execution.
# Arg 1: var (variable to override)
# Arg 2: val (value that var is set to for the duration of the override)
# Arg 3: enter_msg (message to output on enter)
# TODO Ensure that this works even when multiple actions (e.g. one defined in file and another being default)
#      override the same var.
#      - A temp var disambiguator would prevent them from overwriting each other's temp var (provided as local var).
#      - deferred evaluation of the actual commands would make them evaluate the command relative to the correct environment
#        (currently they both evaluate in the same environment but after the first is run the second one is in a new env).
MO_override_var() {
	local -r var="$1"
	local -r val="$2"

	local enter_msg="$3"
	local leave_msg="$4"

	local tmp="$(MO_tmp_var_name "$var" "$dir")"

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

	local enter_stmt="$var='$val'"
	if is_set "$var"; then
		local -r var_val="$(dereference "$var")"
		enter_stmt="$tmp='$var_val'; $enter_stmt"
	else
		enter_stmt="unset $tmp; $enter_stmt"
	fi
	[ -z "$enter_msg" ] && enter_msg="Overriding $var='$val'."

	local leave_stmt
	if is_set "$tmp"; then
		local -r tmp_val="$(dereference "$tmp")"
		leave_stmt="$var='$tmp_val'; unset $tmp"
		[ -z "$leave_msg" ] && leave_msg="Restoring $var='$tmp_val'."
	else
		leave_stmt="unset $var"
		[ -z "$leave_msg" ] && leave_msg="Unsetting $var'."
	fi

	# Prepend any message to actions.
	[ "$enter_msg" = '-' ] || enter_stmt="MO_echo \"$enter_msg\"; $enter_stmt"
	[ "$leave_msg" = '-' ] || leave_stmt="MO_echo \"$leave_msg\"; $leave_stmt"

	# TODO Save some kind of entry such that the override chain of variables can be listed.

	MO_action_extend "$enter_stmt" "$leave_stmt"
}

# TODO Add function 'MO_unset_var'.