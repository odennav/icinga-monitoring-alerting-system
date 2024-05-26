#!/bin/bash

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
