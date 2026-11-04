// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

//! ChaCha20-Poly1305: HACL*'s verified `Hacl_Chacha20Poly1305_32`, as
//! libcrux-chacha20poly1305 ships it, on CPUs without NEON. With NEON,
//! aws-lc's ChaCha20 and NEON Poly1305 in separate passes, which are not
//! verified but measured twice as fast from 1200 bytes.

use super::chacha20::ChaCha20;
use super::cpu::HaveNeon;
use super::poly1305_arm::Poly1305Neon;
use crate::low::{ct_equal, zeroise};

/// Encrypts `inout` in place, returning the tag over `aad` and the ciphertext.
pub(crate) fn seal(key: &[u8; 32], nonce: &[u8; 12], aad: &[u8], inout: &mut [u8]) -> [u8; 16] {
    let Some(neon) = HaveNeon::check() else {
        // libcrux reads and writes separate buffers.
        let mut plain = inout.to_vec();
        let mut tag = [0u8; 16];
        let result =
            libcrux_chacha20poly1305::encrypt_detached(key, &plain, inout, &mut tag, aad, nonce);
        // The plaintext copy is on the heap.
        zeroise(&mut plain);
        // Its only errors are lengths past `u32::MAX`, which no slice reaches
        // on a 32-bit target.
        assert!(result.is_ok(), "ChaCha20-Poly1305 lengths fit 32 bits");
        return tag;
    };
    separate(neon, key, nonce, aad, inout, true)
}

/// Decrypts `inout` in place, returning whether `tag` is right.
pub(crate) fn open(
    key: &[u8; 32],
    nonce: &[u8; 12],
    aad: &[u8],
    inout: &mut [u8],
    tag: &[u8; 16],
) -> bool {
    let Some(neon) = HaveNeon::check() else {
        // HACL* checks the tag itself, and decrypts only if it is right.
        let cipher = inout.to_vec();
        return libcrux_chacha20poly1305::decrypt_detached(key, inout, &cipher, tag, aad, nonce)
            .is_ok();
    };
    ct_equal(&separate(neon, key, nonce, aad, inout, false), tag)
}

fn separate(
    neon: HaveNeon,
    key: &[u8; 32],
    nonce: &[u8; 12],
    aad: &[u8],
    inout: &mut [u8],
    seal: bool,
) -> [u8; 16] {
    let mut counter_nonce = [0u8; 16];
    counter_nonce[4..].copy_from_slice(nonce);

    // Block 0's first half keys Poly1305.
    let mut chacha = ChaCha20::new(key, &counter_nonce);
    let mut poly_key = [0u8; 32];
    chacha.cipher(&mut poly_key);
    let mut poly = Poly1305Neon::new(&poly_key, neon);

    // AAD || pad(AAD) || ciphertext || pad(ciphertext) || len_64(AAD) || len_64(ciphertext)
    let pad =
        |poly: &mut Poly1305Neon, len: usize| poly.add_bytes(&[0u8; 16][..(16 - len % 16) % 16]);
    poly.add_bytes(aad);
    pad(&mut poly, aad.len());
    if seal {
        chacha.cipher(inout);
        poly.add_bytes(inout);
    } else {
        poly.add_bytes(inout);
        chacha.cipher(inout);
    }
    pad(&mut poly, inout.len());
    poly.add_bytes(&(aad.len() as u64).to_le_bytes());
    poly.add_bytes(&(inout.len() as u64).to_le_bytes());
    poly.finish()
}

#[cfg(test)]
#[cfg_attr(coverage_nightly, coverage(off))]
mod tests {
    use super::*;
    use crate::low::ct;

