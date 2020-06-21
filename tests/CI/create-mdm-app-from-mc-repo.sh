#!/bin/bash

set -e
[[ $debug ]] && set -x
unset apps_resources_dir

# shellcheck source=../../bin/lib.sh
source ./bin/lib.sh

if ! is_mac; then
  app_name="app-from-repo-test"
  ./bin/dockerize -g https://github.com/PMET-public/magento-cloud.git -b pmet-2.3.5-ref-github -n "$app_name"
  msg_w_newlines "$app_name successfully created."
  # find newly create app
  app_dir="$(find "$HOME/Downloads" -name "$app_name*.app" -type d)"
  app_dir="${app_dir#$HOME/Downloads/}"
  
  # invoke it emulating platypus app method
  export apps_resources_dir="$HOME/Downloads/$app_dir/Contents/Resources"
  run_bundled_app_as_script
  env
  docker-compose -v
  echo "pwd"
  pwd
  docker stats --no-stream --no-trunc
  free -m 
  run_bundled_app_as_script install_app || :
  docker ps -a
  # run_bundled_app_as_script start_mdm_shell
  # echo "subprocesses: ";
  # pgrep -aP $$ || :
  # echo "subprocesses #2: "; 
  # ps -o time,pid,ppid,cmd --forest -g -p $(pgrep -x bash)
  docker-compose logs || :
  export_compose_file
  export_compose_project_name
  docker-compose logs
else
  warning_w_newlines "Test skipped."
fi

exit 0
