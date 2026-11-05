// Written for Graviola by Joe Birr-Pixton, 2024.
// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

use super::aes::HwKey;
use super::aes128_gcm_dec::aes128_gcm_dec;
use super::aes128_gcm_enc::aes128_gcm_enc;
use super::aes256_gcm_dec::aes256_gcm_dec;
use super::aes256_gcm_dec_alt::aes256_gcm_dec_alt;
use super::aes256_gcm_enc::aes256_gcm_enc;
use super::aes256_gcm_enc_alt::aes256_gcm_enc_alt;
use crate::low::ghash::{Ghash, GhashTable};
use crate::low::{AesKey, aes_ctr, ct_equal};

/// Encrypts `cipher_inout` in place under `nonce`, and returns its tag.
pub(crate) fn seal(
    key: &AesKey,
    table: &GhashTable,
    nonce: &[u8; 12],
    aad: &[u8],
    cipher_inout: &mut [u8],
) -> [u8; 16] {
    tagged::<true>(key, table, nonce, aad, cipher_inout)
}

/// Decrypts `cipher_inout` in place under `nonce`, and returns whether `tag`
/// is its tag, a secret.
pub(crate) fn open(
    key: &AesKey,
    table: &GhashTable,
    nonce: &[u8; 12],
    aad: &[u8],
    cipher_inout: &mut [u8],
    tag: &[u8; 16],
) -> bool {
    ct_equal(&tagged::<false>(key, table, nonce, aad, cipher_inout), tag)
}

fn tagged<const ENC: bool>(
    key: &AesKey,
    table: &GhashTable,
    nonce: &[u8; 12],
    aad: &[u8],
    cipher_inout: &mut [u8],
) -> [u8; 16] {
    tagged_from::<ENC>(key, table, &counter_block(nonce), aad, cipher_inout)
}

/// GCM's first counter block for a 96-bit nonce: the nonce, then 1.
fn counter_block(nonce: &[u8; 12]) -> [u8; 16] {
    let mut y0 = [0u8; 16];
    y0[..12].copy_from_slice(nonce);
    y0[15] = 0x01;
    y0
}

/// GCM's first counter block for `iv`, of any length but zero: the 96-bit
/// nonce's, or else the GHASH of `iv` and its bit length.
pub(crate) fn initial_counter(table: &GhashTable, iv: &[u8]) -> [u8; 16] {
    if let Ok(nonce) = iv.try_into() {
        return counter_block(nonce);
    }
    let mut ghash = Ghash::new(table);
    ghash.add(iv);
    ghash.add(&lengths(0, iv.len()));
    ghash.into_bytes()
}

/// GCM's last GHASH block: the bit lengths of the AAD and the message.
fn lengths(aad: usize, msg: usize) -> [u8; 16] {
    (((aad as u128 * 8) << 64) | (msg as u128 * 8)).to_be_bytes()
}

/// Encrypts (if `ENC`) or decrypts `cipher_inout` in place from the counter
/// block `y0`, and returns its tag.
#[inline]
pub(crate) fn tagged_from<const ENC: bool>(
    key: &AesKey,
    table: &GhashTable,
    y0: &[u8; 16],
    aad: &[u8],
    cipher_inout: &mut [u8],
) -> [u8; 16] {
    let mut ghash = Ghash::new(table);
    cipher::<ENC>(key, &mut ghash, y0, aad, cipher_inout);
    ghash.add(&lengths(aad.len(), cipher_inout.len()));

    let mut tag = *y0;
    key.encrypt_block(&mut tag);
    for (t, x) in tag.iter_mut().zip(ghash.into_bytes()) {
        *t ^= x;
    }
    tag
}

