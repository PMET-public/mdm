#!/usr/bin/env bash

# if a selected menu item task:
#   1. completes immediately, just run it
#   2. requires user interaction (including long term monitoring of output), run in terminal
#   3. should be completed in the background, run as child process and set non-blocking status

# jobs will either be ongoing (no file extention), done (.done), seen but not cleared (.seen), or .cleared (.cleared)
# when user selects a job status msg, clear all seen
# if one of the cleared was an error, pop up a terminal with what that error was
clear_job_statuses() {
  local job_file job_msg job_start job_pid job_end job_exit_code job_ui_state unseen_error_msgs=""
  pushd "$apps_mdm_jobs_dir" > /dev/null || return
  for job_file in $(find * -type f -not -name "*.cleared"); do
    mv "$job_file" "${job_file/%seen/cleared}"
    [[ "$job_exit_code" != "0" ]] && unseen_error_msgs="true"
  done
  is_advanced_mode && [[ $unseen_error_msgs ]] && {
    show_errors_from_mdm_logs
  }
  popd > /dev/null || return
}

# get all non cleared jobs
# display an icon to represent running, successful, or failed jobs
# mark done jobs as seen
# calculate the run time for each job
get_job_statuses() {
  local job_file job_msg job_start job_pid job_end job_exit_code job_ui_state
  pushd "$apps_mdm_jobs_dir" > /dev/null || return
  for job_file in $(find * -type f -not -name "*.cleared"); do
    read -r job_start job_pid job_end job_exit_code job_ui_state <<<"$(echo "$job_file" | tr '.' ' ')"
    job_msg="$(<"$job_file")"
    [[ "$job_ui_state" = "done" ]] && mv "$job_file" "${job_file/%done/seen}"
    if [[ "$job_ui_state" = "done" || "$job_ui_state" = "seen" ]]; then
      duration=" ⌚️$(convert_secs_to_hms "$(( $job_end - $job_start ))")"
      if [[ "$job_exit_code" = "0" ]]; then
        prefix="✅ Success."
      else
        prefix="❗Error!"
      fi
    else
      prefix="DISABLED|⏳ "
      duration=" $(convert_secs_to_hms "$(( $($date_cmd +%s) - $job_start ))")"
    fi
    echo "$prefix $job_msg $duration"
  done
  echo "---------"
  popd > /dev/null || return
}

install_additional_tools() {
  run_this_menu_item_handler_in_new_terminal_if_applicable || {

    is_magento_cloud_cli_installed || {
      msg_w_newlines "Installing magento-cloud CLI ..."
      curl -sLS https://accounts.magento.cloud/cli/installer | php
    }

    ! is_docker_bash_completion_installed && is_mac && {
      msg_w_newlines "Installing shell completion support for Docker for Mac ..."
      etc=/Applications/Docker.app/Contents/Resources/etc
      ln -s $etc/docker.bash-completion $(brew --prefix)/etc/bash_completion.d/docker
      ln -s $etc/docker-compose.bash-completion $(brew --prefix)/etc/bash_completion.d/docker-compose
    }

    is_mac && ! is_platypus_installed && {
      msg_w_newlines "Installing Platypus ..."
      brew cask install platypus
      gunzip -c /Applications/Platypus.app/Contents/Resources/platypus_clt.gz > /usr/local/bin/platypus
      mkdir -p /usr/local/share/platypus
      cp -R /Applications/Platypus.app/Contents/Resources/PlatypusDefault.icns /Applications/Platypus.app/Contents/Resources/MainMenu.nib /usr/local/share/platypus/
      gunzip -c /Applications/Platypus.app/Contents/Resources/ScriptExec.gz > /usr/local/share/platypus/ScriptExec
      chmod +x /usr/local/bin/platypus /usr/local/share/platypus/ScriptExec
    }

    ! is_mkcert_installed && {
      msg_w_newlines "Installing mkcert ..."
      brew install mkcert nss
    }

    msg_w_newlines "Additional tools successfully installed."
  }
}

