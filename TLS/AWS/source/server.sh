#!/bin/bash

set -e # exit on error
set -x # show commands

# show a red + before each command
PS4='\[\e[31m\]+ \[\e[0m\]'

export SIG_ALG=$(cat /sig_alg.txt)

export KEM="mlkem512"

# copy the environmet
export PATH="/opt/oqssa/bin:${PATH}"
export OPENSSL=/opt/oqssa/bin/openssl
export OPENSSL_CNF=/opt/oqssa/ssl/openssl.cnf

openssl version

mkdir -p /opt/test
rm -rf /opt/test/*
cd /opt/test

# kill existing server
pkill -9 -f "openssl s_server" > /dev/null 2>&1 || true
# root CA: generate key and certificate
openssl req -x509 -new -newkey ${SIG_ALG} -keyout root.key -out root.crt -nodes -subj "/CN=oqstest-root" -days 365 -config ${OPENSSL_CNF}
# download LetsEncrypt root certificates
wget https://letsencrypt.org/certs/isrgrootx1.pem
# boundle the root certificates
cat isrgrootx1.pem root.crt >> truststore.pem 
# intermediate CA: generate key, CSR, and certificate
openssl req -new -newkey ${SIG_ALG} -keyout intermediate.key -out intermediate.csr -nodes -subj "/CN=oqstest-intermediate" -config ${OPENSSL_CNF}
echo "basicConstraints = CA:TRUE" > intermediate.cnf
openssl x509 -req -in intermediate.csr -out intermediate.crt -CA root.crt -CAkey root.key -CAcreateserial -days 365 -extfile intermediate.cnf
# server CA: generate key, CSR, and certificate
openssl req -new -newkey ${SIG_ALG} -keyout server.key -out server.csr -nodes -subj "/CN=oqstest-server" -config ${OPENSSL_CNF}
openssl x509 -req -in server.csr -out server.crt -CA intermediate.crt -CAkey intermediate.key -CAcreateserial -days 365
# start the server
nohup openssl s_server -cert server.crt -cert_chain intermediate.crt -key server.key -groups ${KEM} -www -tls1_3 -accept 4433 > /tmp/server.log 2>&1 &
sleep 2
# verify the server is up
# echo | openssl s_client -verify_return_error -connect localhost:4433 -CAfile root.crt -verify_depth 1 > /dev/null 2>&1 && echo "[OK]" || echo "[ERROR]"

echo ">>>> done"
