#!/bin/bash
set -e

# establish $lib_dir for reference
# N.B. when to use $resource_dir (references a specific platypus app instance) vs $lib_dir:
# $lib_dir (the dir containing this file) should be used unless a specific running platypus app instance or 
# its resources from $resource_dir are required to complete successfully.
# this maximizes what can be tested generically and from a shell

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

mdm_version=0.0.21
mdm_path="$HOME/.mdm"
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[1;33m'
no_color='\033[0m'
recommended_vm_cpu=4
recommended_vm_mem_mb=4096
recommended_vm_swap_mb=2048
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

is_docker_installed() {
  [[ -f "$docker_settings_file" ]]
}

is_docker_suboptimal() {
  can_optimize_vm_cpus || can_optimize_vm_mem || can_optimize_vm_swap
}

is_docker_running() {
  pgrep -q com.docker.hyperkit
}

is_docker_ready() {
  docker ps > /dev/null 2>&1
}

is_docker_ready && formatted_cached_docker_ps_output="$(
  docker ps -a -f "label=com.magento.dockerized" --format "{{.Names}} {{.Status}}" | \
    perl -pe 's/ (Up|Exited) .*/ \1/'
)"

is_onedrive_linked() {
  [[ -d "$HOME/Adobe Systems Incorporated/SITeam - docker" ]] ||
    [[ -d "$HOME/Adobe/SITeam - docker" ]]
}

reload_rev_proxy() {
  verify_mdm_cert_dir
  docker-compose -f ~/.mdm/current/docker-files/docker-compose.yml run --rm nginx-rev-proxy-setup
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

is_app_installed() {
  # grep once and store result in var
  [[ -n "$app_is_installed" ]] ||
    {
      echo "$formatted_cached_docker_ps_output" | grep -q "^${COMPOSE_PROJECT_NAME}_db_1 "
      app_is_installed=$?
    }
  return "$app_is_installed"
}

is_app_running() {
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

run_without_args() {
  # for debugging. bash vscode debugger changes normal invocation, so check for a special var 
  [[ "$vsc_debugger_arg" == "n/a" ]] && return
  [[ -n "$vsc_debugger_arg" ]] &&
    menu_selection="$vsc_debugger_arg" ||
    menu_selection="${BASH_ARGV[-1]}"
  return "${BASH_ARGC[-1]}" # BASH_ARGC tracks number of parameters in call stack; last index is original script
}

called_from_platypus_app() {
  [[ "$parent_pids_path" =~ .app/Contents/MacOS/ ]]
}

get_latest_sem_ver() {
  curl -svL "$repo_url/releases" | \
    perl -ne 'BEGIN{undef $/;} /archive\/(.*)\.tar\.gz/ and print $1'
}

is_update_available() {
  # check for a new version once a day (86400 secs)
  local mdm_ver_file more_recent_of_two
  mdm_ver_file="$mdm_path/latest-sem-ver"
  if [[ -f "$mdm_ver_file" && "$(( $(date +%s) - $(stat -f%c "$mdm_ver_file") ))" -lt 86400 ]]; then
    local latest_sem_ver
    latest_sem_ver="$(<"$mdm_ver_file")"
    [[ "$mdm_version" == "$latest_sem_ver" ]] && return 1
    # verify latest is more recent using gsort -V
    more_recent_of_two="$(printf "%s\n%s" "$mdm_version" "$latest_sem_ver" | gsort -V | tail -1)"
    [[ "$latest_sem_ver" == "$more_recent_of_two" ]] && return
  else
    # get info in the background to prevent latency in menu rendering
    get_latest_sem_ver > "$mdm_ver_file" 2>/dev/null &
  fi
  return 1
}

download_and_link_latest_release() {
  local latest_release_ver
  latest_release_ver=$(get_latest_sem_ver)
  cd "$mdm_path"
  curl -svLO "$repo_url/archive/$latest_release_ver.tar.gz"
  mkdir -p "$latest_release_ver"
  tar -zxf "$latest_release_ver.tar.gz" --strip-components 1 -C "$latest_release_ver"
  rm "$latest_release_ver.tar.gz" current || : # cleanup and remove old link
  ln -sf "$latest_release_ver" current
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
export COMPOSE_PROJECT_NAME=\"$COMPOSE_PROJECT_NAME\"
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
  touch "$quit_detection_file"
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
    sleep 5
  done
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
      # if a submenu heading, was the last char a newline? if not, add one to start new submenu
      [[ $menu_output =~ $'\n'$ ]] || menu_output+=$'\n'
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

handle_menu_selection() {
  local key
  # if selected menu item matches an exit timer, clear exit timer status and exit
  [[ "$menu_selection" =~ [0-9]{2}:[0-9]{2}:[0-9]{2} ]] && clear_status && exit
  
  # otherwise check what type of menu item was selected

  # a func?
  key="$menu_selection-handler"
  [[ -n "${menu[$key]}" ]] && {
    "${menu[$key]}"
    exit
  }

  # a link?
  key="$menu_selection-link"
  [[ -n "${menu[$key]}" ]] && {
    open "${menu[$key]}"
    exit
  }

}

###
#
# initialization logic
#
##

# allow parent_pids_path to be set by the env to debug a specific instance
# otherwise grab the actual exact path of the osx platypus app
parent_pids_path="${parent_pids_path:-$(ps -p $PPID -o command=)}"

called_from_platypus_app && {
  resource_dir="${parent_pids_path/\.app\/Contents\/MacOS\/*/}.app/Contents/Resources"
  cd "$resource_dir/app" || exit
  export COMPOSE_PROJECT_NAME
  COMPOSE_PROJECT_NAME="$(perl -ne 's/.*VIRTUAL_HOST=([^.]*).*/\1/ and print' "$resource_dir/app/docker-compose.yml")"
  [[ -n "$COMPOSE_PROJECT_NAME" ]] || error "Could not find COMPOSE_PROJECT_NAME"
  env_dir="$mdm_path/envs/$COMPOSE_PROJECT_NAME"
  mkdir -p "$env_dir"
}

# if developing and calling from shell, output shows in terminal in real time as expected
# but if called from the platypus app, out to STDOUT for menu and log to a file for debugging
[[ $resource_dir ]] && {
  menu_log_file="$env_dir/menu.log"
  handler_log_file="$env_dir/handler.log"
  if run_without_args; then
    cur_log_file="$menu_log_file"
  else
    cur_log_file="$handler_log_file"
  fi
  [[ $debug ]] && {
    # log stdout to log file, too
    exec > >(tee -ia "$cur_log_file")
    # exec 2> >(tee -ia "$cur_log_file")
    exec 2>> "$cur_log_file"
    if run_without_args; then
      timestamp_msg "Script called without args" >&2
    else 
      timestamp_msg "Script called with ${BASH_ARGV[-1]}" >&2
    fi
  }
}

# before this point, only variable & function definitions and trivial ops, now enable debugging
[[ $debug ]] && set -x

[[ $resource_dir ]] && {
  quit_detection_file="$env_dir/.$PPID-still_running"
  status_msg_file="$env_dir/.status"
}

: # need to return true or will exit when sourced with "-e" and last test = false
