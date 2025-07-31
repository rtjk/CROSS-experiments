#!/bin/bash

set -e # exit on error

SERVER_IPV4="$1"
SERVER_PORT="443"

cd /opt/test

export PATH="/opt/oqssa/bin:${PATH}"
export OPENSSL=/opt/oqssa/bin/openssl
export OPENSSL_CNF=/opt/oqssa/ssl/openssl.cnf

openssl version

openssl s_time -connect ${SERVER_IPV4}:${SERVER_PORT} -CAfile truststore.pem -new -verify 1 -verify_return_error -time 10 | grep -E "bytes|server.crt|>>>>"

echo ">>>> done"
