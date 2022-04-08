helm uninstall vault-demo-unseal
helm uninstall vault-demo
oc delete pvc data-vault-demo-unseal-0
oc delete route vault-demo-unseal
oc delete pvc data-vault-demo-0
oc delete pvc data-vault-demo-1
oc delete pvc data-vault-demo-2