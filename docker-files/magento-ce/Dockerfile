FROM pmetpublic/magento-cloud-docker-php:7.3-cli-1.1

RUN git clone --depth 1 https://github.com/magento/magento2.git -b 2.3.5-p1 /m2

WORKDIR /m2

RUN composer config repositories.mcd git https://github.com/pmet-public/magento-cloud-docker.git

RUN composer config repositories.ece-tools git https://github.com/pmet-public/ece-tools.git

RUN composer config repositories.ece-tools git https://github.com/magento/magento-cloud-components

RUN composer require magento/magento-cloud-components:dev-develop magento/magento-cloud-docker:dev-develop magentoese/ece-tools:2002.1.x-dev --no-suggest --no-ansi --no-interaction --no-progress

# RUN composer require magentoese/ece-tools:2002.1.x-dev --no-suggest --no-ansi --no-interaction --no-progress