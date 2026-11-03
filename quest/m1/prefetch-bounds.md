# [XS] The x86_64 prefetch helper is sound for any stride

## Goal

`low::x86_64::cpu::prefetch` is a safe function with no undefined behavior for any `stride`, so a future caller can't introduce an out-of-allocation pointer through it.

## Plan

Planned with the maintainer on 2026-11-03 from an external audit. It computes `table.as_ptr().add(stride)`, which is undefined behavior when the result leaves the allocation, though every current caller stays in bounds. Prefetching an address never faults, so compute it with `wrapping_add` and fix the doc comment.
