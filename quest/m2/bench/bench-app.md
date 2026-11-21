# [M] A bench app anyone can run, and the decisions to ship it

## Goal

`admin/bench-app` gives a contributor one command that times rind against aws-lc-rs and ring on their own host, scrubs the result, and writes a host JSON that `admin/bench-report render --from DIR` imports and `render --check` accepts, so every new host reaches `BENCHMARKS.md` the same way. It is a command line tool only, with no server part.

## Plan

- Base: `admin/bench-app`, a script beside `admin/bench-report` that loads it as a module and reuses its host fields, machine tag, toolchain check, operation IDs, and schema. It builds `rind-bench`'s existing criterion benches once and runs the binaries directly; it adds no crypto, no dependency, and no C library.
- Prerequisite: the app calls `admin/bench-report` functions that `main` lacks (`cpu_metadata`, `machine_identity`, `machine_tag`, `resolve_host`, `try_output`, `unmeasured`: the CPU slug as host name and the machine tag). They land first, in the same PR or a smaller one before it.
- Suite: 12 report operations that rind, aws-lc-rs, and ring all have rows for (aes128-gcm, chacha20poly1305, and sha256 at 1350 B; x25519; ed25519 sign and verify; p256 ECDH; ECDSA sign and verify) plus ML-KEM-768 encaps and decaps, which ring lacks.
- Rounds: 7 by default and at least 5, every library each round, the bench order rotated per round, each round in its own criterion home, pinned to the fastest, highest numbered core where the OS allows. Before and after every round it records the core's governor, the temperature, and the throttle state (`vcgencmd get_throttled` on a Raspberry Pi, `thermal_throttle` counters on x86 Linux, `pmset -g therm` on macOS). Other load on the machine is recorded, not refused.
- Verdict: a round that throttled is dropped, and while the aws-lc-rs control spread (each row's slowest round over its fastest) is above 1.02, the round furthest from the control medians is dropped. The run is `ok` when at least 5 rounds are left, and each time is then their median. Otherwise it is `noisy` with the reason, and `render` skips it.
- Scrubbing: home and Windows user paths, user name, host names, wifi names, emails, MAC, IPv4 and IPv6 addresses, UUIDs and Apple UDIDs, and tokens (GitHub, GitLab, Slack, AWS, `sk-`, JWT) never leave the host. The scrub re-checks its output and writes nothing if a value it was told to remove survives.
- Output: `<host>.json` in `.tmp/bench-app/` by default. The app only writes the file; sending it anywhere is the contributor's step, decided under Waiting.
- CI: `sh/dispatch.sh`'s bench module also covers `admin/bench-app`, and `check:bench` runs `admin/bench-app-test`.
- `python3 admin/bench-app-test` passes: planted leaks (paths, user and host names, addresses, tokens), the verdict rule, throttle parsing for each source, and the round trip through `render --from` and `render --check`.
- `admin/bench-report render --check`, `python3 admin/testing`, `quest check`, and `python3 admin/audit check` pass.
- One run on at least two hosts of different CPUs, each with its CPU model and verdict in the PR body, and a Raspberry Pi and a Mac run once those hosts are reachable.
- `CI_STRICT=1 quest gate sh/dispatch.sh ci origin/main` passes: `sh/dispatch.sh` changes, so dispatch runs every module.

## Waiting

Each item opens with who acts. Options are lettered, the recommendation first.

- Maintainer: where results live. (a) Contributors open a PR to `rind-results` with the app's output, as #76 to #78 did. (b) The app fills a GitHub issue form. (c) It only prints; contributors paste. Recommended: (a), because the review, scrubbing, and host-slug checks already live there.
- Maintainer: trust. The report accepts self-reported timings. (a) Keep community rows out of README, in a separate table, until a host has a second independent run. (b) Accept them as labelled, with the control spread and throttle state beside each row. (c) Require a CI re-run before a row reaches README. Recommended: (a).
- Maintainer: which hosts reach the report. (a) Add a host only by a maintainer-approved PR; the app only proposes the slug. (b) Let the app register a slug by itself. Recommended: (a).
- Maintainer: noise policy. (a) Accept a run only when the aws-lc-rs control stays within 1.02, no throttle bit is set in the rounds kept, and at least 5 interleaved rounds are left. (b) Accept any run with the values shown. Recommended: (a), which the app enforces today.
- Maintainer: privacy. Confirm the scrub list above is enough, and that scrubbed results may be committed to `rind-results`.
- Maintainer: hosting. (a) None; the app is a CLI. (b) A GitHub Pages view generated from `rind-results`. (c) A service. Recommended: (a); (b) later if wanted, since (c) needs an owner, a budget, and an on-call.
- Maintainer: release. (a) `admin/bench-app` is a script, never published, and runs from the repository. (b) Publish it by hand once (CONTRIBUTING.md Releases). Recommended: (a).
- Maintainer: dependencies. It adds none: Python's standard library and the crates `rind-bench` already uses. Confirm `deny` needs no change.
- Maintainer: review (draft, `REVIEW_REQUIRED`).
- Not an owner call: the Raspberry Pi and macOS runs have not happened (no reachable Pi with a Rust toolchain, no Mac with disk to build on); the macOS `pmset` parser is unit tested only. The strict CI gate has not run on the implementation.
