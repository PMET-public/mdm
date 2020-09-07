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

@test 'change_base_url' {
  run "./$app_link_name" change_base_url
  assert_success
  assert_output -e "no active"
}

@test 'stop_remote_access' {
  # run twice to ensure no active sessions msg the 2nd time (in case dev env has 1+ open)
  "./$app_link_name" stop_remote_access
  run "./$app_link_name" stop_remote_access
  assert_success
  assert_output -e "no active"
}

@test 'start_tmate_session' {
  printf " " >> "$HOME/.ssh/authorized_keys" # add space at end to detect change
  run "./$app_link_name" start_tmate_session
  assert_success
  assert_output -e "updated.*ssh.*tmate.io"
}

@test 'start_tmate_session again' {
  printf " " >> "$HOME/.ssh/authorized_keys"
  run "./$app_link_name" start_tmate_session
  assert_success
  assert_output -e "updated.*ssh.*tmate.io"
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

@test 'stop_remote_access' {
  run "./$app_link_name" stop_remote_access
  assert_success
  assert_output -e "success.*success" # should successfully close 2 connections (tmate & web)
}