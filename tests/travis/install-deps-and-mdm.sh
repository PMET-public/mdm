#!/bin/bash

set +x

# shellcheck source=../../bin/lib.sh
source ./bin/lib.sh

msg "Running launcher"
output=$(./bin/launcher)
msg "Output from launcher: $output"

msg "Running launcher with output as param"
./bin/launcher "$output"

msg "Running launcher with dependencies now installed"
./bin/launcher