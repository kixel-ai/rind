// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

//! Each public call that handles a secret runs under DIT, and costs the
//! number of DIT toggles listed for it.
//!
//! The toggle counts come from [`super::model`], which counts on every
//! backend, so they are checked on x86_64 too. Where rind sets DIT (Apple's
//! targets, or any aarch64 OS with `--cfg rind_dit_everywhere`) a debug
//! build also reads PSTATE.DIT at each secret `Entry` and each primitive's
//! [`super::Entry::assert_held`], and these tests require those reads to
//! have run and passed, and DIT to be clear again after each call.

use super::model;
use crate::{aead, agreement, constant_time, digest, ed25519, hkdf, hmac};

/// A public call, and the DIT toggles it costs alone.
struct Call {
    name: &'static str,
    toggles: u64,
    run: fn(),
}

fn quic_key(algorithm: &'static aead::quic::Algorithm) -> aead::quic::HeaderProtectionKey {
    aead::quic::HeaderProtectionKey::new(algorithm, &[7; 32][..algorithm.key_len()]).unwrap()
}

fn hmac_key() -> hmac::Key {
    hmac::Key::new(&hmac::HMAC_SHA256, &[1; 32])
}

fn aead_key(algorithm: &'static aead::Algorithm) -> aead::Key {
    aead::Key::new(algorithm, &[2; 32][..algorithm.key_len()]).unwrap()
}

fn nonce() -> aead::Nonce {
    aead::Nonce::assume_unique_for_key([3; 12])
}

fn sealed(algorithm: &'static aead::Algorithm) -> (aead::Key, [u8; 1350], aead::Tag) {
    let key = aead_key(algorithm);
    let mut packet = [4; 1350];
    let tag = key
        .seal_in_place_separate_tag(nonce(), b"header", &mut packet)
        .unwrap();
    (key, packet, tag)
}

/// Each call runs its operation on values made before it is timed, so its
/// count is the operation's alone. Setup that makes those values runs
/// outside the count, in `setup`.
macro_rules! call {
    ($name:literal, $toggles:literal, || $body:expr) => {
        Call {
            name: $name,
            toggles: $toggles,
            run: || {
                let _value = $body;
            },
        }
    };
}

/// Runs `body` and returns the toggles it made.
fn toggles(body: impl FnOnce()) -> u64 {
    let before = model::toggles();
    body();
    model::toggles() - before
}

