#!/usr/bin/env ./tests/libs/bats/bin/bats

# bats will loop indefinitely with debug mode on (i.e. set -x)
unset debug

load '../libs/bats-assert/load'
load '../libs/bats-support/load'
load '../libs/bats-file/load'

load '../../bin/lib.sh'

@test './bin/launcher' {
  shopt -s nocasematch
  run ./bin/launcher
  assert_success
  assert_output -e "install.*missing"
}

@test './bin/launcher with initial output' {
  shopt -s nocasematch
  output="$(./bin/launcher)"
  run ./bin/launcher "$output"
  assert_success
  assert_output -e "installed"
}

@test './bin/launcher install_additional_tools' {
  shopt -s nocasematch
  run ./bin/launcher install_additional_tools
  assert_success
  assert_output -e "magento-cloud.*mkcert.*installed"
}
