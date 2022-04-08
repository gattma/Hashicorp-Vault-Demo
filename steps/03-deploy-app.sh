#!/bin/sh

printActionHeader "3/5 DEPLOY AN APPLICATION (without DB)"

printCmd "vault auth enable kubernetes"
printStep "Enable kubernetes authentication"
oc exec $RELEASE_NAME-0 -- vault auth enable kubernetes > /dev/null
check "enable kubernetes auth"

printCmd 'vault write auth/kubernetes/config \
    token_reviewer_jwt="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
    kubernetes_host="https://$KUBERNETES_PORT_443_TCP_ADDR:443" \
    kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
    issuer="https://kubernetes.default.svc"'

printStep "Configure kubernetes authentication"
oc exec $RELEASE_NAME-0 -- /bin/sh -c 'vault write auth/kubernetes/config \
token_reviewer_jwt="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
kubernetes_host="https://$KUBERNETES_PORT_443_TCP_ADDR:443" \
kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
issuer="https://kubernetes.default.svc"' > /dev/null
check "configure auth"

printCmd 'vault policy write demo-app - <<EOF                     
    path "secret/data/demo/app" {         
    capabilities = ["read"]
    }
    EOF'
printStep "Create a new policy for read permissions"
oc exec $RELEASE_NAME-0 -- /bin/sh -c 'vault policy write demo-app - <<EOF                     
path "secret/data/demo/app" {         
capabilities = ["read"]
}
EOF' > /dev/null
check "Create new policy"

printCmd 'vault write auth/kubernetes/role/demo-app \
    bound_service_account_names=demo-app \
    bound_service_account_namespaces=vault-demo \
    policies=demo-app'
printStep "Create a kubernetes authentication role in vault"
oc exec $RELEASE_NAME-0 -- vault write auth/kubernetes/role/demo-app \
                            bound_service_account_names=demo-app \
                            bound_service_account_namespaces=vault-demo \
                            policies=demo-app \
                            ttl=24h > /dev/null
check "Create kubernetes role"

printStep "Create the serviceaccount for authentication"
oc create sa demo-app > /dev/null
check "Create a service account"

# TODO eigene anwendung deployen und zeigen das noch keine Secrets von Vault gelesen wurden
printStep "Deploy a demo application"
oc apply -f apps/01-demo-app.yaml > /dev/null
check "Deploy demo"
# TODO wait for the pod to be in state running/ready
waitToContinue

printf "\nTry to read the secrets from the pod\n"
printCmd "oc exec [PODNAME] -- ls /vault/secrets"
oc exec \
$(oc get pod -l app=orgchart -o jsonpath="{.items[0].metadata.name}") \
--container orgchart -- ls /vault/secrets
waitToContinueSilent

# PATCH demo app (without template)
printStep "Patch the demo app to enable the vault-agent-injector"
code patches/demo-app-patch.yaml
oc patch deployment orgchart --patch "$(cat patches/demo-app-patch.yaml)" > /dev/null
check "Patch the demo app"
# TODO wait for the pod to be in state running/ready
waitToContinue

printf "\nTry to read the secrets again\n"
printCmd "oc exec [PODNAME] -- ls /vault/secrets"
oc exec \
$(oc get pod -l app=orgchart -o jsonpath="{.items[0].metadata.name}") \
--container orgchart -- ls /vault/secrets

waitToContinueSilent
printf "\nContent of the secret:\n"
oc exec \
$(oc get pod -l app=orgchart -o jsonpath="{.items[0].metadata.name}") \
--container orgchart -- cat /vault/secrets/database-config.txt
waitToContinueSilent

# PATCH demo app (with template)
printStep "\nPatch the demo app to apply a template for the secret"
code patches/demo-app-template-patch.yaml
oc patch deployment orgchart --patch "$(cat patches/demo-app-template-patch.yaml)" > /dev/null
check "Patch the demo app"
# TODO wait for the pod to be in state running/ready
waitToContinueSilent

printf "\nTry to read the secrets again\n"
oc exec \
$(oc get pod -l app=orgchart -o jsonpath="{.items[0].metadata.name}") \
--container orgchart -- ls /vault/secrets

printf "\nContent of the secret:\n"
oc exec \
$(oc get pod -l app=orgchart -o jsonpath="{.items[0].metadata.name}") \
--container orgchart -- cat /vault/secrets/database-config.txt

waitToContinueSilent

oc delete pod $RELEASE_NAME-1

waitToContinue
printf "\n"