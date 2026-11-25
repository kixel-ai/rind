mod criterion;
use std::hint::black_box;

use criterion::{Criterion, criterion_group, criterion_main};

fn ab(c: &mut Criterion) {
    use rind::rsa::{KeyPair, PublicKey, sign, verify};
    let keys: [(u32, &[u8]); 5] = [
        (2048, include_bytes!("../../rind/src/high/rsa/rsa2048.der")),
        (
            3072,
            include_bytes!("../../rind/src/high/rsa/rsa3072.pkcs8.der"),
        ),
        (
            4096,
            include_bytes!("../../rind/src/high/rsa/rsa4096.pkcs8.der"),
        ),
        (
            6144,
            include_bytes!("../../rind/src/high/rsa/rsa6144.pkcs8.der"),
        ),
        (
            8192,
            include_bytes!("../../rind/src/high/rsa/rsa8192.pkcs8.der"),
        ),
    ];
    let message = b"hello";
    // Rounds, so slow drift in the runner hits every variant.
    for round in 0..3 {
        for (bits, der) in keys {
            let key = KeyPair::from_pkcs8(der)
                .or_else(|_| KeyPair::from_pkcs1(der))
                .unwrap();
            let public_key = key.public_key();
            let peer = PublicKey::new(public_key.as_ref()).unwrap();
            let signature = key.sign(&sign::PKCS1_SHA256, message).unwrap();
            for (name, v) in [("old", 0u8), ("b2", 1), ("b4", 2), ("b8", 3)] {
                let mut group = c.benchmark_group(format!("exp-r{round}-rsa{bits}-{name}-sign"));
                group.bench_function("rind", |b| {
                    rind::exp_variant(v);
                    b.iter(|| black_box(key.sign(&sign::PKCS1_SHA256, message)).unwrap())
                });
                group.finish();
                let mut group = c.benchmark_group(format!("exp-r{round}-rsa{bits}-{name}-verify"));
                group.bench_function("rind", |b| {
                    rind::exp_variant(v);
                    b.iter(|| {
                        black_box(peer.verify(&verify::PKCS1_SHA256, message, signature.as_ref()))
                            .unwrap()
                    })
                });
                group.finish();
            }
        }
    }
}

criterion_group!(benches, ab);
criterion_main!(benches);
