# [S] AES-GCM's partial AAD block costs no more than a full one on VAES CPUs

## Goal

On x86_64 CPUs with VAES, AES-GCM's non-Vale path hashes a partial AAD block, such as QUIC's 13 B short header, about as fast as a full one, so short seals and opens stop paying for it and the Vale crossovers can be re-measured.

## Plan

[moq-dev/rind#391](https://github.com/moq-dev/rind/pull/391) moved short opens, and short seals on VAES-AVX2, to Vale's kernel. Measuring it showed the old path spends about 12 ns on a partial AAD block: on Arrow Lake a 32 B seal took 30.7 ns under a 13 B AAD against 18.3 ns under a 32 B one. Decided with the maintainer on 2026-11-06: plan it as an m1 speed quest, since every QUIC and TLS record has a partial-block AAD. For bulk encryption the fastest source wins outright, with no tie margin for verified code. Find where the time goes (the tail's load and padding, or a separate GHASH call), fix it, then re-measure #391's crossovers (opens under 256 B, seals under 80 B on VAES-AVX2, none on AVX-512) and move them if the old path now wins. Measure on `desktop` (Arrow Lake), `nixos` (Zen 3), and GitHub's AVX-512 runners, comparing only matching `CPU:` lines.
