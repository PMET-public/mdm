#!/usr/bin/env bash

# N.B. be wary of colliding (repeating) keys where one is a top level menu item and another is a submenu
# TODO - ^why? key collision with different values? need to document this note better

declare -A mdm_menu_items

! is_docker_installed && is_docker_compatible && {
  key="▶️ Complete Docker installation by running for first time"
  mdm_menu_items_keys+=("$key")
  mdm_menu_items["$key-handler"]=start_docker
  return 0
}

has_uncleared_jobs_statuses && {
  while read -r key; do
    mdm_menu_items_keys+=("$key")
    mdm_menu_items["$key-handler"]=clear_job_statuses
  done < <(get_job_statuses)
}

! are_additional_tools_installed && {
  key="🔼 Install additional tools for additional features"
  mdm_menu_items_keys+=("$key")
  mdm_menu_items["$key-handler"]=install_additional_tools
}

is_adobe_system && ! is_onedrive_linked && {
  key="🔄 Setup OneDrive -> Click 'Sync' button"
  mdm_menu_items_keys+=("$key")
  mdm_menu_items["$key-link"]="https://adobe.sharepoint.com/sites/SITeam/Shared%20Documents/adobe-internal/docker"
}

is_docker_compatible && {

  is_mac && {

    is_docker_suboptimal && {
      key="🎚 Adjust Docker for minimum requirements"
      mdm_menu_items_keys+=("$key")
      mdm_menu_items["$key-display-condition"]=""
      mdm_menu_items["$key-handler"]=optimize_docker
      return 0
    }

  }

  ! is_docker_running && {
    key="▶️ Start Docker to continue"
    mdm_menu_items_keys+=("$key")
    mdm_menu_items["$key-handler"]=start_docker
    return 0
  }

  ! is_docker_ready && return 0

  has_valid_composer_auth || {
    key="⚠️ Missing credentials - some features limited"
    mdm_menu_items_keys+=("$key")
    mdm_menu_items["$key-link"]="https://devdocs.magento.com/guides/v2.4/install-gde/prereq/dev_install.html#instgde-prereq-compose-clone-auth"
  }

}

is_update_available && {
  key="🔄 Update MDM"
  mdm_menu_items_keys+=("$key")
  mdm_menu_items["$key-handler"]=update_mdm
}

! is_detached && {

  ! is_magento_app_installed && {
    if is_network_state_ok; then
      key="🔼 Install & open Magento app in browser"
      mdm_menu_items_keys+=("$key")
      mdm_menu_items["$key-handler"]=install_app
    else
      key="⚠️🔼 Can't install. Local ports in use."
      mdm_menu_items_keys+=("$key")
      mdm_menu_items["$key-handler"]=no_op
      mdm_menu_items["$key-disabled"]=true
    fi
  }

  is_magento_app_running && is_network_state_ok && {
    key="🚀 Open Magento app in browser"
    mdm_menu_items_keys+=("$key")
    mdm_menu_items["$key-handler"]=open_app
  }

  is_magento_app_installed && is_magento_app_running && {
    key="🛑 Stop Magento app"
    mdm_menu_items_keys+=("$key")
    mdm_menu_items["$key-handler"]=stop_app
  }

  is_magento_app_installed && ! is_magento_app_running && {
    if is_network_state_ok; then
      key="▶️ Restart Magento app"
      mdm_menu_items_keys+=("$key")
      mdm_menu_items["$key-handler"]=restart_app
    else 
      key="⚠️▶️ Can't restart Magento app. Local ports in use."
      mdm_menu_items_keys+=("$key")
      mdm_menu_items["$key-handler"]=no_op
      mdm_menu_items["$key-disabled"]=true
    fi
  }

  # is_advanced_mode && ! is_magento_app_running && {
  #   key="TODO Sync Magento app to remote env"
  #   mdm_menu_items_keys+=("$key")
  #   mdm_menu_items["$key-handler"]=sync_app_to_remote
  #   mdm_menu_items["$key-disabled"]=true
  # }

  # is_advanced_mode && ! is_magento_app_running && {
  #   key="TODO Clone to new Magento app"
  #   mdm_menu_items_keys+=("$key")
  #   mdm_menu_items["$key-handler"]=clone_app
  #   mdm_menu_items["$key-disabled"]=true
  # }

  is_magento_app_installed && {
    key="🚨 Uninstall this Magento app"
    mdm_menu_items_keys+=("$key")
    mdm_menu_items["$key-handler"]=uninstall_app
  }
}

