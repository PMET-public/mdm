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

@test '[CI][osx] Remove homebrew' {
  is_mac && is_CI || skip
  echo "y" | /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/uninstall.sh)"
  run which brew
  assert_failure
}

@test '[CI][osx] Check for newly missing requirements' {
  is_mac && is_CI || skip
  
  # mock docker and settings file to show menu options
  cp /bin/bash /usr/local/bin/docker
  mkdir -p "$(dirname "$docker_settings_file")"
  touch "$docker_settings_file"

  run "$lib_dir/launcher"
  assert_success
  assert_output -p "install_additional_tools"
}

@test '[CI][osx] Reinstall missing requirements' {
  is_mac && is_CI || skip
  output="$("$lib_dir/launcher")"
  run "$lib_dir/launcher" "install_additional_tools"
  assert_success
  assert_output -p "installed"
}

@test '[CI][osx] Requirements satisfied and menu displayed' {
  is_mac && is_CI || skip
  run "$lib_dir/launcher"
  assert_success
  assert_output -p "advanced mode"
}
