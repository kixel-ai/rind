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
- [The bench report times rind with the DIT guard held](/quest/m1/bench-dit-held.md) - shows what MoQ pays on DIT cores, before the post
- [Each adapter's version matches the upstream it adapts](/quest/m1/adapter-versions.md) - rind-ring 0.17, rind-rustls 0.23, and so on, before the post quotes them
- [rind covers MoQ](/quest/m1/moq/README.md) - the primitives, CPU check, armv7 backend, and `rind-*` adapters MoQ needs, verified and released
