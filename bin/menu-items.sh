#!/usr/bin/env bash

# N.B. be wary of colliding (repeating) keys where one is a top level menu item and another is a submenu

# icons from https://material.io/resources/icons/

is_dark_mode() {
  [[ "$(defaults read -g AppleInterfaceStyle 2> /dev/null)" == "Dark" ]]
}

icon_color=$(is_dark_mode && echo "white" || echo "black")

declare -A menu

! is_docker_installed && {
  key="Complete Docker installation by running for first time"
  keys+=("$key")
  menu["$key-handler"]=start_docker
  menu["$key-icon"]="ic_play_arrow_${icon_color}_48dp.png"
  return
}

has_status_msg && {
  key="$(show_status)"
  keys+=("$key")
  menu["$key-handler"]=clear_status
  # if status is disabled (i.e. still running), no icon. otherwise, show completed check mark
  [[ "$key" =~ ^DISABLED ]] || menu["$key-icon"]="ic_check_${icon_color}_48dp.png"
}

! has_additional_tools && {
  key="Install additional tools for additional features"
  keys+=("$key")
  menu["$key-handler"]=install_additional_tools
  menu["$key-icon"]="ic_present_to_all_${icon_color}_48dp.png"
}

is_adobe_system && ! is_onedrive_linked && {
  key="Setup OneDrive -> Click 'Sync' button"
  keys+=("$key")
  menu["$key-link"]="https://adobe.sharepoint.com/sites/SITeam/Shared%20Documents/adobe-internal/docker"
  menu["$key-icon"]="ic_sync_${icon_color}_48dp.png"
}

is_docker_suboptimal && {
  key="Optimize Docker for better performance"
  keys+=("$key")
  menu["$key-display-condition"]=""
  menu["$key-handler"]=optimize_docker
  menu["$key-icon"]="baseline_speed_${icon_color}_48dp.png"
}

! is_docker_running && {
  key="Start Docker to continue"
  keys+=("$key")
  menu["$key-handler"]=start_docker
  menu["$key-icon"]="ic_play_arrow_${icon_color}_48dp.png"
}

is_update_available && {
  key="Update MDM"
  keys+=("$key")
  menu["$key-handler"]=update_mdm
  menu["$key-icon"]="ic_system_update_alt_${icon_color}_48dp.png"
}

! is_app_installed && {
  if is_network_state_ok; then
    key="Install & open Magento app in browser"
    keys+=("$key")
    menu["$key-handler"]=install_app
    menu["$key-icon"]="ic_present_to_all_${icon_color}_48dp.png"
    # menu["$key-icon"]="ic_publish_${icon_color}_48dp.png"
  else
    key="Can't install. Local ports in use."
    keys+=("$key")
    menu["$key-handler"]=no_op
    menu["$key-icon"]="ic_present_to_all_${icon_color}_48dp.png"
    # menu["$key-icon"]="ic_publish_${icon_color}_48dp.png"
    menu["$key-disabled"]=true
  fi
}

is_app_running && {
  key="Open Magento app in browser"
  keys+=("$key")
  menu["$key-handler"]=open_app
  menu["$key-icon"]="ic_launch_${icon_color}_48dp.png"
}

is_app_installed && is_app_running && {
  key="Stop Magento app"
  keys+=("$key")
  menu["$key-handler"]=stop_app
  menu["$key-icon"]="ic_stop_${icon_color}_48dp.png"
}

is_app_installed && ! is_app_running && {
  if is_network_state_ok; then
    key="Restart Magento app"
    keys+=("$key")
    menu["$key-handler"]=restart_app
    menu["$key-icon"]="ic_play_arrow_${icon_color}_48dp.png"
  else 
    key="Can't restart Magento app. Local ports in use."
    keys+=("$key")
    menu["$key-handler"]=no_op
    menu["$key-icon"]="ic_play_arrow_${icon_color}_48dp.png"
    menu["$key-disabled"]=true
  fi
}

