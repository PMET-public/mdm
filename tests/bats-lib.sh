#!/usr/bin/env bash

set -e
# set -x

# get the most recently created app dir
get_most_recent_mdm_app() {
  ls -dtr "$HOME/Downloads/"*.app | tail -1 || :
}

post_magento_install_setup() {
  local mdm_app_dir link_prefix="mdm-app-"

  shopt -s nocasematch

  # create links if they have not already been created
  if ! ls "$link_prefix*" > /dev/null 2>&1; then
    mdm_app_dir="$(get_most_recent_mdm_app)"
    [[ "$mdm_app_dir" ]] && {
      app_link_name="mdm-app-$(echo "$mdm_app_dir" | perl -ne '/Downloads\/(.*)\.app/ and print $1')"
      [[ -L "$app_link_name" ]] || {
        ln -sfn "$mdm_app_dir/Contents/Resources/script" "$app_link_name"
        [[ -d "$mdm_app_dir/Contents/Resources/app" ]] && {
          ln -sfn "$mdm_app_dir/Contents/Resources/app" "$app_link_name-dir"
          [[ "$GITHUB_WORKSPACE" ]] && {
            ln -sfn "$GITHUB_WORKSPACE" "$mdm_app_dir/Contents/Resources/app/mdm-dir"
          }
        }
      }
    } || :
  fi
}