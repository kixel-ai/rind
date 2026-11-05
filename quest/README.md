# rind questline

## Goal

Keep rind's living work organized as visible, versioned quests, grouped into
milestones ordered by priority.

## Plan

m0 holds urgent fixes: security advisories, broken CI, and anything that
breaks MoQ on a published rind. m1 is everything MoQ needs from rind to drop C
cryptography, ending in the release MoQ switches to. m2 holds work that
follows that release, including adoption beyond MoQ. m3 holds external
conditions and speculative work. m4 holds long-term work that takes rind
into C and regulated deployments.

## Required

- [m0: immediate priorities](/quest/m0/README.md) - urgent fixes and breakage on a published release
- [m1: MoQ coverage](/quest/m1/README.md) - every primitive, backend, and adapter MoQ needs, released
- [m2: later work](/quest/m2/README.md) - follow-ups to the release MoQ switches to
- [m3: deferred](/quest/m3/README.md) - gated on the outside world, or speculative with no named consumer
- [m4: long-term](/quest/m4/README.md) - an OpenSSL provider and FIPS 140-3, after adoption
