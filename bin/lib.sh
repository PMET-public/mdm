#!/usr/bin/env bash
set -e

# don't trap errors while using VSC debugger
[[ "$VSCODE_PID" ]] || {
  set -E # If set, the ERR trap is inherited by shell functions.
  trap 'error "Command $BASH_COMMAND failed with exit code $? on line $LINENO of $BASH_SOURCE."' ERR
}

# this lib is used by dockerize, mdm, tests, etc. but logging to STDOUT is problematic for platypus apps
# so need a way to check and if appropiate, defer output until lib can bootstrap the appropiate logging
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
    [[ "$lib_dir" =~ ^\./ ]] && lib_dir="$PWD/${lib_dir#./}"
    break
  }
done

###
#
# start constants
#
###

# in general, use $lib_dir/.. to reference the running version's path; use $mdm_path only when the central install dir is intended
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[1;33m'
no_color='\033[0m'
recommended_vm_cpu=4
recommended_vm_mem_mb=4096
recommended_vm_swap_mb=4096
recommended_vm_disk_mb=64000
bytes_in_mb=1048576
detached_project_name="MDM-lite"
hosts_file_line_marker="# added by MDM"
host_docker_internal="172.17.0.1"

mdm_path="$HOME/.mdm" # must be set in lib.sh and launcher b/c each can be used independently
launched_apps_dir="$mdm_path/launched-apps"
certs_dir="$mdm_path/certs"
hosts_backup_dir="$mdm_path/hosts.bak"
see_docs_msg="See docs."

mdm_config_filename=".mdm_config.sh"
mdm_config_file="$mdm_path/$mdm_config_filename"
menu_log_file="$mdm_path/menu.log"
handler_log_file="$mdm_path/handler.log"
dockerize_log_file="$mdm_path/dockerize.log"
docker_settings_file="$HOME/Library/Group Containers/group.com.docker/settings.json"
advanced_mode_flag_file="$mdm_path/advanced-mode-on"
mkcert_installed_flag_file="$mdm_path/.mkcert-installed"
rel_app_config_file="app/.docker/config.env"
mdm_ver_file="$mdm_path/latest-sem-ver"
magento_cloud_cmd="$HOME/.magento-cloud/bin/magento-cloud"

docker_install_link="https://hub.docker.com/editions/community/docker-ce-desktop-mac/"
repo_url="https://github.com/PMET-public/mdm"
mdm_version="${lib_dir#$mdm_path/}" && mdm_version="${mdm_version%/bin}" && [[ "$mdm_version" =~ ^[0-9.]*$ ]] || mdm_version="0.0.0-dev"

# a mnemonic for storing certain calculated vals. however b/c this lib needs bash 3 compatibility initially,
# no functionality requiring the mdm_store can be run until after initialization logic
declare -A mdm_store  2> /dev/null || :

[[ -f "$mdm_config_file" ]] && {
  # shellcheck source=../.mdm_config.sh
  source "$mdm_config_file"
}

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
  [[ -f "$magento_cloud_cmd" ]]
}

is_magento_cloud_cli_logged_in() {
  local status
  "$magento_cloud_cmd" > /dev/null 2>&1 || status=$?
  [[ "$status" -eq 0 ]]
}

