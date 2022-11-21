#! /usr/bin/env bash

auth_json_path="$HOME/.composer/auth.json.less-privileged"

./bin/dockerize -d

# ./bin/dockerize -s -p xy4itwbmg2khk -e master -n "ref-cloned" -i "$HOME/.mdm/current/icons/ref.icns"
# ./bin/dockerize -s -p a6terwtbk67os -e master -n "demo-cloned" -i "$HOME/.mdm/current/icons/demo.icns"
# ./bin/dockerize -s -p a6terwtbk67os -e grocery-freshmarket -n "demo-w-grocery-cloned" -i "$HOME/.mdm/current/icons/demo.icns"
# ./bin/dockerize -s -p unkfuvjhn2nss -e master -n "b2b-cloned" -i "$HOME/.mdm/current/icons/b2b.icns"


for version in 2.4.5; do
  for flavor in ref demo b2b; do
    ./bin/dockerize -g "git@github.com:pmet-public/magento-cloud.git" -b "pmet-$version-$flavor" -n "$flavor-bundled-new" -a "$auth_json_path" -i "$HOME/.mdm/current/icons/$flavor.icns"
  done
done
