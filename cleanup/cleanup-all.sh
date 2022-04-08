#!/bin/sh
BASEDIR=$(dirname "$0")
. $BASEDIR/cleanup-unseal.sh
. $BASEDIR/cleanup-app-with-db.sh
. $BASEDIR/cleanup-app-without-db.sh