is_advanced_mode && ! is_app_running && {
  key="TODO Sync Magento app to remote env"
  keys+=("$key")
  menu["$key-handler"]=sync_app_to_remote
  menu["$key-icon"]="ic_sync_${icon_color}_48dp.png"
  menu["$key-disabled"]=true
}

is_advanced_mode && ! is_app_running && {
  key="TODO Clone to new Magento app"
  keys+=("$key")
  menu["$key-handler"]=clone_app
  menu["$key-icon"]="ic_content_copy_${icon_color}_48dp.png"
  menu["$key-disabled"]=true
}

is_app_installed && {
  key="Uninstall this Magento app"
  keys+=("$key")
  menu["$key-handler"]=uninstall_app
  menu["$key-icon"]="ic_delete_${icon_color}_48dp.png"
}

###
#
# start Magento commands submenu
#
###

is_app_installed && {
  key="Magento commands"
  keys+=("$key")

  ! is_app_running && {
    key="Warning: 🛑 App is stopped."
    keys+=("$key")
    menu["$key-handler"]=no_op
  }

  key="Start shell in Magento app"
  keys+=("$key")
  menu["$key-handler"]=start_shell_in_app

  is_app_running && {
    key="Reindex"
    keys+=("$key")
    menu["$key-handler"]=reindex

    key="Run cron jobs"
    keys+=("$key")
    menu["$key-handler"]=run_cron

    key="Enable all except cms cache"
    keys+=("$key")
    menu["$key-handler"]=enable_all_except_cms_cache

    key="Enable all caches"
    keys+=("$key")
    menu["$key-handler"]=enable_all_caches

    key="Disable most caches"
    keys+=("$key")
    menu["$key-handler"]=disable_most_caches

    key="Flush Cache"
    keys+=("$key")
    menu["$key-handler"]=flush_cache

    key="Warm Cache"
    keys+=("$key")
    menu["$key-handler"]=warm_cache
  }

  key="Pre-generate resized catalog images"
  keys+=("$key")
  menu["$key-handler"]=resize_images

  # key="Switch to production mode"
  # keys+=("$key")
  # menu["$key-handler"]=switch_to_production_mode

  # key="Switch to developer mode"
  # keys+=("$key")
  # menu["$key-handler"]=switch_to_developer_mode

}

###
#
# end Magento commands submenu
#
###

is_advanced_mode && {
  key="Start MDM shell"
  keys+=("$key")
  menu["$key-handler"]=start_mdm_shell
  menu["$key-icon"]="ic_code_${icon_color}_48dp.png"
}

! is_advanced_mode && {
  key="Show MDM logs"
  keys+=("$key")
  menu["$key-handler"]=show_mdm_logs
  menu["$key-icon"]="ic_subject_${icon_color}_48dp.png"
}

are_other_magento_apps_running && {
  key="Stop all other Magento apps"
  keys+=("$key")
  menu["$key-handler"]=stop_other_apps
  menu["$key-icon"]="ic_stop_${icon_color}_48dp.png"
}


###
#
# start Help / Support submenu
#
###

key="Help / Support"
keys+=("$key")

is_adobe_system && {
  key="#m2-demo-support (Magento Org Slack)"
  keys+=("$key")
  menu["$key-link"]="slack://channel?team=T025FJ55H&id=C0MQZ62DV"
}

key="#cloud-docker (Magento Community Slack)"
keys+=("$key")
menu["$key-link"]="slack://channel?team=T4YUW69CM&id=CJ6F3F8NS"

key="Offical Cloud Support"
keys+=("$key")
menu["$key-link"]="https://support.magento.com/hc/en-us/requests"

# key=""
# keys+=("$key")
# menu["$key-link"]=""

###
#
# end Help/Support submenu
#
###

###
#
# start Useful resources submenu
#
###

key="Useful resources"
keys+=("$key")

