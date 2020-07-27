#!/usr/bin/env bash

# this script is meant to run independent of any single magento app to
# - discover all magento hosts
# - ensure they resolve to localhost
# - verify or create their private keys and TLS certificates
# - write the nginx conf and start the nginx container

set -e
[[ $debug ]] && set -x

# shellcheck source=lib.sh
source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/lib.sh" || :

trim() {
  xargs $@
}

get_pwa_hostname() {
  false && is_adobe_system && echo "pwa.storystore.dev" || echo "pwa"
}

get_pwa_prev_hostname() {
  false && is_adobe_system && echo "pwa-prev.storystore.dev" || echo "pwa-prev"
}

find_networks() {
  docker network ls -q --filter 'driver=bridge' --filter 'name=_default'
}

find_proxy_by_network() {
  docker ps -a --filter "network=$1" \
    --filter "label=com.docker.compose.service=varnish" --format "{{.Ports}}" | \
    sed 's/.*://;s/-.*//'
}

find_hostname_by_network() {
  local cid apps_resources_dir
  cid="$(docker ps -a --filter "network=$1" \
      --filter "label=com.docker.compose.service=web" --format "{{.ID}}")"
  [[ "$cid" ]] &&
    apps_resources_dir="$(docker inspect "$cid" | \
      perl -ne 's/.*com.docker.compose.project.working_dir.*?(\/[^"]*).*/$1\/../ and print')"
  [[ "$apps_resources_dir" ]] &&
    perl -ne 's/.*VIRTUAL_HOST\s*=\s*([^ ]*).*/$1/ and print' "$apps_resources_dir/app/docker-compose.yml" ||
    :
}

find_hostnames() {
  hostnames="$pwa_hostname $pwa_prev_hostname"
  for network in $networks; do
    hostnames+=" $(find_hostname_by_network "$network")"
  done
  echo "$hostnames" | trim
}

find_hostnames_not_resolving_to_local() {
  local hostname
  for hostname in $hostnames; do
    [[ "$hostname" ]] && ! is_hostname_resolving_to_local "$hostname" && 
      hostnames_not_resolving_to_local+=" $hostname"
  done
  echo $hostnames_not_resolving_to_local | trim
}

add_hostnames_to_hosts_file() {
  local lines="" $error_msg="Could not update hosts files." tmp_hosts
  for host in $hostnames_not_resolving_to_local; do
    lines+="127.0.0.1 $host $hosts_file_line_marker"$'\n'
  done
  echo "Password may be required to modify /etc/hosts."
  tmp_hosts=$(mktemp)
  cat /etc/hosts <(echo "$lines") > "$tmp_hosts"
  cp /etc/hosts "$mdm_path/hosts.bak"
  if is_running_as_sudo; then
    mv "$tmp_hosts" /etc/hosts || error "$error_msg"
  elif is_interactive; then
    sudo mv "$tmp_hosts" /etc/hosts || error "$error_msg"
  elif is_mac; then
    osascript -e "do shell script \"sudo mv $tmp_hosts /etc/hosts \" with administrator privileges" ||
      error "$error_msg"
  fi
}

does_cert_and_key_exist_for_host() {
  local hostname="$1" cert_dir
  cert_dir="$certs_dir/$hostname"
  [[ -d "$cert_dir" && -f "$cert_dir/fullchain1.pem" && -f "$cert_dir/privkey1.pem" ]]
}

read_cert_for_hostname() {
  openssl x509 -text -noout -in "$certs_dir/$1/fullchain1.pem"
}

get_cert_utc_end_date_for_hostname() {
  end_date="$(read_cert_for_hostname "$1" | perl -ne 's/\s*not after :\s*//i and print')"
  $date_cmd --utc --date="$end_date" +"%Y-%m-%d %H:%M:%S"
}

is_cert_for_hostname_current() {
  [[ "$($date_cmd --utc +"%Y-%m-%d %H:%M:%S")" < "$(get_cert_utc_end_date_for_hostname "$1")" ]]
}

is_cert_for_hostname_expiring_soon() {
  [[ "$($date_cmd --utc --date "+7 days" +"%Y-%m-%d %H:%M:%S")" < "$(get_cert_utc_end_date_for_hostname "$1")" ]]
}

wildcard_domain_for_hostname() {
  # must have 2 '.' and then replace the 1st segment before the 1st dot with '*'
  echo "$1" | perl -pe '/.+\..+\..+/ and s/.*?\./*./'
}

is_cert_match_for_hostname() {
  local wildcard_domain="$(wildcard_domain_for_hostname "$1")"
  read_cert_for_hostname "$1" | grep -q "DNS:$1" ||
    read_cert_for_hostname "$1" | grep -q "DNS:$wildcard_domain"
}

are_certs_valid_for_host() {
  :
}

are_certs_expired_for_hosts() {
  :
}

