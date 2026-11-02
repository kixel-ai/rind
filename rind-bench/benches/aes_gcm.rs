mod criterion;
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

fn aes128_gcm(c: &mut Criterion) {
    let key = [0u8; 16];
    let nonce = [0u8; 12];
    let aad = [0u8; 32];

    let mut group = c.benchmark_group("aes128-gcm");
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
        let mut ct = vec![0u8; size];
        let tag = rind_key
            .seal_in_place_separate_tag(
                rind::aead::Nonce::assume_unique_for_key(nonce),
                &aad,
                &mut ct,
            )
            .unwrap();
        group.throughput(Throughput::Bytes(size as u64));

        group.bench_with_input(BenchmarkId::new("ring", size_name), &ct, |b, ct| {
            let tag = ring::aead::Tag::try_from(tag.as_ref()).unwrap();
            b.iter(|| {
                let mut pt = ct.to_vec();
                ring_key
                    .open_in_place_separate_tag(
                        ring::aead::Nonce::assume_unique_for_key(nonce),
                        ring::aead::Aad::from(aad),
                        tag,
                        &mut pt,
                        0..,
                    )
                    .unwrap();
            });
        });
        group.bench_with_input(BenchmarkId::new("aws-lc-rs", size_name), &ct, |b, ct| {
            b.iter(|| {
                let mut pt = ct.to_vec();
                aws_key
                    .open_in_place_separate_tag(
                        aws_lc_rs::aead::Nonce::assume_unique_for_key(nonce),
                        aws_lc_rs::aead::Aad::from(aad),
                        tag.as_ref(),
                        &mut pt,
                    )
                    .unwrap();
            });
        });
        group.bench_with_input(BenchmarkId::new("rind", size_name), &ct, |b, ct| {
            b.iter(|| {
                let mut pt = ct.to_vec();
                rind_key
                    .open_in_place_separate_tag(
                        rind::aead::Nonce::assume_unique_for_key(nonce),
                        &aad,
                        tag,
                        &mut pt,
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
