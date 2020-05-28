#!/bin/bash

set +x

# shellcheck source=../../bin/lib.sh
source ./bin/lib.sh

msg "Running launcher ..."
output=$(./bin/launcher)
msg "Output from launcher: $output"

msg "Running launcher with output ..."
./bin/launcher "$output"
