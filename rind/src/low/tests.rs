// Written for Graviola by Joe Birr-Pixton, 2024.
// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

fn bignum_mux_equiv(p: u64, x_if_p: &[u64], y_if_not_p: &[u64]) {
    let mut model_z = vec![0; x_if_p.len()];
    let mut real_z = vec![0; x_if_p.len()];
    model::bignum_mux(p, &mut model_z, x_if_p, y_if_not_p);
    super::bignum_mux(p, &mut real_z, x_if_p, y_if_not_p);
    assert_eq!(model_z, real_z);
}

#[test]
fn bignum_mux() {
    bignum_mux_equiv(0, &[0u64; 4], &[1u64; 4]);
    bignum_mux_equiv(1, &[1u64; 4], &[0xff; 4]);
    bignum_mux_equiv(u64::MAX, &[1; 1], &[0; 1]);
}

#[test]
fn zeroise() {
    for n in 0..1024 {
        for offset in 0..4 {
            zeroise_equiv(offset, n);
        }
    }
}

// Zeroes `len` bytes from `offset` in, so the wide stores start unaligned too,
// and checks the bytes either side are untouched.
fn zeroise_equiv(offset: usize, len: usize) {
    let mut expect = vec![0xffu8; offset + len + 1];
    expect[offset..offset + len].fill(0);
    let mut bytes = vec![0xffu8; offset + len + 1];
    super::zeroise(&mut bytes[offset..offset + len]);
    assert_eq!(expect, bytes);
}

#[test]
fn ct_equal() {
    ct_equal_equiv(&[], &[]);

    for n in 1..1024 {
        let a = vec![0u8; n];

        for i in 0..n {
            let mut b = vec![0u8; n];
            b[i] = i as u8;
            ct_equal_equiv(&a, &b);
        }
    }
}

fn ct_equal_equiv(a: &[u8], b: &[u8]) {
    assert_eq!(a == b, super::ct_equal(a, b));
}

// ld64 splits a Mach-O object into atoms at each CFI frame, and can
// dead-strip one that is reached only by branches with no relocation, such as
// a routine joined into another's naked function.
#[test]
fn apple_routines_open_one_cfi_frame() {
    fn visit(dir: &std::path::Path, files: &mut usize) {
        for entry in std::fs::read_dir(dir).unwrap() {
            let path = entry.unwrap().path();
            if path.is_dir() {
                visit(&path, files);
            } else if path.to_str().unwrap().ends_with(".apple.s") {
                let text = std::fs::read_to_string(&path).unwrap();
                let frames = text
                    .lines()
                    .filter(|line| line.trim() == ".cfi_startproc")
                    .count();
                assert!(frames <= 1, "{}: {frames} CFI frames", path.display());
                *files += 1;
            }
        }
    }

    let mut files = 0;
    visit(
        concat!(env!("CARGO_MANIFEST_DIR"), "/src/low").as_ref(),
        &mut files,
    );
    assert_ne!(files, 0);
}

mod model {
    pub(super) fn bignum_mux(p: u64, z: &mut [u64], x_if_p: &[u64], y_if_not_p: &[u64]) {
        if p > 0 {
            z.copy_from_slice(x_if_p);
        } else {
            z.copy_from_slice(y_if_not_p);
        }
    }
}

#[test]
fn test_edwards25519_decode() {
    use hex::FromHex;

    // valid pubkey from RFC 8032
    let pk_hex = "d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a";
    let pk = <[u8; 32]>::from_hex(pk_hex).unwrap();
    let mut point = [0u64; 8];
    assert!(super::edwards25519_decode(&mut point, &pk));

    // invalid pubkey
    assert!(!super::edwards25519_decode(&mut point, &[0xffu8; 32]));
}
