#!/bin/bash

set +x
shopt -s nocasematch

# shellcheck source=../../bin/lib.sh
source ./bin/lib.sh

msg "Running launcher
"
output="$(./bin/launcher)"
[[ $output =~ install ]] || exit 1

msg "Running launcher with output as param
"
./bin/launcher "$output"

msg "Running launcher with dependencies now installed:
"
./bin/launcher
output2="$(./bin/launcher)"


msg "Removing homebrew
"
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/uninstall.sh)"

msg "Rerunning launcher
"
output3="$(./bin/launcher)"

[[ "$output" -eq "$output3" ]] || exit 1

msg "Rerunning launcher with new output
"
./bin/launcher "$output3"

exit 0
