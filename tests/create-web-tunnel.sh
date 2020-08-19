#!/usr/bin/env bash

set -e
# set -x

echo "$TUNNEL_SSH_PK" > "$HOME/pk"

remote_port="$(( $RANDOM + 20000 ))"
if [[ "$TUNNEL_LOCAL_PORT" =~ ^[0-9]+$ ]]; then
  local_port="$TUNNEL_LOCAL_PORT"
elif [[ "$TUNNEL_DOCKER_NAME_FILTER" ]]; then
  local_port="$(docker ps -a --filter "name=$TUNNEL_DOCKER_NAME_FILTER" --format "{{.Ports}}" | perl -pe 's/.*://;s/-.*//')"
fi

[[ ! "$local_port" =~ ^[0-9]+$ ]] && echo "Could not find valid local port" && exit 1

ssh -i "$HOME/pk" -NR "$remote_port":127.0.0.1:"$local_port" "$TUNNEL_SSH_URL"

sleep 7200