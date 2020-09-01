#!/usr/bin/env ./tests/libs/bats/bin/bats

# bats will loop indefinitely with debug mode on (i.e. set -x)
unset debug

load '../../libs/bats-assert/load'
load '../../libs/bats-support/load'
load '../../libs/bats-file/load'

load '../../../bin/lib.sh'

# this E2E test can 
# - test MDM itself using a specified magento-cloud project (default: PMET-public/magento-cloud) on a specified branch (default: master)
# - test a magento-cloud repo on its current commit and the specified ref of MDM
# - test a change to a dependency of a magento-cloud project and/or MDM


setup() {
  shopt -s nocasematch
  # if repo is not specified
  if [[ -z "$MAGENTO_CLOUD_REPO" ]]; then
    if [[ -f "$GITHUB_WORKSPACE/.magento.app.yaml" ]]; then # if workspace is a mc project, use that repo
      MAGENTO_CLOUD_REPO="https://github.com/$GITHUB_REPOSITORY.git"
    else
      MAGENTO_CLOUD_REPO="https://github.com/PMET-public/magento-cloud.git"
    fi
  fi

  # if ref is not specified
  if [[ -z "$MAGENTO_CLOUD_REF_TO_TEST" ]]; then
    if [[ -f "$GITHUB_WORKSPACE/.magento.app.yaml" ]]; then # if workspace is a mc project, use the current ref
      MAGENTO_CLOUD_REF_TO_TEST="$GITHUB_SHA"
    else
      MAGENTO_CLOUD_REF_TO_TEST="master"
    fi
  fi

  # app name will be truncated by dockerize and prevent very long symlink, too
  app_name="${MAGENTO_CLOUD_REF_TO_TEST:0:12}"
  app_link_name="mdm-app-$app_name"
}

@test 'install mdm by running launcher with initial output' {
  output="$($lib_dir/launcher)"
  [[ "$output" =~ advanced_mode ]] && skip # already installed (dev machine or 2nd app install)
  run "$lib_dir/launcher" "$output"
  assert_success
  assert_output -e "installed missing"
  assert_file_exist "$HOME/.mdm/current/bin/lib.sh"
}

@test '[CI] install_additional_tools' {
  output="$($lib_dir/launcher)"
  [[ "$output" =~ install_additional_tools ]] || skip # already installed (dev machine or 2nd app install)
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

@test 'dockerize app' {
  run "$lib_dir/dockerize" -g "$MAGENTO_CLOUD_REPO" -b "$MAGENTO_CLOUD_REF_TO_TEST" -n "$app_name" -i "$HOME/.mdm/current/icons/ref.icns"
  assert_success
}

@test 'install_app' {
  # get the most recently created app dir
  app_dir="$(ls -dtr "$HOME"/Downloads/*.app | tail -1 || :)"
  ln -sfn "$app_dir/Contents/Resources/script" "$app_link_name"
  run "./$app_link_name" install_app
  assert_success
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
  admin_output="$(curl -L -c /tmp/myc -b /tmp/myc "$base_url/admin/")"
  form_url="$(echo "$admin_output" | perl -ne '/.*BASE_URL[\s='\''"]+([^'\''"]+).*/ and print $1')"
  form_key="$(echo "$admin_output" | perl -ne '/.*FORM_KEY[\s='\''"]+([^'\''"]+).*/ and print $1')"
  run curl -Lv --max-redirs 3 -c /tmp/myc -b /tmp/myc -d "login[username]=admin&login[password]=pass4mdmCI&form_key=$form_key" "$form_url"
  assert_success
  assert_output -e "Location.*admin/dashboard"
}
