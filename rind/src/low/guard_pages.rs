// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

//! Runs each kernel that takes a caller's slice with that slice against a
//! `PROT_NONE` page, so a load or store past either end faults. Valgrind
//! cannot decode the fastest tiers and AddressSanitizer does not instrument
//! assembly, so nothing else checks their bounds.

use crate::aead::{self, Nonce, gcm};
use crate::cipher::{AES_128, AES_256, AesCbcDecryptingKey, AesCbcEncryptingKey, AesCtr, ChaCha20};
use crate::{constant_time, digest, hmac};

/// Past the widest stride of every backend (AVX-512 ChaCha20's 1 KiB) and
/// each short-message threshold below it.
const MAX_LEN: usize = 1100;

/// AES-GCM's 512-bit VAES kernel starts at 2048 bytes; these cover its
/// threshold, a stride past it, and the tails.
const LONG_AEAD_LENS: core::ops::RangeInclusive<usize> = 2000..=2600;

/// Start offsets for the placement just after the leading guard page. The
/// placement against the trailing one starts at every alignment as `len`
/// varies.
const START_OFFSETS: [usize; 3] = [0, 1, 15];

/// One writable page between two `PROT_NONE` pages.
struct Guarded {
    base: *mut u8,
    page: usize,
}

impl Guarded {
    fn new() -> Self {
        // SAFETY: sysconf has no preconditions.
        let page = usize::try_from(unsafe { libc::sysconf(libc::_SC_PAGESIZE) }).unwrap();
        assert!(page >= LONG_AEAD_LENS.end() + START_OFFSETS[2]);
        // SAFETY: a fresh anonymous mapping aliases nothing.
        let base = unsafe {
            libc::mmap(
                core::ptr::null_mut(),
                3 * page,
                libc::PROT_NONE,
                libc::MAP_PRIVATE | libc::MAP_ANON,
                -1,
                0,
            )
        };
        assert_ne!(base, libc::MAP_FAILED);
        let base = base.cast::<u8>();
        // SAFETY: the middle page lies inside the mapping just made.
        let made = unsafe {
            libc::mprotect(
                base.add(page).cast(),
                page,
                libc::PROT_READ | libc::PROT_WRITE,
            )
        };
        assert_eq!(made, 0);
        Self { base, page }
    }

    /// `len` bytes starting `offset` past the leading guard page.
    fn after_start(&mut self, offset: usize, len: usize) -> &mut [u8] {
        assert!(offset + len <= self.page);
        // SAFETY: the range lies in the writable page, borrowed from `self`.
        unsafe { core::slice::from_raw_parts_mut(self.base.add(self.page + offset), len) }
    }

    /// `len` bytes ending at the trailing guard page.
    fn before_end(&mut self, len: usize) -> &mut [u8] {
        let page = self.page;
        self.after_start(page - len, len)
    }

    /// Copies `src` into each placement in turn and runs `f` on it.
    fn each(&mut self, src: &[u8], mut f: impl FnMut(&mut [u8])) {
        let buf = self.before_end(src.len());
        buf.copy_from_slice(src);
        f(buf);
        for offset in START_OFFSETS {
            let buf = self.after_start(offset, src.len());
            buf.copy_from_slice(src);
            f(buf);
        }
    }
}

impl Drop for Guarded {
    fn drop(&mut self) {
        // SAFETY: unmaps exactly the mapping `new` made.
        assert_eq!(unsafe { libc::munmap(self.base.cast(), 3 * self.page) }, 0);
    }
}

fn message(len: usize) -> Vec<u8> {
    (0..len).map(|i| i as u8).collect()
}

#[test]
fn aead() {
    let mut in_out = Guarded::new();
    let mut aad = Guarded::new();
    for algorithm in [
        &aead::AES_128_GCM,
        &aead::AES_256_GCM,
        &aead::CHACHA20_POLY1305,
    ] {
        let key = aead::Key::new(algorithm, &[7; 32][..algorithm.key_len()]).unwrap();
        let nonce = || Nonce::assume_unique_for_key([9; 12]);
        let check = |aad: &[u8], in_out: &mut [u8]| {
            // The reference seals unguarded copies.
            let (unguarded_aad, mut expect) = (aad.to_vec(), in_out.to_vec());
            let tag = key
                .seal_in_place_separate_tag(nonce(), &unguarded_aad, &mut expect)
                .unwrap();
            let plain = in_out.to_vec();
            let got = key
                .seal_in_place_separate_tag(nonce(), aad, in_out)
                .unwrap();
            assert_eq!((&*in_out, got.as_ref()), (&expect[..], tag.as_ref()));
            key.open_in_place_separate_tag(nonce(), aad, tag, in_out)
                .unwrap();
            assert_eq!(in_out, plain);
        };
        for len in 0..=MAX_LEN {
            in_out.each(&message(len), |buf| check(&[1; 13], buf));
            aad.each(&message(len), |aad| check(aad, &mut message(67)));
        }
        for len in LONG_AEAD_LENS {
            in_out.each(&message(len), |buf| check(&[1; 13], buf));
        }
    }
}

