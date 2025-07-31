#include <assert.h>
#include <immintrin.h>
#include <stdalign.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include "cpucycles.h"

#define TESTS           10000
#define SEED            42

#include "parameters.h"
#include "merkle_tree.h"

int main() {

    srand(SEED);

    long long count_1;
    long long count_2;
    long long sum = 0;

    uint64_t checksum = 0;

    uint8_t root[HASH_DIGEST_LENGTH];
    uint8_t tree[NUM_NODES_MERKLE_TREE * HASH_DIGEST_LENGTH];
    uint8_t leaves[T][HASH_DIGEST_LENGTH];

    for(long long test=0; test<TESTS; test++){

        // initialize the leaves
        for (int i = 0; i < T; i++) {
            for (int j = 0; j < HASH_DIGEST_LENGTH; j++) {
                leaves[i][j] = rand() % 256;
            }
        }

        count_1 = cpucycles();
        tree_root(root, tree, leaves);
        count_2 = cpucycles();
        sum += count_2 - count_1;

        // checksum to prevent the compiler from skipping the test loop
        for(int i=0; i<HASH_DIGEST_LENGTH; i++){
            checksum += root[i];
            checksum %= 10000;
        }

    }
    printf("[%d]Cycles: %lld\n", checksum, sum/TESTS);

    return checksum;
}

/*

impl="ref"
impl="avx2"
rm -f mtree.o; gcc mtree.c cross/$impl/*.c -Icross/$impl -o mtree.o -DRSDP=1 -DCATEGORY_5=1 -DSIG_SIZE=1 -march=native -O3 -lcpucycles
taskset --cpu-list 0 ./mtree.o

*/
