#[cfg(feature = "__bench_codspeed")]
pub use codspeed_criterion_compat::*;
#[cfg(not(feature = "__bench_codspeed"))]
pub use criterion::*;

/// Message sizes for ciphers and AEADs: a short token, QUIC datagrams at and
/// near the common 1200- and 1350-byte MTUs, and a full TLS record.
#[allow(dead_code)]
pub const SIZES: [(usize, &str); 4] = [
    (32, "32B"),
    (1200, "1200B"),
    (1350, "1350B"),
    (16384, "16KB"),
];

/// [`SIZES`], plus one hash block and a file-sized input, for hashes and MACs.
#[allow(dead_code)]
pub const HASH_SIZES: [(usize, &str); 6] = [
    (32, "32B"),
    (64, "64B"),
    (1200, "1200B"),
    (1350, "1350B"),
    (8192, "8KB"),
    (16384, "16KB"),
];

/// rind's rows: `rind`, then, on an Apple CPU with DIT, `rind-dit-held` with a
/// [`rind::cpu::Dit`] guard for the caller to hold while timing it, as a
/// caller batching calls would. Elsewhere the guard does nothing, so the row
/// would repeat `rind`'s.
#[allow(dead_code)]
pub fn rind_rows() -> impl Iterator<Item = (&'static str, Option<rind::cpu::Dit>)> {
    #[cfg(all(target_arch = "aarch64", target_vendor = "apple"))]
    let dit = std::arch::is_aarch64_feature_detected!("dit");
    #[cfg(not(all(target_arch = "aarch64", target_vendor = "apple")))]
    let dit = false;
    // Lazily, so that the guard is taken only once `rind`'s row is timed.
    let held = dit.then_some(()).into_iter();
    std::iter::once(("rind", None))
        .chain(held.map(|()| ("rind-dit-held", Some(rind::cpu::Dit::hold()))))
}
