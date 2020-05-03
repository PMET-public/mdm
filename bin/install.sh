#!/bin/bash

set -e # stop on errors

red='\033[0;31m'
green='\033[0;32m'
no_color='\033[0m'

error() {
  printf "\n%b%s%b\n\n" "$red" "$*" "$no_color" 1>&2 && exit 1
}
msg() {
  printf "%b%s%b\n" "$green" "$*" "$no_color"
}

# increase the size & clear the terminal
printf '\e[8;50;140t' && clear

msg "

Once all requirements are installed and validated, this script will not need to run again. (This script will require an admin account.)

"

# install homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
# do not install docker (which is docker toolbox) via brew; use docker for mac instead
brew install bash coreutils
brew upgrade bash coreutils

msg "

Press ANY key to continue to the Docker Desktop For Mac download page. Then download and install that app.

https://hub.docker.com/editions/community/docker-ce-desktop-mac/

"

read -n 1 -s -r -p ""

# open docker for mac installation page
open "https://hub.docker.com/editions/community/docker-ce-desktop-mac/"

msg "

CLI dependencies successfully installed. If you downloaded and installed Docker Desktop for Mac, this script should not need to run again.

You may close this terminal.

"

