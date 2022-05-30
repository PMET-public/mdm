#!/usr/bin/env ./tests/libs/bats/bin/bats

# bats will loop indefinitely with debug mode on (i.e. set -x)
unset debug

load '../../libs/bats-assert/load'
load '../../libs/bats-support/load'
load '../../libs/bats-file/load'

load '../../../bin/lib.sh'
load '../../bats-lib.sh'

# this E2E test can 
# - test MDM itself using a specified magento-cloud project (default: PMET-public/magento-cloud) on a specified branch (default: master)
# - test a magento-cloud repo on its current commit and the specified ref of MDM
# - test a change to a dependency of a magento-cloud project and/or MDM


setup() {
  [ ! -f ${BATS_PARENT_TMPNAME}.skip ] || skip "remaining tests"
  post_magento_install_setup
  # get the most recently created app dir
  app_dir="$(ls -dtr "$HOME"/Downloads/*.app | tail -1 || :)"
  export apps_resources_dir="$app_dir/Contents/Resources"
  hostname1="random34653.some-new.site.dev"
  hostname2="altrandom2.testing.dev"
  hostname3="reset.testing.dev"
}


@test 'set_hostname_for_this_app' {
  run set_hostname_for_this_app "$hostname1"
  assert_success
  assert_output ""
}

@test 'set_hostname_for_this_app (2)' {
  run set_hostname_for_this_app "$hostname2"
  assert_success
  assert_output ""
}

@test 'get_hostname_for_this_app' {
  run get_hostname_for_this_app
  assert_success
  assert_output "$hostname2"
}

@test 'get_prev_hostname_for_this_app' {
  run get_prev_hostname_for_this_app
  assert_success
  assert_output "$hostname1"
}

@test 'set_hostname_for_this_app (3)' {
  run set_hostname_for_this_app "$hostname3"
  assert_success
  assert_output ""
}

@test 'get_prev_hostname_for_this_app (2)' {
  run get_prev_hostname_for_this_app
  assert_success
  assert_output "$hostname2"
}

@test 'export_compose_project_name' {
  export_compose_project_name
  output="$(env | grep COMPOSE_PROJECT_NAME=)"
  run echo "$output"
  refute_output -p "\." # not dots allowed in COMPOSE_PROJECT_NAME
  assert_output -e "^COMPOSE_PROJECT_NAME=.*"
}

@test 'export_compose_file' {
  export_compose_file
  output="$(env | grep COMPOSE_FILE=)"
  run echo "$output"
  assert_output -e "^COMPOSE_FILE=.*docker-compose.*mcd.override"
}

@test 'get_docker_compose_runtime_services' {
  export_compose_file
  run get_docker_compose_runtime_services
  assert_output -e "db"
  assert_output -e "varnish"
  assert_output -e "web"
}

teardown() {
  [ -n "$BATS_TEST_COMPLETED" ] || touch ${BATS_PARENT_TMPNAME}.skip
}
