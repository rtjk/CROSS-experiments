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
#define EPI16_PER_M256  (256/16)
#define LEN             (251)
#define SEED            (42)

#define ROUND_UP(amount, round_amt) (((amount+round_amt-1)/round_amt)*round_amt)

/********************************* Reference **********************************/

#define POW_16__1_M509 ((uint16_t)  16)
#define POW_16__2_M509 ((uint16_t) 256)
#define POW_16__4_M509 ((uint16_t) 384)
#define POW_16__8_M509 ((uint16_t) 355)
#define POW_16_16_M509 ((uint16_t) 302)
#define POW_16_32_M509 ((uint16_t)  93)
#define POW_16_64_M509 ((uint16_t) 505)

#define U16_CMOV(BIT, TRUE_V, FALSE_V) ((((uint16_t)0 - (BIT)) & (TRUE_V)) | (~((uint16_t)0 - (BIT)) & (FALSE_V)))

/* Reduction modulo P=509 as shown in:
 * Hacker's Delight, Second Edition, Chapter 10, Figure 10-4
 * Works for integers in the range [0,4294967295] i.e. all uint32_t */
#define M509(x) (((x) - (((uint64_t)(x) * 2160140723) >> 40) * 509))

uint16_t EXP16M509(uint16_t c) {
    uint32_t res1, res2;
    res1 = (U16_CMOV(((c >> 0) & 1), POW_16__1_M509, 1)) *
           (U16_CMOV(((c >> 1) & 1), POW_16__2_M509, 1)) *
           (U16_CMOV(((c >> 2) & 1), POW_16__4_M509, 1)) *
           (U16_CMOV(((c >> 3) & 1), POW_16__8_M509, 1));
    res2 = (U16_CMOV(((c >> 4) & 1), POW_16_16_M509, 1)) *
           (U16_CMOV(((c >> 5) & 1), POW_16_32_M509, 1)) *
           (U16_CMOV(((c >> 6) & 1), POW_16_64_M509, 1));
    return M509(M509(res1) * M509(res2));
}

/************************************ AVX2 ************************************/

/* reduce modulo 509 eigth 32-bit integers packed into a 256-bit vector, using Barrett's method
 * each 32-bit integer sould be in the range [0, 508*508] i.e. the result of a mul in FP
 * however, the function actually works for integers in the wider range [0, 8339743] */
static inline __m256i mm256_mod509_epu32(__m256i a) {
    int b_shift = 18; // ceil(log2(509))*2
    int b_mul = (((uint64_t)1U << b_shift) / 509);
    /* r = a - ((B_MUL * a) >> B_SHIFT) * P) */
    __m256i b_mul_32 = _mm256_set1_epi32(b_mul);
    __m256i p_32 = _mm256_set1_epi32(509);
    __m256i r = _mm256_mullo_epi32(a, b_mul_32);
            r = _mm256_srli_epi32(r, b_shift);
            r = _mm256_mullo_epi32(r, p_32);
            r = _mm256_sub_epi32(a, r);
    /* r = min(r, r - P) */
    __m256i rs= _mm256_sub_epi32(r, p_32);
            r = _mm256_min_epu32(r, rs);
    return r;
}

/* shuffle sixteen 16-bit integers packed into a 256-bit vector:
 * shuffle(a[], b[]) returns c[] where c[i]=a[b[i]] 
 * operates within 128-bit lanes, so b[i] must be in the range [0,7] */
static inline __m256i mm256_shuffle_epi16(__m256i a, __m256i b) {
    __m256i x1 = _mm256_setr_epi8(0, 0, 2, 2, 4, 4, 6, 6, 8, 8, 10, 10, 12, 12, 14, 14, 0, 0, 2, 2, 4, 4, 6, 6, 8, 8, 10, 10, 12, 12, 14, 14);
    __m256i x2 = _mm256_setr_epi8(0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1);
    b = _mm256_adds_epu16(b, b);
    b = _mm256_shuffle_epi8(b, x1);
    b = _mm256_adds_epu8(b, x2);
    b = _mm256_shuffle_epi8(a, b);
    return b;
}

/* for each 16-bit integer packed into a 256-bit vector, select one of two 
 * values based on a boolean condition, without using if-else statements:
 * cmov(cond[], true_val[], false_val[]) returns r[] where r[i]=true_val[i]
 * if cond[i]==1, and r[i]=false_val[i] if cond[i]==0 */
