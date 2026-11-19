# [XS] dudect is removed; Marvin stays

## Goal

`admin/timing dudect`, its dev shell, and its job in the weekly `timing` workflow are gone. The Marvin toolkit's run against RSA decryption stays, and TESTING.md and AUDIT.md describe what remains.

## Plan

Decided with the maintainer on 2026-11-18 (/quest-plan): ✅ drop dudect (rejected: keep it). The reason is noise, not cost (about an hour a day). It is statistical on shared runners, no commit in the history shows it finding anything, and ctgrind, BINSEC, `admin/ct-sde`, `admin/ct-qemu`, and `admin/ct-vartime` check the same property deterministically. Marvin stays because RSA decryption's timing is where real attacks have landed, and it checks the whole call path, the C ABI and adapters included.

- Remove whatever only dudect uses: its flake shell, harness code, and `timing.yml` steps. Keep `rind-timing` if Marvin still needs it.
