# [S] HOL Light sessions start from a checkpoint

## Goal

A repo helper starts an interactive HOL Light session with s2n-bignum's `base.ml` for an architecture already loaded, restored in seconds from a checkpointed image built once per architecture and set of inputs, so agents developing proofs stop reloading the model and stop building REPL servers of their own. `admin/prove` keeps compiling the proofs natively.

## Plan

Decided with the maintainer on 2026-11-12, from read-only audits of the maintainer's agent hosts: ✅ a checkpointed session image after `base.ml` loads, once per architecture, shipped as a repo helper.

- The cost: each session reloads `base.ml`, which agents estimate at 2 to 20 minutes, single-threaded and peaking at 19.6 GB. Gated sessions took 4.3 CPU-h in 1.8 days, and agents built REPL servers (`holserver.sh`, `send.sh`) that run outside `quest gate`.
- Checkpoint with DMTCP or CRIU, both in nixpkgs, as HOL Light's README describes. DMTCP is recommended: it runs unprivileged, and HOL Light's `make-checkpoint.sh` already loads a statement such as `needs "x86/proofs/base.ml"` before checkpointing, while CRIU needs privileges and selfie, HOL Light's third option, is not packaged.
- The session sees what `admin/prove hol-light` checks: the same load path, with `proofs/hol-light/s2n-bignum/` and the patched x86 model ahead of the submodule. Key each image by HOL Light's store path, the submodule's commit, and those carried files, keep it outside the worktree so worktrees on the same inputs share it, and build it under `quest gate`.
- Let an agent run a file in a restored session and read the output without a server, if restore is fast enough; record the image's size and restore time.
- Name the helper in `proofs/README.md`'s HOL Light section, where agents writing proofs look.
