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

# rather than lib_dir will use full launcher path of specific app

# @test "toggle_mdm_debug_mode" {
#   is_advanced_mode || "$lib_dir/launcher" toggle_advanced_mode
#   output1="$("$lib_dir/launcher")"
#   "$lib_dir/launcher" toggle_mdm_debug_mode
#   output2="$("$lib_dir/launcher")"
#   run diff <(echo "$output1") <(echo "$output2")
#   assert_failure
#   assert_output -e "debugging.*on"
#   assert_output -e "debugging.*off"
# }