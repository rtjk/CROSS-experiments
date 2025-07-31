# check=skip=JSONArgsRecommended
# this Dockerfile is derived from
# https://github.com/open-quantum-safe/oqs-demos/tree/main/curl
#
# 1. build liboqs, oqs-provider, openssl, and curl
# 2. create the certificate chain root->intermediate->server
#    where all 3 entities use SIG_ALG to generate keys and sign
# 3. use traffic control to simulate a network configuration (optional)
# 4. start the server
# 5. connect and measure the number of handshakes in a given time frame
#
# post-quantum KEMs and signature schemes available:
# https://github.com/open-quantum-safe/oqs-provider#algorithms
#
# classical KEMs and signature schemes are also available:
# openssl list -kem-algorithms
# openssl list -signature-algorithms

FROM alpine:3.21 AS stage_1

ENV DEBIAN_FRONTEND=noninteractive

############## software versions ##################
ARG CURL_VERSION="8.11.1"
###################################################
ARG OPENSSL_SOURCE="rtjk"
ARG OPENSSL_TAG="fix_apps_verification"
###################################################
ARG LIBOQS_SOURCE="rtjk"
ARG LIBOQS_TAG="tlsexp-cross-2.2"
###################################################
ARG PROVIDER_SOURCE="rtjk"
ARG PROVIDER_TAG="tlsexp-enable-all"
###################################################

# KEMs
ARG DEFAULT_GROUPS="mlkem512:x25519:x448"

ARG LIBOQS_BUILD_DEFINES="-DOQS_DIST_BUILD=ON"
#ARG LIBOQS_BUILD_DEFINES="-DOQS_DIST_BUILD=OFF -DOQS_USE_AVX2_INSTRUCTIONS=OFF" # DISABLE AVX2

# get system packages
RUN apk update && apk upgrade
RUN apk add build-base linux-headers libtool automake autoconf cmake ninja make openssl openssl-dev git wget
RUN apk add iproute2 net-tools iperf3 tcpdump

# get sources
WORKDIR /opt
RUN git clone --depth 1 --branch ${LIBOQS_TAG} https://github.com/${LIBOQS_SOURCE}/liboqs
RUN git clone --depth 1 --branch ${OPENSSL_TAG} https://github.com/${OPENSSL_SOURCE}/openssl.git
RUN git clone --depth 1 --branch ${PROVIDER_TAG} https://github.com/${PROVIDER_SOURCE}/oqs-provider.git
RUN wget https://curl.haxx.se/download/curl-${CURL_VERSION}.tar.gz && tar -zxvf curl-${CURL_VERSION}.tar.gz;

# install liboqs
WORKDIR /opt/liboqs
RUN mkdir build && \
    cd build && cmake -G"Ninja" .. ${LIBOQS_BUILD_DEFINES} -DCMAKE_INSTALL_PREFIX=/opt/oqssa && \
    ninja install

# install OpenSSL
WORKDIR /opt/openssl
RUN if [ -d "/opt/oqssa/lib64" ]; then ln -s "/opt/oqssa/lib64" "/opt/oqssa/lib"; fi && \
    if [ -d "/opt/oqssa/lib" ]; then ln -s "/opt/oqssa/lib" "/opt/oqssa/lib64"; fi
RUN LDFLAGS="-Wl,-rpath -Wl,/opt/oqssa/lib64" ./config shared --prefix=/opt/oqssa && \
    make -j && \
    make install_sw install_ssldirs;
ENV PATH="/opt/oqssa/bin:${PATH}"

# install provider
WORKDIR /opt/oqs-provider
RUN ln -s ../openssl . && \
    cmake -DOPENSSL_ROOT_DIR=/opt/oqssa -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH=/opt/oqssa -S . -B _build && \
    cmake --build _build  && \
    cp _build/lib/oqsprovider.so /opt/oqssa/lib64/ossl-modules && \
    sed -i "s/default = default_sect/default = default_sect\noqsprovider = oqsprovider_sect/g" /opt/oqssa/ssl/openssl.cnf && \
    sed -i "s/\[default_sect\]/\[default_sect\]\nactivate = 1\n\[oqsprovider_sect\]\nactivate = 1\n/g" /opt/oqssa/ssl/openssl.cnf && \
    sed -i "s/providers = provider_sect/providers = provider_sect\nssl_conf = ssl_sect\n\n\[ssl_sect\]\nsystem_default = system_default_sect\n\n\[system_default_sect\]\nGroups = \$ENV\:\:DEFAULT_GROUPS\n/g" /opt/oqssa/ssl/openssl.cnf && \
    sed -i "s/\# Use this in order to automatically load providers/\# Set default KEM groups if not set via environment variable\nKDEFAULT_GROUPS = $DEFAULT_GROUPS\n\n# Use this in order to automatically load providers/g" /opt/oqssa/ssl/openssl.cnf && \
    sed -i "s/HOME\t\t\t= ./HOME\t\t= .\nDEFAULT_GROUPS\t= ${DEFAULT_GROUPS}/g" /opt/oqssa/ssl/openssl.cnf
