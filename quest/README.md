# rind questline

## Goal

Keep rind's living work organized as visible, versioned quests, grouped into
milestones ordered by priority.

## Plan

m0 holds urgent fixes: security advisories, broken CI, anything that breaks
MoQ on a published rind, and a published adapter that diverges from its
upstream. m1 is everything MoQ needs from rind to drop C
cryptography, ending in the release MoQ switches to. m2 holds work that
follows that release: the API audit's fixes, adoption beyond MoQ, and the
checks, measurements, and proof groundwork that keep rind correct and fast.
m3 holds work deferred by priority or waiting on the outside world. m4 holds
long-term work: C and regulated deployments, post-quantum and protocol
building blocks, and a proof of every hot path. m5 holds the cold tiers'
proofs.

## Required

- [m0: immediate priorities](/quest/m0/README.md) - urgent fixes and breakage on a published release
- [m1: MoQ coverage](/quest/m1/README.md) - every primitive, backend, and adapter MoQ needs, released
- [m2: later work](/quest/m2/README.md) - follow-ups to the release MoQ switches to
- [m3: deferred](/quest/m3/README.md) - gated on the outside world, or speculative with no named consumer
- [m4: long-term](/quest/m4/README.md) - an OpenSSL provider, FIPS 140-3, post-quantum, protocols, and every hot path proven
- [m5: cold tiers](/quest/m5/README.md) - proofs of armv7 and the legacy and fallback tiers
