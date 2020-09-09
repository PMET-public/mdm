# Development on a Mac

## 1. clone this repo

```
$ git clone https://github.com/PMET-public/mdm.git && cd mdm
```

## 2. configure additional features

```
cp .mdm_config.tmpl.sh .mdm_config.sh
```

## 3. set up your env

```
$ export debug=1 MDM_REPO_DIR=. COMPOSER_AUTH='{"github-oauth":{"github.com":"..."}}'
```

## Additional troubleshooting notes

To debug the launching script, `export debug_launcher=1`, too. This is currently a separate var because the launching script debugging output would otherwise pollute the menu output before the logging initialization can run. Also, it represents the output of the app's `<osx_appp>/Contents/Resources/script`, not the output of ~/.mdm/current/launcher because it is bundled with the app.  The launcher should not need to be debugged often because it's relatively minimal, stable code to bootstrap the app.

# Development on Linux

Since the included Travis CI and GitHub Workflow configuration use Ubuntu Bionic (18.04) for testing, you will probably also want a local version for faster feedback and debugging.

You can use the default included Vagrantfile. Remember to install the vagrant-diskzie plugin first.

```
$ vagrant plugin install vagrant-disksize
$ vagrant up
$ vagrant ssh
```

In your test vm, there's are just a few remaining setup steps.

## 1. add the default user to the docker group

```
$ sudo apt update && sudo apt upgrade -y
$ sudo apt install docker-compose php -y
$ sudo usermod -aG docker vagrant
$ sudo shutdown -r now
```

## 2. clone this repo

Menu Item|   |
---|----
▶️ Complete Docker installation by running for first time|   |
🔼 Install additional tools for additional features|   |
🔄 Setup OneDrive -> Click 'Sync' button |[link](https://adobe.sharepoint.com/sites/SITeam/Shared%20Documents/adobe-internal/docker)|
🎚 Adjust Docker for minimum requirements|   |
▶️ Start Docker to continue|   |
⚠️ Missing credentials - some features limited |[link](https://devdocs.magento.com/guides/v2.4/install-gde/prereq/dev_install.html#instgde-prereq-compose-clone-auth)|
🔄 Update MDM|   |
🔼 Install & open Magento app in browser|   |
⚠️🔼 Can't install. Local ports in use.|   |
🚀 Open Magento app in browser|   |
🛑 Stop Magento app|   |
▶️ Restart Magento app|   |
⚠️▶️ Can't restart Magento app. Local ports in use.|   |
🚨 Uninstall this Magento app|   |
🛑 Stop all other Magento apps|   |
📦 Create a new Magento app|   |


Magento commands|   |
---|---|---
🛑 App stopped. Many cmds N/A|   |
💻 Start shell in app|   |
Reindex|   |
Run cron jobs|   |
Enable all except cms cache|   |
Enable all caches|   |
Flush cache|   |
Warm cache|   |
Pre-generate resized catalog images|   |
Change url for app|   |
💻 Start MDM shell|   |


Menu Item|   |
---|----
📝 Show MDM logs|   |


PWA|   |
---|---|---
(Re)start latest PWA using this Magento app|   |
🛑 App stopped. Start PWA offline|   |
(Re)start latest PWA using a remote backend|   |
Storystore PWA @ GitHub - Docs, Issues, etc. |[link](https://github.com/PMET-public/storystore-pwa/blob/master/README.md)|

Menu Item|   |
---|----
⚠️ Can't run PWA. Local ports in use.|   |


Help / Support|   |
---|---|---
#m2-demo-support (Magento Org Slack) |[link](slack://channel?team=T016XBMUQLA&id=C018FCG0HHS)
💻 Grant remote access to the system|   |
🛑 Stop remote system access|   |
🔓 Grant remote web access|   |
🛑 Stop remote web access and revert url|   |
#cloud-docker (Magento Community Slack) |[link](slack://channel?team=T4YUW69CM&id=CJ6F3F8NS)
Offical Cloud Support |[link](https://support.magento.com/hc/en-us/requests)|


Useful resources|   |
---|---|---
About MDM |[link](https://adobe.sharepoint.com/sites/SITeam/SitePages/local-demo-solution-using-docker.aspx)|
Docker Folder (OneDrive) |[link](https://adobe.sharepoint.com/sites/SITeam/Shared%20Documents/adobe-internal/docker)|
SI Team Home Page (SharePoint) |[link](https://adobe.sharepoint.com/sites/SITeam/SitePages/home.aspx)|
MDM @ GitHub |[link](https://github.com/pmet-public/mdm)|
Docker development @ devdocs |[link](https://devdocs.magento.com/cloud/docker/docker-development.html)|
Your Magento Cloud Projects |[link](https://demo.magento.cloud/projects/)|
Magento Cloud Chrome Extension |[link](https://github.com/PMET-public/magento-cloud-extension)|
Inside Adobe |[link](https://inside.corp.adobe.com/)|
Field Readiness |[link](https://fieldreadiness-adobe.highspot.com/spots/5cba1d07659e93677419f707)|

Logs|   |
---|---|---
Show errors from MDM logs|   |
Show advanced MDM logs|   |
Show Magento app logs|   |
Show docker-compose logs|   |

Maintenance|   |
---|---|---
🐞 PHP Xdebug is ON for this app|   |
🐞 PHP Xdebug is OFF for this app|   |
🐞 MDM debugging is ON for this app|   |
🐞 MDM debugging is OFF for this app|   |
Force check for new MDM version|   |
Revert to previous MDM|   |
⚠️  🔓 Permit spoofing ANY domain is ON!|   |
⚠️  🔒 Permit spoofing ANY domain is OFF|   |
🔄 Reload reverse proxy|   |
🧹 Remove hostnames added to /etc/hosts file|   |
⚠️  Remove Magento images (breaks stopped apps)|   |
⚠️  Reset Docker (keeps only images)|   |
🚨 Wipe Docker (removes everything!!!)|   |

Menu Item|   |
---|----
💡Advanced mode is ON             (v. $mdm_version)|   |
○ Advanced mode is OFF            (v. $mdm_version)|   |


