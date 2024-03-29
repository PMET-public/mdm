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


@test 'is_string_valid_composer_credentials valid 1' {
  input='{"github-oauth":{"github.com":"test"},"http-basic":{"repo.magento.com":{"username":"test","password":"test"}}}'
  run is_string_valid_composer_credentials "$input"
  assert_success
  assert_output ""
}

@test 'is_string_valid_composer_credentials valid 2' {
  input='{"github-oauth":{"github.com":"test"},
    "http-basic":{"repo.magento.com":{"username":"test","password":"test"}}}'
  run is_string_valid_composer_credentials "$input"
  assert_success
  assert_output ""
}

@test 'is_string_valid_composer_credentials valid 3' {
  input='{
    "github-oauth":{"github.com":"test"},
    "http-basic":{
      "repo.magento.com":{"username":"test","password":"test"},
      "connect20-qa01":{"username":"test","password":"test"}
      }
    }'
  run is_string_valid_composer_credentials "$input"
  assert_success
  assert_output ""
}

@test 'is_string_valid_composer_credentials invalid 1' {
  [[ "$(jq --version)" =~ 1\.5 ]] && skip # jq 1.5 ignore the missing closing '}'
  input='{"github-oauth":{"github.com":"test"},"http-basic":{"repo.magento.com":{"username":"test","password":"test"}}'
  run is_string_valid_composer_credentials "$input"
  assert_failure
  assert_output ""
}

@test 'is_string_valid_composer_credentials invalid 2' {
  input='"github-oauth":{"github.com":"test"},"http-basic":{"repo.magento.com":{"username":"test","password":"test"}}}'
  run is_string_valid_composer_credentials "$input"
  assert_failure
  assert_output ""
}

@test 'is_string_valid_composer_credentials invalid 3' {
  input='{"github-oauth":{"github.com":"test"},"http-basic":{"repo.magento.com":{"username":"test","password":"test"}},}'
  run is_string_valid_composer_credentials "$input"
  assert_failure
  assert_output ""
}

@test 'prompt_user_for_token valid' {
  run prompt_user_for_token << RESPONSES
9662d057e4e52b1b236fa237a232349841e60b44e
RESPONSES
  assert_success
  assert_output -p "numbers"
  refute_output -e "numbers.*numbers"

}

@test 'prompt_user_for_new_GH_token valid' {
  run prompt_user_for_token << RESPONSES
ghp_9662d057e4e52b1b236fa237a232349841e60b44e
RESPONSES
  assert_success
  assert_output -p "numbers"
  refute_output -e "numbers.*numbers"

}

@test 'prompt_user_for_token invalid' {
  run prompt_user_for_token << RESPONSES
z
9662d057e4e52b1b236fa237a232349841e60b44e
RESPONSES
  assert_success
  # prompt for numbers should happen twice b/c bad initial response
  assert_output -e "numbers.*numbers"
}

# requires mc cli to be installed and logged in
@test 'is_valid_mc_site_url https://user:pass@master-7rqtwtj-bdbasn83n3otg.demo.magentosite.cloud/admin/' {
  run is_valid_mc_site_url "https://user:pass@master-7rqtwtj-bdbasn83n3otg.demo.magentosite.cloud/admin/"
  assert_success
  assert_output ""
}

@test 'is_active_project_env valid' {
  run is_active_project_env "a6terwtbk67os" "master"
  assert_success
  assert_output ""
}

@test 'is_active_project_env invalid' {
  run is_active_project_env "a6terwtbk67os" "master-not-real-env-asdfasd"
  assert_failure
  assert_output ""
}

@test 'get_project_from_mc_site_url https://user:pass@master-7rqtwtj-bdbasn83n3otg.demo.magentosite.cloud/admin/' {
  run get_project_from_mc_site_url "https://user:pass@master-7rqtwtj-bdbasn83n3otg.demo.magentosite.cloud/admin/"
  assert_success
  assert_output "bdbasn83n3otg"
}

@test 'get_active_env_from_mc_env_url https://user:pass@master-7rqtwtj-bdbasn83n3otg.demo.magentosite.cloud/admin/' {
  # invalid project
  run get_active_env_from_mc_env_url https://user:pass@master-7rqtwtj-bdbasn83n3otg.demo.magentosite.cloud/admin/
  assert_failure
  assert_output ""
}

@test 'get_active_env_from_mc_env_url https://user:pass@master-7rqtwti-a6terwtbk67os.demo.magentosite.cloud/admin/' {
  # valid project
  run get_active_env_from_mc_env_url "https://user:pass@master-7rqtwti-a6terwtbk67os.demo.magentosite.cloud/"
  assert_success
  assert_output "master"
}

teardown() {
  [ -n "$BATS_TEST_COMPLETED" ] || touch ${BATS_PARENT_TMPNAME}.skip
}
