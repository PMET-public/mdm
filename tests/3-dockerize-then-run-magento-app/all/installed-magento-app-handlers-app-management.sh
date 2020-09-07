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

@test 'stop_app' {
  "./$app_link_name" stop_app
  while is_magento_app_running; do
    sleep 5
  done
  run is_magento_app_running
  assert_failure
  assert_output ""
}

@test 'restart_app' {
  "./$app_link_name" restart_app
  while ! is_magento_app_running; do
    sleep 5
  done
  run is_magento_app_running
  assert_success
  assert_output ""
}

@test 'clear_job_statuses' {
  "./$app_link_name" clear_job_statuses
  run "./$app_link_name"
  assert_success
  refute_output -p "clear_job_statuses" # if cleared, the cmd shouldn't be listed
}