is_docker_bash_completion_installed_on_mac() {
  [[ -h "/usr/local/etc/bash_completion.d/docker" ]]
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

is_web_tunnel_configured() {
  [[ "$mdm_tunnel_ssh_url" && "$mdm_tunnel_domain" && "$mdm_tunnel_pk_url" ]]
}

are_additional_tools_installed() {
  is_magento_cloud_cli_installed || return 1
  is_mac && {
    is_docker_compatible && is_docker_bash_completion_installed_on_mac || return 1
    is_platypus_installed || return 1
  }
  is_mkcert_installed || return 1
  is_tmate_installed || return 1
}

can_optimize_vm_cpus() {
  cpus_for_vm="$(grep '"cpus"' "$docker_settings_file" | perl -pe 's/.*: (\d+),/$1/')"
  cpus_available="$(sysctl -n hw.logicalcpu)"
  [[ cpus_for_vm -lt recommended_vm_cpu && cpus_available -gt recommended_vm_cpu ]]
}

can_optimize_vm_mem() {
  memory_for_vm="$(grep '"memoryMiB"' "$docker_settings_file" | perl -pe 's/.*: (\d+),/$1/')"
  memory_available="$(( $(sysctl -n hw.memsize) / bytes_in_mb ))"
  [[ memory_for_vm -lt recommended_vm_mem_mb && memory_available -ge 8192 ]]
}

can_optimize_vm_swap() {
  swap_for_vm="$(grep '"swapMiB"' "$docker_settings_file" | perl -pe 's/.*: (\d+),/$1/')"
  [[ swap_for_vm -lt recommended_vm_swap_mb ]]
}

can_optimize_vm_disk() {
  disk_for_vm="$(grep '"diskSizeMiB"' "$docker_settings_file" | perl -pe 's/.*: (\d+),/$1/')"
  [[ disk_for_vm -lt recommended_vm_disk_mb ]]
}

is_mac() {
  # [[ "$(uname)" = "Darwin" ]]
  # matching against uname is relatively slow compared to checking for safari and the users dir
  # and if this funct is called 20x to render the menu, it makes a diff
  [[ -d /Applications/Safari.app && -d /Users ]]
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
  which docker > /dev/null 2>&1
}

is_docker_initialized_on_mac() {
  [[ -f "$docker_settings_file" ]]
}

are_docker_settings_optimized() {
  local md5 md5_file
  md5="$(md5sum "$docker_settings_file" | sed 's/ .*//')"
  md5_file="$mdm_path/.md5-of-optimized-docker-settings-${md5}"
  [[ -f "$md5_file" ]] && return 0
  if can_optimize_vm_cpus || can_optimize_vm_mem || can_optimize_vm_swap || can_optimize_vm_disk; then
    return 1
  fi
  touch "$md5_file"
  return 0
}

is_docker_running() {
  docker ps > /dev/null 2>&1
}

is_docker_running_cached() {
  [[ "${mdm_store["docker_is_running"]}" ]] && return "${mdm_store["docker_is_running"]}" # already calculated
  mdm_store["docker_is_running"]=0
  mdm_store["formatted_docker_ps_output"]="$(docker ps -a --format "{{.Names}} {{.Status}} [labels]: {{.Labels}}" 2> /dev/null)" ||
    mdm_store["docker_is_running"]="$?"
  return "${mdm_store["docker_is_running"]}"
}

is_detached() {
  [[ ! -d "$apps_resources_dir/app" ]]
}

is_magento_app_installed_cached() {
  is_detached && return 1
  [[ "${mdm_store["app_is_installed"]}" ]] && return "${mdm_store["app_is_installed"]}" # already calculated
  mdm_store["app_is_installed"]=0
  echo "${mdm_store["formatted_docker_ps_output"]}" | grep -q "^${COMPOSE_PROJECT_NAME}_db_1 " || mdm_store["app_is_installed"]="$?"
  return "${mdm_store["app_is_installed"]}"
}

is_magento_app_running_cached() {
  is_detached && return 1 # n/a
  [[ "${mdm_store["magento_app_is_running"]}" ]] && return "${mdm_store["magento_app_is_running"]}" # already calculated
  local service services
  services="$(get_docker_compose_runtime_services)"
  mdm_store["magento_app_is_running"]=0 # assume up and will return 0 unless an expected up service is not found
  for service in $services; do
    # if a service sets to 1, func will have non-zero exit, so false (app is not fully running)
    echo "${mdm_store["formatted_docker_ps_output"]}" | grep -q "^${COMPOSE_PROJECT_NAME}_${service}_1 Up" ||
      { mdm_store["magento_app_is_running"]="$?"; break; }
  done
  return "${mdm_store["magento_app_is_running"]}"
}

is_pwa_module_installed() {
  [[ -f "$apps_resources_dir/app/composer.json" ]] && grep -q "PMET-public/module-storystore" "$apps_resources_dir/app/composer.json"
}

are_required_ports_free() {
  { ! nc -z 127.0.0.1 80 && ! nc -z 127.0.0.1 443; } > /dev/null 2>&1
  return
}

is_nginx_rev_proxy_running() {
  echo "${mdm_store["formatted_docker_ps_output"]}" | grep -q ' Up .*mdm-nginx-rev-proxy'
}

is_network_state_ok() {
  # check once and store result in var
  [[ -n "${mdm_store["network_state_is_ok"]}" ]] || {
    are_required_ports_free || is_nginx_rev_proxy_running
    mdm_store["network_state_is_ok"]="$?"
  }
  return "${mdm_store["network_state_is_ok"]}"
}

are_other_magento_apps_running() {
  echo "${mdm_store["formatted_docker_ps_output"]}" |
    grep "_db_1 " |
    grep -v "^${COMPOSE_PROJECT_NAME}_db_1 " |
    grep -q -v '_db_1 Exited'
  return "$?"
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
  if [[ "$apps_resources_dir" ]]; then
    # check that the dir was properly specified
    [[ ! -d "$apps_resources_dir" ]] && error "$apps_resources_dir does not exist."
    # it exists - return success
    return 0
  fi
  # else is the sourcing process a specific app instance?
  # DON'T use ${BASH_SOURCE[-1]} b/c invalid syntax before bash upgraded
  local oldest_parent_path="${BASH_SOURCE[${#BASH_SOURCE[@]}-1]}"
  if which realpath > /dev/null 2>&1; then
    oldest_parent_path="$(realpath "$oldest_parent_path")"
  else 
    return 1 # TODO this is not strictly correct but this func doesn't matter before realpath is installed?
  fi
  [[ "$oldest_parent_path" =~ \.app\/Contents\/ ]] &&
    apps_resources_dir="${oldest_parent_path/\/Contents\/*/\/Contents\/Resources}" &&
    export apps_resources_dir
}

lookup_latest_remote_sem_ver() {
  curl -sL "$repo_url/releases" | \
    perl -ne 'BEGIN{undef $/;} /archive\/([\d.]+)\.tar\.gz/ and print $1'
}

is_update_available() {
  # check for a new version once a day (86400 secs)
  local latest_sem_ver more_recent_of_two
  if [[ -f "$mdm_ver_file" && "$(( $(date +"%s") - $("$stat_cmd" -c%Z "$mdm_ver_file") ))" -lt 86400 ]]; then
    latest_sem_ver="$(<"$mdm_ver_file")"
    [[ "$mdm_version" == "$latest_sem_ver" ]] && return 1
    # verify latest is more recent using sort -V
    more_recent_of_two="$(printf "%s\n%s" "$mdm_version" "$latest_sem_ver" | "$sort_cmd" -V | tail -1)"
    [[ "$latest_sem_ver" == "$more_recent_of_two" ]] && return 0
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
    curl -sI --max-time 2 "http://$1" > /dev/null || [[ "$?" -ne 3 ]]
  }
}

