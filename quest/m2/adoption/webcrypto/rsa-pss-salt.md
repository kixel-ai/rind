# [S] RSA-PSS with any salt length

## Goal

rind signs and verifies RSA-PSS with any salt length the key size allows, as
WebCrypto's `saltLength` and pyca's `PSS(salt_length=...)` expose, beside
today's salt the length of the hash.

## Plan

Keep the common case (salt the hash's length) a named constant so most
callers never pick a length.
