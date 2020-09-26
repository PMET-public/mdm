#!/usr/bin/env bash

# N.B.
# 1. be wary of colliding (repeating) keys where one is a top level menu item and another is a submenu
# TODO - ^why? key collision with different values? need to document this note better
# 2. the submenu heading are used to help generate documentation


declare -A mdm_menu_items

is_docker_compatible && {
  ! is_docker_installed && {
    key="⚠️▶️ Docker not installed. Click for download."
    description="Complete the install by running Docker for the 1st time to reveal more menu items."
    mdm_menu_items_keys+=("$key")
    mdm_menu_items["$key-link"]="$docker_install_link"
    return 0
  }
  is_mac && ! is_docker_initialized_on_mac && {
    key="▶️ Finish Docker install by running for the 1st time."
    description="Finish the install by running Docker for the 1st time and revealing more menu items."
    mdm_menu_items_keys+=("$key")
    mdm_menu_items["$key-handler"]=start_docker
    return 0
  }
}

has_uncleared_jobs_statuses && {
  while read -r key; do
    mdm_menu_items_keys+=("$key")
    mdm_menu_items["$key-handler"]=clear_job_statuses
  done < <(get_job_statuses)
}

! are_additional_tools_installed && {
  key="🔼 Install added tools for more features"
  description="Highly recommended - includes the magento-cloud CLI, mkcert, tmate, platypus, docker CLI completion"
  mdm_menu_items_keys+=("$key")
  mdm_menu_items["$key-handler"]=install_additional_tools
}

is_docker_compatible && {

  is_mac && {

    ! are_docker_settings_optimized && {
      key="🎚 Adjust Docker for min reqs"
      description="Update the docker vm settings for better performance."
      mdm_menu_items_keys+=("$key")
      mdm_menu_items["$key-display-condition"]=""
      mdm_menu_items["$key-handler"]=optimize_docker
      return 0
    }

  }

  ! is_docker_running_cached && {
    key="▶️ Start Docker to continue"
    description="Docker is not running. Start it."
    mdm_menu_items_keys+=("$key")
    mdm_menu_items["$key-handler"]=start_docker
    return 0
  }

  has_valid_composer_credentials_cached || {
    if [[ ! -f "$HOME/.composer/auth.json" ]]; then
      key="⚠️ Missing credentials - features limited"
      description="MDM can not find your \`~/.composer/auth.json\` file. You won't be able to create new apps from source or use features tied to your GitHub org configuration, but a prepackaged app will work. The link to doc shows how to create it."
    else
      key="⚠️ Credentials found but invalid"
      description="Your \`~/.composer/auth.json\` file exists, but the JSON contents aren't parsing correctly OR it doesn't have the required GitHub token & Magento keys. Please verify its contents."
    fi
    mdm_menu_items_keys+=("$key")
    mdm_menu_items["$key-link"]="https://devdocs.magento.com/guides/v2.4/install-gde/prereq/dev_install.html#instgde-prereq-compose-clone-auth"
  }

}

is_update_available && {
  key="🔄 Update MDM"
  description="There is a new version of MDM available. Under *Maintenance*, there is an option to revert if needed."
  mdm_menu_items_keys+=("$key")
  mdm_menu_items["$key-handler"]=update_mdm
}

! is_detached && {

  ! is_magento_app_installed_cached && {
    if is_network_state_ok; then
      key="🔼 Install & open Magento app"
      description=""
      mdm_menu_items_keys+=("$key")
      mdm_menu_items["$key-handler"]=install_app
    else
      key="⚠️🔼 Can't install - ports in use."
      description="Some local service other than docker is using port 80 or 443."
      mdm_menu_items_keys+=("$key")
      mdm_menu_items["$key-handler"]=no_op
      mdm_menu_items["$key-disabled"]=true
    fi
  }

  is_magento_app_running_cached && is_network_state_ok && {
    key="🚀 Open https://$(get_hostname_for_this_app)"
    description="Opens your browser to the app's base url. The menu will render the base url instead of the function call. You'll actually see something like: '🚀 Open https://mysite.com'"
    mdm_menu_items_keys+=("$key")
    mdm_menu_items["$key-handler"]=open_app
  }

  is_magento_app_installed_cached && is_magento_app_running_cached && {
    key="🛑 Stop Magento app"
    description="If not actively being using, stopping the app will free memory."
    mdm_menu_items_keys+=("$key")
    mdm_menu_items["$key-handler"]=stop_app
  }

  is_magento_app_installed_cached && ! is_magento_app_running_cached && {
    if is_network_state_ok; then
      key="▶️ Restart Magento app"
      description=""
      mdm_menu_items_keys+=("$key")
      mdm_menu_items["$key-handler"]=restart_app
    else 
      key="⚠️▶️ Can't restart app - ports in use."
      description=""
      mdm_menu_items_keys+=("$key")
      mdm_menu_items["$key-handler"]=no_op
      mdm_menu_items["$key-disabled"]=true
    fi
  }

  # is_advanced_mode && ! is_magento_app_running_cached && {
  #   key="TODO Sync Magento app to remote env"
  #   description=""
  #   mdm_menu_items_keys+=("$key")
  #   mdm_menu_items["$key-handler"]=sync_app_to_remote
  #   mdm_menu_items["$key-disabled"]=true
  # }

  # is_advanced_mode && ! is_magento_app_running_cached && {
  #   key="TODO Clone to new Magento app"
  #   description=""
  #   mdm_menu_items_keys+=("$key")
  #   mdm_menu_items["$key-handler"]=clone_app
  #   mdm_menu_items["$key-disabled"]=true
  # }

  is_magento_app_installed_cached && {
    key="🚨 Uninstall this Magento app"
    description="If an error occurred during install, this option allows you to try again."
    mdm_menu_items_keys+=("$key")
    mdm_menu_items["$key-handler"]=uninstall_app
  }
}

