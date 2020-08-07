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

@test 'launcher with initial output' {
  output="$($lib_dir/launcher)"
  run "$lib_dir/launcher" "$output"
  assert_success
  assert_output -e "installed missing"
  assert_file_exist "$HOME/.mdm/current/bin/lib.sh"
}

@test '[CI] launcher install_additional_tools' {
  is_CI || skip
  run "$lib_dir/launcher" install_additional_tools
  assert_success
  assert_output -p "magento-cloud"
  assert_output -p "installed"
}

