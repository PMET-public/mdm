#!/usr/bin/env ./tests/libs/bats/bin/bats

# bats will loop indefinitely with debug mode on (i.e. set -x)
unset debug

load '../../libs/bats-assert/load'
load '../../libs/bats-support/load'
load '../../libs/bats-file/load'

load '../../../bin/lib.sh'
load '../../bats-lib.sh'


setup() {
  [ ! -f ${BATS_PARENT_TMPNAME}.skip ] || skip "skip remaining tests"
  post_magento_install_setup
}

@test 'stop_app' {
  "./$app_link_name" stop_app
  output="$(./$app_link_name)"
  # when app stops menu items should disappear
  while [[ "$output" =~ reindex.*run_cron ]]; do
    sleep 5
    output="$(./$app_link_name)"
  done
  run echo "$output"
  refute_output -p "stop_app"
  assert_output -p "restart_app"
}

@test 'restart_app' {
  "./$app_link_name" restart_app
  output="$(./$app_link_name)"
  # until app starts menu items will be unavailable
  while [[ ! "$output" =~ reindex.*run_cron ]]; do
    sleep 5
    output="$(./$app_link_name)"
  done
  run echo "$output"
  refute_output -p "restart_app"
  assert_output -p "stop_app"
}

@test 'clear_job_statuses' {
  "./$app_link_name" clear_job_statuses
  run "./$app_link_name"
  assert_success
  refute_output -p "clear_job_statuses" # if cleared, the cmd shouldn't be listed
}

teardown() {
  [ -n "$BATS_TEST_COMPLETED" ] || touch ${BATS_PARENT_TMPNAME}.skip
}
