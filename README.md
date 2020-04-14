# M-O

M-O is a pernickety little command line bot that keeps your path clean in your
endeavors around the file system.

He will painstakingly follow your every step to ensure that your environment
lives up to the exact specifications of the current working directory:

Whenever the working directory is changed, M-O will traverse the directory tree
from the previous working directory to the current one (with symbolic links resolved).
He meticulously ensures that all directories on the way are properly
"entered" and "left" by executing actions defined in any `.M-O`-files
in the directories of this path.

While M-O will execute arbitrary shell code as actions,
helper functions for the following use cases are provided:

* Overwrite environment variable (e.g. `PS1`, `PATH`, `GOPATH`, ...) on enter
  (and restore it on leave).

* Activate Python virtual environment on enter (and deactivate it on delete).

* Set Node.js version using `nvm` (and restore it on leave).

## Install

M-O should be loaded and registered as part of your dotfiles setup.

The project is heavily modularized to make it easy to swap out the different moving parts independently.
Each isolated feature is enabled by sourcing a file.

The project is written to work for both bash (3+) and zsh.
The only difference in usage between the shells is which "register" file to source.

### Bash

In `.bashrc` and/or `.bash_profile`:

    MO_PATH=/path/to/M-O
	source "$MO_PATH/M-O.sh"                 # base module M-O
    source "$MO_PATH/register.bash"          # register M-O in bash shell
    
	source "$MO_PATH/handler/enter-leave.sh" # use default event handler (optional; see below)
	source "$MO_PATH/action/load-file.sh"    # enable loading actions from config file (optional; see below)
	source "$MO_PATH/action/load-default.sh" # enable default actions (optional; see below)
	source "$MO_PATH/action/common.sh"       # common actions (optional; see below)

### Zsh

Note that zsh support currently isn't properly tested.

In `.zshrc`: Same as for Bash above, except that `register.zsh"` should be used instead of `register.bash`.

## Components

* Base: The event emitter registered into the shell. Defined in `M-O.sh` and can be extended or replaced by setting `MO_PROMPT_COMMAND`.
* Event handler: Defined in `handler/enter-leave.sh` and can be extended or replaced by setting `MO_HANDLER`.
* Actions: Defined in `action/{common,load-default,load-file}.sh` and by the user.

### Exposed API:

* Base:
  - Printing and utility functions: `MO_echo`, `MO_errcho`, `MO_debucho`.
  - State variables: `dir` and `event` (containing current directory and `enter` or `leave`, respectively).
* Event handler: `MO_override_var`, `MO_action_extend`, `MO_action_inject` for defining handler-independent actions.
  [TODO Descibe.]
* Actions: Nothing internally, but a common usage for actions is to set some state to configure external tools.

The (currently only) event handler (`handler/enter-leave.sh`) implements the API by exposing the "return" variables
`on_enter` and `on_leave` which the functions above manipulate.
While manual actions can be implemented by doing the same, this is not a stable API and therefore not recommended.

## Entering and leaving

A directory is "entered" when the working directory is changing
from somewhere outside of its subtree to somewhere inside of it.
The directory is "left" when the working directory is changing back
to somewhere outside of its subtree.

This means that when the current working directory changes,
M-O will execute actions corresponding to the following events:

1. "Leave" all directories from the previous working directory (inclusive)
   up to the closest common ancestor (exclusive).
  
2. "Enter" all directories from the closest common ancestor (exclusive)
   down to the next working directory (inclusive).

## Defining actions

### File action (enabled by loading `action/load-file.sh`)

When a directory `dir` containing the file `dir/.M-O` is entered or left,
this file will be sourced and the actions defined within it be executed (as defined by the event handler).
Note that while any arbitrary shell code can be run this way,
only the functions exposed by the event handler (see above) should be used (unless the code is pure).

The following other variables that M-O exposes to `.MO`
provide context that help make the files more generic:

* `dir`: The absolute path of the directory containing the file.

* `file`: The absolute path of the file.

One should *not* count on these variables maintaining their values from the
time the file is sourced until actions defined within it are executed.
In other words, if actions use these variables, they must be fully expanded.

### Default action

TODO...

## Examples

TODO...

## Common actions

* `MO_python_env[_default]`: Activate/deactivate Python virtual environment...

* `MO_ensure_nodejs_version`: Set/restore node.js version...

## Curriculum Vitae

M-O (Microbe-Obliterator) made his first appearance in the movie Wall-E,
where he was proudly in charge of keeping all "foreign contaminants" off of
the space ship Axiom.
After having played a crucial rule in the human race's safe return to Earth,
M-O then personally oversaw a thorough planet-wide disinfection campaign.

These days M-O is up to the task of keeping paths clean in
the virtual world of terminal emulators.
To quote the master himself:

> Wow WoW WOW! - M-O
