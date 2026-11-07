# [L] Aeneas translates function pointers

## Goal

Aeneas translates the function-pointer dispatch rind's APIs use, so `proofs/` retires its hand models of that dispatch, and `admin/prove`'s quote checks for them, as the m3 epic's plan promised once Aeneas can.

## Plan

- Find out whether Aeneas's maintainers plan function-pointer or trait-object support, and contribute it upstream if they welcome it. There is no standing approval to post: stop and ask the maintainer before posting outside the moq-dev and kixelated orgs (decided with the maintainer on 2026-11-07 on [moq-dev/rind#448](https://github.com/moq-dev/rind/pull/448)).
- If upstream won't take it, report the options, such as restructuring rind's dispatch into something Aeneas translates without losing speed, and let the maintainer pick.
