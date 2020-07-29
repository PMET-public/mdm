#!/bin/bash

set -e
[[ "$debug" ]] && set -x

# shellcheck source=../../bin/lib.sh
source ./bin/lib.sh

if is_mac; then
  ./bin/dockerize -d
  open -a "$detached_project_name"
  ps aux | grep -qE "$detached_project_name\$" || error "Expected MDM process not found."
else
  warning_w_newlines "Test skipped."
fi

exit 0
