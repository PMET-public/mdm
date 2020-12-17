# Instructions

DO NOT DOWNLOAD APPS FROM THE ONEDRIVE WEB UI. USE FINDER. - Currently, OSX prevents apps downloaded via the web UI from running. We are looking into possible solutions.

Copy any MDM app from your synced OneDrive folder to another local folder like Downloads or Documents.

Double click the local app and look for the Magento icon in your menu bar.


# Frequently Asked Questions

## What's the difference between the "bundled-new" apps and the "cloned" apps?

The "bundled-new" apps have all the composer dependencies bundled with them and will install a new Magento store from the beginning. No composer credentials are required to run, but they will be required to update.

The "cloned" apps represent a snapshot of sample Magento install just after installation has completed. Credentials will be required to run, but because it is a snapshot of an already installed app, the initial start up will be **MUCH faster.**

## What is MDM-lite?

It's a version of MDM with no associated Magento application, so it downloads from OneDrive and starts up almost instantly.

Despite no associated app, MDM-lite still has several uses such as:
- cloning your existing envs instead of using one of the pre-made, generic apps.
- running PWA against remote back-ends
- getting support access for your local systme

