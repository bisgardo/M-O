# TODO Use variable overriding feature for this.

# Register prompt command.
OLD_PROMPT_COMMAND_MO="$PROMPT_COMMAND"
PROMPT_COMMAND="_MO_prompt_command;$PROMPT_COMMAND"

unregister_MO() {
	# Unset all hooks.
	unset _MO_update_begin
	unset _MO_update_end
	unset _MO_handle_action_begin
	unset _MO_handle_action_end
	
	# Restore prompt command.
	PROMPT_COMMAND="$OLD_PROMPT_COMMAND_MO"
	unset OLD_PROMPT_COMMAND_MO
	
	# Delete this function.
	unset -f unregister_MO
}