ENV OPENSSL=/opt/oqssa/bin/openssl
ENV OPENSSL_CNF=/opt/oqssa/ssl/openssl.cnf

# install curl
WORKDIR /opt/curl-${CURL_VERSION}
RUN env LDFLAGS=-Wl,-R/opt/oqssa/lib64  \
        ./configure --prefix=/opt/oqssa \
                    --enable-debug \
                    --without-libpsl \
                    --with-ssl=/opt/oqssa && \
    make -j && \
    make install

################
# SECOND STAGE #
################

FROM stage_1 AS stage_2

# having a second stage saves us building time if we change only these arguments:
ARG SIG_ALG="mldsa44"
ARG KEM="mlkem512"
ARG TEST_TIME=5
ARG TC_STATUS=ON
ARG TC_DELAY=100ms
ARG TC_RATE=500mbps

# export the arguments as environmet varables to use them in ENTRYPOINT
ENV KEM=${KEM}
ENV TEST_TIME=${TEST_TIME}
ENV TC_STATUS=${TC_STATUS}
ENV TC_DELAY=${TC_DELAY}
ENV TC_RATE=${TC_RATE}

# copy the environmet from the first stage
ENV PATH="/opt/oqssa/bin:${PATH}"
ENV OPENSSL=/opt/oqssa/bin/openssl
ENV OPENSSL_CNF=/opt/oqssa/ssl/openssl.cnf

WORKDIR /opt/test

###################

# root CA: generate key and certificate
RUN openssl req -x509 -new -newkey ${SIG_ALG} -keyout root.key -out root.crt -nodes -subj "/CN=oqstest-root" -days 365 -config ${OPENSSL_CNF}

# download LetsEncrypt root certificate
RUN wget https://letsencrypt.org/certs/isrgrootx1.pem

# boundle the 2 root certificates
RUN cat isrgrootx1.pem root.crt >> truststore.pem 

# intermediate CA: generate key, CSR, and certificate
RUN openssl req -new -newkey ${SIG_ALG} -keyout intermediate.key -out intermediate.csr -nodes -subj "/CN=oqstest-intermediate" -config ${OPENSSL_CNF}
RUN echo "basicConstraints = CA:TRUE" > intermediate.cnf
RUN openssl x509 -req -in intermediate.csr -out intermediate.crt -CA root.crt -CAkey root.key -CAcreateserial -days 365 -extfile intermediate.cnf

# server CA: generate key, CSR, and certificate
RUN openssl req -new -newkey ${SIG_ALG} -keyout server.key -out server.csr -nodes -subj "/CN=oqstest-server" -config ${OPENSSL_CNF}
RUN openssl x509 -req -in server.csr -out server.crt -CA intermediate.crt -CAkey intermediate.key -CAcreateserial -days 365

# certificate chain: root -> intermediate -> server

STOPSIGNAL SIGTERM

ENTRYPOINT \
    # apply traffic control
    [ ${TC_STATUS} != "ON" ] && echo ">>>> tc is disabled" || tc qdisc add dev lo root netem delay ${TC_DELAY} rate ${TC_RATE} && \
    \
    # start the server
    (openssl s_server -cert server.crt -cert_chain intermediate.crt -key server.key -groups ${KEM} -www -tls1_3 -accept localhost:4433 &) && \
    # wait for the server to respond
    while ! echo | openssl s_client -connect :4433 -CAfile truststore.pem -verify_return_error > /dev/null 2>&1 ; do sleep 0.1; done  && \
    # measure the number of connections in a given time frame
    # -new          use a new session for each connection (opposite of -reuse)
    # -verify x     verify that the certificate chain has at most x intermediate CAs
    openssl s_time -connect :4433 -CAfile truststore.pem -new -verify 1 -verify_return_error -time ${TEST_TIME} && \
    \
    echo ">>>> done"


