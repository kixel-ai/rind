mod criterion;
use std::hint::black_box;

use criterion::{BenchmarkId, Criterion, Throughput, criterion_group, criterion_main};

fn test_ring_aes_gcm(key: &ring::aead::LessSafeKey, nonce: &[u8; 12], aad: &[u8], plain: &[u8]) {
    let mut ct = plain.to_vec();
    let _tag = key
        .seal_in_place_separate_tag(
            ring::aead::Nonce::assume_unique_for_key(*nonce),
            ring::aead::Aad::from(aad),
            &mut ct,
        )
        .unwrap();
}

fn test_aws_aes_gcm(
    key: &aws_lc_rs::aead::LessSafeKey,
    nonce: &[u8; 12],
    aad: &[u8],
    plain: &[u8],
) {
    let mut ct = plain.to_vec();
    let _tag = key
        .seal_in_place_separate_tag(nonce.into(), aws_lc_rs::aead::Aad::from(aad), &mut ct)
        .unwrap();
}

fn test_rc_aes128_gcm(key: &aes_gcm::Aes128Gcm, nonce: &[u8; 12], aad: &[u8], plain: &[u8]) {
    use aes_gcm::AeadInOut;
    let mut ct = plain.to_vec();
    let _tag = key
        .encrypt_inout_detached(nonce.into(), aad, ct.as_mut_slice().into())
        .unwrap();
}

fn test_rc_aes256_gcm(key: &aes_gcm::Aes256Gcm, nonce: &[u8; 12], aad: &[u8], plain: &[u8]) {
    use aes_gcm::AeadInOut;
    let mut ct = plain.to_vec();
    let _tag = key
        .encrypt_inout_detached(nonce.into(), aad, ct.as_mut_slice().into())
        .unwrap();
}

fn test_rind_aes_gcm(key: &rind::aead::Key, nonce: &[u8; 12], aad: &[u8], plain: &[u8]) {
    let mut ct = plain.to_vec();
    let _tag = key
        .seal_in_place_separate_tag(
            rind::aead::Nonce::assume_unique_for_key(*nonce),
            aad,
            &mut ct,
        )
        .unwrap();
}

// Expanding a key and its GHASH table, as each QUIC connection and derived
// track key pays. It drops each key in the loop, so their wiping is timed too.
fn key_setup(
    group: &mut criterion::BenchmarkGroup<'_, criterion::measurement::WallTime>,
    key: &[u8],
    ring: &'static ring::aead::Algorithm,
    aws: &'static aws_lc_rs::aead::Algorithm,
    ours: &'static rind::aead::Algorithm,
) {
    group.bench_function(BenchmarkId::new("ring", "key"), |b| {
        b.iter(|| ring::aead::UnboundKey::new(ring, black_box(key)).unwrap())
    });
    group.bench_function(BenchmarkId::new("aws-lc-rs", "key"), |b| {
        b.iter(|| aws_lc_rs::aead::UnboundKey::new(aws, black_box(key)).unwrap())
    });
    group.bench_function(BenchmarkId::new("rind", "key"), |b| {
        b.iter(|| rind::aead::Key::new(ours, black_box(key)).unwrap())
    });
}

fn aes128_gcm(c: &mut Criterion) {
    let key = [0u8; 16];
    let nonce = [0u8; 12];
    let aad = [0u8; 32];

    let mut group = c.benchmark_group("aes128-gcm");
    key_setup(
        &mut group,
        &key,
        &ring::aead::AES_128_GCM,
        &aws_lc_rs::aead::AES_128_GCM,
        &rind::aead::AES_128_GCM,
    );

    for (size, size_name) in criterion::SIZES {
        let input = vec![0u8; size];
        group.throughput(Throughput::Bytes(size as u64));

        group.bench_with_input(BenchmarkId::new("ring", size_name), &input, |b, input| {
            use ring::aead::{AES_128_GCM, LessSafeKey, UnboundKey};
            let key = UnboundKey::new(&AES_128_GCM, &key).unwrap();
            let key = LessSafeKey::new(key);
            b.iter(|| test_ring_aes_gcm(&key, &nonce, &aad, input));
        });
        group.bench_with_input(
            BenchmarkId::new("aws-lc-rs", size_name),
            &input,
            |b, input| {
                use aws_lc_rs::aead::{AES_128_GCM, LessSafeKey, UnboundKey};
                let key = UnboundKey::new(&AES_128_GCM, &key).unwrap();
                let key = LessSafeKey::new(key);
                b.iter(|| test_aws_aes_gcm(&key, &nonce, &aad, input));
            },
        );
        group.bench_with_input(
            BenchmarkId::new("rustcrypto", size_name),
            &input,
            |b, input| {
                use aes_gcm::KeyInit;
                let key = aes_gcm::Aes128Gcm::new_from_slice(&key).unwrap();
                b.iter(|| test_rc_aes128_gcm(&key, &nonce, &aad, input));
            },
        );
        group.bench_with_input(BenchmarkId::new("rind", size_name), &input, |b, input| {
            use rind::aead::{AES_128_GCM, Key};
            let key = Key::new(&AES_128_GCM, &key).unwrap();
            b.iter(|| test_rind_aes_gcm(&key, &nonce, &aad, input));
        });
    }
}

fn aes256_gcm(c: &mut Criterion) {
    let key = [0u8; 32];
    let nonce = [0u8; 12];
    let aad = [0u8; 32];

    let mut group = c.benchmark_group("aes256-gcm");
    key_setup(
        &mut group,
        &key,
        &ring::aead::AES_256_GCM,
        &aws_lc_rs::aead::AES_256_GCM,
        &rind::aead::AES_256_GCM,
    );

    for (size, size_name) in criterion::SIZES {
        let input = vec![0u8; size];
        group.throughput(Throughput::Bytes(size as u64));

        group.bench_with_input(BenchmarkId::new("ring", size_name), &input, |b, input| {
            use ring::aead::{AES_256_GCM, LessSafeKey, UnboundKey};
            let key = UnboundKey::new(&AES_256_GCM, &key).unwrap();
            let key = LessSafeKey::new(key);
            b.iter(|| test_ring_aes_gcm(&key, &nonce, &aad, input));
        });
        group.bench_with_input(
            BenchmarkId::new("aws-lc-rs", size_name),
            &input,
            |b, input| {
                use aws_lc_rs::aead::{AES_256_GCM, LessSafeKey, UnboundKey};
                let key = UnboundKey::new(&AES_256_GCM, &key).unwrap();
                let key = LessSafeKey::new(key);
                b.iter(|| test_aws_aes_gcm(&key, &nonce, &aad, input));
            },
        );
        group.bench_with_input(
            BenchmarkId::new("rustcrypto", size_name),
            &input,
            |b, input| {
                use aes_gcm::KeyInit;
                let key = aes_gcm::Aes256Gcm::new_from_slice(&key).unwrap();
                b.iter(|| test_rc_aes256_gcm(&key, &nonce, &aad, input));
            },
        );
        group.bench_with_input(BenchmarkId::new("rind", size_name), &input, |b, input| {
            use rind::aead::{AES_256_GCM, Key};
            let key = Key::new(&AES_256_GCM, &key).unwrap();
            b.iter(|| test_rind_aes_gcm(&key, &nonce, &aad, input));
        });
    }
}

criterion_group!(benches, aes128_gcm, aes256_gcm);
criterion_main!(benches);
