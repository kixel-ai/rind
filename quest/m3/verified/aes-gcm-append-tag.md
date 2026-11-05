# [XS] AES-GCM's seal_in_place_append_tag is proven on the Vale tier

## Goal

The Vale tier's AES-GCM proof covers `seal_in_place_append_tag` too, so every seal the AEAD API offers is proven there, not only the separate-tag calls the benchmarks use.

## Plan

[moq-dev/rind#344](https://github.com/moq-dev/rind/pull/344) proves `seal_in_place_separate_tag` and both opens. `seal_in_place_append_tag` is generic over `Extend`, which Aeneas does not translate as written. Prove it as `seal_in_place_separate_tag` followed by appending the tag, through a hand model of the generic call quoted and checked by `admin/prove` like the other dispatch models, or reshape the Rust so Aeneas translates it with unchanged release codegen.