is_docker_compatible && are_other_magento_apps_running && {
  key="🛑 Stop all other Magento apps"
  description="While multiple Magento apps can run at the same time, it may consume many resources."
  mdm_menu_items_keys+=("$key")
  mdm_menu_items["$key-handler"]=stop_other_apps
}

is_docker_compatible && has_valid_composer_credentials_cached && {
  key="📦 Create a new Magento app"
  description="Asks for a Magento Cloud project to recreate locally"
  mdm_menu_items_keys+=("$key")
  mdm_menu_items["$key-handler"]=dockerize_app
}

! is_detached && {

  ###
  #
  # start Magento commands submenu
  #
  ###

  is_magento_app_installed_cached && {
    key="Magento commands"
    description=""
    mdm_menu_items_keys+=("$key")

    ! is_magento_app_running_cached && {
      key="🛑 App stopped. Many cmds N/A"
      description="Start Magento to reveal more options"
      mdm_menu_items_keys+=("$key")
      mdm_menu_items["$key-handler"]=no_op
    }

    key="💻 Start shell in app"
    description=""
    mdm_menu_items_keys+=("$key")
    mdm_menu_items["$key-handler"]=start_shell_in_app

    is_magento_app_running_cached && {

      key="Reindex"
      description=""
      mdm_menu_items_keys+=("$key")
      mdm_menu_items["$key-handler"]=reindex

      key="Run cron jobs"
      description=""
      mdm_menu_items_keys+=("$key")
      mdm_menu_items["$key-handler"]=run_cron

      key="Enable all except cms cache"
      description=""
      mdm_menu_items_keys+=("$key")
      mdm_menu_items["$key-handler"]=enable_all_except_cms_cache

      key="Enable all caches"
      description=""
      mdm_menu_items_keys+=("$key")
      mdm_menu_items["$key-handler"]=enable_all_caches

      # key="Disable most caches"
      # description=""
      # mdm_menu_items_keys+=("$key")
      # mdm_menu_items["$key-handler"]=disable_most_caches

      key="Flush cache"
      description=""
      mdm_menu_items_keys+=("$key")
      mdm_menu_items["$key-handler"]=flush_cache

      key="Warm cache"
      description=""
      mdm_menu_items_keys+=("$key")
      mdm_menu_items["$key-handler"]=warm_cache

      key="Pre-generate resized catalog images"
      description=""
      mdm_menu_items_keys+=("$key")
      mdm_menu_items["$key-handler"]=resize_images

      key="Change url for app"
      description="Use ANY url for your app. Combine with certificate spoofing for better browser compatibility."
      mdm_menu_items_keys+=("$key")
      mdm_menu_items["$key-handler"]=change_base_url

    }

    # key="Switch to production mode"
    # description=""
    # mdm_menu_items_keys+=("$key")
    # mdm_menu_items["$key-handler"]=switch_to_production_mode

    # key="Switch to developer mode"
    # description=""
    # mdm_menu_items_keys+=("$key")
    # mdm_menu_items["$key-handler"]=switch_to_developer_mode

    is_advanced_mode && {
      key="💻 Start MDM shell"
      description="*Advanced* See the status of your Docker services"
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
    description="*Advanced* Watch the MDM output in realtime. Combine with MDM debugging under *Maintenance*"
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
  description=""
  mdm_menu_items_keys+=("$key")

  is_docker_compatible && {

    ! is_detached && is_pwa_module_installed && {
      if is_magento_app_running_cached; then
        key="(Re)start PWA using this Magento app"
        description="The PWA will use the local Magento app as the backend."
      else
        key="🛑 App stopped. Start PWA offline"
        description=""
      fi
      mdm_menu_items_keys+=("$key")
      mdm_menu_items["$key-handler"]=start_pwa_with_app
    }

    key="(Re)start PWA using a remote backend"
    description=""
    mdm_menu_items_keys+=("$key")
    mdm_menu_items["$key-handler"]=start_pwa_with_remote

  }

  # the pwa github repo
  key="Storystore PWA @ GitHub"
  description=""
  mdm_menu_items_keys+=("$key")
  mdm_menu_items["$key-link"]="https://github.com/PMET-public/storystore-pwa/blob/master/README.md"

  mdm_menu_items_keys+=("end submenu")

  ###
  #
  # end PWA submenu
  #
  ###

else

  key="⚠️ Can't run PWA - ports in use."
  description="A local service is already using the required ports."
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
description=""
mdm_menu_items_keys+=("$key")

is_adobe_system && {
  key="Magento Org #m2-demo-support"
  description="link to slack channel"
  mdm_menu_items_keys+=("$key")
  mdm_menu_items["$key-link"]="slack://channel?team=T016XBMUQLA&id=C018FCG0HHS"
}

is_tmate_installed && {
  key="💻 Grant remote access to system"
  description="Only remote users with pre-authorized keys will be able to connect *1* time. If not configured, a warning appears. Choose if you want to continue and provide the secret url to a remote user."
  mdm_menu_items_keys+=("$key")
  mdm_menu_items["$key-handler"]=start_tmate_session

  key="🛑 Stop remote system access"
  description=""
  mdm_menu_items_keys+=("$key")
  mdm_menu_items["$key-handler"]=stop_tmate_session
}

is_magento_app_running_cached && is_web_tunnel_configured && {
  key="🔓 Grant remote web access"
  description="If configured, creates a public url able to access this Magenot app."
  mdm_menu_items_keys+=("$key")
  mdm_menu_items["$key-handler"]=start_remote_web_access

  key="🛑 Stop remote web access; revert url"
  description=""
  mdm_menu_items_keys+=("$key")
  mdm_menu_items["$key-handler"]=stop_remote_web_access
}

key="Magento Community #cloud-docker"
description="link to slack channel"
mdm_menu_items_keys+=("$key")
mdm_menu_items["$key-link"]="slack://channel?team=T4YUW69CM&id=CJ6F3F8NS"

key="Offical Cloud Support"
description=""
mdm_menu_items_keys+=("$key")
mdm_menu_items["$key-link"]="https://support.magento.com/hc/en-us/requests"

# key=""
# description=""
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
description=""
mdm_menu_items_keys+=("$key")

# key="About MDM"
# description=""
# mdm_menu_items_keys+=("$key")
# mdm_menu_items["$key-link"]="https://adobe.sharepoint.com/sites/SITeam/SitePages/local-demo-solution-using-docker.aspx"

key="MDM @ GitHub"
description="This project"
mdm_menu_items_keys+=("$key")
mdm_menu_items["$key-link"]="https://github.com/pmet-public/mdm"

is_adobe_system && {

  key="Docker Folder (OneDrive)"
  description=""
  mdm_menu_items_keys+=("$key")
  mdm_menu_items["$key-link"]="https://adobe.sharepoint.com/sites/SITeam/Shared%20Documents/adobe-internal/docker"

  key="SI Team Home Page (SharePoint)"
  description=""
  mdm_menu_items_keys+=("$key")
  mdm_menu_items["$key-link"]="https://adobe.sharepoint.com/sites/SITeam/SitePages/home.aspx"
}

key="Docker development @ devdocs"
description="The project that MDM builds on to mimic Magento Cloud services"
mdm_menu_items_keys+=("$key")
mdm_menu_items["$key-link"]="https://devdocs.magento.com/cloud/docker/docker-development.html"

key="Your Magento Cloud Projects"
description=""
mdm_menu_items_keys+=("$key")
mdm_menu_items["$key-link"]="https://demo.magento.cloud/projects/"

is_adobe_system && {
  key="Magento Cloud Chrome Extension"
  description=""
  mdm_menu_items_keys+=("$key")
  mdm_menu_items["$key-link"]="https://github.com/PMET-public/magento-cloud-extension"

  key="Inside Adobe"
  description=""
  mdm_menu_items_keys+=("$key")
  mdm_menu_items["$key-link"]="https://inside.corp.adobe.com/"

  key="Field Readiness"
  description=""
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
  description="*Advanced*"
  mdm_menu_items_keys+=("$key")

  key="Show errors from MDM log"
  description="Show just the recorded errors"
  mdm_menu_items_keys+=("$key")
  mdm_menu_items["$key-handler"]=show_errors_from_mdm_logs

  key="Show entire MDM log"
  description=""
  mdm_menu_items_keys+=("$key")
  mdm_menu_items["$key-handler"]=show_mdm_logs

  is_magento_app_installed_cached && {
    key="Show Magento app logs"
    description=""
    mdm_menu_items_keys+=("$key")
    mdm_menu_items["$key-handler"]=show_app_logs
  }

  # key="Show docker-compose logs"
  # description=""
  # mdm_menu_items_keys+=("$key")
  # mdm_menu_items["$key-handler"]=show_mdm_logs

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
  description="*Advanced*"
  mdm_menu_items_keys+=("$key")

  # this option only applies to a specific app so should not appear when testing from a repo dir
  if lib_sourced_for_specific_bundled_app; then

    if [[ "$notsetyet" ]]; then
      key="🐞 PHP Xdebug is ON for this app"
      description="Turn on|off php debugging"
    else
      key="🐞 PHP Xdebug is OFF for this app"
      description=""
    fi
    mdm_menu_items_keys+=("$key")
    mdm_menu_items["$key-handler"]=toggle_xdebug

    launched_from_mac_menu_cached && {
      if [[ "$debug" ]]; then
        key="🐞 MDM debugging is ON for this app"
        description="Turn on|off debugging of MDM - much more info written to the logs"
      else
        key="🐞 MDM debugging is OFF for this app"
        description=""
      fi
      is_magento_app_running_cached && {
        key+=" (stops running app)"
      }
      mdm_menu_items_keys+=("$key")
      mdm_menu_items["$key-handler"]=toggle_mdm_debug_mode
    }
  fi

  key="Force check for new MDM version"
  description=""
  mdm_menu_items_keys+=("$key")
  mdm_menu_items["$key-handler"]=force_check_mdm_ver

  key="Revert to previous MDM"
  description=""
  mdm_menu_items_keys+=("$key")
  mdm_menu_items["$key-handler"]=revert_to_prev_mdm

  if is_mkcert_CA_installed; then
    key="⚠️  🔓 Permit spoofing ANY domain is ON!"
    description="Create TLS certificates that are valid *locally* for any domain. Do not share your local CA!"
    mdm_menu_items_keys+=("$key")
    mdm_menu_items["$key-handler"]=toggle_mkcert_CA_install
  else
    key="⚠️  🔒 Permit spoofing ANY domain is OFF"
    description=""
    mdm_menu_items_keys+=("$key")
    mdm_menu_items["$key-handler"]=toggle_mkcert_CA_install
  fi

  is_docker_compatible && { # meaning currently n/a on CI/CD on mac

    key="🔄 Reload reverse proxy"
    description=""
    mdm_menu_items_keys+=("$key")
    mdm_menu_items["$key-handler"]=reload_rev_proxy

    key="🧹 Remove hosts added to /etc/hosts"
    description=""
    mdm_menu_items_keys+=("$key")
    mdm_menu_items["$key-handler"]=rm_added_hostnames_from_hosts_file

    # can this be removed now that docker pull is being used each time?
    key="🧹 Prune all unused docker images"
    description="Removes old or currently unused Docker images. If no apps are currently installed, Docker will re-download the required images during installation."
    mdm_menu_items_keys+=("$key")
    mdm_menu_items["$key-handler"]=docker_prune_all_images

    key="⚠️  Prune all non-running containers and volumes"
    description="Deletes ANY installation that is not ACTIVELY RUNNING. This will remove any installation that you can not currently browse."
    mdm_menu_items_keys+=("$key")
    mdm_menu_items["$key-handler"]=docker_prune_all_stopped_containers_and_volumes

    key="⚠️  Prune everything EXCEPT images"
    description="This will delete ALL docker containers, volumes, and networks. ONLY Docker images will be preserved to avoid re-downloading images for new installations."
    mdm_menu_items_keys+=("$key")
    mdm_menu_items["$key-handler"]=reset_docker

    key="🚨 Wipe Docker (removes ALL Docker artifacts)"
    description="Use this to wipe the Docker virtual machine of all data. Only modified Docker VM settings will be preserved."
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
tmp_var_if_used="$v"; v="$mdm_version" # for MD formatting
if is_advanced_mode; then
  key="💡Advanced mode is ON         (v. $v)"
  description="Show more advanced menu items and display the current version of MDM"
  mdm_menu_items_keys+=("$key")
  mdm_menu_items["$key-handler"]=toggle_advanced_mode
else
  key="○ Advanced mode is OFF        (v. $v)"
  description=""
  mdm_menu_items_keys+=("$key")
  mdm_menu_items["$key-handler"]=toggle_advanced_mode
fi
v="$tmp_var_if_used";

: # need to return true or will exit when sourced with "-e" and last test = false
