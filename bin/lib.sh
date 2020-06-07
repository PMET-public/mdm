#!/bin/bash
set -e

# this lib is used by dockerize, mdm, tests, etc. but logging to STDOUT is problematic for platypus apps
# so need a way to check and if appropiate, defer until lib can bootstrap the appropiate logging
included_by_mdm() {
  # misidentification by shellcheck? implicit array concatenation - which is desired plus = vs =~
  # shellcheck disable=SC2199
  [[ "${BASH_SOURCE[@]}" =~ /bin/mdm ]]
}

[[ $debug ]] && ! included_by_mdm && set -x

# establish $lib_dir for reference
# N.B. when to use $resource_dir (references a specific platypus app instance) vs $lib_dir:
# $lib_dir (the dir containing this file) should be used unless a specific running platypus app instance or 
# its resources from $resource_dir are required to complete successfully.
# this maximizes what can be used generically and from a shell

# iterate thru BASH_SOURCE to find this lib.sh (should work even when debugging in IDE)
bs_len=${#BASH_SOURCE[@]}
for (( index=0; index < bs_len; ((index++)) )); do
  [[ "${BASH_SOURCE[$index]}" =~ /lib.sh$ ]] && {
    lib_dir="$(dirname "${BASH_SOURCE[$index]}")"
    break
  }
done

###
#
# start constants
#
###

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

has_status_msg() {
  [[ -f "$status_msg_file" ]]
}

has_additional_tools() {
  [[ -f /usr/local/bin/composer && -f ~/.magento-cloud/bin/magento-cloud ]]
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

reload_rev_proxy() {
  verify_mdm_cert_dir
  # shellcheck source=nginx-rev-proxy-setup.sh
  source "$lib_dir/nginx-rev-proxy-setup.sh"
}

verify_mdm_cert_dir() {
  # search multiple paths including ones that may not exist causing a non-zero exit status
  mdm_cert_dir="$(find \
    $HOME/Adobe \
    $HOME/Adobe\ Systems\ Incorporated \
    -type d -path "*/certs/the1umastory.com" 2> /dev/null || :)"
  [[ -n $mdm_cert_dir ]] &&
    export mdm_cert_dir ||
    error "Could not find certs in expected location."
  [[ -r "$mdm_cert_dir/cert1.pem" ]] ||
    error "Can't read TLS certificates: $mdm_cert_dir/cert1.pem."
}

is_standalone() {
  [[ ! -d "$resource_dir/app" ]]
}

is_app_installed() {
  is_standalone && return 1
  # grep once and store result in var
  [[ -n "$app_is_installed" ]] ||
    {
      echo "$formatted_cached_docker_ps_output" | grep -q "^${COMPOSE_PROJECT_NAME}_db_1 "
      app_is_installed=$?
    }
  return "$app_is_installed"
}

is_app_running() {
  is_standalone && return 1
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
  # determining whether mdm was called without args to display the menu or invoke a selection is difficult.
  # bash5 on mac and bash4 on linux report BASH_ARGC differently. the vsc debugger wraps the call in other args.
  # modify carefully.
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

# need way to distinguish being called from app or other script sourcing this lib (e.g. dockerize script)
called_from_platypus_app() {
  # allow parent_pids_path to be set by the env to debug a specific instance
  # otherwise grab the actual exact path of the osx platypus app
  parent_pids_path="${parent_pids_path:-$(ps -p $PPID -o command=)}"
  [[ "$parent_pids_path" =~ .app/Contents/MacOS/ ]]
}

lookup_latest_remote_sem_ver() {
  curl -svL "$repo_url/releases" | \
    perl -ne 'BEGIN{undef $/;} /archive\/([\d.]+)\.tar\.gz/ and print $1'
}

is_update_available() {
  # check for a new version once a day (86400 secs)
  local more_recent_of_two stat_cmd sort_cmd
  if is_mac; then
    stat_cmd=gstat
    sort_cmd=gsort
  else
    stat_cmd=stat
    sort_cmd=sort
  fi
  if [[ -f "$mdm_ver_file" && "$(( $(date +%s) - $("$stat_cmd" -c%Z "$mdm_ver_file") ))" -lt 86400 ]]; then
    local latest_sem_ver
    latest_sem_ver="$(<"$mdm_ver_file")"
    [[ "$mdm_version" == "$latest_sem_ver" ]] && return 1
    # verify latest is more recent using gsort -V
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

error() {
  printf "\n%b%s%b\n\n" "$red" "$*" "$no_color" 1>&2 && exit 1
}

warning() {
  printf "%b%s%b" "$yellow" "$*" "$no_color"
}

msg() {
  printf "%b%s%b" "$green" "$*" "$no_color"
}

timestamp_msg() {
  echo "$(msg "[$(date -u +%FT%TZ)] $*")"
}

convert_secs_to_hms() {
  ((h=$1/3600))
  ((m=($1%3600)/60))
  ((s=$1%60))
  printf "%02d:%02d:%02d" "$h" "$m" "$s"
}

seconds_since() {
  echo "$(( $(date +%s) - $1 ))"
}

confirm_or_exit() {
  warning "

ARE YOU SURE?! (y/n)

"
  read -p ''
  [[ $REPLY =~ ^[Yy]$ ]] || {
    msg "Exiting unchanged." && exit
  }
}

###
#
# end util functions
#
###

get_host() {
  [[ -f "$resource_dir/app/docker-compose.yml" ]] &&
    perl -ne 's/.*VIRTUAL_HOST=\s*(.*)\s*/\1/ and print' "$resource_dir/app/docker-compose.yml" ||
    error "Host not found"
}

# echos pid of script as result
run_as_bash_script_in_terminal() {
  local script counter pid
  script=$(mktemp -t "$COMPOSE_PROJECT_NAME-${FUNCNAME[1]}") || exit
  echo "#!/usr/bin/env bash -l
set +x
unset BASH_XTRACEFD
unset debug
# set title of terminal
echo -n -e '\033]0;${FUNCNAME[1]} $COMPOSE_PROJECT_NAME\007'
# is this export still needed?  (old comment: by exporting this, additional debug configurations will work)
# export parent_pids_path=\"$parent_pids_path\"
clear
source \"$lib_dir/lib.sh\"
${*}
" > "$script"
  chmod u+x "$script"
  open -a Terminal "$script"
  # wait up to a brief time to return pid of script or false
  # exit status of pid will be unavailable b/c not a child job
  # but script could leave exit status artifact
  for (( counter=0; counter < 10; ((counter++)) )); do
    pid="$(pgrep -f "$script")"
    [[ -n "$pid" ]] && echo "$pid" && return
    sleep 0.5
  done
  return false
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

set_status_and_wait_for_exit() {
  local pid_to_wait_for status start exit_status_msg
  pid_to_wait_for="$1"
  status="$2"
  start="$(date +%s)"
  # using some UTF icon characters for status but not the rest of the menu (didn't like available options)
  echo "DISABLED|⏳ Please wait. $status" > "$status_msg_file"
  if wait "$pid_to_wait_for"; then
    exit_status_msg+="✅ Success. $status "
  else
    exit_status_msg+="❗Error! $status "
  fi
  exit_status_msg+="$(convert_secs_to_hms "$(seconds_since "$start")")"
  printf "%s" "$exit_status_msg" > "$status_msg_file"
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
  export COMPOSE_PROJECT_NAME
  COMPOSE_PROJECT_NAME="$(perl -ne 's/.*VIRTUAL_HOST=([^.]*).*/\1/ and print' "$resource_dir/app/docker-compose.yml")"
}

export_compose_file() {
  export COMPOSE_FILE="docker-compose.yml"
  # check for a CWD override file
  [[ -f docker-compose.override.yml ]] && {
    COMPOSE_FILE+=":docker-compose.override.yml"
  }
  # also use the global override file included with MDM
  [[  -f "$mdm_path/current/docker-files/mcd.override.yml" ]] && {
    COMPOSE_FILE+=":$mdm_path/current/docker-files/mcd.override.yml"
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

render_platypus_status_menu() {
  local key key_length menu_output is_submenu
  key_length=${#keys[@]}
  menu_output=""
  is_submenu=false
  # based on Platypus menu syntax, submenu headers can not have icons and they are not seletctable
  # (so they shouldn't have handler or link entries)
  # submenu items also can not have icons but need handlers
  for (( index=0; index < key_length; index++ )); do
    key="${keys[$index]}"
    # no handler or link? must be a submenu heading
    [[ -z "${menu["$key-handler"]}" && -z "${menu["$key-link"]}" ]] && {
      # if menu has some output already & if a submenu heading, was the last char a newline? if not, add one to start new submenu
      [[ -n $menu_output && ! $menu_output =~ $'\n'$ ]] && menu_output+=$'\n'
      menu_output+="SUBMENU|$key"
      is_submenu=true
      continue
    }
    # icon? starting a new top level menu item
    if [[ -n "${menu["$key-icon"]}" ]]; then
      $is_submenu && {
        is_submenu=false
        menu_output+=$'\n'
      }
      [[ ${menu["$key-disabled"]} ]] && menu_output+="DISABLED|"
      menu_output+="MENUITEMICON|$lib_dir/../icons/${menu["$key-icon"]}|$key"$'\n'
    # status menu at top of menu case - needs newline
    elif [[ "$key" =~ ^DISABLED && "$key" =~ ---$ ]]; then
      menu_output+="$key"$'\n'
    else
      menu_output+="|$key"
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
      msg "$mdm_input found in current menu. Running ...
"
      "$mdm_input"
      exit
    }
  done

  for value in "${testable_menu[@]}"; do
    [[ "$mdm_input" = "$value" ]] && {
      warning "$mdm_input NOT FOUND in current menu BUT is testable menu option. Running anyway ...
"
      "$mdm_input"
      exit
    }
  done

  error "Handler for $mdm_input was not found or valid in this context."

}

ensure_mdm_log_files_exist() {
  touch "$menu_log_file" "$handler_log_file"
}

init_app_specific_vars() {
  resource_dir="${parent_pids_path/\.app\/Contents\/MacOS\/*/}.app/Contents/Resources"
  if is_standalone; then
    env_dir="$mdm_path/envs/standalone"
  else
    cd "$resource_dir/app"
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
    timestamp_msg "Script called without args" >&2
  else 
    timestamp_msg "Script called with ${BASH_ARGV[-1]}" >&2
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
  }
}

###
#
# initialization logic
#
##

called_from_platypus_app && {
  ensure_mdm_log_files_exist
  init_app_specific_vars
  [[ $debug ]] && init_mdm_logging
  ! is_standalone && init_quit_detection
}

: # need to return true or will exit when sourced with "-e" and last test = false
