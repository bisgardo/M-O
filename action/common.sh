# Extensions for simplifying creation of M-O actions.
# Dependencies:
# - Base printing functions: MO_echo, MO_errcho, MO_debucho (implemented in './M-O.sh').
# - Action definition functions: MO_override_var, MO_action_extend, MO_action_inject
#   (implemented by the event handler engine - currently only the enter/leave implementation
#   defined in 'handler/enter-leave.sh' exists).

# TODO Add checks and error handling for verifying that actions are applicable.
# TODO Optionally add indicator to PS1 that some override is in effect (e.g. "[GOPATH=../..]").
# TODO Split into separate files.
# TODO Add functions for setting/unsetting alias (needs to store alias value in var to allow nesting).

MO_with_message() {
  local -r msg="$1"
  local -r cmd="$2"

  if [ -n "$msg" ]; then
    MO_echo "$msg"
  else
    MO_echo "Evaluating command '$cmd'."
  fi
  eval "$cmd"
}

MO_append_path() {
  local -r value="$1"
  MO_override_var PATH "$PATH:$value"
}

# OVERRIDE AND RESTORE GOPATH #

MO_set_gopath() {
	local -r value="$1"
	MO_override_var GOPATH "$value"
}

MO_set_gopath_default() {
	MO_set_gopath "$dir"
}

# ACTIVATE AND DEACTIVATE PYTHON ENVIRONMENT #

_MO_create_python_virtualenv() {
	local -r env_path="$1"
	local -r env_args="$2"
	
	MO_echo 'Creating Python virtualenv'
	if command -v virtualenv > /dev/null; then
		eval "virtualenv '$env_path' $env_args"
	else
		MO_errcho "Cannot create Python virtualenv: command 'virtualenv' not found"
	fi
}

_MO_activate_python_virtualenv() {
	local -r activate_path="$1"
	
	MO_echo 'Activating Python virtualenv'
	source "$activate_path"
}

_MO_deactivate_python_virtualenv() {
	MO_echo 'Deactivating Python virtualenv'
	deactivate
}

_MO_enter_python_virtualenv() {
	local -r env_path="$1"
	local -r env_args="$2"
	
	# Create virtualenv if it doesn't exist.
	[ ! -e "$env_path" ] && _MO_create_python_virtualenv "$env_path" "$env_args"
	
	# Activate virtualenv if it exists.
	local -r activate_path="$env_path/bin/activate"
	if [ -f "$activate_path" ]; then
		_MO_activate_python_virtualenv "$activate_path"
	else
		MO_errcho "Cannot activate non-existent Python virtualenv in '$env_path'"
	fi
}

_MO_leave_python_virtualenv() {
	local -r env_path="$1"
	
	if declare -f deactivate > /dev/null; then
		_MO_deactivate_python_virtualenv
	else
		MO_errcho "Cannot deactivate non-active Python virtualenv in '$env_path'"
	fi
}

MO_python_virtualenv() {
	local -r env="$1"
	local -r env_args="$2"
	
	local -r env_path="$dir/$env"
	
	local -r enter_stmt="_MO_enter_python_virtualenv '$env_path' '$env_args'"
	local -r leave_stmt="_MO_leave_python_virtualenv '$env_path'"
	MO_action_extend "$enter_stmt" "$leave_stmt"
}

# SET NODE.JS VERSION #

_MO_set_nodejs_version() {
	local -r current_version="$1"
	local -r target_version="$2"
	
	if ! nvm list "$target_version" > /dev/null; then
		MO_echo "Installing node.js version $target_version"
		nvm install "$target_version" || MO_errcho "Could not install node.js version '$target_version'"
	fi
	
	if [ "$current_version" = "$target_version" ]; then
		MO_echo "Already using node.js version '$target_version'"
	else
		MO_echo "Setting node.js version '$target_version'"
		nvm use "$target_version" || MO_errcho "Could not set node.js version '$target_version'"
	fi
}

MO_nodejs_version() {
	local -r node_version="$1"
	
	# TODO Optinally(?) loazy-load nvm if it wasn't loaded by .bash_profile (or similar).
	
	local -r current_version="$(nvm current)"
	MO_override_var OLD_NODEJS_VERSION "$current_version"
	
	local enter_stmt="_MO_set_nodejs_version '$current_version' '$node_version'"
	local leave_stmt="_MO_set_nodejs_version '$current_version' '$OLD_NODEJS_VERSION'"
	MO_action_extend "$enter_stmt" "$leave_stmt"
}
