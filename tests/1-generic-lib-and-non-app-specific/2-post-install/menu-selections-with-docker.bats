#!/usr/bin/env ./tests/libs/bats/bin/bats

# bats will loop indefinitely with debug mode on (i.e. set -x)
unset debug

load '../../libs/bats-assert/load'
load '../../libs/bats-support/load'
load '../../libs/bats-file/load'

load '../../../bin/lib.sh'

setup() {
  shopt -s nocasematch
  is_docker_compatible || skip
}


@test '[docker] find_non_default_networks - normal function (not a menu item)' {
  run find_non_default_networks
  assert_success
  assert_output -p 'mymdmtestnetwork'
}

@test '[docker] alpine container still exists' {
  run docker inspect mytestalpinecontainer
  assert_success
}

@test '[docker] mymdmtestnetwork still exists' {
  run docker inspect mymdmtestnetwork
  assert_success
}

@test '[docker] reset_docker' {
  yes | "$lib_dir/launcher" reset_docker
  run echo "$(docker ps -qa)$(find_non_default_networks)$(docker volume ls -q)"
  assert_success
  assert_output ''
}

@test '[docker] reset_docker - 2nd time' {
  yes | "$lib_dir/launcher" reset_docker
  run echo "$(docker ps -qa)$(find_non_default_networks)$(docker volume ls -q)"
  assert_success
  assert_output ''
}

@test '[docker] alpine image still exists' {
  run docker images --format '{{.Repository}}'
  assert_success
  assert_output -p 'alpine'
}

@test '[docker] wipe_docker' {
  yes | "$lib_dir/launcher" wipe_docker
  run echo "$(docker ps -qa)$(docker images -q)$(find_non_default_networks)$(docker volume ls -q)"
  assert_success
  assert_output ''
}

@test '[docker] wipe_docker - 2nd time' {
  yes | "$lib_dir/launcher" wipe_docker
  run echo "$(docker ps -qa)$(docker images -q)$(find_non_default_networks)$(docker volume ls -q)"
  assert_success
  assert_output ''
}