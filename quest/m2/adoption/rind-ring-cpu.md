# [XS] rind-ring exposes rind's CPU check

## Goal

A rind-ring user can run rind's CPU check without depending on `rind` directly.

## Plan

Found by the migration prompt's trial ([moq-dev/rind#357](https://github.com/moq-dev/rind/pull/357)): the CPU check is how a program refuses an unsupported CPU at startup, and rind-ring's users had to add `rind` only for it. Re-export `rind::cpu` from rind-ring, under the name rind uses, and mention it in the migration guide's ring rows.
