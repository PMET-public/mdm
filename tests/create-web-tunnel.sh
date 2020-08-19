#!/usr/bin/env bash

set -e
# set -x

# shellcheck source=lib.sh
source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/../bin/lib.sh" || :

echo "$TUNNEL_SSH_PK" > "$HOME/pk"

remote_port="$(( $RANDOM + 20000 ))"
network="$(find_bridged_docker_networks)"
local_port="$(find_varnish_port_by_network "$network")"

ssh -i "$HOME/pk" -NR "$remote_port":127.0.0.1:"$local_port" "$TUNNEL_SSH_URL"

