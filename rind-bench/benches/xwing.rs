mod criterion;
use std::hint::black_box;

use criterion::{Criterion, Throughput, criterion_group, criterion_main};

// X-Wing (draft-connolly-cfrg-xwing-kem), the X25519 and ML-KEM-768 hybrid.
// aws-lc-rs has no X-Wing. libcrux-kem follows draft 06, whose combiner is the
// final draft's, and RustCrypto's `x-wing` the final draft; the tests in
// `rind::kem` check all three against each other byte for byte.
//
// Each row does what a protocol does with one key: keygen draws a seed and
// yields the encapsulation key's bytes; encaps parses a received key and
// encapsulates; decaps parses a received ciphertext and decapsulates with a
// key loaded once, as each library keeps it.

fn libcrux_rng() -> getrandom::SysRng {
    getrandom::SysRng
}

fn libcrux_keypair() -> (libcrux_kem::PrivateKey, libcrux_kem::PublicKey) {
    libcrux_kem::key_gen(libcrux_kem::Algorithm::XWingKemDraft06, &mut libcrux_rng()).unwrap()
}

fn agree() {
    use rind::kem::*;
    use x_wing::{Decapsulate, Decapsulator, Generate, KeyExport};

    // Each library decapsulates what the others encapsulate to its key.
    let ours = DecapsulationKey::<XWing>::generate().unwrap();
    let rustcrypto =
        x_wing::DecapsulationKey::from(<[u8; 32]>::try_from(ours.to_seed().as_ref()).unwrap());
    assert_eq!(
        rustcrypto.encapsulation_key().to_bytes().as_slice(),
        ours.public_key().as_ref()
    );
    let (ciphertext, secret) = ours.public_key().encapsulate().unwrap();
    let ciphertext = Ciphertext::<XWing>::new(ciphertext.as_ref()).unwrap();
    assert_eq!(ours.decapsulate(&ciphertext).as_ref(), secret.as_ref());
    assert_eq!(
        rustcrypto
            .decapsulate(&ciphertext.as_ref().try_into().unwrap())
            .as_slice(),
        secret.as_ref()
    );
    let (libcrux_sk, libcrux_pk) = libcrux_keypair();
    let theirs = EncapsulationKey::<XWing>::new(&libcrux_pk.encode()).unwrap();
    let (ciphertext, secret) = theirs.encapsulate().unwrap();
    let ciphertext =
        libcrux_kem::Ct::decode(libcrux_kem::Algorithm::XWingKemDraft06, ciphertext.as_ref())
            .unwrap();
    assert_eq!(
        ciphertext.decapsulate(&libcrux_sk).unwrap().encode(),
        secret.as_ref()
    );
    let _ = x_wing::DecapsulationKey::generate();
}

fn xwing_keygen(c: &mut Criterion) {
    agree();
    let mut group = c.benchmark_group("xwing-keygen");
    group.throughput(Throughput::Elements(1));

    group.bench_function("libcrux-kem", |b| {
        b.iter(|| {
            let (sk, pk) = libcrux_keypair();
            black_box((sk.encode(), pk.encode()))
        })
    });

    group.bench_function("rustcrypto", |b| {
        use x_wing::{Decapsulator, Generate, KeyExport};

        b.iter(|| {
            let key = x_wing::DecapsulationKey::generate();
            black_box(key.encapsulation_key().to_bytes())
        })
    });

    group.bench_function("rind", |b| {
        use rind::kem::*;

        b.iter(|| {
            let key = DecapsulationKey::<XWing>::generate().unwrap();
            black_box(key.public_key().as_ref().len())
        })
    });
}

fn xwing_encaps(c: &mut Criterion) {
    let mut group = c.benchmark_group("xwing-encaps");
    group.throughput(Throughput::Elements(1));

    group.bench_function("libcrux-kem", |b| {
        let (_, pk) = libcrux_keypair();
        let bytes = pk.encode();

        b.iter(|| {
            let pk =
                libcrux_kem::PublicKey::decode(libcrux_kem::Algorithm::XWingKemDraft06, &bytes)
                    .unwrap();
            black_box(pk.encapsulate(&mut libcrux_rng()).unwrap())
        })
    });

    group.bench_function("rustcrypto", |b| {
        use x_wing::{Decapsulator, Encapsulate, Generate, KeyExport};

        let key = x_wing::DecapsulationKey::generate();
        let bytes = key.encapsulation_key().to_bytes();

        b.iter(|| {
            let pk = x_wing::EncapsulationKey::try_from(bytes.as_slice()).unwrap();
            black_box(pk.encapsulate())
        })
    });

    group.bench_function("rind", |b| {
        use rind::kem::*;

        let pk = DecapsulationKey::<XWing>::generate()
            .unwrap()
            .public_key()
            .clone();

        b.iter(|| {
            let pk = EncapsulationKey::<XWing>::new(pk.as_ref()).unwrap();
            black_box(pk.encapsulate().unwrap())
        })
    });
}

fn xwing_decaps(c: &mut Criterion) {
    let mut group = c.benchmark_group("xwing-decaps");
    group.throughput(Throughput::Elements(1));

    group.bench_function("libcrux-kem", |b| {
        let (sk, pk) = libcrux_keypair();
        let (_, ct) = pk.encapsulate(&mut libcrux_rng()).unwrap();
        let bytes = ct.encode();

        b.iter(|| {
            let ct =
                libcrux_kem::Ct::decode(libcrux_kem::Algorithm::XWingKemDraft06, &bytes).unwrap();
            black_box(ct.decapsulate(&sk).unwrap())
        })
    });

    group.bench_function("rustcrypto", |b| {
        use x_wing::{Decapsulate, Decapsulator, Encapsulate, Generate};

        let key = x_wing::DecapsulationKey::generate();
        let (ct, _) = key.encapsulation_key().encapsulate();
        let bytes = ct.as_slice().to_vec();

        b.iter(|| {
            let ct = x_wing::Ciphertext::try_from(bytes.as_slice()).unwrap();
            black_box(key.decapsulate(&ct))
        })
    });

    group.bench_function("rind", |b| {
        use rind::kem::*;

        let key = DecapsulationKey::<XWing>::generate().unwrap();
        let (ct, _) = key.public_key().encapsulate().unwrap();
        let bytes = ct.as_ref().to_vec();

        b.iter(|| {
            let ct = Ciphertext::<XWing>::new(&bytes).unwrap();
            black_box(key.decapsulate(&ct))
        })
    });
}

criterion_group!(benches, xwing_keygen, xwing_encaps, xwing_decaps);
criterion_main!(benches);
