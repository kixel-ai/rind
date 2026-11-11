// Written for Graviola by Joe Birr-Pixton, 2024.
// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

use crate::low::{Entry, ct_compare_16, ct_compare_bytes};

pub(crate) fn ct_equal(a: &[u8], b: &[u8]) -> bool {
    Entry::assert_held();
    if a.len() != b.len() {
        return false;
    }

    // Every AEAD open checks a 16-byte tag, which compares as whole words
    // rather than through the byte loop.
    let diff = match (<[u8; 16]>::try_from(a), <[u8; 16]>::try_from(b)) {
        (Ok(a), Ok(b)) => ct_compare_16(&a, &b),
        _ => ct_compare_bytes(a, b).into(),
    };
    // The result stays secret: a caller that accepts or rejects on it
    // declassifies it, but ML-KEM's implicit rejection must not.
    diff == 0
}

#[cfg(test)]
#[cfg_attr(coverage_nightly, coverage(off))]
mod tests {
    use super::*;
    use crate::low::ct;

    // Every length up to 1 KiB, the 16-byte words included, differing in
    // each byte in turn, under inputs `admin/ctgrind` keeps secret.
    #[test]
    fn matches_eq() {
        equiv(&[], &[]);
        for n in 1..1024 {
            let a = vec![0u8; n];
            equiv(&a, &a.clone());
            for i in 0..n {
                let mut b = vec![0u8; n];
                b[i] = 1 << (i % 8);
                equiv(&a, &b);
            }
        }
        equiv(&[0; 16], &[0; 15]);
    }

    fn equiv(a: &[u8], b: &[u8]) {
        let want = a == b;
        ct::secret_slice(a);
        ct::secret_slice(b);
        assert_eq!(want, ct::into_public(ct_equal(a, b)));
        ct::public_slice(a);
        ct::public_slice(b);
    }
}
