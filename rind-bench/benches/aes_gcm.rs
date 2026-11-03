mod criterion;
use std::hint::black_box;

use criterion::{BenchmarkId, Criterion, Throughput, criterion_group, criterion_main};

fn test_ring_aes_gcm(key: &ring::aead::LessSafeKey, nonce: &[u8; 12], aad: &[u8], buf: &mut [u8]) {
    let _tag = key
        .seal_in_place_separate_tag(
            ring::aead::Nonce::assume_unique_for_key(*nonce),
            ring::aead::Aad::from(aad),
            buf,
        )
        .unwrap();
}

fn test_aws_aes_gcm(
    key: &aws_lc_rs::aead::LessSafeKey,
    nonce: &[u8; 12],
    aad: &[u8],
    buf: &mut [u8],
) {
    let _tag = key
        .seal_in_place_separate_tag(nonce.into(), aws_lc_rs::aead::Aad::from(aad), buf)
        .unwrap();
}

fn test_rc_aes128_gcm(key: &aes_gcm::Aes128Gcm, nonce: &[u8; 12], aad: &[u8], buf: &mut [u8]) {
    use aes_gcm::AeadInOut;
    let _tag = key
        .encrypt_inout_detached(nonce.into(), aad, buf.into())
        .unwrap();
}

fn test_rc_aes256_gcm(key: &aes_gcm::Aes256Gcm, nonce: &[u8; 12], aad: &[u8], buf: &mut [u8]) {
    use aes_gcm::AeadInOut;
    let _tag = key
        .encrypt_inout_detached(nonce.into(), aad, buf.into())
        .unwrap();
}

