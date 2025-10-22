#!/bin/sh

# before running this script launch the AWS server instance:
#   https://console.aws.amazon.com/ec2#Instances:
#   > debian
#   > m7i-flex.large
#   > network settings > edit > add rule > custom TCP 4433 anywhere
# then setup the server instance:
#   export SERVER="admin@..."
#   chmod 400 server.pem
#   scp -i server.pem generate.yml $SERVER:~
#   ssh -i server.pem $SERVER 'sudo bash -s' < setup.sh
# then export the instance as AMI:
#   > action > image and templates > create image > reboot image: no > create image
# when the AMI status becomes "available" copy it to the other regions
#   https://console.aws.amazon.com/ec2#Images:
#   > actions > copy AMI > destination region: ... > copy AMI
# then launch 3 client instances from this AMI

set -e

SIG_ALG_LIST=$(cat siglist.txt | grep -v '^\s*#')

SERVER="admin@ec2-13-39-107-30.eu-west-3.compute.amazonaws.com"
CLIENT_1="admin@ec2-13-38-229-139.eu-west-3.compute.amazonaws.com"
CLIENT_2="admin@ec2-63-177-52-110.eu-central-1.compute.amazonaws.com"
CLIENT_3="admin@ec2-13-57-59-170.us-west-1.compute.amazonaws.com"

date '+%Y-%m-%d-%H-%M-%S'
echo "--------"

mkdir -p ../results
rm -rf ../results/*

for SIG_ALG in $SIG_ALG_LIST
    do
        # server
        ssh -i server.pem $SERVER "echo $SIG_ALG | sudo tee /sig_alg.txt"
        ssh -i server.pem $SERVER 'sudo bash -s' < server.sh
        scp -i server.pem $SERVER:/opt/test/truststore.pem ./
        # client 1
        echo "sig: $SIG_ALG" >> ../results/client_1.txt
        scp -i client_1.pem truststore.pem $CLIENT_1:~
        ssh -i client_1.pem $CLIENT_1 "echo ${SERVER#admin@} | sudo tee /server.txt"
        ssh -i client_1.pem $CLIENT_1 'sudo bash -s' < client.sh | grep bytes >> ../results/client_1.txt
        # client 2
        echo "sig: $SIG_ALG" >> ../results/client_2.txt
        scp -i client_2.pem truststore.pem $CLIENT_2:~
        ssh -i client_2.pem $CLIENT_2 "echo ${SERVER#admin@} | sudo tee /server.txt"
        ssh -i client_2.pem $CLIENT_2 'sudo bash -s' < client.sh | grep bytes >> ../results/client_2.txt
        # client 3
        echo "sig: $SIG_ALG" >> ../results/client_3.txt
        scp -i client_3.pem truststore.pem $CLIENT_3:~
        ssh -i client_3.pem $CLIENT_3 "echo ${SERVER#admin@} | sudo tee /server.txt"
        ssh -i client_3.pem $CLIENT_3 'sudo bash -s' < client.sh | grep bytes >> ../results/client_3.txt
    done


echo "--------"
date '+%Y-%m-%d-%H-%M-%S'
