#!/usr/bin/env bash

# this script is meant to run independent of any single magento app to
# - discover all magento hosts
# - ensure they resolve to localhost
# - verify, create, or fetch their private keys and TLS certificates
# - write the nginx conf and start the nginx container

set -e
[[ "$debug" ]] && set -x

# shellcheck source=lib.sh
source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/lib.sh" || :

prepare_cert_and_key_for_hostname() {
  local hostname="$1" cert_dir
  cert_dir="$certs_dir/$hostname"
  mkdir -p "$cert_dir"

  # if applicable, try to fetch a valid cert and return
  if [[ "$hostname" =~ \.$mdm_demo_domain$ ]]; then
    get_wildcard_cert_and_key_for_mdm_demo_domain &&
      cp_wildcard_mdm_demo_domain_cert_and_key_for_subdomain $hostname &&
      return
  fi

  mkcert_for_domain "$hostname"
}

prepare_certs_and_keys() {
  local hostname hostnames="$*"
  for hostname in $hostnames; do
    prepare_cert_and_key_for_hostname "$hostname"
  done
}

# the config output assumes the letsencrypt convention of TLS cert paths
# and mounting the $mdm_path/certs to /etc/letsencrypt
write_nginx_config_for_host_at_port() {
  local hostname="$1" web_port="$2" cert_dir
  [[ ! $hostname || ! $web_port ]] && error "Missing config option for nginx."
  does_cert_and_key_exist_for_domain "$hostname" ||
    error "Missing necessary certificate or private key for $hostname."
  cat << EOF
    server {
      listen 80;
      listen 443 ssl http2;
      server_name $hostname;
      ssl_certificate /etc/letsencrypt/$hostname/fullchain1.pem;
      ssl_certificate_key /etc/letsencrypt/$hostname/privkey1.pem;
      location / {
        proxy_pass http://$host_docker_internal:$web_port;
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_buffer_size          128k;
        proxy_buffers              4 256k;
        proxy_busy_buffers_size    256k;
      }
    }
EOF
}

# find each magento app by interating over docker's networks
write_nginx_configs() {
  local hostname web_port
  for network in $(find_bridged_docker_networks); do
    web_port="$(find_varnish_port_by_network "$network")"
    hostname="$(find_web_service_hostname_by_network "$network")"
    [[ -n "$hostname" ]] && write_nginx_config_for_host_at_port "$hostname" "$web_port" > "$tmp_nginx_conf_dir/$hostname.conf"
  done

  # plus 2 pwa demo hostnames
  hostname="$(get_pwa_hostname)"
  write_nginx_config_for_host_at_port "$hostname" "3000" > "$tmp_nginx_conf_dir/$hostname.conf"
  hostname="$(get_pwa_prev_hostname)"
  write_nginx_config_for_host_at_port "$hostname" "3001" > "$tmp_nginx_conf_dir/$hostname.conf"
}

tmp_nginx_conf_dir="$(mktemp -d)"
hostnames="$(find_mdm_hostnames)"
hostnames_not_resolving_to_local="$(find_hostnames_not_resolving_to_local "$hostnames")"
add_hostnames_to_hosts_file "$hostnames_not_resolving_to_local"
prepare_certs_and_keys "$hostnames"
write_nginx_configs "$hostnames"


# ensure latest nginx image
docker_nginx_image="pmetpublic/nginx-with-pagespeed:1.0"
docker pull "$docker_nginx_image"

# create new nginx container with latest config
cid=$(docker create --label mdm-nginx-rev-proxy -v "$mdm_path/certs":/etc/letsencrypt -p 443:443 -p 80:80 "$docker_nginx_image")
docker cp "$tmp_nginx_conf_dir/." "$cid:/etc/nginx/conf.d"
rm -rf "$tmp_nginx_conf_dir"

# delete exited or currently running nginx rev proxies
old_cid="$(docker ps -qa --filter 'label=mdm-nginx-rev-proxy' --filter 'status=running' --filter 'status=exited')"
[[ "$old_cid" ]] && docker rm -f "$old_cid"
docker start "$cid"
