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
	
	builtin echo "$left$sep$right"
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

MO_tmp_var_name() {
	local -r var="$1"
	local -r dir="$2"
	
	builtin echo "${var}_MO_${#dir}"
}

# TODO Modularize such that the implementation of this can be swapped out with one that uses array (as stack of values).

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
	
	local -r var_val="$(eval builtin echo "\$$var")" # Like "${!var}" but works in both bash and zsh.
	local -r tmp_val="$(eval builtin echo "\$$tmp")" # Like "${!tmp}" but works in both bash and zsh.
	
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
