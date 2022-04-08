#!/bin/sh

printActionHeader "2/5 INSERT SOME SECRETS"

printCmd "vault secrets enable -path=secret kv-v2"
printStep "Enable key-value store"
oc exec $RELEASE_NAME-0 -- vault secrets enable -path=secret kv-v2 > /dev/null
check "enable kv store"

printCmd 'vault kv put secret/demo/app username="blub" password="blub-but-save"'
printStep "Add secrets 'username=blub' and 'password=blub-but-save'"
oc exec $RELEASE_NAME-0 -- vault kv put secret/demo/app username="blub" password="blub-but-save" > /dev/null
check "Add secrets"
waitToContinue