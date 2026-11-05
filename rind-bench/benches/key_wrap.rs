mod criterion;
use criterion::{BenchmarkId, Criterion, criterion_group, criterion_main};

// Wrapping and unwrapping a 16- and a 32-byte key, each from the KEK's bytes:
// aws-lc-rs's `KeyWrap` consumes its key, so every call expands it again.
fn bench_key_wrap(c: &mut Criterion) {
    for (name, kek_len) in [("aes128-kw", 16), ("aes256-kw", 32)] {
        let kek = &[0x42u8; 32][..kek_len];
        for (op, unwrap) in [("wrap", false), ("unwrap", true)] {
            let mut group = c.benchmark_group(format!("{name}-{op}"));
            for key_len in [16, 32] {
                let size_name = format!("{key_len}B");
                let key = &[0x24u8; 32][..key_len];
                let mut wrapped = vec![0u8; key_len + 8];
                rind::key_wrap::AesKek::new(rind_algorithm(kek_len), kek)
                    .unwrap()
                    .wrap(key, &mut wrapped)
                    .unwrap();
                let mut out = vec![0u8; key_len + 8];

                group.bench_function(BenchmarkId::new("aws-lc-rs", &size_name), |b| {
                    use aws_lc_rs::key_wrap::{AES_128, AES_256, AesKek, KeyWrap};
                    let algorithm = if kek_len == 16 { &AES_128 } else { &AES_256 };
                    b.iter(|| {
                        let kek = AesKek::new(algorithm, kek).unwrap();
                        if unwrap {
                            kek.unwrap(&wrapped, &mut out).unwrap();
                        } else {
                            kek.wrap(key, &mut out).unwrap();
                        }
                    });
                });
                group.bench_function(BenchmarkId::new("rind", &size_name), |b| {
                    let algorithm = rind_algorithm(kek_len);
                    b.iter(|| {
                        let kek = rind::key_wrap::AesKek::new(algorithm, kek).unwrap();
                        if unwrap {
                            kek.unwrap(&wrapped, &mut out[..key_len]).unwrap();
                        } else {
                            kek.wrap(key, &mut out).unwrap();
                        }
                    });
                });
            }
        }
    }
}

fn rind_algorithm(kek_len: usize) -> &'static rind::cipher::Algorithm {
    if kek_len == 16 {
        &rind::key_wrap::AES_128
    } else {
        &rind::key_wrap::AES_256
    }
}

criterion_group!(benches, bench_key_wrap);
criterion_main!(benches);