// AES-GCM encrypt (if `ENC` is `true`) or decrypt.
fn cipher<const ENC: bool>(
    key: &AesKey,
    ghash: &mut Ghash<'_>,
    initial_counter: &[u8; 16],
    aad: &[u8],
    cipher_inout: &mut [u8],
) {
    ghash.add(aad);

    let mut counter = *initial_counter;
    inc32(&mut counter);

    let (AesKey::Hw(hw_key), GhashTable::Pmull(table)) = (key, ghash.table) else {
        return composed::<ENC>(key, ghash, &counter, cipher_inout);
    };

    let (blocks, remainder) = cipher_inout.as_chunks_mut::<16>();

    if !blocks.is_empty() {
        let mut tag = ghash.state();
        let htable = &table.htable;
        let [htable4 @ .., _, _, _, _, _, _] = htable;
        let (inout, len) = (blocks.as_mut_ptr(), blocks.len());
        // SAFETY: only a `HaveCryptoExt` token builds `AesKey128` and
        // `AesKey256`, proving the `aes` cpu feature, `eight_way` proves
        // `sha3`, and `inout` is valid for reads and writes of `len`
        // blocks. The kernels' proofs assume the input and output do not
        // overlap, but every path through them loads each input block before
        // storing its output block and never reads an output back, so in
        // place they compute the same, as `admin/parse-asm/inplace.py`
        // checks.
        unsafe {
            match (hw_key, ENC, table.eight_way) {
                (HwKey::Aes128(k), true, _) => {
                    aes128_gcm_enc(inout, len, &mut tag, &mut counter, k.round_keys(), htable4)
                }
                (HwKey::Aes128(k), false, _) => {
                    aes128_gcm_dec(inout, len, &mut tag, &mut counter, k.round_keys(), htable4)
                }
                (HwKey::Aes256(k), true, None) => {
                    aes256_gcm_enc(inout, len, &mut tag, &mut counter, k.round_keys(), htable4)
                }
                (HwKey::Aes256(k), false, None) => {
                    aes256_gcm_dec(inout, len, &mut tag, &mut counter, k.round_keys(), htable4)
                }
                (HwKey::Aes256(k), true, Some(_)) => {
                    aes256_gcm_enc_alt(inout, len, &mut tag, &mut counter, k.round_keys(), htable)
                }
                (HwKey::Aes256(k), false, Some(_)) => {
                    aes256_gcm_dec_alt(inout, len, &mut tag, &mut counter, k.round_keys(), htable)
                }
            }
        }

        ghash.set_state(tag);
    }

    if !remainder.is_empty() {
        if !ENC {
            ghash.add(remainder);
        }

        let mut keystream = counter;
        key.encrypt_block(&mut keystream);
        for (c, k) in remainder.iter_mut().zip(keystream) {
            *c ^= k;
        }

        if ENC {
            ghash.add(remainder);
        }
    }
}

/// AES-CTR and GHASH in separate passes over each eight blocks, for keys
/// without the stitched kernels, as aws-lc composes vpaes and NEON GHASH.
fn composed<const ENC: bool>(
    key: &AesKey,
    ghash: &mut Ghash<'_>,
    counter: &[u8; 16],
    cipher_inout: &mut [u8],
) {
    let (nonce, ctr) = counter.split_at(12);
    let nonce = nonce.try_into().unwrap();
    let mut ctr = u32::from_be_bytes(ctr.try_into().unwrap());

    let (chunks, remainder) = cipher_inout.as_chunks_mut::<128>();
    for chunk in chunks {
        if !ENC {
            ghash.add(chunk);
        }
        aes_ctr::apply(key, nonce, ctr, chunk);
        if ENC {
            ghash.add(chunk);
        }
        ctr = ctr.wrapping_add(8);
    }

    if !ENC {
        ghash.add(remainder);
    }
    aes_ctr::apply(key, nonce, ctr, remainder);
    if ENC {
        ghash.add(remainder);
    }
}

/// Increments the big-endian 32-bit counter in the last four bytes of `block`.
fn inc32(block: &mut [u8; 16]) {
    let b = u128::from_be_bytes(*block);
    let ctr = (b as u32).wrapping_add(1);
    *block = (b & !0xffff_ffff | ctr as u128).to_be_bytes();
}

#[cfg(test)]
#[cfg_attr(coverage_nightly, coverage(off))]
mod tests {
    use super::*;
    use crate::low::aarch64::cpu::HaveCryptoExt;
    use crate::low::aarch64::ghash::PmullTable;
    use crate::low::aarch64::ghash_neon_armv8::NeonTable;
    use crate::low::aarch64::vpaes_armv8::VpaesKey;
    use crate::low::generic::ghash::gcm_model;

