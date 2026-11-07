# [XS] The bench report times rind with the DIT guard held

## Goal

On a CPU with DIT, the bench report shows rind both as it runs by default and with `rind::cpu::Dit::hold()` held across the timed loop, so readers see what MoQ, which holds the guard, actually pays.

## Plan

Decided with the maintainer on 2026-11-07, from [moq-dev/rind#435](https://github.com/moq-dev/rind/pull/435): `kixtop` (Apple M4) showed rind behind on 19 short-message rows (short AES-GCM, header protection, SHA-2, HMAC, HKDF). It sets DIT on and off around every call that handles a secret, which costs about 35-55 ns, and no other library sets DIT. With DIT off, all but two of those rows came within 10%. [moq-dev/rind#431](https://github.com/moq-dev/rind/pull/431) added the guard, but skipped a held case because no report host had DIT.

- Add a held series for rind (for example `rind (DIT held)`) to the `rind-bench` groups those rows come from, timed only where the CPU has DIT. Elsewhere the guard does nothing, so it would just duplicate the default row.
- Show it in `BENCHMARKS.md`'s `kixtop` column next to the default row, and say in the gap reasons (`benchmarks/gaps.toml`) that holding the guard closes them.
- `kixtop` is the only report host with DIT. GitHub's Cobalt runners hide it. Collect with `admin/bench-report collect --host kixtop` in a quiet window. The [quiet re-collect](/quest/m1/bench-apple-m4.md) carries the new rows if this lands first.