fn calls() -> [Call; 24] {
    [
        call!("digest::digest", 1, || digest::digest(
            &digest::SHA256,
            &[5; 1350]
        )),
        call!("digest::Context::update", 1, || {
            digest::Context::new(&digest::SHA256).update(&[5; 1350])
        }),
        call!("digest::Context::finish", 1, || {
            digest::Context::new(&digest::SHA256).finish()
        }),
        call!("hmac::Key::new", 1, || hmac_key()),
        call!("hmac::sign", 1, || hmac::sign(
            &hmac_key_untimed(),
            &[5; 1350]
        )),
        call!("hmac::verify", 1, || {
            let key = hmac_key_untimed();
            hmac::verify(&key, b"m", &[0; 32]).unwrap_err();
        }),
        call!("hkdf::Salt::new", 1, || hkdf::Salt::new(
            &hkdf::HKDF_SHA256,
            b"salt"
        )),
        call!("hkdf::Salt::extract", 1, || salt_untimed()
            .extract(&[6; 32])
            .unwrap()),
        call!("hkdf::Prk::new", 1, || prk()),
        call!("hkdf::Prk::fill", 1, || {
            prk_untimed().fill(&[b"info"], &mut [0; 32]).unwrap()
        }),
        // Each conversion expands, then keys what it expanded: two entries,
        // one after the other.
        call!("hkdf Okm into aead::Key", 2, || {
            aead::Key::from(
                prk_untimed()
                    .expand(&[b"quic key"], &aead::AES_128_GCM)
                    .unwrap(),
            )
        }),
        call!("hkdf Okm into quic::HeaderProtectionKey", 2, || {
            aead::quic::HeaderProtectionKey::from(
                prk_untimed()
                    .expand(&[b"quic hp"], &aead::quic::AES_128)
                    .unwrap(),
            )
        }),
        call!("hkdf Okm into hmac::Key", 2, || {
            hmac::Key::from(
                prk_untimed()
                    .expand(&[b"finished"], &hmac::HMAC_SHA256)
                    .unwrap(),
            )
        }),
        call!("hkdf Okm into Prk", 2, || {
            hkdf::Prk::from(
                prk_untimed()
                    .expand(&[b"derived"], &hkdf::HKDF_SHA256)
                    .unwrap(),
            )
        }),
        call!("aead::Key::new AES-128-GCM", 1, || aead_key(
            &aead::AES_128_GCM
        )),
        call!("aead::Key::seal AES-128-GCM", 1, || {
            aead_key_untimed(&aead::AES_128_GCM)
                .seal_in_place_separate_tag(nonce(), b"header", &mut [4; 1350])
                .unwrap()
        }),
        call!("aead::Key::open AES-128-GCM", 1, || open_untimed(
            &aead::AES_128_GCM
        )),
        call!("aead::Key::seal ChaCha20-Poly1305", 1, || {
            aead_key_untimed(&aead::CHACHA20_POLY1305)
                .seal_in_place_separate_tag(nonce(), b"header", &mut [4; 1350])
                .unwrap()
        }),
        call!("aead::Key::open ChaCha20-Poly1305", 1, || open_untimed(
            &aead::CHACHA20_POLY1305
        )),
        call!("quic::HeaderProtectionKey::mask AES-128", 1, || {
            quic_key_untimed(&aead::quic::AES_128).mask(&[8; 16])
        }),
        call!("quic::HeaderProtectionKey::mask ChaCha20", 1, || {
            quic_key_untimed(&aead::quic::CHACHA20).mask(&[8; 16])
        }),
        call!("constant_time::verify", 1, || {
            constant_time::verify(&[9; 32], &[9; 32]).unwrap();
        }),
        call!("agreement X25519 agree", 1, || {
            x25519_untimed().agree(&X25519_PEER).unwrap()
        }),
        call!("ed25519 sign", 1, || ed25519_untimed().sign(b"message")),
    ]
}

// The values a timed call works on, made by the `untimed` helpers, whose
// toggles `run_counted` leaves out of the call's count.

const X25519_PEER: [u8; 32] = [9; 32];

/// Runs `make` as setup, outside the toggle count of the call it serves:
/// its toggles are subtracted by [`run_counted`].
fn untimed<T>(make: impl FnOnce() -> T) -> T {
    let before = model::toggles();
    let value = make();
    UNTIMED.set(UNTIMED.get() + (model::toggles() - before));
    value
}

thread_local! {
    static UNTIMED: core::cell::Cell<u64> = const { core::cell::Cell::new(0) };
}

fn prk() -> hkdf::Prk {
    hkdf::Prk::new(&hkdf::HKDF_SHA256, &[6; 32])
}

fn prk_untimed() -> hkdf::Prk {
    untimed(prk)
}

fn salt_untimed() -> hkdf::Salt {
    untimed(|| hkdf::Salt::new(&hkdf::HKDF_SHA256, b"salt"))
}

fn hmac_key_untimed() -> hmac::Key {
    untimed(hmac_key)
}

fn aead_key_untimed(algorithm: &'static aead::Algorithm) -> aead::Key {
    untimed(|| aead_key(algorithm))
}

fn quic_key_untimed(algorithm: &'static aead::quic::Algorithm) -> aead::quic::HeaderProtectionKey {
    untimed(|| quic_key(algorithm))
}

fn x25519_untimed() -> agreement::PrivateKey {
    untimed(|| agreement::PrivateKey::from_scalar(&agreement::X25519, &[10; 32]).unwrap())
}

fn ed25519_untimed() -> ed25519::KeyPair {
    untimed(|| ed25519::KeyPair::from_seed(&[11; 32]).unwrap())
}

fn open_untimed(algorithm: &'static aead::Algorithm) {
    let (key, mut packet, tag) = untimed(|| sealed(algorithm));
    key.open_in_place_separate_tag(nonce(), b"header", tag, &mut packet)
        .unwrap();
}

