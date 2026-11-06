//! rind against Bun's BoringSSL, through the calls Bun's WebCrypto and
//! node:crypto make.
use std::ffi::c_void;
use std::hint::black_box;
use std::time::{Duration, Instant};

use rind::{agreement, digest};
use rind::signature::{self, EcdsaKeyPair, Ed25519KeyPair, PublicKey};

#[allow(non_camel_case_types)]
type EC_KEY = c_void;
#[allow(non_camel_case_types)]
type ECDSA_SIG = c_void;
#[allow(non_camel_case_types)]
type BIGNUM = c_void;

unsafe extern "C" {
    fn ED25519_keypair(out_public: *mut u8, out_private: *mut u8);
    fn ED25519_sign(out_sig: *mut u8, msg: *const u8, len: usize, private: *const u8) -> i32;
    fn ED25519_verify(msg: *const u8, len: usize, sig: *const u8, public: *const u8) -> i32;
    fn X25519_keypair(out_public: *mut u8, out_private: *mut u8);
    fn X25519(out: *mut u8, private: *const u8, peer: *const u8) -> i32;
    fn EC_KEY_new_by_curve_name(nid: i32) -> *mut EC_KEY;
    fn EC_KEY_free(key: *mut EC_KEY);
    fn EC_KEY_generate_key(key: *mut EC_KEY) -> i32;
    fn EC_KEY_get0_public_key(key: *const EC_KEY) -> *const c_void;
    fn ECDH_compute_key(out: *mut u8, outlen: usize, pubkey: *const c_void, key: *const EC_KEY, kdf: *const c_void) -> i32;
    fn ECDSA_do_sign(digest: *const u8, len: usize, key: *const EC_KEY) -> *mut ECDSA_SIG;
    fn ECDSA_do_verify(digest: *const u8, len: usize, sig: *const ECDSA_SIG, key: *const EC_KEY) -> i32;
    fn ECDSA_SIG_new() -> *mut ECDSA_SIG;
    fn ECDSA_SIG_free(sig: *mut ECDSA_SIG);
    fn ECDSA_SIG_get0(sig: *const ECDSA_SIG, r: *mut *const BIGNUM, s: *mut *const BIGNUM);
    fn ECDSA_SIG_set0(sig: *mut ECDSA_SIG, r: *mut BIGNUM, s: *mut BIGNUM) -> i32;
    fn BN_bn2bin_padded(out: *mut u8, len: usize, bn: *const BIGNUM) -> i32;
    fn BN_bin2bn(input: *const u8, len: usize, ret: *mut BIGNUM) -> *mut BIGNUM;
    fn EC_KEY_get0_private_key(key: *const EC_KEY) -> *const BIGNUM;
    fn EC_KEY_key2buf(key: *const EC_KEY, form: i32, out: *mut *mut u8, ctx: *mut c_void) -> usize;
    fn OPENSSL_free(p: *mut c_void);
    fn SHA256(data: *const u8, len: usize, out: *mut u8) -> *mut u8;
    fn SHA384(data: *const u8, len: usize, out: *mut u8) -> *mut u8;
    fn SHA512(data: *const u8, len: usize, out: *mut u8) -> *mut u8;
    fn d2i_PKCS8_PRIV_KEY_INFO(out: *mut c_void, inp: *mut *const u8, len: i64) -> *mut c_void;
    fn i2d_PKCS8_PRIV_KEY_INFO(p8: *const c_void, out: *mut *mut u8) -> i32;
    fn PKCS8_PRIV_KEY_INFO_free(p8: *mut c_void);
    fn EVP_PKCS82PKEY(p8: *const c_void) -> *mut c_void;
    fn EVP_PKEY2PKCS8(pkey: *const c_void) -> *mut c_void;
    fn EVP_PKEY_new() -> *mut c_void;
    fn EVP_PKEY_free(pkey: *mut c_void);
    fn EVP_PKEY_get0_EC_KEY(pkey: *const c_void) -> *mut EC_KEY;
    fn EVP_PKEY_set1_EC_KEY(pkey: *mut c_void, key: *mut EC_KEY) -> i32;
    fn EVP_PKEY_get_raw_private_key(pkey: *const c_void, out: *mut u8, len: *mut usize) -> i32;
    fn EVP_PKEY_get_raw_public_key(pkey: *const c_void, out: *mut u8, len: *mut usize) -> i32;
    fn EVP_parse_private_key(cbs: *mut Cbs) -> *mut c_void;
    fn EVP_parse_public_key(cbs: *mut Cbs) -> *mut c_void;
    fn d2i_PUBKEY(out: *mut c_void, inp: *mut *const u8, len: i64) -> *mut c_void;
    fn i2d_PUBKEY(pkey: *const c_void, out: *mut *mut u8) -> i32;
    fn i2d_ECPrivateKey(key: *const EC_KEY, out: *mut *mut u8) -> i32;
    fn EC_KEY_check_key(key: *const EC_KEY) -> i32;
    fn EC_KEY_get0_group(key: *const EC_KEY) -> *const c_void;
    fn EC_KEY_set_public_key(key: *mut EC_KEY, point: *const c_void) -> i32;
    fn EC_POINT_new(group: *const c_void) -> *mut c_void;
    fn EC_POINT_free(point: *mut c_void);
    fn EC_POINT_oct2point(group: *const c_void, point: *mut c_void, buf: *const u8, len: usize, ctx: *mut c_void) -> i32;
    fn ED25519_keypair_from_seed(out_public: *mut u8, out_private: *mut u8, seed: *const u8);
}

