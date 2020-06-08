#!/bin/bash

# shellcheck source=../../bin/lib.sh
source ./bin/lib.sh

[[ $debug ]] && set -x

yes 'no' | ./bin/launcher rm_magento_docker_images
yes | ./bin/launcher rm_magento_docker_images

yes 'no' | ./bin/launcher reset_docker
yes | ./bin/launcher reset_docker

yes 'no' | ./bin/launcher wipe_docker
yes | ./bin/launcher wipe_docker

exit 0
