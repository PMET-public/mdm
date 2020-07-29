#!/usr/bin/env ./tests/libs/bats/bin/bats

load '../libs/bats-assert/load'
load '../libs/bats-support/load'
load '../libs/bats-file/load'

load '../../bin/lib.sh'

setup() {
  is_docker_installed && is_docker_ready || error "Docker missing."
}

@test "is_mac" {
  run is_mac
  assert_success
}

@test "are_required_ports_free 80" {
  docker run -p 80:80 -d nginx
  run are_required_ports_free
  assert_failure
}

@test "are_required_ports_free 443" {
  docker run -p 443:443 -d nginx
  run are_required_ports_free
  assert_failure
}