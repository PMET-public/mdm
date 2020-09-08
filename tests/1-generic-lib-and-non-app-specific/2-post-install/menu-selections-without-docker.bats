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

@test 'toggle_advanced_mode' {
  # if the outputs are the same, it did not toggle
  is_advanced_mode || output1="off"
  "$lib_dir/launcher" toggle_advanced_mode
  is_advanced_mode || output2="off"
  run [ "$output1" == "$output2" ]
  assert_failure
}

@test 'toggle_mkcert_CA_install' {
  is_advanced_mode || "$lib_dir/launcher" toggle_advanced_mode
  output1="$("$lib_dir/launcher")"
  "$lib_dir/launcher" toggle_mkcert_CA_install
  output2="$("$lib_dir/launcher")"
  run diff <(echo "$output1") <(echo "$output2")
  assert_failure
  assert_output -e "spoofing.*on"
  assert_output -e "spoofing.*off"
}