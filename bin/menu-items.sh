#!/usr/bin/env bash

# N.B. be wary of colliding (repeating) keys where one is a top level menu item and another is a submenu

declare -A menu

! is_docker_installed && is_docker_compatible && {
  key="▶️ Complete Docker installation by running for first time"
  keys+=("$key")
  menu["$key-handler"]=start_docker
  return 0
}

has_uncleared_jobs_statuses && {
  while read -r key; do
    keys+=("$key")
    menu["$key-handler"]=clear_job_statuses
  done < <(get_job_statuses)
}

! are_additional_tools_installed && {
  key="🔼 Install additional tools for additional features"
  keys+=("$key")
  menu["$key-handler"]=install_additional_tools
}

is_adobe_system && ! is_onedrive_linked && {
  key="🔄 Setup OneDrive -> Click 'Sync' button"
  keys+=("$key")
  menu["$key-link"]="https://adobe.sharepoint.com/sites/SITeam/Shared%20Documents/adobe-internal/docker"
}

is_docker_compatible && {

  is_mac && {

    is_docker_suboptimal && {
      key="🎚 Adjust Docker for minimum requirements"
      keys+=("$key")
      menu["$key-display-condition"]=""
      menu["$key-handler"]=optimize_docker
      return 0
    }

    ! is_docker_running && {
      key="▶️ Start Docker to continue"
      keys+=("$key")
      menu["$key-handler"]=start_docker
      return 0
    }

  }

  ! is_docker_ready && return 0

}

is_update_available && {
  key="🔄 Update MDM"
  keys+=("$key")
  menu["$key-handler"]=update_mdm
}

! is_detached && {

  ! is_app_installed && {
    if is_network_state_ok; then
      key="🔼 Install & open Magento app in browser"
      keys+=("$key")
      menu["$key-handler"]=install_app
    else
      key="⚠️🔼 Can't install. Local ports in use."
      keys+=("$key")
      menu["$key-handler"]=no_op
      menu["$key-disabled"]=true
    fi
  }

  is_app_running && is_network_state_ok && {
    key="🚀 Open Magento app in browser"
    keys+=("$key")
    menu["$key-handler"]=open_app
  }

  is_app_installed && is_app_running && {
    key="🛑 Stop Magento app"
    keys+=("$key")
    menu["$key-handler"]=stop_app
  }

  is_app_installed && ! is_app_running && {
    if is_network_state_ok; then
      key="▶️ Restart Magento app"
      keys+=("$key")
      menu["$key-handler"]=restart_app
    else 
      key="⚠️▶️ Can't restart Magento app. Local ports in use."
      keys+=("$key")
      menu["$key-handler"]=no_op
      menu["$key-disabled"]=true
    fi
  }

  # is_advanced_mode && ! is_app_running && {
  #   key="TODO Sync Magento app to remote env"
  #   keys+=("$key")
  #   menu["$key-handler"]=sync_app_to_remote
  #   menu["$key-disabled"]=true
  # }

  # is_advanced_mode && ! is_app_running && {
  #   key="TODO Clone to new Magento app"
  #   keys+=("$key")
  #   menu["$key-handler"]=clone_app
  #   menu["$key-disabled"]=true
  # }

  is_app_installed && {
    key="🚨 Uninstall this Magento app"
    keys+=("$key")
    menu["$key-handler"]=uninstall_app
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
      key="🛑 App stopped. Many cmds N/A"
      keys+=("$key")
      menu["$key-handler"]=no_op
    }

    key="💻 Start shell in Magento app"
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

    keys+=("end submenu")

  }

  ###
  #
  # end Magento commands submenu
  #
  ###

  is_advanced_mode && {
    key="💻 Start MDM shell"
    keys+=("$key")
    menu["$key-handler"]=start_mdm_shell
  }

  ! is_advanced_mode && {
    key="📝 Show MDM logs"
    keys+=("$key")
    menu["$key-handler"]=show_mdm_logs
  }

  is_docker_compatible && are_other_magento_apps_running && {
    key="🛑 Stop all other Magento apps"
    keys+=("$key")
    menu["$key-handler"]=stop_other_apps
  }

}


