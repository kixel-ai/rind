# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.10.1](https://github.com/kixel-ai/rind/compare/rind-rand-core-v0.10.0...rind-rand-core-v0.10.1) - 2026-11-28

Requires rind 0.4, so `SystemRandom`'s `TryRng::Error` is rind 0.4's `rind::Error`.

### Added

- rind's `ml-dsa` and `slh-dsa` features, on by default, so building rind with `default-features = false` leaves ML-DSA and SLH-DSA out, as the adapters do (rind-aws-lc-rs and rind-openssl turn ML-DSA back on); a build for one CPU links one tier, and CI holds rind's size in a binary ([#1008](https://github.com/kixel-ai/rind/pull/1008))