optimize_docker() {
  {
    msg_w_timestamp "${FUNCNAME[0]}"
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
  track_job_status_and_wait_for_exit $! "Optimizing Docker VM ..."
}

start_docker() {
  {
    msg_w_timestamp "${FUNCNAME[0]}"
    restart_docker_and_wait
  } >> "$handler_log_file" 2>&1 &
  track_job_status_and_wait_for_exit $! "Starting Docker VM ..."
}

update_mdm() {
  download_and_link_latest
}

install_app() {
  {
    msg_w_timestamp "${FUNCNAME[0]}"
    cd "$apps_resources_dir/app" || exit
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
      # docker-compose up build
      # docker-compose up deploy || :
      # docker-compose logs deploy
    # option 2 creates containers (when *_1 already exist) but doesn't have reliance on default cmds
    docker-compose run build cloud-build
    docker-compose run deploy cloud-deploy
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
    # TODO would this be an option instead? https://docs.docker.com/compose/compose-file/#extra_hosts
    docker-compose run --rm deploy bash -c "getent hosts host.docker.internal | \
      perl -pe 's/ .*/ $(get_hostname_for_this_app)/' >> /etc/hosts;
      /app/bin/magento cache:enable
      cloud-post-deploy"
    open "https://$(get_hostname_for_this_app)"
  } >> "$handler_log_file" 2>&1 &
  local background_install_pid=$!
  # skip showing logs in new terminal for CI
  is_CI || show_mdm_logs >> "$handler_log_file" 2>&1 &
  # last b/c of blocking wait 
  # can't run in background b/c child process can't "wait" for sibling proces only descendant processes
  track_job_status_and_wait_for_exit $background_install_pid "Installing Magento ..."
}

open_app() {
  open "https://$(get_hostname_for_this_app)"
}

stop_app() {
  {
    msg_w_timestamp "${FUNCNAME[0]}"
    docker-compose stop
  } >> "$handler_log_file" 2>&1 &
  # if stopped indirectly (by quitting the app), don't bother to set the status and wait
  invoked_mdm_without_args ||
    track_job_status_and_wait_for_exit $! "Stopping Magento ..."
}

restart_app() {
  {
    msg_w_timestamp "${FUNCNAME[0]}"
    services="$(get_docker_compose_runtime_services)"
    docker-compose start $services
    reload_rev_proxy
    # TODO another BUG where a cache has to be cleaned with a restart AND after a time delay. RACE CONDITION?!
    docker-compose run --rm deploy magento-command cache:clean config_webservice
    open "https://$(get_hostname_for_this_app)"
  } >> "$handler_log_file" 2>&1 &
  track_job_status_and_wait_for_exit $! "Starting Magento ..."
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
    $sort_cmd -rV |
    xargs
  )"
  prev=$(echo "${vers/* $current / }" | perl -pe 's/.*?\b([0-9.]+).*/$1/')
  [[ -d $prev ]] && {
    rm current
    ln -sf $prev current
  }
}

toggle_mdm_debug_mode() {
  kill $PPID
  if [[ "$debug" ]]; then
    unset debug
    open "$apps_resources_dir/../../"
  else
    debug=1 open "$apps_resources_dir/../../"
  fi
}

toggle_mkcert_CA_install() {
  run_this_menu_item_handler_in_new_terminal_if_applicable || {
    if is_mkcert_CA_installed; then
      warning_w_newlines "Removing your local certificate authority. Your password is required to make these changes."
      mkcert -uninstall
      ! is_mkcert_CA_installed && msg_w_newlines "Successfully removed." || msg_w_newlines "Please try again."
    else
      warning_w_newlines "Please be careful when installing a local certificate authority and only continue if you understand the risks.
This will require your password.
      "
      mkcert -install
      is_mkcert_CA_installed && msg_w_newlines "Successfully installed." || msg_w_newlines "Please try again."
    fi
  }
}

rm_magento_docker_images() {
  run_this_menu_item_handler_in_new_terminal_if_applicable || {
    warning_w_newlines "This will delete all Magento images to force the download of the latest versions. 
If a Magento app is stopped, it will NOT be preserved."
    confirm_or_exit
    image_ids=$(docker images | grep -E '^(magento|pmetpublic)/' | awk '{print $3}')
    [[ $image_ids ]] && {
      docker rmi -f $image_ids
    }
    msg_w_newlines "Magento docker images successfully removed."
  }
}

reset_docker() {
  run_this_menu_item_handler_in_new_terminal_if_applicable || {
    local container_ids volume_ids
    warning_w_newlines "This will delete all docker containers, volumes, and networks.
  Docker images will be preserved to avoid downloading all images from scratch."
    confirm_or_exit
    # remove containers
    container_ids="$(docker ps -qa)"
    [[ "$container_ids" ]] && {
      docker stop $container_ids
      docker rm -fv $container_ids
    }
    # remove volumes
    volume_ids="$(docker volume ls -q)"
    [[ "$volume_ids" ]] && {
      docker volume rm -f $volume_ids
    }
    # remove networks
    docker network prune -f || :
    msg_w_newlines "Docker reset successfully."
  }
}

wipe_docker() {
  run_this_menu_item_handler_in_new_terminal_if_applicable || {
    warning_w_newlines "This will delete ALL local docker artifacts - containers, images, volumes, and networks!"
    confirm_or_exit
    reset_docker
    docker rmi -f $(docker images -qa) || :
    # also clean up envs artifacts
    rm -rf "$mdm_path/envs/*" || :
    msg_w_newlines "Docker wiped successfully."
  }
}

clone_app() {
  :
}

no_op() {
  :
}

start_shell_in_app() {
  run_this_menu_item_handler_in_new_terminal_if_applicable || {
    cd "$apps_resources_dir/app" || exit
    docker-compose run --rm deploy bash
  }
}

