#!/bin/sh
helm uninstall vault-demo
oc delete pvc data-vault-demo-0
oc delete pvc data-vault-demo-1
oc delete pvc data-vault-demo-2
oc delete routes --all
oc delete all -l app=orgchart