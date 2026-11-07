// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

//! Divisions of a secret that `admin/ct-vartime` must find, so a scan that
//! finds nothing fails. Only that scan builds with `--cfg
//! rind_vartime_planted`.

/// A divide instruction, or on armv7, which has none, a call to the
/// compiler's division routine.
fn planted_division(secret: u64, by: u64) -> u64 {
    secret / by
}

/// A call to the compiler's 128-bit division routine, which armv7 lacks.
fn planted_wide_division(secret: u128, by: u128) -> u128 {
    secret / by
}

// Nothing calls them, so this keeps them in rind's rlib.
#[used]
static PLANTED: (fn(u64, u64) -> u64, fn(u128, u128) -> u128) =
    (planted_division, planted_wide_division);
