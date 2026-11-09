#!/usr/bin/env bash
set -euo pipefail
for script in deploy/demo/*.sh; do bash -n "$script"; done
shellcheck deploy/demo/*.sh
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
ENV_FILE="$tmp/demo.env" sh deploy/demo/generate-env.sh ci.example.test
grep -q '^PAYPAL_RETURN_BASE_URL=https://api.ci.example.test$' "$tmp/demo.env"
before=$(sha256sum "$tmp/demo.env")
if ENV_FILE="$tmp/demo.env" sh deploy/demo/generate-env.sh different.example.test; then
  echo 'generate-env must refuse to overwrite existing credentials' >&2; exit 1
fi
[[ "$(sha256sum "$tmp/demo.env")" == "$before" ]]
for overlay in demo ci; do
  args=(-f docker-compose.yml -f deploy/demo/docker-compose.demo.yml)
  [[ "$overlay" == ci ]] && args+=(-f deploy/demo/docker-compose.ci.yml)
  DEPLOY_TAG=validation docker compose --env-file "$tmp/demo.env" "${args[@]}" config --quiet
done
echo 'Deployment scripts and Compose configuration validated'
