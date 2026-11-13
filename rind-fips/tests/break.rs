// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

//! The break build (`--features __break_tests`) shows each self-test's
//! failure path, as a lab asks to see: `RIND_FIPS_BREAK` names a test whose
//! input the module corrupts, and the module must print that test's name and
//! abort, so nothing after it runs.
//!
//! Each case runs a trigger test of this binary again in a child, which
//! loads the module with the variable set.
#![cfg(feature = "__break_tests")]

use std::process::Command;

/// Every known-answer test, by the name the module prints, and the
/// integrity test.
const SELF_TESTS: [&str; 26] = [
    "integrity",
    "sha1",
    "sha256",
    "sha512",
    "sha3",
    "hmac",
    "hkdf",
    "pbkdf2",
    "aes_encrypt",
    "aes_decrypt",
    "aes_gcm_seal",
    "aes_gcm_open",
    "drbg",
    "ecdsa_sign",
    "ecdsa_verify",
    "ecdh",
    "ed25519_sign",
    "ed25519_verify",
    "rsa_sign",
    "rsa_verify",
    "ml_kem_keygen",
    "ml_kem_encaps",
    "ml_kem_decaps",
    "ml_dsa_keygen",
    "ml_dsa_sign",
    "ml_dsa_verify",
];

/// Runs trigger test `trigger` in a child with `RIND_FIPS_BREAK=name`,
/// returning whether it succeeded and its standard error.
fn run(trigger: &str, name: &str) -> (bool, String) {
    let output = Command::new(std::env::current_exe().unwrap())
        .args(["--exact", trigger, "--test-threads=1", "--nocapture"])
        .env("RIND_FIPS_BREAK", name)
        .output()
        .unwrap();
    (
        output.status.success(),
        String::from_utf8_lossy(&output.stderr).into_owned(),
    )
}

/// Asserts that breaking `name` makes `trigger` fail at that test, printing
/// its name, before the trigger's own output.
fn assert_breaks(trigger: &str, name: &str) {
    let (succeeded, stderr) = run(trigger, name);
    assert!(!succeeded, "breaking {name} did not fail {trigger}: {stderr}");
    assert!(
        stderr.contains(&format!("rind-fips: {name} self-test failed")),
        "breaking {name} failed {trigger} otherwise: {stderr}"
    );
    assert!(
        !stderr.contains("trigger done"),
        "{trigger} went on after {name} failed: {stderr}"
    );
}

/// What the children run: every self-test, on demand.
#[test]
fn trigger_self_test() {
    rind_fips::self_test();
    eprintln!("trigger done");
}

#[test]
fn every_self_test_fails_when_broken() {
    for name in SELF_TESTS {
        assert_breaks("trigger_self_test", name);
    }
}

#[test]
fn an_unknown_name_breaks_nothing() {
    let (succeeded, stderr) = run("trigger_self_test", "sha");
    assert!(succeeded, "{stderr}");
}
