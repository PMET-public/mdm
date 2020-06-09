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

./bin/launcher install_additional_tools

./bin/launcher

exit 0
