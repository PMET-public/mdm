#!/usr/bin/env bash

set -e # stop on errors
set -x # turn on debugging

tmp_dir=$(mktemp -d)

for network in $(docker network ls -q --filter 'driver=bridge' --filter 'name=_default'); do

  varnish_port=$(docker ps -a --filter "network=$network" --filter "label=com.docker.compose.service=varnish" --format "{{.Ports}}" | sed 's/.*://;s/-.*//')
  magento_hostname=$(docker ps -a --filter "network=$network" --filter "label=com.docker.compose.service=web" --format "{{.Names}}" | sed 's/_web_.*//')

  if [[ -n "$varnish_port" && -n "$magento_hostname" ]]; then

  echo "Writing nginx conf file for $magento_hostname"
  cat << EOF > "$tmp_dir/host-$magento_hostname.conf"
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

cid=$(docker create --label mdm-nginx-rev-proxy -v "$mdm_cert_dir":/etc/letsencrypt -p 443:443 -p 80:80 nginx:stable)
docker cp $tmp_dir $cid:/etc/nginx/conf.d/
rm -rf $tmp_dir
old_cid="$(docker ps -q --filter 'label=mdm-nginx-rev-proxy')"
[[ $old_cid ]] && docker rm -f $old_cid
docker start $cid

