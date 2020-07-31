#!/usr/bin/env ./tests/libs/bats/bin/bats

# bats will loop indefinitely with debug mode on (i.e. set -x)
unset debug

load '../libs/bats-assert/load'
load '../libs/bats-support/load'
load '../libs/bats-file/load'

load '../../bin/lib.sh'

setup() {
  shopt -s nocasematch
}

@test "self_install" {
  self_uninstall
  run self_install
  assert_success
  assert_output -p "installed"
  assert_output -p "terminal"
}

@test './bin/launcher' {
  self_uninstall
  run ./bin/launcher
  assert_success
  assert_output -e "install.*missing"
}

@test './bin/launcher with initial output' {

  output="$(./bin/launcher)"
  run ./bin/launcher "$output"
  assert_success
  assert_output -p "installed"
}

@test './bin/launcher install_additional_tools' {
  run ./bin/launcher install_additional_tools
  assert_success
  assert_output -p "magento-cloud"
  assert_output -p "installed"
}
