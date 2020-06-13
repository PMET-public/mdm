#!/bin/bash

set -e
[[ $debug ]] && set -x

# shellcheck source=../../bin/lib.sh
source ./bin/lib.sh

if ! is_mac; then
  app_name="app-from-repo-test"
  ./bin/dockerize -g https://github.com/PMET-public/magento-cloud.git -b pmet-2.3.5-ref-github -n "$app_name"
  msg_w_newlines "$app_name successfully created."
  app_dir"$(find ~/Downloads -name "$app_name*.app" -type d)"
  "$HOME/Downloads/$app_dir/Contents/Resources/script"
  "$HOME/Downloads/$app_dir/Contents/Resources/script" install_app
else
  warning_w_newlines "Test skipped."
fi

exit 0
