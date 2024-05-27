#!/bin/bash

# This script runs the node wizard and tells the client/agent about the master icinga server

# Heredoc used to stream input to wizard

sudo icinga2 node wizard << EOF
Y
Enter
central-server1
Y
192.168.10.1
Enter
N
y
PKI
Enter
Enter
y
y
Enter
Enter
N
Y
EOF
