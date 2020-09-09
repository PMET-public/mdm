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

@test 'self_install' {
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

# additional tools part 1
@test 'launcher after initial install' {
  # remove an inconsequential tool to run this test locally
  is_mac && rm "$(brew --prefix)"/etc/bash_completion.d/docker* || :
  run "$lib_dir/launcher"
  assert_success
  assert_output -p "additional_tools"
}

# additional tools part 2 opt a
@test '[CI] launcher install_additional_tools' {
  is_CI || skip
  run "$lib_dir/launcher" install_additional_tools
  assert_success
  assert_output -p "magento-cloud"
  assert_output -p "installed"
}

# additional tools part 2 opt b
@test '[dev] launcher install_additional_tools' {
  is_CI && skip
  run "$lib_dir/launcher" install_additional_tools
  assert_success
  assert_output -p "installed"
}

# if docker is not running, a message should ask the user to start docker
@test '[docker] launcher needs running docker to continue' {
  is_docker_compatible || skip
  stop_docker_service
  run "$lib_dir/launcher"
  assert_success
  assert_output -e "start docker"
  refute_output -p "advanced"
}

# start docker and the normal menu should display
@test '[docker] launcher start_docker' {
  is_docker_compatible || skip
  "$lib_dir/launcher" start_docker
  run "$lib_dir/launcher"
  assert_success
  assert_output -e "advanced"
}