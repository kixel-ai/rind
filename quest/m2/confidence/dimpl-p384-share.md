# [S] rind-dimpl accepts the P-384 key shares aws-lc-rs accepts

## Goal

rind-dimpl's P-384 key exchange accepts or refuses a peer's share exactly as dimpl's aws-lc-rs provider does, so `fuzz/fuzzer/dimpl.rs`'s `key_share` check passes and the weekly `fuzz` run's `Fuzz dimpl` job is green again.

## Plan

Found on 2026-11-14 by `fuzz.yml`. Both main's scheduled [run 43525080590](https://github.com/kixel-ai/rind/actions/runs/43525080590) and [run 43530778796](https://github.com/kixel-ai/rind/actions/runs/43530778796), dispatched from [kixel-ai/rind#743](https://github.com/kixel-ai/rind/pull/743), fail at `fuzz/fuzzer/dimpl.rs:231` with `Secp384r1`: rind refuses a share that aws-lc-rs accepts (`left: false`, `right: true`). The 23-byte input reproduces it every time with main's x86_64 fuzz binary:

```
09a0ff97fbffffff970100000340002b01db0d250c0c06
```

(`xxd -r -p` rebuilds it). Decode which share the input builds before choosing a side. If aws-lc-rs accepts an encoding that rind's own P-384 agreement refuses as hostile, such as a compressed or otherwise non-canonical point, decide by AGENTS.md's rule (follow aws-lc-rs) and by what dimpl's DTLS peers send. If the harness built a share that only one side should see, fix the harness instead. Either way, add the input to the target's seeds so the corpus keeps it.
