//! RFC 9383's SPAKE2+-P256-SHA256-HKDF-SHA256-HMAC-SHA256: each side's work
//! in one exchange, from its share to the shared key. The other side's steps
//! run between them, untimed.
mod criterion;
use std::hint::black_box;
use std::time::{Duration, Instant};

use criterion::{Criterion, Throughput, criterion_group, criterion_main};
use getrandom::{SysRng, rand_core::UnwrapErr};
use rind::spake2plus::{ProverSecrets, RFC9383, VerifierRecord};
use spake2plus::{Context, P256Sha256, Prover, ProverSecret, Verifier};

const CONTEXT: &[u8] = b"rind-bench";
const PROVER: &[u8] = b"client";
const VERIFIER: &[u8] = b"server";

// w0s and w1s, the password hash's output, which each library reduces into
// the same w0 and w1.
const W0S: [u8; 40] = [0x11; 40];
const W1S: [u8; 40] = [0x22; 40];

fn context() -> Context<'static> {
    Context {
        context: CONTEXT,
        prover_id: PROVER,
        verifier_id: VERIFIER,
    }
}

fn rustcrypto_secret() -> ProverSecret<P256Sha256> {
    ProverSecret::from_pbkdf_output(&[W0S, W1S].concat()).unwrap()
}

// A rind prover and the other library's verifier agree on a key, so the rows
// time the same protocol.
fn check_interop() {
    let prover = ProverSecrets::new(&W0S, &W1S).unwrap();
    let record = rustcrypto_secret().verifier_record();
    let (share_p, prover) = prover.start(&RFC9383, CONTEXT, PROVER, VERIFIER).unwrap();
    let (verifier, share_v) = Verifier::start(&record, &context(), &mut UnwrapErr(SysRng));
    let (verifier, confirm_v) = verifier
        .receive(&spake2plus::ShareP::from_bytes(share_p.as_ref()).unwrap())
        .unwrap();
    let share_v = rind::spake2plus::Share::from_bytes(share_v.as_bytes().as_ref()).unwrap();
    let confirm_v = rind::spake2plus::Confirm::from_bytes(confirm_v.as_bytes().as_ref()).unwrap();
    let (confirm_p, prover_key) = prover.finish(&share_v, &confirm_v).unwrap();
    let verifier_key = verifier
        .finish(&spake2plus::ConfirmP::from_bytes(confirm_p.as_ref()).unwrap())
        .unwrap();
    assert_eq!(prover_key.as_ref(), verifier_key.as_bytes().as_ref());
}

fn prover(c: &mut Criterion) {
    check_interop();
    let mut group = c.benchmark_group("spake2plus-p256-prover");
    group.throughput(Throughput::Elements(1));

    group.bench_function("rind", |b| {
        let secrets = ProverSecrets::new(&W0S, &W1S).unwrap();
        let record = VerifierRecord::from_w1(&W0S, &W1S).unwrap();
        b.iter_custom(|iters| {
            let mut timed = Duration::ZERO;
            for _ in 0..iters {
                let start = Instant::now();
                let (share_p, prover) = secrets.start(&RFC9383, CONTEXT, PROVER, VERIFIER).unwrap();
                timed += start.elapsed();
                let (share_v, confirm_v, _) = record
                    .start(&RFC9383, CONTEXT, PROVER, VERIFIER, &share_p)
                    .unwrap();
                let start = Instant::now();
                black_box(prover.finish(&share_v, &confirm_v).unwrap());
                timed += start.elapsed();
            }
            timed
        });
    });

    group.bench_function("rustcrypto", |b| {
        let secret = rustcrypto_secret();
        let record = secret.verifier_record();
        let context = context();
        let mut rng = UnwrapErr(SysRng);
        b.iter_custom(|iters| {
            let mut timed = Duration::ZERO;
            for _ in 0..iters {
                let start = Instant::now();
                let (prover, share_p) = Prover::start(&secret, &context, &mut rng);
                timed += start.elapsed();
                let (verifier, share_v) = Verifier::start(&record, &context, &mut rng);
                let (_, confirm_v) = verifier.receive(&share_p).unwrap();
                let start = Instant::now();
                black_box(
                    prover
                        .receive(&share_v)
                        .unwrap()
                        .finish(&confirm_v)
                        .unwrap(),
                );
                timed += start.elapsed();
            }
            timed
        });
    });
}

fn verifier(c: &mut Criterion) {
    let mut group = c.benchmark_group("spake2plus-p256-verifier");
    group.throughput(Throughput::Elements(1));

    group.bench_function("rind", |b| {
        let secrets = ProverSecrets::new(&W0S, &W1S).unwrap();
        let record = VerifierRecord::from_w1(&W0S, &W1S).unwrap();
        b.iter_custom(|iters| {
            let mut timed = Duration::ZERO;
            for _ in 0..iters {
                let (share_p, prover) = secrets.start(&RFC9383, CONTEXT, PROVER, VERIFIER).unwrap();
                let start = Instant::now();
                let (share_v, confirm_v, verifier) = record
                    .start(&RFC9383, CONTEXT, PROVER, VERIFIER, &share_p)
                    .unwrap();
                timed += start.elapsed();
                let (confirm_p, _) = prover.finish(&share_v, &confirm_v).unwrap();
                let start = Instant::now();
                black_box(verifier.finish(&confirm_p).unwrap());
                timed += start.elapsed();
            }
            timed
        });
    });

    group.bench_function("rustcrypto", |b| {
        let secret = rustcrypto_secret();
        let record = secret.verifier_record();
        let context = context();
        let mut rng = UnwrapErr(SysRng);
        b.iter_custom(|iters| {
            let mut timed = Duration::ZERO;
            for _ in 0..iters {
                let (prover, share_p) = Prover::start(&secret, &context, &mut rng);
                let start = Instant::now();
                let (verifier, share_v) = Verifier::start(&record, &context, &mut rng);
                let (verifier, confirm_v) = verifier.receive(&share_p).unwrap();
                timed += start.elapsed();
                let (confirm_p, _) = prover
                    .receive(&share_v)
                    .unwrap()
                    .finish(&confirm_v)
                    .unwrap();
                let start = Instant::now();
                black_box(verifier.finish(&confirm_p).unwrap());
                timed += start.elapsed();
            }
            timed
        });
    });
}

criterion_group!(benches, prover, verifier);
criterion_main!(benches);
