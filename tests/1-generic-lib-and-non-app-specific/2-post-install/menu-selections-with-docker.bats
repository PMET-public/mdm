#!/usr/bin/env ./tests/libs/bats/bin/bats

# bats will loop indefinitely with debug mode on (i.e. set -x)
unset debug

load '../../libs/bats-assert/load'
load '../../libs/bats-support/load'
load '../../libs/bats-file/load'

load '../../../bin/lib.sh'

setup() {
  [ ! -f ${BATS_PARENT_TMPNAME}.skip ] || skip "skip remaining tests"
  shopt -s nocasematch
  is_docker_compatible || skip
}

@test '[docker] find_non_default_networks - normal function (not a menu item)' {

  # one time setup for various tests
  {
    docker network create network_w_exited_container
    docker network create network_w_running_container
    # create a container that exits immediately
    docker run --network=network_w_exited_container --name=exited_alpine_container alpine
    # create a running container in the background to account for how BATS handles background/child processes
    docker run --network=network_w_running_container --name=running_alpine_container alpine sleep 600 & 3>&-
    docker pull alpine:edge # download an image to prune
  }  > /dev/null
  is_advanced_mode || "$lib_dir/launcher" toggle_advanced_mode

  run find_non_default_networks
  assert_success
  assert_output -p 'network_w_exited_container'
}

@test '[docker] docker_prune_all_images' {
  yes | "$lib_dir/launcher" docker_prune_all_images
  run docker images
  assert_success
  assert_output -p 'alpine'
  refute_output -p 'edge'
}

@test '[docker] docker_prune_all_stopped_containers_and_volumes' {
  yes | "$lib_dir/launcher" docker_prune_all_stopped_containers_and_volumes
  run echo "$(docker ps -a)$(find_non_default_networks)"
  assert_success
  # verify running container and its network still exist while others deleted
  assert_output -p 'running_alpine_container'
  assert_output -p 'network_w_running_container'
  refute_output -p 'exited_alpine_container'
  refute_output -p 'network_w_exited_container'
}

@test '[docker] wipe_docker_except_images' {
  yes | "$lib_dir/launcher" wipe_docker_except_images
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

teardown() {
  [ -n "$BATS_TEST_COMPLETED" ] || touch ${BATS_PARENT_TMPNAME}.skip
}
