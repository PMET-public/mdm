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
  run get_github_file_contents "PMET-public/mdm" "bin/lib.sh" "master"
  assert_success
  assert_output -e "#!.*bash"
}

@test 'get_github_file_contents from this public repo at specific commit' {
  run get_github_file_contents "PMET-public/mdm" "lib.sh" "bb90b5e9a2bf82228841ef61c3e650e9ce669d84"
  assert_success
  assert_output -e "#!.*bash"
}

@test 'get_github_file_contents from this public repo that does not exist' {
  run get_github_file_contents "PMET-public/mdm" "file-that-does-not-exist" "master"
  assert_failure
  assert_output -e "404"
}

@test 'get_github_file_contents from private repo' {
  run get_github_file_contents "PMET-public/mdm-config" "$mdm_demo_domain/fullchain1.pem" "master"
  assert_success
  assert_output -e "BEGIN CERTIFICATE"
}
