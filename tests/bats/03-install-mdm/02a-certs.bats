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

@test 'does_cert_and_key_exist_for_domain "localhost"' {
  run does_cert_and_key_exist_for_domain "localhost"
  assert_success
  assert_output ""
}

@test 'read_cert_for_domain ".$mdm_demo_domain"' {
  run read_cert_for_domain ".$mdm_demo_domain"
  assert_success
  assert_output -e "DNS:.*\*\.$mdm_demo_domain"
}

@test 'read_cert_for_domain "*.$mdm_demo_domain"' {
  run read_cert_for_domain "*.$mdm_demo_domain"
  assert_success
  assert_output -e "DNS:.*\*\.$mdm_demo_domain"
}

@test 'does_cert_and_key_exist_for_domain "*.$mdm_demo_domain"' {
  get_wildcard_cert_and_key_for_mdm_demo_domain
  run does_cert_and_key_exist_for_domain "*.$mdm_demo_domain"
  assert_success
}

@test 'does_cert_and_key_exist_for_domain ".$mdm_demo_domain"' {
  get_wildcard_cert_and_key_for_mdm_demo_domain
  run does_cert_and_key_exist_for_domain ".$mdm_demo_domain"
  assert_success
}

@test 'does_cert_and_key_exist_for_domain "made-up-localhost"' {
  run does_cert_and_key_exist_for_domain "made-up-localhost"
  assert_failure
}

@test 'read_cert_for_domain "localhost"' {
  run read_cert_for_domain "localhost"
  assert_success
  assert_output -e "DNS:.*localhost"
}

@test 'read_cert_for_domain "made-up-localhost"' {
  run read_cert_for_domain "made-up-localhost"
  assert_failure
  assert_output -p "Error:"
}

@test 'get_cert_utc_end_date_for_domain "localhost"' {
  run get_cert_utc_end_date_for_domain "localhost"
  assert_success
  assert_output -e "^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$"
}

@test 'get_cert_utc_end_date_for_domain "$mdm_demo_domain"' {
  run get_cert_utc_end_date_for_domain "$mdm_demo_domain"
  assert_success
  assert_output -e "^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$"
}

@test 'get_cert_utc_end_date_for_domain "made-up-localhost"' {
  run get_cert_utc_end_date_for_domain "made-up-localhost"
  assert_failure
  assert_output -p "Error:"
}

@test 'is_cert_current_for_domain "localhost"' {
  run is_cert_current_for_domain "localhost"
  assert_success
  assert_output ""
}

@test 'is_cert_current_for_domain "$mdm_demo_domain"' {
  run is_cert_current_for_domain "$mdm_demo_domain"
  assert_success
  assert_output ""
}

@test 'is_cert_current_for_domain "made-up-localhost"' {
  run is_cert_current_for_domain "made-up-localhost"
  assert_failure
  assert_output -p "Error:"
}

@test 'is_cert_for_domain_expiring_soon "localhost"' {
  run is_cert_for_domain_expiring_soon "localhost"
  assert_failure
  assert_output ""
}

@test 'is_cert_for_domain_expiring_soon "$mdm_demo_domain"' {
  run is_cert_for_domain_expiring_soon "$mdm_demo_domain"
  assert_failure
  assert_output ""
}

@test 'is_cert_for_domain_expiring_soon "made-up-localhost"' {
  run is_cert_for_domain_expiring_soon "made-up-localhost"
  assert_failure
  assert_output -p "Error:"
}

@test 'does_cert_follow_convention "localhost"' {
  run does_cert_follow_convention "localhost"
  assert_success
  assert_output ""
}

@test 'does_cert_follow_convention "pwa.$mdm_demo_domain"' {
  cp_wildcard_mdm_demo_domain_cert_and_key_for_subdomain "pwa.$mdm_demo_domain"
  run does_cert_follow_convention "pwa.$mdm_demo_domain"
  assert_success
  assert_output ""
}


@test 'does_cert_follow_convention "made-up-localhost"' {
  run does_cert_follow_convention "made-up-localhost"
  assert_failure
  assert_output -p "Error:"
}

@test 'is_new_cert_required_for_domain "localhost"' {
  run is_new_cert_required_for_domain "localhost"
  assert_failure
  assert_output ""
}

@test 'is_new_cert_required_for_domain "$mdm_demo_domain"' {
  run is_new_cert_required_for_domain "$mdm_demo_domain"
  assert_failure
  assert_output ""
}

@test 'is_new_cert_required_for_domain "made-up-localhost"' {
  run is_new_cert_required_for_domain "made-up-localhost"
  assert_success
}
