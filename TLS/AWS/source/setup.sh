#!/bin/bash

set -e # exit on error
set -x # show commands

# show a red + before each command
PS4='\[\e[31m\]+ \[\e[0m\]'

############## software versions ##################
export CURL_VERSION="8.11.1"
###################################################
export OPENSSL_SOURCE="rtjk"
export OPENSSL_TAG="fix_apps_verification"
###################################################
export LIBOQS_SOURCE="open-quantum-safe"
export LIBOQS_TAG="main"
###################################################
export PROVIDER_SOURCE="open-quantum-safe"
export PROVIDER_TAG="main"
###################################################

# KEMs
export DEFAULT_GROUPS="mlkem512:x25519:x448"

export LIBOQS_BUILD_DEFINES="-DOQS_DIST_BUILD=ON"
# export LIBOQS_BUILD_DEFINES="-DOQS_DIST_BUILD=OFF -DOQS_USE_AVX2_INSTRUCTIONS=OFF" # DISABLE AVX2

# get system packages
apt update
apt install -y build-essential ninja-build cmake openssl git wget iperf3 tcpdump binutils gcc clang libssl-dev htop python3 python3-pip

# get sources
mkdir -p /opt
cd /opt
rm -rf liboqs openssl oqs-provider curl-${CURL_VERSION}*
git clone --depth 1 --branch ${LIBOQS_TAG} https://github.com/${LIBOQS_SOURCE}/liboqs
git clone --depth 1 --branch ${OPENSSL_TAG} https://github.com/${OPENSSL_SOURCE}/openssl.git
git clone --depth 1 --branch ${PROVIDER_TAG} https://github.com/${PROVIDER_SOURCE}/oqs-provider.git
wget https://curl.haxx.se/download/curl-${CURL_VERSION}.tar.gz && tar -zxvf curl-${CURL_VERSION}.tar.gz;

# install liboqs
mkdir -p /opt/oqssa/
cd /opt/liboqs
mkdir -p build
cd build && cmake -G"Ninja" .. ${LIBOQS_BUILD_DEFINES} -DCMAKE_INSTALL_PREFIX=/opt/oqssa
ninja install

# increase the limit for the certifcate chain size in OpenSSL
cd /opt/openssl
sed -i 's/# define SSL_MAX_CERT_LIST_DEFAULT (1024\*100)/# define SSL_MAX_CERT_LIST_DEFAULT (1024*16000)/' include/openssl/ssl.h.in

# install OpenSSL
cd /opt/openssl
if [ -d "/opt/oqssa/lib64" ]; then ln -s "/opt/oqssa/lib64" "/opt/oqssa/lib"; fi
if [ -d "/opt/oqssa/lib" ]; then ln -s "/opt/oqssa/lib" "/opt/oqssa/lib64"; fi
LDFLAGS="-Wl,-rpath -Wl,/opt/oqssa/lib64" ./config shared --prefix=/opt/oqssa
make -j
make install_sw install_ssldirs
export PATH="/opt/oqssa/bin:${PATH}"

# enable all signature schemes in oqs-provider
cd /opt/oqs-provider
mv /home/admin/generate.yml oqs-template/generate.yml
export LIBOQS_SRC_DIR=/opt/liboqs
export LIBOQS_DOCS_DIR=/opt/liboqs/doc
pip3 install --break-system-packages --ignore-installed -r oqs-template/requirements.txt
python3 oqs-template/generate.py

# install oqs-provider
cd /opt/oqs-provider
ln -s ../openssl .
cmake -DOPENSSL_ROOT_DIR=/opt/oqssa -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH=/opt/oqssa -S . -B _build
cmake --build _build 
cp _build/lib/oqsprovider.so /opt/oqssa/lib64/ossl-modules
sed -i "s/default = default_sect/default = default_sect\noqsprovider = oqsprovider_sect/g" /opt/oqssa/ssl/openssl.cnf
sed -i "s/\[default_sect\]/\[default_sect\]\nactivate = 1\n\[oqsprovider_sect\]\nactivate = 1\n/g" /opt/oqssa/ssl/openssl.cnf
sed -i "s/providers = provider_sect/providers = provider_sect\nssl_conf = ssl_sect\n\n\[ssl_sect\]\nsystem_default = system_default_sect\n\n\[system_default_sect\]\nGroups = \$ENV\:\:DEFAULT_GROUPS\n/g" /opt/oqssa/ssl/openssl.cnf
sed -i "s/\# Use this in order to automatically load providers/\# Set default KEM groups if not set via environment variable\nKDEFAULT_GROUPS = $DEFAULT_GROUPS\n\n# Use this in order to automatically load providers/g" /opt/oqssa/ssl/openssl.cnf
sed -i "s/HOME\t\t\t= ./HOME\t\t= .\nDEFAULT_GROUPS\t= ${DEFAULT_GROUPS}/g" /opt/oqssa/ssl/openssl.cnf
export OPENSSL=/opt/oqssa/bin/openssl
export OPENSSL_CNF=/opt/oqssa/ssl/openssl.cnf

# install curl
cd /opt/curl-${CURL_VERSION}
env LDFLAGS=-Wl,-R/opt/oqssa/lib64  \
    ./configure --prefix=/opt/oqssa \
                --enable-debug \
                --without-libpsl \
                --with-ssl=/opt/oqssa
make -j
make install

echo ">>>> done"