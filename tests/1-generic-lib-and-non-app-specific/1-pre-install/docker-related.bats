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
  is_docker_compatible || skip
  is_docker_running || {
    printf "Docker not ready. Starting docker ..." | tee /dev/tty
    start_docker_service
  }
}

@test '[docker] extract_tar_to_existing_container_path some.tar' {
  run extract_tar_to_existing_container_path some.tar.gz
  assert_failure
}

@test '[docker] extract_tar_to_existing_container_path some.tar some_container' {
  run extract_tar_to_existing_container_path some.tar.gz some_container
  assert_failure
}

@test '[docker] extract_tar_to_existing_container_path some.tar some_container:/some_dir' {
  mkdir -p a/1 a/2
  msg="hello, world!"
  echo "$msg" > a/1/file1
  tar -zcf some.tar.gz a
  # simple container that will remove itself after brief period (enough for test)
  cid="$(docker run --rm -d alpine sleep 20)"
  extract_tar_to_existing_container_path some.tar.gz "$cid:/tmp"
  docker cp "$cid:/tmp/a/1/file1" file1
  run cat file1 && rm -rf a some.tar.gz file1
  assert_success
  assert_output "$msg"
}

@test '[docker] are_required_ports_free with no running containers' {
  docker stop $(docker ps -qa) || :
  run are_required_ports_free
  assert_success
}

@test '[docker] are_required_ports_free 80' {
  docker stop $(docker ps -qa) || :
  docker run -p 80:80 -d nginx
  sleep 5 # docker background process may take a moment
  run are_required_ports_free
  assert_failure
}

@test '[docker] are_required_ports_free 443' {
  docker stop $(docker ps -qa) || :
  docker run -p 443:443 -d nginx
  sleep 5 # docker background process may take a moment
  run are_required_ports_free
  assert_failure
}

@test '[docker] adjust_compose_project_name_for_docker_compose_reqs SomeProj-Env' {
  shopt -u nocasematch
  run adjust_compose_project_name_for_docker_compose_reqs "SomeProj-Env"
  assert_success
  assert_output "someproj-env"
}

teardown() {
  [ -n "$BATS_TEST_COMPLETED" ] || touch ${BATS_PARENT_TMPNAME}.skip
}
