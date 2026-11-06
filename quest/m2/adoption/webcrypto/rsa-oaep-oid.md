# [S] RSA keys labelled id-RSAES-OAEP load

## Goal

rind loads RSA PKCS#8 and SPKI keys whose algorithm is id-RSAES-OAEP (1.2.840.113549.1.1.7), as aws-lc-rs does, so keys exported for WebCrypto's RSA-OAEP import and the keys fuzzer stops flagging the difference.

## Plan

The keys fuzzer found this in [moq-dev/rind#382](https://github.com/moq-dev/rind/pull/382) (selectors 12 and 14): aws-lc-rs takes the OID and rind refuses it. Decided with the maintainer on 2026-11-05: accept it, following aws-lc-rs. Match aws-lc's parameter handling exactly (which parameter encodings it takes with the OID, and which key types load such a key), and add Wycheproof or hand-built vectors plus the aws-lc-rs crosscheck.