/// BoringSSL's `CBS`.
#[repr(C)]
struct Cbs {
    data: *const u8,
    len: usize,
}

fn cbs(bytes: &[u8]) -> Cbs {
    Cbs { data: bytes.as_ptr(), len: bytes.len() }
}

/// An `i2d_*` encoding, freed.
unsafe fn i2d(f: impl FnOnce(*mut *mut u8) -> i32) -> usize {
    let mut out: *mut u8 = std::ptr::null_mut();
    let n = f(&mut out);
    assert!(n > 0);
    unsafe { OPENSSL_free(out.cast()) };
    n as usize
}

/// Bun's EC raw import: `EC_POINT_oct2point`, then the key checked.
unsafe fn bssl_ec_raw(nid: i32, point: &[u8]) {
    unsafe {
        let key = EC_KEY_new_by_curve_name(nid);
        let group = EC_KEY_get0_group(key);
        let p = EC_POINT_new(group);
        assert_eq!(EC_POINT_oct2point(group, p, point.as_ptr(), point.len(), std::ptr::null_mut()), 1);
        assert_eq!(EC_KEY_set_public_key(key, p), 1);
        assert_eq!(EC_KEY_check_key(key), 1);
        let pkey = EVP_PKEY_new();
        EVP_PKEY_set1_EC_KEY(pkey, key);
        black_box(pkey);
        EVP_PKEY_free(pkey);
        EC_POINT_free(p);
        EC_KEY_free(key);
    }
}

