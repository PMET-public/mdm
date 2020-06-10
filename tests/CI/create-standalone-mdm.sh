#!/bin/bash

set -e
[[ $debug ]] && set -x

# shellcheck source=../../bin/lib.sh
source ./bin/lib.sh

./bin/dockerize -s
# open -a MDM
ps_output="$(ps aux | grep "MDM$" || :)"
[[ $ps_output =~ Contents/MacOS/MDM$ ]] || error "Expected MDM process not found."

exit 0
