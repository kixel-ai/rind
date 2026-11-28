# [L] Split charon/aeneas Funs.lean per algorithm family, parallelize, and cache

## Goal

Break `rind`'s monolithic per-architecture `proofs/Rind/<Arch>/Funs.lean` rebuild cascade by splitting `charon`/`aeneas` extractions into per-algorithm-family namespaces, running extractions in parallel, and caching extracted `{Types,Funs}.lean` artifacts by input hash, so editing one Rust algorithm only invalidates that algorithm's Lean proofs rather than every proof on the architecture.

Non-goals: changing any proven Rust semantics, weakening Aeneas translation checks or axioms, or altering proof coverage.

## Plan

Decided 2026-11-27 (maintainer, `/quest-plan`):
- ✅ Place in `m2`: per `quest/README.md`, `m2` holds proof groundwork that keeps `rind` correct and fast; this is a larger structural refactor (`[L]`) that complements `m0`'s cache work without blocking MoQ's `m1` switch.
- ✅ Split `charon`/`aeneas` extractions into per-algorithm-family namespaces (following `extract_kdf`'s existing pattern) AND parallelize and cache extractions, migrating incrementally family by family without breaking existing proofs (rejected: parallelizing and caching the monolithic `Funs.lean` files without splitting them per family, which still invalidates all proofs on an architecture on any 1-line Rust edit).

Baseline (2026-11-27):
- `admin/prove:1752-2023` runs 5+ `charon` + `aeneas` extractions serially (`X86_64`, `Aarch64`, `X86_64/Kdf`, `Aarch64/Kdf`, `Armv7`, plus `Portable` and `dalek`), and `to_lean` clobbers a single `$out/lean` scratch directory so extractions cannot overlap.
- Because `X86_64/Funs.lean` and `Aarch64/Funs.lean` each hold the entire translated Rust surface for that arch, editing a single Rust function (for example in `mlkem`) regenerates the whole `Funs.lean` and forces Lake to re-elaborate every downstream proof module for that architecture (AES-GCM, SHA-2, SHA-3, ChaCha20, P-256, P-384, RSA, Ed25519, ML-KEM).

Approach:
1. **Parallelize and content-address `charon`/`aeneas` extractions:**
   - Give each `to_lean` / `extract` / `extract_kdf` / `extract_armv7` invocation its own scratch directory under `$out/lean-<name>` (and per-target `CARGO_TARGET_DIR` isolation where needed) so all extractions run concurrently.
   - Cache extracted `{Types,Funs}.lean` artifacts locally (and optionally against the shared cache from [kixel-ai/rind#1138](https://github.com/kixel-ai/rind/pull/1138)), keying on every input that affects translation: `charon_path`, `rustc -vV`, `aeneas -version`, extraction flags, target triple and effective target/cfg configuration (including `RUSTFLAGS` / `CARGO_ENCODED_RUSTFLAGS`), `.cargo/config.toml`, root and crate `Cargo.toml` manifests, `Cargo.lock`, `rind/build.rs`, `rind/src/**` (and any local/vendored path crates Charon traverses), and `admin/prove`'s extraction/post-processing steps. Preserve file mtimes when generated outputs are byte-identical so Lake never sees spurious dirty timestamps.
2. **Split monolithic `X86_64` and `Aarch64` extractions by algorithm family:**
   - Following `extract_kdf`'s proven pattern (`proofs/Rind/<Arch>/Kdf/{Types,Funs}.lean` + `{Types,Funs}External.lean`), split independent algorithm families out of the monolith into their own namespaces (such as `MlKem`, `Rsa`, `P256`/`P384`/`Ecdsa`, `Ed25519`/`X25519`, `Aes`, `ChaCha`, `Sha`).
   - Keep shared foundational primitives (e.g., `Error`, `low::ct`, core hash contracts) in a small shared base extraction or opaque boundary so families do not duplicate heavy definitions, and preserve `admin/prove`'s global-name isolation invariant.
   - Migrate incrementally so every commit keeps full `admin/prove lean` green with identical theorem statements and zero new axioms.
3. **Measure impact:**
   - Measure before/after `admin/prove lean` wall time and CPU seconds for:
     - a clean/unchanged Rust run (testing extraction parallelization + caching), and
     - a 1-line edit inside a single algorithm (e.g., `rind/src/mid/mlkem.rs`), reporting how many of the 261 Lean modules re-elaborate before vs after.

Progress (2026-11-28, [kixel-ai/rind#1182](https://github.com/kixel-ai/rind/pull/1182)):
- Landed: ML-KEM is a family of its own on x86_64 and aarch64 (`extract_family`, `family_lean`, `proofs/Rind/X86_64/MlKem/{Types,Funs}External.lean`, written for aarch64 too). Every translation runs Aeneas at once, each in its own `$out/lean-<name>`, and installs only what changed. Each family is its own `aeneas_cached` entry, so it shares through whatever store `cached` reads, [kixel-ai/rind#1180](https://github.com/kixel-ai/rind/pull/1180)'s included, with no key of its own.
- Measured on a 24-core host shared with other agents: a one-line comment in `rind/src/mid/mlkem.rs` took `admin/prove lean` from 14:19 wall and 4,114 CPU-s, rebuilding 203 Lean modules (both targets' `Funs` and everything above them), to 6:08 and 734 CPU-s, rebuilding 16 (the two ML-KEM translations, their proofs, and `Axioms`). Up to the end of `lake build`: 602 s to 112 s. An unchanged run: 4:49 to 4:27. About 4 of those minutes, in every run, are `SimdVectors.lean`'s check, which [its quest](/quest/m2/simd-vectors-cache.md) caches.
- Charon still runs for every translation, about 5 s each once its target directory is warm, taking turns on Cargo's lock while Aeneas runs.
- Next, roughly by payoff: Ed25519 (its 1,024-word tables elaborate in the target's `Funs`), P-256 and P-384 with ECDSA (their generator tables, the largest literals there), RSA (x86_64 and portable, on the critical path [kixel-ai/rind#1176](https://github.com/kixel-ai/rind/pull/1176) measured), AES and AES-GCM, ChaCha20 and ChaCha20-Poly1305, and SHA-3's sponge, which ML-KEM reaches from the target. The hashes, HMAC, and the error types stay in the target's translation, which every family reaches.
- What the next family will meet, as ML-KEM did:
  - Items only the family reached leave the target's translation and come with the family, such as `core.marker.PhantomData` and `ct_copy` for ML-KEM. One two families share must stay in the target's: start it from there.
  - The family translates the error types, whose constructors it builds, and `family_lean` drops each declaration the target makes word for word, since two siblings' `@[discriminant]` instances would take the same global name (`instDiscriminantKeyFormatErrorIsize_1`, with HKDF's).
  - A constant the target translates as a value, the family, which leaves it opaque, reads as a computation: its `FunsExternal` gives it with a `@[step]` spec, and a proof stepping over it takes one more `step` (`SHAKE_PAD_BYTE`).
  - Hand models (`Dispatch`, `EcdsaDispatch`, `RsaDispatch`, and the like) build on the target's translation, and a translation cannot call a model built on itself, so a family whose Rust calls a model needs its own pass above that model, as HKDF's does. `S2nBignum.lean` states axioms about translated wrappers in `low::<arch>::adx_mux`, which Ed25519 and the curves call: they stay in the target's translation.
  - The proofs `open rind.<arch>.<family>`; the target's names win over the family's where both exist.

## Related

- [Aeneas translation cache and SSH-shared Lake outputs](https://github.com/kixel-ai/rind/pull/1138) - shared cross-host cache work
- [Build spec-server once in prove.yml and add scoped admin/prove lean targets](/quest/m0/spec-server-single-build.md) - scoped `admin/prove lean <Module>` runs
- [Spike and benchmark Lean 4.35 speedup levers on rind's proof corpus](/quest/m2/lean-speed-spikes.md) - `module` system and tactic profiling
- [rind's HOL Light proofs are ported to Lean](/quest/m5/verified/hol-light-to-lean.md) - will add ~19.7k more lines of Lean proofs benefiting from split extractions
- [admin/prove caches the intrinsic vectors' check](/quest/m2/simd-vectors-cache.md) - the four minutes every run spends after the split's rebuild
