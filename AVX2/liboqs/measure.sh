#!/bin/sh

set -e

sig_alg_list=$(cat siglist.txt | grep -v '^\s*#')

git clone https://github.com/open-quantum-safe/liboqs
cd liboqs
rm -rf build; mkdir build && cd build; cmake -GNinja ..; ninja; cd ..

date '+%Y-%m-%d-%H-%M-%S'
echo "--------"

for i in $sig_alg_list
    do
        echo sig: $i
        ./build/tests/speed_sig $i
    done

echo "--------"
date '+%Y-%m-%d-%H-%M-%S'