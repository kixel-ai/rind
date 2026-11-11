// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

//! The portable public-key arithmetic on 64-bit limbs, for 64-bit targets,
//! which form a 128-bit product in one or two multiply instructions, for a
//! quarter of [`super::limb32`]'s products.
//!
//! Each module here is also `limb32`'s, over 32-bit limbs.

/// One limb.
type Limb = u64;
/// Twice a limb, which holds a product of two and two more limbs.
type Wide = u128;

use fiat_crypto::{p256_64 as fiat_p256, p256_scalar_64 as fiat_p256_scalar};

#[path = "mont.rs"]
#[allow(
    clippy::duplicate_mod,
    clippy::modulo_one,
    clippy::useless_conversion,
    trivial_numeric_casts,
    reason = "shared with `limb32`, whose limbs are narrower than a word"
)]
pub(crate) mod mont;
#[path = "p256.rs"]
#[allow(
    clippy::duplicate_mod,
    clippy::modulo_one,
    clippy::useless_conversion,
    trivial_numeric_casts,
    reason = "shared with `limb32`, whose limbs are narrower than a word"
)]
pub(crate) mod p256;
#[path = "p256_mul64.rs"]
mod p256_mul;
