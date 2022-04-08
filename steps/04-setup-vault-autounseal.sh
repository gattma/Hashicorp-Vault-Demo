#!/bin/sh

printActionHeader "4/5 VAULT WITH AUTO UNSEAL"

# SETUP "Unsealer"-Vault
printf "Install HashiCorp Vault Cluster - UNSEALER\n"
waitToContinue
code values/02-values-unsealer.yaml
helm upgrade --install $RELEASE_NAME-unseal hashicorp/vault -f values/02-values-unsealer.yaml > /dev/null
printStep "Install HashiCorp Vault Cluster"
check "Install Unsealer"

vault0Running=$(getPhase $RELEASE_NAME-unseal-0)
while [[ $vault0Running != 'Running' ]]; do
    printf "waiting for pod $RELEASE_NAME-unseal-0 to get in phase running...\n"
    sleep 5
    vault0Running=$(getPhase $RELEASE_NAME-unseal-0)
done;
printStep "$RELEASE_NAME-unseal-0 running..."
check "$RELEASE_NAME-unseal-0 running"

printCmd "vault operator init"
printStep "Initialize pod $RELEASE_NAME-unseal-0"
oc exec $RELEASE_NAME-unseal-0 -- vault operator init > generated/unseal_keys_unsealer.txt
check "Initialize Vault"

loadUnsealKeys "unseal_keys_unsealer"
code generated/unseal_keys_unsealer.txt
printCmd "vault operator unseal [UNSEAL-KEY]"
printStep "Unseal pod $RELEASE_NAME-unseal-0"
oc exec $RELEASE_NAME-unseal-0 -- vault operator unseal $unsealKey1 > /dev/null
oc exec $RELEASE_NAME-unseal-0 -- vault operator unseal $unsealKey2 > /dev/null
oc exec $RELEASE_NAME-unseal-0 -- vault operator unseal $unsealKey3 > /dev/null
check "Unseal pod $RELEASE_NAME-unseal-0"

printStep "\nExpose service 'vault-demo-unseal'"
oc expose service $RELEASE_NAME-unseal --hostname vault-demo-unseal.apps.play.gepaplexx.com --name vault-demo-unseal > /dev/null
check "Expose service"

printStep "Enable AutoUnseal Feature\n"
printCmd "vault login [ROOT-TOKEN]"
oc exec $RELEASE_NAME-unseal-0 -- vault login $rootToken > /dev/null
oc exec $RELEASE_NAME-unseal-0 -- vault audit enable file file_path=/home/vault/audit.log > /dev/null
printCmd "vault secrets enable transit" # enable the transit secrets engine
oc exec $RELEASE_NAME-unseal-0 -- vault secrets enable transit > /dev/null
printCmd "vault write -f transit/keys/autounseal" # Create an encryption key named 'autounseal'
oc exec $RELEASE_NAME-unseal-0 -- vault write -f transit/keys/autounseal > /dev/null

# Create a policy file named autounseal.hcl which permits update against transit/encrypt/autounseal and transit/decrypt/autounseal paths
printCmd 'tee /home/vault/autounseal.hcl <<EOF
path "transit/encrypt/autounseal" {
    capabilities = [ "update" ]
}	

path "transit/decrypt/autounseal" {
    capabilities = [ "update" ]
}
EOF'
oc exec $RELEASE_NAME-unseal-0 -- /bin/sh -c 'tee /home/vault/autounseal.hcl <<EOF
path "transit/encrypt/autounseal" {
    capabilities = [ "update" ]
}	

path "transit/decrypt/autounseal" {
    capabilities = [ "update" ]
}
EOF' > /dev/null

# Create a policy named autounseal
printCmd "vault policy write autounseal /home/vault/autounseal.hcl"
oc exec $RELEASE_NAME-unseal-0 -- vault policy write autounseal /home/vault/autounseal.hcl > /dev/null
printCmd 'vault token create -policy="autounseal"'
oc exec $RELEASE_NAME-unseal-0 -- vault token create -policy="autounseal" -wrap-ttl=120 >> generated/unseal_keys_unsealer.txt
code generated/unseal_keys_unsealer.txt

wrappingToken=$(awk '/wrapping_token:/{printf $NF}' generated/unseal_keys_unsealer.txt)
printCmd 'VAULT_TOKEN=[WRAPPING TOKEN] vault unwrap'
oc exec $RELEASE_NAME-unseal-0 -- /bin/sh -c "VAULT_TOKEN=$wrappingToken vault unwrap" >> generated/unseal_keys_unsealer.txt

waitToContinue

# SETUP Vault
clientToken=$(awk '/token /{printf $NF}' generated/unseal_keys_unsealer.txt)
export UNSEALER_ADDRESS=http://vault-demo-unseal.apps.play.gepaplexx.com
export CLIENT_TOKEN=$clientToken
envsubst < values/03-values-vault-with-unsealer-TEMPLATE.yaml > values/03-values-vault-with-unsealer.yaml

code values/03-values-vault-with-unsealer.yaml

printStep "Install Hashicorp Vault"
helm upgrade --install $RELEASE_NAME hashicorp/vault -f values/03-values-vault-with-unsealer.yaml > /dev/null

vault0Running=$(getPhase $RELEASE_NAME-0)
while [[ $vault0Running != 'Running' ]]; do
    printf "waiting for pod $RELEASE_NAME-0 to get in phase running...\n"
    sleep 5
    vault0Running=$(getPhase $RELEASE_NAME-0)
done;

printCmd "vault operator init"
oc exec $RELEASE_NAME-0 -- vault operator init > generated/unseal_keys_vault_with_unsealer.txt
loadUnsealKeys "unseal_keys_vault_with_unsealer"
oc exec $RELEASE_NAME-0 -- vault login $rootToken > /dev/null
sleep 5
waitToContinue

# TODO kann zu schnell kommen => warten oder auf Success prüfen!
printStep "Join the raft cluster"
oc exec $RELEASE_NAME-1 -- vault operator raft join http://$RELEASE_NAME-0.$RELEASE_NAME-internal:8200 > /dev/null
oc exec $RELEASE_NAME-2 -- vault operator raft join http://$RELEASE_NAME-0.$RELEASE_NAME-internal:8200 > /dev/null
waitToContinue
