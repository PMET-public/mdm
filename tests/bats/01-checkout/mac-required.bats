#!/usr/bin/env ./tests/libs/bats/bin/bats

load '../../libs/bats-assert/load'
load '../../libs/bats-support/load'
load '../../libs/bats-file/load'

load '../../../bin/lib.sh'

setup() {
  shopt -s nocasematch
  is_docker_installed && is_docker_ready || error "Docker missing."
}

@test "is_mac" {
  run is_mac
  assert_success
}
