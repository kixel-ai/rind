# [S] AES-CTR with any counter length

## Goal

rind applies AES-CTR over WebCrypto's 16-byte counter block, incrementing
only its rightmost `length` bits (1 to 128) and wrapping them within those
bits, as WebCrypto's `AesCtrParams` and pyca's `modes.CTR` define it. It
refuses a message longer than 2^`length` blocks, which would repeat a counter
block, as Chromium does; the spec sets no limit.

## Plan

`rind::cipher::AesCtr` takes a 12-byte nonce and a 32-bit counter (RFC 3686
and SRTP). Extend or generalize it rather than adding a second CTR type, if
the 32-bit form stays as fast.
