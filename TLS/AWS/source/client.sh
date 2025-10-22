#!/bin/bash

set -e # exit on error
set -x # show commands

# show a red + before each command
PS4='\[\e[31m\]+ \[\e[0m\]'

# copy the environmet
export PATH="/opt/oqssa/bin:${PATH}"
export OPENSSL=/opt/oqssa/bin/openssl
export OPENSSL_CNF=/opt/oqssa/ssl/openssl.cnf

openssl version

export SERVER=$(cat /server.txt)

openssl s_time -connect $SERVER:4433 -CAfile truststore.pem -new -verify 1 -verify_return_error -time 10

echo ">>>> done"