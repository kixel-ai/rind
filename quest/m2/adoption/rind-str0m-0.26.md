# [S] rind-str0m supports str0m 0.26

## Goal

A published rind-str0m 0.26.x is a `CryptoProvider` for str0m 0.26, offering exactly the API str0m's own `str0m-aws-lc-rs` provider offers there, so its users get str0m 0.26's fixes: the TWCC and VLA overflows and zero-length runs that panicked or misparsed, port-0 ICE candidates ignored, and conflicting SDP mappings warned and ignored instead of panicking.

## Plan

Found by the 2026-11-28 [upstream-updates](/quest/m2/upstream-updates.md) run. str0m 0.26.0 shipped on 2026-11-22; its breaking change is the `color-space` RTP header extension (#1135), which does not touch the crypto provider, so the adapter's own change may be only its versions.

- Bump `rind-str0m`'s `str0m` requirement to 0.26 (and its `str0m-aws-lc-rs` dev-dependency to the release built on 0.26, if one has shipped past 0.7.0, the newest on 2026-11-28), and the crate to 0.26.0, as `sh/adapter-versions.sh` requires; the fuzz crate's `str0m` follows.
- `admin/adapter-api` diffs the adapter's API against `str0m-aws-lc-rs`; follow it.
- Whether to keep a 0.25.x maintenance line is the maintainer's call at the time; ask with what each costs.

## Scheduled

- 2026-11-29 - str0m 0.26.0 clears Dependabot's 7-day cooldown
