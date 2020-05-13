#!/usr/bin/env bash

set -e # stop on errors
set -x # turn on debugging

mkdir -p /tmp/conf.d

for network in $(docker network ls | grep default | grep bridge | awk '{print $2}'); do

  varnish_port=$(docker ps -a --filter "network=$network" --filter "label=com.docker.compose.service=varnish" --format "{{.Ports}}" | sed 's/.*://;s/-.*//')
  magento_hostname=$(docker ps -a --filter "network=$network" --filter "label=com.docker.compose.service=web" --format "{{.Names}}" | sed 's/_web_.*//')

  if [[ -n "$varnish_port" && -n "$magento_hostname" ]]; then

  echo "Writing nginx conf file for $magento_hostname"
  cat << EOF > "/tmp/conf.d/host-$magento_hostname.conf"
    server {
      listen 80;
      listen 443 ssl http2;
      server_name $magento_hostname.*;
      ssl_certificate /etc/letsencrypt/fullchain1.pem;
      ssl_certificate_key /etc/letsencrypt/privkey1.pem;
      location / {
        proxy_pass http://host.docker.internal:$varnish_port;
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-Proto \$scheme;
      }
    }
EOF
  else
    echo "Either varnish or app service not found on network $network. Skipping ..."
  fi

done

# N.B. after some testing, docker -v can NOT be quoted and must have spaces escaped (\ )
# so a string is constructed by escaping and then removing the bash expansion quotes
cid=$(echo "docker create \
  --label mdm-nginx-rev-proxy \
  -v $(echo "$cert_dir" | perl -pe 's/ /\\ /g'):/etc/letsencrypt \
  -p 443:443 \
  -p 80:80 \
  nginx:stable" | perl -pe 's/"//g' | bash)
docker cp /tmp/conf.d $cid:/etc/nginx/
old_cid="$(docker ps -q --filter 'label=mdm-nginx-rev-proxy')"
[[ $old_cid ]] && docker rm -f $old_cid
docker start $cid

