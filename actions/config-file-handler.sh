# The file containing enter/leave actions
export MO_FILENAME="${MO_FILENAME:-.M-O}"

# Arg 1: dir
# Arg 2: event
# Arg 3: action
_MO_handle_file_action() {
	# API defines the following stable variables: dir, file, and event
	# 
	# Adds on_enter, on_leave, func, and action.
	
	# TODO Consider moving the rest of function to plugin/extension structure.
	#      This is only one of several reasonable ways of handling such an event
	#      (others being "default actions" and file per event).
	#      We might as well allow user code to customize it; adding features per subtree!
	#      The must be a code implementation that enables variable override/recovery, though.
	
	# TODO Experiment with adding a "leave" stack of registered leave functions.
	#      The stack is represented as an ordinary global variable updated using MO_override_var.
	
	# Exposed variables. Note that even unused variables must be declared
	# in order to prevent leakage from local (i.e. function) scope.
	local on_enter=''
	local on_leave=''
	
	local -r file="$dir/$MO_FILENAME"
	if [ -f "$file" ]; then
		source "$file"
	fi
	
	local -r func="on_$event"
	local -r action="$(eval builtin echo "\$$func")" # Like "${!func}" but works in both bash and zsh.
	
	if [ -n "$action" ]; then
		_MO_echo_action "$dir" "$event" "$action"
		_MO_eval_action ${action} # No quoting.
	elif [ "$MO_LOG_LEVEL" -ge 2 ]; then
		MO_echo "($event $dir)"
	fi
}

MO_HANDLE_ACTION="_MO_handle_file_action;$MO_HANDLE_ACTION"
