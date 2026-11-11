// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

//! The portable public-key arithmetic on 32-bit limbs, for 32-bit targets,
//! armv7 among them, whose 32 by 32-bit product is one instruction where a
//! 64-bit limb's high half would be a library call. wasm32 is one: it
//! multiplies 64-bit values natively, but only to their low half until its
//! `wide-arithmetic` instructions, which stable Rust cannot yet enable.
//!
//! Each module here is also [`super::limb64`]'s, over 64-bit limbs.

/// One limb.
type Limb = u32;
/// Twice a limb, which holds a product of two and two more limbs.
type Wide = u64;

#[path = "mont.rs"]
#[allow(clippy::duplicate_mod, reason = "shared with `limb64`")]
pub(crate) mod mont;
