#!/usr/bin/env bash

set -e
# set -x

find_all_handlers_in_menu_items() {
  perl -ne 's/.*-handler.*=// and print' "$this_dir/../bin/menu-items.sh" | sort -u
}

find_all_tests() {
  find "$this_dir/../tests/bats" -type f -name "*.bats" -exec cat {} \;
}

this_dir="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
patterns_file="$(mktemp)"
find_all_handlers_in_menu_items > "$patterns_file"
contents_file="$(mktemp)"
find_all_tests > "$contents_file"

grep -oFf "$patterns_file" "$contents_file" | ggrep -vFf - "$patterns_file"