is_valid_git_url() {
  [[ "$1" =~ http.*\.git ]] || [[ "$1" =~ git.*\.git ]]
}

is_existing_cloud_env() {
  [[ "$env_is_existing_cloud" ]]
}

is_valid_github_web_url() {
  local url="$1"
  [[ "$url" =~ https?://.*github\.com/.+/.+ ]]
}

get_branch_from_github_web_url() {
  local url="$1"
  echo "$url" | perl -ne '/.*\/(tree|blob|commit)\/([^\/]+)/ and print $2'
}

is_valid_mc_url() {
  local url="$1"
  [[ "$url" =~ https?://.*magento\.cloud/ ]]
}

is_hostname_resolving_to_local() {
  local curl_output
  curl_output="$(curl --max-time 0.5 -vI "$1" 2>&1 >/dev/null | grep Trying)"
  [[ "$curl_output" =~ ::1 || "$curl_output" =~ 127\.0\.0\.1 ]]
}

is_interactive_terminal() {
  [[ $- == *i* ]]
}

launched_from_mac_menu_cached() {
  [[ "${mdm_store["launched_from_mac_menu_cached"]}" ]] && return "${mdm_store["launched_from_mac_menu_cached"]}" # already calculated
  [[ "$(ps -p $PPID -o comm=)" =~ Contents/MacOS/ ]]
  mdm_store["launched_from_mac_menu_cached"]="$?"
  return "${mdm_store["launched_from_mac_menu_cached"]}"
}

is_running_as_sudo() {
  env | grep -q 'SUDO_USER='
}

is_mkcert_CA_installed() {
  # if user install mkcert CA out of band, this will be inaccurate
  # but using the menu item to install/uninstall again will bring it back in sync
  [[ -f "$mkcert_installed_flag_file" ]]
}

is_string_valid_composer_credentials() {
  local str="$1" status=0 md5 md5_file
  md5="$(echo "$1" | md5sum | sed 's/ .*//')"
  md5_file="$mdm_path/.md5-of-passed-composer-cred-${md5}"
  # for max menu rendering speed, check for md5 of prev passed credentials
  [[ -f "$md5_file" ]] && return 0
  echo "$1" | jq -e -c '[."github-oauth"."github.com", ."http-basic"."repo.magento.com"["username","password"]] |
      map(strings) |
      length == 3' > /dev/null 2>&1 || status="$?"
  if [[ "$status" -eq 0 ]]; then
    touch "$md5_file"
  fi
  return "$status"
}

has_valid_composer_credentials_cached() {
  [[ "${mdm_store["composer_credentials_are_valid"]}" ]] && return "${mdm_store["composer_credentials_are_valid"]}" # already calculated
  # check the env var
  [[ "$COMPOSER_AUTH" ]] && 
    is_string_valid_composer_credentials "$COMPOSER_AUTH" && 
    mdm_store["composer_credentials_are_valid"]=0 && 
    return "${mdm_store["composer_credentials_are_valid"]}"
  # check the user's file
  [[ -f "$HOME/.composer/auth.json" ]] && 
    COMPOSER_AUTH="$(<"$HOME/.composer/auth.json")" && 
    is_string_valid_composer_credentials "$COMPOSER_AUTH" &&
    mdm_store["composer_credentials_are_valid"]=0 &&
    export COMPOSER_AUTH &&
    return "${mdm_store["composer_credentials_are_valid"]}"
  mdm_store["composer_credentials_are_valid"]=1
  return "${mdm_store["composer_credentials_are_valid"]}"
}

# has_magento_cloud_token() {
#   [[ "$MAGENTO_CLOUD_CLI_TOKEN" ]]
# }

# is_ssh_agent_running() {
#   [[ "$SSH_AUTH_SOCK" =~ ^/ ]]
# }

# has_magento_cloud_ssh_key() {
#   local status key_list
#   key_list="$("$magento-cloud_cmd" ssh-key:list --no-header --format csv || return 1)"
#   [[ "$key_list" =~ ",/" ]]
# }

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
  printf "\n%b%s%b\n\n" "$red" "[$(date +"%FT%TZ")] Error: $*" "$no_color" 1>&2 && exit 1
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
  msg "[$(date +"%FT%TZ")] $*"
}

convert_secs_to_hms() {
  h="$(($1/3600))"
  m="$((($1%3600)/60))"
  s="$(($1%60))"
  [[ "$h" != 0 ]]  && printf "%dh %dm %ds" "$h" "$m" "$s" && return 0
  [[ "$m" != 0 ]]  && printf "%dm %ds" "$m" "$s" && return 0
  printf "%ds" "$s" && return 0
}

seconds_since() {
  echo "$(( $(date +"%s") - $1 ))"
}

show_success_msg_plus_duration() {
  msg_w_newlines "Completely successfully in ⌚️$(convert_secs_to_hms "$(seconds_since "$1")")"
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
  [[ "$REPLY" =~ ^[Yy]$ ]] || {
    msg_w_newlines "Exiting unchanged." && exit
  }
}

# look in env and fallback to expected home path
get_github_token_from_composer_auth() {
  local token
  [[ "$COMPOSER_AUTH" ]] && {
    token="$(echo "$COMPOSER_AUTH" | perl -ne '/github.com".*?"([^"]*)"/ and print "$1"')"
    [[ "$token" =~ [a-zA-Z0-9]{20,} ]] && echo "$token" && return
  }
  [[ -f "$HOME/.composer/auth.json" ]] && {
    token="$(perl -ne '/github.com".*?"([^"]*)"/ and print "$1"' "$HOME/.composer/auth.json")"
    [[ "$token" =~ [a-zA-Z0-9]{20,} ]] && echo "$token" && return
  }
  return 1
}

