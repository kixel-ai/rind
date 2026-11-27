#[cfg(not(any(target_arch = "x86_64", target_arch = "aarch64")))]
fn main() {
    println!("only for x86_64 and aarch64 architectures");
}

#[cfg(target_arch = "x86_64")]
fn main() {
    use std::arch::x86_64::__cpuid;

    // "GenuineIntel", spread over ebx, edx, and ecx.
    // `__cpuid` is safe from Rust 1.94 but `unsafe` on the 1.90 MSRV.
    #[allow(unused_unsafe)]
    // SAFETY: every x86_64 CPU has `cpuid`.
    let id = unsafe { __cpuid(0) };
    let intel = (id.ebx, id.edx, id.ecx) == (0x756e_6547, 0x4965_6e69, 0x6c65_746e);
    // "AuthenticAMD", whose family 19h CPUs with AVX-512 IFMA are Zen 4's:
    // leaf 1's EAX holds the family, bits 11:8 plus 27:20 where those are 0xf.
    #[allow(unused_unsafe)]
    // SAFETY: as above, and the CPU has leaf 1 where leaf 0 reports it.
    let eax1 = if id.eax >= 1 {
        unsafe { __cpuid(1) }.eax
    } else {
        0
    };
    let family = (eax1 >> 8 & 0xf)
        + if eax1 >> 8 & 0xf == 0xf {
            eax1 >> 20 & 0xff
        } else {
            0
        };
    let amd = (id.ebx, id.edx, id.ecx) == (0x6874_7541, 0x6974_6e65, 0x444d_4163);
    let zen4 = amd && family == 0x19 && is_x86_feature_detected!("avx512ifma");
    // Family 1Ah is Zen 5's, whose AES-GCM runs verified-garbage's AVX-512
    // code for long messages.
    let zen5 = amd && family == 0x1a;

    // Every feature `rind/src/low/x86_64/cpu.rs` reads, so the scans show
    // which dispatch paths each CPU selects, plus `sha512`, which rind records
    // and does not dispatch on.
    let cpuid = [
        ("intel", intel),
        ("zen4", zen4),
        ("zen5", zen5),
        ("adx", is_x86_feature_detected!("adx")),
        ("aes", is_x86_feature_detected!("aes")),
        ("vaes", is_x86_feature_detected!("vaes")),
        ("pclmulqdq", is_x86_feature_detected!("pclmulqdq")),
        ("vpclmulqdq", is_x86_feature_detected!("vpclmulqdq")),
        ("bmi1", is_x86_feature_detected!("bmi1")),
        ("bmi2", is_x86_feature_detected!("bmi2")),
        ("movbe", is_x86_feature_detected!("movbe")),
        ("popcnt", is_x86_feature_detected!("popcnt")),
        ("ssse3", is_x86_feature_detected!("ssse3")),
        ("sse4.1", is_x86_feature_detected!("sse4.1")),
        ("avx", is_x86_feature_detected!("avx")),
        ("avx2", is_x86_feature_detected!("avx2")),
        ("avx512f", is_x86_feature_detected!("avx512f")),
        ("avx512dq", is_x86_feature_detected!("avx512dq")),
        ("avx512ifma", is_x86_feature_detected!("avx512ifma")),
        ("avx512bw", is_x86_feature_detected!("avx512bw")),
        ("avx512vl", is_x86_feature_detected!("avx512vl")),
        ("avx512vbmi", is_x86_feature_detected!("avx512vbmi")),
        ("avx512vbmi2", is_x86_feature_detected!("avx512vbmi2")),
        ("sha", is_x86_feature_detected!("sha")),
        ("sha512", is_x86_feature_detected!("sha512")),
    ];
    let has = |name| cpuid.iter().any(|&(n, v)| n == name && v);

    let avx512_aes_gcm = ["avx512f", "avx512bw", "avx512vl", "vaes", "vpclmulqdq"]
        .into_iter()
        .all(has);

    let cpuid = cpuid
        .iter()
        .map(|(name, v)| format!("\"{name}\": {}", *v as u8))
        .collect::<Vec<_>>()
        .join(", ");
    println!(
        "{{ \"cpuid\": {{ {cpuid} }}, \"supports_avx512_aes_gcm\": {} }}",
        avx512_aes_gcm as u8,
    );
}

#[cfg(target_arch = "aarch64")]
fn main() {
    use std::arch::is_aarch64_feature_detected;

    let aes = is_aarch64_feature_detected!("aes");
    let dit = is_aarch64_feature_detected!("dit");
    let neon = is_aarch64_feature_detected!("neon");
    let pmull = is_aarch64_feature_detected!("pmull");
    let sha2 = is_aarch64_feature_detected!("sha2");
    let sha3 = is_aarch64_feature_detected!("sha3");
    let sve2 = is_aarch64_feature_detected!("sve2");

    println!(
        "{{ \"cpuid\": {{ \"aes\": {}, \"dit\": {}, \"neon\": {}, \"pmull\": {}, \
        \"sha2\": {}, \"sha3\": {}, \"sve2\": {} }} }}",
        aes as u8, dit as u8, neon as u8, pmull as u8, sha2 as u8, sha3 as u8, sve2 as u8,
    );
}