/// The import and export rows: Bun's `CryptoKeyEC` and `CryptoKeyOKP` calls
/// against rind's loaders, each on the same bytes.
fn keys(filter: &str) {
    let ed = "ed25519".contains(filter) || filter.is_empty();
    if ed || "keys".contains(filter) {
        let pair = Ed25519KeyPair::generate().unwrap();
        let seed = pair.to_seed();
        let pkcs8 = pair.to_pkcs8v1();
        let spki = pair.to_spki();
        let b = time(|| unsafe {
            let mut c = cbs(pkcs8.as_ref());
            let pkey = EVP_parse_private_key(&mut c);
            let mut raw = [0u8; 32];
            let mut len = 32;
            assert_eq!(EVP_PKEY_get_raw_private_key(pkey, raw.as_mut_ptr(), &mut len), 1);
            EVP_PKEY_free(pkey);
            let (mut p, mut s) = ([0u8; 32], [0u8; 64]);
            ED25519_keypair_from_seed(p.as_mut_ptr(), s.as_mut_ptr(), raw.as_ptr());
            black_box((p, s));
        });
        let r = time(|| {
            black_box(Ed25519KeyPair::from_pkcs8(black_box(pkcs8.as_ref())).unwrap());
        });
        row("Ed25519 importKey pkcs8", b, r, "v1, public key derived");
        let b = time(|| unsafe {
            let (mut p, mut s) = ([0u8; 32], [0u8; 64]);
            ED25519_keypair_from_seed(p.as_mut_ptr(), s.as_mut_ptr(), black_box(seed.as_ref()).as_ptr());
            black_box((p, s));
        });
        let r = time(|| {
            black_box(Ed25519KeyPair::from_seed(black_box(seed.as_ref())).unwrap());
        });
        row("Ed25519 importKey jwk private", b, r, "seed alone");
        let b = time(|| unsafe {
            let mut c = cbs(spki.as_ref());
            let pkey = EVP_parse_public_key(&mut c);
            let mut raw = [0u8; 32];
            let mut len = 32;
            assert_eq!(EVP_PKEY_get_raw_public_key(pkey, raw.as_mut_ptr(), &mut len), 1);
            EVP_PKEY_free(pkey);
            black_box(raw);
        });
        let r = time(|| {
            black_box(PublicKey::from_spki(&signature::verify::ED25519, black_box(spki.as_ref())).unwrap());
        });
        row("Ed25519 importKey spki", b, r, "rind checks the point, BoringSSL at verify");
    }
    if "x25519".contains(filter) || filter.is_empty() || "keys".contains(filter) {
        let key = agreement::PrivateKey::generate(&agreement::X25519).unwrap();
        let spki = key.public_key().to_spki();
        let b = time(|| unsafe {
            let mut c = cbs(spki.as_ref());
            let pkey = EVP_parse_public_key(&mut c);
            let mut raw = [0u8; 32];
            let mut len = 32;
            assert_eq!(EVP_PKEY_get_raw_public_key(pkey, raw.as_mut_ptr(), &mut len), 1);
            EVP_PKEY_free(pkey);
            black_box(raw);
        });
        let r = time(|| {
            black_box(agreement::PublicKey::from_spki(&agreement::X25519, black_box(spki.as_ref())).unwrap());
        });
        row("X25519 importKey spki", b, r, "");
    }
}

/// The EC import and export rows for `c`.
unsafe fn ec_keys(c: &Curve) {
    let pair = EcdsaKeyPair::generate(c.sign).unwrap();
    let pkcs8 = pair.to_pkcs8();
    let spki = pair.to_spki();
    let public = pair.public_key();
    let point = public.as_ref();
    let (x, y) = point[1..].split_at(c.len);
    let compressed = [&[0x02 | (y[c.len - 1] & 1)][..], x].concat();
    unsafe {
        // Bun's platformImportPkcs8.
        let b = time(|| {
            let mut p = pkcs8.as_ref().as_ptr();
            let p8 = d2i_PKCS8_PRIV_KEY_INFO(std::ptr::null_mut(), &mut p, pkcs8.as_ref().len() as i64);
            let pkey = EVP_PKCS82PKEY(p8);
            assert_eq!(EC_KEY_check_key(EVP_PKEY_get0_EC_KEY(pkey)), 1);
            black_box(pkey);
            EVP_PKEY_free(pkey);
            PKCS8_PRIV_KEY_INFO_free(p8);
        });
        let r = time(|| {
            black_box(EcdsaKeyPair::from_pkcs8(c.sign, black_box(pkcs8.as_ref())).unwrap());
        });
        row(&format!("EC {} importKey pkcs8", c.name), b, r, "");

        // Bun's platformImportSpki parses the DER by hand before this.
        let b = time(|| {
            let mut p = spki.as_ref().as_ptr();
            let pkey = d2i_PUBKEY(std::ptr::null_mut(), &mut p, spki.as_ref().len() as i64);
            assert_eq!(EC_KEY_check_key(EVP_PKEY_get0_EC_KEY(pkey)), 1);
            black_box(pkey);
            EVP_PKEY_free(pkey);
        });
        let r = time(|| {
            black_box(PublicKey::from_spki(c.verify, black_box(spki.as_ref())).unwrap());
        });
        row(&format!("EC {} importKey spki", c.name), b, r, "BoringSSL: d2i_PUBKEY, a lower bound on Bun's path");

        let b = time(|| bssl_ec_raw(c.nid, black_box(point)));
        let r = time(|| {
            black_box(PublicKey::new(c.verify, black_box(point)).unwrap());
        });
        row(&format!("EC {} importKey raw", c.name), b, r, "uncompressed");
        let b = time(|| bssl_ec_raw(c.nid, black_box(&compressed)));
        let r = time(|| {
            black_box(agreement::PublicKey::new(c.agree, black_box(&compressed)).unwrap());
        });
        row(&format!("EC {} importKey raw", c.name), b, r, "compressed: a square root");

        // Bun's export paths, from a key BoringSSL already holds.
        let mut p = pkcs8.as_ref().as_ptr();
        let p8 = d2i_PKCS8_PRIV_KEY_INFO(std::ptr::null_mut(), &mut p, pkcs8.as_ref().len() as i64);
        let pkey = EVP_PKCS82PKEY(p8);
        PKCS8_PRIV_KEY_INFO_free(p8);
        let b = time(|| {
            let p8 = EVP_PKEY2PKCS8(pkey);
            black_box(i2d(|out| i2d_PKCS8_PRIV_KEY_INFO(p8, out)));
            PKCS8_PRIV_KEY_INFO_free(p8);
        });
        let r = time(|| {
            black_box(pair.to_pkcs8());
        });
        row(&format!("EC {} exportKey pkcs8", c.name), b, r, "");
        let b = time(|| {
            black_box(i2d(|out| i2d_PUBKEY(pkey, out)));
        });
        let r = time(|| {
            black_box(pair.to_spki());
        });
        row(&format!("EC {} exportKey spki", c.name), b, r, "");
        let ec = EVP_PKEY_get0_EC_KEY(pkey);
        let b = time(|| {
            black_box(i2d(|out| i2d_ECPrivateKey(ec, out)));
        });
        let r = time(|| {
            black_box(pair.to_sec1());
        });
        row(&format!("EC {} export sec1", c.name), b, r, "node:crypto KeyObject");
        EVP_PKEY_free(pkey);
    }
}

