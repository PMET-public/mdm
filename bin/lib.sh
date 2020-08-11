#!/usr/bin/env bash
set -e

# don't trap errors while using VSC debugger
[[ $VSCODE_PID ]] || {
  set -E # If set, the ERR trap is inherited by shell functions.
#   trap 'error "Command $BASH_COMMAND failed with exit code $? on line $LINENO of $BASH_SOURCE.
# Env when error occurred:
# $(env | "$sort_cmd")
# "' ERR
    trap 'error "Command $BASH_COMMAND failed with exit code $? on line $LINENO of $BASH_SOURCE.' ERR
}

# this lib is used by dockerize, mdm, tests, etc. but logging to STDOUT is problematic for platypus apps
# so need a way to check and if appropiate, defer until lib can bootstrap the appropiate logging
included_by_mdm() {
  # shellcheck disable=SC2199 # error in shellcheck? implicit array concatenation - which is desired plus = vs =~
  [[ "${BASH_SOURCE[@]}" =~ /bin/mdm ]]
}

[[ "$debug" ]] && ! included_by_mdm && set -x

# iterate thru BASH_SOURCE to find this lib.sh (should work even when debugging in IDE)
bs_len=${#BASH_SOURCE[@]}
for (( index=0; index < bs_len; ((index++)) )); do
  [[ "${BASH_SOURCE[$index]}" =~ /lib.sh$ ]] && {
    lib_dir="$(dirname "${BASH_SOURCE[$index]}")"
    # if lib_dir is relative, determine & use absolute path
    [[ $lib_dir =~ ^\./ ]] && lib_dir="$(pwd)/${lib_dir#./}"
    break
  }
done

###
#
# start constants
#
###

# in general, use $lib_dir/.. to reference the running version's path; use $mdm_path only when that specific dir is intended
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[1;33m'
no_color='\033[0m'
recommended_vm_cpu=4
recommended_vm_mem_mb=4096
recommended_vm_swap_mb=2048
recommended_vm_disk_mb=64000
bytes_in_mb=1048576
mdm_demo_domain="storystore.dev"
detached_project_name="detached-mdm"
hosts_file_line_marker="# added by MDM"
host_docker_internal="172.17.0.1"

mdm_path="$HOME/.mdm"
launched_apps_dir="$mdm_path/launched-apps"
certs_dir="$mdm_path/certs"
hosts_backup_dir="$mdm_path/hosts.bak"

menu_log_file="$mdm_path/current/menu.log"
handler_log_file="$mdm_path/current/handler.log"
docker_settings_file="$HOME/Library/Group Containers/group.com.docker/settings.json"
advanced_mode_flag_file="$mdm_path/advanced_mode_on"
mdm_ver_file="$mdm_path/latest-sem-ver"

repo_url="https://github.com/PMET-public/mdm"
mdm_version="${lib_dir#$mdm_path/}" && mdm_version="${mdm_version%/bin}" && [[ $mdm_version =~ ^[0-9.]*$ ]] || mdm_version="dev?"

###
#
# end constants
#
###

###
#
# start test functions
#
###

has_uncleared_jobs_statuses() {
  [[ -d "$apps_mdm_jobs_dir" && "$(find "$apps_mdm_jobs_dir" -type f -not -name "*.cleared" -print -quit)" ]]
}

is_magento_cloud_cli_installed() {
  [[ -f "$HOME/.magento-cloud/bin/magento-cloud" ]]
}

is_docker_bash_completion_installed() {
  [[ -f "$(brew --prefix)/etc/bash_completion.d/docker" ]]
}

is_platypus_installed() {
  [[ -n "$(which platypus)" ]]
}

is_mkcert_installed() {
  [[ -n "$(which mkcert)" ]]
}

is_tmate_installed() {
  [[ -n "$(which tmate)" ]]
}

are_additional_tools_installed() {
  is_magento_cloud_cli_installed || return
  is_mac && {
    is_docker_compatible && is_docker_bash_completion_installed || return
    is_platypus_installed || return
  }
  is_mkcert_installed || return
  is_tmate_installed || return
}

can_optimize_vm_cpus() {
  cpus_for_vm=$(grep '"cpus"' "$docker_settings_file" | perl -pe 's/.*: (\d+),/\1/')
  cpus_available=$(sysctl -n hw.logicalcpu)
  [[ cpus_for_vm -lt recommended_vm_cpu && cpus_available -gt recommended_vm_cpu ]]
}

can_optimize_vm_mem() {
  memory_for_vm=$(grep '"memoryMiB"' "$docker_settings_file" | perl -pe 's/.*: (\d+),/\1/')
  memory_available=$(( $(sysctl -n hw.memsize) / bytes_in_mb ))
  [[ memory_for_vm -lt recommended_vm_mem_mb && memory_available -ge 8192 ]]
}

can_optimize_vm_swap() {
  swap_for_vm=$(grep '"swapMiB"' "$docker_settings_file" | perl -pe 's/.*: (\d+),/\1/')
  [[ swap_for_vm -lt recommended_vm_swap_mb ]]
}

can_optimize_vm_disk() {
  disk_for_vm=$(grep '"diskSizeMiB"' "$docker_settings_file" | perl -pe 's/.*: (\d+),/\1/')
  [[ disk_for_vm -lt recommended_vm_disk_mb ]]
}

is_mac() {
  [[ "$(uname)" = "Darwin" ]]
}

# override default linux docker host ip with mac dns alias host.docker.internal
is_mac && host_docker_internal="host.docker.internal"

# if the core_utils are installed (should always be true after initial install), use the GNU tools
# there may be some inconsistencies prior to install.
# if they are significant, hopefully testing finds them and will be accounted for
if is_mac && [[ -d /usr/local/Cellar/coreutils ]]; then
  # use homebrew's core utils
  stat_cmd="gstat"
  sort_cmd="gsort"
  date_cmd="gdate"
else
  stat_cmd="stat"
  sort_cmd="sort"
  date_cmd="date"
fi

is_CI() {
  [[ "$GITHUB_WORKSPACE" || "$TRAVIS" ]]
}

# this exists for CI testing of some functionality even when docker is n/a (e.g. travis and github ci with a mac)
is_docker_compatible() {
  ! ( is_mac && is_CI )
}

is_docker_installed() {
  [[ -n $(which docker) || -f "$docker_settings_file" ]]
}

is_docker_suboptimal() {
  can_optimize_vm_cpus || can_optimize_vm_mem || can_optimize_vm_swap || can_optimize_vm_disk
}

is_docker_running() {
  if is_mac; then
    # this is faster on mac and speed is important for menu rendering
    pgrep -q com.docker.hyperkit
  else
    docker ps > /dev/null 2>&1 || return 1
  fi
}

is_docker_ready() {
  docker ps > /dev/null 2>&1
}

is_onedrive_linked() {
  [[ -d "$HOME/Adobe Systems Incorporated/SITeam - docker" ]] ||
    [[ -d "$HOME/Adobe/SITeam - docker" ]]
}

is_detached() {
  [[ ! -d "$apps_resources_dir/app" ]]
}

is_magento_app_installed() {
  is_detached && return 1
  # grep once and store result in var
  [[ -n "$app_is_installed" ]] ||
    {
      echo "$formatted_cached_docker_ps_output" | grep -q "^${COMPOSE_PROJECT_NAME}_db_1 "
      app_is_installed=$?
    }
  return "$app_is_installed"
}

is_magento_app_running() {
  is_detached && return 1
  # grep once and store result in var
  [[ -n "$app_is_running" ]] || {
    echo "$formatted_cached_docker_ps_output" | grep -q "^${COMPOSE_PROJECT_NAME}_db_1 Up"
    app_is_running=$?
  }
  return "$app_is_running"
}

are_required_ports_free() {
  { ! nc -z 127.0.0.1 80 && ! nc -z 127.0.0.1 443; } > /dev/null 2>&1
  return
}

is_nginx_rev_proxy_running() {
  container_id=$(docker ps -q --filter 'label=mdm-nginx-rev-proxy')
  [[ -n "$container_id" ]]
}

is_network_state_ok() {
  # check once and store result in var
  [[ -n "$network_state_is_ok" ]] || {
    are_required_ports_free || is_nginx_rev_proxy_running
    network_state_is_ok=$?
  }
  return "$network_state_is_ok"
}

are_other_magento_apps_running() {
  echo "$formatted_cached_docker_ps_output" | \
    grep -v "^${COMPOSE_PROJECT_NAME}_db_1 " | \
    grep -q -v ' Exited$'
  return $?
}

invoked_mdm_without_args() {
  # it can be difficult to determine whether mdm was called w/o args to display the menu or invoke a selected menu item
  # bash5 on mac and bash4 on linux report BASH_ARGC (he number of parameters in each frame of the current bash 
  # execution call stack) differently. also the vsc debugger wraps the call in other args (changing BASH_ARGC)
  # so modify this carefully.
  # for debugging, bash vscode debugger changes normal invocation, so check for a special env var $vsc_debugger_arg
  if [[ "$vsc_debugger_arg" == "n/a" ]]; then
    return 0 # invoked WITHOUT args
  elif [[ -n "$vsc_debugger_arg" ]]; then
    mdm_first_arg="$vsc_debugger_arg"
    return 1 # invoked WITH args
  elif [[ "${BASH_ARGV[-1]}" =~ /bin/mdm$ ]]; then
    return 0 # invoked WITHOUT args
  else
    mdm_first_arg="${BASH_ARGV[-1]}"
    return 1 # invoked WITH args
  fi
}

# need way to distinguish being sourced for specific app or sourced for some other script (e.g. dockerize script)
lib_sourced_for_specific_bundled_app() {
  # if a specific apps_resources_dir is already set in the env, then lib was sourced for a specific app
  if [[ $apps_resources_dir ]]; then
    # check that the dir was properly specified
    [[ ! -d $apps_resources_dir ]] && error "$apps_resources_dir does not exist."
    # it exists - return success
    return 0
  fi
  # else is the sourcing process a specific app instance?
  # DON'T use ${BASH_SOURCE[-1]} b/c this is unusual reference before bash is upgraded on mac
  local oldest_parent_path="${BASH_SOURCE[${#BASH_SOURCE[@]}-1]}"
  [[ "$oldest_parent_path" =~ \.app\/Contents\/ ]] &&
    apps_resources_dir="${oldest_parent_path/\/Contents\/*/\/Contents\/Resources}" &&
    export apps_resources_dir
}

lookup_latest_remote_sem_ver() {
  curl -svL "$repo_url/releases" | \
    perl -ne 'BEGIN{undef $/;} /archive\/([\d.]+)\.tar\.gz/ and print $1'
}

is_update_available() {
  # check for a new version once a day (86400 secs)
  local more_recent_of_two
  if [[ -f "$mdm_ver_file" && "$(( $("$date_cmd" +"%s") - $("$stat_cmd" -c%Z "$mdm_ver_file") ))" -lt 86400 ]]; then
    local latest_sem_ver
    latest_sem_ver="$(<"$mdm_ver_file")"
    [[ "$mdm_version" == "$latest_sem_ver" ]] && return 1
    # verify latest is more recent using sort -V
    more_recent_of_two="$(printf "%s\n%s" "$mdm_version" "$latest_sem_ver" | "$sort_cmd" -V | tail -1)"
    [[ "$latest_sem_ver" == "$more_recent_of_two" ]] && return
  else
    # get info in the background to prevent latency in menu rendering
    lookup_latest_remote_sem_ver > "$mdm_ver_file" 2>/dev/null &
  fi
  return 1
}

is_adobe_system() {
  [[ -d /Applications/Adobe\ Hub.app ]]
}

is_advanced_mode() {
  [[ -f "$advanced_mode_flag_file" ]]
}

is_valid_hostname() {
  # do not allow names to start with "."
  # only allow [a-zA-Z0-9] for last char
  # curl exit code 3 = bad/illegal url
  [[ ! "$1" =~ ^\. ]] && [[ "$1" =~ [a-zA-Z0-9]$ ]] && {
    # just want to know if name is valid so ignore output and timeout quickly
    # exit code 3 would be almost instant
    curl -sI ---max-time 2 "http://$1" > /dev/null || [[ "$?" -ne 3 ]]
  }
}

is_valid_git_url() {
  [[ "$1" =~ http.*\.git ]] || [[ "$1" =~ git.*\.git ]]
}

is_existing_cloud_env() {
  [[ "$env_is_existing_cloud" ]]
}

is_hostname_resolving_to_local() {
  local curl_output
  curl_output="$(curl -vI "$1" 2>&1 >/dev/null | grep Trying)"
  [[ "$curl_output" =~ ::1 || "$curl_output" =~ 127\.0\.0\.1 ]]
}

is_terminal_interactive() {
  [[ $- == *i* ]]
}

is_running_as_sudo() {
  env | grep -q 'SUDO_USER='
}

is_mkcert_CA_installed() {
  local warning_count
  is_mkcert_installed || return 1
  warning_count="$(mkcert 2>&1 | grep "Warning:" | wc -l)"
  if is_CI; then
    # no chrome or firefox installed on CI so a warning remains
    [[ "$warning_count" -eq 1 ]]
  else
    [[ "$warning_count" -eq 0 ]]
  fi
}

has_valid_composer_auth() {
  [[ "$COMPOSER_AUTH" =~ \{.*github-oauth && "$COMPOSER_AUTH" =~ repo.magento.com.*\} ]] && return
  if [[ -f "$HOME/.composer/auth.json" ]]; then
    # print auth.json as 1 line and assign to var
    COMPOSER_AUTH="$(perl -0777 -pe 's/\r?\n//g;s/\s*("|{|})\s*/\1/g' "$HOME/.composer/auth.json")"
    if [[ "$COMPOSER_AUTH" =~ github-oauth && "$COMPOSER_AUTH" =~ repo.magento.com ]]; then
      export COMPOSER_AUTH && return
    fi
  fi
  return 1
}

###
#
# end test functions
#
###

###
#
# start util functions
#
###

trim() {
  echo "$@" | xargs
}

error() {
  printf "\n%b%s%b\n\n" "$red" "[$("$date_cmd" --utc +"%Y-%m-%d %H:%M:%S")] Error: $*" "$no_color" 1>&2 && exit 1
}

warning() {
  printf "%b%s%b" "$yellow" "$*" "$no_color"
}

warning_w_newlines() {
  warning "
$*
"
}

msg() {
  printf "%b%s%b" "$green" "$*" "$no_color"
}

msg_w_newlines() {
  msg "
$*
"
}

msg_w_timestamp() {
  msg "[$("$date_cmd" -u +%FT%TZ)] $*"
}

convert_secs_to_hms() {
  h="$(($1/3600))"
  m="$((($1%3600)/60))"
  s="$(($1%60))"
  [[ "$h" != "0" ]]  && printf "%dh %dm %ds" "$h" "$m" "$s" && return
  [[ "$m" != "0" ]]  && printf "%dm %ds" "$m" "$s" && return
  printf "%ds" "$s" && return
}

seconds_since() {
  echo "$(( $("$date_cmd" +"%s") - $1 ))"
}

reverse_array() {
    declare -n input_array="$1" output_array="$2"
    local index
    for index in "${input_array[@]}"; do
        output_array=("$index" "${output_array[@]}")
    done
}

confirm_or_exit() {
  warning "

ARE YOU SURE?! (y/n)

"
  read -r -p ''
  [[ $REPLY =~ ^[Yy]$ ]] || {
    msg_w_newlines "Exiting unchanged." && exit
  }
}

# look in env and fallback to expected home path
get_github_token_from_composer_auth() {
  ( echo "$COMPOSER_AUTH" && cat "$HOME/.composer/auth.json" ) |
    perl -ne '/github.com".*?"([^"]*)"/ and print "$1\n"' |
    head -1
}

###
#
# end util functions
#
###

###
#
# start network functions
#
###

get_docker_host_ip() {
  [[ "$docker_host_ip" ]] && return # already defined
  docker_host_ip="$host_docker_internal"
  is_mac && docker_host_ip="$(docker run alpine getent hosts host.docker.internal | perl -pe 's/\s.*//')"
}

get_hostname_for_this_app() {
  [[ -f "$apps_resources_dir/app/docker-compose.yml" ]] &&
    perl -ne 's/.*VIRTUAL_HOST=\s*(.*)\s*/\1/ and print' "$apps_resources_dir/app/docker-compose.yml" ||
    error "Host not found"
}

print_containers_hosts_file_entry() {
  printf '%s' "$(get_docker_host_ip) $(get_hostname_for_this_app) $hosts_file_line_marker"
}

print_local_hosts_file_entry() {
  local hostname="$1"
  printf '%s' "127.0.0.1 $hostname $hosts_file_line_marker"
}

set_hostname_for_this_app() {
  local hostname="$1"
  is_valid_hostname "$hostname" || error "Invalid hostname"
  [[ -f "$apps_resources_dir/app/docker-compose.yml" ]] &&
    perl -i -pe "s/(.*VIRTUAL_HOST=\s*)(.*)(\s*)/\1$hostname\3/" "$apps_resources_dir/app/docker-compose.yml" ||
    error "Host not found"
}

get_pwa_hostname() {
  is_adobe_system && echo "pwa.$mdm_demo_domain" || echo "pwa"
}

get_pwa_prev_hostname() {
  is_adobe_system && echo "pwa-prev.$mdm_demo_domain" || echo "pwa-prev"
}

find_mdm_networks() {
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
  [[ "$apps_resources_dir" ]] || return 0
  perl -ne 's/.*VIRTUAL_HOST\s*=\s*([^ ]*).*/$1/ and print' "$apps_resources_dir/app/docker-compose.yml"
}

find_mdm_hostnames() {
  local hostnames networks
  hostnames=("$(get_pwa_hostname)" "$(get_pwa_prev_hostname)")
  networks="$(find_mdm_networks)"
  for network in $networks; do
    hostnames+=("$(find_hostname_by_network "$network")")
  done
  echo "${hostnames[*]}"
}

find_hostnames_not_resolving_to_local() {
  local hostname hostnames="$*" hostnames_not_resolving_to_local=()
  for hostname in $hostnames; do
    ! is_hostname_resolving_to_local "$hostname" && hostnames_not_resolving_to_local+=("$hostname")
  done
  echo "${hostnames_not_resolving_to_local[*]}"
}

backup_hosts() {
  cp /etc/hosts "$hosts_backup_dir/hosts.$("$date_cmd" "+%s")"
}

add_hostnames_to_hosts_file() {
  [[ "$*" ]] || return 0
  local hostnames="$*" hostname lines="" error_msg="Could not update hosts files." tmp_hosts
  for hostname in $hostnames; do
    lines+="$(print_local_hosts_file_entry "$hostname")"$'\n'
  done
  echo "Password may be required to modify /etc/hosts."
  tmp_hosts=$(mktemp)
  cat /etc/hosts <(echo "$lines") > "$tmp_hosts"
  backup_hosts
  sudo_run_bash_cmds "
    mv \"$tmp_hosts\" /etc/hosts
    chmod 644 /etc/hosts
  " || error "$error_msg"
}

rm_added_hostnames_from_hosts_file() {
  backup_hosts
  sudo_run_bash_cmds "perl -i -ne \"print unless /$hosts_file_line_marker/\" /etc/hosts"
}

# for certificate functions, a wildcard domain parameter should be passed as "*.example.com" or ".example.com"
# if a domain name consisting of 2 parts is the full, desired hostname, then it should only 
# contain those 2 parts e.g. example.com
#
# N.B. most browsers will not accept a wildcard certificate for "*.example.com" as valid for "example.com",
# but a certificate can explicitly designate both "*.example.com" and "example.com" as valid 
# in the common names section of a cert

normalize_domain_if_wildcard() {
  echo "${1/#\*/}"
}

has_valid_wildcard_domain() {
  [[ "$1" =~ .+\..+ ]] # need at least 2 part domain name, and thus a "."
}

wildcard_domain_for_hostname() {
  has_valid_wildcard_domain "$1" &&
    echo "$1" | perl -pe '/.+\..+/ and s/.*?\./*./'
}

does_cert_and_key_exist_for_domain() {
  local domain cert_dir
  domain="$(normalize_domain_if_wildcard "$1")"
  cert_dir="$certs_dir/$domain"
  [[ -d "$cert_dir" && -f "$cert_dir/fullchain1.pem" && -f "$cert_dir/privkey1.pem" ]]
}

read_cert_for_domain() {
  local domain cert_dir
  domain="$(normalize_domain_if_wildcard "$1")"
  cert_dir="$certs_dir/$domain"
  openssl x509 -text -noout -in "$cert_dir/fullchain1.pem" || error "Could not read cert for $domain"
}

get_cert_utc_end_date_for_domain() {
  local end_date
  end_date="$(read_cert_for_domain "$1" | perl -ne 's/\s*not after :\s*//i and print')"
  [[ "$end_date" ]] && "$date_cmd" --utc --date="$end_date" +"%Y-%m-%d %H:%M:%S" ||
    error "Could not retrieve end date"
}

is_cert_current_for_domain() {
  local end_date
  end_date="$(get_cert_utc_end_date_for_domain "$1")"
  [[ "$end_date" && "$("$date_cmd" --utc +"%Y-%m-%d %H:%M:%S")" < "$end_date" ]] ||
    error "Could not determine if cert is current"
}

is_cert_for_domain_expiring_soon() {
  local end_date
  end_date="$(get_cert_utc_end_date_for_domain "$1")"
  [[ "$end_date" && "$("$date_cmd" --utc --date "+7 days" +"%Y-%m-%d %H:%M:%S")" > "$end_date" ]]
}


# .domain.com/ must contain a wildcard cert for "*.domain.com"
# my.domain.com/ must contain a cert for "my.domain.com" or a cert for "*.domain.com"
does_cert_follow_convention() { 
  local domain cert
  domain="$(normalize_domain_if_wildcard "$1")"
  cert="$(read_cert_for_domain "$domain")"
  if [[ "$domain" =~ ^\. ]]; then
    [[ "$cert" =~ DNS:\*$domain ]] && return
  else
    wildcard_domain="$(wildcard_domain_for_hostname "$1")"
    [[ "$cert" =~ DNS:.*$domain || "$cert" =~ DNS:\*$wildcard_domain ]] && return
  fi
  return 1
}

is_new_cert_required_for_domain() {
  ! { does_cert_and_key_exist_for_domain "$1" && is_cert_current_for_domain "$1" && 
    does_cert_follow_convention "$1" && ! is_cert_for_domain_expiring_soon "$1"; }
}

get_github_file_contents() {
  local project="$1" path="$2" ref="$3" token url
  token="$(get_github_token_from_composer_auth)"
  url="https://api.github.com/repos/$project/contents/$path?ref=${ref:-master}"
  [[ "$token" ]] && token=("-H" "Authorization: token $token")
  curl --fail -vL -H 'Accept: application/vnd.github.v3.raw' "${token[@]}" "$url"
}

get_wildcard_cert_and_key_for_mdm_demo_domain() {
  is_new_cert_required_for_domain ".$mdm_demo_domain" || return 0
  cert_dir="$certs_dir/.$mdm_demo_domain"
  mkdir -p "$cert_dir"
  get_github_file_contents "PMET-public/mdm-config" "$mdm_demo_domain/fullchain1.pem" > "$cert_dir/fullchain1.pem"
  get_github_file_contents "PMET-public/mdm-config" "$mdm_demo_domain/privkey1.pem" > "$cert_dir/privkey1.pem"
}

mkcert_for_domain() {
  local cert_dir="$certs_dir/$1" domain="$1"
  is_valid_hostname "$domain" || error "Invalid name '$domain'"
  mkdir -p "$cert_dir"
  mkcert -cert-file "$cert_dir/fullchain1.pem" -key-file "$cert_dir/privkey1.pem" "$domain"
}

cp_wildcard_mdm_demo_domain_cert_and_key_for_subdomain() {
  local subdomain="$1"
  [[ "$subdomain" =~ $mdm_demo_domain$ ]] || error "$domain is not a subdomain of $mdm_demo_domain"
  is_new_cert_required_for_domain "$subdomain" || return 0 # still valid
  is_new_cert_required_for_domain ".$mdm_demo_domain" && get_wildcard_cert_and_key_for_mdm_demo_domain
  rsync -az "$certs_dir/.$mdm_demo_domain/" "$certs_dir/$subdomain/"
}

###
#
# end network functions
#
###

sudo_run_bash_cmds() {
  local script bash_cmd
  script="$(mktemp)"
  bash_cmd="bash"
  is_mac && bash_cmd="bash -l"
  echo "#!/usr/bin/env $bash_cmd
    $*
  " > "$script"
  chmod u+x "$script"
  # echo "Running $script ..."
  if is_running_as_sudo; then
    "$script"
  elif is_terminal_interactive || is_CI; then
    sudo "$script"
  elif is_mac; then
    # osascript -e "do shell script \"sudo mv $tmp_hosts /etc/hosts \" with administrator privileges" ||
    osascript -e "do shell script \"sudo $script\" with administrator privileges"
  fi
}

# some menu item handlers should open a terminal to receive user input or display output to the user
# however, if MDM_DIRECT_HANDLER_CALL is true in function, then the calling function has already
# opened a new terminal to rerun it and we should not open new terminal again (would lead to infinite recursion)
# also, if this is not a mac, don't open a new "Terminal" and just run the calling function directly
# TODO make this cross platform compatible by opening the corresponing terminal application
run_this_menu_item_handler_in_new_terminal_if_applicable() {
  [[ $MDM_DIRECT_HANDLER_CALL ]] && return 1
  ! is_mac && return 1
  local caller script funcs="${FUNCNAME[*]}"
  # extract the calling function from the list of function names ordinarily it's immediately after
  # run_this_menu_item_handler_in_new_terminal_if_applicable unless called by the helper run_as_bash_cmds_in_app
  if [[ "$funcs" =~ "run_as_bash_cmds_in_app" ]]; then
    caller="$(echo "${FUNCNAME[*]}" | sed 's/.*run_as_bash_cmds_in_app //; s/ .*//')"
  else
    caller="$(echo "${FUNCNAME[*]}" | sed 's/.*run_this_menu_item_handler_in_new_terminal_if_applicable //; s/ .*//')"
  fi
  script="$(mktemp -t "$COMPOSE_PROJECT_NAME-$caller")" || exit
  # remember to escape in this string if you want it to be evaluated at RUN time vs when the script is written
  # also env vars are appear to be overriden by disconnected instances of Mac's Terminal app
  # (i.e. started by separate MDM apps)
  # particularly watch out for COMPOSE_PROJECT_NAME. may have to evaluate each time. 
  # see export_compose_project_name below
  echo "#!/usr/bin/env bash -l
export MDM_REPO_DIR=\"${MDM_REPO_DIR}\"
export apps_resources_dir=\"$apps_resources_dir\"
[[ \"$debug\" ]] && echo \"\$(env | $sort_cmd)\" && set -x
printf '\e[8;45;180t' # terminal size
$lib_dir/launcher $caller
" > "$script"
  chmod u+x "$script"
  open -a Terminal "$script"
  # open -F -n -a Terminal "$script"
}

detect_quit_and_stop_app() {
  # run the loop in a subshell so it doesn't fill the log with loop output
  ( 
    set +x
    # while the Platyplus app exists ($PPID), do nothing
    while ps -p $PPID > /dev/null 2>&1; do
      sleep 10
    done
  )
  # parent pid gone, so remove file and stop dockerized magento
  rm "$quit_detection_file"
  stop_app
}

# background jobs invoked by a menu selection are tracked to relay info about their progress to the user.
# the tracked info includes:
# - the PID
# - a msg
# - the start and end timestamp
# - current state: running or done
# - result state: success or error
# - UI state: ongoing, done, seen, or cleared
#
# this complexity could make it a candidate for a sqlite db but we'll defer that implementation for now
# and just capture the info using the filesytem
# the intial file will be DATE_STARTED.PID and
# will become DATE_STARTED.PID.DATE_ENDED.EXIT_CODE.UI_STATE where UI_STATE is "new"
# the UI_STATE can be updated to "seen" for errors and then "cleared" when clicked in the UI
# successes aren't worth tracking so after displaying once "new" -> "cleared"
track_job_status_and_wait_for_exit() {
  local pid_to_wait_for msg job_file
  pid_to_wait_for="$1"

  if [[ -z "$apps_mdm_jobs_dir" ]]; then 
    # shouldn't be here unless testing from $MDM_REPO_DIR
    [[ "$MDM_REPO_DIR" ]] || error "MDM_REPO_DIR and apps_mdm_jobs_dir are undefined"
    wait "$pid_to_wait_for" # wait but don't track b/c no app's mdm job dir to associate job to
  else
    msg="$2"
    job_file="$apps_mdm_jobs_dir/$("$date_cmd" +"%s").$pid_to_wait_for"
    echo "$msg" > "$job_file"
    wait "$pid_to_wait_for" || exit_code=$?
    mv "$job_file" "$job_file.$("$date_cmd" +"%s").$exit_code.done"
  fi
}

extract_tar_to_existing_container_path() {
  # extract tar to tmp dir then stream to docker build container
  # N.B. `tar -xf some.tar -O` is stream of file _contents_; `tar -cf -` is tar formatted stream (handles metadata)
  [[ "$1" && "$2" && ( "$1" =~ \.tar$ || "$1" =~ \.tar\.gz$ ) && "$2" =~ : ]] ||
    error "${FUNCNAME[0]} missing or bad required params"
  local src_tar container_dest tmp_dir
  src_tar="$1"
  container_dest="$2"
  tmp_dir="$(mktemp -d)"
  tar -zxf "$src_tar" -C "$tmp_dir"
  tar -cf - -C "$tmp_dir" . | docker cp - "$container_dest"
  rm -rf "$tmp_dir"
}

start_docker_service() {
  if is_mac; then
    open --background -a Docker
    while ! is_docker_ready; do
      sleep 1
    done
  else
    sudo systemctl start docker
  fi
}


stop_docker_service() {
  if is_mac; then
    osascript -e 'quit app "Docker"'
    while is_docker_running; do
      sleep 1
    done
  else
    sudo systemctl stop docker
  fi
}

restart_docker_and_wait() {
  stop_docker_service
  start_docker_service
}

find_magento_docker_image_ids() {
  docker images | grep -E '^(magento|pmetpublic)/' | awk '{print $3}'
}

find_non_default_networks() {
  docker network ls --format '{{.Name}}' | perl -ne 'print unless /^(bridge|host|none)$/'
}

reload_rev_proxy() {
  # shellcheck source=nginx-rev-proxy-setup.sh
  source "$lib_dir/nginx-rev-proxy-setup.sh"
}

download_and_link_latest() {
  local latest_ver latest_ver_dir
  latest_ver="${1:-$(lookup_latest_remote_sem_ver)}"
  latest_ver_dir="$mdm_path/$latest_ver"
  mkdir -p "$latest_ver_dir"
  cd "$mdm_path"
  curl -sLO "$repo_url/archive/$latest_ver.tar.gz"
  tar -zxf "$latest_ver.tar.gz" --strip-components 1 -C "$latest_ver_dir"
  rm "$latest_ver.tar.gz" current 2> /dev/null || : # cleanup and remove old link
  ln -sf "$latest_ver" current
  [[ -d current/certs ]] && rsync -az current/certs/ certs/ || : # cp over any new certs if the exist
}

# "-" dashes must be stripped out of COMPOSE_PROJECT_NAME prior to docker-compose 1.21.0 https://docs.docker.com/compose/release-notes/#1210
adjust_compose_project_name_for_docker_compose_version() {
  local docker_compose_ver more_recent_of_two
  docker_compose_ver="$(docker-compose -v | perl -ne 's/.*\b(\d+\.\d+\.\d+).*/\1/ and print')"
  more_recent_of_two="$(printf "%s\n%s" 1.21.0 "$docker_compose_ver" | "$sort_cmd" -V | tail -1)"
  # now strip dashes if 1.21.0 is more recent
  if [[ "$more_recent_of_two" != "$docker_compose_ver" ]]; then
    echo "$1" | perl -pe 's/-//g'
  else
    echo "$1"
  fi
}

get_compose_project_name() {
  local cpn_file="$apps_resources_dir/app/COMPOSE_PROJECT_NAME" name
  # return previously written compose project name
  [[ -f "$cpn_file" ]] && cat "$cpn_file" && return
  # else create a unique one & write it to file
  name="$(perl -ne 's/.*VIRTUAL_HOST=([^.]*).*/\1/ and print' "$apps_resources_dir/app/docker-compose.yml")"
  name+="-$(head /dev/urandom | LC_ALL=C tr -dc 'a-z' | head -c 4)"
  name="$(adjust_compose_project_name_for_docker_compose_version "$name")"
  printf "%s" "$name" | tee "$cpn_file"
}

export_compose_project_name() {
  if is_detached; then
    COMPOSE_PROJECT_NAME="$detached_project_name"
  else
    COMPOSE_PROJECT_NAME="$(get_compose_project_name)"
  fi
  export COMPOSE_PROJECT_NAME
}

export_compose_file() {
  if is_detached; then
    COMPOSE_FILE="$lib_dir/../docker-files/docker-compose.yml"
  else
    COMPOSE_FILE="$apps_resources_dir/app/docker-compose.yml"
    # check for a CWD override file
    [[ -f "$apps_resources_dir/docker-compose.override.yml" ]] && {
      COMPOSE_FILE+=":$apps_resources_dir/app/docker-compose.override.yml"
    }
    # also use the global override file included with MDM
    [[  -f "$lib_dir/../docker-files/mcd.override.yml" ]] && {
      COMPOSE_FILE+=":$lib_dir/../docker-files/mcd.override.yml"
    }
  fi
  export COMPOSE_FILE
}

export_image_vars_for_override_yml() {
  #TODO - properly derive this value by examining config
  export php_cli_docker_image="pmetpublic/magento-cloud-docker-php:7.3-cli-1.1"
}

get_docker_compose_runtime_services() {
  # get only runtime services build and deploy restarts may be interfering; tls and generic are unused
  docker-compose config |
    python -c "import sys, yaml; data=yaml.load(sys.stdin); print(' '.join(data['services'].keys()))" |
    perl -pe 's/build|deploy|generic|tls//g'
}

# if come across entry with no handler or link, entering submenu
# 
render_platypus_status_menu() {
  local index key key_length menu_output is_submenu
  key_length=${#mdm_menu_items_keys[@]}
  menu_output=""
  is_submenu=false
  # based on Platypus menu syntax, submenu headers are not seletctable so no handler or link entry unlike actual submenu items
  for (( index=0; index < key_length; index++ )); do
    key="${mdm_menu_items_keys[$index]}"
    if [[ $key = "end submenu" ]]; then
      $is_submenu && {
        is_submenu=false
        menu_output+=$'\n'
        continue
      }
    fi
    # no handler or link? must be a submenu heading
    [[ -z "${mdm_menu_items["$key-handler"]}" && -z "${mdm_menu_items["$key-link"]}" ]] && {
      # if menu has some output already & if a submenu heading, was the last char a newline? if not, add one to start new submenu
      [[ -n $menu_output && ! $menu_output =~ $'\n'$ ]] && menu_output+=$'\n'
      menu_output+="SUBMENU|$key"
      is_submenu=true
      continue
    }
    [[ ${mdm_menu_items["$key-disabled"]} ]] && menu_output+="DISABLED|"
    # status menu at top of menu case - needs newline
    if [[ "$key" =~ ^DISABLED && "$key" =~ ---$ ]]; then
      menu_output+="$key"$'\n'
    else
      $is_submenu && menu_output+="|"
      menu_output+="$key"
      $is_submenu || menu_output+=$'\n'
    fi
  done
  printf "%s" "$menu_output"
}

handle_mdm_args() {
  local key value
  # check what type of menu item was selected

  # a handler?
  key="$mdm_first_arg-handler"
  [[ -n "${mdm_menu_items[$key]}" ]] && {
    "${mdm_menu_items[$key]}"
    exit
  }

  # a link?
  key="$mdm_first_arg-link"
  [[ -n "${mdm_menu_items[$key]}" ]] && {
    open "${mdm_menu_items[$key]}"
    exit
  }

  # direct invocations of the launcher with currently valid, single menu item handlers are allowed 
  # to facilitate testing (e.g. ./launcher some_menu_item_handler_function_name)
  # N.B. a menu item is not "valid" if it does not appear in the current menu items 
  # (so don't test options that wouldn't be available (invalid))
  #
  # an env var is exported to mark these calls in case changes in the handler behavior are appropiate for these calls
  # (e.g. it's not appropiate to launch a new interactive OSX terminal)
  for value in "${mdm_menu_items[@]}"; do
    [[ "$mdm_first_arg" = "$value" ]] && {
      export MDM_DIRECT_HANDLER_CALL=true
      # BASH_ARGV has all parameters in the current bash execution call stack
      # the final parameter of the last subroutine call is first in the queue
      # the first parameter of the initial call is last
      # in this case, the sourced bin/mdm is first and the last element is the directly called handler
      # so remove the first and last and reverse the middle (whew!)
      local len=$(( ${#BASH_ARGV[*]} - 2 )) remaining_args
      reverse_array BASH_ARGV remaining_args
      "$mdm_first_arg" "${remaining_args[@]:1:$len}"
      exit
    }
  done

  error "Handler for $mdm_first_arg was not found or valid in this context."

}

ensure_mdm_log_files_exist() {
  touch "$menu_log_file" "$handler_log_file"
}

run_bundled_app_as_script() {
  [[ $apps_resources_dir ]] || error "App's resources dir not set"
  local script_arg="$1"
  # invoke in the same way platypus would
  if is_mac; then
    /usr/bin/env -P "/usr/local/bin:/bin" bash -c "$apps_resources_dir/script $script_arg"
  else
    /usr/bin/env bash -c "debug=1; set -x; env; $apps_resources_dir/script $script_arg"
  fi
}

init_app_specific_vars() {
  # export vars that may be used in a non-child terminal script so when lib is sourced, vars are defined
  export_compose_project_name
  export_compose_file
  if ! is_detached; then
    export_image_vars_for_override_yml
  fi
  apps_mdm_dir="$launched_apps_dir/$COMPOSE_PROJECT_NAME"
  apps_mdm_jobs_dir="$apps_mdm_dir/jobs"
  mkdir -p "$apps_mdm_jobs_dir"
}

init_mdm_logging() {
  if invoked_mdm_without_args; then
    cur_log_file="$menu_log_file"
  else
    cur_log_file="$handler_log_file"
  fi
  # log stdout to log file, too
  exec > >(tee -ia "$cur_log_file")
  # exec 2> >(tee -ia "$cur_log_file")
  exec 2>> "$cur_log_file"
  if invoked_mdm_without_args; then
    msg_w_timestamp "Script called without args" >&2
  else 
    msg_w_timestamp "Script called with ${BASH_ARGV[-1]}" >&2
  fi
  # before this point, enabling debugging could cause debug info in menu output
  set -x
}

init_quit_detection() {
  quit_detection_file="$apps_mdm_dir/.$PPID-still_running"
  # if quit_detection_file does not exist, this is either the 1st start or it was removed when quit
  [[ ! -f "$quit_detection_file" ]] && {
    touch "$quit_detection_file"
    detect_quit_and_stop_app >> "$handler_log_file" 2>&1 & # must background & disconnect STDIN & STDOUT for Platypus to exit
  } || :
}

###
#
# initialization logic
#
##

self_install() {

  is_terminal_interactive && printf '\e[8;50;140t' # resize terminal

  # on linux, some services require a min virtual memory map count and may need to be raised
  # https://devdocs.magento.com/cloud/docker/docker-containers-service.html#troubleshooting
  ! is_mac && [[ $(sysctl vm.max_map_count | perl -pe 's/.*=\s*//') -lt 262144 ]] && {
    sudo sysctl -w vm.max_map_count=262144 > /dev/null 2>&1
  }

  # create expected directory structure
  mkdir -p "$launched_apps_dir" "$certs_dir" "$hosts_backup_dir"
  
  pushd "$MDM_REPO_DIR"
  MDM_REPO_BRANCH="$(git branch --show-current)"
  popd
  download_and_link_latest "$MDM_REPO_BRANCH"

  msg_w_newlines "
Once all requirements are installed and validated, this script will not need to run again."

  if is_mac; then

    # install homebrew
    [[ -f /usr/local/bin/brew ]] || {
      warning_w_newlines "This script installs Homebrew, which may require your password. If you're
    skeptical about entering your password here, you can install Homebrew (https://brew.sh/)
    independently first. Then you will NOT be prompted for your password by this script."
      msg_w_newlines "Alternatively, you can allow this script to install Homebrew by pressing ANY key to continue."

      ! is_CI && read -n 1 -s -r -p ""

      clear

      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
    }

    # do not install docker (which is docker toolbox) via homebrew; use docker for mac instead
    # upgrade mac's bash, use coreutils for consistency across *NIX
    brew install bash coreutils
    brew upgrade bash coreutils

    [[ -d /Applications/Docker.app ]] || {
      msg_w_newlines "
    Press ANY key to continue to the Docker Desktop For Mac download page. Then download and install that app.

    https://hub.docker.com/editions/community/docker-ce-desktop-mac/
  "
      ! is_CI && read -n 1 -s -r -p ""
      # open docker for mac installation page
      open "https://hub.docker.com/editions/community/docker-ce-desktop-mac/"
    }

    msg_w_newlines "CLI dependencies successfully installed. Once you download and install Docker Desktop for Mac, this script should not run again."

  fi

  # needed by multiple platforms
  # install mkcert but do not install CA generated by mkcert without explicit user interaction
  # nss is required by mkcert to install Firefox trust store
  brew install mkcert nss || :
  brew upgrade mkcert nss

  msg_w_newlines "You may close this terminal."
}

self_uninstall() {
  [[ -d "$mdm_path" && -f "$mdm_path/current/bin/lib.sh" ]] && rm -rf "$mdm_path" || :
}

lib_sourced_for_specific_bundled_app && {
  ensure_mdm_log_files_exist
  init_app_specific_vars
  [[ "$debug" ]] && init_mdm_logging
  ! is_detached && init_quit_detection
  # if docker is up, then cache this output to parse when adding and filtering additional available menu options
  is_docker_ready && formatted_cached_docker_ps_output="$(
    docker ps -a -f "label=com.docker.compose.service=db" --format "{{.Names}} {{.Status}}" | \
      perl -pe 's/ (Up|Exited) .*/ \1/'
  )"
}

: # need to return true or will exit when sourced with "-e" and last test = false
