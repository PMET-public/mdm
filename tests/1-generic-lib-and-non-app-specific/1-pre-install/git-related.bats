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

@test 'get_github_token_from_composer_auth' {
  run get_github_token_from_composer_auth
  assert_success
  assert_output -e "[0-z]{20,}"
}

@test 'get_github_file_contents from this public repo' {
  run get_github_file_contents "https://github.com/PMET-public/mdm/blob/master/bin/lib.sh"
  assert_success
  assert_output -e "#!.*bash"
}

@test 'get_github_file_contents from this public repo at specific commit' {
  run get_github_file_contents "https://github.com/PMET-public/mdm/blob/2cd34a3f7cc5472544ba48ac63ebd6df358d893c/bin/lib.sh"
  assert_success
  assert_output -e "#!.*bash"
}

@test 'get_github_file_contents from this public repo that does not exist' {
  run get_github_file_contents "https://github.com/PMET-public/mdm/blob/master/DOES_NOT_EXIST"
  assert_failure
  assert_output -e "404"
}

@test 'get_github_file_contents from private file defined in .mdm_config.sh' {
  [[ "$MDM_CONFIG_URL" ]] || skip
  run get_github_file_contents "$mdm_domain_fullchain_gh_url"
  assert_success
  assert_output -e "BEGIN CERTIFICATE"
}
