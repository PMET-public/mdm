#!/usr/bin/env bash

set -e
# set -x

echo "$TUNNEL_SSH_PK" > "$HOME/pk"
chmod 600 "$HOME/pk"

remote_port="$(( $RANDOM + 20000 ))" # RANDOM is between 0-32767 (2^16 / 2 - 1)
if [[ "$TUNNEL_LOCAL_PORT" =~ ^[0-9]+$ ]]; then
  local_port="$TUNNEL_LOCAL_PORT"
elif [[ "$TUNNEL_DOCKER_NAME_FILTER" ]]; then
  # all local docker host 5 digit ports: 
  #   docker ps -a --format "{{.Ports}}" | tr ',' '\n' | perl -ne "s/.*:(?=\d{5})// and s/-.*// and print"
  local_port="$(docker ps -a --filter "name=$TUNNEL_DOCKER_NAME_FILTER" --format "{{.Ports}}" | perl -pe 's/.*://;s/-.*//')"
fi

[[ ! "$local_port" =~ ^[0-9]+$ ]] && echo "Could not find valid local port" && exit 1

# port forwarding only in background, fail if can't forward
ssh -f \
  -F /dev/null \
  -o IdentitiesOnly=yes \
  -o ExitOnForwardFailure=yes \
  -o StrictHostKeyChecking=no \
  -i "$HOME/pk" \
  -NR "$remote_port":127.0.0.1:"$local_port" \
  "$TUNNEL_SSH_URL"

sleep 7200