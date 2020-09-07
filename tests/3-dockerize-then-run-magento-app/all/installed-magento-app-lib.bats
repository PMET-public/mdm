#!/usr/bin/env ./tests/libs/bats/bin/bats

# bats will loop indefinitely with debug mode on (i.e. set -x)
unset debug

load '../../libs/bats-assert/load'
load '../../libs/bats-support/load'
load '../../libs/bats-file/load'

load '../../../bin/lib.sh'

# this E2E test can 
# - test MDM itself using a specified magento-cloud project (default: PMET-public/magento-cloud) on a specified branch (default: master)
# - test a magento-cloud repo on its current commit and the specified ref of MDM
# - test a change to a dependency of a magento-cloud project and/or MDM


setup() {
  shopt -s nocasematch
  # get the most recently created app dir
  app_dir="$(ls -dtr "$HOME"/Downloads/*.app | tail -1 || :)"
  export apps_resources_dir="$app_dir/Contents/Resources"
}

@test 'get_hostname_for_this_app' {
  run get_hostname_for_this_app
  assert_success
  assert_output -e "tunnel"
}

# adjust_compose_project_name_for_docker_compose_version
# get_compose_project_name
# export_compose_project_name
# export_compose_file
# set_hostname_for_this_app
# get_pwa_hostname
# get_pwa_prev_hostname
# export_pwa_hostnames
# ensure_mdm_log_files_exist

# included_by_mdm
# has_uncleared_jobs_statuses
# is_magento_cloud_cli_installed
# is_docker_bash_completion_installed
# are_additional_tools_installed
# is_docker_running
# is_onedrive_linked
# is_detached
# is_magento_app_installed
# is_magento_app_running
# is_pwa_module_installed
# is_nginx_rev_proxy_running
# is_network_state_ok
# are_other_magento_apps_running
# invoked_mdm_without_args
# lib_sourced_for_specific_bundled_app
# is_update_available
# is_adobe_system
# is_existing_cloud_env
# launched_from_mac_menu
# is_running_as_sudo
# has_valid_composer_auth
# seconds_since
# get_docker_host_ip
# print_containers_hosts_file_entry
# print_local_hosts_file_entry
# find_bridged_docker_networks
# find_varnish_port_by_network
# find_web_service_hostname_by_network
# find_mdm_hostnames
# find_hostnames_not_resolving_to_local
# has_valid_wildcard_domain
# run_this_menu_item_handler_in_new_terminal_if_applicable
# track_job_status_and_wait_for_exit
# restart_docker_and_wait
# reload_rev_proxy
# get_docker_compose_runtime_services
# render_platypus_status_menu
# handle_mdm_args
# run_bundled_app_as_script
# init_app_specific_vars
# init_mdm_logging
# init_mac_quit_detection
# download_mdm_config
