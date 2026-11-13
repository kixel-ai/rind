// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

//! The self-tests: each algorithm's CAST runs once, before its first use,
//! as IG 10.3.A allows, so a process pays only for what it uses. A failure
//! enters the error state, aborting, so no output follows a failed test.

use std::sync::Once;

pub(crate) use rind::fips::SelfTest;
use rind::fips::{broken, fail};

static PASSED: [Once; SelfTest::ALL.len()] = [const { Once::new() }; SelfTest::ALL.len()];

/// Runs each of `tests` that has not yet passed in this process, blocking
/// any other thread that needs one until it has.
pub(crate) fn ensure(tests: &[SelfTest]) {
    for &test in tests {
        PASSED[index(test)].call_once(|| run(test));
    }
}

/// Runs every self-test now, passed before or not: the on-demand service.
pub(crate) fn run_all() {
    for test in SelfTest::ALL {
        run(test);
        PASSED[index(test)].call_once(|| {});
    }
}

fn run(test: SelfTest) {
    if let Err(name) = test.run() {
        fail(name);
    }
}

fn index(test: SelfTest) -> usize {
    SelfTest::ALL.iter().position(|&t| t == test).unwrap()
}

/// A pairwise consistency test's outcome: aborts naming `name` unless
/// `passed`, which the break build forces false when `RIND_FIPS_BREAK`
/// names it.
pub(crate) fn pct(name: &str, passed: impl FnOnce() -> bool) {
    if broken(name) || !passed() {
        fail(name);
    }
}
