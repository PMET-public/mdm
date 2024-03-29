#!/usr/bin/env ./tests/libs/bats/bin/bats

# bats will loop indefinitely with debug mode on (i.e. set -x)
unset debug

load '../../libs/bats-assert/load'
load '../../libs/bats-support/load'
load '../../libs/bats-file/load'

load '../../../bin/lib.sh'

setup() {
  [ ! -f ${BATS_PARENT_TMPNAME}.skip ] || skip "remaining tests"
  shopt -s nocasematch
}

@test 'launcher with initial output' {
  is_CI || skip # skip on dev
  output="$($lib_dir/launcher)"
  run "$lib_dir/launcher" "$output"
  assert_success
  assert_output -e "installed missing"
  assert_file_exist "$HOME/.mdm/current/bin/lib.sh"
}

@test '[CI] launcher install_additional_tools' {
  is_CI || skip # skip on dev
  run "$lib_dir/launcher" install_additional_tools
  assert_success
  assert_output -p "magento-cloud"
  assert_output -p "installed"
}

# unlike other MDM apps, the detached app is a singleton
@test 'create detached app' {
  cp "$lib_dir/../.mdm_config.tmpl.sh" "$lib_dir/../.mdm_config.sh"
  run "$lib_dir/dockerize" -d
  assert_success
  assert_output -e "created.*$detached_project_name"
}

@test '[osx] open detached app' {
  is_mac || skip
  run open -a "$detached_project_name"
  assert_success
  assert_output ''
}

teardown() {
  [ -n "$BATS_TEST_COMPLETED" ] || touch ${BATS_PARENT_TMPNAME}.skip
}