    // Every other test sees only the path the CPU picks, so the stitched
    // kernels are checked against vpaes and NEON GHASH here: each key size,
    // and AAD and message lengths around the block and eight-block
    // boundaries, both ways.
    #[test]
    fn kernels_match_composed() {
        let Some(token) = HaveCryptoExt::check() else {
            return;
        };
        let bytes = |n: usize, seed: u32| -> Vec<u8> {
            (0..n as u32)
                .map(|i| (i.wrapping_add(seed).wrapping_mul(0x9e3779b9) >> 24) as u8)
                .collect()
        };
        for key_len in [16, 32] {
            let key = bytes(key_len, 1);
            let hw = AesKey::new(&key);
            let vpaes = AesKey::Vpaes(VpaesKey::new(&key));
            let mut h = [0u8; 16];
            vpaes.encrypt_block(&mut h);
            let pmull = GhashTable::Pmull(PmullTable::new(u128::from_be_bytes(h), token));
            let neon = GhashTable::Neon(NeonTable::new(&h));

            for aad_len in [0, 1, 16, 17] {
                for msg_len in [0, 1, 15, 16, 17, 112, 127, 128, 129, 255, 256, 1000] {
                    let nonce = bytes(12, msg_len as u32).try_into().unwrap();
                    let aad = bytes(aad_len, 2);
                    let plain = bytes(msg_len, 3);

                    let mut want = plain.clone();
                    let want_tag = seal(&hw, &pmull, &nonce, &aad, &mut want);
                    let mut got = plain.clone();
                    let tag = seal(&vpaes, &neon, &nonce, &aad, &mut got);
                    let what = format!("{key_len} {aad_len} {msg_len}");
                    assert_eq!(got, want, "{what}");
                    assert_eq!(tag, want_tag, "{what}");

                    assert!(
                        open(&vpaes, &neon, &nonce, &aad, &mut got, &want_tag),
                        "{what}"
                    );
                    assert_eq!(got, plain, "{what}");
                }
            }
        }
    }

    // An IV other than 96 bits hashes to a counter block whose 32-bit
    // counter may wrap within one message, as GCM's increment does mod 2^32
    // without carrying into the rest of the block: on both paths, at lengths
    // that wrap within the kernels' eight- and four-block loops and tails,
    // or not at all.
    #[test]
    fn counter_wraps() {
        let bytes = |n: usize, seed: u32| -> Vec<u8> {
            (0..n as u32)
                .map(|i| (i.wrapping_add(seed).wrapping_mul(0x9e3779b9) >> 24) as u8)
                .collect()
        };
        for key_len in [16, 32] {
            let key = bytes(key_len, 1);
            let vpaes = AesKey::Vpaes(VpaesKey::new(&key));
            let mut h = [0u8; 16];
            vpaes.encrypt_block(&mut h);
            let mut paths = vec![(vpaes, GhashTable::Neon(NeonTable::new(&h)))];
            if let Some(token) = HaveCryptoExt::check() {
                let pmull = PmullTable::new(u128::from_be_bytes(h), token);
                paths.push((AesKey::new(&key), GhashTable::Pmull(pmull)));
            }

            for (key, table) in &paths {
                for start in [0xffff_ffffu32, 0xffff_fffe, 0xffff_fff9, 0xffff_ff00, 7] {
                    for msg_len in [16, 17, 100, 128, 300, 1000] {
                        let mut y0: [u8; 16] = bytes(16, msg_len as u32).try_into().unwrap();
                        y0[12..].copy_from_slice(&start.to_be_bytes());
                        let aad = bytes(17, 2);
                        let plain = bytes(msg_len, 3);
                        let what = format!("{key_len} {start:x} {msg_len}");
                        let (want, want_tag) =
                            gcm_model(|b| key.encrypt_block(b), &y0, &aad, &plain);

                        let mut got = plain.clone();
                        let tag = tagged_from::<true>(key, table, &y0, &aad, &mut got);
                        assert_eq!((&got, tag), (&want, want_tag), "{what}");

                        let tag = tagged_from::<false>(key, table, &y0, &aad, &mut got);
                        assert_eq!((&got, tag), (&plain, want_tag), "{what}");
                    }
                }
            }
        }
    }
}
