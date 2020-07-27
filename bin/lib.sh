#!/bin/bash
set -e

# don't trap errors while using VSC debugger
[[ $VSCODE_PID ]] || {
  set -E # If set, the ERR trap is inherited by shell functions.
  trap 'error "Env @ error:

$(env | sort)

Command $BASH_COMMAND on line $LINENO failed with exit code $?."' ERR
}

# this lib is used by dockerize, mdm, tests, etc. but logging to STDOUT is problematic for platypus apps
# so need a way to check and if appropiate, defer until lib can bootstrap the appropiate logging
included_by_mdm() {
  # shellcheck disable=SC2199 # error in shellcheck? implicit array concatenation - which is desired plus = vs =~
  [[ "${BASH_SOURCE[@]}" =~ /bin/mdm ]]
}

[[ $debug ]] && ! included_by_mdm && set -x

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
mdm_path="$HOME/.mdm"
mdm_version="${lib_dir#$mdm_path/}" && mdm_version="${mdm_version%/bin}" && [[ $mdm_version =~ ^[0-9.]*$ ]] || mdm_version="dev?"
menu_log_file="$mdm_path/current/menu.log"
handler_log_file="$mdm_path/current/handler.log"
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[1;33m'
no_color='\033[0m'
recommended_vm_cpu=4
recommended_vm_mem_mb=4096
recommended_vm_swap_mb=2048
recommended_vm_disk_mb=64000
bytes_in_mb=1048576
docker_settings_file="$HOME/Library/Group Containers/group.com.docker/settings.json"
repo_url="https://github.com/PMET-public/mdm"
advanced_mode_flag_file="$mdm_path/advanced_mode_on"
mdm_ver_file="$mdm_path/latest-sem-ver"
detached_project_name="detached-mdm"

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
  [[ "$(find "$apps_mdm_dir/jobs" -type f -not -name "*.cleared" -print -quit)" ]]
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

are_additional_tools_installed() {
  is_mac && is_magento_cloud_cli_installed || return
  is_docker_compatible && is_docker_bash_completion_installed || return
  is_mac && is_platypus_installed || return
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

is_CI() {
  [[ $GITHUB_WORKSPACE || $TRAVIS ]]
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
  pgrep -q com.docker.hyperkit
}

is_docker_ready() {
  docker ps > /dev/null 2>&1
}

is_docker_ready && formatted_cached_docker_ps_output="$(
  docker ps -a -f "label=com.docker.compose.service=db" --format "{{.Names}} {{.Status}}" | \
    perl -pe 's/ (Up|Exited) .*/ \1/'
)"

is_onedrive_linked() {
  [[ -d "$HOME/Adobe Systems Incorporated/SITeam - docker" ]] ||
    [[ -d "$HOME/Adobe/SITeam - docker" ]]
}

is_detached() {
  [[ ! -d "$apps_resources_dir/app" ]]
}

is_app_installed() {
  is_detached && return 1
  # grep once and store result in var
  [[ -n "$app_is_installed" ]] ||
    {
      echo "$formatted_cached_docker_ps_output" | grep -q "^${COMPOSE_PROJECT_NAME}_db_1 "
      app_is_installed=$?
    }
  return "$app_is_installed"
}

is_app_running() {
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
  # it can be difficult to determine whether mdm was called without args to display the menu or invoke a selected menu item.
  # bash5 on mac and bash4 on linux report BASH_ARGC differently. the vsc debugger wraps the call in other args.
  # so modify this carefully.
  # for debugging, bash vscode debugger changes normal invocation, so check for a special var 
  if [[ "$vsc_debugger_arg" == "n/a" ]]; then
    return 0
  elif [[ -n "$vsc_debugger_arg" ]]; then
    mdm_input="$vsc_debugger_arg"
    return 1
  elif [[ ${BASH_ARGV[-1]} =~ /bin/mdm$ ]]; then
    return 0
  else
    mdm_input="${BASH_ARGV[-1]}"
    return 1
  fi
}

# need way to distinguish being sourced for specific app or sourced for some other script (e.g. dockerize script)
lib_sourced_for_specific_bundled_app() {
  # if a specific apps_resources_dir is already set in the env, then lib was sourced for a specific app
  if [[ $apps_resources_dir ]]; then
    # check that the dir was properly specified
    [[ ! -d $apps_resources_dir ]] && error "Exiting because $apps_resources_dir does not exist."
    # it exists - return pass
    return 0
  fi
  # else is the sourcing process a specific app instance?
  local parent_pids_path
  parent_pids_path="$(ps -p $PPID -o command=)"
  [[ "$parent_pids_path" =~ .app/Contents/MacOS/ ]] &&
    apps_resources_dir="${parent_pids_path/\/MacOS\/*/\/Resources}" &&
    export apps_resources_dir
}

lookup_latest_remote_sem_ver() {
  curl -svL "$repo_url/releases" | \
    perl -ne 'BEGIN{undef $/;} /archive\/([\d.]+)\.tar\.gz/ and print $1'
}

is_update_available() {
  # check for a new version once a day (86400 secs)
  local more_recent_of_two
  if [[ -f "$mdm_ver_file" && "$(( $($date_cmd +%s) - $($stat_cmd -c%Z "$mdm_ver_file") ))" -lt 86400 ]]; then
    local latest_sem_ver
    latest_sem_ver="$(<"$mdm_ver_file")"
    [[ "$mdm_version" == "$latest_sem_ver" ]] && return 1
    # verify latest is more recent using sort -V
    more_recent_of_two="$(printf "%s\n%s" "$mdm_version" "$latest_sem_ver" | $sort_cmd -V | tail -1)"
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

is_hostname_curlable() {
  ! curl -I "http://$1" 2>&1 | grep -q illegal
}

is_valid_git_url() {
  [[ "$1" =~ http.*\.git ]] || [[ "$1" =~ git.*\.git ]]
}

is_existing_cloud_env() {
  [[ $env_is_existing_cloud ]]
}

is_hostname_resolving_to_local() {
  curl -vI "$1" 2>&1 | grep -q 127.0.0.1
}

is_interactive() {
  [[ $- == *i* ]]
}

is_running_as_sudo() {
  env | grep -q 'SUDO_USER='
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

if is_mac; then
  # use homebrew's core utils
  stat_cmd="gstat"
  sort_cmd="gsort"
  date_cmd="gdate"
else
  stat_cmd="stat"
  sort_cmd="sort"
  date_cmd="date"
  # on linux, some services require a min virtual memory map count and may need to be raised
  # https://devdocs.magento.com/cloud/docker/docker-containers-service.html#troubleshooting
  [[ $(sysctl vm.max_map_count | perl -pe 's/.*=\s*//') -lt 262144 ]] && {
    sudo sysctl -w vm.max_map_count=262144
  }
fi

error() {
  printf "\n[%s] %b%s%b\n\n" "$($date_cmd --utc +"%Y-%m-%d %H:%M:%S")" "$red" "Error: $*" "$no_color" 1>&2 && exit 1
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
  msg "[$($date_cmd -u +%FT%TZ)] $*"
}

convert_secs_to_hms() {
  h="$(($1/3600))"
  m="$((($1%3600)/60))"
  s="$(($1%60))"
  printf "%02d:%02d:%02d" "$h" "$m" "$s"
}

seconds_since() {
  echo "$(( $($date_cmd +%s) - $1 ))"
}

confirm_or_exit() {
  warning "

ARE YOU SURE?! (y/n)

"
  read -p ''
  [[ $REPLY =~ ^[Yy]$ ]] || {
    msg_w_newlines "Exiting unchanged." && exit
  }
}

###
#
# end util functions
#
###

normalize_hostname() {
  # convert user supplied name to a curlable one if possible
  curl -sv -I "http://$1" 2>&1 >/dev/null | \
    perl -ne 's/to connect to\s+([^\s]+)// and print "$1"; s/.*host:\s*//i and print'
}

get_host() {
  [[ -f "$apps_resources_dir/app/docker-compose.yml" ]] &&
    perl -ne 's/.*VIRTUAL_HOST=\s*(.*)\s*/\1/ and print' "$apps_resources_dir/app/docker-compose.yml" ||
    error "Host not found"
}

# this function enables menu item handlers to be run in a new interactive terminal
# it also allows a menu item to invoke another similar to a user selecting a menu option themself (via the launcher)
run_this_menu_item_handler_in_new_terminal() {
  local caller script
  [[ ! $MDM_DIRECT_HANDLER_CALL ]] && {
    caller="$(echo "${FUNCNAME[*]}" | sed 's/.*run_this_menu_item_handler_in_new_terminal //; s/ .*//')"
    script=$(mktemp -t "$COMPOSE_PROJECT_NAME-$caller") || exit
    echo "#!/usr/bin/env bash -l
export REPO_DIR=\"${REPO_DIR}\"
export apps_resources_dir=\"$apps_resources_dir\"
$lib_dir/launcher $caller
" > "$script"
    chmod u+x "$script"
    open -a Terminal "$script"
  } || :
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
  msg="$2"
  job_file="$apps_mdm_dir/jobs/$($date_cmd +%s).$pid_to_wait_for"
  echo "$msg" > "$job_file"
  wait "$pid_to_wait_for" || exit_code=$?
  mv "$job_file" "$job_file.$($date_cmd +%s).$exit_code.done"
}

extract_tar_to_docker() {
  # extract tar to tmp dir then stream to docker build container
  # N.B. `tar -xf some.tar -O` is stream of file _contents_; `tar -cf -` is tar formatted stream (handles metadata)
  local src_tar container_dest tmp_dir
  src_tar="$1"
  container_dest="$2"
  tmp_dir="$(mktemp -d)"
  tar -zxf "$src_tar" -C "$tmp_dir"
  tar -cf - -C "$tmp_dir" . | docker cp - "$container_dest"
  rm -rf "$tmp_dir"
}

restart_docker_and_wait() {
  osascript -e 'quit app "Docker"'
  open --background -a Docker
  while ! is_docker_ready; do
    sleep 2
  done
}

reload_rev_proxy() {
  # shellcheck source=nginx-rev-proxy-setup.sh
  source "$lib_dir/nginx-rev-proxy-setup.sh"
}

download_and_link_latest_release() {
  local latest_release_ver
  latest_release_ver=$(lookup_latest_remote_sem_ver)
  cd "$mdm_path"
  curl -svLO "$repo_url/archive/$latest_release_ver.tar.gz"
  mkdir -p "$latest_release_ver"
  tar -zxf "$latest_release_ver.tar.gz" --strip-components 1 -C "$latest_release_ver"
  rm "$latest_release_ver.tar.gz" current || : # cleanup and remove old link
  ln -sf "$latest_release_ver" current
}

export_compose_project_name() {
  # if already set, skip
  [[ $COMPOSE_PROJECT_NAME ]] && return
  # "-" dashes must be stripped out of COMPOSE_PROJECT_NAME prior to docker-compose 1.21.0 https://docs.docker.com/compose/release-notes/#1210
  local docker_compose_ver more_recent_of_two
  docker_compose_ver="$(docker-compose -v | perl -ne 's/.*\b(\d+\.\d+\.\d+).*/\1/ and print')"
  more_recent_of_two="$(printf "%s\n%s" 1.21.0 "$docker_compose_ver" | $sort_cmd -V | tail -1)"
  COMPOSE_PROJECT_NAME="$(perl -ne 's/.*VIRTUAL_HOST=([^.]*).*/\1/ and print' "$apps_resources_dir/app/docker-compose.yml")"
  # now strip dashes if 1.21.0 is more recent
  if [[ $more_recent_of_two != $docker_compose_ver ]]; then
    COMPOSE_PROJECT_NAME="$(echo $COMPOSE_PROJECT_NAME | perl -pe 's/-//g')"
  fi
  export COMPOSE_PROJECT_NAME
}

export_compose_file() {
  export COMPOSE_FILE="$apps_resources_dir/app/docker-compose.yml"
  # check for a CWD override file
  [[ -f "$apps_resources_dir/docker-compose.override.yml" ]] && {
    COMPOSE_FILE+=":$apps_resources_dir/app/docker-compose.override.yml"
  }
  # also use the global override file included with MDM
  [[  -f "$lib_dir/../docker-files/mcd.override.yml" ]] && {
    COMPOSE_FILE+=":$lib_dir/../docker-files/mcd.override.yml"
  }
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
  local key key_length menu_output is_submenu
  key_length=${#keys[@]}
  menu_output=""
  is_submenu=false
  # based on Platypus menu syntax, submenu headers are not seletctable so no handler or link entry unlike actual submenu items
  for (( index=0; index < key_length; index++ )); do
    key="${keys[$index]}"
    if [[ $key = "end submenu" ]]; then
      $is_submenu && {
        is_submenu=false
        menu_output+=$'\n'
        continue
      }
    fi
    # no handler or link? must be a submenu heading
    [[ -z "${menu["$key-handler"]}" && -z "${menu["$key-link"]}" ]] && {
      # if menu has some output already & if a submenu heading, was the last char a newline? if not, add one to start new submenu
      [[ -n $menu_output && ! $menu_output =~ $'\n'$ ]] && menu_output+=$'\n'
      menu_output+="SUBMENU|$key"
      is_submenu=true
      continue
    }
    [[ ${menu["$key-disabled"]} ]] && menu_output+="DISABLED|"
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

handle_mdm_input() {
  local key value
  # if selected menu item matches an exit timer, clear exit timer status and exit
  [[ "$mdm_input" =~ [0-9]{2}:[0-9]{2}:[0-9]{2} ]] && clear_status && exit
  
  # otherwise check what type of menu item was selected

  # a handler?
  key="$mdm_input-handler"
  [[ -n "${menu[$key]}" ]] && {
    "${menu[$key]}"
    exit
  }

  # a link?
  key="$mdm_input-link"
  [[ -n "${menu[$key]}" ]] && {
    open "${menu[$key]}"
    exit
  }

  # not a handler or a link key? look for direct call (useful for testing)
  for value in "${menu[@]}"; do
    [[ "$mdm_input" = "$value" ]] && {
      export MDM_DIRECT_HANDLER_CALL=true
      # msg_w_newlines "$mdm_input found in current menu. Running ..."
      "$mdm_input"
      exit
    }
  done

  error "Handler for $mdm_input was not found or valid in this context."

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
  if is_detached; then
    env_dir="$launched_apps_dir/standalone"
  else
    cd "$apps_resources_dir/app"
    # export vars that may be used in a non-child terminal script so when lib is sourced, vars are defined
    export_compose_project_name
    export_compose_file
    export_image_vars_for_override_yml
    [[ -n "$COMPOSE_PROJECT_NAME" ]] || error "Could not find COMPOSE_PROJECT_NAME"
    env_dir="$mdm_path/envs/$COMPOSE_PROJECT_NAME"
  fi
  mkdir -p "$env_dir"
  status_msg_file="$env_dir/.status"
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
  quit_detection_file="$env_dir/.$PPID-still_running"
  # if quit_detection_file does not exist, this is either the 1st start or it was removed when quit
  # also ensure log files exist
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

lib_sourced_for_specific_bundled_app && {
  ensure_mdm_log_files_exist
  init_app_specific_vars
  [[ $debug ]] && init_mdm_logging
  ! is_detached && init_quit_detection
}

: # need to return true or will exit when sourced with "-e" and last test = false
