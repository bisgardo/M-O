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
export MO_CUR_DIR="$MO_CUR_DIR"

# The file containing enter/leave actions
export MO_FILENAME="${MO_FILENAME:-.M-O}"

# Log level: 1+: action info, 2+: event info.
export MO_LOG_LEVEL="${MO_LOG_LEVEL:-0}"

######################
# PRINTING FUNCTIONS #
######################

 # Print a M-O head as a prefix for a echoed message.
_MO_echo_head() {
    # Bold foreground and black background.
    command echo -ne "\033[1;40m"
    
    # "[": Bold white foreground on black background.
    command echo -ne "\033[97m["
    # "--": Bold light yellow foreground on black background.
    command echo -ne "\033[33m--"
    # "]": Bold white foreground on default background.
    command echo -ne "\033[97m]"
    # Reset.
    command echo -en "\033[0m"
}

# Print a message prefixed with a M-O head prefix.
MO_echo() {
    _MO_echo_head
    echo " $@"
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
    eval $@ || echo "Failed evaluating command: $@"
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
    local -r dir="$1"
    local -r file="$2"
    local -r event="$3"
    
    if [ ! -d "$dir" ]; then
        MO_echo "warning: $event non-existent dir '$dir'"
    fi
    
    if [ -f "$file" ]; then
        # Exposed variables. Note that even unused variables must be declared
        # in order to prevent leakage from local (i.e. function) scope.
        local on_enter
        local on_leave
        source "$file"
        
        local -r func="on_$event"
        local -r action="${!func}"
        
        if [ -n "$action" ]; then
            _MO_echo_action "$dir" "$event" "$action"
            _MO_eval_action ${action}
            return
        fi
    fi
    
    if [ "$MO_LOG_LEVEL" -ge 2 ]; then
        MO_echo "($event $dir)"
    fi
}

# Arg 1: dir
_MO_enter() {
    local -r dir="${1%/}"
    
    _MO_handle_action "$dir" "$dir/$MO_FILENAME" enter
    
    MO_CUR_DIR="$dir"
}

# Arg 1: dir
_MO_leave() {
    local -r dir="${1%/}"
    
    _MO_handle_action "$dir" "$dir/$MO_FILENAME" leave
    
    MO_CUR_DIR="$(_MO_dirname "$dir")"
}

# Arg 1: new_dir (new directory)
_MO_update() {
    local -r new_dir="${1%/}"
    local -r x=$?
    
    # Common case.
    if [ "$MO_CUR_DIR" = "$new_dir" ]; then
        if [ "$MO_LOG_LEVEL" -ge 1 ]; then
            MO_echo "(staying in $MO_CUR_DIR)"
        fi
        return $x
    fi
    
    _MO_update_begin "$new_dir"
    
    # Traverse from $old_dir up the tree ("leaving" directories on the way)
    # until $MO_CUR_DIR is an ancestor (i.e. prefix) of $new_dir.
    until _MO_is_ancestor "$MO_CUR_DIR" "$new_dir"; do
        _MO_leave "$MO_CUR_DIR"
    done
    
    # Relative path from $MO_CUR_DIR to $new_dir.
    local relative_path="${new_dir#"$MO_CUR_DIR"}"
    
    if [ -n "$relative_path" ]; then
        local dir
        while read -d'/' dir; do
            _MO_enter "$MO_CUR_DIR/$dir"
        done <<< "${relative_path#/}"
        _MO_enter "$MO_CUR_DIR/$dir"
    fi
    
    _MO_update_end "$new_dir"
    
    return $?
}

###################
# EXTENSION HOOKS #
###################

# Overwriteable hook for running code before update.
_MO_update_begin() {
    :
}

# Overwriteable hook for running code after update.
_MO_update_end() {
    :
}

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
    
    local sep=
    if [ -n "$left" -a -n "$right" ]; then
        sep='; '
    fi
    
    command echo "$left$sep$right"
}

# TODO Add print capabilities to functions below.

# Arg 1: enter_stmt ("enter" statement)
# Arg 2: leave_stmt ("leave" statement)
# Extend the return variables by prepending enter_stmt to on_enter and appending leave_stmt to on_leave.
MO_extend() {
    local -r enter_stmt="$1"
    local -r leave_stmt="$2"
    
    on_enter="$(_MO_join_stmts "$on_enter" "$enter_stmt")"
    on_leave="$(_MO_join_stmts "$leave_stmt" "$on_leave")"
}

# Arg 1: enter_stmt ("enter" statement)
# Arg 2: leave_stmt ("leave" statement)
# Extend the return variables by appending enter_stmt to on_enter and
# prepending leave_stmt to on_leave.
MO_inject() {
    local -r enter_stmt="$1"
    local -r leave_stmt="$2"
    
    on_enter="$(_MO_join_stmts "$enter_stmt" "$on_enter")"
    on_leave="$(_MO_join_stmts "$on_leave" "$leave_stmt")"
}

# Arg 1: var (variable to override)
# Arg 2: val (value that var is set to for the duration of the override)
# Arg 3: suffix (suffix to append to var for storing the original value for restoration)
MO_override_var() {
    local -r var="$1"
    local -r val="$2"
    local -r suffix="$3"
    
    # TODO Take (renamed) $tmp directly instead of $suffix.
    local -r tmp="$var$suffix"
    
    local -r varVal="${!var}"
    local -r tmpVal="${!tmp}"
    
    # TODO Make new function for joining message to command.
    local enter_stmt="MO_echo \"Overriding $var='$val'\"; $tmp='$varVal'; $var='$val'"
    # TODO Can do only if $tmpVal is defined (i.e. if its value is not empty)?
    local leave_stmt="MO_echo \"Restoring $var='$tmpVal'\"; $var='$tmpVal'; unset $tmp"
    
    MO_extend "$enter_stmt" "$leave_stmt"
}
