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

@test 'stop_remote_access' {
  # run twice to ensure no active sessions msg the 2nd time (in case dev env has 1+ open)
  "./$app_link_name" stop_remote_access
  run "./$app_link_name" stop_remote_access
  assert_success
  assert_output -e "no active"
}

@test 'start_tmate_session' {
  is_tmate_installed || skip
  if [[ "$mdm_tmate_authorized_keys_url" ]]; then
    output="$("./$app_link_name" start_tmate_session)"
  else 
    output="$(yes | "./$app_link_name" start_tmate_session)" # if no key url, have to confirm to continue
  fi
  run echo "$output"
  assert_success
  assert_output -e "updated.*ssh.*tmate.io"
}

@test 'start_tmate_session again' {
  is_tmate_installed || skip
  if [[ "$mdm_tmate_authorized_keys_url" ]]; then
    output="$("./$app_link_name" start_tmate_session)"
  else 
    output="$(yes | "./$app_link_name" start_tmate_session)" # if no key url, have to confirm to continue
  fi
  run echo "$output"
  assert_success
  assert_output -e "ssh.*tmate.io"
}

@test 'start_remote_web_access' {
  run "./$app_link_name" start_remote_web_access
  assert_success
  assert_output -e "success"
}

@test 'start_remote_web_access again' {
  run "./$app_link_name" start_remote_web_access
  assert_failure
  assert_output -e "already" # already opened connection
}

@test 'stop_remote_access again' {
  run "./$app_link_name" stop_remote_access
  assert_success
  assert_output -e "success.*success" # should successfully close 2 connections (tmate & web)
}