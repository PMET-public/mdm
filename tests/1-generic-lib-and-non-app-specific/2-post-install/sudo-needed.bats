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
}

@test 'sudo_run_bash_cmds check env' {
  run sudo_run_bash_cmds "env | grep -q SUDO"
  assert_success
}

@test 'add_hostnames_to_hosts_file "random-hostname-that-should-not-exist"' {
  add_hostnames_to_hosts_file "random-hostname-that-should-not-exist"
  sleep 2 # slight delay needed b/c prev cmd runs async
  run grep -q "$hosts_file_line_marker" /etc/hosts &&
    is_hostname_resolving_to_local "random-hostname-that-should-not-exist"
  assert_success
  assert_output ''
}

@test 'add_hostnames_to_hosts_file "a b"' {
  add_hostnames_to_hosts_file "a b"
  sleep 2 # slight delay needed b/c prev cmd runs async
  run is_hostname_resolving_to_local "a" && is_hostname_resolving_to_local "b"
  assert_success
  assert_output ''
}

@test 'rm_added_hostnames_from_hosts_file' {
  is_advanced_mode || "$lib_dir/launcher" toggle_advanced_mode
  "$lib_dir/launcher" rm_added_hostnames_from_hosts_file
  run grep -q "$hosts_file_line_marker" /etc/hosts
  assert_failure
  assert_output ''
}

@test 'check /etc/hosts permissions' {
  run "$stat_cmd" -c '%a' /etc/hosts
  assert_success
  assert_output '644'
}

teardown() {
  [ -n "$BATS_TEST_COMPLETED" ] || touch ${BATS_PARENT_TMPNAME}.skip
}
