// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0
#![doc = include_str!("../README.md")]
#![warn(
    clippy::undocumented_unsafe_blocks,
    elided_lifetimes_in_paths,
    missing_docs,
    unreachable_pub,
    unused_qualifications
)]

mod error;
mod ffi;

pub use error::{Error, KeyRejected};

/// The module's name and version, as its security policy names it.
///
/// ```
/// assert!(rind_fips::version().starts_with("rind-fips "));
/// ```
pub fn version() -> &'static str {
    let mut len = 0;
    // SAFETY: `len` is writable; the string lives as long as the module,
    // which is never unloaded.
    let bytes = unsafe { core::slice::from_raw_parts(ffi::rind_fips_version(&mut len), len) };
    core::str::from_utf8(bytes).expect("the module's version is UTF-8")
}

/// Runs the module's self-tests now: the integrity test, then every
/// algorithm's known-answer test, whether it has run or not.
///
/// Each runs before its algorithm's first use anyway; this is the on-demand
/// test FIPS 140-3 asks a module to offer. A failure aborts the process,
/// naming the test, as the module's error state.
pub fn self_test() {
    // SAFETY: no arguments.
    unsafe { ffi::rind_fips_self_test() }
}

/// Cryptographic hash functions: SHA-2 and SHA-3.
///
/// ```
/// use rind_fips::digest;
///
/// let mut ctx = digest::Context::new(&digest::SHA256);
/// ctx.update(b"hello, ");
/// ctx.update(b"world");
/// assert_eq!(
///     ctx.finish().as_ref(),
///     digest::digest(&digest::SHA256, b"hello, world").as_ref(),
/// );
/// ```
pub mod digest;

/// Constant-time comparison, for checking a secret such as a MAC or token.
///
/// ```
/// use rind_fips::constant_time;
///
/// constant_time::verify(b"expected", b"expected").unwrap();
/// assert_eq!(
///     constant_time::verify(b"expected", b"presented"),
///     Err(rind_fips::Error::WrongLength)
/// );
/// assert_eq!(
///     constant_time::verify(b"expected", b"Expected"),
///     Err(rind_fips::Error::NotEqual)
/// );
/// ```
pub mod constant_time {
    use crate::{Error, ffi};

    /// Checks that `a` and `b` are equal in constant time, failing with
    /// [`Error::WrongLength`] if their lengths differ and
    /// [`Error::NotEqual`] if their contents do.
    pub fn verify(a: &[u8], b: &[u8]) -> Result<(), Error> {
        // SAFETY: both are readable for their lengths.
        ffi::check(unsafe {
            ffi::rind_fips_constant_time_verify(a.as_ptr(), a.len(), b.as_ptr(), b.len())
        })
    }
}

/// Random bytes from the module's SP 800-90A DRBG, seeded from the system.
///
/// ```
/// let mut nonce = [0u8; 16];
/// rind_fips::rand::fill(&mut nonce).unwrap();
/// ```
pub mod rand {
    use crate::{Error, ffi};

    /// Fills the entirety of `out` with random bytes.
    pub fn fill(out: &mut [u8]) -> Result<(), Error> {
        // SAFETY: `out` is writable for its length.
        ffi::check(unsafe { ffi::rind_fips_rand_fill(out.as_mut_ptr(), out.len()) })
    }
}

/// CPU support.
///
/// The module requires AES, carry-less multiplication, and, on x86_64, the
/// AVX2 generation's integer instructions, and refuses to load on a CPU
/// without them, naming the first one missing.
pub mod cpu;
