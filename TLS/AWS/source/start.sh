#!/bin/bash

set -e # exit on error
set -x # show commands

# show a red + before each command
PS4='\[\e[31m\]+ \[\e[0m\]'

cd /

export KEM="mlkem512"

# copy the environmet
export PATH="/opt/oqssa/bin:${PATH}"
export OPENSSL=/opt/oqssa/bin/openssl
export OPENSSL_CNF=/opt/oqssa/ssl/openssl.cnf

openssl version

cd /opt/test

# kill existing server
pkill -9 -f "openssl s_server" > /dev/null 2>&1 || true
pkill -9 -f "iperf" > /dev/null 2>&1 || true

# start iperf3 server to measure bandwidth
iperf3 -s &

# start openssl server
openssl s_server -cert server.crt -cert_chain intermediate.crt -key server.key -groups ${KEM} -www -tls1_3 -accept 443 &
sleep 2

echo ">>>> done"