static inline __m256i mm256_cmov_epu16(__m256i c, __m256i t, __m256i f) {
    __m256i zeros  = _mm256_setzero_si256();
    __m256i cmask  = _mm256_sub_epi16(zeros, c);
    __m256i cmaskn = _mm256_xor_si256(cmask, _mm256_set1_epi16(-1));
    __m256i tval   = _mm256_and_si256(cmask, t);
    __m256i fval   = _mm256_and_si256(cmaskn, f);
    __m256i r      = _mm256_or_si256(tval, fval);
    return r;
}

/* multiply 16-bit integers packed into 256-bit vectors and reduce the result
 * modulo 509: mulmod509(a[], b[]) returns c[] where c[i]=(a[i]*b[i])%509 */
static inline __m256i mm256_mulmod509_epu16(__m256i a, __m256i b) {
    /* multiply */
    __m256i l = _mm256_mullo_epi16(a, b);
    __m256i h = _mm256_mulhi_epu16(a, b);
    /* unpack 16-bit to 32-bit */
    __m256i u0 = _mm256_unpacklo_epi16(l, h);
    __m256i u1 = _mm256_unpackhi_epi16(l, h);
    /* reduce */
    u0 = mm256_mod509_epu32(u0);
    u1 = mm256_mod509_epu32(u1);
    /* pack 32-bit to 16-bit */
    __m256i r = _mm256_packs_epi32(u0, u1);
    return r;
}

/* for each 16-bit integer x packed into a 256-bit vector, with x in [1, 127],
 * compute: (16^x) mod 509 */
__m256i mm256_exp16m509_epu16(__m256i c) {
    /* high 3 bits */
    __m256i h3 = _mm256_srli_epi16(c, 4);
    __m256i pre_h3 = _mm256_setr_epi16(
        1,302,93,91,505,319,137,145,
        1,302,93,91,505,319,137,145);
    __m256i h3_shu = mm256_shuffle_epi16(pre_h3, h3);
    /* low 4 bits */
    __m256i mask_l4 = _mm256_set1_epi16(0x0F); //0b1111
    __m256i l4 = _mm256_and_si256(c, mask_l4);
    __m256i mask_l4_bit4 = _mm256_set1_epi16(0x8); //0b1000
    __m256i l4_bit4 = _mm256_and_si256(c, mask_l4_bit4);
    l4_bit4 = _mm256_srli_epi16(l4_bit4, 3);
    __m256i l4_sub8 = _mm256_sub_epi16(l4, _mm256_set1_epi16(8));
    __m256i pre_l4_0 = _mm256_setr_epi16(
        1,16,256,24,384,36,67,54,
        1,16,256,24,384,36,67,54);
    __m256i l4_shu_0 = mm256_shuffle_epi16(pre_l4_0, l4);
    __m256i pre_l4_1 = _mm256_setr_epi16(
        355,81,278,376,417,55,371,337,
        355,81,278,376,417,55,371,337);
    __m256i l4_shu_1 = mm256_shuffle_epi16(pre_l4_1, l4_sub8);
    __m256i l4_shu = mm256_cmov_epu16(l4_bit4, l4_shu_1, l4_shu_0);
    /* multiply */
    __m256i r = mm256_mulmod509_epu16(h3_shu, l4_shu);
    return r;
}
    
/******************************************************************************/

int main() {

    srand(SEED);

    long long count_1;
    long long count_2;
    long long sum = 0;

    alignas(32) uint8_t c[LEN];
    alignas(32) uint16_t c16[ROUND_UP(LEN, EPI16_PER_M256)];
    alignas(32) uint16_t r[LEN];

    uint64_t checksum = 0;

    for(long long test=0; test<TESTS; test++){

        memset(c16, 0, sizeof(c16));
        for (int i = 0; i < LEN; i++) {
            c[i] = (rand() % 127) + 1;
        }

        count_1 = cpucycles();
        /***************************** Reference ******************************/
        #if IMPL == 1
            for (int i = 0; i < LEN; i++) {
                r[i] = EXP16M509(c[i]);
            }
        /******************************* AVX2 *********************************/
        #elif IMPL == 2
            for (int i = 0; i < LEN; i++) {
                c16[i] = c[i];
            }
            for (int i = 0; i < LEN; i+=EPI16_PER_M256) {
                __m256i c_x = _mm256_load_si256((__m256i*)&c16[i]);
                __m256i r_x = mm256_exp16m509_epu16(c_x);
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
rm -f exp16mod509.o; gcc -o exp16mod509.o exp16mod509.c -march=native -O3 -lcpucycles -DIMPL=1
taskset --cpu-list 0 ./exp16mod509.o
*/
