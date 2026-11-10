# [XS] rind-dart and pyrind say plainly that they do not wipe

## Goal

rind-dart's and pyrind's READMEs and comments say that the bindings do not wipe keys, which is what their binaries do. Today rind-dart says it wipes keys and never does, and pyrind says so only obliquely. rind-dart 0.1.0 does not publish with the false sentence.

## Plan

Found by the 2026-11-09 API and hostile-input audit. Decided with the maintainer the same day: ✅ fix the docs only (rejected: both bindings enable `rind/wipe`; fix the docs now and plan wiping for later). Few binding users would care about wiping itself: the `bytes` or `Uint8List` a key is loaded from stays unwiped in managed memory anyway, and rind's own default is not to wipe. What a reviewer does care about is a false security claim. Add wiping only when a consumer asks for it.

The evidence:

- rind wipes only under its `wipe` feature, which is off by default: `zeroise` and `zeroise_value` do nothing without it (`rind/src/low/generic/zeroise.rs:13-24`).
- rind-dart depends on rind with default features (`rind-dart/Cargo.toml:18`), and its build hook passes cargo no `--features` (`rind-dart/hook/build.dart:50-61`). So no Dart build wipes anything.
- rind-dart says otherwise in three places: "Keys live in native memory, which rind wipes when Dart collects them" (`rind-dart/README.md:88`), "dropping one wipes it as rind does" (`rind-dart/src/lib.rs:7`), and "Drops the handle, wiping what it holds" (`rind-dart/src/lib.rs:154`).
- pyrind depends on rind the same way (`rind-python/Cargo.toml:24`), and maturin builds its wheels with no features (`sh/python.sh:18`). Its README is accurate but easy to misread: "pyrind wipes keys and keyed state when Python frees them exactly when rind does, through rind's own drops; the wheels build rind with its default features" (`rind-python/README.md:111-113`). That means never.

Each README says it in one plain sentence, and names what a user who needs wiping can do today: nothing in the binding, so use rind from Rust with `wipe`.

If wiping is ever added, the audit also found heap copies the bindings make that would then need wiping: rind-dart copies caller bytes into `malloc` memory and frees it unwiped (`rind-dart/lib/src/ffi.dart:56-62`), which holds an RSA private key's DER when one is loaded, and pyrind's `copy_buffer` copies any argument that is not `bytes` into a `Vec<u8>` (`rind-python/src/lib.rs:111`).

## Related

- [rind for Dart installs without a Rust toolchain](/quest/m2/adoption/rind-dart-prebuilt.md) - builds the binaries these docs describe
