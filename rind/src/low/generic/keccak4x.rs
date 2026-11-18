// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

/// Keccak-f1600 on four states kept interleaved, lane `i` of state `j` at
/// `s[i][j]`, as SLH-DSA's four-way SHAKE holds them: in place with AVX2 on
/// x86_64, else moved into four separate states and back around the
/// backend's four-way permutation.
pub(crate) fn sha3_keccak4x_f1600(s: &mut [[u64; 4]; 25], rc: &[u64; 24]) {
    #[cfg(rind_backend = "x86_64")]
    if let Some(avx2) = super::super::x86_64::cpu::HaveAvx2::check() {
        return super::super::x86_64::sha3_keccak4x_avx2::sha3_keccak4x_f1600(avx2, s, rc);
    }
    let mut states: [[u64; 25]; 4] = core::array::from_fn(|j| core::array::from_fn(|i| s[i][j]));
    super::super::sha3_keccak4_f1600(&mut states, rc);
    *s = core::array::from_fn(|i| core::array::from_fn(|j| states[j][i]));
}
