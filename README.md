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
helper functions for the following use cases are available:

* Overwrite environment variable (e.g. `PS1`, `PATH`, `GOPATH`, ...) on enter
  (and restore it on leave).

* Activate Python virtual environment on enter (and deactivate it on delete).

* Set Node.js version using `nvm` (and restore it on leave).

## Install

M-O should be loaded and registered as part of your dotfiles setup.

The project is written to work for both bash (3+) and zsh.
The only difference in usage between the shells is which "register" file to source.

### Bash

In `.bashrc` and/or `.bash_profile`:

    MO_PATH=/path/to/M-O
    source "$MO_PATH/M-O.sh"
    source "$MO_PATH/extensions/action-helpers.sh" # Optional; see below.
    source "$MO_PATH/extensions/default-action.sh" # Optional; see below.
    source "$MO_PATH/register.bash"

### Zsh

In e.g. `.zshrc`:

    MO_PATH=/path/to/M-O
    source "$MO_PATH/M-O.sh"
    source "$MO_PATH/extensions/action-helpers.sh" # Optional; see below.
    source "$MO_PATH/extensions/default-action.sh" # Optional; see below.
    source "$MO_PATH/register.zsh"

## Entering and leaving

A directory is "entered" when the working directory is changed
from somewhere outside of its subtree to somewhere inside of it.
The directory is "left" when the working directory is changed back
to the outside of its subtree.

This means that when the current working directory changes,
M-O will execute actions corresponding to the following events:

1. "Leave" all directories from the previous working directory (inclusive)
   up to the closest common ancestor (exclusive).
  
2. "Enter" all directories from the closest common ancestor (exclusive)
   down to the next working directory (inclusive).

## Defining actions

When a directory `dir` containing the file `dir/.MO` is entered or left,
M-O will source this file and expose a number of dynamically scoped
local variables to it.
The two most important of these variables are `on_enter` and `on_leave`.
The script may overwrite these variables in order to bind actions
to the enter/leave events as described above.
As such, these variables may be thought of as the script's return values
and will be referred to as the "return variables".

The following other variables that M-O exposes to `.MO`
provide context that help make the files more generic:

* `dir`: The absolute path of the directory containing the file.

* `file`: The absolute path of the file.

One should *not* count on these variables maintaining their values from the
time the script is sourced until actions defined within it are executed.
In other words, no exposed variables should not appear unexpanded in the
return variables.

## Helpers

The following helper functions simplify action definitions:

* `MO_override_var <var> <val> <suffix>`:
  Overwrite the environment variable `<var>` with value `<val>` on enter
  The old value is kept in a temporary variable named `"$var$suffix"` which
  M-O will restore when leaving the directory.
  
* `MO_extend <on_enter_prependee> <on_leave_appendee>`:
  Augment the return variables by prepending `<on_enter_prependee>` to `on_enter`
  and appending `<on_leave_appendee>` to `on_leave`.
  As this function preserves previously registered return variables,
  this is the recommended way of registering actions.
* `MO_inject <on_enter_appendee> <on_leave_prependee>`:
  Augment the return variables by appending `<on_enter_appendee>` to `on_enter`
  and prepending `<on_leave_prependee>` to `on_leave`.
  As with `MO_extend`, this function preserves previously registered return variables.
  It is, however, expected to less commonly usable than `MO_extend`.

## Examples

TODO...

## Extensions

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
