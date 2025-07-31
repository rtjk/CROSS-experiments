#!/bin/sh

sig_alg_list="ed25519 ed448 rsa mldsa44 mldsa65 mldsa87 falcon512 falconpadded512 falcon1024 falconpadded1024 sphincsshake128fsimple sphincsshake192fsimple sphincsshake256fsimple mayo1 mayo2 mayo3 mayo5 CROSSrsdp128balanced CROSSrsdp128fast CROSSrsdp128small CROSSrsdp192balanced CROSSrsdp192fast CROSSrsdp192small CROSSrsdpg128balanced CROSSrsdpg128fast CROSSrsdpg128small CROSSrsdpg192balanced CROSSrsdpg192fast CROSSrsdpg192small CROSSrsdpg256balanced CROSSrsdpg256fast CROSSrsdpg256small OV_Ip_pkc OV_Ip_pkc_skc snova2454 snova37172 snova2455 snova2965"
# sig_alg_list="ed25519 ed448 rsa"

# parameters passed on to the Dockerfile
kem="mlkem512"
test_time="10"
tc_status="ON"
tc_delay="0ms"
tc_rate="500mbps"

set -e

date '+%Y-%m-%d-%H-%M-%S'
echo KEM: $kem
echo Time: $test_time
echo Traffic Control: "$tc_status ($tc_delay $tc_rate)"
echo "--------"

for i in $sig_alg_list
	do
		echo alg: $i
		./docker-nuke.sh > /dev/null 2>&1 || true
        # quiet, verbose
		docker build --quiet -t oqs-curl --build-arg SIG_ALG=$i --build-arg TEST_TIME=$test_time --build-arg KEM=$kem --build-arg TC_STATUS=$tc_status --build-arg TC_DELAY=$tc_delay --build-arg TC_RATE=$tc_rate . > /dev/null 2>&1
		# docker build -t oqs-curl --build-arg SIG_ALG=$i --build-arg TEST_TIME=$test_time --build-arg KEM=$kem --build-arg TC_STATUS=$tc_status --build-arg TC_DELAY=$tc_delay --build-arg TC_RATE=$tc_rate .
		docker run --rm -it --cap-add=NET_ADMIN oqs-curl | grep -E "bytes|server.crt|>>>>"
		# docker run --rm -it --cap-add=NET_ADMIN oqs-curl
	done

echo "--------"
date '+%Y-%m-%d-%H-%M-%S'
