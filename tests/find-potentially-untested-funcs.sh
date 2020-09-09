#!/usr/bin/env bash

set -e
# set -x

find_all_funcs_in_lib() {
  perl -ne '/^([\w]+)\(/ and print "$1\n"' "$this_dir/../bin/lib.sh"
}

find_all_tests() {
  find "$this_dir/../tests" -type f -name "*.bats" -not -path "*/libs/*" -exec cat {} \;
}

this_dir="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
patterns_file="$(mktemp)"
find_all_funcs_in_lib > "$patterns_file"
contents_file="$(mktemp)"
find_all_tests > "$contents_file"

grep '^@test' "$contents_file" | grep -oFf "$patterns_file" | ggrep -vFf - "$patterns_file"

rm "$patterns_file" "$contents_file"