fn test_rind_aes_gcm(key: &rind::aead::Key, nonce: &[u8; 12], aad: &[u8], buf: &mut [u8]) {
    let _tag = key
        .seal_in_place_separate_tag(rind::aead::Nonce::assume_unique_for_key(*nonce), aad, buf)
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
        // Sealing the same buffer in place each iteration times the cipher
        // alone, without an allocation or a copy of the input.
        let mut buf = vec![0u8; size];
        group.throughput(Throughput::Bytes(size as u64));

        group.bench_function(BenchmarkId::new("ring", size_name), |b| {
            use ring::aead::{AES_128_GCM, LessSafeKey, UnboundKey};
            let key = UnboundKey::new(&AES_128_GCM, &key).unwrap();
            let key = LessSafeKey::new(key);
            b.iter(|| test_ring_aes_gcm(&key, &nonce, &aad, &mut buf));
        });
        group.bench_function(BenchmarkId::new("aws-lc-rs", size_name), |b| {
            use aws_lc_rs::aead::{AES_128_GCM, LessSafeKey, UnboundKey};
            let key = UnboundKey::new(&AES_128_GCM, &key).unwrap();
            let key = LessSafeKey::new(key);
            b.iter(|| test_aws_aes_gcm(&key, &nonce, &aad, &mut buf));
        });
        group.bench_function(BenchmarkId::new("rustcrypto", size_name), |b| {
            use aes_gcm::KeyInit;
            let key = aes_gcm::Aes128Gcm::new_from_slice(&key).unwrap();
            b.iter(|| test_rc_aes128_gcm(&key, &nonce, &aad, &mut buf));
        });
        group.bench_function(BenchmarkId::new("rind", size_name), |b| {
            use rind::aead::{AES_128_GCM, Key};
            let key = Key::new(&AES_128_GCM, &key).unwrap();
            b.iter(|| test_rind_aes_gcm(&key, &nonce, &aad, &mut buf));
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
        // Sealing the same buffer in place each iteration times the cipher
        // alone, without an allocation or a copy of the input.
        let mut buf = vec![0u8; size];
        group.throughput(Throughput::Bytes(size as u64));

        group.bench_function(BenchmarkId::new("ring", size_name), |b| {
            use ring::aead::{AES_256_GCM, LessSafeKey, UnboundKey};
            let key = UnboundKey::new(&AES_256_GCM, &key).unwrap();
            let key = LessSafeKey::new(key);
            b.iter(|| test_ring_aes_gcm(&key, &nonce, &aad, &mut buf));
        });
        group.bench_function(BenchmarkId::new("aws-lc-rs", size_name), |b| {
            use aws_lc_rs::aead::{AES_256_GCM, LessSafeKey, UnboundKey};
            let key = UnboundKey::new(&AES_256_GCM, &key).unwrap();
            let key = LessSafeKey::new(key);
            b.iter(|| test_aws_aes_gcm(&key, &nonce, &aad, &mut buf));
        });
        group.bench_function(BenchmarkId::new("rustcrypto", size_name), |b| {
            use aes_gcm::KeyInit;
            let key = aes_gcm::Aes256Gcm::new_from_slice(&key).unwrap();
            b.iter(|| test_rc_aes256_gcm(&key, &nonce, &aad, &mut buf));
        });
        group.bench_function(BenchmarkId::new("rind", size_name), |b| {
            use rind::aead::{AES_256_GCM, Key};
            let key = Key::new(&AES_256_GCM, &key).unwrap();
            b.iter(|| test_rind_aes_gcm(&key, &nonce, &aad, &mut buf));
        });
    }
}

// Decrypting and verifying each size's ciphertext, as a receiver pays.
fn open(
    c: &mut Criterion,
    name: &str,
    key: &[u8],
    ring: &'static ring::aead::Algorithm,
    aws: &'static aws_lc_rs::aead::Algorithm,
    ours: &'static rind::aead::Algorithm,
) {
    let nonce = [0u8; 12];
    let aad = [0u8; 32];
    let ring_key = ring::aead::LessSafeKey::new(ring::aead::UnboundKey::new(ring, key).unwrap());
    let aws_key =
        aws_lc_rs::aead::LessSafeKey::new(aws_lc_rs::aead::UnboundKey::new(aws, key).unwrap());
    let rind_key = rind::aead::Key::new(ours, key).unwrap();

    let mut group = c.benchmark_group(name);
    for (size, size_name) in criterion::SIZES {
        // Opening consumes its ciphertext, so each iteration first copies it
        // into a buffer a whole number of 4 KiB pages after it. Two separate
        // heap buffers can instead land with the destination just past the
        // source in a page, where Zen 3 and 4 run the `rep movsb` that
        // glibc's memcpy can pick for 16 KB about 30x slower.
        let stride = size.next_multiple_of(4096);
        let mut buf = vec![0u8; stride + size];
        let (ct, pt) = buf.split_at_mut(stride);
        let ct = &mut ct[..size];
        let tag = rind_key
            .seal_in_place_separate_tag(rind::aead::Nonce::assume_unique_for_key(nonce), &aad, ct)
            .unwrap();
        group.throughput(Throughput::Bytes(size as u64));

        group.bench_function(BenchmarkId::new("ring", size_name), |b| {
            let tag = ring::aead::Tag::try_from(tag.as_ref()).unwrap();
            b.iter(|| {
                pt.copy_from_slice(ct);
                ring_key
                    .open_in_place_separate_tag(
                        ring::aead::Nonce::assume_unique_for_key(nonce),
                        ring::aead::Aad::from(aad),
                        tag,
                        pt,
                        0..,
                    )
                    .unwrap();
            });
        });
        group.bench_function(BenchmarkId::new("aws-lc-rs", size_name), |b| {
            b.iter(|| {
                pt.copy_from_slice(ct);
                aws_key
                    .open_in_place_separate_tag(
                        aws_lc_rs::aead::Nonce::assume_unique_for_key(nonce),
                        aws_lc_rs::aead::Aad::from(aad),
                        tag.as_ref(),
                        pt,
                    )
                    .unwrap();
            });
        });
        group.bench_function(BenchmarkId::new("rind", size_name), |b| {
            b.iter(|| {
                pt.copy_from_slice(ct);
                rind_key
                    .open_in_place_separate_tag(
                        rind::aead::Nonce::assume_unique_for_key(nonce),
                        &aad,
                        tag,
                        pt,
                    )
                    .unwrap();
            });
        });
    }
}

fn aes128_gcm_open(c: &mut Criterion) {
    open(
        c,
        "aes128-gcm-open",
        &[0u8; 16],
        &ring::aead::AES_128_GCM,
        &aws_lc_rs::aead::AES_128_GCM,
        &rind::aead::AES_128_GCM,
    );
}

fn aes256_gcm_open(c: &mut Criterion) {
    open(
        c,
        "aes256-gcm-open",
        &[0u8; 32],
        &ring::aead::AES_256_GCM,
        &aws_lc_rs::aead::AES_256_GCM,
        &rind::aead::AES_256_GCM,
    );
}

criterion_group!(
    benches,
    aes128_gcm,
    aes256_gcm,
    aes128_gcm_open,
    aes256_gcm_open
);
criterion_main!(benches);
