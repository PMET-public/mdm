#!/usr/bin/env bash

## if a selected menu item task:
#   1. would complete immediately, just run it
#   2. would require user interaction (including long term monitoring of output), run in terminal
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
    can_optimize_vm_cpus && perl -i -pe 's/("cpus"\s*:\s*)\d+/${1}4/' "$docker_settings_file"
    can_optimize_vm_swap && perl -i -pe 's/("swapMiB"\s*:\s*)\d+/${1}2048/' "$docker_settings_file"
    can_optimize_vm_mem && perl -i -pe 's/("memoryMiB"\s*:\s*)\d+/${1}4096/' "$docker_settings_file"
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
    docker-compose up build
    docker-compose run --rm deploy cloud-deploy
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
    # varnish brings up web -> brings up fpm
    docker-compose up -d varnish
    mdm_cert_dir="$(get_onedrive_cert_dir)"
    [[ -n $mdm_cert_dir ]] &&
      export mdm_cert_dir ||
      error "Could not find certs in expected OneDrive location."
    [[ -r "$mdm_cert_dir/cert1.pem" ]] ||
      error "Can't read TLS certificates from OneDrive."
    docker-compose -f ~/.mdm/current/docker-files/docker-compose.yml run --rm nginx-rev-proxy-setup
    # map the magento app host to the internal docker ip and add it to the container's host file before running post deploy hook
    docker-compose run --rm deploy bash -c "getent hosts host.docker.internal | \
      perl -pe 's/ .*/ $(get_host)/' >> /etc/hosts;
      /app/bin/magento cache:enable
      cloud-post-deploy"
    # docker-compose run --rm deploy cloud-post-deploy
    # DO NOT RUN -> docker-compose up -d
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
  run_without_args ||
    set_status_and_wait_for_exit $! "Stopping Magento application ..."
}

restart_app() {
  {
    timestamp_msg "${FUNCNAME[0]}"
    # build and deploy restarts may be interfering
    # TODO find way to start up all appropiate services without enumerating
    docker-compose start rabbitmq db fpm web varnish elasticsearch redis
    # TODO another apparent bug where any cache has to be cleaned with a restart
    docker-compose run --rm deploy magento-command cache:clean config_webservice
    docker-compose -f ~/.mdm/current/docker-files/docker-compose.yml run --rm nginx-rev-proxy-setup
    open "https://$(get_host)"
  } >> "$handler_log_file" 2>&1 &
  set_status_and_wait_for_exit $! "Starting Magento application ..."
}

sync_app_to_remote() {
  :
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
    read -p ' ARE YOU SURE?? (y/n) '
    if [[ \$REPLY =~ ^[Yy]\$ ]]; then
      cd \"$resource_dir/app\" || exit
      docker-compose down -v
    else
      echo -e '\nNothing changed.'
    fi
  "
}

stop_other_apps() {
  {
    timestamp_msg "${FUNCNAME[0]}"
    # relies on db service having label=label=com.magento.dockerized
    compose_project_names="$(
      docker ps -f "label=com.magento.dockerized" --format="{{ .Names  }}" | \
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

toggle_advanced_mode() {
  if [[ -f "$advanced_mode_flag_file" ]]; then
    rm "$advanced_mode_flag_file"
  else
    touch "$advanced_mode_flag_file"
  fi
}
