#!/bin/bash

set -e
[[ $debug ]] && set -x

# shellcheck source=../../bin/lib.sh
source ./bin/lib.sh

if ! is_mac; then
  ./bin/dockerize -g https://github.com/PMET-public/magento-cloud.git -b pmet-2.3.5-ref-github
  open -a MDM
  ps_output="$(ps aux | grep "MDM$" || :)"
  [[ $ps_output =~ Contents/MacOS/MDM$ ]] || error "Expected MDM process not found."
else
  warning "Test skipped.
"
fi

exit 0