is_docker_compatible && are_other_magento_apps_running && {
  key="🛑 Stop all other Magento apps"
  mdm_menu_items_keys+=("$key")
  mdm_menu_items["$key-handler"]=stop_other_apps
}

is_docker_compatible && has_valid_composer_auth && {
  key="📦 Create a new Magento app"
  mdm_menu_items_keys+=("$key")
  mdm_menu_items["$key-handler"]=dockerize_app
}

! is_detached && {
  ###
  #
  # start Magento commands submenu
  #
  ###

  is_magento_app_installed && {
    key="Magento commands"
    mdm_menu_items_keys+=("$key")

    ! is_magento_app_running && {
      key="🛑 App stopped. Many cmds N/A"
      mdm_menu_items_keys+=("$key")
      mdm_menu_items["$key-handler"]=no_op
    }

    key="💻 Start shell in app"
    mdm_menu_items_keys+=("$key")
    mdm_menu_items["$key-handler"]=start_shell_in_app

    is_magento_app_running && {

      key="Reindex"
      mdm_menu_items_keys+=("$key")
      mdm_menu_items["$key-handler"]=reindex

      key="Run cron jobs"
      mdm_menu_items_keys+=("$key")
      mdm_menu_items["$key-handler"]=run_cron

      key="Enable all except cms cache"
      mdm_menu_items_keys+=("$key")
      mdm_menu_items["$key-handler"]=enable_all_except_cms_cache

      key="Enable all caches"
      mdm_menu_items_keys+=("$key")
      mdm_menu_items["$key-handler"]=enable_all_caches

      # key="Disable most caches"
      # mdm_menu_items_keys+=("$key")
      # mdm_menu_items["$key-handler"]=disable_most_caches

      key="Flush cache"
      mdm_menu_items_keys+=("$key")
      mdm_menu_items["$key-handler"]=flush_cache

      key="Warm cache"
      mdm_menu_items_keys+=("$key")
      mdm_menu_items["$key-handler"]=warm_cache

      key="Pre-generate resized catalog images"
      mdm_menu_items_keys+=("$key")
      mdm_menu_items["$key-handler"]=resize_images

      key="Change url for app"
      mdm_menu_items_keys+=("$key")
      mdm_menu_items["$key-handler"]=change_base_url

    }

    # key="Switch to production mode"
    # mdm_menu_items_keys+=("$key")
    # mdm_menu_items["$key-handler"]=switch_to_production_mode

    # key="Switch to developer mode"
    # mdm_menu_items_keys+=("$key")
    # mdm_menu_items["$key-handler"]=switch_to_developer_mode

    is_advanced_mode && {
      key="💻 Start MDM shell"
      mdm_menu_items_keys+=("$key")
      mdm_menu_items["$key-handler"]=start_mdm_shell
    }

    mdm_menu_items_keys+=("end submenu")

  }

  ###
  #
  # end Magento commands submenu
  #
  ###

  ! is_advanced_mode && {
    key="📝 Show MDM logs"
    mdm_menu_items_keys+=("$key")
    mdm_menu_items["$key-handler"]=show_mdm_logs
  }
}


if is_network_state_ok; then

  ###
  #
  # start PWA submenu
  #
  ###

  key="PWA"
  mdm_menu_items_keys+=("$key")

  is_docker_compatible && {

    ! is_detached && is_pwa_module_installed && {
      if is_magento_app_running; then
        key="(Re)start latest PWA using this Magento app"
      else
        key="🛑 App stopped. Start PWA offline"
      fi
      mdm_menu_items_keys+=("$key")
      mdm_menu_items["$key-handler"]=start_pwa_with_app
    }

    key="(Re)start latest PWA using a remote backend"
    mdm_menu_items_keys+=("$key")
    mdm_menu_items["$key-handler"]=start_pwa_with_remote

  }

  # the pwa github repo
  key="Storystore PWA @ GitHub - Docs, Issues, etc."
  mdm_menu_items_keys+=("$key")
  mdm_menu_items["$key-link"]="https://github.com/PMET-public/storystore-pwa/blob/master/README.md"

  mdm_menu_items_keys+=("end submenu")

  ###
  #
  # end PWA subemenu
  #
  ###

