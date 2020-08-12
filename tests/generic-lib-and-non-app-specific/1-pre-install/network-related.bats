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

@test 'is_valid_mc_url https://demo.magento.cloud/projects/xy4itwbmg2khb' {
  run is_valid_mc_url "https://demo.magento.cloud/projects/xy4itwbmg2khb"
  assert_success
}

@test 'get_project_from_mc_url "https://demo.magento.cloud/projects/xy4itwbmg2khb"' {
  run get_project_from_mc_url "https://demo.magento.cloud/projects/xy4itwbmg2khb"
  assert_success
  assert_output "xy4itwbmg2khb"
}

@test 'get_branch_from_mc_url "https://demo.magento.cloud/projects/xy4itwbmg2khb"' {
  run get_branch_from_mc_url "https://demo.magento.cloud/projects/xy4itwbmg2khb"
  assert_success
  assert_output ""
}

@test 'is_valid_mc_url "https://demo.magento.cloud/projects/xy4itwbmg2khb/environments/master"' {
  run is_valid_mc_url "https://demo.magento.cloud/projects/xy4itwbmg2khb/environments/master"
  assert_success
}

@test 'get_project_from_mc_url "https://demo.magento.cloud/projects/xy4itwbmg2khb/environments/master"' {
  run get_project_from_mc_url "https://demo.magento.cloud/projects/xy4itwbmg2khb/environments/master"
  assert_success
  assert_output "xy4itwbmg2khb"
}

@test 'get_branch_from_mc_url "https://demo.magento.cloud/projects/xy4itwbmg2khb/environments/master"' {
  run get_branch_from_mc_url "https://demo.magento.cloud/projects/xy4itwbmg2khb/environments/master"
  assert_success
  assert_output "master"
}

@test 'is_valid_mc_url "https://master-7rqtwti-xy4itwbmg2khb.demo.magentosite.cloud/"' {
  run is_valid_mc_url "https://master-7rqtwti-xy4itwbmg2khb.demo.magentosite.cloud/"
  assert_failure
}

@test 'is_valid_mc_url "https://google.com/"' {
  run is_valid_mc_url "https://google.com/"
  assert_failure
}

@test 'is_valid_github_web_url "https://github.com/PMET-public/magento-cloud/tree/deployable"' {
  run is_valid_github_web_url "https://github.com/PMET-public/magento-cloud/tree/deployable"
  assert_success
}

@test 'is_valid_github_web_url "https://github.com/PMET-public/magento-cloud"' {
  run is_valid_github_web_url "https://github.com/PMET-public/magento-cloud"
  assert_success
}

@test 'is_valid_github_web_url "https://github.com/PMET-public"' {
  run is_valid_github_web_url "https://github.com/PMET-public"
  assert_failure
}

@test 'get_branch_from_github_web_url "https://github.com/PMET-public/mdm"' {
  run get_branch_from_github_web_url "https://github.com/PMET-public/mdm"
  assert_success
  assert_output ''
}

@test 'get_branch_from_github_web_url "https://github.com/PMET-public/mdm/commit/f3f84327f7308a983b8464a333ac0ec323a66553"' {
  run get_branch_from_github_web_url "https://github.com/PMET-public/mdm/commit/f3f84327f7308a983b8464a333ac0ec323a66553"
  assert_success
  assert_output "f3f84327f7308a983b8464a333ac0ec323a66553"
}

@test 'get_branch_from_github_web_url "https://github.com/PMET-public/mdm/tree/develop"' {
  run get_branch_from_github_web_url "https://github.com/PMET-public/mdm/tree/develop"
  assert_success
  assert_output "develop"
}

@test 'get_branch_from_github_web_url "https://github.com/PMET-public/mdm/tree/travis/docker-files"' {
  run get_branch_from_github_web_url "https://github.com/PMET-public/mdm/tree/travis/docker-files"
  assert_success
  assert_output "travis"
}

@test 'get_branch_from_github_web_url "https://github.com/PMET-public/mdm/blob/travis/some/file.yml"' {
  run get_branch_from_github_web_url "https://github.com/PMET-public/mdm/blob/travis/some/file.yml"
  assert_success
  assert_output "travis"
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
