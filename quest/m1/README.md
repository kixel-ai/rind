# m1: MoQ coverage and Bun

## Goal

rind carries everything [MoQ](https://github.com/moq-dev/moq) needs to take
all its cryptography from rind, on every target MoQ releases, and publishes it.
Bun's fastest asymmetric operations run on rind, ahead of Bun writing its own.

## Required

- [Bun runs its fastest asymmetric crypto on rind](/quest/m1/bun.md) - Ed25519, X25519, P-384, and P-521 in Bun on rind, before Bun writes its own
- [The launch post can say what building rind cost in AI tokens, time, and money](/quest/m1/ai-usage.md) - tokens, agent and maintainer hours, and API-price cost, before the post
- [rind's launch blog post is published](/quest/m1/launch-post.md) - the Bun PR waits on it
- [The bench report has a quiet Arrow Lake run and kixtop's build cost](/quest/m1/bench-apple-m4.md) - a fresh desktop column and M4 build costs before the launch post
- [rind-jsonwebtoken and rind-instant-acme check the CPU themselves](/quest/m1/adapter-cpu-check.md) - `default_provider()` like the other adapters, before 11.0.0 publishes
- [rind-rcgen users don't depend on rind directly](/quest/m1/rcgen-helpers.md) - `check()` and `serial_number()` helpers
- [rind covers MoQ](/quest/m1/moq/README.md) - the primitives, CPU check, armv7 backend, and `rind-*` adapters MoQ needs, verified and released
