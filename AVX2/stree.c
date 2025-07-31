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

#include "rng.h"
#include "seedtree.h"

int main() {

    srand(SEED);

    long long count_1;
    long long count_2;
    long long sum = 0;

    uint64_t checksum = 0;

    uint8_t seed_tree[NUM_NODES_SEED_TREE * SEED_LENGTH_BYTES];
    uint8_t root_seed[SEED_LENGTH_BYTES];
    uint8_t salt[SALT_LENGTH_BYTES];

    for(long long test=0; test<TESTS; test++){

        // initialize the root seed and salt
        for (int i = 0; i < SEED_LENGTH_BYTES; i++) root_seed[i] = rand();
        for (int i = 0; i < SALT_LENGTH_BYTES; i++) salt[i] = rand();

        count_1 = cpucycles();
        gen_seed_tree(seed_tree, root_seed, salt);
        count_2 = cpucycles();
        sum += count_2 - count_1;

        // checksum to prevent the compiler from skipping the test loop
        for(int i=0; i<(NUM_NODES_SEED_TREE*SEED_LENGTH_BYTES); i++){
            checksum += seed_tree[i];
            checksum %= 10000;
        }

    }
    printf("[%d]Cycles: %lld\n", checksum, sum/TESTS);

    return checksum;
}

/*

impl="ref"
impl="avx2"
rm -f stree.o; gcc stree.c cross/$impl/*.c -Icross/$impl -o stree.o -DRSDP=1 -DCATEGORY_5=1 -DSIG_SIZE=1 -march=native -O3 -lcpucycles
taskset --cpu-list 0 ./stree.o

*/
