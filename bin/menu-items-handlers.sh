#!/usr/bin/env bash

# if a selected menu item task:
#   1. completes immediately, just run it
#   2. requires user interaction (including long term monitoring of output), run in terminal
#   3. should be completed in the background, run as child process and set non-blocking status

start_docker() {
  {
    msg_w_timestamp "${FUNCNAME[0]}"
    restart_docker_and_wait
  } >> "$handler_log_file" 2>&1 &
  track_job_status_and_wait_for_exit $! "Starting Docker VM ..."
}

# jobs will either be ongoing (no file extention), done (.done), seen but not cleared (.seen), or .cleared (.cleared)
# when user selects a job status msg, clear all seen
# if one of the cleared was an error, pop up a terminal with what that error was
clear_job_statuses() {
  local job_file job_msg job_start job_pid job_end job_exit_code job_ui_state unseen_error_msgs
  pushd "$apps_mdm_jobs_dir" > /dev/null || return 1
  for job_file in $(find * -type f -not -name "*.cleared"); do
    read -r job_start job_pid job_end job_exit_code job_ui_state <<<"$(echo "$job_file" | tr '.' ' ')"
    [[ "$job_exit_code" != 0 ]] && unseen_error_msgs="true"
    mv "$job_file" "${job_file/%seen/cleared}"
  done
  is_advanced_mode && [[ "$unseen_error_msgs" ]] && {
    show_errors_from_mdm_logs
  }
  popd > /dev/null || return 1
}

# get all non cleared jobs
# display an icon to represent running, successful, or failed jobs
# mark done jobs as seen
# calculate the run time for each job
get_job_statuses() {
  local job_file job_msg job_start job_pid job_end job_exit_code job_ui_state
  pushd "$apps_mdm_jobs_dir" > /dev/null || return 1
  for job_file in $(find * -type f -not -name "*.cleared"); do
    # shellcheck disable=SC2034
    read -r job_start job_pid job_end job_exit_code job_ui_state <<<"$(echo "$job_file" | tr '.' ' ')"
    job_msg="$(<"$job_file")"
    [[ "$job_ui_state" = "done" ]] && mv "$job_file" "${job_file/%done/seen}"
    if [[ "$job_ui_state" = "done" || "$job_ui_state" = "seen" ]]; then
      duration=" ⌚️$(convert_secs_to_hms "$(( "$job_end" - "$job_start" ))")"
      if [[ "$job_exit_code" = 0 ]]; then
        prefix="✅ Success."
      else
        prefix="❗Error!"
      fi
    else
      prefix="DISABLED|⏳ "
      duration=" $(convert_secs_to_hms "$(seconds_since "$job_start")")"
    fi
    echo "$prefix $job_msg $duration"
  done
  echo "---------"
  popd > /dev/null || return 1
}

