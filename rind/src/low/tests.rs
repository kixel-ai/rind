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
fn zero_bytes() {
    for n in 0..1024 {
        for offset in 0..4 {
            zero_bytes_equiv(offset, n);
        }
    }
}

// Zeroes `len` bytes from `offset` in, so the wide stores start unaligned too,
// and checks the bytes either side are untouched.
fn zero_bytes_equiv(offset: usize, len: usize) {
    let mut expect = vec![0xffu8; offset + len + 1];
    expect[offset..offset + len].fill(0);
    let mut bytes = vec![0xffu8; offset + len + 1];
    // SAFETY: `bytes` holds `len` writable bytes from `offset`.
    unsafe { super::zero_bytes(bytes[offset..].as_mut_ptr(), len) };
    assert_eq!(expect, bytes);
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

// A source with `unsafe` checks its preconditions in every build, so a
// release binary's soundness never rests on its callers.
#[test]
fn no_debug_assert_beside_unsafe() {
    fn visit(dir: &std::path::Path, found: &mut Vec<String>) {
        for entry in std::fs::read_dir(dir).unwrap() {
            let path = entry.unwrap().path();
            if path.is_dir() {
                visit(&path, found);
            } else if path.extension().is_some_and(|e| e == "rs") {
                let text = std::fs::read_to_string(&path).unwrap();
                // Spelled apart, so this file does not match itself.
                let debug = ["debug", "_assert"].concat();
                let asserts = ["!", "_eq!", "_ne!"]
                    .iter()
                    .any(|bang| text.contains(&format!("{debug}{bang}")));
                let unsafe_ = [
                    "unsafe {",
                    "unsafe fn",
                    "unsafe extern",
                    "unsafe(",
                    "unsafe impl",
                ]
                .iter()
                .any(|word| text.contains(word));
                if asserts && unsafe_ {
                    found.push(path.display().to_string());
                }
            }
        }
    }

    let mut found = Vec::new();
    visit(
        concat!(env!("CARGO_MANIFEST_DIR"), "/src/low").as_ref(),
        &mut found,
    );
    assert!(
        found.is_empty(),
        "debug assertions beside `unsafe`: {found:?}"
    );
}

/// Each wrapper that takes slices refuses mismatched ones, by panicking
/// before its assembly runs. CI runs this in release builds too, where a
/// debug assertion would not fire.
#[test]
fn wrappers_refuse_mismatched_slices() {
    #[repr(align(32))]
    struct Aligned<const N: usize>([i16; N]);

    // 2 bytes past a 32-byte boundary.
    fn misaligned<const N: usize>(buf: &mut Aligned<512>) -> &mut [i16; N] {
        (&mut buf.0[1..1 + N]).try_into().unwrap()
    }

    let mut cases: Vec<(&str, Box<dyn Fn()>)> = vec![
        (
            "mont_mul",
            Box::new(|| super::mont_mul(&mut [0; 4], &[0; 4], &[0; 3], &[1; 4], 1)),
        ),
        (
            "mont_sqr",
            Box::new(|| super::mont_sqr(&mut [0; 3], &[0; 4], &[1; 4], 1)),
        ),
        (
            "mont_mul, one word",
            Box::new(|| super::mont_mul(&mut [0; 1], &[0; 1], &[], &[1; 1], 1)),
        ),
        (
            "sha1_compress_blocks",
            Box::new(|| super::sha1_compress_blocks(&mut [0; 5], &[0; 63])),
        ),
        (
            "sha256_compress_blocks",
            Box::new(|| super::sha256_compress_blocks(&mut [0; 8], &[0; 65])),
        ),
        (
            "sha512_compress_blocks",
            Box::new(|| super::sha512_compress_blocks(&mut [0; 8], &[0; 127])),
        ),
    ];

    #[cfg(rind_backend = "x86_64")]
    {
        use super::x86_64 as a;
        cases.extend::<[(&str, Box<dyn Fn()>); _]>([
            (
                "bignum_mux",
                Box::new(|| a::bignum_mux::bignum_mux(1, &mut [0; 4], &[0; 4], &[0; 3])),
            ),
            (
                "bignum_copy_row_from_table",
                Box::new(|| {
                    a::bignum_copy_row_from_table::bignum_copy_row_from_table(
                        &mut [0; 4],
                        &[0; 15],
                        4,
                        4,
                        0,
                    )
                }),
            ),
            (
                "bignum_modadd",
                Box::new(|| {
                    a::bignum_modadd::bignum_modadd(&mut [0; 4], &[0; 4], &[0; 4], &[1; 3])
                }),
            ),
            (
                "bignum_modsub",
                Box::new(|| {
                    a::bignum_modsub::bignum_modsub(&mut [0; 4], &[0; 3], &[0; 4], &[1; 4])
                }),
            ),
            (
                "bignum_modinv",
                Box::new(|| {
                    a::bignum_modinv::bignum_modinv(&mut [0; 4], &[0; 4], &[1; 4], &mut [0; 11])
                }),
            ),
            (
                "bignum_montmul",
                Box::new(|| {
                    a::bignum_montmul::bignum_montmul(&mut [0; 4], &[0; 4], &[0; 3], &[1; 4])
                }),
            ),
            (
                "bignum_demont",
                Box::new(|| a::bignum_demont::bignum_demont(&mut [0; 4], &[0; 3], &[1; 4])),
            ),
            (
                "bignum_montifier",
                Box::new(|| {
                    a::bignum_montifier::bignum_montifier(&mut [0; 4], &[1; 4], &mut [0; 3])
                }),
            ),
            (
                "bignum_montredc",
                Box::new(|| a::bignum_montredc::bignum_montredc(&mut [0; 4], &[0; 8], &[1; 3], 1)),
            ),
            (
                "bignum_mul",
                Box::new(|| a::bignum_mul::bignum_mul(&mut [0; 7], &[0; 4], &[0; 4])),
            ),
            (
                "bignum_emontredc_8n",
                Box::new(|| {
                    a::bignum_emontredc_8n::bignum_emontredc_8n(&mut [0; 8], &[1; 4], 1);
                }),
            ),
            (
                "bignum_optsub",
                Box::new(|| a::bignum_optsub::bignum_optsub(&mut [0; 4], &[0; 4], &[0; 3], 1)),
            ),
            (
                "bignum_negmodinv",
                Box::new(|| a::bignum_negmodinv::bignum_negmodinv(&mut [0; 4], &[1; 3])),
            ),
            (
                "bignum_coprime",
                Box::new(|| {
                    a::bignum_coprime::bignum_coprime(&[1; 4], &[1; 4], &mut [0; 7]);
                }),
            ),
            (
                "bignum_kmul_16_32",
                Box::new(|| {
                    a::bignum_kmul_16_32::bignum_kmul_16_32(
                        &mut [0; 32],
                        &[0; 16],
                        &[0; 15],
                        &mut [0; 32],
                    )
                }),
            ),
            (
                "bignum_kmul_32_64",
                Box::new(|| {
                    a::bignum_kmul_32_64::bignum_kmul_32_64(
                        &mut [0; 63],
                        &[0; 32],
                        &[0; 32],
                        &mut [0; 96],
                    )
                }),
            ),
            (
                "bignum_ksqr_16_32",
                Box::new(|| {
                    a::bignum_ksqr_16_32::bignum_ksqr_16_32(&mut [0; 32], &[0; 15], &mut [0; 24])
                }),
            ),
            (
                "bignum_ksqr_32_64",
                Box::new(|| {
                    a::bignum_ksqr_32_64::bignum_ksqr_32_64(&mut [0; 64], &[0; 31], &mut [0; 72])
                }),
            ),
            (
                "mont_exp",
                Box::new(|| a::mont_exp::mont_exp(&mut [0; 4], &[0; 4], &[0; 3], &[1], &[1; 4], 1)),
            ),
            (
                "mlkem_rej_uniform_vartime",
                Box::new(|| {
                    a::mlkem_rej_uniform_vartime::mlkem_rej_uniform_vartime(
                        &mut [0; 256],
                        &[0; 13],
                        &[0; 4096],
                    );
                }),
            ),
            (
                "mlkem_ntt",
                Box::new(|| a::mlkem_ntt::mlkem_ntt(misaligned(&mut Aligned([0; 512])), &[0; 624])),
            ),
            (
                "mlkem_intt",
                Box::new(|| {
                    a::mlkem_intt::mlkem_intt(misaligned(&mut Aligned([0; 512])), &[0; 624])
                }),
            ),
            (
                "mlkem_tobytes",
                Box::new(|| {
                    a::mlkem_tobytes::mlkem_tobytes(
                        &mut [0; 384],
                        misaligned(&mut Aligned([0; 512])),
                    )
                }),
            ),
            (
                "mlkem_frombytes",
                Box::new(|| {
                    a::mlkem_frombytes::mlkem_frombytes(
                        misaligned(&mut Aligned([0; 512])),
                        &[0; 384],
                    )
                }),
            ),
            (
                "mlkem_tomont",
                Box::new(|| a::mlkem_tomont::mlkem_tomont(misaligned(&mut Aligned([0; 512])))),
            ),
            (
                "mlkem_unpack",
                Box::new(|| a::mlkem_unpack::mlkem_unpack(misaligned(&mut Aligned([0; 512])))),
            ),
            (
                "mlkem_reduce",
                Box::new(|| a::mlkem_reduce::mlkem_reduce(misaligned(&mut Aligned([0; 512])))),
            ),
            (
                "mlkem_mulcache_compute",
                Box::new(|| {
                    a::mlkem_mulcache_compute::mlkem_mulcache_compute(
                        misaligned(&mut Aligned([0; 512])),
                        &Aligned([0; 256]).0,
                        &Aligned([0; 624]).0,
                    )
                }),
            ),
            (
                "mlkem_basemul_k3",
                Box::new(|| {
                    a::mlkem_basemul_k3::mlkem_basemul_k3(
                        &mut Aligned([0; 256]).0,
                        misaligned(&mut Aligned([0; 512])),
                        &Aligned([0; 768]).0,
                        &Aligned([0; 384]).0,
                    )
                }),
            ),
        ]);
    }

    #[cfg(rind_backend = "aarch64")]
    {
        use super::aarch64 as a;
        cases.extend::<[(&str, Box<dyn Fn()>); _]>([
            (
                "bignum_mux",
                Box::new(|| a::bignum_mux::bignum_mux(1, &mut [0; 4], &[0; 4], &[0; 3])),
            ),
            (
                "bignum_copy_row_from_table",
                Box::new(|| {
                    a::bignum_copy_row_from_table::bignum_copy_row_from_table(
                        &mut [0; 4],
                        &[0; 15],
                        4,
                        4,
                        0,
                    )
                }),
            ),
            (
                "bignum_copy_row_from_table_8n",
                Box::new(|| {
                    a::bignum_copy_row_from_table_8n::bignum_copy_row_from_table_8n(
                        &mut [0; 8],
                        &[0; 31],
                        4,
                        8,
                        0,
                    )
                }),
            ),
            (
                "bignum_copy_row_from_table_16",
                Box::new(|| {
                    a::bignum_copy_row_from_table_16::bignum_copy_row_from_table_16(
                        &mut [0; 16],
                        &[0; 63],
                        4,
                        0,
                    )
                }),
            ),
            (
                "bignum_copy_row_from_table_32",
                Box::new(|| {
                    a::bignum_copy_row_from_table_32::bignum_copy_row_from_table_32(
                        &mut [0; 32],
                        &[0; 127],
                        4,
                        0,
                    )
                }),
            ),
            (
                "bignum_modadd",
                Box::new(|| {
                    a::bignum_modadd::bignum_modadd(&mut [0; 4], &[0; 4], &[0; 4], &[1; 3])
                }),
            ),
            (
                "bignum_modsub",
                Box::new(|| {
                    a::bignum_modsub::bignum_modsub(&mut [0; 4], &[0; 3], &[0; 4], &[1; 4])
                }),
            ),
            (
                "bignum_modinv",
                Box::new(|| {
                    a::bignum_modinv::bignum_modinv(&mut [0; 4], &[0; 4], &[1; 4], &mut [0; 11])
                }),
            ),
            (
                "bignum_montmul",
                Box::new(|| {
                    a::bignum_montmul::bignum_montmul(&mut [0; 4], &[0; 4], &[0; 3], &[1; 4])
                }),
            ),
            (
                "bignum_montsqr",
                Box::new(|| a::bignum_montsqr::bignum_montsqr(&mut [0; 4], &[0; 3], &[1; 4])),
            ),
            (
                "bignum_demont",
                Box::new(|| a::bignum_demont::bignum_demont(&mut [0; 4], &[0; 3], &[1; 4])),
            ),
            (
                "bignum_montifier",
                Box::new(|| {
                    a::bignum_montifier::bignum_montifier(&mut [0; 4], &[1; 4], &mut [0; 3])
                }),
            ),
            (
                "bignum_montredc",
                Box::new(|| a::bignum_montredc::bignum_montredc(&mut [0; 4], &[0; 8], &[1; 3], 1)),
            ),
            (
                "bignum_mul",
                Box::new(|| a::bignum_mul::bignum_mul(&mut [0; 7], &[0; 4], &[0; 4])),
            ),
            (
                "bignum_optsub",
                Box::new(|| a::bignum_optsub::bignum_optsub(&mut [0; 4], &[0; 4], &[0; 3], 1)),
            ),
            (
                "bignum_negmodinv",
                Box::new(|| a::bignum_negmodinv::bignum_negmodinv(&mut [0; 4], &[1; 3])),
            ),
            (
                "bignum_coprime",
                Box::new(|| {
                    a::bignum_coprime::bignum_coprime(&[1; 4], &[1; 4], &mut [0; 7]);
                }),
            ),
            (
                "mlkem_ntt",
                Box::new(|| {
                    a::mlkem_ntt::mlkem_ntt(
                        misaligned(&mut Aligned([0; 512])),
                        &Aligned([0; 80]).0,
                        &Aligned([0; 384]).0,
                    )
                }),
            ),
            (
                "mlkem_intt",
                Box::new(|| {
                    a::mlkem_intt::mlkem_intt(
                        misaligned(&mut Aligned([0; 512])),
                        &Aligned([0; 80]).0,
                        &Aligned([0; 384]).0,
                    )
                }),
            ),
            (
                "mlkem_tobytes",
                Box::new(|| {
                    a::mlkem_tobytes::mlkem_tobytes(
                        &mut [0; 384],
                        misaligned(&mut Aligned([0; 512])),
                    )
                }),
            ),
        ]);
    }

    let accepted: Vec<_> = cases
        .iter()
        .filter(|(_, call)| std::panic::catch_unwind(core::panic::AssertUnwindSafe(call)).is_ok())
        .map(|(name, _)| *name)
        .collect();
    assert!(
        accepted.is_empty(),
        "ran with mismatched arguments: {accepted:?}"
    );
}