// An IV of other than 12 bytes, and a truncated tag, are buffers of their own.
#[test]
fn aes_gcm_any_iv_and_tag() {
    let mut iv = Guarded::new();
    let mut tag = Guarded::new();
    for tag_len in [gcm::TagLength::Full, gcm::TagLength::Truncated120] {
        let key = gcm::Key::new(&AES_128, &[7; 16], tag_len).unwrap();
        for len in 1..=200 {
            iv.each(&message(len), |iv| {
                let seal = |in_out: &mut [u8]| {
                    let iv = gcm::Iv::assume_unique_for_key(iv).unwrap();
                    key.seal_in_place_separate_tag(iv, b"aad", in_out).unwrap()
                };
                let mut expect = message(70);
                let sealed = seal(&mut expect);
                tag.each(sealed.as_ref(), |tag| {
                    let iv = gcm::Iv::assume_unique_for_key(iv).unwrap();
                    let mut in_out = expect.clone();
                    key.open_in_place_separate_tag(iv, b"aad", tag, &mut in_out)
                        .unwrap();
                    assert_eq!(in_out, message(70));
                });
            });
        }
    }
}

#[test]
fn ciphers() {
    let mut guarded = Guarded::new();
    let ctr = AesCtr::new(&AES_256, &[7; 32], 32).unwrap();
    let chacha = ChaCha20::new(&[7; 32]);
    let cbc_enc = AesCbcEncryptingKey::new(&AES_128, &[7; 16]).unwrap();
    let cbc_dec = AesCbcDecryptingKey::new(&AES_128, &[7; 16]).unwrap();
    for len in 0..=MAX_LEN {
        let src = message(len);
        let mut expect = src.clone();
        ctr.apply_keystream(&[3; 16], &mut expect).unwrap();
        guarded.each(&src, |buf| {
            ctr.apply_keystream(&[3; 16], buf).unwrap();
            assert_eq!(buf, expect);
        });

        let mut expect = src.clone();
        chacha.apply_keystream(&[3; 12], 1, &mut expect).unwrap();
        guarded.each(&src, |buf| {
            chacha.apply_keystream(&[3; 12], 1, buf).unwrap();
            assert_eq!(buf, expect);
        });

        if len % 16 == 0 {
            let iv = || crate::cipher::CbcIv::assume_unpredictable([3; 16]);
            let mut expect = src.clone();
            cbc_enc.encrypt_blocks(iv(), &mut expect).unwrap();
            guarded.each(&src, |buf| {
                cbc_enc.encrypt_blocks(iv(), buf).unwrap();
                assert_eq!(buf, expect);
                cbc_dec.decrypt_blocks(&[3; 16], buf).unwrap();
                assert_eq!(buf, src);
            });
        }
    }
}

// The one-shot digest hands the caller's slice, tail included, straight to
// the block and finishing functions; HMAC reaches the same ones.
#[test]
fn digests() {
    let mut guarded = Guarded::new();
    let hmac_key = hmac::Key::new(&hmac::HMAC_SHA256, &[7; 32]);
    let algorithms = [
        &digest::legacy::MD5,
        &digest::legacy::SHA1,
        &digest::SHA256,
        &digest::SHA384,
        &digest::SHA512,
        &digest::SHA3_256,
    ];
    for len in 0..=MAX_LEN {
        let src = message(len);
        for algorithm in algorithms {
            let expect = digest::digest(algorithm, &src);
            guarded.each(&src, |buf| {
                assert_eq!(digest::digest(algorithm, buf).as_ref(), expect.as_ref());
            });
        }
        let expect = hmac::sign(&hmac_key, &src);
        guarded.each(&src, |buf| {
            assert_eq!(hmac::sign(&hmac_key, buf).as_ref(), expect.as_ref());
        });
    }
}

#[test]
fn compare_and_zero() {
    let mut a = Guarded::new();
    let mut b = Guarded::new();
    for len in 0..=MAX_LEN {
        let src = message(len);
        a.each(&src, |a| {
            b.each(&src, |b| constant_time::verify(a, b).unwrap());
            super::zero_bytes(a.as_mut_ptr(), a.len());
            assert!(a.iter().all(|&x| x == 0));
        });
    }
}

/// Checks the guard pages fault, by reading one byte before and after a
/// placed buffer in a forked child. A fork, not a new process, so it runs
/// under the same qemu runner as the parent.
#[test]
fn planted_over_read_faults() {
    for before in [true, false] {
        let mut guarded = Guarded::new();
        let buf = guarded.after_start(0, 64);
        let past = if before {
            buf.as_ptr().wrapping_sub(1)
        } else {
            guarded.before_end(64).as_ptr().wrapping_add(64)
        };
        // SAFETY: the child calls only async-signal-safe functions before
        // `_exit`, as a fork of a threaded process must.
        let pid = unsafe { libc::fork() };
        assert!(pid >= 0);
        if pid == 0 {
            // SAFETY: restores the default action, so a sanitizer's handler
            // cannot turn the fault into an ordinary exit, then makes the
            // deliberate out-of-bounds read the guard page must catch.
            unsafe {
                libc::signal(libc::SIGSEGV, libc::SIG_DFL);
                libc::signal(libc::SIGBUS, libc::SIG_DFL);
                core::ptr::read_volatile(past);
                libc::_exit(0);
            }
        }
        let mut status = 0;
        // SAFETY: waits on the child just forked.
        assert_eq!(unsafe { libc::waitpid(pid, &mut status, 0) }, pid);
        assert!(
            libc::WIFSIGNALED(status)
                && matches!(libc::WTERMSIG(status), libc::SIGSEGV | libc::SIGBUS),
            "reading {} the buffer did not fault: status {status:#x}",
            if before { "before" } else { "after" },
        );
    }
}
