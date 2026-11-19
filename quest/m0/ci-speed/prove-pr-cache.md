# [M] Pull requests re-check only the proofs whose inputs changed

## Goal

On a pull request, `prove.yml` reruns a HOL Light proof only when its object bytes, its proof file, or rind's s2n-bignum fork changed since a run that passed. It runs `admin/prove cosim` only when the fork's instruction-model files or the AArch32 model changed. The nightly run still checks everything.

## Plan

Decided with the maintainer on 2026-11-18 (/quest-plan): ✅ cache each HOL Light result and scope cosim (rejected: run everything on every pull request). Why: in the 30 hours from 2026-11-17 12:00 UTC, pull requests spent about 327 hosted machine-hours on `prove` (143 runs). Per run, `hol-light-aarch64` averaged 50 minutes, `hol-light-x86_64` 35, `cosim` 26, `lean` 25, and `hol-light-armv7` 10. Most of those pull requests changed no proven assembly, and none changed the models cosim checks.

- Key each proof's result on a hash of the object `admin/prove` extracts (the bytes, the relocations, and the read-only data they reach), the `.ml` file, and the fork's tree. A cache hit must still run `admin/prove bytes`, which is cheap and checks that the build emits those bytes. The pull request builds rind anyway, so extract first, then skip the proof on a hit.
- Store the keys where a pull request from a fork cannot write them, such as an artifact or the Actions cache from `main`'s nightly run only. A pull request may read the cache but never populate it, so a malicious pull request cannot plant a passing result.
- The Lean job stays as it is: Lake already rebuilds only the modules that changed.
- Give the per-run machine time before and after in the PR, as the epic does.
