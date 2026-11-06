// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

use core::mem::ManuallyDrop;

use crate::Error;
use crate::cipher::Algorithm;
use crate::low::{self, AesDecKey, AesKey, Entry, Zeroable, ct_equal, zeroise_value};

/// RFC 3394's default initial value, which unwrapping checks.
const IV: [u8; 8] = [0xa6; 8];

/// An AES key-encryption key, which wraps and unwraps other keys with RFC
/// 3394 AES-KW; wiped on drop.
///
/// Wrapping is deterministic and authenticated: a wrapped key that was
/// altered fails to unwrap.
///
/// Each call expands the schedule it needs, as aws-lc does: a KEK usually
/// wraps or unwraps once, as pyca's functions and JWE use it, and holding
/// both schedules would cost that call a second expansion.
pub struct AesKek {
    key: [u8; 32],
    key_len: usize,
}

impl AesKek {
    /// Expands `key` for `algorithm`, failing with [`Error::WrongLength`] if
    /// it is not that algorithm's key length.
    pub fn new(algorithm: &'static Algorithm, key: &[u8]) -> Result<Self, Error> {
        let _entry = Entry::new_secret();
        if key.len() != algorithm.key_len {
            return Err(Error::WrongLength);
        }
        // Mark a copy: the caller's buffer may be shared, or a promoted constant.
        let mut copy = [0u8; 32];
        copy[..key.len()].copy_from_slice(key);
        low::ct::secret_slice(&copy);
        Ok(Self {
            key: copy,
            key_len: key.len(),
        })
    }

    fn key(&self) -> &[u8] {
        &self.key[..self.key_len]
    }

    /// Wraps `key` into `wrapped`, which must be 8 bytes longer.
    ///
    /// Fails with [`Error::WrongLength`], leaving `wrapped` unchanged, if
    /// `key` is shorter than 16 bytes or not a multiple of 8, or `wrapped` is
    /// not 8 bytes longer.
    pub fn wrap(&self, key: &[u8], wrapped: &mut [u8]) -> Result<(), Error> {
        let _entry = Entry::new_secret();
        if key.len() < 16 || !key.len().is_multiple_of(8) || wrapped.len() != key.len() + 8 {
            return Err(Error::WrongLength);
        }
        let (a, r) = wrapped.split_at_mut(8);
        r.copy_from_slice(key);
        low::ct::secret_slice(r);

        // Expanded for this call, so it skips its wipe.
        let aes = ManuallyDrop::new(AesKey::new(self.key()));
        // `block` is A followed by each R[i] in turn.
        let mut block = [0u8; 16];
        block[..8].copy_from_slice(&IV);
        let mut t = 0u64;
        for _ in 0..6 {
            for r_i in r.as_chunks_mut::<8>().0 {
                t += 1;
                block[8..].copy_from_slice(r_i);
                aes.encrypt_block(&mut block);
                xor_counter(&mut block, t);
                r_i.copy_from_slice(&block[8..]);
            }
        }
        a.copy_from_slice(&block[..8]);

        low::ct::public_slice(wrapped);
        Ok(())
    }

    /// Unwraps `wrapped` into `key`, which must be 8 bytes shorter.
    ///
    /// Fails with [`Error::DecryptFailed`] if `wrapped` was not wrapped by
    /// this key, clearing `key`, or is shorter than 24 bytes or not a
    /// multiple of 8, and with [`Error::WrongLength`] if `key` is not 8 bytes
    /// shorter; a length failure leaves `key` unchanged.
    pub fn unwrap(&self, wrapped: &[u8], key: &mut [u8]) -> Result<(), Error> {
        let _entry = Entry::new_secret();
        if wrapped.len() < 24 || !wrapped.len().is_multiple_of(8) {
            return Err(Error::DecryptFailed);
        }
        if key.len() != wrapped.len() - 8 {
            return Err(Error::WrongLength);
        }
        let (a, c) = wrapped.split_at(8);
        key.copy_from_slice(c);

        // Expanded for this call, so it skips its wipe.
        let aes = ManuallyDrop::new(AesDecKey::new(self.key()));
        let mut block = [0u8; 16];
        block[..8].copy_from_slice(a);
        let r = key.as_chunks_mut::<8>().0;
        let mut t = 6 * r.len() as u64;
        for _ in 0..6 {
            for r_i in r.iter_mut().rev() {
                xor_counter(&mut block, t);
                t -= 1;
                block[8..].copy_from_slice(r_i);
                aes.decrypt_block(&mut block);
                r_i.copy_from_slice(&block[8..]);
            }
        }

        if low::ct::into_public(ct_equal(&block[..8], &IV)) {
            low::ct::public_slice(key);
            Ok(())
        } else {
            // avoid unauthenticated key leak
            key.fill(0x00);
            Err(Error::DecryptFailed)
        }
    }
}

impl Drop for AesKek {
    fn drop(&mut self) {
        zeroise_value(self);
    }
}

impl Zeroable for AesKek {}

