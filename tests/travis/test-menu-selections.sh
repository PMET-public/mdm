#!/bin/bash

# shellcheck source=../../bin/lib.sh
source ./bin/lib.sh

launch_output="$(./bin/launcher)"

# on
./bin/launcher toggle_advanced_mode 

launch_output2="$(./bin/launcher)"

[[ "$launch_output" = "$launch_output2" ]] && error "Output should be different."

# off
./bin/launcher toggle_advanced_mode

launch_output3="$(./bin/launcher)"

[[ "$launch_output" = "$launch_output3" ]] || error "Output should be the same."

# on again
./bin/launcher toggle_advanced_mode

echo "$mdm_ver_file"

# stat_output="$(stat "$mdm_ver_file")"

# ./bin/launcher force_check_mdm_ver

# stat_output2="$(stat "$mdm_ver_file")"

# [[ "$stat_output" = "$stat_output2" ]] && error "Output should be different."

exit 0