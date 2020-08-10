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

# TODO reverse_array currently requires bash > 4 so must be tested (and used) after bash is updated
@test 'reverse_array ("a" 2 3 "a string")' {
  a1=("a" 2 3 "a string")
  reverse_array a1 a2
  run echo ${a2[@]}
  assert_success
  assert_output 'a string 3 2 a'
}

@test 'backup_hosts' {
  backup_hosts
  run diff /etc/hosts "$hosts_backup_dir/$(ls -t $hosts_backup_dir | head -n 1)"
  assert_success
  assert_output ''
}