install_additional_tools() {
  run_this_menu_item_handler_in_new_terminal_if_applicable || {

    is_magento_cloud_cli_installed || {
      msg_w_newlines "Installing magento-cloud CLI ..."
      curl -sLS https://accounts.magento.cloud/cli/installer | php
    }

    ! is_docker_bash_completion_installed_on_mac && is_mac && {
      msg_w_newlines "Installing shell completion support for Docker for Mac ..."
      etc=/Applications/Docker.app/Contents/Resources/etc
      [[ -d /usr/local/etc ]] || error "Expected destination for bash completion does not exist"
      ln -s "$etc/docker.bash-completion" "/usr/local/etc/bash_completion.d/docker"
      ln -s "$etc/docker-compose.bash-completion" "/usr/local/etc/bash_completion.d/docker-compose"
    }

    is_mac && ! is_platypus_installed && {
      msg_w_newlines "Installing Platypus ..."
      # check if previouly installed but must not have completed b/c failing is_platypus_installed check
      if [[ -d /Applications/Platypus.app ]]; then
        brew reinstall --cask platypus
      else
        brew install --cask platypus
      fi
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

    ! is_tmate_installed && {
      msg_w_newlines "Installing tmate ..."
      brew install tmate
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

create_auth_json() {
  run_this_menu_item_handler_in_new_terminal_if_applicable || {
    local github_token magento_public_key magento_private_key
    warning_w_newlines "

>> This script will prompt for your GitHub and Magento account information to create your $HOME/.composer/auth.json file. <<

"
    echo "If you prefer to create the file on your own, follow the instructions here:
https://devdocs.magento.com/guides/v2.4/install-gde/prereq/dev_install.html#instgde-prereq-compose-clone-auth"
    msg_w_newlines "GitHub Personal Access Token"
    echo "1. Sign into GitHub https://github.com/
2. Go to your account Profile > Developer settings > Personal access tokens
3. Generate a new token with any name and 'repo' scope (no other selections are needed)
4. Paste the token here
"
    github_token="$(prompt_user_for_token >&2)"

    msg_w_newlines "Magento Public Key"
    echo "1. Sign into the Magento Marketplace https://marketplace.magento.com/
2. Go to your account profile
3. Go to your access keys
4. Copy an existing key or create a new one
5. Paste your public key here
"
    magento_public_key="$(prompt_user_for_token >&2)"

    msg_w_newlines "Magento Private Key"
    echo "1. From the same place as #5 above, paste your private key here
"
    magento_private_key="$(prompt_user_for_token >&2)"

    # back up file if it exists
    [[ -f "$HOME/.composer/auth.json" ]] && cp "$HOME/.composer/auth.json" "$HOME/.composer/auth.json.$(date +"%s")"

    printf '{
    "github-oauth": {
      "github.com": "%s"
    },
    "http-basic": {
        "repo.magento.com": {
            "username": "%s",
            "password": "%s"
        }
    }
}' "$github_token" "$magento_public_key" "$magento_private_key" > "$HOME/.composer/auth.json"

    msg_w_newlines "$HOME/.composer/auth.json successfully created."
  }
}


update_mdm() {
  download_and_link_repo_ref
}

install_app() {
  local tmp_file cid background_install_pid finished_msg="install_app finished" # line 
  {
    msg_w_timestamp "${FUNCNAME[0]}"
    cd "$apps_resources_dir/app" || exit 1
    docker-compose pull || : # check for new versions; don't fail if DNE b/c they may exist locally
    # create containers but do not start
    docker-compose up --no-start
    # copy db files to db container & start it up
    docker cp .docker/mysql/docker-entrypoint-initdb.d "${COMPOSE_PROJECT_NAME}_db_1:/"
    docker-compose up -d db
    # copy over most files in local app dir to build container
    tar -cf - --exclude .docker --exclude .composer.tar.gz --exclude media.tar.gz . | \
      docker cp - "${COMPOSE_PROJECT_NAME}_build_1:/app"
    # extract tars created for distribution via sync service e.g. dropbox, onedrive
    [[ -f .composer.tar.gz ]] && extract_tar_to_existing_container_path .composer.tar.gz "${COMPOSE_PROJECT_NAME}_build_1:/app"
    [[ -f media.tar.gz ]] && extract_tar_to_existing_container_path media.tar.gz "${COMPOSE_PROJECT_NAME}_build_1:/app"
    [[ -d app/etc ]] && docker cp app/etc "${COMPOSE_PROJECT_NAME}_deploy_1:/app/app/"
    docker-compose run build cloud-build

    # TODO need way to output install log b/c may appear frozen for mins to hours
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

    # TODO find alt way to resolve permissions issue between mcd images assumptions and
    # 3rd party ext assumptions user and group have read perm and remove read from other
    docker-compose run --rm deploy chmod -R o+rx /app/pub/media

    docker-compose run --rm deploy magento-command indexer:reindex
    docker-compose run --rm deploy magento-command cache:clean config_webservice
    services="$(get_docker_compose_runtime_services)"
    # shellcheck disable=SC2086
    docker-compose up -d $services
    reload_rev_proxy
    # map the magento app hostname to docker host's ip 
    # add it to the container's /etc/hosts file before running post deploy hook
    # so curl https://magento-app-hostname/ (the base url) properly resolves for cache warm-up

    # TODO would this be an option instead? https://docs.docker.com/compose/compose-file/#extra_hosts
    cid="$(docker-compose run -d deploy bash -c "
      sleep 10 # need time to copy over root CA
      update-ca-certificates
      echo '$(print_containers_hosts_file_entry)' >> /etc/hosts
      bin/magento cache:enable
      cloud-post-deploy
    ")"

    docker cp "$(mkcert -CAROOT)/rootCA.pem" "$cid:/usr/local/share/ca-certificates/rootCA.crt"
    open_app
    echo "$finished_msg"
  } >> "$handler_log_file" 2>&1 &
  background_install_pid="$!"
  if launched_from_mac_menu_cached; then
    show_mdm_logs
  else
    # https://superuser.com/a/449307/10719
    #tail -f "$handler_log_file" | tee /dev/tty | while read -r line; do
    #  [[ "$line" = "$finished_msg" ]] && pkill -P $$ tail
    #done
    echo "To watch the install progress: tail -f \"$handler_log_file\""
  fi
  # last b/c of blocking wait
  # can't run in background b/c child process can't "wait" for sibling proces only descendant processes
  track_job_status_and_wait_for_exit $background_install_pid "Installing Magento ..."
}

open_app() {
  local url
  url="https://$(get_hostname_for_this_app)"
  if is_mac; then
    open "$url"
  else
    curl -L "$url"
  fi
}

stop_app() {
  {
    msg_w_timestamp "${FUNCNAME[0]}"
    docker-compose stop
  } >> "$handler_log_file" 2>&1 &
  track_job_status_and_wait_for_exit $! "Stopping Magento ..."
}

restart_app() {
  {
    msg_w_timestamp "${FUNCNAME[0]}"
    services="$(get_docker_compose_runtime_services)"
    # shellcheck disable=SC2086
    docker-compose start $services
    reload_rev_proxy
    # TODO another BUG where a cache has to be cleaned with a restart AND after a time delay. RACE CONDITION?!
    docker-compose run --rm deploy magento-command cache:clean config_webservice
    open_app
  } >> "$handler_log_file" 2>&1 &
  track_job_status_and_wait_for_exit $! "Starting Magento ..."
}

no_op() {
  :
}

uninstall_app() {
  run_this_menu_item_handler_in_new_terminal_if_applicable || {
    msg_w_timestamp "${FUNCNAME[0]}"
    exec > >(tee -ia "$handler_log_file")
    exec 2> >(tee -ia "$handler_log_file" >&2)
    warning_w_newlines "THIS WILL DELETE ANY CHANGES TO $COMPOSE_PROJECT_NAME!"
    confirm_or_exit
    cd "$apps_resources_dir/app" || exit 1
    docker-compose down -v
  }
}

stop_other_apps() {
  {
    msg_w_timestamp "${FUNCNAME[0]}"
    compose_project_names="$(docker ps -a -f "label=com.docker.compose.service=db" --format="{{ .Names  }}" |
      perl -pe 's/_db_1$//')"
    for name in $compose_project_names; do
      [[ "$name" == "$COMPOSE_PROJECT_NAME" ]] && continue
      # shellcheck disable=SC2046
      docker stop $(docker ps -q -f "name=^${name}_")
    done
  } >> "$handler_log_file" 2>&1 &
  track_job_status_and_wait_for_exit $! "Stopping other apps ..."
}

dockerize_app() {
  run_this_menu_item_handler_in_new_terminal_if_applicable || {
    local url start project env branch skip_option="-s"

    printf '\n\n%s\n' "Paste the url for your $(warning "existing Magento Cloud") env or a $(warning "cloud compatible") git repo. If it's a Magento Cloud url, it must be from your Magento Cloud projects page to avoid ambiguity due to capitalaziation or certain punctuation."
    msg_about_url_format="
Enter a valid Magento Cloud url from your Magento Cloud projects page (ex. $(warning "https://<region>.magento.cloud/projects/<project-id>/environments/<env-id>"))
or a valid GitHub url (ex. https://github.com...)."
    REPLY=""
    while ! ( is_valid_mc_env_url "$REPLY" || is_valid_github_web_url "$REPLY" ); do
      echo "$msg_about_url_format"
      read -r -p '> '
      REPLY="$(trim $REPLY)"
    done
    url="$REPLY"
    
    if is_valid_mc_env_url "$url"; then
      is_magento_cloud_cli_logged_in || "$magento_cloud_cmd" login
      read -r project env <<<"$(get_project_and_env_from_mc_url "$url")"
      msg_w_newlines "Pre-bundle EVERYTHING? (Defaults to No)
  Pros:
    Faster to deploy the 1st time
    End user will not need credentials to run but will for any update
  Cons:
    Much slower to create app
    Much larger app to distribute
    End user will need their own valid credentials to install and run

[yes|No]?"
      read -r -p ''
      start="$(date +"%s")"
      [[ "$REPLY" =~ ^[Yy]$ ]] && skip_option=""
      "$lib_dir/dockerize" -p "$project" -e "$env" -i "$HOME/.mdm/current/icons/magento.icns" "$skip_option"
    elif is_valid_github_web_url "$url"; then
      branch="$(get_branch_from_github_web_url "$url")"
      "$lib_dir/dockerize" -g "$url" -b "$branch" -i "$HOME/.mdm/current/icons/magento.icns"
    fi
    show_success_msg_plus_duration "$start"
  }
}

sync_remote_to_app() {
  run_this_menu_item_handler_in_new_terminal_if_applicable || {
    local url start project env media_tmp_dir backup_sql_path sql_tmp_file hostname

    printf '\n\n%s\n' "☁️→💻 Paste the url for the $(warning "existing Magento Cloud") env from your Magento Cloud projects page 
(ex. https://<region>.magento.cloud/projects/<projectid>/environments/<envid>)."
    msg_about_url_format="
Enter a valid Magento Cloud url from your Magento Cloud projects page (ex. $(warning "https://<region>.magento.cloud/projects/<project-id>/environments/<env-id>"))."
    REPLY=""
    while !  is_valid_mc_env_url "$REPLY"; do
      echo "$msg_about_url_format"
      read -r -p '> '
      REPLY="$(trim $REPLY)"
    done
    url="$REPLY"

    start="$(date +"%s")"
    is_magento_cloud_cli_logged_in || "$magento_cloud_cmd" login
    read -r project env <<<"$(get_project_and_env_from_mc_url "$url")"

    msg_w_newlines "Copying cloud media to app ..."
    media_tmp_dir="$(mktemp -d)"
    # copy from container to tmp dir for easy rsync comparison
    docker cp "${COMPOSE_PROJECT_NAME}_fpm_1:/app/pub/media" "$media_tmp_dir"
    "$magento_cloud_cmd" mount:download -y -p "$project" -e "$env" -m pub/media --target "$media_tmp_dir/media" 2>&1 |
      filter_cloud_mount_transfer_output
    docker cp "$media_tmp_dir/media/." "${COMPOSE_PROJECT_NAME}_fpm_1:/app/pub/media/"
    rm -rf "$media_tmp_dir"

    msg_w_newlines "Copying cloud DB to app ..."
    sql_tmp_file="$(mktemp)"
    "$magento_cloud_cmd" db:dump -y -p "$project" -e "$env" -f "$sql_tmp_file"
    # create backup fold in case it does not exist yet
    docker exec "${COMPOSE_PROJECT_NAME}_fpm_1" mkdir -p /app/var/backups
    # magento requires specific naming for it's backups to restore from (e.g. 1601987083_db.sql b/c why??)
    docker cp "$sql_tmp_file" "${COMPOSE_PROJECT_NAME}_fpm_1:/app/var/backups/${start}_db.sql"
    if ! docker exec "${COMPOSE_PROJECT_NAME}_fpm_1" bin/magento setup:rollback -n -d "${start}_db.sql"; then
      # frustrating!! looks like basic back up and rollback from magento is broken (also auto-deletes backup file??!)
      warning "Could not rollback via magento CLI. Attempting direct import ..."
      docker cp "$sql_tmp_file" "${COMPOSE_PROJECT_NAME}_db_1:/tmp/${start}_db.sql"
      docker exec -it "${COMPOSE_PROJECT_NAME}_db_1" bash -c "mysql -u user --password="" main < /tmp/${start}_db.sql"
    fi
    rm "$sql_tmp_file"

    hostname="$(get_hostname_for_this_app)"
    msg_w_newlines "Resetting urls to https://$hostname and flushing the cache ..."
    docker exec "${COMPOSE_PROJECT_NAME}_fpm_1" bash -c "$(get_magento_cmds_to_update_hostname_to "$hostname")"

    show_success_msg_plus_duration "$start"

    # default to env cloned from?
    # check for git changes?
    # warnings to user? under what conditions?
    # does media-gallery:sync need to run
    # reload env if necessary
    # db encrypt key differences?
    # git operations

  }
}

sync_app_to_remote() {
  run_this_menu_item_handler_in_new_terminal_if_applicable || {
    local url start project env media_tmp_dir backup_sql_path sql_tmp_file hostname
    
    printf '\n\n%s\n' "💻→☁️ Paste the url for the $(warning "existing Magento Cloud") env from your Magento Cloud projects page 
(ex. https://<region>.magento.cloud/projects/<projectid>/environments/<envid>)."
    msg_about_url_format="
Enter a valid Magento Cloud url from your Magento Cloud projects page (ex. $(warning "https://<region>.magento.cloud/projects/<project-id>/environments/<env-id>"))."
    REPLY=""
    while !  is_valid_mc_env_url "$REPLY"; do
      echo "$msg_about_url_format"
      read -r -p '> '
      REPLY="$(trim $REPLY)"
    done
    url="$REPLY"
    
    start="$(date +"%s")"
    is_magento_cloud_cli_logged_in || "$magento_cloud_cmd" login
    read -r project env <<<"$(get_project_and_env_from_mc_url "$url")"

    msg_w_newlines "Copying app media to cloud ..."
    media_tmp_dir="$(mktemp -d)"
    docker cp "${COMPOSE_PROJECT_NAME}_fpm_1:/app/pub/media" "$media_tmp_dir"
    "$magento_cloud_cmd" mount:upload -y -p "$project" -e "$env" -m pub/media --source "$media_tmp_dir/media" 2>&1 |
      filter_cloud_mount_transfer_output
    rm -rf "$media_tmp_dir"

    hostname="$("$magento_cloud_cmd" ssh -p "$project" -e "$env" "bin/magento config:show web/secure/base_url" |
      perl -pe 's/^https?:\/\///;s/\s+$//')"

    msg_w_newlines "Copying app DB to cloud ..."
    backup_sql_path="$(docker exec "${COMPOSE_PROJECT_NAME}_fpm_1" bash -c "
      bin/magento config:set -q system/backup/functionality_enabled 1 && 
      bin/magento setup:backup --db | sed -n 's/.*path: //p' | tr -d '\n'
    ")"
    sql_tmp_file="$(mktemp)"
    docker cp "${COMPOSE_PROJECT_NAME}_fpm_1:$backup_sql_path" "$sql_tmp_file"
    "$magento_cloud_cmd" sql -p "$project" -e "$env" < "$sql_tmp_file"
    rm "$sql_tmp_file"

    msg_w_newlines "Resetting urls to https://$hostname and flushing the cache ..."
    "$magento_cloud_cmd" ssh -p "$project" -e "$env" "$(get_magento_cmds_to_update_hostname_to "$hostname")"

    show_success_msg_plus_duration "$start"

  }
}

# by accepting additional args this function allows arbitrary cmds to be run in the magento app with a single call
# this is useful for testing since no menu items currently accept args as user input
start_shell_in_app() {
  run_this_menu_item_handler_in_new_terminal_if_applicable || {
    cd "$apps_resources_dir/app" || exit 1
    if [[ -z "$*" ]]; then
      docker-compose run --rm deploy bash
    else
      docker-compose run --rm deploy bash -c "$*"
    fi
  }
}

# TODO - remove this func and make use of start shell in app
# run_this_menu_item_handler_in_new_terminal_if_applicable will have to be modified to pass args
run_as_bash_cmds_in_app() {
  run_this_menu_item_handler_in_new_terminal_if_applicable || {
    local start
    start="$(date +"%s")"
    cd "$apps_resources_dir/app" || exit 1
    echo 'Running in Magento app:'
    msg "
      $1
"
    docker-compose run --rm deploy bash -c "$1" 2> /dev/null
    show_success_msg_plus_duration "$start"
  }
}

reindex() {
  run_as_bash_cmds_in_app "bin/magento indexer:reindex"
}

run_cron() {
  run_as_bash_cmds_in_app "bin/magento cron:run"
}

enable_all_except_cms_cache() {
  run_as_bash_cmds_in_app "bin/magento cache:enable; bin/magento cache:disable layout block_html full_page"
}

enable_all_caches() {
  run_as_bash_cmds_in_app "bin/magento cache:enable"
}

disable_all_caches() {
  run_as_bash_cmds_in_app "bin/magento cache:disable"
}

flush_cache() {
  run_as_bash_cmds_in_app "bin/magento cache:flush"
}

# compare to chrome extenstion function (keep the funcs synced)
warm_cache() {
  run_this_menu_item_handler_in_new_terminal_if_applicable || {
    local domain tmp_file
    domain=$(get_hostname_for_this_app)
    set -x
    domain=$domain
    url="https://$domain"
    tmp_file="$(mktemp)"

    msg Warming cache ...

    # recursively get admin and store front
    # TODO --no-check-certificate is only needed on mac (even with mkcert CA installed)
    wget --no-check-certificate -nv -O "$tmp_file" -H --domains="$domain" "$url/admin"
    # TODO should work without --no-cookies option but varnish is caching 404 (the default behavior) 
    # but why are urls like whats-new.html returning 404 - is it a demo store issue - and admin is visited 1st?
    # have something to do with admin being visited first
    wget --no-cookies --no-check-certificate -nv -r -X static,media -l 1 -O "$tmp_file" -H --domains="$domain" "$url"
    rm "$tmp_file"
  }
}

resize_images() {
  run_as_bash_cmds_in_app "bin/magento catalog:images:resize"
}

change_base_url() {
  run_this_menu_item_handler_in_new_terminal_if_applicable || {
    local hostname
    msg_w_newlines "Enter new domain or hostname for this magento app:  (Ex. www.example.com, sales-opp.demo, etc.)"
    read -r -p ''
    hostname="$REPLY"
    is_valid_hostname "$hostname" || error "Invalid domain. Exiting unchanged."
    stop_ssh_tunnel
    update_hostname "$hostname"
    msg_w_newlines "Successfully set url to https://$hostname/."
  }
}

switch_to_production_mode() {
  run_as_bash_cmds_in_app "bin/magento deploy:mode:set production"
}

switch_to_developer_mode() {
  run_as_bash_cmds_in_app "bin/magento deploy:mode:set developer"
}

start_mdm_shell() {
  run_this_menu_item_handler_in_new_terminal_if_applicable || {
    local services_status
    if is_magento_app_installed_cached; then
      services_status="$(docker-compose ps)"
    else
      services_status="$(warning_w_newlines "Magento app not installed yet.")"
    fi
    cd "$apps_resources_dir/app" || exit 1
    msg "Running $COMPOSE_PROJECT_NAME from $(pwd)"
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

# TODO change away positional pararms & is demo mode still used?
start_pwa_with_app() {
  start_pwa "https://$(get_hostname_for_this_app)" "" "false"
}

start_pwa_with_luma() {
  start_pwa "https://adminlongliveluma-ee63poq-a6terwtbk67os.demo.magentosite.cloud/" "" "false"
}

start_pwa_with_freshmarket() {
  start_pwa "https://grocery-pks6wry-xy4itwbmg2khk.demo.magentosite.cloud/" "" "false"
}

start_pwa_with_remote() {
  start_pwa "" "settings" "true"
}

start_pwa() {
  local magento_url="$1" pwa_path="$2" cloud_mode="$3" index=1
  {
    # shellcheck disable=SC2030
    export MAGENTO_URL="$magento_url" COMPOSE_PROJECT_NAME="$detached_project_name" CLOUD_MODE="$cloud_mode" \
      COMPOSE_FILE="$lib_dir/../docker-files/pwa-docker-compose.yml"
    docker-compose pull
    docker-compose rm -sfv storystore-pwa storystore-pwa-prev
    docker-compose up -d storystore-pwa storystore-pwa-prev
    ! is_nginx_rev_proxy_running && reload_rev_proxy
    until [[ 200 = $(curl -w '%{http_code}' -so /dev/null "https://$(get_pwa_hostname)/settings") || $index -gt 10 ]]; do sleep 0.5; ((index++)); done
    open "https://$(get_pwa_hostname)/$pwa_path"
  } >> "$handler_log_file" 2>&1 &
  track_job_status_and_wait_for_exit $! "(Re)starting PWA"
}

start_tmate_session() {
  run_this_menu_item_handler_in_new_terminal_if_applicable || {
    local start_pattern="# start mdm keys" end_pattern="# end mdm keys" auth_keys_file="$HOME/.ssh/authorized_keys" \
      auth_keys_md5 auth_keys_to_add tmate_socket
    if [[ "$mdm_tmate_authorized_keys_url" ]]; then
      auth_keys_to_add="$(curl -sL "$mdm_tmate_authorized_keys_url")"
      [[ "$auth_keys_to_add" =~ ssh\- ]] ||
        error "Url $mdm_tmate_authorized_keys_url does not contain valid public ssh key(s)."
      [[ ! -d "$HOME/.ssh/" ]] && mkdir "$HOME/.ssh/"
      chmod 700 "$HOME/.ssh/"
      [[ ! -f "$auth_keys_file" ]] && touch "$auth_keys_file"
      chmod 600 "$auth_keys_file"
      auth_keys_md5="$(md5sum "$auth_keys_file")"
      perl -i.bak -0777 -pe "s/$start_pattern.*$end_pattern\r?\n//s" "$auth_keys_file" # rm old if exists
      printf "%s\n%s\n%s\n" "$start_pattern" "$auth_keys_to_add" "$end_pattern" >> "$auth_keys_file" # add new
      [[ "$auth_keys_md5" = "$(md5sum "$auth_keys_file")" ]] ||
        msg_w_newlines "Successfully updated authorized keys."
    else
      warning_w_newlines "No authorized ssh keys set. $see_docs_msg
If you continue, anyone with your unique url will be able to access to your system."
      confirm_or_exit
    fi
    tmate_socket="/tmp/tmate.$(date "+%s")"
    [[ "$(pgrep tmate)" ]] && { 
      pkill tmate # kill any existing session
      sleep 3
    }
    if [[ "$mdm_tmate_authorized_keys_url" ]]; then
      tmate -a "$auth_keys_file" -S "$tmate_socket" new-session -d
    else
      tmate -S "$tmate_socket" new-session -d
    fi
    tmate -S "$tmate_socket" wait tmate-ready
    ssh_url="$(tmate -S "$tmate_socket" display -p '#{tmate_ssh}')"
    msg_w_newlines "Provide this url to your remote collaborator. Access will end when they close their session or after a period of inactivity."
    warning_w_newlines "$ssh_url"
  }
}

stop_tmate_session() {
  run_this_menu_item_handler_in_new_terminal_if_applicable || {
    if pkill tmate; then
      msg_w_newlines "Successfully stopped 1 or more remote system access sessions."
    else
      msg_w_newlines "No active remote access sessions."
    fi
  }
}

start_remote_web_access() {
  run_this_menu_item_handler_in_new_terminal_if_applicable || {
    local remote_port local_port tmp_file hostname
    is_web_tunnel_configured || error "1 or more ssh tunnel vars not configured"
    hostname="$(get_hostname_for_this_app)"
    if [[ "$hostname" =~ $mdm_tunnel_domain ]] && pgrep -f "ssh.*$mdm_tunnel_ssh_url" > /dev/null; then
      msg "Remote web access is already enabled via "
      warning "https://$hostname"
      msg ". If the url is unresponsive, use the menu to stop remote connection and try again."
      return 0
    fi
    remote_port="$(( $RANDOM + 20000 ))" # RANDOM is between 0-32767 (2^16 / 2 - 1)
    # shellcheck disable=SC2031
    local_port="$(docker ps -a --filter "name=varnish" --filter "label=com.docker.compose.project=$COMPOSE_PROJECT_NAME" --format "{{.Ports}}" | \
      tr ',' '\n' | \
      perl -ne "s/.*:(?=\d{5})// and s/-.*// and print"
    )"
    [[ ! "$local_port" =~ ^[0-9]+$ ]] && echo "Could not find valid local port" && exit 1
    tmp_file="$(mktemp)"
    get_github_file_contents "$mdm_tunnel_pk_url" > "$tmp_file"
    ssh -f \
      -F /dev/null \
      -o IdentitiesOnly=yes \
      -o ExitOnForwardFailure=yes \
      -o StrictHostKeyChecking=no \
      -i "$tmp_file" \
      -NR "$remote_port:127.0.0.1:$local_port" \
      "$mdm_tunnel_ssh_url"
    hostname="$remote_port.$mdm_tunnel_domain"
    update_hostname "$hostname"
    msg_w_newlines "Successfully opened public url https://$hostname"
    rm "$tmp_file"
  }
}

stop_remote_web_access() {
  run_this_menu_item_handler_in_new_terminal_if_applicable || {
    local hostname
    is_web_tunnel_configured || error "1 or more ssh tunnel vars not configured"
    stop_ssh_tunnel
    hostname="$(get_prev_hostname_for_this_app)"
    update_hostname "$hostname"
    msg_w_newlines "Successfully reverted to local url https://$hostname"
  }
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
    cd "$apps_resources_dir" || exit 1
    [[ ! -s "$handler_log_file" ]] && warning_w_newlines "No logs yet. Keep terminal open to view logs as they happen."
    msg_w_newlines "Waiting for new output ..."
    tail -n 0 -f "$handler_log_file"
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

force_check_mdm_ver() {
  rm "$mdm_ver_file" || : # okay if file doesn't exist
  is_update_available || : # okay if update n/a, just triggering the check
}

revert_to_prev_mdm() {
  local current prev
  current="$(readlink "$mdm_path/current")"
  current="${current/*\/}"
  # assumes every version starts with number dot number
  prev="$(
    find "$mdm_path" -type d -maxdepth 1 -name "[0-9]*\.[0-9]*" |
      sort -V |
      perl -pe 's/^.*\///' |
      perl -0777 -ne "/([\d\.]+)\s*(?=$current)/ and print \$1"
  )"
  if [[ "$prev" ]]; then
    ln -sfn "$prev" current
  fi
}

toggle_mkcert_CA_install() {
  run_this_menu_item_handler_in_new_terminal_if_applicable || {
    if is_mkcert_CA_installed; then
      warning_w_newlines "Removing your local certificate authority. Your password is required to make these changes."
      mkcert -uninstall
      rm "$mkcert_installed_flag_file"
      ! is_mkcert_CA_installed && msg_w_newlines "Successfully removed." || msg_w_newlines "Please try again."
    else
      warning_w_newlines "Please be careful when installing a local certificate authority and only continue if you understand the risks.
This will require your password.
      "
      mkcert -install
      touch "$mkcert_installed_flag_file"
      is_mkcert_CA_installed && msg_w_newlines "Successfully installed." || msg_w_newlines "Please try again."
    fi
  }
}

rm_added_hostnames_from_hosts_file() {
  backup_hosts
  sudo_run_bash_cmds "perl -i -ne \"print unless /$hosts_file_line_marker/\" /etc/hosts"
}

docker_prune_all_images() {
    docker image prune -a -f
}

docker_prune_all_stopped_containers_and_volumes() {
  run_this_menu_item_handler_in_new_terminal_if_applicable || {
    warning_w_newlines "This will delete all non-running containers and their associated volumes. Use this to 
preserve ONLY RUNNING installations and DELETE everything else. If you have an old app with data that you might
want to save, do not continue. Export that data before continuing."
    confirm_or_exit
    msg_w_newlines "Removing containers ..."
    docker container prune -f
    msg_w_newlines "Removing volumes ..."
    docker volume prune -f
    msg_w_newlines "Removing networks ..."
    docker network prune -f
  }
}

wipe_docker_except_images() {
  run_this_menu_item_handler_in_new_terminal_if_applicable || {
    local cids
    warning_w_newlines "This will delete ALL docker containers, volumes, and networks!
ONLY Docker images will be preserved to avoid re-downloading images for new installations."
    confirm_or_exit
    cids="$(docker ps -qa)"
    # shellcheck disable=SC2046
    [[ "$cids" ]] && docker stop $(docker ps -qa)
    msg_w_newlines "Removing containers ..."
    docker container prune -f
    msg_w_newlines "Removing volumes ..."
    docker volume prune -f
    msg_w_newlines "Removing networks ..."
    docker network prune -f
  }
}

wipe_docker() {
  run_this_menu_item_handler_in_new_terminal_if_applicable || {
    warning_w_newlines "This will delete ALL local docker artifacts - containers, images, volumes, and networks!"
    confirm_or_exit
    cids="$(docker ps -qa)"
    # shellcheck disable=SC2046
    [[ "$cids" ]] && docker stop $(docker ps -qa)
    msg_w_newlines "Removing containers, images, and volumes ..."
    docker system prune -a -f --volumes
    msg_w_newlines "Removing networks ..."
    docker network prune -f
    msg_w_newlines "Removing MDM config dir"
    rm -rf "$launched_apps_dir"
  }
}

toggle_advanced_mode() {
  if [[ -f "$advanced_mode_flag_file" ]]; then
    rm "$advanced_mode_flag_file"
  else
    touch "$advanced_mode_flag_file"
  fi
}
