# [S] In-place assembly calls derive both pointers from one mutable borrow

## Goal

Every call that passes the same buffer to an assembly routine as both input and output takes both pointers from a single `as_mut_ptr()`, so no pointer is invalidated under Rust's aliasing rules before the routine reads it. Today some take the input from `as_ptr()` and then the output from `as_mut_ptr()`. Under Stacked Borrows, the second reborrow invalidates the first pointer. This covers the x86_64 and aarch64 wrappers and `low/ct.rs`.

## Plan

- Found in [kixel-ai/rind#913](https://github.com/kixel-ai/rind/pull/913) by CodeRabbit. That PR fixed only the armv7 wrappers it added (`rind/src/low/arm/vpaes_armv7.rs` and its siblings); follow their pattern.
- Find the in-place call sites, where one slice yields both pointers, in `rind/src/low/x86_64/`, `rind/src/low/aarch64/` and `rind/src/low/ct.rs`. Leave calls with distinct input and output buffers alone.
- No behavior or speed change is expected; the assembly can't observe the difference. Miri doesn't run the assembly, so there's no test to add. State the call sites changed in the PR.
