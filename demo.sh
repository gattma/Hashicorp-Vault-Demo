#!/bin/sh
##### VARS ##############
red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
blue=$(tput setaf 4)
cyan=$(tput setaf 6)
normal=$(tput sgr0)

RELEASE_NAME=vault-demo

##### HELPERS ###########
function printActionHeader() {
    printf "\n${yellow}################################################################################\n"
    printf "%*s\n" $(((${#1}+80)/2)) "${2}${1}"
    printf "################################################################################${normal}\n"
}

function printSuccess() {
    printf '\033[79`%s\n' "${green}OK${normal}"
}

function printFailure() {
    printf '\033[75`%s\n' "${red}FAILED${normal}"
}

function printFailureAndExit() {
    printf "${1} ${red}FAILED${normal}"
    exit 1
}

function waitToContinue() {
    printf "\npress any key to continue..."
    read  -n 1
}

function waitToContinueSilent() {
    read  -n 1
}

function check() {
    [[ $? = 0 ]] && printSuccess || printFailureAndExit ${1}
}

function printfColor() {
    printf "$2$1${normal}"
}

function printStep() {
    printf "$1"
}

function printCmd() {
    printf "\n==> COMMAND: ${green}$1${normal}"
    waitToContinueSilent
}

function loadUnsealKeys() {
    unsealKey1=$(awk '/Unseal Key 1:/{print $NF}' generated/$1.txt)
    unsealKey2=$(awk '/Unseal Key 2:/{print $NF}' generated/$1.txt)
    unsealKey3=$(awk '/Unseal Key 3:/{print $NF}' generated/$1.txt)
    rootToken=$(awk '/Initial Root Token:/{print $NF}' generated/$1.txt)
}

function getPhase() {
    oc get pod $1 -o=jsonpath='{.status.phase}'
}

function init() {
    printActionHeader "INITIALIZE"
    oc project ${1}
    [[ $? = 1 ]] && oc new-project ${1}
    open https://play.gepaplexx.com/k8s/ns/vault-demo/pods
    mkdir -p generated
}

function deleteAndInitVaultPod() {
    oc delete pod $RELEASE_NAME-2
    waitToContinue

    oc exec $RELEASE_NAME-2 -- vault operator unseal $unsealKey1 > /dev/null
    oc exec $RELEASE_NAME-2 -- vault operator unseal $unsealKey2 > /dev/null
    oc exec $RELEASE_NAME-2 -- vault operator unseal $unsealKey3 > /dev/null
    waitToContinue
}

function main() {
    init ${1}
    . steps/01-setup-vault.sh
    . steps/02-insert-secrets.sh
    . steps/03-deploy-app.sh

    . cleanup/cleanup-app-without-db.sh

    . steps/04-setup-vault-autounseal.sh
    . steps/05-deploy-app-with-db.sh
}

# 1 .. Openshift Project
main "${1}"