#!/bin/bash

# shellcheck source=../../bin/lib.sh
source ./bin/lib.sh

[[ $debug ]] && set -x

launch_output="$(./bin/launcher)"

# on
./bin/launcher toggle_advanced_mode 

launch_output2="$(./bin/launcher)"

[[ "$launch_output" = "$launch_output2" ]] && error "Launch output should be different."

# off
./bin/launcher toggle_advanced_mode

launch_output3="$(./bin/launcher)"

[[ "$launch_output" = "$launch_output3" ]] || error "Launch output should be the same."

# on again
./bin/launcher toggle_advanced_mode

stat_output="$(stat "$mdm_ver_file")"

stat_output2="$(stat "$mdm_ver_file")"

./bin/launcher force_check_mdm_ver
wait # check runs in background

stat_output3="$(stat "$mdm_ver_file")"

[[ "$stat_output" = "$stat_output2" && "$stat_output" != "$stat_output3" ]] || error "Stat output should be different."

# 

exit 0