// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

//! AES-192's key schedule, FIPS 197 section 5.2, word by word.
//!
//! Its six-word stride splits round keys across iterations, so the
//! four-word vector forms the backends use for AES-128 and AES-256 do not
//! fit it; a key schedule runs once per key, so this simpler form costs
//! little. Each backend passes its own constant-time SubWord.

/// The 13 round keys of the 24-byte `key`, with `sub_word` applying the
/// S-box to each byte of a little-endian word.
#[inline(always)]
pub(crate) fn expand(key: &[u8; 24], mut sub_word: impl FnMut(u32) -> u32) -> [[u8; 16]; 13] {
    const RCON: [u32; 8] = [0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80];

    let mut w = [0u32; 52];
    for (w, bytes) in w.iter_mut().zip(key.as_chunks::<4>().0) {
        *w = u32::from_le_bytes(*bytes);
    }
    for i in 6..52 {
        let mut t = w[i - 1];
        if i % 6 == 0 {
            // RotWord moves the first byte, the lowest, to the end.
            t = sub_word(t.rotate_right(8)) ^ RCON[i / 6 - 1];
        }
        w[i] = w[i - 6] ^ t;
    }

    let mut round_keys = [[0u8; 16]; 13];
    for (rk, words) in round_keys.iter_mut().zip(w.as_chunks::<4>().0) {
        for (bytes, word) in rk.as_chunks_mut::<4>().0.iter_mut().zip(words) {
            *bytes = word.to_le_bytes();
        }
    }
    round_keys
}
