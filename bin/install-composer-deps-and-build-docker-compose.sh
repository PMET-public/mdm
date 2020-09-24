#!/bin/bash

composer global require hirak/prestissimo --no-interaction # parallelize downloads (much faster)
composer install --no-suggest --no-ansi --no-interaction --no-progress --prefer-dist

# require (or replace if already required) the official magento cloud docker module with ours
# also note that a few envs may have a composer repo entry that needs to be updated
perl -i -pe 's/magento\/magento-cloud-docker.git/pmet-public\/magento-cloud-docker.git/' composer.json
grep -q 'pmet-public/magento-cloud-docker' composer.json ||
  composer config repositories.mcd git git@github.com:pmet-public/magento-cloud-docker.git
composer require magento/magento-cloud-docker:dev-develop --no-suggest --no-ansi --no-interaction --no-progress

# creates docker-compose.yml & .docker/config.env w/ base64 encoded vals for the "generic" service extended by others
# inspect w/ perl -MMIME::Base64 -ne '/(MAGENTO_CLOUD_.*?)=(.*)/ and print "\"$1\":".decode_base64($2).",\n"' .docker/config.env | perl -0777 -pe 's/^/{/;s/.$/}/;' | jq
./vendor/bin/ece-docker build:compose --host="$app_hostname"

# OVERRIDE_MCD_IMAGE_VERSION is used to test new images from the pmetpublic/magento-cloud-docker project forked from magento
[[ "$OVERRIDE_MCD_IMAGE_VERSION" ]] && {
  echo "Overriding docker-compose.yml image versions ..."
  perl -i -pe "/image.*pmetpublic\// and s/-[a-f0-9]{7}'/-$OVERRIDE_MCD_IMAGE_VERSION'/" docker-compose.yml
} || :
