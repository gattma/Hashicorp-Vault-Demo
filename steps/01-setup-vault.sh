#!/bin/sh

printActionHeader "1/5 SETUP VAULT (with Raft, without AutoUnseal)"
# SETUP
printStep "Add helm repo for HashiCorp..."
helm repo add hashicorp https://helm.releases.hashicorp.com > /dev/null
check "Add helm repo"

waitToContinue
printf "Install HashiCorp Vault in Openshift...\n"
code values/01-values-without-AutoUnseal.yaml

helm upgrade --install $RELEASE_NAME hashicorp/vault -f values/01-values-without-AutoUnseal.yaml > /dev/null
printStep "Install HashiCorp Vault"
check "Install HashiCorp Vault"

# UNSEAL
# TODO wait for status=running 
vault0Running=$(getPhase $RELEASE_NAME-0)
while [[ $vault0Running != 'Running' ]]; do
    printf "waiting for pod $RELEASE_NAME-0 to get in phase running...\n"
    sleep 5
    vault0Running=$(getPhase $RELEASE_NAME-0)
done;
printStep "$RELEASE_NAME-0 running..."
check "$RELEASE_NAME-0 running"


printCmd "vault operator init"
printStep "Initialize pod $RELEASE_NAME-0"
oc exec $RELEASE_NAME-0 -- vault operator init > generated/unseal_keys.txt
check "Initialize Vault"

printf "Unseal all vault pods...\n"
loadUnsealKeys "unseal_keys"

code generated/unseal_keys.txt
printCmd "vault operator unseal [UNSEAL KEY]"
printStep "Unseal pod $RELEASE_NAME-0"
oc exec $RELEASE_NAME-0 -- vault operator unseal $unsealKey1 > /dev/null
oc exec $RELEASE_NAME-0 -- vault operator unseal $unsealKey2 > /dev/null
oc exec $RELEASE_NAME-0 -- vault operator unseal $unsealKey3 > /dev/null
check "Unseal pod $RELEASE_NAME-0"

sleep 5
printCmd "vault operator raft join [URL of vault-0 pod]"
printStep "Pod $RELEASE_NAME-1 joins the raft cluster"
oc exec $RELEASE_NAME-1 -- vault operator raft join http://$RELEASE_NAME-0.$RELEASE_NAME-internal:8200 > /dev/null
check "join the raft cluster"

printStep "Unseal pod $RELEASE_NAME-1"
oc exec $RELEASE_NAME-1 -- vault operator unseal $unsealKey1 > /dev/null
oc exec $RELEASE_NAME-1 -- vault operator unseal $unsealKey2 > /dev/null
oc exec $RELEASE_NAME-1 -- vault operator unseal $unsealKey3 > /dev/null
check "Unseal pod $RELEASE_NAME-1"

printStep "Pod $RELEASE_NAME-2 joins the raft cluster"
oc exec $RELEASE_NAME-2 -- vault operator raft join http://$RELEASE_NAME-0.$RELEASE_NAME-internal:8200 > /dev/null
check "join the raft cluster"

printStep "Unseal pod $RELEASE_NAME-2"
oc exec $RELEASE_NAME-2 -- vault operator unseal $unsealKey1 > /dev/null
oc exec $RELEASE_NAME-2 -- vault operator unseal $unsealKey2 > /dev/null
oc exec $RELEASE_NAME-2 -- vault operator unseal $unsealKey3 > /dev/null
check "Unseal pod $RELEASE_NAME-2"

waitToContinue
printf "\nVault raft cluster infos:\n"
oc exec $RELEASE_NAME-0 -- vault login $rootToken
printf "\n"
oc exec $RELEASE_NAME-0 -- vault operator raft list-peers 
waitToContinue

printStep "\nExpose service 'vault-demo'"
oc expose service vault-demo --hostname vault-demo.apps.play.gepaplexx.com --name vault-demo > /dev/null
check "Expose service"
printfColor "TOKEN: " ${red}
printf "${rootToken}"

open http://vault-demo.apps.play.gepaplexx.com
waitToContinue