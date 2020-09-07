#!/usr/bin/env bash

set -e
# set -x

post_magento_install_setup() {
  shopt -s nocasematch
  # get the most recently created app dir
  app_dir="$(ls -dtr "$HOME"/Downloads/*.app | tail -1 || :)"
  app_link_name="mdm-app-$(echo "$app_dir" | perl -ne '/Downloads\/(.*)\.app/ and print $1')"
  [[ -L "$app_link_name" ]] || {
    ln -sfn "$app_dir/Contents/Resources/script" "$app_link_name"
    ln -sfn "$app_dir/Contents/Resources/app" "$app_link_name-dir"
    if [[ "$GITHUB_WORKSPACE" ]]; then
      ln -sfn "$GITHUB_WORKSPACE" "$app_dir/Contents/Resources/app/mdm-dir"
    fi
  }
}