run_as_bash_cmds_in_app() {
  run_this_menu_item_handler_in_new_terminal_if_applicable || {
    cd "$apps_resources_dir/app" || exit
    echo 'Running in Magento app:'
    msg '
      $1
  '
    docker-compose run --rm deploy bash -c '$1' 2> /dev/null
  }
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

# compare to chrome extenstion function (keep the funcs synced)
warm_cache() {
  run_this_menu_item_handler_in_new_terminal_if_applicable || {
    local domain tmp_file
    domain=$(get_hostname_for_this_app)
    set -x
    domain=$domain
    url="https://$domain"
    tmp_file=$(mktemp)

    msg Warming cache ...

    # recursively get admin and store front
    wget -nv -O $tmp_file -H --domains=$domain $url/admin
    wget -nv -r -X static,media -l 1 -O $tmp_file -H --domains=$domain $url
    rm $tmp_file
  }
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
  run_this_menu_item_handler_in_new_terminal_if_applicable || {
    local services_status
    if is_app_installed; then
      services_status="$(docker-compose ps)"
    else
      services_status="$(warning_w_newlines "Magento app not installed yet.")"
    fi
    cd "$apps_resources_dir/app" || exit
    msg Running $COMPOSE_PROJECT_NAME from $(pwd)
    echo -e "\\n\\n$services_status"
    msg_w_newlines "
  You can run docker-compose cmds here, but it's recommend to use the MDM app to (un)install or
  start/stop the Magento app to ensure the proper application state.

  Magento docker-compose reference: https://devdocs.magento.com/cloud/docker/docker-quick-reference.html
  Full docker-compose reference: https://docs.docker.com/compose/reference/overview/
  "
    bash -l
  }
}

show_app_logs() {
  :
}

show_errors_from_mdm_logs() {
  run_this_menu_item_handler_in_new_terminal_if_applicable || {
    local errors
    # prefix output with spaces so the output won't match itself (and duplicate errors in output)
    errors="$(perl -ne '/^[^ ]+\[20.*\].*error:/i and print "  $_"' "$handler_log_file")"
    if [[ "$errors" ]]; then
      msg_w_newlines "These are the current errors in the MDM log:"
      echo "$errors"
    else
      msg_w_newlines "No errors found in the MDM log."
    fi
  }
}

show_mdm_logs() {
  run_this_menu_item_handler_in_new_terminal_if_applicable || {
    cd "$apps_resources_dir" || exit
    screen -c "$lib_dir/../.screenrc"
  }
}

uninstall_app() {
  run_this_menu_item_handler_in_new_terminal_if_applicable || {
    msg_w_timestamp "${FUNCNAME[0]}"
    exec > >(tee -ia "$handler_log_file")
    exec 2> >(tee -ia "$handler_log_file" >&2)
    warning_w_newlines "THIS WILL DELETE ANY CHANGES TO $COMPOSE_PROJECT_NAME!"
    confirm_or_exit
    cd "$apps_resources_dir/app" || exit
    docker-compose down -v
  }
}

stop_other_apps() {
  {
    msg_w_timestamp "${FUNCNAME[0]}"
    compose_project_names="$(
      docker ps -f "label=com.docker.compose.service=db" --format="{{ .Names  }}" | \
      perl -pe 's/_db_1$//'
    )"
    for name in $compose_project_names; do
      [[ $name == "COMPOSE_PROJECT_NAME" ]] && continue
      # shellcheck disable=SC2046
      docker stop $(docker ps -q -f "name=^${name}_")
    done
  } >> "$handler_log_file" 2>&1 &
  track_job_status_and_wait_for_exit $! "Stopping other apps ..."
}


# TODO change away positional pararms & is demo mode still used?
start_pwa_with_app() {
  start_pwa "https://$(get_hostname_for_this_app)" "" "false"
}

start_pwa_with_remote() {
  start_pwa "" "settings" "true"
}

start_pwa() {
  local magento_url pwa_path cloud_mode
  magento_url="$1"
  pwa_path="$2"
  cloud_mode="$3"
  {
    export MAGENTO_URL="$magento_url" \
      COMPOSE_PROJECT_NAME="detached-mdm" \
      COMPOSE_FILE="$lib_dir/../docker-files/docker-compose.yml" \
      CLOUD_MODE="$cloud_mode"
    docker-compose pull
    docker-compose rm -sfv storystore-pwa storystore-pwa-prev
    docker-compose up -d storystore-pwa storystore-pwa-prev
    ! is_nginx_rev_proxy_running && reload_rev_proxy
    local index=1
    until [[ 200 = $(curl -w '%{http_code}' -so /dev/null https://pwa/settings) || $index -gt 10 ]]; do sleep 0.5; ((index++)); done
    open "https://pwa/$pwa_path"
  } >> "$handler_log_file" 2>&1 &
  track_job_status_and_wait_for_exit $! "(Re)starting PWA"
}


toggle_advanced_mode() {
  if [[ -f "$advanced_mode_flag_file" ]]; then
    rm "$advanced_mode_flag_file"
  else
    touch "$advanced_mode_flag_file"
  fi
}
