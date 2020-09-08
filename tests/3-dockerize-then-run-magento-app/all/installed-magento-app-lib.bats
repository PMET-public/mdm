#!/usr/bin/env ./tests/libs/bats/bin/bats

# bats will loop indefinitely with debug mode on (i.e. set -x)
unset debug

load '../../libs/bats-assert/load'
load '../../libs/bats-support/load'
load '../../libs/bats-file/load'

load '../../../bin/lib.sh'

# this E2E test can 
# - test MDM itself using a specified magento-cloud project (default: PMET-public/magento-cloud) on a specified branch (default: master)
# - test a magento-cloud repo on its current commit and the specified ref of MDM
# - test a change to a dependency of a magento-cloud project and/or MDM


setup() {
  shopt -s nocasematch
  # get the most recently created app dir
  app_dir="$(ls -dtr "$HOME"/Downloads/*.app | tail -1 || :)"
  export apps_resources_dir="$app_dir/Contents/Resources"
  export ORIGINAL_APP_HOSTNAME
}

@test 'get_hostname_for_this_app' {
  output="$(get_hostname_for_this_app)"
  export ORIGINAL_APP_HOSTNAME="$output"
  run echo "$output"
  assert_success
  assert_output -e "[A-Za-z0-9]+"
}

@test 'get_prev_hostname_for_this_app' {
  run get_prev_hostname_for_this_app
  assert_success
  assert_output "$ORIGINAL_APP_HOSTNAME"
}

@test 'set_hostname_for_this_app' {
  run set_hostname_for_this_app "34653.some-new.site.dev"
  assert_success
  assert_output ""
}

@test 'get_hostname_for_this_app (2)' {
  run get_hostname_for_this_app
  assert_success
  assert_output -e "34653.some-new.site.dev"
}

@test 'get_prev_hostname_for_this_app (2)' {
  run get_prev_hostname_for_this_app
  assert_success
  assert_output "$ORIGINAL_APP_HOSTNAME"
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