if is_network_state_ok; then

  ###
  #
  # start PWA submenu
  #
  ###

  key="PWA"
  keys+=("$key")

  is_docker_compatible && {

    ! is_detached && {
      if is_app_running; then
        key="(Re)start latest PWA using this Magento app"
      else
        key="🛑 App stopped. Start PWA offline"
      fi
      keys+=("$key")
      menu["$key-handler"]=start_pwa_with_app
    }

    key="(Re)start latest PWA using a remote backend"
    keys+=("$key")
    menu["$key-handler"]=start_pwa_with_remote

  }

  # the pwa github repo
  key="Storystore PWA @ GitHub - Docs, Issues, etc."
  keys+=("$key")
  menu["$key-link"]="https://github.com/PMET-public/storystore-pwa/blob/master/README.md"

  keys+=("end submenu")

  ###
  #
  # end PWA subemenu
  #
  ###

else

  key="⚠️ Can't run PWA. Local ports in use."
  keys+=("$key")
  menu["$key-handler"]=no_op
  menu["$key-disabled"]=true

fi

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

keys+=("end submenu")

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

key="About MDM (v. $mdm_version)"
keys+=("$key")
menu["$key-link"]="https://adobe.sharepoint.com/sites/SITeam/SitePages/local-demo-solution-using-docker.aspx"

is_adobe_system && {

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
  menu["$key-link"]="https://fieldreadiness-adobe.highspot.com/spots/5cba1d07659e93677419f707"
} || :

keys+=("end submenu")

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
  menu["$key-link"]="https://htmlpreview.github.io/?https://github.com/PMET-public/mdm/blob/master/docs/magento-cloud-cli-reference.html"

  key="Docker Reference"
  keys+=("$key")
  menu["$key-link"]="https://docs.docker.com/reference/"

  keys+=("end submenu")

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

  key="Show errors from MDM logs"
  keys+=("$key")
  menu["$key-handler"]=show_errors_from_mdm_logs

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

  keys+=("end submenu")

}

###
#
# end logs submenu
#
###

###
#
# start maintenance submenu
#
###

is_advanced_mode && {

  key="Maintenance"
  keys+=("$key")

  if [[ $debug ]]; then
    key="MDM debugging is ON"
  else
    key="MDM debugging is OFF"
  fi
  is_app_running && {
    key+=" (stops running app)"
  }

  keys+=("$key")
  menu["$key-handler"]=toggle_mdm_debug_mode

  key="Force check for new MDM versioon"
  keys+=("$key")
  menu["$key-handler"]=force_check_mdm_ver

  key="Revert to previous MDM"
  keys+=("$key")
  menu["$key-handler"]=revert_to_prev_mdm

  is_docker_compatible && {

    key="Reload reverse proxy"
    keys+=("$key")
    menu["$key-handler"]=reload_rev_proxy

    key="⚠️ Remove Magento images (breaks stopped apps)"
    keys+=("$key")
    menu["$key-handler"]=rm_magento_docker_images

    key="⚠️ Reset Docker (keeps only images)"
    keys+=("$key")
    menu["$key-handler"]=reset_docker

    key="🚨 Wipe Docker (removes everything!!!)"
    keys+=("$key")
    menu["$key-handler"]=wipe_docker

  }

  keys+=("end submenu")

}

###
#
# end maintenance submenu
#
###

if is_advanced_mode; then
  key="💡Advanced mode is ON"
  keys+=("$key")
  menu["$key-handler"]=toggle_advanced_mode
else
  key="○ Advanced mode is OFF"
  keys+=("$key")
  menu["$key-handler"]=toggle_advanced_mode
fi

: # need to return true or will exit when sourced with "-e" and last test = false
