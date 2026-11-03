# [XS] Regeneration uses pinned cross tools

## Goal

The importers and generators that `admin/regenerate` reruns get their aarch64 cross assembler and disassembler from the Nix flake, not Ubuntu's apt, so a runner image update can't change their output and fail the check with nothing wrong in the code.

## Plan

Planned with the maintainer on 2026-11-03 as a follow-up of [moq-dev/rind#304](https://github.com/moq-dev/rind/pull/304), which added the regeneration check.

- Add the cross binutils to a flake dev shell, and have the `regenerate` workflow and the generators use it. Confirm regeneration is still byte-identical.
