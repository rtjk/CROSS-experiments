#!/bin/sh

set -e

sig_alg_list=$(cat siglist.txt | grep -v '^\s*#')

# parameters passed on to the Dockerfile
kem="mlkem512"
test_time="10"
tc_status="ON"
tc_delay="120ms"
tc_rate="500mbps"

date '+%Y-%m-%d-%H-%M-%S'
echo KEM: $kem
echo Time: $test_time
echo Traffic Control: "$tc_status ($tc_delay $tc_rate)"
echo "--------"

for i in $sig_alg_list
	do
		echo sig: $i
		./docker-nuke.sh > /dev/null 2>&1 || true
        # quiet, verbose
		docker build --quiet -t oqs-curl --build-arg SIG_ALG=$i --build-arg TEST_TIME=$test_time --build-arg KEM=$kem --build-arg TC_STATUS=$tc_status --build-arg TC_DELAY=$tc_delay --build-arg TC_RATE=$tc_rate . > /dev/null 2>&1
		# docker build -t oqs-curl --build-arg SIG_ALG=$i --build-arg TEST_TIME=$test_time --build-arg KEM=$kem --build-arg TC_STATUS=$tc_status --build-arg TC_DELAY=$tc_delay --build-arg TC_RATE=$tc_rate .
		docker run -it --cap-add=NET_ADMIN oqs-curl | grep -E "bytes|server.crt|>>>>"
		# docker run -it --cap-add=NET_ADMIN oqs-curl
	done

# export logs from the last run
echo "--------"
rm -rf ./export/*
docker cp $(docker ps -lq):/export ./ > /dev/null 2>&1
./docker-nuke.sh > /dev/null 2>&1 || true
cat ./export/sw.txt
echo "*" > ./export/.gitignore

echo "--------"
date '+%Y-%m-%d-%H-%M-%S'
