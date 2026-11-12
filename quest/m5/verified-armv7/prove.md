# [L] armv7's Rust AES-GCM and SHA are proven

## Goal

armv7's remaining Rust-only paths earn the ✓: AES-GCM without the crypto extension, and SHA-256 and SHA-1 without it unless [moq-dev/rind#620](https://github.com/moq-dev/rind/pull/620) replaces that Rust with aws-lc's assembly.

## Plan

- `admin/prove`'s `extract_armv7` translates armv7 into `proofs/Rind/Armv7/`, so far from the header-protection API alone, whose ChaCha20 already earns the ✓: add the AEAD and digest APIs' start-froms, and to `Rind/Armv7/{Types,Funs}External.lean` what they leave opaque.
- AES-GCM without the crypto extension runs rind's ports of aws-lc's `aes_nohw.c` (`low/generic/aes_nohw.rs`, in 32-bit words) and `gcm_nohw.c`: prove both with Aeneas. [x86_64 without AES-NI](/quest/m5/verified/x86-no-aesni.md) proves the same file in SSE2 words, so whichever lands first states the circuit's proof over the word operations both widths share.
- SHA-256 and SHA-1 without the crypto extension run Graviola's and rind's portable Rust (`low/generic/sha256.rs`, `sha1.rs`): prove them with Aeneas against FIPS 180-4. If #620 lands first, they run aws-lc's NEON and integer assembly instead, which [armv7's assembly](/quest/m5/verified-armv7/assembly.md) proves, and this bullet goes.
- ML-KEM's portable arithmetic is [its own quest](/quest/m4/verified/mlkem-portable.md); its Keccak-f is assembly, in [armv7's assembly](/quest/m5/verified-armv7/assembly.md).
- Poly1305 without NEON is libcrux's HACL\*-compiled Rust, which `benchmarks/verified.toml` counts, under rind's glue.
