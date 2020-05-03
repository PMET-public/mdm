#!/bin/bash

set -e # stop on errors
set -x # turn on debugging

read -r -p $'\033[0;31mThis script is for testing on new systems only and should not ordinarily be run. ARE YOU SURE?? (y/n) \033[0m'
if [[ $REPLY =~ ^[Yy]$ ]]; then
  echo "Removing magento-cloud CLI"
  rm -rf ~/.magento-cloud || :
  echo "Removing homebrew"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/uninstall.sh)" || :
  echo "Removing xcode tools"
  sudo rm -rf /Library/Developer/CommandLineTools || :
  echo "Removing docker"
  sudo rm -rf /Applications/Docker.app || :
fi
