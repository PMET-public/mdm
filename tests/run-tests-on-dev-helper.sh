#!/usr/bin/env bash

set -e
# set -x

this_dir="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"

tests=($(find "$this_dir" -type f -not -path "*/libs/*" -name "*.bats" | sort))
deferred_tests=()

for test in "${tests[@]}"; do
  # defer sudo tests until end b/c will have to enter password multiple times
  [[ "$test" =~ sudo ]] &&
    deferred_tests+=("$test") &&
    echo "Deferring: \"$test\"" &&
    continue

  echo "Running: \"$this_dir/libs/bats/bin/bats\" -T \"$test\""
  "$this_dir/libs/bats/bin/bats" -T "$test"
done

for test in "${deferred_tests[@]}"; do
  echo "Running deferred test: \"$this_dir/libs/bats/bin/bats\" -T \"$test\""
  "$this_dir/libs/bats/bin/bats" -T "$test"
done