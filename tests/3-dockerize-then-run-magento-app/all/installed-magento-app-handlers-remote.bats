#!/usr/bin/env ./tests/libs/bats/bin/bats

# bats will loop indefinitely with debug mode on (i.e. set -x)
unset debug

load '../../libs/bats-assert/load'
load '../../libs/bats-support/load'
load '../../libs/bats-file/load'

load '../../../bin/lib.sh'
load '../../bats-lib.sh'


setup() {
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
  output="$(yes | "./$app_link_name" start_tmate_session)" # if no key url, have to confirm to continue
  run echo "$output"
  assert_success
  assert_output -e "no authorized.*ssh.*tmate.io"
}

@test 'start_tmate_session w/o authorized keys again' { # should simply run again
  is_tmate_installed || skip
  [[ "$mdm_tmate_authorized_keys_url" ]] && skip
  output="$(yes | "./$app_link_name" start_tmate_session)" # if no key url, have to confirm to continue
  run echo "$output"
  assert_success
  assert_output -e "no authorized.*ssh.*tmate.io"
}

@test 'start_tmate_session with authorized keys' { # should d/l an update keys
  is_tmate_installed || skip
  [[ "$mdm_tmate_authorized_keys_url" ]] || skip
  output="$("./$app_link_name" start_tmate_session)"
  run echo "$output"
  assert_success
  assert_output -e "updated.*ssh.*tmate.io"
}

@test 'start_tmate_session with authorized keys again' { # no update to keys the 2nd time
  is_tmate_installed || skip
  [[ "$mdm_tmate_authorized_keys_url" ]] || skip
  output="$("./$app_link_name" start_tmate_session)"
  run echo "$output"
  assert_success
  assert_output -e "ssh.*tmate.io"
  refute_output -e "updated"
}

@test 'stop_remote_web_access' {
  is_web_tunnel_configured || skip
  run "./$app_link_name" stop_remote_web_access
  assert_success
  assert_output -e "no active" # should successfully close 2 connections (tmate & web)
}

@test 'start_remote_web_access' {
  is_web_tunnel_configured || skip
  run "./$app_link_name" start_remote_web_access
  assert_success
  assert_output -e "success"
}

@test 'start_remote_web_access again' {
  is_web_tunnel_configured || skip
  run "./$app_link_name" start_remote_web_access
  assert_failure
  assert_output -e "already" # already opened connection
}

@test 'stop_remote_web_access again' {
  is_web_tunnel_configured || skip
  run "./$app_link_name" stop_tmate_session
  assert_success
  assert_output -e "success" # should successfully close 2 connections (tmate & web)
}