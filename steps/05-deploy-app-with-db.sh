#!/bin/sh

printActionHeader "5/5 DEMO APP WITH DB"

printStep "Enable kubernetes authentication"
oc exec $RELEASE_NAME-0 -- vault auth enable kubernetes > /dev/null
check "enable kubernetes auth"

printStep "Configure kubernetes authentication"
oc exec $RELEASE_NAME-0 -- /bin/sh -c 'vault write auth/kubernetes/config \
token_reviewer_jwt="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
kubernetes_host="https://$KUBERNETES_PORT_443_TCP_ADDR:443" \
kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
issuer="https://kubernetes.default.svc"' > /dev/null
check "configure auth"

printCmd "vault secrets enable database"
printStep "Enable database engine"
oc exec $RELEASE_NAME-0 -- vault secrets enable database > /dev/null
check "enable db engine"

printStep "Deploy database"
oc apply -f apps/02-1-postgres.yaml > /dev/null
check "deploy db"

printCmd 'vault write database/config/wizard \
    plugin_name=postgresql-database-plugin \
    verify_connection=false \
    allowed_roles="*" \
    connection_url="postgresql://{{username}}:{{password}}@postgres:5432/wizard?sslmode=disable" \
    username="postgres" \
    password="password"'
printStep "Create db config"
oc exec $RELEASE_NAME-0 -- /bin/sh -c 'vault write database/config/wizard \
    plugin_name=postgresql-database-plugin \
    verify_connection=false \
    allowed_roles="*" \
    connection_url="postgresql://{{username}}:{{password}}@postgres:5432/wizard?sslmode=disable" \
    username="postgres" \
    password="password"' > /dev/null
check "configure db"

printCmd 'vault write database/rotate-root/wizard'
printStep "Activate password rotation"
oc exec $RELEASE_NAME-0 -- vault write --force database/rotate-root/wizard > /dev/null
check "pw rotation"

printCmd 'vault write database/roles/db-app \
    db_name=wizard \
    creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; \
        GRANT SELECT ON ALL TABLES IN SCHEMA public TO \"{{name}}\";" \
    revocation_statements="ALTER ROLE \"{{name}}\" NOLOGIN;"\
    default_ttl="1h" \
    max_ttl="24h"'
printStep "Create db role"
oc exec $RELEASE_NAME-0 -- vault write database/roles/db-app \
    db_name=wizard \
    creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; \
        GRANT SELECT ON ALL TABLES IN SCHEMA public TO \"{{name}}\";" \
    revocation_statements="ALTER ROLE \"{{name}}\" NOLOGIN;"\
    default_ttl="1h" \
    max_ttl="24h" > /dev/null

check "create db role"

printCmd 'vault policy write web-dynamic - <<EOF
path "database/creds/db-app" {
  capabilities = ["read"]
}
EOF'
printStep "Create db policy"
oc exec $RELEASE_NAME-0 -- /bin/sh -c 'vault policy write web-dynamic - <<EOF
path "database/creds/db-app" {
  capabilities = ["read"]
}
EOF' > /dev/null
check "create db policy"

printCmd 'vault write auth/kubernetes/role/web \
    bound_service_account_names=demo-app \
    bound_service_account_namespaces=vault-demo \
    policies=web-dynamic \
    ttl=1h'
printStep "Create role"
oc exec $RELEASE_NAME-0 -- /bin/sh -c 'vault write auth/kubernetes/role/web \
    bound_service_account_names=demo-app \
    bound_service_account_namespaces=vault-demo \
    policies=web-dynamic \
    ttl=1h' > /dev/null
check "create role"

printCmd "vault read database/creds/db-app"
oc exec $RELEASE_NAME-0 -- vault read database/creds/db-app

waitToContinue

printStep "Deploy an application"
oc apply -f apps/02-2-web.yaml
check "deploy"

printStep "Expose the service"
oc expose svc web-service
check "expose"
waitToContinue

printStep "Read the secrets from the pod"
oc exec $(oc get pod -l app=web -o jsonpath="{.items[0].metadata.name}") --container web -- cat /vault/secrets/db-creds
waitToContinue

printStep "Open the coffee endpoint"
open http://web-service-vault-demo.apps.play.gepaplexx.com/coffee