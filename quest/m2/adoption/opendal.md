# [S] opendal builds rustls without a provider

## Goal

[opendal](https://github.com/apache/opendal) offers a rustls feature with no
built-in provider, so its users install rind-rustls (or any provider) instead
of compiling aws-lc-rs, in a merged upstream PR for
[apache/opendal#7571](https://github.com/apache/opendal/issues/7571), where a
maintainer welcomed one.

## Plan

Follow reqwest's `rustls-no-provider` pattern. Its users also hit aws-lc-sys
build failures ([apache/opendal#5048](https://github.com/apache/opendal/issues/5048)),
which the PR can cite.
