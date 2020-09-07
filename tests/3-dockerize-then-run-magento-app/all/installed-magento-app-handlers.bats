#!/usr/bin/env ./tests/libs/bats/bin/bats

# bats will loop indefinitely with debug mode on (i.e. set -x)
unset debug

load '../../libs/bats-assert/load'
load '../../libs/bats-support/load'
load '../../libs/bats-file/load'

load '../../../bin/lib.sh'
load '../../bats-lib.sh'


setup() {
  post_magento_install_setup
}

@test 'disable 2FA' {
  run "./$app_link_name" start_shell_in_app 'perl -i -pe "/Magento_TwoFactorAuth/ and s/1/0/" app/etc/config.php'
  assert_success
}

@test 'reindex' {
  run "./$app_link_name" reindex
  assert_success
}

@test 'run_cron' {
  run "./$app_link_name" run_cron
  assert_success
}

@test 'enable_all_except_cms_cache' {
  run "./$app_link_name" enable_all_except_cms_cache
  assert_success
}

@test 'enable_all_caches' {
  run "./$app_link_name" enable_all_caches
  assert_success
}

# @test 'disable_most_caches' {
#   run "./$app_link_name" disable_most_caches
#   assert_success
# }

@test 'flush_cache' {
  run "./$app_link_name" flush_cache
  assert_success
}

@test 'warm_cache' {
  run "./$app_link_name" warm_cache
  assert_success
}

@test 'open_app' {
  is_CI || skip # install_app already opens browser tab in gui and in non-CI text won't be available as output
  run "./$app_link_name" open_app
  assert_success
  assert_output -e 'copyright.*magento'
}

# can't use get_* funcs directly b/c lib.sh is loaded independently of any specific app
# have to use an indirect method to get the app's url

@test 'web/unsecure/base_url should be secure' {
  run "./$app_link_name" start_shell_in_app 'php bin/magento config:show "web/unsecure/base_url"'
  assert_success
  assert_output -p 'https://'
}

@test 'web/secure/base_url should be secure' {
  run "./$app_link_name" start_shell_in_app 'php bin/magento config:show "web/secure/base_url"'
  assert_success
  assert_output -p 'https://'
}

@test 'check search result page for images' {
  "./$app_link_name" start_shell_in_app 'grep -q catalog-sample-data composer.json' || skip
  base_url="$("./$app_link_name" start_shell_in_app 'php bin/magento config:show "web/secure/base_url"')"
  run curl "$base_url/catalogsearch/result/?q=accessory"
  assert_success
  assert_output -e 'img.*src.*catalog\/product\/cache'
}

@test 'find and check the first category page in the nav for images' {
  "./$app_link_name" start_shell_in_app 'grep -q catalog-sample-data composer.json' || skip
  base_url="$("./$app_link_name" start_shell_in_app 'php bin/magento config:show "web/secure/base_url"')"
  category_url="$(curl "$base_url" |
    perl -ne 's/.*?class.*?nav-[12]-1.*?href=.([^ ]+.html).*/$1/ and print')"
  run curl "$category_url"
  assert_success
  assert_output -e 'img.*src.*catalog\/product\/cache'
}

@test 'create admin user' {
  run "./$app_link_name" start_shell_in_app 'php bin/magento admin:user:create --admin-user "admin" \
    --admin-password "pass4mdmCI" --admin-email admin@example.com --admin-firstname admin --admin-lastname admin'
  assert_success
  assert_output -e 'created.*admin'
}

@test 'check admin login user:pass == admin:pass4mdmCI' {
  base_url="$("./$app_link_name" start_shell_in_app 'php bin/magento config:show "web/secure/base_url"' | perl -ne 's/\/\s*$// and print')"
  rm /tmp/myc 2> /dev/null || :
  admin_output="$(wget --save-cookies /tmp/myc --quiet --no-check-certificate -O - "$base_url/admin/")"
  form_url="$(echo "$admin_output" | perl -ne '/.*BASE_URL[\s='\''"]+([^'\''"]+).*/ and print $1')"
  form_key="$(echo "$admin_output" | perl -ne '/.*FORM_KEY[\s='\''"]+([^'\''"]+).*/ and print $1')"
  run wget --load-cookies /tmp/myc --no-check-certificate -O - --post-data "login[username]=admin&login[password]=pass4mdmCI&form_key=$form_key" "$form_url"
  assert_success
  assert_output -e "Location.*admin/dashboard"
}

# change_base_url
# clear_job_statuses
# clone_app
# dockerize_app
# no_op
# optimize_docker
# resize_images

# show_app_logs
# show_errors_from_mdm_logs
# show_mdm_logs
# start_mdm_shell
# start_pwa_with_app
# start_pwa_with_remote

@test 'start_tmate_session' {
  printf " " >> "$HOME/.ssh/authorized_keys" # add space at end to detect change
  run "./$app_link_name" start_tmate_session
  assert_success
  assert_output -e "updated.*ssh.*tmate.io"
}

@test 'start_tmate_session again' {
  printf " " >> "$HOME/.ssh/authorized_keys" # add space at end to detect change
  run "./$app_link_name" start_tmate_session
  assert_success
  assert_output -e "updated.*ssh.*tmate.io"
}

@test 'start_remote_web_access' {
  run "./$app_link_name" start_remote_web_access
  assert_success
  assert_output -e ""
}

@test 'stop_remote_access' {
  run "./$app_link_name" stop_remote_access
  assert_success
  assert_output -e ""
}

# stop_other_apps
# stop_app
# restart_app

# switch_to_developer_mode
# switch_to_production_mode


# sync_app_to_remote
# toggle_xdebug

# update_mdm
# revert_to_prev_mdm
