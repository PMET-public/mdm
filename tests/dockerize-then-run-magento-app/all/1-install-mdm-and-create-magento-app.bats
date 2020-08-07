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

@test 'create ref app' {
  run "$lib_dir/dockerize" -g https://github.com/PMET-public/magento-cloud.git -b pmet-2.4.0-ref -n app-from-repo-test -i $HOME/.mdm/current/icons/ref.icns
  assert_success
}

@test 'install_app' {
  run "$HOME/Downloads/app-from-repo-test-2.4.0.app/Contents/Resources/script" install_app
  assert_success
}