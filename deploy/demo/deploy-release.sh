#!/usr/bin/env bash
# Run on an already bootstrapped demo server. Never regenerates .env or removes volumes.
set -euo pipefail
umask 077
root=/opt/animal-locket
release=${1:?Usage: deploy-release.sh /opt/animal-locket/releases/<release-id>}
mode=${2:-deploy}
[[ "$mode" == deploy || "$mode" == --rollback ]] || exit 2
tag=$(basename "$release")
[[ "$tag" =~ ^[a-f0-9]{40}-[0-9]+-[0-9]+$ ]] || { echo 'Invalid release id' >&2; exit 2; }
[[ "$release" == "$root/releases/$tag" && ! -L "$release" ]] || exit 2
[[ -f "$root/.env" && -f "$release/docker-compose.yml" ]] || {
  echo 'Bootstrap the server and generate its .env using the runbook first.' >&2; exit 1;
}
[[ -f "$root/deploy/demo/traefik.demo.yml" ]] || exit 1
exec 9>"$root/.deploy.lock"
flock -n 9 || { echo 'Another deployment is running' >&2; exit 1; }
export COMPOSE_PROFILES=core,app
export DEPLOY_TAG="$tag"
compose() {
  docker compose --project-name animal-locket --project-directory "$release" \
    --env-file "$root/.env" -f "$release/docker-compose.yml" \
    -f "$release/deploy/demo/docker-compose.demo.yml" \
    -f "$release/deploy/demo/docker-compose.ci.yml" "$@"
}
compose config --quiet
# Ensure the artifact contains the resources required by the Nov 8 avatar change.
[[ -s "$release/services/user-service/target/user-service-0.1.0-SNAPSHOT.jar" ]] || exit 1
services=(eureka-server config-server api-gateway user-service media-service post-service
          notification-service discovery-service chat-service billing-service minio)
if [[ "$mode" == --rollback ]]; then
  for service in "${services[@]}"; do
    docker image inspect "animal-locket/$service:$tag" >/dev/null
  done
else
  for service in "${services[@]}"; do
    compose build "$service"
  done
fi

# Build failure above leaves running containers untouched. Database migrations below
# are NOT automatically rolled back: stop on failure and inspect before rollback.
if ! compose up -d --no-build --wait --wait-timeout 600; then
  compose ps -a
  echo 'Release failed health checks. Inspect logs; current-release was not advanced.' >&2
  exit 1
fi
bash "$release/deploy/demo/smoke-check.sh" "$root/.env"
previous=
if [[ -L "$root/current-release" ]]; then
  previous=$(readlink -f "$root/current-release")
fi
if [[ -n "$previous" && "$previous" != "$release" ]]; then
  ln -sfn "$previous" "$root/previous-release"
fi
ln -sfn "$release" "$root/current-release"
echo "Deployed release $tag"