is_adobe_system && {

  key="About MDM (ver. $mdm_version)"
  keys+=("$key")
  menu["$key-link"]="https://adobe.sharepoint.com/sites/SITeam/SitePages/local-demo-solution-using-docker.aspx"

  key="Docker Folder (OneDrive)"
  keys+=("$key")
  menu["$key-link"]="https://adobe.sharepoint.com/sites/SITeam/Shared%20Documents/adobe-internal/docker"

  key="SI Team Home Page (SharePoint)"
  keys+=("$key")
  menu["$key-link"]="https://adobe.sharepoint.com/sites/SITeam/SitePages/home.aspx"
}

key="MDM @ GitHub"
keys+=("$key")
menu["$key-link"]="https://github.com/pmet-public/mdm"

key="Docker development @ devdocs"
keys+=("$key")
menu["$key-link"]="https://devdocs.magento.com/cloud/docker/docker-development.html"

key="Your Magento Cloud Projects"
keys+=("$key")
menu["$key-link"]="https://demo.magento.cloud/projects/"

is_adobe_system && {
  key="Magento Cloud Chrome Extension"
  keys+=("$key")
  menu["$key-link"]="https://github.com/PMET-public/magento-cloud-extension"

  key="Inside Adobe"
  keys+=("$key")
  menu["$key-link"]="https://inside.corp.adobe.com/"

  key="Field Readiness"
  keys+=("$key")
  menu["$key-link"]="https://fieldreadiness-adobe.highspot.com/"
} || :

###
#
# end Useful resources submenu
#
###

###
#
# start CLI references
#
###

is_advanced_mode && {

  key="CLI refences"
  keys+=("$key")

  key="Magento CLI commands"
  keys+=("$key")
  menu["$key-link"]="https://htmlpreview.github.io/?https://github.com/PMET-public/mdm/blob/master/docs/magento-cli-reference.html"

  key="Magento Cloud CLI commands"
  keys+=("$key")
  menu["$key-link"]="https://htmlpreview.github.io/?https://github.com/PMET-public/mdm/blob/master/docs/magento-cli-reference.html"

  key="Docker CLI commands"
  keys+=("$key")
  menu["$key-link"]="https://htmlpreview.github.io/?https://github.com/PMET-public/mdm/blob/master/docs/magento-cli-reference.html"

  key="Docker-compose CLI commands"
  keys+=("$key")
  menu["$key-link"]="https://htmlpreview.github.io/?https://github.com/PMET-public/mdm/blob/master/docs/magento-cli-reference.html"

}

###
#
# end cli references
#
###

###
#
# start logs submenu
#
###

is_advanced_mode && {

  key="Logs"
  keys+=("$key")

  key="Show advanced MDM logs"
  keys+=("$key")
  menu["$key-handler"]=show_mdm_logs

  is_app_installed && {
    key="Show Magento app logs"
    keys+=("$key")
    menu["$key-handler"]=show_app_logs
  }

  key="Show docker-compose logs"
  keys+=("$key")
  menu["$key-handler"]=show_mdm_logs

}

###
#
# end logs submenu
#
###

is_advanced_mode && {
  key="TODO Restart MDM with debugging enabled"
  keys+=("$key")
  menu["$key-handler"]=sync_app_to_remote
  menu["$key-icon"]="ic_sync_${icon_color}_48dp.png"
  menu["$key-disabled"]=true
}

is_advanced_mode && {
  key="Advanced mode is ON"
  keys+=("$key")
  menu["$key-handler"]=toggle_advanced_mode
  menu["$key-icon"]="outline_toggle_on_${icon_color}_48dp.png"
}

! is_advanced_mode && {
  key="Advanced mode is OFF"
  keys+=("$key")
  menu["$key-handler"]=toggle_advanced_mode
  menu["$key-icon"]="outline_toggle_off_${icon_color}_48dp.png"
}

: # need to return true or will exit when sourced with "-e" and last test = false
