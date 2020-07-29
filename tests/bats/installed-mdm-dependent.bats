#!/usr/bin/env ./tests/libs/bats/bin/bats

load '../libs/bats-assert/load'
load '../libs/bats-support/load'
load '../libs/bats-file/load'

load '../../bin/lib.sh'

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

@test 'is_hostname_resolving_to_local "pwa.storystore.dev"' {
  run is_hostname_resolving_to_local "pwa.storystore.dev"
  assert_success
  assert_output ""
}

@test 'is_hostname_resolving_to_local "pwa-prev.storystore.dev"' {
  run is_hostname_resolving_to_local "pwa-prev.storystore.dev"
  assert_success
  assert_output ""
}

@test 'is_hostname_resolving_to_local "google.com"' {
  run is_hostname_resolving_to_local "google.com"
  assert_failure
  assert_output ""
}

@test 'does_cert_and_key_exist_for_host "localhost"' {
  run does_cert_and_key_exist_for_host "localhost"
  assert_success
  assert_output ""
}

@test 'does_cert_and_key_exist_for_host "made-up-localhost"' {
  run does_cert_and_key_exist_for_host "made-up-localhost"
  assert_failure
}

@test 'read_cert_for_hostname "localhost"' {
  run read_cert_for_hostname "localhost"
  assert_success
  assert_output -e "DNS:.*localhost"
}

@test 'read_cert_for_hostname "made-up-localhost"' {
  run read_cert_for_hostname "made-up-localhost"
  assert_failure
  assert_output -p "Error:"
}

@test 'get_cert_utc_end_date_for_hostname "localhost"' {
  run get_cert_utc_end_date_for_hostname "localhost"
  assert_success
  assert_output -e "^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$"
}

@test 'get_cert_utc_end_date_for_hostname "made-up-localhost"' {
  run get_cert_utc_end_date_for_hostname "made-up-localhost"
  assert_failure
  assert_output -p "Error:"
}

@test 'is_cert_for_hostname_current "localhost"' {
  run is_cert_for_hostname_current "localhost"
  assert_success
  assert_output ""
}

@test 'is_cert_for_hostname_current "made-up-localhost"' {
  run is_cert_for_hostname_current "made-up-localhost"
  assert_failure
  assert_output -p "Error:"
}

@test 'is_cert_for_hostname_expiring_soon "localhost"' {
  run is_cert_for_hostname_expiring_soon "localhost"
  assert_failure
  assert_output ""
}

@test 'is_cert_for_hostname_expiring_soon "made-up-localhost"' {
  run is_cert_for_hostname_expiring_soon "made-up-localhost"
  assert_failure
  assert_output -p "Error:"
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

@test 'is_cert_match_for_hostname "localhost"' {
  run is_cert_match_for_hostname "localhost"
  assert_success
  assert_output ""
}

@test 'is_cert_match_for_hostname "made-up-localhost"' {
  run is_cert_match_for_hostname "made-up-localhost"
  assert_failure
  assert_output -p "Error:"
}

@test 'is_new_cert_required_for_host "localhost"' {
  run is_new_cert_required_for_host "localhost"
  assert_failure
  assert_output ""
}

@test 'is_new_cert_required_for_host "made-up-localhost"' {
  run is_new_cert_required_for_host "made-up-localhost"
  assert_success
}
