#!/bin/bash

set -e
[[ $debug ]] && set -x

# shellcheck source=../../bin/lib.sh
source ./bin/lib.sh

msg_w_newlines "Running launcher ..."
output="$(./bin/launcher)"
shopt -s nocasematch
[[ $output =~ install ]] || error "Could not find install menu item."

msg_w_newlines "Running launcher with output as param ..."
./bin/launcher "$output"

msg_w_newlines "Running launcher with dependencies now installed ..."
./bin/launcher

# now try without homebrew pre-installed (for CI envs)
is_CI && is_mac && {

  msg_w_newlines "Removing homebrew ..."
  echo "y" | /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/uninstall.sh)"

  msg_w_newlines "Rerunning launcher ..."
  output3="$(./bin/launcher)"

  [[ "$output" = "$output3" ]] || error "Launcher output should be different."

  msg_w_newlines "Rerunning launcher with new output ..."
  ./bin/launcher "$output3"

  msg_w_newlines "Rerunning launcher with dependencies installed again ..."
  ./bin/launcher

}

./bin/launcher 

exit 0
