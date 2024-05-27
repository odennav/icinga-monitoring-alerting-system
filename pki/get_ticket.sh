#!/bin/bash

# This script replaces the PKI placeholder with actual ticket value in the icinga_node_wizard script

extractTicket() {

    local host="$1"
    
    local ticket=$(cat "pki-$host.txt")

    sed -i "s/PKI/$ticket/g" icinga_node_wizard.sh

}


extractTicket "$1"
