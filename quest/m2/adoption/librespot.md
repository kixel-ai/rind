# [S] librespot builds rustls without ring

## Goal

[librespot](https://github.com/librespot-org/librespot), the Spotify client
library under spotifyd, raspotify, and ncspot, lets its users pick their
rustls provider instead of hard-wiring ring, in a merged upstream PR.

## Plan

It runs mostly on Raspberry Pis (armv7 and aarch64), where rind is fastest,
and its users report ring build failures there and on FreeBSD
([librespot-org/librespot#1447](https://github.com/librespot-org/librespot/issues/1447),
[#1393](https://github.com/librespot-org/librespot/issues/1393),
[Spotifyd/spotifyd#1334](https://github.com/Spotifyd/spotifyd/issues/1334)).
Check how it reaches ring (hyper-rustls's features, plus any direct use)
before proposing a shape.
