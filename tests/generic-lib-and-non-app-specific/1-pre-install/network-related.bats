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

@test 'is_valid_hostname "?a"' {
  run is_valid_hostname "?a"
  assert_failure
}

@test 'is_valid_hostname ".a"' {
  run is_valid_hostname ".a"
  assert_failure
}

@test 'is_valid_hostname "a?"' {
  run is_valid_hostname "a?"
  assert_failure
}

@test 'is_valid_hostname "a."' {
  run is_valid_hostname "a."
  assert_failure
}

@test 'is_hostname_resolving_to_local "localhost"' {
  run is_hostname_resolving_to_local "localhost"
  assert_success
  assert_output ""
}

@test 'is_hostname_resolving_to_local "pwa.$mdm_demo_domain"' {
  run is_hostname_resolving_to_local "pwa.$mdm_demo_domain"
  assert_success
  assert_output ""
}

@test 'is_hostname_resolving_to_local "pwa-prev.$mdm_demo_domain"' {
  run is_hostname_resolving_to_local "pwa-prev.$mdm_demo_domain"
  assert_success
  assert_output ""
}

@test 'is_hostname_resolving_to_local "google.com"' {
  run is_hostname_resolving_to_local "google.com"
  assert_failure
  assert_output ""
}

@test 'wildcard_domain_for_hostname "test.com"' {
  run wildcard_domain_for_hostname "test.com"
  assert_success
  assert_output "*.com"
}

@test 'wildcard_domain_for_hostname "www.test.com"' {
  run wildcard_domain_for_hostname "www.test.com"
  assert_success
  assert_output "*.test.com"
}

@test 'wildcard_domain_for_hostname "www.www.test.com"' {
  run wildcard_domain_for_hostname "www.www.test.com"
  assert_success
  assert_output "*.www.test.com"
}

@test 'normalize_domain_if_wildcard "test.com"' {
  run normalize_domain_if_wildcard "test.com"
  assert_success
  assert_output "test.com"
}

@test 'normalize_domain_if_wildcard "*.test.com"' {
  run normalize_domain_if_wildcard "*.test.com"
  assert_success
  assert_output ".test.com"
}

@test "lookup_latest_remote_sem_ver" {
  run lookup_latest_remote_sem_ver
  assert_success
  assert_output -e ".+\..+\..+"
}

@test "download_and_link_latest" {
  ver="$(lookup_latest_remote_sem_ver)"
  run download_and_link_latest
  assert_success
  assert_symlink_to "$HOME/.mdm/$ver" "$HOME/.mdm/current"
}

@test "download_and_link_latest develop" {
  run download_and_link_latest develop
  assert_success
  assert_symlink_to "$HOME/.mdm/develop" "$HOME/.mdm/current"
}
