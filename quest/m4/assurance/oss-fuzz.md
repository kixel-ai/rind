# [S] rind runs in OSS-Fuzz

## Goal

rind's `fuzz` crate targets run continuously in OSS-Fuzz, with crashes reported to the maintainer, and its coverage shows on OSS-Fuzz's dashboard.

## Plan

- Prepare the project files (`project.yaml`, `Dockerfile`, `build.sh`) and check them with OSS-Fuzz's `helper.py`, building every target with cargo-fuzz.
- Draft the google/oss-fuzz PR and its stated criticality, and show it to the maintainer before posting it.
