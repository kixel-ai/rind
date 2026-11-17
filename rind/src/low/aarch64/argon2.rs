// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

//! Argon2's compression function on aarch64.
//!
//! The portable permutation runs unless the build passes
//! `--cfg rind_argon2_neon`, which selects [`super::argon2_neon`]: the NEON
//! fill measured on `perf/argon2-neon-scalar-rider`, SHA3's `xar` where the
//! CPU has it and the plain NEON fill with its scalar rider otherwise.

use crate::low::generic::argon2::Argon2Block;

/// Argon2's compression function, as `low::generic::argon2` defines it.
pub(crate) fn argon2_compress(x: &Argon2Block, y: &Argon2Block, out: &mut Argon2Block, xor: bool) {
    // Off until the kernel beats the portable permutation on an Apple core
    // and a Neoverse core. See quest/m4/protocols/argon2-simd.md.
    #[cfg(rind_argon2_neon)]
    super::argon2_neon::compress_selected(x, y, out, xor);
    #[cfg(not(rind_argon2_neon))]
    crate::low::generic::argon2::argon2_compress(x, y, out, xor);
}