get_project_from_mc_url() {
  local url="$1"
  echo "$url" | perl -ne '/.*?\/projects\/([^\/]+)/ and print $1'
}

get_env_from_mc_url() {
  local url="$1"
  echo "$url" | perl -ne '/.*?\/environments\/([^\/]+)/ and print $1'
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
  [[ "$docker_host_ip" ]] && return 0 # already defined
  docker_host_ip="$host_docker_internal"
  is_mac && docker_host_ip="$(docker run --rm alpine getent hosts host.docker.internal | perl -pe 's/\s.*//')"
  printf '%s' "$docker_host_ip"
}

print_containers_hosts_file_entry() {
  printf '%s' "$(get_docker_host_ip) $(get_hostname_for_this_app) $hosts_file_line_marker"
}

print_local_hosts_file_entry() {
  local hostname="$1"
  printf '%s' "127.0.0.1 $hostname $hosts_file_line_marker"
}

get_hostname_for_this_app() {
  [[ -f "$apps_resources_dir/$rel_app_config_file" ]] &&
    perl -ne 's/^APP_HOSTNAME=\s*(.*)\s*/$1/ and print' "$apps_resources_dir/$rel_app_config_file" ||
    error "Host not found"
}

get_prev_hostname_for_this_app() {
  [[ -f "$apps_resources_dir/$rel_app_config_file" ]] &&
    perl -ne 's/^PREV_APP_HOSTNAME=\s*(.*)\s*/$1/ and print' "$apps_resources_dir/$rel_app_config_file" ||
    error "Host not found"
}

set_hostname_for_this_app() {
  local new_hostname="$1" cur_hostname prev_hostname
  is_valid_hostname "$new_hostname" || error "Invalid hostname"
  if [[ -f "$apps_resources_dir/$rel_app_config_file" ]]; then
    cur_hostname="$(perl -ne '/^(APP_HOSTNAME=\s*)(.*)(\s*)/ and print $2' "$apps_resources_dir/$rel_app_config_file")"
    prev_hostname="$(perl -ne '/^(PREV_APP_HOSTNAME=\s*)(.*)(\s*)/ and print $2' "$apps_resources_dir/$rel_app_config_file")"
    [[ "$cur_hostname" != "$new_hostname" ]] &&
      perl -i -pe "s/^(APP_HOSTNAME=\s*)(.*)(\s*)/\${1}$new_hostname\${3}/" "$apps_resources_dir/$rel_app_config_file"
    # update prev hostname unless a tunnel domain to prevent reverting to a tunnel domain
    [[ "$cur_hostname" != "$prev_hostname" && ! "$cur_hostname" =~ "$mdm_tunnel_domain"$ ]] &&
      perl -i -pe "s/^(PREV_APP_HOSTNAME=\s*)(.*)(\s*)/\${1}$cur_hostname\${3}/" "$apps_resources_dir/$rel_app_config_file"
    return 0
  else
    error "Host not found"
  fi
}

stop_ssh_tunnel() {
  is_web_tunnel_configured || return 0
  local hostname
  hostname="$(get_hostname_for_this_app)"
  port="${hostname/.*}"
  if pkill -f "ssh.*$port:.*$mdm_tunnel_ssh_url"; then
    msg_w_newlines "Succcessfully stopped 1 or more remote web sessions."
  else
    msg_w_newlines "No active remote web sessions."
  fi
}

update_hostname() {
  local new_hostname="$1" cur_hostname prev_hostname
  cur_hostname="$(get_hostname_for_this_app)"
  prev_hostname="$(get_prev_hostname_for_this_app)"
  if [[ "$cur_hostname" != "$new_hostname" ]]; then
    set_hostname_for_this_app "$new_hostname"
    run_as_bash_cmds_in_app "$(get_magento_cmds_to_update_hostname_to $new_hostname)"
    warm_cache > /dev/null 2>&1 &
    if is_web_tunnel_configured; then
      # reload the proxy if the new hostname is not a tunnel domain b/c it will be a public url
      # UNLESS reverting from a tunnel domain to the previous hostname b/c proxy settings will not have changed
      if [[ ! "$new_hostname" =~ "$mdm_tunnel_domain"$ ]]; then
        if [[ "$cur_hostname" =~ "$mdm_tunnel_domain"$ && "$new_hostname" = "$prev_hostname" ]]; then
          : # do nothing b/c reverting from tunnel domain that did not change proxy settings
        else
          reload_rev_proxy
        fi
      fi
    else
      reload_rev_proxy
    fi
    open_app
  fi
}

