#!/usr/bin/env sh
set -eu

container=${KEYCLOAK_CONTAINER:-animal-locket-keycloak-1}
client_file=${POSTMAN_CLIENT_FILE:-/opt/animal-locket/deploy/demo/keycloak-postman-client.json}
container_file=/tmp/keycloak-postman-client.json

docker cp "$client_file" "$container:$container_file"

docker exec "$container" sh -lc '
  set -eu
  kcadm=/opt/keycloak/bin/kcadm.sh
  "$kcadm" config credentials \
    --server http://127.0.0.1:8080 \
    --realm master \
    --user "$KC_BOOTSTRAP_ADMIN_USERNAME" \
    --password "$KC_BOOTSTRAP_ADMIN_PASSWORD" >/dev/null

  if "$kcadm" get clients -r animal-locket -q clientId=postman | grep -q "\"clientId\" : \"postman\""; then
    echo "Keycloak client postman already exists"
  else
    "$kcadm" create clients -r animal-locket -f /tmp/keycloak-postman-client.json >/dev/null
    echo "Created Keycloak client postman"
  fi

'

docker exec --user 0 "$container" rm -f "$container_file"
