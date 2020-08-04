#!/usr/bin/env ./tests/libs/bats/bin/bats

# bats will loop indefinitely with debug mode on (i.e. set -x)
unset debug

load '../../libs/bats-assert/load'
load '../../libs/bats-support/load'
load '../../libs/bats-file/load'

load '../../../bin/lib.sh'

setup() {
  shopt -s nocasematch
  is_docker_installed && is_docker_ready || error "Docker missing."
}

@test "Remove homebrew" {
  is_mac && is_CI || skip
  echo "y" | /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/uninstall.sh)"
  run which brew
  assert_failure
}

@test "Check for newly missing requirements" {
  is_mac && is_CI || skip
  run "$lib_dir/launcher"
  assert_success
  assert_output -p "install"
}

@test "Reinstall missing requirements" {
  is_mac && is_CI || skip
  output="$("$lib_dir/launcher")"
  run "$lib_dir/launcher" "$output"
  assert_success
  assert_output -p "installed"
}

@test "Requirements satisfied and menu displayed" {
  is_mac && is_CI || skip
  run "$lib_dir/launcher"
  assert_success
  assert_output -p "advanced mode"
}
