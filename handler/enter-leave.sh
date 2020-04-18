# Event handler for "enter" and "leave" events emitted from M-O.sh.
# Depends on M-O.sh (for utility functions is_set and join_stmts).

# The command that's being evaluated when M-O enters or leaves a directory.
# The exposed variables 'dir' and 'event' contain the current directory and 'enter'/'leave', respectively.
# Actions are intended to register themselves by extending this variable.
MO_ACTION=''

_MO_handle_enter() {
	local on_enter=''
	local on_leave=''
	
	eval ${MO_ACTION}
	
	local -r enter_action="$on_enter"
	local -r leave_action="$on_leave"
	
	# Evaluate enter action.
	if [ -n "$enter_action" ]; then
		MO_log 1 "Executing enter action: $enter_action"
		_MO_eval_action ${enter_action} # No quoting.
	else
		MO_log 2 "($event $dir)"
	fi
	
	# Save leave action.
	if [ -n "$leave_action" ]; then
		local var="MO_LEAVE_${#dir}"
		MO_log 1 "Storing leave action in $var: $leave_action"
		eval "$var=$(quote "$leave_action")"
	else
		MO_log 2 "($event $dir)"
	fi
}

_MO_handle_leave() {
	# Find previously stored leave action.
	local -r var="MO_LEAVE_${#dir}"
	local -r leave_action="$(dereference "$var")"
	if [ -n "$leave_action" ]; then
		MO_log 1 "Executing leave action: $leave_action"
		_MO_eval_action ${leave_action} # No quoting.
	fi
	unset "$var"
}

MO_ENTER_HANDLER="_MO_handle_enter;$MO_ENTER_HANDLER"
MO_LEAVE_HANDLER="_MO_handle_leave;$MO_LEAVE_HANDLER"

####################
# HELPER FUNCTIONS #
####################

_MO_eval_action() {
	eval $@ || MO_errcho "Failed evaluating command: $@"
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

# Register actions to set and restore a given variable on enter and leave, respectively.
# Note that the concrete values assigned to on_enter and on_leave depend on the current environment:
# In particular, when entering, the value computed for on_leave is not the same as when actually leaving.
# This means that the action cannot just be stored somewhere for later execution.
# Arg 1: var (variable to override)
# Arg 2: val (value that var is set to for the duration of the override)
MO_override_var() {
	local -r var="$1"
	local -r val="$2"
	
	local tmp="${var}_MO_${#dir}_$RANDOM"
	
#	# Since all local variables are lower case by convention, requiring that
#	# overridden variable isn't purely lower case ensures that such
#	# collisions cannot happen.
#	if [ "$(echo "$var" | tr '[:upper:]' '[:lower:]')" = "$var" ]; then
#		MO_errcho "Cannot override purely lower case variable '$var'"
#		return 1
#	fi
#	if [ "$(echo "$tmp" | tr '[:upper:]' '[:lower:]')" = "$tmp" ]; then
#		MO_errcho "Cannot back up '$var' in purely lower case variable '$tmp'"
#		return 1
#	fi
	
	MO_action_extend "_MO_set_var '$var' '$val' '$tmp'" "_MO_unset_var '$var' '$val' '$tmp'" 
}

# TODO Use quote function below.

_MO_set_var() {
	local -r var="$1"
	local -r val="$2"
	local -r tmp="$3"
	
	if is_set "$var"; then
		local -r var_val="$(dereference "$var")"
		MO_log 0 "Overriding $var='$val'".
		eval "$tmp='$var_val'; $var='$val'"
	else
		MO_log 0 "Setting $var='$val'".
		eval "unset $tmp; export $var='$val'"
	fi
}

_MO_unset_var() {
	local -r var="$1"
	local -r val="$2"
	local -r tmp="$3"
	
	if is_set "$tmp"; then
		local -r tmp_val="$(dereference "$tmp")"
		MO_log 0 "Restoring $var='$tmp_val'."
		eval "$var='$tmp_val'; unset $tmp"
	else
		MO_log 0 "Unsetting $var."
		eval "unset $var"
	fi
}

# TODO Add function 'MO_unset_var'.
