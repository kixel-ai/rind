# [XS] Every LICENSE rind ships lists the third-party code it carries

## Goal

The LICENSE copies in `rind-aws-lc-rs/`, `rind-openssl/`, `rind-dart/`, and `rind-dart/cryptography/`, which ship rind's code inside their packages, list every source the root LICENSE lists for the code they carry, and a check in `just ci` fails when a copy drifts.

## Plan

Found by the 2026-11-28 [upstream-updates](/quest/m2/upstream-updates.md) run: `rind-python/LICENSE` matches the root's byte for byte, but the other four lack the pyca/verified-garbage entry entirely, and aws-lc's newer entries (the ported C SHA-2 block functions, the x86_64 ChaCha20-Poly1305 copies), while each still names the current pins, so the previous runs' pin edits reached them but no new entry did.

- Find why each copy differs (rind-dart's adds the Dart package's own sources), then either generate the copies from the root plus each package's additions, or have `admin/scan-license` compare them, whichever is less code.
