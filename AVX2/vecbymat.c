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
#include "parameters.h"
#include "fp_arith.h"

int main() {

    srand(SEED);

    long long count_1;
    long long count_2;
    long long sum = 0;

    uint64_t checksum = 0;

    /******************************* AVX2 *************************************/
    #if defined(HIGH_PERFORMANCE_X86_64)
        #define IMPL 2
        alignas(32) FP_ELEM res[N-K];
        alignas(32) FP_ELEM e[N];
        #if defined(RSDP)
            alignas(32) FP_DOUBLEPREC V_tr[K][ROUND_UP(N-K,EPI16_PER_REG)];
        #elif defined(RSDPG)
            alignas(32) FP_DOUBLEPREC V_tr[K][ROUND_UP(N-K,EPI32_PER_REG)];
        #endif
    /***************************** Reference **********************************/
    #else
        #define IMPL 1
        FP_ELEM res[N-K];
        FP_ELEM e[N];
        FP_ELEM V_tr[K][N-K];
    #endif


    for(long long test=0; test<TESTS; test++){

        // initialize the error vector
        for(int i = 0; i < N; i++) {
            e[i] = (FP_ELEM)rand() % P;
        }
        // initialize the parity check matrix
        for(int i = 0; i < K; i++) {
            for(int j = 0; j < N-K; j++) {
                V_tr[i][j] = rand() % P;
            }
        }

        count_1 = cpucycles();
        fp_vec_by_fp_matrix(res, e, V_tr);
        count_2 = cpucycles();
        sum += count_2 - count_1;

        // checksum to prevent the compiler from skipping the test loop
        for(int i=0; i<N-K; i++) {
            checksum += res[i];
            checksum %= 10000;
        }

    }
    printf("{%d}[%d]Cycles: %lld\n", IMPL, checksum, sum/TESTS);

    return checksum;
}

/*

impl="ref"
impl="avx2"
rm -f vecbymat.o; gcc vecbymat.c cross/$impl/*.c -Icross/$impl -o vecbymat.o -DRSDPG=1 -DCATEGORY_5=1 -DSIG_SIZE=1 -march=native -O3 -lcpucycles
taskset --cpu-list 0 ./vecbymat.o

*/
