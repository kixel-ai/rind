// Probe only: short AES-GCM seals and opens, rind against aws-lc-rs.
mod criterion;
use std::hint::black_box;
use std::time::Duration;

use criterion::{BenchmarkId, Criterion, criterion_group, criterion_main};

const CASES: [(usize, usize); 15] = [(13, 3), (13, 32), (13, 64), (13, 96), (13, 128), (13, 160), (13, 192), (13, 208), (13, 224), (13, 240), (13, 256), (13, 320), (0, 240), (13, 1200), (13, 1452)];

fn bench(c: &mut Criterion) {
    let algs: [(&str, &[u8], &'static rind::aead::Algorithm, &'static aws_lc_rs::aead::Algorithm); 2] = [
        ("aes128", &[7u8; 16], &rind::aead::AES_128_GCM, &aws_lc_rs::aead::AES_128_GCM),
        ("aes256", &[7u8; 32], &rind::aead::AES_256_GCM, &aws_lc_rs::aead::AES_256_GCM),
    ];
    for (name, key, ours, aws) in algs {
        let rind_key = rind::aead::Key::new(ours, key).unwrap();
        let aws_key = aws_lc_rs::aead::LessSafeKey::new(aws_lc_rs::aead::UnboundKey::new(aws, key).unwrap());
        let nonce = [3u8; 12];
        let mut group = c.benchmark_group(name);
        for (aad_len, len) in CASES {
            let aad = vec![5u8; aad_len];
            let id = format!("a{aad_len}-m{len}");
            let mut buf = vec![9u8; len];
            group.bench_function(BenchmarkId::new("seal-rind", &id), |b| {
                b.iter(|| {
                    rind_key
                        .seal_in_place_separate_tag(rind::aead::Nonce::assume_unique_for_key(nonce), black_box(&aad), &mut buf)
                        .unwrap()
                })
            });
            group.bench_function(BenchmarkId::new("seal-aws", &id), |b| {
                b.iter(|| {
                    aws_key
                        .seal_in_place_separate_tag(aws_lc_rs::aead::Nonce::assume_unique_for_key(nonce), aws_lc_rs::aead::Aad::from(black_box(&aad[..])), &mut buf)
                        .unwrap()
                })
            });
            let mut ct = vec![9u8; len];
            let tag = rind_key
                .seal_in_place_separate_tag(rind::aead::Nonce::assume_unique_for_key(nonce), &aad, &mut ct)
                .unwrap();
            let mut pt = vec![0u8; len];
            group.bench_function(BenchmarkId::new("open-rind", &id), |b| {
                b.iter(|| {
                    pt.copy_from_slice(&ct);
                    rind_key
                        .open_in_place_separate_tag(rind::aead::Nonce::assume_unique_for_key(nonce), black_box(&aad), tag, &mut pt)
                        .unwrap();
                })
            });
            group.bench_function(BenchmarkId::new("open-aws", &id), |b| {
                b.iter(|| {
                    pt.copy_from_slice(&ct);
                    aws_key
                        .open_in_place_separate_tag(aws_lc_rs::aead::Nonce::assume_unique_for_key(nonce), aws_lc_rs::aead::Aad::from(black_box(&aad[..])), tag.as_ref(), &mut pt)
                        .unwrap();
                })
            });
        }
    }
}

criterion_group! {
    name = benches;
    config = Criterion::default().warm_up_time(Duration::from_millis(300)).measurement_time(Duration::from_millis(1200)).sample_size(40);
    targets = bench
}
criterion_main!(benches);