prepare_cert_and_key_for_hostname() {
  local hostname="$1" cert_dir
  cert_dir="$certs_dir/$hostname"
  mkdir -p "$cert_dir"
  
  # check for existing, valid cert & return
  does_cert_and_key_exist_for_host "$hostname" && is_cert_for_hostname_current "$hostname" && 
    is_cert_match_for_hostname "$hostname" && ! is_cert_for_hostname_expiring_soon "$hostname" && 
    return
  
  # otherwise, if applicable, try to fetch a valid cert
  is_adobe_system && :

  # otherwise, if mkcert is installed, create a cert
  mkcert -cert-file "$cert_dir/fullchain1.pem" -key-file "$cert_dir/privkey1.pem" "$hostname"

  # otherwise, use a pregenerated insecure one
  
}

prepare_certs_and_keys() {
  local hostname
  for hostname in $hostnames; do
    prepare_cert_and_key_for_hostname "$hostname"
  done
}

# the config output assumes the letsencrypt convention of TLS cert paths
# and mounting the $mdm_path/certs to /etc/letsencrypt
write_nginx_config_for_host_at_port() {
  local hostname="$1" web_port="$2" cert_dir
  [[ ! $hostname || ! $web_port ]] && error "Missing config option for nginx."
  does_cert_and_key_exist_for_host "$hostname" ||
    error "Missing necessary certificate or private key for $hostname."
  cat << EOF
    server {
      listen 80;
      listen 443 ssl http2;
      server_name $hostname;
      ssl_certificate /etc/letsencrypt/$hostname/fullchain1.pem;
      ssl_certificate_key /etc/letsencrypt/$hostname/privkey1.pem;
      location / {
        proxy_pass http://host.docker.internal:$web_port;
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-Proto \$scheme;
      }
    }
EOF
}

# find each magento app by interating over docker's networks
write_nginx_configs() {
  local hostname web_port
  for network in $(networks); do
    web_port="$(find_proxy_by_network "$network")"
    hostname="$(find_hostname_by_network "$network")"
    write_nginx_config_for_host_at_port "$hostname" "$web_port"
    # cur_wildcard_for_hostname="$(echo "$cur_magento_hostname" | perl -pe 's/.*?\.//')"
    # dirs_to_check=("$mdm_path/certs/$cur_wildcard_for_hostname" "$mdm_path/certs/$cur_magento_hostname")
    # for cur_dir in "${dirs_to_check[@]}"; do
    #   if [[ -d "$cur_dir" && -f "$cur_dir/fullchain1.pem" && -f "$cur_dir/privkey1.pem" ]]; then
    #     is_cert_for_hostname_expiring_soon "$cur_dir/fullchain1.pem" && get_apps_certs
    #     if is_cert_for_hostname_current "$cur_dir/fullchain1.pem"; then
    #       :
    #     else
    #       :
    #     fi
    #   fi
    # done
  done

  # plus 2 pwa demo hostnames
  write_nginx_config_for_host_at_port "$pwa_hostname" "3000" > "$tmp_nginx_conf_dir/host-$pwa_hostname.conf"
  write_nginx_config_for_host_at_port "$pwa_prev_hostname" "3001" > "$tmp_nginx_conf_dir/host-$pwa_prev_hostname.conf"
}


# although many of these functions are manipulating global vars directly and only run once,
# so they don't strictly need to be as var="$(get_var)"
# keeping them as concise, readable functions should be easier to maintain and rewrite later if desired
#
# the benefit of using global vars and referencing global vars in funcs is much better performance
# for otherwise expensive service calls to the local docker api
#
# however, one downside is that the order of execution is coupled and very important
tmp_nginx_conf_dir="$(mktemp -d)"
pwa_hostname="$(get_pwa_hostname)"
pwa_prev_hostname="$(get_pwa_prev_hostname)"
networks="$(find_networks)"
hostnames="$(find_hostnames)"
hostnames_not_resolving_to_local="$(find_hostnames_not_resolving_to_local)"
[[ "$hostnames_not_resolving_to_local" ]] && add_hostnames_to_hosts_file
prepare_certs_and_keys
write_nginx_configs


# ensure latest nginx image
docker_nginx_image="pmetpublic/nginx-with-pagespeed:1.0"
docker pull "$docker_nginx_image"

cid=$(docker create --label mdm-nginx-rev-proxy -v "$mdm_path/certs":/etc/letsencrypt/certs -p 443:443 -p 80:80 --network mdm_default "$docker_nginx_image")
docker cp $tmp_nginx_conf_dir/. $cid:/etc/nginx/conf.d

rm -rf $tmp_nginx_conf_dir
# delete exited or currently running nginx rev proxies
old_cid="$(docker ps -qa --filter 'label=mdm-nginx-rev-proxy' --filter 'status=running' --filter 'status=exited')"
[[ $old_cid ]] && docker rm -f $old_cid
docker start $cid
