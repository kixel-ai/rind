// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0
//! An OpenSSL 3 provider backed by rind, for the algorithms where rind is
//! faster than OpenSSL's default provider: X25519, Ed25519, ML-KEM, and
//! ML-DSA.
//!
//! OpenSSL loads the shared library this crate builds through
//! `openssl.cnf`, as the README shows. Its one export is
//! [`OSSL_provider_init`]; everything else is OpenSSL's provider ABI.
#![allow(
    clippy::missing_safety_doc,
    reason = "OpenSSL's provider ABI sets every export's safety contract"
)]
#![warn(clippy::undocumented_unsafe_blocks, unreachable_pub)]
// Library code never panics by accident: what can fail returns an error, and
// what cannot states why it holds. Tests may panic (clippy.toml).
#![warn(
    clippy::allow_attributes_without_reason,
    clippy::indexing_slicing,
    clippy::panic,
    clippy::unwrap_used
)]
#![cfg_attr(not(test), warn(clippy::arithmetic_side_effects))]

use core::ffi::{c_int, c_void};

mod ed25519;
mod ffi;
mod keymgmt;
mod ml_dsa;
mod ml_kem;
mod params;
mod pq_keymgmt;
mod provider;
mod x25519;

/// The entry point OpenSSL calls when it loads the provider.
///
/// # Safety
///
/// OpenSSL calls it with its core's handle and dispatch table, and two
/// outputs to write: the provider's table and its context.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn OSSL_provider_init(
    handle: *const c_void,
    core: *const c_void,
    out: *mut *const c_void,
    provctx: *mut *mut c_void,
) -> c_int {
    // SAFETY: per the caller; the pointers are OpenSSL's, cast to its types.
    unsafe { provider::init(handle.cast(), core.cast(), out.cast(), provctx) }
}
