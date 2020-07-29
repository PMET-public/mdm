#!/bin/bash

set -e
[[ "$debug" ]] && set -x

# shellcheck source=../../bin/lib.sh
source ./bin/lib.sh

launcher_output="$(./bin/launcher)"

# advanced mode on
./bin/launcher toggle_advanced_mode

launcher_output2="$(./bin/launcher)"

[[ "$launcher_output" = "$launcher_output2" ]] && error "Launcher output should be different."

# advanced mode  off
./bin/launcher toggle_advanced_mode

launcher_output3="$(./bin/launcher)"

[[ "$launcher_output" = "$launcher_output3" ]] || error "Launcher output should be the same."

# advanced mode on again
./bin/launcher toggle_advanced_mode


# force check mdm version
stat_output="$(stat "$mdm_ver_file")"

stat_output2="$(stat "$mdm_ver_file")"

./bin/launcher force_check_mdm_ver
# TODO figure out why wait fails
wait # check runs in background
sleep 10

stat_output3="$(stat "$mdm_ver_file")"

[[ "$stat_output" = "$stat_output2" && "$stat_output" != "$stat_output3" ]] || error "Stat output should be different."

exit 0