/// Median nanoseconds per call over batches filling about `budget`.
fn time(mut f: impl FnMut()) -> f64 {
    let budget = Duration::from_millis(
        std::env::var("BUDGET_MS").ok().and_then(|s| s.parse().ok()).unwrap_or(1500),
    );
    let warm = Instant::now();
    let mut n = 0u64;
    while warm.elapsed() < budget / 10 {
        f();
        n += 1;
    }
    let per_batch = (n / 2).max(1);
    let mut samples = Vec::new();
    let start = Instant::now();
    while start.elapsed() < budget || samples.len() < 5 {
        let t = Instant::now();
        for _ in 0..per_batch {
            f();
        }
        samples.push(t.elapsed().as_nanos() as f64 / per_batch as f64);
    }
    samples.sort_by(|a, b| a.partial_cmp(b).unwrap());
    samples[samples.len() / 2]
}

fn row(name: &str, bssl: f64, rind: f64, note: &str) {
    println!(
        "| {name} | {:.1} | {:.1} | {:.2}x | {note} |",
        bssl / 1000.0,
        rind / 1000.0,
        bssl / rind
    );
}

const MSG: &[u8] = &[0x5a; 64];

struct Curve {
    name: &'static str,
    nid: i32,
    len: usize,
    hash: unsafe extern "C" fn(*const u8, usize, *mut u8) -> *mut u8,
    hash_len: usize,
    digest: &'static digest::Algorithm,
    /// Another hash WebCrypto and node:crypto pair with the curve.
    other: (&'static str, unsafe extern "C" fn(*const u8, usize, *mut u8) -> *mut u8, usize, &'static digest::Algorithm),
    sign: &'static signature::EcdsaSigningAlgorithm,
    verify: &'static signature::VerificationAlgorithm,
    agree: &'static agreement::Algorithm,
}

