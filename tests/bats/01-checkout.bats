#!/usr/bin/env ./tests/libs/bats/bin/bats

# bats will loop indefinitely with debug mode on (i.e. set -x)
unset debug

load '../libs/bats-assert/load'
load '../libs/bats-support/load'
load '../libs/bats-file/load'

load '../../bin/lib.sh'

@test 'convert_secs_to_hms "3599"' {
  run convert_secs_to_hms "3599"
  assert_equal "${lines[0]}" '59m 59s'
}

@test 'convert_secs_to_hms "3600"' {
  run convert_secs_to_hms "3600"
  assert_equal "${lines[0]}" '1h 0m 0s'
}

@test 'convert_secs_to_hms "3601"' {
  run convert_secs_to_hms "3601"
  assert_equal "${lines[0]}" '1h 0m 1s'
}

@test 'confirm_or_exit "y"' {
  run confirm_or_exit <<< 'y'
  assert_success
  refute_output 'unchanged'
}

@test 'confirm_or_exit "n"' {
  run confirm_or_exit <<< 'n'
  assert_success
  assert_output -p 'unchanged'
}

@test 'trim " removed left space"' {
  run trim " removed left space"
  assert_success
  assert_output "removed left space"
}

@test 'trim "removed right space "' {
  run trim "removed right space "
  assert_success
  assert_output "removed right space"
}

@test 'trim " removed both spaces "' {
  run trim " removed both spaces "
  assert_success
  assert_output "removed both spaces"
}

@test 'trim "removed no spaces"' {
  run trim "removed no spaces"
  assert_success
  assert_output "removed no spaces"
}

@test 'trim "  removed many spaces  "' {
  run trim "  removed many spaces   "
  assert_success
  assert_output "removed many spaces"
}

@test 'msg "some-msg"' {
  run msg "some-msg"
  assert_success
  assert_output -p "some-msg"
}

@test 'warning "some-warning"' {
  run warning "some-warning"
  assert_success
  assert_output -p "some-warning"
}

@test 'error "some-error"' {
  run error "some-error"
  assert_failure
  assert_output -e "Error:.*some-error"
}

@test 'is_valid_git_url "https://github.com/PMET-public/mdm.git"' {
  run is_valid_git_url "https://github.com/PMET-public/mdm.git"
  assert_success
  assert_output ""
}

@test 'is_valid_git_url "git@github.com:PMET-public/mdm.git"' {
  run is_valid_git_url "git@github.com:PMET-public/mdm.git"
  assert_success
  assert_output ""
}

@test 'is_valid_git_url "google.com"' {
  run is_valid_git_url "google.com"
  assert_failure
  assert_output ""
}

@test 'is_terminal_interactive' {
  run is_terminal_interactive
  assert_failure
  assert_output ""
}

@test 'normalize_hostname "a?" -> "a"' {
  run normalize_hostname "a?"
  assert_output 'a'
}

@test 'normalize_hostname "?a" -> ""' {
  run normalize_hostname "?a"
  assert_output ''
}

@test 'is_hostname_curlable "?a"' {
  run is_hostname_curlable "?a"
  assert_failure
}

@test 'is_hostname_curlable "a?"' {
  run is_hostname_curlable "a?"
  assert_success
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
