#!/bin/bash

# This file contains configuration for various features of MDM

mdm_domain="your-domain.com"

# wildcard cert for your app plus related key
# (e.g. letsencrypt artifacts in private repo that ~/.composer/auth.json has access to via github api key)
mdm_domain_fullchain_gh_url="https://github.com/your-org/your-config-project/blob/master/your-domain.com/fullchain1.pem"
mdm_domain_privkey_gh_url="https://github.com/your-org/your-config-project/blob/master/your-domain.com/fullchain1.pem"


# url to the public authorized keys that should be allowed to connect to a tmate remote support session
mdm_tmate_authorized_keys_url="https://raw.githubusercontent.com/your-org/public-keys/master/authorized_keys"


# remote browsing via ssh Tunneling (similar to ngrok)
mdm_tunnel_domain="tunnel.your-domain.com"
mdm_tunnel_ssh_url="restricted-user@tunnel.your-domain.com"

# url to retrieve the private key that an end user should have access to that authorizes the restricted ssh user above
mdm_tunnel_pk_url="https://github.com/your-org/your-config-project/blob/master/id_rsa.restricted-user"

