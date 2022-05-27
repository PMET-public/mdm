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
  [ ! -f ${BATS_PARENT_TMPNAME}.skip ] || skip "skip remaining tests"
  cp /etc/hosts /tmp/hosts."$(echo $BATS_TEST_NAME | sed 's/ /-/g')"
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

@test 'toggle_mkcert_CA_install' {
  is_advanced_mode || "$lib_dir/launcher" toggle_advanced_mode
  is_mkcert_CA_installed || "$lib_dir/launcher" toggle_mkcert_CA_install
  run "$lib_dir/launcher"
  assert_success
  assert_output -e "spoofing.*on"
}

@test 'dockerize app' {
  cp "$lib_dir/../.mdm_config.tmpl.sh" "$lib_dir/../.mdm_config.sh"
  run "$lib_dir/dockerize" -g "$MAGENTO_CLOUD_REPO" -b "$MAGENTO_CLOUD_REF_TO_TEST" -n "$app_name" -i "$HOME/.mdm/current/icons/ref.icns"
  assert_success
}

@test 'install_app' {
  # get the most recently created app dir
  app_dir="$(ls -dtr "$HOME"/Downloads/*.app | tail -1 || :)"
  run "$app_dir/Contents/Resources/script" install_app
  assert_success
}

teardown() {
  [ -n "$BATS_TEST_COMPLETED" ] || touch ${BATS_PARENT_TMPNAME}.skip
}