get_magento_cmds_to_update_hostname_to() {
  local hostname="$1"
  echo "
    bin/magento app:config:import
    bin/magento config:set web/unsecure/base_url https://$hostname/
    bin/magento config:set web/secure/base_url https://$hostname/
    bin/magento cache:flush
  "
}

get_project_and_env_from_mc_url() {
  local url="$1" project env
  project="$(get_project_from_mc_url "$url")"
  [[ "$project" ]] || error "$url not recognized as a valid Magento Cloud url from the Magento Cloud projects page
(ex. https://<region>.magento.cloud/projects/<projectid>/environments/<envid>)."
  env="$(get_env_from_mc_url "$url")"
  [[ "$env" ]] || env="master"
  echo "$project $env"
}

get_pwa_hostname() {
  [[ "$mdm_domain" ]] && echo "pwa.$mdm_domain" || echo "pwa"
}

get_pwa_prev_hostname() {
  [[ "$mdm_domain" ]] && echo "pwa-prev.$mdm_domain" || echo "pwa-prev"
}

# get_MAGENTO_CLOUD_vars_as_json() {
#   perl -MMIME::Base64 -ne '/(MAGENTO_CLOUD_.*?)=(.*)/ and print "\"$1\":".decode_base64($2).",\n"' \
#     "$apps_resources_dir/app/.docker/config.env" | perl -0777 -pe 's/^/{/;s/.$/}/;'
# }

set_MAGENTO_CLOUD_vars_json_to_env() {
  jq -r 'to_entries|map("\(.key)=\(.value|tostring|@base64)")|.[]'
}

export_pwa_hostnames() {
  PWA_HOSTNAME="$(get_pwa_hostname)"
  PWA_PREV_HOSTNAME="$(get_pwa_prev_hostname)"
  export PWA_HOSTNAME PWA_PREV_HOSTNAME
}

find_bridged_docker_networks() {
  docker network ls -q --filter 'driver=bridge' --filter 'name=_default'
}

network_has_running_web_service() {
  [[ "$(docker ps --filter "network=$1" \
    --filter "label=com.docker.compose.service=web" --format "{{.Ports}}")" =~ \-\>80 ]]
}

find_varnish_port_by_network() {
  docker ps -a --filter "network=$1" \
    --filter "label=com.docker.compose.service=varnish" --format "{{.Ports}}" | \
    sed 's/.*://;s/-.*//'
}

find_running_app_hostname_by_network() {
  local cid resources_dir
  cid="$(docker ps --filter "network=$1" --filter "label=com.docker.compose.service=fpm" --format "{{.ID}}")"
  [[ "$cid" ]] || return 0
  docker exec "$cid" bash -c 'bin/magento config:show "web/secure/base_url"' | perl -pe 's#^.*//(.*)/#$1#'
}

find_mdm_hostnames() {
  local hostnames hostname networks network
  hostnames="$(get_pwa_hostname) $(get_pwa_prev_hostname)"
  networks="$(find_bridged_docker_networks)"
  for network in $networks; do
    hostname="$(find_running_app_hostname_by_network "$network")"
    [[ -n "$hostname" ]] && hostnames+=" $hostname"
  done
  echo "$hostnames"
}

find_hostnames_not_resolving_to_local() {
  local hostname hostnames="$*" hostnames_not_resolving_to_local=""
  for hostname in $hostnames; do
    ! is_hostname_resolving_to_local "$hostname" && hostnames_not_resolving_to_local+=" $hostname"
  done
  echo "$hostnames_not_resolving_to_local"
}

backup_hosts() {
  [[ -d "$hosts_backup_dir" ]] || {
    warning "Creating hosts back up dir - should only need to do this if MDM install was skipped (e.g. testing/development)"
    mkdir -p "$hosts_backup_dir"
  }
  cp /etc/hosts "$hosts_backup_dir/hosts.$(date "+%s")"
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
    [[ "$cert" =~ DNS:\*$domain ]] && return 0
  else
    wildcard_domain="$(wildcard_domain_for_hostname "$1")"
    [[ "$cert" =~ DNS:.*$domain || "$cert" =~ DNS:\*$wildcard_domain ]] && return 0
  fi
  return 1
}

is_new_cert_required_for_domain() {
  ! { does_cert_and_key_exist_for_domain "$1" && is_cert_current_for_domain "$1" && 
    does_cert_follow_convention "$1" && ! is_cert_for_domain_expiring_soon "$1"; }
}

# accept any public or private github.com or raw.githubusercontent.com url
# but for consistency retrieve from github api 
# where token (if needed) will be passed as header and not url get param
get_github_file_contents() {
  local url="$1" org repo ref path token
  read -r org repo ref path <<<"$(
    echo "$url" | perl -pe 's/
    ^https?:\/\/[^\/]+\/
    (?<org>[^\/]+)\/
    (?<repo>[^\/]+)\/
    (blob\/)?
    (?<ref>[^\/]+)\/
    (?<path>[^\?\$]+)
    .*
    /$+{org} $+{repo} $+{ref} $+{path}/x'
  )"
  token="$(get_github_token_from_composer_auth)"
  url="https://api.github.com/repos/$org/$repo/contents/$path?ref=${ref:-master}"
  [[ "$token" ]] && token=("-H" "Authorization: token $token")
  curl --fail -sL -H 'Accept: application/vnd.github.v3.raw' "${token[@]}" "$url"
}