/// XORs the step counter `t`, big-endian, into A.
#[inline]
fn xor_counter(block: &mut [u8; 16], t: u64) {
    let a: &mut [u8; 8] = block.first_chunk_mut().unwrap();
    *a = (u64::from_ne_bytes(*a) ^ t.to_be()).to_ne_bytes();
}

#[cfg(test)]
#[cfg_attr(coverage_nightly, coverage(off))]
mod tests {
    use super::*;
    use crate::cipher::{AES_128, AES_256};

    // RFC 3394 section 4.1 and 4.6: the smallest and largest key under each
    // KEK size, both ways.
    #[test]
    fn rfc3394() {
        for (algorithm, kek, key, wrapped) in [
            (
                &AES_128,
                "000102030405060708090a0b0c0d0e0f",
                "00112233445566778899aabbccddeeff",
                "1fa68b0a8112b447aef34bd8fb5a7b829d3e862371d2cfe5",
            ),
            (
                &AES_256,
                "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f",
                "00112233445566778899aabbccddeeff000102030405060708090a0b0c0d0e0f",
                "28c9f404c4b810f4cbccb35cfb87f8263f5786e2d80ed326cbc7f0e71a99f43bfb988b9b7a02dd21",
            ),
        ] {
            let kek = AesKek::new(algorithm, &hex::decode(kek).unwrap()).unwrap();
            let key = hex::decode(key).unwrap();
            let wrapped = hex::decode(wrapped).unwrap();

            let mut out = vec![0u8; wrapped.len()];
            kek.wrap(&key, &mut out).unwrap();
            assert_eq!(out, wrapped);

            let mut out = vec![0u8; key.len()];
            kek.unwrap(&wrapped, &mut out).unwrap();
            assert_eq!(out, key);
        }
    }

    #[test]
    fn unwrap_failure_clears_key() {
        let kek = AesKek::new(&AES_128, &[0x42; 16]).unwrap();
        let mut wrapped = [0u8; 40];
        kek.wrap(&[0x24; 32], &mut wrapped).unwrap();

        // every byte is covered, the integrity value and each key block
        for i in [0, 7, 8, 39] {
            let mut tampered = wrapped;
            tampered[i] ^= 1;
            let mut key = [0xaa; 32];
            assert_eq!(kek.unwrap(&tampered, &mut key), Err(Error::DecryptFailed));
            assert_eq!(key, [0; 32], "byte {i}");
        }
    }

    #[test]
    fn lengths() {
        let kek = AesKek::new(&AES_256, &[0x42; 32]).unwrap();
        let buf = [0x55u8; 64];
        for len in 0..=48usize {
            let valid = len >= 16 && len.is_multiple_of(8);
            let mut wrapped = vec![0xaa; len + 8];
            let result = kek.wrap(&buf[..len], &mut wrapped);
            assert_eq!(result.is_ok(), valid, "wrap {len}");
            if !valid {
                assert!(wrapped.iter().all(|b| *b == 0xaa), "refused wrap wrote");
            }

            // malformed, or well formed but not wrapped by this key
            let mut key = vec![0xaa; len.saturating_sub(8)];
            let result = kek.unwrap(&buf[..len], &mut key);
            assert_eq!(result, Err(Error::DecryptFailed), "unwrap {len}");
            if len < 24 || !len.is_multiple_of(8) {
                assert!(key.iter().all(|b| *b == 0xaa), "refused unwrap wrote");
            }
        }

        // the other buffer's length must match
        let mut wrapped = [0u8; 32];
        assert_eq!(kek.wrap(&buf[..16], &mut wrapped), Err(Error::WrongLength));
        kek.wrap(&buf[..24], &mut wrapped).unwrap();
        let mut key = [0u8; 16];
        assert_eq!(kek.unwrap(&wrapped, &mut key), Err(Error::WrongLength));

        assert!(AesKek::new(&AES_128, &[0; 32]).is_err());
        assert!(AesKek::new(&AES_256, &[0; 16]).is_err());
    }

    // armv7's AES-KW on the crypto extension, which valgrind hides, for each
    // key size, with a secret KEK and key, for `admin/ct-qemu`.
    #[cfg(target_arch = "arm")]
    #[test]
    #[ignore = "admin/ct-qemu runs it under qemu-arm"]
    fn ct_qemu_aes_kw() {
        use crate::low::ct_qemu;

        let seed = ct_qemu::seed().to_le_bytes();
        let bytes = |n| seed.iter().cycle().take(n).copied().collect::<Vec<u8>>();
        for algorithm in [&AES_128, &AES_256] {
            let kek_bytes = bytes(algorithm.key_len);
            let kek = ct_qemu::traced(|| AesKek::new(algorithm, &kek_bytes).unwrap());
            assert!(
                matches!(AesDecKey::new(kek.key()), AesDecKey::Hw(_)),
                "the crypto extension"
            );

            let key = bytes(32);
            let mut wrapped = [0u8; 40];
            ct_qemu::traced(|| kek.wrap(&key, &mut wrapped)).unwrap();
            let mut unwrapped = [0u8; 32];
            ct_qemu::traced(|| kek.unwrap(&wrapped, &mut unwrapped)).unwrap();
        }
    }
}
