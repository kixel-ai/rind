# [S] librespot builds rustls without ring

## Goal

[librespot](https://github.com/librespot-org/librespot), the Spotify client
library under spotifyd, raspotify, and ncspot, lets its users pick their
rustls provider instead of hard-wiring ring, in a merged upstream PR.

## Plan

It runs mostly on Raspberry Pis (armv7 and aarch64), where rind is fastest.
Its users hit aws-lc-sys build failures there and on FreeBSD when 0.6 took
rustls's default provider
([librespot-org/librespot#1447](https://github.com/librespot-org/librespot/issues/1447),
[#1393](https://github.com/librespot-org/librespot/issues/1393),
[Spotifyd/spotifyd#1334](https://github.com/Spotifyd/spotifyd/issues/1334)),
and its `dev` branch now enables hyper-rustls's `ring` feature instead. Check
for any other path to ring before proposing a shape.
