# [S] Apache Iggy encrypts streams with rind

## Goal

A PR to [Apache Iggy](https://github.com/apache/iggy), with numbers from its
own `stream_encryption` benchmark, moves its AES-256-GCM message encryption
from RustCrypto onto rind.

## Plan

Decided with the maintainer on 2026-11-04, in a planning interview. Its
AES-GCM-SIV option stays on RustCrypto (rind has none). Apache projects take
contributions through their own process; follow it. Posting is the
maintainer's call.
