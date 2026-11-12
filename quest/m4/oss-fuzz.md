# [S] rind runs in OSS-Fuzz

## Goal

rind's `fuzz` crate targets run continuously in OSS-Fuzz, with crashes reported to the maintainer, and its coverage shows on OSS-Fuzz's dashboard.

## Waiting

- Maintainer: post the google/oss-fuzz PR adding `projects/rind` from `fuzz/oss-fuzz/` (outside the moq-dev and kixelated orgs); its drafted body is in this quest's moq-dev/rind PR. `primary_contact` must be a Google account to see crashes. Check `gh pr list --repo google/oss-fuzz --search rind`.

## Plan

- ✅ `fuzz/oss-fuzz/` holds `project.yaml`, `Dockerfile`, and `build.sh`; OSS-Fuzz's `helper.py` builds all 20 targets under ASan and coverage and passes `check_build`.
- Draft the google/oss-fuzz PR and its stated criticality, and show it to the maintainer before posting it.
- This was one of three children of an assurance epic (maintainer, 2026-11-07). On 2026-11-09 the maintainer chose ✅ ACVP to m2 and cryptofuzz deleted (rejected: retarget cryptofuzz at MozillaSecurity's fork, leave both in m4): ACVP is static vectors that need no outside approval, and cryptofuzz's upstream, guidovranken/cryptofuzz, is gone, with OSS-Fuzz's own cryptofuzz project disabled. Don't plan cryptofuzz again without a maintained upstream.
