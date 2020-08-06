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

@test "self_install" {
  self_uninstall
  run self_install
  assert_success
  assert_output -p "installed"
}

@test 'launcher' {
  self_uninstall
  run "$lib_dir/launcher"
  assert_success
  assert_output -e "install missing"
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

@test '[dev] launcher install_additional_tools' {
  is_CI && skip
  # remove a inconsequential tool to run this test locally
  rm "$(brew --prefix)"/etc/bash_completion.d/docker* || :
  run "$lib_dir/launcher" install_additional_tools
  assert_success
  assert_output -p "installed"
}

@test '[docker] launcher needs running docker to continue' {
  is_docker_compatible || skip
  stop_docker_service
  run "$lib_dir/launcher"
  assert_success
  assert_output -e "start docker"
  refute_output -p "advanced"
}