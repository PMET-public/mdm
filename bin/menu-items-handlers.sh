#!/usr/bin/env bash

# if a selected menu item task:
#   1. completes immediately, just run it
#   2. requires user interaction (including long term monitoring of output), run in terminal
#   3. should be completed in the background, run as child process and set non-blocking status

clear_status() {
  rm "$status_msg_file"
}

show_status() {
  local status
  status="$(<"$status_msg_file")"
  # if status already has time, process completed
  if [[ "$status" =~ [0-9]{2}:[0-9]{2}:[0-9]{2} ]]; then
    echo "$status"
  else
    echo "$status $(convert_secs_to_hms "$(( $(date +%s) - $(stat -f%c "$status_msg_file") ))")"
  fi
  echo "---------"
}


install_additional_tools() {
  run_as_bash_script_in_terminal "
    msg \"Installing composer\"
    brew install composer
    msg \"Installing magento-cloud CLI\"
    curl -sLS https://accounts.magento.cloud/cli/installer | php
    msg \"Installing shell completion support for Docker\"
    etc=/Applications/Docker.app/Contents/Resources/etc
    ln -s \$etc/docker.bash-completion \$(brew --prefix)/etc/bash_completion.d/docker
    ln -s \$etc/docker-compose.bash-completion \$(brew --prefix)/etc/bash_completion.d/docker-compose
    msg \"Install Platypus \"
    brew cask install platypus
    gunzip -c /Applications/Platypus.app/Contents/Resources/platypus_clt.gz > /usr/local/bin/platypus
    chmod +x /usr/local/bin/platypus
  "
}

optimize_docker() {
  {
    timestamp_msg "${FUNCNAME[0]}"
    cp "$docker_settings_file" "$docker_settings_file.bak"
    can_optimize_vm_cpus && perl -i -pe "s/(\"cpus\"\s*:\s*)\d+/\${1}$recommended_vm_cpu/" "$docker_settings_file"
    can_optimize_vm_swap && perl -i -pe "s/(\"swapMiB\"\s*:\s*)\d+/\${1}$recommended_vm_swap_mb/" "$docker_settings_file"
    can_optimize_vm_mem && perl -i -pe "s/(\"memoryMiB\"\s*:\s*)\d+/\${1}$recommended_vm_mem_mb/" "$docker_settings_file"
    can_optimize_vm_disk && perl -i -pe "s/(\"diskSizeMiB\"\s*:\s*)\d+/\${1}$recommended_vm_disk_mb/" "$docker_settings_file"
    perl -i -pe "s/(\"autoStart\"\s*:\s*).*/\${1}false,/" "$docker_settings_file"
    perl -i -pe "s/(\"displayedTutorial\"\s*:\s*).*/\${1}true,/" "$docker_settings_file"
    perl -i -pe "s/(\"analyticsEnabled\"\s*:\s*).*/\${1}false,/" "$docker_settings_file"
    restart_docker_and_wait
  } >> "$handler_log_file" 2>&1 &
  set_status_and_wait_for_exit $! "Optimizing Docker VM ..."
}

start_docker() {
  {
    timestamp_msg "${FUNCNAME[0]}"
    restart_docker_and_wait
  } >> "$handler_log_file" 2>&1 &
  set_status_and_wait_for_exit $! "Starting Docker VM ..."
}

update_mdm() {
  download_and_link_latest_release
}

