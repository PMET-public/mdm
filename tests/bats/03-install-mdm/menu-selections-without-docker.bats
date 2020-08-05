#!/usr/bin/env ./tests/libs/bats/bin/bats

# bats will loop indefinitely with debug mode on (i.e. set -x)
unset debug

load '../../libs/bats-assert/load'
load '../../libs/bats-support/load'
load '../../libs/bats-file/load'

load '../../../bin/lib.sh'

setup() {
  shopt -s nocasematch
}

@test "toggle_advanced mode" {
  # if the outputs are the same, it did not toggle
  is_advanced_mode || output1="off"
  "$lib_dir/launcher" toggle_advanced_mode
  is_advanced_mode || output2="off"
  run [ "$output1" == "$output2" ]
  assert_failure
}

@test "force_check_mdm_ver" {
  is_advanced_mode || "$lib_dir/launcher" toggle_advanced_mode
  output1="$("$stat_cmd" "$mdm_ver_file")"
  "$lib_dir/launcher" force_check_mdm_ver
  sleep 5
  output2="$("$stat_cmd" "$mdm_ver_file")"
  # mdm_ver_file metadata should be different even if content hasn't changed
  run diff <(echo "$output1") <(echo "$output2")
  assert_failure
}