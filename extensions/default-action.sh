# Extend action handling with functionality for default actions.

# Is not exported to ensure that subshells build their state from scratch.
MO_DEFAULT_ACTION="$MO_DEFAULT_ACTION"

_MO_handle_default_action() {
	if [ "$MO_DEFAULT_ACTION" ]; then
		if [ "$MO_LOG_LEVEL" -ge 1 ]; then
			MO_echo "(evaluating default action)"
		fi
		eval $MO_DEFAULT_ACTION
	fi
}

_MO_handle_action_begin="$(_MO_join_stmts "$_MO_handle_action_begin" _MO_handle_default_action)"
