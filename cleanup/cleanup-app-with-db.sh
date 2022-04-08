#!/bin/sh
oc delete all -l app=web
oc delete deployment postgres
oc delete route web-service
oc delete sa demo-app