    // Every other test sees only the path the CPU picks, so with NEON the
    // separate passes are checked against HACL*'s AEAD here, under a key
    // `admin/ctgrind` keeps secret: every message length through aws-lc's
    // switch to NEON ChaCha20 at 192 bytes and Poly1305's 64-byte loop, AAD
    // lengths around its 16-byte blocks, and a long message.
    #[test]
    fn neon_matches_hacl() {
        let Some(neon) = HaveNeon::check() else {
            return;
        };
        let key = core::array::from_fn(|i| i as u8);
        ct::secret_slice(&key);
        let nonce = core::array::from_fn(|i| (i * 7) as u8);
        let input: Vec<u8> = (0..16384 + 15).map(|i| (i * 13 + 5) as u8).collect();
        let lens = (0..=600)
            .map(|len| (len, 13))
            .chain((0..=48).map(|aad| (300, aad)));
        for (len, aad_len) in lens.chain([(16384 + 15, 13)]) {
            let aad = &input[..aad_len];
            let plain = &input[..len];
            let mut sealed = vec![0u8; len];
            let mut tag = [0u8; 16];
            libcrux_chacha20poly1305::encrypt_detached(
                &key,
                plain,
                &mut sealed,
                &mut tag,
                aad,
                &nonce,
            )
            .unwrap();
            let tag = ct::into_public(tag);
            ct::public_slice(&sealed);

            let mut ours = plain.to_vec();
            let ours_tag = ct::into_public(separate(neon, &key, &nonce, aad, &mut ours, true));
            ct::public_slice(&ours);
            assert_eq!(ours_tag, tag, "seal tag, {len} bytes, {aad_len} of AAD");
            assert_eq!(ours, sealed, "seal, {len} bytes, {aad_len} of AAD");
            let ours_tag = ct::into_public(separate(neon, &key, &nonce, aad, &mut ours, false));
            ct::public_slice(&ours);
            assert_eq!(ours_tag, tag, "open tag, {len} bytes, {aad_len} of AAD");
            assert_eq!(ours, plain, "open, {len} bytes, {aad_len} of AAD");
        }
    }

    fn hacl_mac(key: &[u8; 32], msg: &[u8]) -> [u8; 16] {
        let mut tag = [0u8; 16];
        assert!(libcrux_poly1305::mac(key, msg, &mut tag).is_ok());
        tag
    }

    // The NEON Poly1305 against HACL*'s: every length up to 200 bytes, plus
    // some past the assembly's 64-byte and 32-byte loops, each fed whole and
    // in ragged pieces that cross its 32-byte buffer. The key and message are
    // secret, so under `admin/ctgrind` this also checks both are constant
    // time in them.
    #[test]
    fn neon_poly1305_matches_hacl() {
        let Some(neon) = HaveNeon::check() else {
            return;
        };
        let key: [u8; 32] = core::array::from_fn(|i| 0xa5 ^ (i as u8).wrapping_mul(29));
        let msg: Vec<u8> = (0..1100u32)
            .map(|i| (i.wrapping_mul(0x9e3779b9) >> 24) as u8)
            .collect();
        ct::secret_slice(&key);
        ct::secret_slice(&msg);
        for len in (0..=200).chain([255, 256, 257, 1023, 1024, 1025, 1100]) {
            let msg = &msg[..len];
            let want = ct::into_public(hacl_mac(&key, msg));

            for piece in [len.max(1), 1, 7, 16, 31, 32, 33, 65] {
                let mut got = Poly1305Neon::new(&key, neon);
                for chunk in msg.chunks(piece) {
                    got.add_bytes(chunk);
                }
                assert_eq!(
                    ct::into_public(got.finish()),
                    want,
                    "{len} bytes in pieces of {piece}"
                );
            }
        }

        // All-ones blocks and key push the accumulator to its largest values
        // before the final reduction.
        let ones = [0xff; 32];
        let msg = [0xff; 1100];
        for len in [16, 17, 32, 64, 1100] {
            let mut got = Poly1305Neon::new(&ones, neon);
            got.add_bytes(&msg[..len]);
            assert_eq!(
                ct::into_public(got.finish()),
                ct::into_public(hacl_mac(&ones, &msg[..len])),
                "{len} bytes of ones"
            );
        }
    }
}
