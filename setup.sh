#!/usr/bin/env bash
set -euo pipefail

COMPOSE="podman compose --env-file src/.env \
  -f src/01-networks.yaml \
  -f src/02-traefik-cloudflared.yaml \
  -f src/03-authelia.yaml \
  -f src/05-vaultwarden.yaml \
  -f src/06-immich.yaml"

# Toggle: if any stack container is running, bring it down; otherwise bring it up.
if podman ps --format '{{.Names}}' | grep -qE '^(traefik|authelia|immich-server|cloudflared)$'; then
  echo "Stack is up — bringing it down..."
  $COMPOSE down
  echo "Stack is down."
  exit 0
fi

echo "Stack is down — bringing it up..."

# Bring the full stack up in detached mode
$COMPOSE up -d

# podman-compose leaves services whose depends_on conditions haven't yet passed
# in Created state rather than starting them automatically. Poll until all
# health-gated dependencies are satisfied, then start any remaining Created containers.
echo "Waiting for dependencies and starting any services left in Created state..."
for i in $(seq 1 30); do
  created=$(podman ps -a --format '{{.Names}}\t{{.Status}}' \
    | awk -F'\t' '$2 ~ /^Created/ {print $1}')
  [ -z "$created" ] && break
  echo "$created" | xargs -r podman start 2>/dev/null || true
  sleep 3
done

echo "Stack is up."
