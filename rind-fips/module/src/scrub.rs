// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

//! Zeroization of what a service leaves on the stack: every SSP that lives
//! only inside a call, such as an ECDSA nonce, an expanded AES key, or
//! HMAC's padded key blocks, and every copy a move leaves behind.
//!
//! A service runs in a frame of its own, below its entry point's, and
//! returns only codes and handles; the entry point then zeroes the stack
//! below itself as deep as the service can reach. The break build checks
//! that depth on every call (see [`scrubbed`]).

use core::mem::MaybeUninit;

/// How deep a service's stack reaches, rounded up to a size the break
/// build has checked it stays within.
#[derive(Clone, Copy)]
pub(crate) enum Depth {
    /// Hashing, MACs, KDFs, and the AES modes.
    Small,
    /// Elliptic curves, the DRBG, and parsing keys.
    Medium,
    /// RSA, ML-KEM, and ML-DSA.
    Large,
}

impl Depth {
    const fn bytes(self) -> usize {
        match self {
            Self::Small => 8 << 10,
            Self::Medium => 32 << 10,
            Self::Large => 160 << 10,
        }
    }
}

/// Runs `service` in a frame of its own, then zeroes `depth` of the stack
/// below the caller's frame.
#[inline(always)]
pub(crate) fn scrubbed<R>(depth: Depth, service: impl FnOnce() -> R) -> R {
    #[cfg(rind_fips_break)]
    stack::<MAX>(Op::Paint);
    let result = run(service);
    match depth {
        Depth::Small => stack::<{ Depth::Small.bytes() }>(Op::Zero),
        Depth::Medium => stack::<{ Depth::Medium.bytes() }>(Op::Zero),
        Depth::Large => stack::<{ Depth::Large.bytes() }>(Op::Zero),
    };
    #[cfg(rind_fips_break)]
    {
        let used = stack::<MAX>(Op::Measure);
        // The scrub's frame and the measure's may sit a few words apart.
        if used + 256 > depth.bytes() {
            std::eprintln!(
                "rind-fips: a service used {used} bytes of stack, beyond the {} it zeroes",
                depth.bytes()
            );
            std::process::abort();
        }
    }
    result
}

#[inline(never)]
fn run<R>(service: impl FnOnce() -> R) -> R {
    service()
}

/// The break build's measure of stack use: how far below the caller it
/// paints before the service runs and looks after.
#[cfg(rind_fips_break)]
const MAX: usize = 512 << 10;

#[cfg(rind_fips_break)]
const PAINT: u8 = 0xa5;

#[derive(Clone, Copy, PartialEq, Eq)]
enum Op {
    Zero,
    #[cfg(rind_fips_break)]
    Paint,
    #[cfg(rind_fips_break)]
    Measure,
}

/// Zeroes, paints, or measures the `N` bytes of stack below the caller.
/// Called from one place for each `N`, so its frame lands where the
/// service's did.
#[inline(never)]
fn stack<const N: usize>(op: Op) -> usize {
    let mut frame = MaybeUninit::<[u8; N]>::uninit();
    let bytes = frame.as_mut_ptr().cast::<u8>();
    let used = match op {
        // SAFETY: `frame` is `N` writable bytes.
        Op::Zero => unsafe {
            core::ptr::write_bytes(bytes, 0, N);
            0
        },
        #[cfg(rind_fips_break)]
        // SAFETY: as for `Zero`.
        Op::Paint => unsafe {
            core::ptr::write_bytes(bytes, PAINT, N);
            0
        },
        // Stacks grow down, so the lowest byte the service wrote is the
        // first that is not paint. Reading bytes this frame never wrote is
        // what the measure is for, so it reads them through volatile loads.
        #[cfg(rind_fips_break)]
        // SAFETY: `frame` is `N` readable bytes.
        Op::Measure => unsafe {
            let untouched = (0..N)
                .take_while(|&i| core::ptr::read_volatile(bytes.add(i)) == PAINT)
                .count();
            N - untouched
        },
    };
    // Keeps the compiler from dropping the writes as dead.
    // SAFETY: an empty instruction sequence, which may read `bytes`.
    unsafe {
        core::arch::asm!("/* {0} */", in(reg) bytes, options(nostack, readonly, preserves_flags));
    }
    used
}
