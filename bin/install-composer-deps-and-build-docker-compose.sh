#!/bin/bash

# composer 1.x does not have much faster parallel downloads
[[ "$(composer --version)" =~ version\ 1 ]] &&
  composer global require hirak/prestissimo --no-interaction

composer install --no-suggest --no-ansi --no-interaction --no-progress --prefer-dist

# replace the official MCD module with ours if exists
perl -i -pe 's/magento\/magento-cloud-docker.git/pmet-public\/magento-cloud-docker.git/' composer.json

# if our repo of MCD still does not exist, add it
grep -q 'pmet-public/magento-cloud-docker' composer.json ||
  composer config repositories.mcd git git@github.com:pmet-public/magento-cloud-docker.git

# if there is not a specified required version of MCD, require one
# TODO: add some case logic based on magento EE version?
jq -e -c '.require."magento/magento-cloud-docker"' composer.json ||
  composer require magento/magento-cloud-docker:dev-develop --no-suggest --no-ansi --no-interaction --no-progress

# creates docker-compose.yml & .docker/config.env w/ base64 encoded vals for the "generic" service extended by others
# inspect w/ perl -MMIME::Base64 -ne '/(MAGENTO_CLOUD_.*?)=(.*)/ and print "\"$1\":".decode_base64($2).",\n"' .docker/config.env | perl -0777 -pe 's/^/{/;s/.$/}/;' | jq
./vendor/bin/ece-docker build:compose --host="$app_hostname"
