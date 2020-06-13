#!/bin/bash

set -e
[[ $debug ]] && set -x

# shellcheck source=../../bin/lib.sh
source ./bin/lib.sh


if is_docker_compatible; then

  # turn on advanced mode if reset option not available
  launcher_output="$(./bin/launcher)"
  shopt -s nocasematch
  [[ $launcher_output =~ maintenance ]] || ./bin/launcher toggle_advanced_mode

  docker run pmetpublic/nginx-with-pagespeed bash

  yes 'no' | ./bin/launcher rm_magento_docker_images
  yes | ./bin/launcher rm_magento_docker_images

  [[ $(docker images | grep -E '^(magento|pmetpublic)/' | awk '{print $3}') ]] &&
    error "Magento images not removed."

  yes 'no' | ./bin/launcher reset_docker
  yes | ./bin/launcher reset_docker

  [[ $(docker ps -qa) ]] &&
    error "Containers not removed."

  yes 'no' | ./bin/launcher wipe_docker
  yes | ./bin/launcher wipe_docker

  [[ ! $(docker ps -qa) ]] &&
    [[ ! $(docker images -qa) ]] &&
    [[ ! $(docker volume ls -q) ]] &&
    [[ ! $(docker network ls -q) ]] &&
    error "Docker not wiped."

else
  warning_w_newlines "Test skipped."
fi

exit 0
