#!/bin/bash

set -e
[[ $debug ]] && set -x

# shellcheck source=../../bin/lib.sh
source ./bin/lib.sh

if is_mac; then
  ./bin/dockerize -d
  open -a "$detached_project_name"
  ps_output="$(ps aux | grep "$detached_project_name" || :)"
  [[ $ps_output =~ Contents/MacOS/MDM$ ]] || error "Expected MDM process not found."
else
  warning_w_newlines "Test skipped."
fi

exit 0
