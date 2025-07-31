#include <assert.h>
#include <immintrin.h>
#include <stdalign.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include "cpucycles.h"

#define TESTS           (10000)
#define EPI8_PER_M256   (256/8)
#define LEN             (251)
#define SEED            (42)

#define ROUND_UP(amount, round_amt) (((amount+round_amt-1)/round_amt)*round_amt)

/********************************* Reference **********************************/

#define T ((uint64_t) (0x0140201008040201))
#define EXP2M127(c) ((uint8_t) (T>>(8*(uint64_t)(c))))

/************************************ AVX2 ************************************/

__m256i mm256_exp2m127_epu8(__m256i c) {
    __m256i t = _mm256_setr_epi8(
        1,2,4,8,16,32,64,1,0,0,0,0,0,0,0,0,
        1,2,4,8,16,32,64,1,0,0,0,0,0,0,0,0);
    return _mm256_shuffle_epi8(t, c);
}

/******************************************************************************/

int main() {

    srand(SEED);

    long long count_1;
    long long count_2;
    long long sum = 0;

    alignas(32) uint8_t c[LEN];
    alignas(32) uint8_t c_e[ROUND_UP(LEN, EPI8_PER_M256)];
    alignas(32) uint8_t r[LEN];

    uint64_t checksum = 0;

    for(long long test=0; test<TESTS; test++){

        memset(c_e, 0, sizeof(c_e));
        for (int i = 0; i < LEN; i++) {
            c[i] = (rand() % 7) + 1;
        }

        count_1 = cpucycles();
        /***************************** Reference ******************************/
        #if IMPL == 1
            for (int i = 0; i < LEN; i++) {
                r[i] = EXP2M127(c[i]);
            }
        /******************************* AVX2 *********************************/
        #elif IMPL == 2
            memcpy(c_e, c, sizeof(c));
            for (int i = 0; i < LEN; i+=EPI8_PER_M256) {
                __m256i c_x = _mm256_load_si256((__m256i*)&c_e[i]);
                __m256i r_x = mm256_exp2m127_epu8(c_x);
                _mm256_store_si256((__m256i*)&r[i], r_x);
            }
        #endif
        /**********************************************************************/
        count_2 = cpucycles();
        sum += count_2 - count_1;

        // checksum to prevent the compiler from skipping the test loop
        for(int i=0; i<LEN; i++){
            checksum += r[i];
            checksum %= 10000;
        }

    }
    printf("[%d][%lu]Cycles: %lld\n", IMPL, checksum, sum/TESTS);

    return checksum;
}

/*
rm -f exp2mod127.o; gcc -o exp2mod127.o exp2mod127.c -march=native -O3 -lcpucycles -DIMPL=1
taskset --cpu-list 0 ./exp2mod127.o
*/
