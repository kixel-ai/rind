# [M] AES-GCM of 2^32 bytes and more is proven on the Vale tier

## Goal

On x86_64 with AVX and MOVBE but no VAES, AES-GCM's proof covers every input rind accepts, not only AAD and messages under 2^32 bytes, so the report's ✓ on that tier holds without a size caveat.

## Plan

The Vale glue's proof ([moq-dev/rind#344](https://github.com/moq-dev/rind/pull/344)) stops at 2^32 bytes, where rind falls back to its unproven by-8 code because Vale's routines take 32-bit lengths.

- Prefer keeping Vale for long inputs: call its routines on chunks below 2^32 bytes with the counter and GHASH state carried across, if its contracts allow resuming, and prove the chunking. That deletes the by-8 fallback on this tier.
- Otherwise prove the by-8 path, or ask the maintainer whether to refuse such inputs there. Refusing breaks AES-GCM's 2^36 - 32 byte limit, which aws-lc-rs accepts.
- Long inputs are rare, so their speed matters less than the common sizes, but measure them against today's path anyway.
