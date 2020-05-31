#!/bin/bash

# shellcheck source=../../bin/lib.sh
source ./bin/lib.sh

msg "Running launcher
"
output="$(./bin/launcher)"
shopt -s nocasematch
[[ $output =~ install ]] || exit 1

msg "Running launcher with output as param
"
./bin/launcher "$output"

msg "Running launcher with dependencies now installed:
"
./bin/launcher

# now try without homebrew pre-installed (for travis-ci envs)
[[ "$TRAVIS" && "$(uname)" = "Darwin" ]] && {

  msg "Removing homebrew
  "
  echo "y" | /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/uninstall.sh)"

  msg "Rerunning launcher
  "
  output3="$(./bin/launcher)"

  [[ "$output" = "$output3" ]] || exit 1

  msg "Rerunning launcher with new output
  "
  ./bin/launcher "$output3"

  msg "Rerunning launcher with dependencies installed again
  "
  ./bin/launcher

}

exit 0
