#!/bin/bash

set -e
[[ $debug ]] && set -x

# shellcheck source=../../bin/lib.sh
source ./bin/lib.sh

# now try without homebrew pre-installed (for CI envs)
output="$(./bin/launcher)"

msg_w_newlines "Removing homebrew ..."
yes | /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/uninstall.sh)"

msg_w_newlines "Rerunning launcher ..."
output2="$(./bin/launcher)" # output2 should be install prereqs option

[[ "$output" = "$output2" ]] && error "Launcher output should be different."

msg_w_newlines "Rerunning launcher with new output ..."
./bin/launcher "$output2"

msg_w_newlines "Rerunning launcher with dependencies installed again ..."
./bin/launcher

exit 0