install_app() {
  (
    timestamp_msg "${FUNCNAME[0]}"
    docker-compose pull # check for new versions
    # create containers but do not start
    docker-compose up --no-start
    # copy db files to db container & start it up
    docker cp .docker/mysql/docker-entrypoint-initdb.d "${COMPOSE_PROJECT_NAME}_db_1":/
    docker-compose up -d db
    # copy over most files in local app dir to build container
    tar -cf - --exclude .docker --exclude .composer.tar.gz --exclude media.tar.gz . | \
      docker cp - "${COMPOSE_PROJECT_NAME}_build_1":/app
    # extract tars created for distribution via sync service e.g. dropbox, onedrive
    extract_tar_to_docker .composer.tar.gz "${COMPOSE_PROJECT_NAME}_build_1:/app"
    [[ -f media.tar.gz ]] && extract_tar_to_docker media.tar.gz "${COMPOSE_PROJECT_NAME}_build_1:/app"
    docker cp app/etc "${COMPOSE_PROJECT_NAME}_deploy_1":/app/app/
    # 2 options to start build & deploy
    # option 1 relies on default cmds in image or set by docker-compose.override.yml file
    docker-compose up build
    docker-compose up deploy
    # option 2 creates containers (when *_1 already exist) but doesn't have reliance on default cmds
    # docker-compose run --rm build cloud-build
    # docker-compose run --rm deploy cloud-deploy
    docker-compose run --rm deploy magento-command config:set system/full_page_cache/caching_application 2 --lock-env
    # this command causes indexer to be set in app/etc/env.php but without the expected values for host/username
    docker-compose run --rm deploy magento-command setup:config:set --http-cache-hosts=varnish
    # TODO remove this hack that fixes this bug https://github.com/magento/magento2/issues/2852
    docker-compose run --rm deploy perl -i -pe \
      "s/'model' => 'mysql4',/
      'username' => 'user', 
      'host' => 'database.internal',
      'dbname' => 'main',
      'password' => '',
      'model' => 'mysql4',/" /app/app/etc/env.php
    docker-compose run --rm deploy magento-command indexer:reindex
    docker-compose run --rm deploy magento-command cache:clean config_webservice
    services="$(get_docker_compose_runtime_services)"
    docker-compose up -d $services
    reload_rev_proxy
    # map the magento app host to the internal docker ip and add it to the container's host file before running post deploy hook
    docker-compose run --rm deploy bash -c "getent hosts host.docker.internal | \
      perl -pe 's/ .*/ $(get_host)/' >> /etc/hosts;
      /app/bin/magento cache:enable
      cloud-post-deploy"
    open "https://$(get_host)"
  ) >> "$handler_log_file" 2>&1 &
  local background_install_pid=$!
  show_mdm_logs >> "$handler_log_file" 2>&1 &
  # last b/c of blocking wait 
  # can't run in background b/c child process can't "wait" for sibling proces only descendant processes
  set_status_and_wait_for_exit $background_install_pid "Installing Magento ..."
}

open_app() {
  open "https://$(get_host)"
}

stop_app() {
  {
    timestamp_msg "${FUNCNAME[0]}"
    docker-compose stop
  } >> "$handler_log_file" 2>&1 &
  # if stopped indirectly (by quitting the app), don't bother to set the status and wait
  invoked_mdm_without_args ||
    set_status_and_wait_for_exit $! "Stopping Magento ..."
}

restart_app() {
  {
    timestamp_msg "${FUNCNAME[0]}"
    services="$(get_docker_compose_runtime_services)"
    docker-compose start $services
    reload_rev_proxy
    # TODO another BUG where a cache has to be cleaned with a restart AND after a time delay. RACE CONDITION?!
    docker-compose run --rm deploy magento-command cache:clean config_webservice
    open "https://$(get_host)"
  } >> "$handler_log_file" 2>&1 &
  set_status_and_wait_for_exit $! "Starting Magento ..."
}

sync_app_to_remote() {
  :
}

force_check_mdm_ver() {
  rm "$mdm_ver_file" || : # okay if file doesn't exist
  is_update_available || : # okay if update n/a, just triggering the check
}

