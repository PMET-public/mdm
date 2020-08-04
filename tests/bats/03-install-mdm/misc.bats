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

@test 'backup_hosts' {
  backup_hosts
  run diff /etc/hosts "$hosts_backup_dir/$(ls -t $hosts_backup_dir | head -n 1)"
  assert_success
  assert_output ''
}