fn main() {
    let filter = std::env::args().nth(1).unwrap_or_default();
    println!("| operation | BoringSSL us | rind us | rind speedup | note |");
    println!("|---|---|---|---|---|");
    keys(&filter);

    if "ed25519".contains(&filter) || filter.is_empty() {
        let mut pk = [0u8; 32];
        let mut sk = [0u8; 64];
        unsafe { ED25519_keypair(pk.as_mut_ptr(), sk.as_mut_ptr()) };
        let rind_pair = Ed25519KeyPair::from_seed_and_public_key(&sk[..32], &pk).unwrap();
        let mut sig = [0u8; 64];
        let b = time(|| unsafe {
            let mut p = [0u8; 32];
            let mut s = [0u8; 64];
            ED25519_keypair(p.as_mut_ptr(), s.as_mut_ptr());
            black_box((p, s));
        });
        let r = time(|| {
            let k = Ed25519KeyPair::generate().unwrap();
            black_box((k.to_seed(), k.public_key()));
        });
        row("Ed25519 generateKey", b, r, "");
        let b = time(|| unsafe {
            ED25519_sign(sig.as_mut_ptr(), MSG.as_ptr(), MSG.len(), sk.as_ptr());
            black_box(&sig);
        });
        let r = time(|| {
            black_box(rind_pair.sign(black_box(MSG)));
        });
        row("Ed25519 sign", b, r, "rind key pair cached");
        let r2 = time(|| {
            let k = Ed25519KeyPair::from_seed_and_public_key(&sk[..32], &pk).unwrap();
            black_box(k.sign(black_box(MSG)));
        });
        row("Ed25519 sign", b, r2, "rind key loaded per call");
        unsafe { ED25519_sign(sig.as_mut_ptr(), MSG.as_ptr(), MSG.len(), sk.as_ptr()) };
        let b = time(|| unsafe {
            black_box(ED25519_verify(MSG.as_ptr(), MSG.len(), sig.as_ptr(), pk.as_ptr()));
        });
        let r = time(|| {
            let k = PublicKey::new(&signature::verify::ED25519, &pk).unwrap();
            black_box(k.verify(MSG, &sig)).unwrap();
        });
        row("Ed25519 verify", b, r, "rind key parsed per call");
    }

    if "x25519".contains(&filter) || filter.is_empty() {
        let mut peer_pub = [0u8; 32];
        let mut peer_priv = [0u8; 32];
        unsafe { X25519_keypair(peer_pub.as_mut_ptr(), peer_priv.as_mut_ptr()) };
        let b = time(|| unsafe {
            let mut p = [0u8; 32];
            let mut s = [0u8; 32];
            X25519_keypair(p.as_mut_ptr(), s.as_mut_ptr());
            black_box((p, s));
        });
        let r = time(|| {
            let k = agreement::PrivateKey::generate(&agreement::X25519).unwrap();
            black_box(k.public_key());
        });
        row("X25519 generateKey", b, r, "");
        let mut out = [0u8; 32];
        let b = time(|| unsafe {
            black_box(X25519(out.as_mut_ptr(), peer_priv.as_ptr(), peer_pub.as_ptr()));
        });
        // Bun's WebCrypto keeps X25519's raw private key and loads it per derive.
        let r = time(|| {
            let k = agreement::PrivateKey::from_scalar(&agreement::X25519, black_box(&peer_priv)).unwrap();
            black_box(k.agree(black_box(&peer_pub)).unwrap());
        });
        row("X25519 deriveBits", b, r, "rind key loaded per call");
        let stored = agreement::PrivateKey::from_scalar(&agreement::X25519, &peer_priv).unwrap();
        let r = time(|| {
            black_box(stored.agree(black_box(&peer_pub)).unwrap());
        });
        row("X25519 deriveBits", b, r, "rind key stored (node:crypto)");
        let bg = time(|| unsafe {
            let mut p = [0u8; 32];
            let mut s = [0u8; 32];
            X25519_keypair(p.as_mut_ptr(), s.as_mut_ptr());
            black_box(X25519(out.as_mut_ptr(), s.as_ptr(), peer_pub.as_ptr()));
        });
        let r = time(|| {
            let k = agreement::PrivateKey::generate(&agreement::X25519).unwrap();
            black_box(k.public_key());
            black_box(k.agree(&peer_pub).unwrap());
        });
        row("X25519 generate + derive", bg, r, "ephemeral");
    }

    let curves = [
        Curve { name: "P-256", nid: 415, len: 32, hash: SHA256, hash_len: 32,
            digest: &digest::SHA256, other: ("SHA-384", SHA384, 48, &digest::SHA384),
            sign: &signature::sign::ECDSA_P256_SHA256_FIXED, verify: &signature::verify::ECDSA_P256_SHA256_FIXED,
            agree: &agreement::ECDH_P256 },
        Curve { name: "P-384", nid: 715, len: 48, hash: SHA384, hash_len: 48,
            digest: &digest::SHA384, other: ("SHA-256", SHA256, 32, &digest::SHA256),
            sign: &signature::sign::ECDSA_P384_SHA384_FIXED, verify: &signature::verify::ECDSA_P384_SHA384_FIXED,
            agree: &agreement::ECDH_P384 },
        Curve { name: "P-521", nid: 716, len: 66, hash: SHA512, hash_len: 64,
            digest: &digest::SHA512, other: ("SHA-256", SHA256, 32, &digest::SHA256),
            sign: &signature::sign::ECDSA_P521_SHA512_FIXED, verify: &signature::verify::ECDSA_P521_SHA512_FIXED,
            agree: &agreement::ECDH_P521 },
    ];
    for c in &curves {
        if filter == "keys" {
            unsafe { ec_keys(c) };
            continue;
        }
        if !c.name.to_lowercase().replace('-', "").contains(&filter) && !filter.is_empty() {
            continue;
        }
        unsafe { ec_keys(c) };
        unsafe {
            let key = EC_KEY_new_by_curve_name(c.nid);
            assert_eq!(EC_KEY_generate_key(key), 1);
            let mut buf: *mut u8 = std::ptr::null_mut();
            let n = EC_KEY_key2buf(key, 4, &mut buf, std::ptr::null_mut());
            let point = std::slice::from_raw_parts(buf, n).to_vec();
            OPENSSL_free(buf.cast());
            let mut scalar = vec![0u8; c.len];
            BN_bn2bin_padded(scalar.as_mut_ptr(), c.len, EC_KEY_get0_private_key(key));
            let rind_pair = EcdsaKeyPair::from_scalar_and_public_key(c.sign, &scalar, &point).unwrap();

            let b = time(|| {
                let k = EC_KEY_new_by_curve_name(c.nid);
                EC_KEY_generate_key(k);
                black_box(k);
                EC_KEY_free(k);
            });
            let r = time(|| {
                black_box(EcdsaKeyPair::generate(c.sign).unwrap());
            });
            row(&format!("ECDSA {} generateKey", c.name), b, r, "");

            // Bun's CryptoAlgorithmECDSA::platformSign: digest, ECDSA_do_sign, r||s.
            let bun_sign = || {
                let mut d = [0u8; 64];
                (c.hash)(MSG.as_ptr(), MSG.len(), d.as_mut_ptr());
                let sig = ECDSA_do_sign(d.as_ptr(), c.hash_len, key);
                let mut rp = std::ptr::null();
                let mut sp = std::ptr::null();
                ECDSA_SIG_get0(sig, &mut rp, &mut sp);
                let mut out = [0u8; 132];
                BN_bn2bin_padded(out.as_mut_ptr(), c.len, rp);
                BN_bn2bin_padded(out[c.len..].as_mut_ptr(), c.len, sp);
                ECDSA_SIG_free(sig);
                out
            };
            let b = time(|| {
                black_box(bun_sign());
            });
            let r = time(|| {
                black_box(rind_pair.sign(black_box(MSG)).unwrap());
            });
            row(&format!("ECDSA {} sign", c.name), b, r, "rind key pair cached");
            let r2 = time(|| {
                let k = EcdsaKeyPair::from_scalar_and_public_key(c.sign, &scalar, &point).unwrap();
                black_box(k.sign(black_box(MSG)).unwrap());
            });
            row(&format!("ECDSA {} sign", c.name), b, r2, "rind key loaded per call");

            let sig = bun_sign();
            let sig = &sig[..2 * c.len];
            let b = time(|| {
                let s = ECDSA_SIG_new();
                let rr = BN_bin2bn(sig.as_ptr(), c.len, std::ptr::null_mut());
                let ss = BN_bin2bn(sig[c.len..].as_ptr(), c.len, std::ptr::null_mut());
                ECDSA_SIG_set0(s, rr, ss);
                let mut d = [0u8; 64];
                (c.hash)(MSG.as_ptr(), MSG.len(), d.as_mut_ptr());
                assert_eq!(ECDSA_do_verify(d.as_ptr(), c.hash_len, s, key), 1);
                ECDSA_SIG_free(s);
            });
            let pk = PublicKey::new(c.verify, &point).unwrap();
            let r = time(|| {
                pk.verify(black_box(MSG), sig).unwrap();
            });
            row(&format!("ECDSA {} verify", c.name), b, r, "rind key cached");
            let r2 = time(|| {
                let pk = PublicKey::new(c.verify, &point).unwrap();
                pk.verify(black_box(MSG), sig).unwrap();
            });
            row(&format!("ECDSA {} verify", c.name), b, r2, "rind key parsed per call");

            // node:crypto's createSign hashes as data arrives, then signs the digest; and
            // WebCrypto and node:crypto also pair a curve with another hash.
            for (name, hash, hash_len, digest) in [("the curve's hash", c.hash, c.hash_len, c.digest), c.other] {
                let b = time(|| {
                    let mut d = [0u8; 64];
                    hash(MSG.as_ptr(), MSG.len(), d.as_mut_ptr());
                    let sig = ECDSA_do_sign(d.as_ptr(), hash_len, key);
                    black_box(sig);
                    ECDSA_SIG_free(sig);
                });
                let r = time(|| {
                    let d = digest::digest(digest, black_box(MSG));
                    black_box(rind_pair.sign_digest(&d).unwrap());
                });
                row(&format!("ECDSA {} sign, prehash {name}", c.name), b, r, "rind key pair cached");
                let prehashed = rind_pair.sign_digest(&digest::digest(digest, MSG)).unwrap();
                let prehashed = prehashed.as_ref();
                let b = time(|| {
                    let s = ECDSA_SIG_new();
                    let rr = BN_bin2bn(prehashed.as_ptr(), c.len, std::ptr::null_mut());
                    let ss = BN_bin2bn(prehashed[c.len..].as_ptr(), c.len, std::ptr::null_mut());
                    ECDSA_SIG_set0(s, rr, ss);
                    let mut d = [0u8; 64];
                    hash(MSG.as_ptr(), MSG.len(), d.as_mut_ptr());
                    assert_eq!(ECDSA_do_verify(d.as_ptr(), hash_len, s, key), 1);
                    ECDSA_SIG_free(s);
                });
                let r = time(|| {
                    let d = digest::digest(digest, black_box(MSG));
                    pk.verify_digest(&d, prehashed).unwrap();
                });
                row(&format!("ECDSA {} verify, prehash {name}", c.name), b, r, "rind key cached");
            }

            let peer = EC_KEY_new_by_curve_name(c.nid);
            EC_KEY_generate_key(peer);
            let mut out = [0u8; 66];
            let b = time(|| {
                black_box(ECDH_compute_key(out.as_mut_ptr(), c.len, EC_KEY_get0_public_key(peer), key, std::ptr::null()));
            });
            // Bun parses the peer's point, then agrees with the stored key.
            let peer_point = {
                let mut buf: *mut u8 = std::ptr::null_mut();
                let n = EC_KEY_key2buf(peer, 4, &mut buf, std::ptr::null_mut());
                let v = std::slice::from_raw_parts(buf, n).to_vec();
                OPENSSL_free(buf.cast());
                v
            };
            let stored = agreement::PrivateKey::from_scalar(c.agree, &scalar).unwrap();
            let r = time(|| {
                let p = agreement::PublicKey::new(c.agree, black_box(&peer_point)).unwrap();
                black_box(stored.agree(p.as_ref()).unwrap());
            });
            row(&format!("ECDH {} deriveBits", c.name), b, r, "rind key stored, peer parsed per call");
            let bg = time(|| {
                let k = EC_KEY_new_by_curve_name(c.nid);
                EC_KEY_generate_key(k);
                black_box(ECDH_compute_key(out.as_mut_ptr(), c.len, EC_KEY_get0_public_key(peer), k, std::ptr::null()));
                EC_KEY_free(k);
            });
            let r = time(|| {
                let k = agreement::PrivateKey::generate(c.agree).unwrap();
                black_box(k.public_key());
                black_box(k.agree(&point).unwrap());
            });
            row(&format!("ECDH {} generate + derive", c.name), bg, r, "ephemeral; rind parses the peer point per call");
            EC_KEY_free(peer);
            EC_KEY_free(key);
        }
    }
}
