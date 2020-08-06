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

@test 'sudo_run_bash_cmds echo string' {
  run sudo_run_bash_cmds "echo 'Hello, world!'"
  assert_success
  assert_output 'Hello, world!'
}

@test 'sudo_run_bash_cmds check env' {
  run sudo_run_bash_cmds "env | grep -q SUDO"
  assert_success
}

@test 'add_hostnames_to_hosts_file "random-hostname-that-should-not-exist"' {
  add_hostnames_to_hosts_file "random-hostname-that-should-not-exist"
  run grep -q "$hosts_file_line_marker" /etc/hosts && 
    is_hostname_resolving_to_local "random-hostname-that-should-not-exist"
  assert_success
  assert_output ''
}

@test 'add_hostnames_to_hosts_file "a b"' {
  add_hostnames_to_hosts_file "a b"
  run is_hostname_resolving_to_local "a" && is_hostname_resolving_to_local "b"
  assert_success
  assert_output ''
}

@test 'rm_added_hostnames_from_hosts_file' {
  rm_added_hostnames_from_hosts_file
  run grep -q "$hosts_file_line_marker" /etc/hosts
  assert_failure
  assert_output ''
}

@test 'check /etc/hosts permissions' {
  run "$stat_cmd" -c '%a' /etc/hosts
  assert_success
  assert_output '644'
}