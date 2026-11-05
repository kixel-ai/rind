# [S] AES key wrap

## Goal

rind wraps and unwraps keys with RFC 3394 AES-KW, as WebCrypto's `AES-KW`,
pyca's `aes_key_wrap`, and JWE's `A*KW` algorithms use it.

## Plan

Unwrapping checks the integrity value in constant time and returns nothing on
failure. RFC 5649's padded variant waits for a consumer.
