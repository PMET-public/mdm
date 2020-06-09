#!/bin/bash

set -e
[[ $debug ]] && set -x

# shellcheck source=../../bin/lib.sh
source ./bin/lib.sh

is_mac && {
  ./bin/dockerize -s
}


exit 0