/// The toggles `call` made, less those its setup made.
fn run_counted(call: &Call) -> u64 {
    UNTIMED.set(0);
    let made = toggles(call.run);
    made - UNTIMED.get()
}

#[cfg(all(debug_assertions, rind_dit))]
fn dit_on() -> Option<bool> {
    crate::low::dit_on()
}

/// Every call costs the toggles listed, so a change that splits one
/// operation into more DIT toggles, or merges them, shows here first.
#[test]
fn each_call_costs_its_toggles() {
    let mut wrong = Vec::new();
    for call in calls() {
        assert!(!model::live(), "{} began inside a guard", call.name);
        let made = run_counted(&call);
        if made != call.toggles {
            wrong.push(std::format!(
                "{}: {made} toggles, listed {}",
                call.name,
                call.toggles
            ));
        }
        assert!(!model::live(), "{} left a guard live", call.name);
    }
    assert!(wrong.is_empty(), "{wrong:#?}");
}

/// Under a held guard no call toggles again.
#[test]
fn a_held_guard_absorbs_every_toggle() {
    let dit = crate::cpu::Dit::hold();
    for call in calls() {
        assert_eq!(toggles(call.run), 0, "{} toggled under a guard", call.name);
    }
    drop(dit);
}

/// A QUIC sender's per-packet work, header protection and a seal, under
/// one guard: one toggle for the whole batch.
#[test]
fn quic_packets_under_one_guard_toggle_once() {
    let header = quic_key(&aead::quic::AES_128);
    let packet_key = aead_key(&aead::AES_128_GCM);
    let made = toggles(|| {
        let _dit = crate::cpu::Dit::hold();
        for number in 0..16u64 {
            let mut packet = [0u8; 1350];
            let nonce = aead::Nonce::from_sequence(&[3; 12], number);
            let tag = packet_key
                .seal_in_place_separate_tag(nonce, b"header", &mut packet[20..])
                .unwrap();
            let sample: &[u8; 16] = tag.as_ref().try_into().unwrap();
            let _mask = header.mask(sample);
        }
    });
    assert_eq!(made, 1);
}

/// Where rind sets DIT and the CPU has it, each call ran PSTATE.DIT checks
/// that passed, and left DIT clear. `RIND_TEST_DIT=1` fails the run if the
/// CPU lacks DIT, so a qemu or Apple run cannot pass by checking nothing.
#[cfg(all(debug_assertions, rind_dit))]
#[test]
fn every_secret_call_runs_with_dit() {
    if std::env::var_os("RIND_TEST_DIT").is_some_and(|v| v == "1") {
        assert!(
            dit_on().is_some(),
            "RIND_TEST_DIT=1 but rind sets no DIT here"
        );
    }
    if dit_on().is_none() {
        return;
    }
    for call in calls() {
        assert_eq!(dit_on(), Some(false), "{} began with DIT set", call.name);
        let before = super::dit_checks();
        (call.run)();
        let checks = super::dit_checks() - before;
        assert!(checks > 0, "{} ran no PSTATE.DIT check", call.name);
        assert_eq!(dit_on(), Some(false), "{} left DIT set", call.name);
    }
}

/// The check fires: a primitive under a secret `Entry` whose DIT something
/// cleared panics.
#[cfg(all(debug_assertions, rind_dit))]
#[test]
fn a_cleared_dit_under_an_entry_panics() {
    if dit_on().is_none() {
        return;
    }
    let entry = super::Entry::new_secret();
    // Clears DIT under the live `Entry`, as a bug that left it would.
    crate::low::leave_cpu_state(1);
    let caught = std::panic::catch_unwind(|| super::Entry::assert_held());
    // Sets it again, so the `Entry` drops cleanly and clears it.
    let _ = crate::low::enter_cpu_state();
    drop(entry);
    assert_eq!(dit_on(), Some(false));
    let message = caught.expect_err("a cleared DIT passed the check");
    let message = message
        .downcast_ref::<&str>()
        .copied()
        .or_else(|| message.downcast_ref::<String>().map(|s| s.as_str()))
        .unwrap_or_default();
    assert!(message.contains("PSTATE.DIT clear"), "{message}");
}
