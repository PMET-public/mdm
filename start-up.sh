#!/usr/bin/env bash

set -e # stop on errors
# set -x # turn on debugging

# the Platypus status menu app will initially run this script without arguments
# and display each line of STDOUT as an option
# so it's critical to complete ASAP when run w/o args to reduce perceived latency
#
# when a menu item is selected, this script is run again in the background w/ the menu item text passed as an arg
# the Platyplus app does not wait for the background run to complete before the menu can be rendered again
#


# check dependencies
# has to be run every time because app could be copied to new computer or user may uninstall dep(s)

if [[

  ${BASH_VERSINFO[0]} -ge 5 && \
  -f /usr/local/bin/brew && \
  -f /usr/local/bin/realpath && \
  -d /Applications/Docker.app

]]; then

  # N.B. the script is invoked by `/usr/bin/env -P "/usr/local/bin:/bin" bash "/path/to/script"`
  # using the upgraded bash if found or /bin/bash. however, -P does not export the path, just sets it for `env`.
  # so export PATH if necessary after tools are installed
  [[ "$PATH" =~ "/usr/local/bin" ]] || export PATH="/usr/local/bin:$PATH"

  # since the dependecies passed, use realpath & run main app
  # shellcheck source=manage-dockerized-cloud-env.sh
  source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/manage-dockerized-cloud-env.sh"

else

  # some dependency is missing
  # if called without args, prompt user to install

  if [[ ${#BASH_ARGV[@]} -eq 0 ]]; then

    echo "Install missing requirements on this computer" && exit

  else

    # due to symlinking, cd to right dir to execute script
    cd "$(dirname "${BASH_SOURCE[0]}")" || exit
    link="$(readlink "${BASH_SOURCE[0]}")"
    [[ -n "$link" ]] && {
      cd "$(dirname "$link")" || exit
    }
    open -a Terminal install-initial-dependencies.sh

  fi

fi


