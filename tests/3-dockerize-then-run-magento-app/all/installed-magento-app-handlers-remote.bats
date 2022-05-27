#!/usr/bin/env ./tests/libs/bats/bin/bats

# bats will loop indefinitely with debug mode on (i.e. set -x)
unset debug

load '../../libs/bats-assert/load'
load '../../libs/bats-support/load'
load '../../libs/bats-file/load'

load '../../../bin/lib.sh'
load '../../bats-lib.sh'


# N.B. starting child processes during bats tests:
# https://github.com/bats-core/bats-core#file-descriptor-3-read-this-if-bats-hangs

setup() {
  [ ! -f ${BATS_PARENT_TMPNAME}.skip ] || skip "skip remaining tests"
  post_magento_install_setup
}

@test 'stop_tmate_session' {
  run "./$app_link_name" stop_tmate_session
  assert_success
  assert_output -e "no active"
}

@test 'start_tmate_session w/o authorized keys' {
  is_tmate_installed || skip
  [[ "$mdm_tmate_authorized_keys_url" ]] && skip
  output="$(yes | "./$app_link_name" start_tmate_session 3>&-)" # if no key url, have to confirm to continue
  run echo "$output"
  assert_success
  assert_output -e "no authorized.*ssh.*tmate.io"
}

@test 'start_tmate_session w/o authorized keys (2)' { # should simply run again
  is_tmate_installed || skip
  [[ "$mdm_tmate_authorized_keys_url" ]] && skip
  output="$(yes | "./$app_link_name" start_tmate_session 3>&-)" # if no key url, have to confirm to continue
  run echo "$output"
  assert_success
  assert_output -e "no authorized.*ssh.*tmate.io"
}

@test 'start_tmate_session with authorized keys' { # should d/l an update keys
  is_tmate_installed || skip
  [[ "$mdm_tmate_authorized_keys_url" ]] || skip
  output="$("./$app_link_name" start_tmate_session 3>&-)"
  run echo "$output"
  assert_success
  assert_output -e "ssh.*tmate.io"
}

@test 'start_tmate_session with authorized keys (2)' { # no update to keys the 2nd time
  is_tmate_installed || skip
  [[ "$mdm_tmate_authorized_keys_url" ]] || skip
  output="$("./$app_link_name" start_tmate_session 3>&-)"
  run echo "$output"
  assert_success
  assert_output -e "ssh.*tmate.io"
  refute_output -e "updated"
}

@test 'stop_tmate_session (2)' {
  run "./$app_link_name" stop_tmate_session
  assert_success
  assert_output -e "success"
}

@test 'stop_remote_web_access' {
  is_web_tunnel_configured || skip
  run "./$app_link_name" stop_remote_web_access
  assert_success
  assert_output -e "no active" # should successfully close 2 connections (tmate & web)
}

@test 'start_remote_web_access' {
  is_web_tunnel_configured || skip
  output=$(mktemp)
  # in CI envs on bash 4.4, this syntax worked when others failed
  "./$app_link_name" start_remote_web_access > "$output" 2>&1 3>&-
  run cat "$output"
  assert_success
  assert_output -e "success"
}

@test 'start_remote_web_access (2)' {
  is_web_tunnel_configured || skip
  run "./$app_link_name" start_remote_web_access
  assert_success
  assert_output -e "already" # already opened connection
}

@test 'stop_remote_web_access (2)' {
  is_web_tunnel_configured || skip
  run "./$app_link_name" stop_remote_web_access
  assert_success
  assert_output -e "success.*revert"
}

teardown() {
  [ -n "$BATS_TEST_COMPLETED" ] || touch ${BATS_PARENT_TMPNAME}.skip
}