else

  key="⚠️ Can't run PWA. Local ports in use."
  mdm_menu_items_keys+=("$key")
  mdm_menu_items["$key-handler"]=no_op
  mdm_menu_items["$key-disabled"]=true

fi

###
#
# start Help / Support submenu
#
###

key="Help / Support"
mdm_menu_items_keys+=("$key")

is_adobe_system && {
  key="#m2-demo-support (Magento Org Slack)"
  mdm_menu_items_keys+=("$key")
  mdm_menu_items["$key-link"]="slack://channel?team=T016XBMUQLA&id=C018FCG0HHS"
}

is_tmate_installed && {
  key="💻 Remote access to the system"
  mdm_menu_items_keys+=("$key")
  mdm_menu_items["$key-handler"]=start_tmate_session

  key="🛑💻 Stop remote system access"
  mdm_menu_items_keys+=("$key")
  mdm_menu_items["$key-handler"]=stop_tmate_session
}

is_web_tunnel_configured && {
  key="🔓 Remote web access to the app"
  mdm_menu_items_keys+=("$key")
  mdm_menu_items["$key-handler"]=start_remote_web_access

  key="🛑🔓 Stop remote web access"
  mdm_menu_items_keys+=("$key")
  mdm_menu_items["$key-handler"]=stop_remote_web_access
}

key="#cloud-docker (Magento Community Slack)"
mdm_menu_items_keys+=("$key")
mdm_menu_items["$key-link"]="slack://channel?team=T4YUW69CM&id=CJ6F3F8NS"

key="Offical Cloud Support"
mdm_menu_items_keys+=("$key")
mdm_menu_items["$key-link"]="https://support.magento.com/hc/en-us/requests"

# key=""
# mdm_menu_items_keys+=("$key")
# mdm_menu_items["$key-link"]=""

mdm_menu_items_keys+=("end submenu")

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
mdm_menu_items_keys+=("$key")

key="About MDM"
mdm_menu_items_keys+=("$key")
mdm_menu_items["$key-link"]="https://adobe.sharepoint.com/sites/SITeam/SitePages/local-demo-solution-using-docker.aspx"
is_adobe_system && {

  key="Docker Folder (OneDrive)"
  mdm_menu_items_keys+=("$key")
  mdm_menu_items["$key-link"]="https://adobe.sharepoint.com/sites/SITeam/Shared%20Documents/adobe-internal/docker"

  key="SI Team Home Page (SharePoint)"
  mdm_menu_items_keys+=("$key")
  mdm_menu_items["$key-link"]="https://adobe.sharepoint.com/sites/SITeam/SitePages/home.aspx"
}

key="MDM @ GitHub"
mdm_menu_items_keys+=("$key")
mdm_menu_items["$key-link"]="https://github.com/pmet-public/mdm"

key="Docker development @ devdocs"
mdm_menu_items_keys+=("$key")
mdm_menu_items["$key-link"]="https://devdocs.magento.com/cloud/docker/docker-development.html"

key="Your Magento Cloud Projects"
mdm_menu_items_keys+=("$key")
mdm_menu_items["$key-link"]="https://demo.magento.cloud/projects/"

is_adobe_system && {
  key="Magento Cloud Chrome Extension"
  mdm_menu_items_keys+=("$key")
  mdm_menu_items["$key-link"]="https://github.com/PMET-public/magento-cloud-extension"

  key="Inside Adobe"
  mdm_menu_items_keys+=("$key")
  mdm_menu_items["$key-link"]="https://inside.corp.adobe.com/"

  key="Field Readiness"
  mdm_menu_items_keys+=("$key")
  mdm_menu_items["$key-link"]="https://fieldreadiness-adobe.highspot.com/spots/5cba1d07659e93677419f707"
} || :

