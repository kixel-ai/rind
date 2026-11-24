# [S] Each benchmark counts the same instructions on every run

## Goal

Two runs of the weekly bench's `instructions` job on one commit report the same count for every benchmark, so Kixel Quest judges every series instead of setting the noisy ones aside as flakes.

## Plan

Two full `rust2-bench run`s on one commit (2026-11-24) differed in 214 of 1,678 benchmarks: ML-DSA signing by up to 165% (rejection sampling over a random `rnd`), ML-KEM by up to 12%, SLH-DSA by 7%, P-521 and the OPRF by up to 4%, and the rustls handshakes, JWT, blind RSA, RSA, HPKE, and P-384 rows by under 2%. Each draws keys, nonces, or messages from the OS RNG on every run.

Under the count build (`__bench_codspeed`), give each such benchmark fixed inputs: a key and message generated once from a fixed seed, and the deterministic variant where the API has one, such as ML-DSA's hedged signing with a fixed `rnd`. The timed rows keep random inputs. Check by diffing two full runs' `metrics.json`; a benchmark whose library offers no way to fix its randomness, such as a baseline's internal RNG, leaves the count build, and its PR says which.

Public API: none.