revert_to_prev_mdm() {
  # what about when verion in lib.sh doesn't match containing dir name?
  # should only happen on dev machine, right?
  # have version determined by path only so it's authoritative?
  local current vers
  cd "$mdm_path"
  current="$(readlink current)"
  # find available version not including 0.0.x
  vers="$(
    find . -type d -maxdepth 1 |
    perl -ne 's/.*\/// and /^[0-9.]+$/ and print' |
    grep -v '^0\.0\.' |
    gsort -rV |
    xargs
  )"
  prev=$(echo "${vers/* $current / }" | perl -pe 's/.*?\b([0-9.]+).*/$1/')
  [[ -d $prev ]] && {
    rm current
    ln -sf $prev current
  }
}

toggle_mdm_debug_mode() {
  local app="${parent_pids_path/.app\/Contents\/MacOS\/*/.app}"
  kill $PPID
  if [[ $debug ]]; then
    unset debug
    open "$app"
  else
    debug=1 open "$app"
  fi
}

rm_magento_docker_images() {
  run_as_bash_script_in_terminal "
    warning \"This will delete all Magento images to force the download of the latest versions. 
If a Magento app is stopped, it will NOT be preserved.\"
    confirm_or_exit
    docker images | grep -E '^(magento|pmetpublic)/' | awk '{print \$3}' | xargs docker rmi -f
  "
}

reset_docker() {
  run_as_bash_script_in_terminal "
    warning \"This will delete all docker containers, volumes, and networks.
Docker images will be preserved to avoid downloading all images from scratch.\"
    confirm_or_exit
    docker stop \$(docker ps -qa)
    docker rm -fv \$(docker ps -qa)
    docker volume rm -f \$(docker volume ls -q)
    docker network prune -f
  "
}

wipe_docker() {
  run_as_bash_script_in_terminal "
    warning \"This will delete ALL local docker artifacts - containers, images, volumes, and networks!\"
    confirm_or_exit
    docker stop \$(docker ps -qa) || :
    docker rm -fv \$(docker ps -qa) || :
    docker volume rm -f \$(docker volume ls -q) || :
    docker network prune -f || :
    docker rmi -f \$(docker images -qa) || :
    # also clean up envs artifacts
    rm -rf \"$mdm_path/envs/*\" || :
  "
}

clone_app() {
  :
}

no_op() {
  :
}

start_shell_in_app() {
  run_as_bash_script_in_terminal "
    cd \"$resource_dir/app\" || exit
    docker-compose run --rm deploy bash
  "
}

run_as_bash_cmds_in_app() {
  run_as_bash_script_in_terminal "
    cd \"$resource_dir/app\" || exit
    echo 'Running in Magento app:'
    msg '
    $1
    
    '
    docker-compose run --rm deploy bash -c '$1' 2> /dev/null
  "
}

reindex() {
  run_as_bash_cmds_in_app "/app/bin/magento indexer:reindex"
}

run_cron() {
  run_as_bash_cmds_in_app "/app/bin/magento cron:run"
}

enable_all_except_cms_cache() {
  run_as_bash_cmds_in_app "/app/bin/magento cache:enable; /app/bin/magento cache:disable layout block_html full_page"
}

enable_all_caches() {
  run_as_bash_cmds_in_app "/app/bin/magento cache:enable"
}

disable_all_caches() {
  run_as_bash_cmds_in_app "/app/bin/magento cache:disable"
}

flush_cache() {
  run_as_bash_cmds_in_app "/app/bin/magento cache:flush"
}

warm_cache() {
  # compare to chrome extenstion function (keep the funcs synced)
  domain=$(get_host)
  run_as_bash_script_in_terminal "
    set -x
    domain=$domain
    url=\"https://\$domain\"
    tmp_file=$(mktemp)

    msg Warming cache ...

    # recursively get admin and store front
    wget -nv -O \$tmp_file -H --domains=\$domain \$url/admin
    wget -nv -r -X static,media -l 1 -O \$tmp_file -H --domains=\$domain \$url
    rm \$tmp_file
  "
}

resize_images() {
  run_as_bash_cmds_in_app "/app/bin/magento catalog:images:resize"
}

