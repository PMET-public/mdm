#!/usr/bin/env ./tests/libs/bats/bin/bats

# bats will loop indefinitely with debug mode on (i.e. set -x)
unset debug

load '../../libs/bats-assert/load'
load '../../libs/bats-support/load'
load '../../libs/bats-file/load'

load '../../../bin/lib.sh'

setup() {
  shopt -s nocasematch
}

@test 'create detached app' {
  run "$lib_dir/dockerize" -d
  assert_success
  assert_output -e "created.*$detached_project_name"
}

@test '[osx] open detached app' {
  is_mac || skip
  run open -a "$detached_project_name"
  assert_success
  assert_output ''
}


#  run ps aux | grep -qE "$detached_project_name\$"