- [Overview](#overview)
- [MDM End Users](#mdm-end-users)
    - [Top Level Menu Items](#top-level-menu-items)
    - [💻 Magento commands](#-magento-commands)
    - [Top Level Menu Items](#top-level-menu-items-1)
    - [📱 PWA](#-pwa)
    - [Top Level Menu Items](#top-level-menu-items-2)
    - [🚑 Help / Support](#-help--support)
    - [🎗 Useful resources](#-useful-resources)
    - [📝 Logs](#-logs)
    - [🛠 Maintenance](#-maintenance)
    - [Top Level Menu Items](#top-level-menu-items-3)
  - [Frequently Asked Qestions (FAQ)](#frequently-asked-qestions-faq)
    - ["How do I spoof domains?" or "Why is my certificate invalid?"](#how-do-i-spoof-domains-or-why-is-my-certificate-invalid)
    - ["What is the default admin username and password?"](#what-is-the-default-admin-username-and-password)
    - ["How do I setup and where do I place my auth.json file?"](#how-do-i-setup-and-where-do-i-place-my-authjson-file)
    - ["What's auth.json used for?"](#whats-authjson-used-for)
    - ["What does this error mean?"](#what-does-this-error-mean)
    - ["How do I upgrade WITHOUT preserving old installations? (i.e. start over)"](#how-do-i-upgrade-without-preserving-old-installations-ie-start-over)
- [MDM Developers](#mdm-developers)
  - [Recommended IDE & Extensions](#recommended-ide--extensions)
  - [Development on a Mac](#development-on-a-mac)
    - [1. clone this repo](#1-clone-this-repo)
    - [2. configure additional features](#2-configure-additional-features)
    - [3. set up your env](#3-set-up-your-env)
  - [Additional troubleshooting notes](#additional-troubleshooting-notes)
  - [Development on Linux (optional)](#development-on-linux-optional)
    - [1. add the default user to the docker group](#1-add-the-default-user-to-the-docker-group)
    - [2. clone this repo](#2-clone-this-repo)
  - [Application Configuration For Development](#application-configuration-for-development)
    - [Configuration of MDM](#configuration-of-mdm)
    - [Configuration of an MDM app](#configuration-of-an-mdm-app)
  - [Running tests](#running-tests)
  - [Debugging](#debugging)
  - [Publishing releases](#publishing-releases)
  - [Updating the README for menu updates](#updating-the-readme-for-menu-updates)

# Overview

Screenshots of the MDM UI on a Mac (left) and on any terminal - Mac/Linux/Windows (right).

| OSX Menu App | CLI Menu App
|:-:|:-:|
|<img src="imgs/osx-menu.png"> |<img src="imgs/cli-menu.png">|

Magento Docker Manager (MDM) is a cross platform (Mac/Linux/Windows) application to run multiple, simultaneous Magento
applications on your local system via Docker. Once installed, simply select options from the available menu items to
manage your applications.

MDM's menus are **contextual**. Only applicable options are shown. For example, if a tool is not installed, you will
be prompted to install it before continuing to unlock a feature. If the application is stopped, you'll be prompted it
to start it for additional menu options.

MDM has 2 general audiences: 
1. End users who might use the Magento app for demos, testing/QA, or training
2. Developers who want to develop/test locally on a Magento Cloud like env or want to configure a packaged app for
their team of end users

# MDM End Users

End users experience MDM almost entirely through the contextual menus. Below is every possible menu item *(in the 
order they would appear if they are applicable)* with some additional notes if appropiate. If you do not see a particular
menu item, then MDM has determined it's not currently appropiate. Many items only become available after toggling
**Advanced** mode on.

<!--- START AUTOGENERATED MD by markdown-generator-for-menu-items.sh --->

### Top Level Menu Items 

|Top Level Menu Items|   |   |
|:---|:-:|:--|
|⚠️▶️ Docker not installed. Click for download. |[link]($docker_install_link)|Complete the install by running Docker for the 1st time to reveal more menu items.|
|▶️ Finish Docker install by running for the 1st time.|   |Finish the install by running Docker for the 1st time and revealing more menu items.|
|🔼 Install added tools for more features|   |Highly recommended - includes the magento-cloud CLI, mkcert, tmate, platypus, docker CLI completion|
|🎚 Adjust Docker for min reqs|   |Update the docker vm settings for better performance.|
|▶️ Start Docker to continue|   |Docker is not running. Start it.|
|⚠️ Missing credentials - features limited|   |MDM can not find your `~/.composer/auth.json` file. You won't be able to create new apps from source or use features tied to your GitHub org configuration, but a prepackaged app will work. The link to doc shows how to create it.|
|⚠️ Credentials found but invalid|   |Your `~/.composer/auth.json` file exists, but the JSON contents aren't parsing correctly OR it doesn't have the required GitHub token & Magento keys. Please verify its contents.|
|👉 🔄 Update MDM 👈|   |There is a new version of MDM available. Under *Maintenance*, there is an option to revert if needed.|
|🔼 Install & open Magento app|   |   |
|⚠️🔼 Can't install - ports in use.|   |Some local service other than docker is using port 80 or 443.|
|🚀 Open https://$(get_hostname_for_this_app)|   |Opens your browser to the app's base url. The menu will render the base url instead of the function call. You'll actually see something like: '🚀 Open https://mysite.com'|
|🛑 Stop Magento app|   |If not actively being using, stopping the app will free memory.|
|▶️ Restart Magento app|   |   |
|⚠️▶️ Can't restart app - ports in use.|   |   |
|🚨 Uninstall this Magento app|   |If an error occurred during install, this option allows you to try again.|
|🛑 Stop all other Magento apps|   |While multiple Magento apps can run at the same time, it may consume many resources.|
|📦 Create new MDM app|   |Asks for a Magento Cloud project to recreate locally|
|☁️→💻 Sync FROM cloud env|   |   |
|💻→☁️ Sync TO cloud env|   |   |
|<nobr>                  </nobr>|<nobr>   </nobr>|   |

<!--- # start Magento commands submenu --->
### 💻 Magento commands 

|💻 Magento commands|   |   |
|:---|:-:|:--|
|🛑 App stopped. Many cmds N/A|   |Start Magento to reveal more options|
|💻 Start shell in app|   |   |
|Reindex|   |   |
|Run cron jobs|   |   |
|Enable all except cms cache|   |   |
|Enable all caches|   |   |
|Flush cache|   |   |
|Warm cache|   |   |
|Pre-generate resized catalog images|   |   |
|Change url for app|   |Use ANY url for your app. Combine with certificate spoofing for better browser compatibility.|
|💻 Start MDM shell|   |*Advanced* See the status of your Docker services|
|<nobr>                  </nobr>|<nobr>   </nobr>|   |
<!--- # end Magento commands submenu --->

### Top Level Menu Items 

|Top Level Menu Items|   |   |
|:---|:-:|:--|
|📝 Open MDM logging|   |*Advanced* Watch the MDM output in realtime. Combine with MDM debugging under *Maintenance*|
|<nobr>                  </nobr>|<nobr>   </nobr>|   |

<!--- # start PWA submenu --->
### 📱 PWA 

|📱 PWA|   |   |
|:---|:-:|:--|
|📱 This app|   |The PWA will use the local Magento app as the backend.|
|🛑 App stopped. Start PWA offline|   |   |
|📲 Choose your own|   |   |
|🎗 Storystore PWA @ GitHub |[link](https://github.com/PMET-public/storystore-pwa/blob/master/README.md)|   |
|<nobr>                  </nobr>|<nobr>   </nobr>|   |
<!--- # end PWA submenu --->

### Top Level Menu Items 

|Top Level Menu Items|   |   |
|:---|:-:|:--|
|⚠️ Can't run PWA - ports in use.|   |A local service is already using the required ports.|
|<nobr>                  </nobr>|<nobr>   </nobr>|   |

<!--- # start Help / Support submenu --->
### 🚑 Help / Support 

|🚑 Help / Support|   |   |
|:---|:-:|:--|
|Magento Org #m2-demo-support |[link](slack://channel?team=T016XBMUQLA&id=C018FCG0HHS)|link to slack channel|
|💻 Grant remote access to system|   |Only remote users with pre-authorized keys will be able to connect *1* time. If not configured, a warning appears. Choose if you want to continue and provide the secret url to a remote user.|
|🛑 Stop remote system access|   |   |
|🔓 Grant remote web access|   |If configured, creates a public url able to access this Magento app.|
|🛑 Stop remote web access; revert url|   |   |
|Magento Community #cloud-docker |[link](slack://channel?team=T4YUW69CM&id=CJ6F3F8NS)|link to slack channel|
|Offical Cloud Support |[link](https://support.magento.com/hc/en-us/requests)|   |
|<nobr>                  </nobr>|<nobr>   </nobr>|   |
<!--- # end Help/Support submenu --->


<!--- # start Useful resources submenu --->
### 🎗 Useful resources 

|🎗 Useful resources|   |   |
|:---|:-:|:--|
|MDM @ GitHub |[link](https://github.com/pmet-public/mdm)|This project|
|Docker Folder (OneDrive) |[link](https://adobe.sharepoint.com/sites/SITeam/Shared%20Documents/adobe-internal/docker)|   |
|SI Team Home Page (SharePoint) |[link](https://adobe.sharepoint.com/sites/SITeam/SitePages/home.aspx)|   |
|Docker development @ devdocs |[link](https://devdocs.magento.com/cloud/docker/docker-development.html)|The project that MDM builds on to mimic Magento Cloud services|
|Your Magento Cloud Projects |[link](https://demo.magento.cloud/projects/)|   |
|Magento Cloud Chrome Extension |[link](https://github.com/PMET-public/magento-cloud-extension)|   |
|Inside Adobe |[link](https://inside.corp.adobe.com/)|   |
|Field Readiness |[link](https://fieldreadiness-adobe.highspot.com/spots/5cba1d07659e93677419f707)|   |
|<nobr>                  </nobr>|<nobr>   </nobr>|   |
<!--- # end Useful resources submenu --->


<!--- # start logs submenu --->
### 📝 Logs 

|📝 Logs|   |*Advanced*|
|:---|:-:|:--|
|Show errors from MDM log|   |Show just the recorded errors|
|Follow MDM logs|   |   |
|Show Magento app logs|   |   |
|<nobr>                  </nobr>|<nobr>   </nobr>|   |
<!--- # end logs submenu --->


<!--- # start maintenance submenu --->
### 🛠 Maintenance 

|🛠 Maintenance|   |*Advanced*|
|:---|:-:|:--|
|🐞 PHP Xdebug is ON\|OFF for this app|   |Turn on|off php debugging|
|🐞 MDM debugging is ON\|OFF for this app|   |Turn on|off debugging of MDM - much more info written to the logs|
|Force check for new MDM version|   |   |
|Revert to previous MDM|   |   |
|⚠️  🔓 Permit spoofing ANY domain is ON\|OFF!|   |Create TLS certificates that are valid *locally* for any domain. Do not share your local CA!|
|🔄 Reload reverse proxy|   |   |
|🧹 Remove hosts added to /etc/hosts|   |   |
|🧹 Prune all unused docker images|   |Removes old or currently unused Docker images. If no apps are currently installed, Docker will re-download the required images during installation.|
|⚠️  Prune all non-running containers and volumes|   |Deletes ANY installation that is not ACTIVELY RUNNING. This will remove any installation that you can not currently browse.|
|⚠️  Prune everything EXCEPT images|   |This will delete ALL docker containers, volumes, and networks. ONLY Docker images will be preserved to avoid re-downloading images for new installations.|
|🚨 Wipe Docker (removes ALL Docker artifacts)|   |Use this to wipe the Docker virtual machine of all data. Only modified Docker VM settings will be preserved.|
|<nobr>                  </nobr>|<nobr>   </nobr>|   |
<!--- # end maintenance submenu --->

### Top Level Menu Items 

|Top Level Menu Items|   |   |
|:---|:-:|:--|
|💡Advanced mode is ON\|OFF         (v. $v)|   |Show more advanced menu items and display the current version of MDM|
|<nobr>                  </nobr>|<nobr>   </nobr>|   |
<!--- END AUTOGENERATED MD by markdown-generator-for-menu-items.sh --->


## Frequently Asked Qestions (FAQ)

### "How do I spoof domains?" or "Why is my certificate invalid?"

By default, the option to "spoof" (mimic) any domain is disabled. You should not enable it on a computer that you share or allow others access too. If a malicious user gains access to your system, they might use it to spoof legitimate domains. With that caveat, it's still very useful. To enable it, enable advance mode, then go to the maintenance menu, then toggle the spoofing option on.

### "What is the default admin username and password?"

The values are inherited from the Magento Cloud Docker project [here](https://github.com/magento/magento-cloud-docker/blob/bc964b272b6c40e2b1b2c8832ef56d40182cbd99/src/Config/Dist/Generator.php#L183)

### "How do I setup and where do I place my auth.json file?"

Follow the instructions [here](https://devdocs.magento.com/guides/v2.4/install-gde/prereq/dev_install.html#instgde-prereq-compose-clone-auth) with 1 clarification: place your `auth.json` file in your `~/.composer/` directory so the full, explicit path will be: `/Users/<yourusername>/.composer/auth.json` on OSX or `/home/<yourusername>/.composer/auth.json` on Linux systems.

Note for OSX users: You will not see the `.composer` dir in your user (Home) dir in `Finder` unless you press **⌘ (command) + shift + . (dot)**. Also be careful that the editor used to create your `auth.json` file does not insert special characters (e.g. curly quotes for double quotes). MDM will attempt to validate the format of `auth.json` and report if it detects such errors.

### "What's auth.json used for?"

You may have downloaded or received a pre-bundled app with all the required modules, but if you need/want to run `composer update` to get future updates OR you want to create your own app, you will need an `auth.json` file. Also the GitHub token in the `auth.json` file is used to configure/download additional features of MDM (e.g. valid wildcard TLS certificates, web tunneling, etc.)

### "What does this error mean?"

Whichever error you encounter, please check (i.e. search) to see if your [issue](https://github.com/PMET-public/mdm/issues?q=is%3Aissue) has already been reported and possibly solved. If not, please open a new one.

### "How do I upgrade WITHOUT preserving old installations? (i.e. start over)"

In a terminal, run `rm -rf ~/.mdm` and the follow any instructions from the MDM menu afterward. Then ensure advanced mode is toggled on to see the maintenance menu. From the maintenance menu, prune everything except images. The Docker VM is now cleaned from old installs, and you can also remove any old MDM apps from the host computer.

---

# MDM Developers

## Recommended IDE & Extensions

IDE: [VSC](https://code.visualstudio.com/download)

IDE Extensions:
1. [Bash Debug](https://github.com/rogalmic/vscode-bash-debug)
1. [BASH IDE](https://github.com/bash-lsp/bash-language-server)
1. [Bats](https://github.com/jetmartin/bats)
1. [shellcheck](https://github.com/timonwong/vscode-shellcheck)

The included `.vscode/launch.json` has some useful debug scenarios pre-configured that you can use to step through.


## Development on a Mac

### 1. clone this repo

```
$ git clone https://github.com/PMET-public/mdm.git && cd mdm
```

### 2. configure additional features

```
cp .mdm_config.tmpl.sh .mdm_config.sh
```

### 3. set up your env

```
$ export debug=1 MDM_REPO_DIR=. COMPOSER_AUTH='{"github-oauth":{"github.com":"..."}}'
```

## Additional troubleshooting notes

To debug the launching script, run `export debug_launcher=1`, too. This is currently a separate var because the launching script debug output would otherwise display (and disrupt) the menu output before the logging initialization can run. Also, the launching script debug output (bundled with each app) is the output of the app's `<osx_appp>/Contents/Resources/script`, not the output of `~/.mdm/current/launcher`.  The launcher should not need to be debugged often because it's relatively minimal, stable code to bootstrap the app.

## Development on Linux (optional)

Since the included Travis CI and GitHub Workflow configuration use Ubuntu Bionic (18.04) for testing, you will probably also want a local version for faster feedback and debugging.

You can use the default included Vagrantfile. Remember to install the vagrant-diskzie plugin first.

```
$ vagrant plugin install vagrant-disksize
$ vagrant up
$ vagrant ssh
```

In your test vm, there's are just a few remaining setup steps.

### 1. add the default user to the docker group

```
$ sudo apt update && sudo apt upgrade -y
$ sudo apt install docker-compose php -y
$ sudo usermod -aG docker vagrant
$ sudo shutdown -r now
```

### 2. clone this repo

## Application Configuration For Development

### Configuration of MDM
|Feature|Config Param|
|-|---|
| Public Certs |`mdm_domain`|
| |`mdm_domain_fullchain_gh_url`|
| |`mdm_domain_privkey_gh_url`|
| | |
| Remote Support/Access |`mdm_tmate_authorized_keys_url`|
| | |
| Public Web Access|`mdm_tunnel_domain`|
| |`mdm_tunnel_ssh_url`|
| |`mdm_tunnel_pk_url`|

### Configuration of an MDM app

## Running tests

MDM uses [Bats](https://github.com/bats-core/bats-core) for testing. You'll find all tests in the numbered subdirectories of `tests`.

Example #1: Call all tests in all immediate subdirectories of the specified one and show test timings.
```
./tests/libs/bats/bin/bats -T ./tests/1-generic-lib-and-non-app-specific/**/*.bats
```

Example #2: Call all tests recursively for the specified dir and show test timings.
```
./tests/libs/bats/bin/bats -T -r ./tests/2-dockerize-then-run-detached-app
```

See `.gitub/workflows` for additional example invocations. 

## Debugging

A VSCode launch file (`.vscode/launch.json`) containing many debugging examples is included. Stepping through example debug configurations is a great way to become familiar with the control flow of MDM.

## Publishing releases

MDM checks the [releases](https://github.com/PMET-public/mdm/releases) page for the version of the most recent release. If that release is a newer semantic version, the user will be prompted to update. This system will need to be updated at some point if there are multiple major & minor releases.

## Updating the README for menu updates

Part of this README is auto generated by script. When menu items are changed, the script should be re-run and the output paste into this file.