switch_to_production_mode() {
  run_as_bash_cmds_in_app "/app/bin/magento deploy:mode:set production"
}

switch_to_developer_mode() {
  run_as_bash_cmds_in_app "/app/bin/magento deploy:mode:set developer"
}


start_mdm_shell() {
  local services_status
  if is_app_installed; then
    services_status="$(docker-compose ps)"
  else
    services_status="$(warning Magento app not installed yet.)"
  fi
  run_as_bash_script_in_terminal "
    cd \"$resource_dir/app\" || exit
    msg Running $COMPOSE_PROJECT_NAME from $(pwd)
    echo -e \"\\n\\n$services_status\"
    msg \"

You can run docker-compose cmds here, but it's recommend to use the MDM app to (un)install or
start/stop the Magento app to ensure the proper application state.

Magento docker-compose reference: https://devdocs.magento.com/cloud/docker/docker-quick-reference.html
Full docker-compose reference: https://docs.docker.com/compose/reference/overview/

\"
    bash -l"
}

show_app_logs() {
  :
}

show_mdm_logs() {
  run_as_bash_script_in_terminal "
    cd \"$resource_dir\" || exit
    screen -c '$lib_dir/../.screenrc'
    exit
  "
}

uninstall_app() {
  timestamp_msg "${FUNCNAME[0]}"
  run_as_bash_script_in_terminal "
    exec > >(tee -ia \"$handler_log_file\")
    exec 2> >(tee -ia \"$handler_log_file\" >&2)
    warning THIS WILL DELETE ANY CHANGES TO $COMPOSE_PROJECT_NAME!
    confirm_or_exit
    cd \"$resource_dir/app\" || exit
    docker-compose down -v
  "
}

stop_other_apps() {
  {
    timestamp_msg "${FUNCNAME[0]}"
    compose_project_names="$(
      docker ps -f "label=com.docker.compose.service=db" --format="{{ .Names  }}" | \
      perl -pe 's/_db_1$//' | \
      grep -v "^${COMPOSE_PROJECT_NAME}\$"
    )"
    for name in $compose_project_names; do
      # shellcheck disable=SC2046
      docker stop $(docker ps -q -f "name=^${name}_")
    done
  } >> "$handler_log_file" 2>&1 &
  set_status_and_wait_for_exit $! "Stopping other apps ..."
}

start_pwa_with_app() {
  export MAGENTO_URL=https://$(get_host) \
    COMPOSE_PROJECT_NAME="" \
    COMPOSE_FILE="$mdm_path/current/docker-files/docker-compose.yml" \
    DEMO_MODE="false" \
    STORYSTORE_PWA_VERSION=$(get_host_version)
  docker-compose rm -sfv storystore-pwa
  docker-compose up -d storystore-pwa
  ! is_nginx_rev_proxy_running && reload_rev_proxy
  local index=1
  until [[ 200 = $(curl -w '%{http_code}' -so /dev/null https://pwa.the1umastory.com) || $index -gt 10 ]]; do sleep 0.5; ((index++)); done
  open https://pwa.the1umastory.com
}

start_pwa_with_diff() {
  export MAGENTO_URL="" \
    COMPOSE_PROJECT_NAME="" \
    COMPOSE_FILE="$mdm_path/current/docker-files/docker-compose.yml" \
    DEMO_MODE="true"
  docker-compose rm -sfv storystore-pwa
  docker-compose up -d storystore-pwa
  ! is_nginx_rev_proxy_running && reload_rev_proxy
  local index=1
  until [[ 200 = $(curl -w '%{http_code}' -so /dev/null https://pwa.the1umastory.com/settings) || $index -gt 10 ]]; do sleep 0.5; ((index++)); done
  open https://pwa.the1umastory.com/settings
}

toggle_advanced_mode() {
  if [[ -f "$advanced_mode_flag_file" ]]; then
    rm "$advanced_mode_flag_file"
  else
    touch "$advanced_mode_flag_file"
  fi
}
