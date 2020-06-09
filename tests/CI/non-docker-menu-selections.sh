#!/bin/bash

set -e
[[ $debug ]] && set -x

# shellcheck source=../../bin/lib.sh
source ./bin/lib.sh

./bin/launcher install_additional_tools

launch_output="$(./bin/launcher)"

# advanced mode on
./bin/launcher toggle_advanced_mode

launch_output2="$(./bin/launcher)"

[[ "$launch_output" = "$launch_output2" ]] && error "Launch output should be different."

# advanced mode  off
./bin/launcher toggle_advanced_mode

launch_output3="$(./bin/launcher)"

[[ "$launch_output" = "$launch_output3" ]] || error "Launch output should be the same."

# advanced mode on again
./bin/launcher toggle_advanced_mode


# force check mdm version
stat_output="$(stat "$mdm_ver_file")"

stat_output2="$(stat "$mdm_ver_file")"

./bin/launcher force_check_mdm_ver
wait # check runs in background

stat_output3="$(stat "$mdm_ver_file")"

[[ "$stat_output" = "$stat_output2" && "$stat_output" != "$stat_output3" ]] || error "Stat output should be different."

# 

exit 0