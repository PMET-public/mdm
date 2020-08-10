#!/usr/bin/env ./tests/libs/bats/bin/bats

# bats will loop indefinitely with debug mode on (i.e. set -x)
unset debug

load '../../libs/bats-assert/load'
load '../../libs/bats-support/load'
load '../../libs/bats-file/load'

load '../../../bin/lib.sh'

setup() {
  shopt -s nocasematch
  app_name="app-from-repo-test"
  app_dir="$(find "$HOME/Downloads" -maxdepth 1 -type d -name "*$app_name*.app" || :)"
  if [[ -z "$GITHUB_REPOSITORY" || "$GITHUB_REPOSITORY" = "PMET-public/mdm" ]]; then
    # default when none specified or mdm is primary repo
    MAGENTO_CLOUD_REPO="https://github.com/PMET-public/magento-cloud.git"
    MAGENTO_CLOUD_CHECKOUT="pmet-2.4.0-ref"
  else
    MAGENTO_CLOUD_REPO="https://github.com/$GITHUB_REPOSITORY.git"
    MAGENTO_CLOUD_CHECKOUT="$GITHUB_SHA"
  fi
}

@test 'launcher with initial output' {
  output="$($lib_dir/launcher)"
  run "$lib_dir/launcher" "$output"
  assert_success
  assert_output -e "installed missing"
  assert_file_exist "$HOME/.mdm/current/bin/lib.sh"
}

@test '[CI] launcher install_additional_tools' {
  is_CI || skip
  run "$lib_dir/launcher" install_additional_tools
  assert_success
  assert_output -p "magento-cloud"
  assert_output -p "installed"
}

@test "toggle_mkcert_CA_install" {
  is_advanced_mode || "$lib_dir/launcher" toggle_advanced_mode
  is_mkcert_CA_installed || "$lib_dir/launcher" toggle_mkcert_CA_install
  run "$lib_dir/launcher"
  assert_success
  assert_output -e "spoofing.*on"
}

@test 'create ref app' {
  run "$lib_dir/dockerize" -g "$MAGENTO_CLOUD_REPO" -b "$MAGENTO_CLOUD_CHECKOUT" -n "$app_name" -i "$HOME/.mdm/current/icons/ref.icns"
  assert_success
}

@test 'install_app' {
  run "$app_dir/Contents/Resources/script" install_app
  assert_success
}

@test 'reindex' {
  run "$app_dir/Contents/Resources/script" reindex
  assert_success
}

@test 'run_cron' {
  run "$app_dir/Contents/Resources/script" run_cron
  assert_success
}

@test 'enable_all_except_cms_cache' {
  run "$app_dir/Contents/Resources/script" enable_all_except_cms_cache
  assert_success
}

@test 'enable_all_caches' {
  run "$app_dir/Contents/Resources/script" enable_all_caches
  assert_success
}

# @test 'disable_most_caches' {
#   run "$app_dir/Contents/Resources/script" disable_most_caches
#   assert_success
# }

@test 'flush_cache' {
  run "$app_dir/Contents/Resources/script" flush_cache
  assert_success
}

@test 'warm_cache' {
  run "$app_dir/Contents/Resources/script" warm_cache
  assert_success
}

@test 'open_app' {
  run "$app_dir/Contents/Resources/script" open_app
  assert_success
  assert_output -e 'copyright.*magento'
}

# can use get_* funcs directly b/c lib.sh is loaded independently
# have to use an indirect method to get the app's url

@test 'web/unsecure/base_url should be secure' {
  run "$app_dir/Contents/Resources/script" start_shell_in_app 'php bin/magento config:show "web/unsecure/base_url"'
  assert_success
  assert_output -p 'https://'
}

@test 'web/secure/base_url should be secure' {
  run "$app_dir/Contents/Resources/script" start_shell_in_app 'php bin/magento config:show "web/secure/base_url"'
  assert_success
  assert_output -p 'https://'
}

@test 'check search result page for images' {
  base_url="$("$app_dir/Contents/Resources/script" start_shell_in_app 'php bin/magento config:show "web/secure/base_url"')"
  run curl "$base_url/catalogsearch/result/?q=accessory"
  assert_success
  assert_output -e 'img.*src.*catalog\/product\/cache'
}

@test 'find and check the first category page in the nav for images' {
  base_url="$("$app_dir/Contents/Resources/script" start_shell_in_app 'php bin/magento config:show "web/secure/base_url"')"
  category_url="$(curl "$base_url" |
    perl -ne 's/.*?class.*?nav-[12]-1.*?href=.([^ ]+.html).*/$1/ and print')"
  run curl "$category_url"
  assert_success
  assert_output -e 'img.*src.*catalog\/product\/cache'
}

# @test 'check admin login' {
#   "$app_dir/Contents/Resources/script" start_shell_in_app 'php bin/magento admin:user:create --admin-user "" --admin-password "" --admin-email admin@example.com --admin-firstname admin --admin-lastname admin'
#   base_url="$("$app_dir/Contents/Resources/script" start_shell_in_app 'php bin/magento config:show "web/secure/base_url"')"
#   rm /tmp/myc 2> /dev/null || :
#   admin_output="$(curl -sL -c /tmp/myc -b /tmp/myc "$base_url/admin/")"
#   form_url="$(echo "$admin_output" | perl -ne '/.*BASE_URL[\s='\''"]+([^'\''"]+).*/ and print $1')"
#   form_key="$(echo "$admin_output" | perl -ne '/.*FORM_KEY[\s='\''"]+([^'\''"]+).*/ and print $1')"
#   curl -sLv --max-redirs 1 -c /tmp/myc -b /tmp/myc -X POST -d "login[username]=&login[password]=&form_key=$form_key" "$form_url" 2>&1 |
#       grep -i -m 1 "Location.*admin/dashboard" | wc -l)
# }