get_wildcard_cert_and_key_for_mdm_domain() {
  is_new_cert_required_for_domain ".$mdm_domain" || return 0
  cert_dir="$certs_dir/.$mdm_domain"
  mkdir -p "$cert_dir"
  get_github_file_contents "$mdm_domain_fullchain_gh_url" > "$cert_dir/fullchain1.pem"
  get_github_file_contents "$mdm_domain_privkey_gh_url" > "$cert_dir/privkey1.pem"
}

mkcert_for_domain() {
  local domain="$1" cert_dir="$certs_dir/$1" 
  is_valid_hostname "$domain" || error "Invalid name '$domain'"
  mkdir -p "$cert_dir"
  mkcert -cert-file "$cert_dir/fullchain1.pem" -key-file "$cert_dir/privkey1.pem" "$domain"
}

cp_wildcard_mdm_domain_cert_and_key_for_subdomain() {
  local subdomain="$1" num_parts_mdm_domain num_parts_subdomain

  # verify immediate subdomain (not subdomain of subdomain)
  num_parts_mdm_domain="$(echo "$mdm_domain" | tr -cd "." | wc -c)" # count dots
  num_parts_subdomain="$(echo "$subdomain" | tr -cd "." | wc -c)" # count dots
  [[ "$subdomain" =~ "$mdm_domain"$ && "$num_parts_subdomain" -eq "$(( "$num_parts_mdm_domain" + 1 ))" ]] || return 1

  is_new_cert_required_for_domain "$subdomain" || return 0 # still valid
  is_new_cert_required_for_domain ".$mdm_domain" && get_wildcard_cert_and_key_for_mdm_domain
  rsync -az "$certs_dir/.$mdm_domain/" "$certs_dir/$subdomain/"
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
  elif is_interactive_terminal || is_CI; then
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
  [[ "$MDM_DIRECT_HANDLER_CALL" ]] && return 1
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
# enable debugging and print env EXCEPT for interactive shell
# TODO - why is shell prompt not showing while in debug mode
[[ \"$debug\" && \"$caller\" != \"start_mdm_shell\" ]] && echo \"\$(env | $sort_cmd)\" && set -x
printf '\e[8;45;180t' # terminal size
$lib_dir/launcher $caller
" > "$script"
  chmod u+x "$script"
  open -a Terminal "$script"
  # open -F -n -a Terminal "$script"
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
  local pid_to_wait_for msg job_file exit_code=0
  pid_to_wait_for="$1"

  if [[ -z "$apps_mdm_jobs_dir" ]]; then 
    # shouldn't be here unless testing from $MDM_REPO_DIR
    [[ "$MDM_REPO_DIR" ]] || error "MDM_REPO_DIR and apps_mdm_jobs_dir are undefined"
    wait "$pid_to_wait_for" # wait but don't track b/c no app's mdm job dir to associate job to
  else
    msg="$2"
    job_file="$apps_mdm_jobs_dir/$(date +"%s").$pid_to_wait_for"
    echo "$msg" > "$job_file"
    wait "$pid_to_wait_for" || exit_code=$?
    mv "$job_file" "$job_file.$(date +"%s").$exit_code.done"
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
    while ! is_docker_running; do
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

find_non_default_networks() {
  docker network ls --format '{{.Name}}' | perl -ne 'print unless /^(bridge|host|none)$/'
}

reload_rev_proxy() {
  # shellcheck source=nginx-rev-proxy-setup.sh
  source "$lib_dir/nginx-rev-proxy-setup.sh"
}

download_and_link_repo_ref() {
  local ref ref_dir
  ref="${1:-$(lookup_latest_remote_sem_ver)}" # if unset or empty string, lookup latest sem ver
  ref_dir="$mdm_path/$ref"
  mkdir -p "$ref_dir"
  curl -sLO "$repo_url/archive/$ref.tar.gz"
  tar -zxf "$ref.tar.gz" --strip-components 1 -C "$ref_dir"
  rm "$ref.tar.gz" # cleanup
  # if not a link, preserve contents just in case - should only happen to dev that has rsynced to current
  [[ -d "$mdm_path/current" && ! -L "$mdm_path/current" ]] && mv "$mdm_path/current" "$mdm_path/current.$(date "+%s")"
  ln -sfn "$ref_dir" "$mdm_path/current"
  [[ -d "$mdm_path/current" ]] && rsync -az "$mdm_path/current/certs/" "$mdm_path/certs/" || : # cp over any new certs if the exist
}

# "-" dashes must be stripped out of COMPOSE_PROJECT_NAME prior to docker-compose 1.21.0 https://docs.docker.com/compose/release-notes/#1210
adjust_compose_project_name_for_docker_compose_version() {
  local docker_compose_ver more_recent_of_two
  docker_compose_ver="$(docker-compose -v | perl -ne 's/.*\b(\d+\.\d+\.\d+).*/$1/ and print')"
  more_recent_of_two="$(printf "%s\n%s" 1.21.0 "$docker_compose_ver" | "$sort_cmd" -V | tail -1)"
  if [[ "$more_recent_of_two" != "$docker_compose_ver" ]]; then
    echo "$1" | perl -pe 's/[\-\.]//g' # strip dashes and dots if 1.21.0 is more recent
  else
    echo "$1" | perl -pe 's/\.//g' # only strip dots
  fi
}

get_compose_project_name() {
  local name
  name="$(perl -ne 's/COMPOSE_PROJECT_NAME=(.*)/$1/ and print $1' "$apps_resources_dir/$rel_app_config_file")"
  [[ "$name" ]] || error "Can not get COMPOSE_PROJECT_NAME."
  printf "%s" "$name"
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

get_docker_compose_runtime_services() {
  # get only runtime services build and deploy restarts may be interfering; tls and generic are unused

  # this method relies on python but issue arose if pyyaml not found
  # docker-compose config |
  #   python -c "import sys, yaml; data=yaml.load(sys.stdin); print(' '.join(data['services'].keys()))" |
  #   perl -pe 's/build|deploy|generic|tls//g'

  # this method has no reliance on python, but assumes each service is 1 indentation level of 2 spaces
  # that should be a fair assumption since the output is generated by docker-compose config

  # docker-compose config |
  # perl -0777 -ne '/services:[\n]*\n(.*?)\n\w/s and print $1'

  # the above method using docker-compose is a bit too slow for menu rendering, but since the primary docker-compose.yml
  # should contain all the services this should be fine
  perl -0777 -ne '/services:[\n]*\n(.*?)\n\w/s and print $1' "$apps_resources_dir/app/docker-compose.yml" | # all of top level services key
    perl -ne '/^  (\w.*):/ and print "$1 "' | # just service names
    perl -pe 's/\b(build|deploy|generic|tls)\b\s*//g;s/^\s*//;s/\s*$//' # remove non runtime services
}

# mount:upload|download lists ALL files; just list the top level dirs and MB xferred
filter_cloud_mount_transfer_output() {
  perl -ne 'BEGIN{ $| = 1; } /^[^\s]/ and print;/\s+[^\/]+\/$/ and print;/^\s+(total|sent) / and print'
}


# if come across entry with no handler or link, entering submenu
render_platypus_status_menu() {
  local index key key_length menu_output is_submenu highlight_func highlight_text tmp_output
  key_length=${#mdm_menu_items_keys[@]}
  menu_output=""
  is_submenu=""
  # based on Platypus menu syntax, submenu headers are not seletctable so no handler or link entry (unlike actual submenu items)
  for (( index=0; index < key_length; index++ )); do
    key="${mdm_menu_items_keys[$index]}"
    if [[ "$key" = "end submenu" ]]; then
      [[ "$is_submenu" ]] && {
        is_submenu=""
        launched_from_mac_menu_cached && menu_output+=$'\n'
        continue
      }
    fi
    # no handler or link? must be a submenu heading
    [[ -z "${mdm_menu_items["$key-handler"]}" && -z "${mdm_menu_items["$key-link"]}" ]] && {
      tmp_output=""
      # if menu has some output already & if a submenu heading, was the last char a newline? if not, add one to start new submenu
      [[ -n "$menu_output" && ! "$menu_output" =~ $'\n'$ ]] && tmp_output=$'\n'
      if launched_from_mac_menu_cached; then
        menu_output+="${tmp_output}SUBMENU|$key"
      else
        menu_output+="$tmp_output$key"$'\n'
      fi
      is_submenu=true
      continue
    }
    [[ "${mdm_menu_items["$key-disabled"]}" ]] && menu_output+="DISABLED|"
    # status menu at top of menu case - needs newline
    if [[ "$key" =~ ^DISABLED && "$key" =~ ---$ ]]; then
      menu_output+="$key"$'\n'
    else
      if launched_from_mac_menu_cached; then
        # OSX menu output
        if [[ "$is_submenu" ]]; then
          menu_output+="|$key"
        else
          menu_output+="$key"$'\n'
        fi
      else
        # CLI output
        tmp_output=""
        [[ "$is_submenu" ]] && tmp_output="   " # indent
        highlight_func="msg"
        highlight_text="${mdm_menu_items["$key-link"]}"
        [[ "${mdm_menu_items["$key-handler"]}" ]] && {
          highlight_func="warning"
          highlight_text="${mdm_menu_items["$key-handler"]}"
        }
        menu_output+="$tmp_output$key $($highlight_func "$highlight_text")"$'\n'
      fi
    fi
  done
  printf "%s" "$menu_output"
}

handle_mdm_args() {
  local key value len remaining_args=()
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
      export MDM_DIRECT_HANDLER_CALL="true"
      # BASH_ARGV has all parameters in the current bash execution call stack
      # the final parameter of the last subroutine call is first in the queue
      # the first parameter of the initial call is last
      # in this case, the sourced bin/mdm is first and the last element is the directly called handler
      # so remove the first and last and reverse the middle (whew!)
      len=$(( ${#BASH_ARGV[*]} - 2 ))
      reverse_array BASH_ARGV remaining_args
      "$mdm_first_arg" "${remaining_args[@]:1:$len}"
      exit
    }
  done

  error "Handler for $mdm_first_arg was not found or valid in this context."

}

ensure_mdm_log_files_exist() {
  [[ -f "$menu_log_file" ]] && return 0
  mkdir -p "$mdm_path"
  touch "$menu_log_file" "$handler_log_file" "$dockerize_log_file"
}

run_bundled_app_as_script() {
  [[ "$apps_resources_dir" ]] || error "App's resources dir not set"
  local script_arg="$1"
  # invoke in the same way platypus would
  if is_mac; then
    /usr/bin/env -P "/usr/local/bin:/bin" bash -c "$apps_resources_dir/script $script_arg"
  else
    /usr/bin/env bash -c "debug=1; set -x; env; $apps_resources_dir/script $script_arg"
  fi
}

init_specific_app() {
  # export vars that may be used in a non-child terminal script so when lib is sourced, vars are defined
  export_pwa_hostnames
  export_compose_project_name
  export_compose_file
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

init_mac_quit_detection() {
  # quit detection is only relevant to the mac gui app (not mac testing or cmd line usage), so return if not launched from mac menu
  launched_from_mac_menu_cached || return 0

  local quit_detection_file="$apps_mdm_dir/.$PPID-still_running"
  # if quit_detection_file does not exist, this is either the 1st start or it was removed when quit
  [[ ! -f "$quit_detection_file" ]] && {
    touch "$quit_detection_file"
    {
      # while the Platyplus app exists ($PPID), do nothing
      while ps -p $PPID > /dev/null 2>&1; do
        sleep 10
      done

      # parent pid now gone, so remove file and stop dockerized magento
      rm "$quit_detection_file" || :
      docker-compose stop
    } >> "$handler_log_file" 2>&1 & # must background & disconnect STDIN & STDOUT for Platypus to exit
  } || :

}

###
#
# initialization logic
#
##

ensure_mdm_log_files_exist

# the mdm config enables additional features
# a dockerized app will include an mdm config file but in CI testing, it will not exist 
# but an env var may exists to download it
download_mdm_config() {
    # assume a github url as will be recommended but try a normal curl if it fails
    get_github_file_contents "$MDM_CONFIG_URL" > "$mdm_config_file" ||
      curl --fail -sL "$MDM_CONFIG_URL" > "$mdm_config_file"
}

self_install() {
  local brew_pkgs_for_mac=("bash" "coreutils" "jq") brew_pkgs_for_all_platforms=("mkcert" "nss")
  is_interactive_terminal && printf '\e[8;50;140t' # resize terminal

  # on linux, some services require a min virtual memory map count and may need to be raised
  # https://devdocs.magento.com/cloud/docker/docker-containers-service.html#troubleshooting
  ! is_mac && [[ "$(sysctl vm.max_map_count | perl -pe 's/.*=\s*//')" -lt 262144 ]] && {
    sudo sysctl -w vm.max_map_count=262144 > /dev/null 2>&1
  }

  # create expected directory structure
  mkdir -p "$launched_apps_dir" "$certs_dir" "$hosts_backup_dir"
  
  # determine which MDM version to install and what MDM config to use 
  if [[ "$MDM_REPO_DIR" ]]; then # dev's env or mdm is checked out for another project
    rsync --cvs-exclude --delete -az "$MDM_REPO_DIR/" "$mdm_path/repo/"
    ln -sfn "$mdm_path/repo/" "$mdm_path/current"
    [[ -f "$MDM_REPO_DIR/.mdm_config.sh" ]] && cp "$MDM_REPO_DIR/.mdm_config.sh" "$mdm_config_file"
    [[ ! -f "$mdm_config_file" && "$MDM_CONFIG_URL" ]] && download_mdm_config
  elif [[ "$GITHUB_REPOSITORY" = "PMET-public/mdm" ]]; then # mdm is testing itself
    download_and_link_repo_ref "$GITHUB_SHA"
    [[ "$MDM_CONFIG_URL" ]] && download_mdm_config
  else # end user, config should already be copied from launcher
    download_and_link_repo_ref # no param = latest sem ver
  fi

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
    ! brew list "${brew_pkgs_for_mac[@]}" > /dev/null 2>&1 && {
      brew install "${brew_pkgs_for_mac[@]}"
    }
    brew upgrade "${brew_pkgs_for_mac[@]}"

    [[ -d /Applications/Docker.app ]] || {
      msg_w_newlines "
    Press ANY key to continue to the Docker Desktop For Mac download page. Then download and install that app.

    $docker_install_link
  "
      ! is_CI && read -n 1 -s -r -p ""
      # open docker for mac installation page
      open "$docker_install_link"
    }

    msg_w_newlines "CLI dependencies successfully installed. Once you download and install Docker Desktop for Mac, this script should not run again."

  fi

  # needed by multiple platforms
  # install mkcert but do not install CA generated by mkcert without explicit user interaction
  # nss is required by mkcert to install Firefox trust store
  ! brew list "${brew_pkgs_for_all_platforms[@]}" > /dev/null && {
    brew install "${brew_pkgs_for_all_platforms[@]}"
  }
  brew upgrade "${brew_pkgs_for_all_platforms[@]}"

  msg_w_newlines "You may close this terminal."
}

self_uninstall() {
  # 2nd file test to ensure mdm_path is set correctly before rm -rf to avoid deleting unintended dir
  [[ -d "$mdm_path" && -f "$mdm_path/current/bin/lib.sh" ]] && rm -rf "$mdm_path" || :
}

lib_sourced_for_specific_bundled_app && {
  init_specific_app
  [[ "$debug" ]] && init_mdm_logging
  ! is_detached && is_mac && ! is_CI && init_mac_quit_detection
}

: # need to return true or will exit when sourced with "-e" and last test = false
