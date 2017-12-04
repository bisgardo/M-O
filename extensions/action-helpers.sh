# Extensions for simplifying creation of M-O actions.

# TODO Add checks and error handling for verifying that actions are applicable.
# TODO Optionally add indicator to PS1 that override is in effect (e.g. "[GOCODE=../..]").

# HELPERS FUNCTIONS #

MO_suffix() {
    local -r dir="${1:-"$dir"}"
    command echo "_MO_$(command echo "$dir" | md5)"
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

MO_python_env() {
    local -r env_path="$1"
    
    local -r enter_stmt="MO_echo 'Activating Python virtualenv'; source '$env_path'"
    local -r leave_stmt="MO_echo 'Deactivating Python virtualenv'; deactivate"
    
    MO_extend_action "$enter_stmt" "$leave_stmt"
}

MO_python_env_default() {
    local -r env="${1:-.}"
    MO_python_env "$dir/$env/bin/activate"
}

# SET NODE.JS VERSION #

_ensure_nodejs_version() {
    local -r node_version="$1"
    [ "$(nvm current)" = "$node_version" ] || nvm use "$node_version"
}

MO_ensure_nodejs_version() {
    local node_version="$1"
    
    # TODO Add restore statement.
    local enter_stmt="MO_echo 'Ensuring that node.js is at version $node_version';_ensure_nodejs_version $node_version"
    MO_extend_action "$enter_stmt" ''
}
