#!/bin/bash

set -e # exit on error
set -x # show commands

# show a red + before each command
PS4='\[\e[31m\]+ \[\e[0m\]'

cd /

# read the signature algorithm
FILE="sig_algs.txt"
if [ -s "$FILE" ]; then
    read -r SIG_ALG < "$FILE"
    echo "signature: $SIG_ALG"
    tail -n +2 "$FILE" > "${FILE}.tmp" && mv "${FILE}.tmp" "$FILE"
else
    echo ">>>> error: empty file"
fi

# copy the environmet
export PATH="/opt/oqssa/bin:${PATH}"
export OPENSSL=/opt/oqssa/bin/openssl
export OPENSSL_CNF=/opt/oqssa/ssl/openssl.cnf

openssl version

rm -rf /opt/test
mkdir /opt/test
cd /opt/test

# root CA: generate key and certificate
openssl req -x509 -new -newkey ${SIG_ALG} -keyout root.key -out root.crt -nodes -subj "/CN=oqstest-root" -days 365 -config ${OPENSSL_CNF}

# download LetsEncrypt root certificate
wget https://letsencrypt.org/certs/isrgrootx1.pem

# boundle the 2 root certificates
cat isrgrootx1.pem root.crt >> truststore.pem 

# intermediate CA: generate key, CSR, and certificate
openssl req -new -newkey ${SIG_ALG} -keyout intermediate.key -out intermediate.csr -nodes -subj "/CN=oqstest-intermediate" -config ${OPENSSL_CNF}
echo "basicConstraints = CA:TRUE" > intermediate.cnf
openssl x509 -req -in intermediate.csr -out intermediate.crt -CA root.crt -CAkey root.key -CAcreateserial -days 365 -extfile intermediate.cnf

# server CA: generate key, CSR, and certificate
openssl req -new -newkey ${SIG_ALG} -keyout server.key -out server.csr -nodes -subj "/CN=oqstest-server" -config ${OPENSSL_CNF}
openssl x509 -req -in server.csr -out server.crt -CA intermediate.crt -CAkey intermediate.key -CAcreateserial -days 365

# verify certificate chain: root -> intermediate -> server
openssl verify -CAfile root.crt -untrusted intermediate.crt server.crt

echo ">>>> print trutstore"
cat truststore.pem

echo ">>>> done"