mdm_menu_items_keys+=("end submenu")

###
#
# end Useful resources submenu
#
###

###
#
# start logs submenu
#
###

is_advanced_mode && {

  key="Logs"
  mdm_menu_items_keys+=("$key")

  key="Show errors from MDM logs"
  mdm_menu_items_keys+=("$key")
  mdm_menu_items["$key-handler"]=show_errors_from_mdm_logs

  key="Show advanced MDM logs"
  mdm_menu_items_keys+=("$key")
  mdm_menu_items["$key-handler"]=show_mdm_logs

  is_magento_app_installed && {
    key="Show Magento app logs"
    mdm_menu_items_keys+=("$key")
    mdm_menu_items["$key-handler"]=show_app_logs
  }

  key="Show docker-compose logs"
  mdm_menu_items_keys+=("$key")
  mdm_menu_items["$key-handler"]=show_mdm_logs

  mdm_menu_items_keys+=("end submenu")

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
  mdm_menu_items_keys+=("$key")

  # this option only applies to a specific app so should not appear when testing from a repo dir
  if lib_sourced_for_specific_bundled_app; then

    if [[ "$notsetyet" ]]; then
      key="🐞 PHP Xdebug is ON for this app"
    else
      key="🐞 PHP Xdebug is OFF for this app"
    fi
    mdm_menu_items_keys+=("$key")
    mdm_menu_items["$key-handler"]=toggle_xdebug

    if [[ "$debug" ]]; then
      key="🐞 MDM debugging is ON for this app"
    else
      key="🐞 MDM debugging is OFF for this app"
    fi
    is_magento_app_running && {
      key+=" (stops running app)"
    }
    mdm_menu_items_keys+=("$key")
    mdm_menu_items["$key-handler"]=toggle_mdm_debug_mode
  fi

  key="Force check for new MDM version"
  mdm_menu_items_keys+=("$key")
  mdm_menu_items["$key-handler"]=force_check_mdm_ver

  key="Revert to previous MDM"
  mdm_menu_items_keys+=("$key")
  mdm_menu_items["$key-handler"]=revert_to_prev_mdm

  if is_mkcert_CA_installed; then
    key="⚠️  🔓 Permit spoofing ANY domain is ON!"
    mdm_menu_items_keys+=("$key")
    mdm_menu_items["$key-handler"]=toggle_mkcert_CA_install
  else
    key="⚠️  🔒 Permit spoofing ANY domain is OFF"
    mdm_menu_items_keys+=("$key")
    mdm_menu_items["$key-handler"]=toggle_mkcert_CA_install
  fi

  is_docker_compatible && { # meaning currently n/a on CI/CD on mac

    key="🔄 Reload reverse proxy"
    mdm_menu_items_keys+=("$key")
    mdm_menu_items["$key-handler"]=reload_rev_proxy

    key="🧹 Remove hostnames added to /etc/hosts file"
    mdm_menu_items_keys+=("$key")
    mdm_menu_items["$key-handler"]=rm_added_hostnames_from_hosts_file

    key="⚠️  Remove Magento images (breaks stopped apps)"
    mdm_menu_items_keys+=("$key")
    mdm_menu_items["$key-handler"]=rm_magento_docker_images

    key="⚠️  Reset Docker (keeps only images)"
    mdm_menu_items_keys+=("$key")
    mdm_menu_items["$key-handler"]=reset_docker

    key="🚨 Wipe Docker (removes everything!!!)"
    mdm_menu_items_keys+=("$key")
    mdm_menu_items["$key-handler"]=wipe_docker

  }

  mdm_menu_items_keys+=("end submenu")

}

###
#
# end maintenance submenu
#
###

if is_advanced_mode; then
  key="💡Advanced mode is ON             (v. $mdm_version)"
  mdm_menu_items_keys+=("$key")
  mdm_menu_items["$key-handler"]=toggle_advanced_mode
else
  key="○ Advanced mode is OFF            (v. $mdm_version)"
  mdm_menu_items_keys+=("$key")
  mdm_menu_items["$key-handler"]=toggle_advanced_mode
fi

: # need to return true or will exit when sourced with "-e" and last test = false
