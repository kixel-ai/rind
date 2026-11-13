#!/usr/bin/env bash
# Run OpenSSL's own `evp_test` on its X25519 and Ed25519 data with
# rind-openssl loaded and preferred, as its README's configuration does;
# `-provider rind` fails the run if rind does not load, instead of letting
# the default provider pass it.
#
# Usage: nix develop .#openssl --command sh/openssl.sh
# That dev shell builds `evp_test` from the source of the OpenSSL the default
# one has. Each stanza that asks Ed25519's `instance` for Ed25519ctx or
# Ed25519ph is left out, since rind backs only pure Ed25519 and refuses
# them; OpenSSL's ED25519ctx and ED25519ph signature algorithms stay the
# default provider's, so their stanzas run.
set -euo pipefail

: "${OPENSSL_EVP_TEST:?run in the .#openssl dev shell}"

cd "$(git rev-parse --show-toplevel)"

cargo build -p rind-openssl --locked
target=$(cargo metadata --format-version 1 --no-deps | jq -r .target_directory)
library=$(find "$target/debug" -maxdepth 1 -name 'librind_openssl.so' -o -maxdepth 1 -name 'librind_openssl.dylib' | head -n 1)
if [[ -z "$library" ]]; then
    echo "error: no rind-openssl library in $target/debug" >&2
    exit 1
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

sed "s|^module = .*|module = $library|" rind-openssl/openssl.cnf >"$work/openssl.cnf"
grep -qxF "module = $library" "$work/openssl.cnf"

skipped=0
for file in "$OPENSSL_EVP_TEST"/share/evp_test/*.txt; do
    # Stanzas are paragraphs.
    awk 'BEGIN { RS = ""; ORS = "\n\n" } !/Ctrl = instance:Ed25519(ctx|ph)/' "$file" >"$work/${file##*/}"
    count() { awk 'BEGIN { RS = "" } END { print NR }' "$1"; }
    skipped=$((skipped + $(count "$file") - $(count "$work/${file##*/}")))
done
echo "Left out $skipped stanzas for Ed25519ctx or Ed25519ph through Ed25519's instance." >&2

"$OPENSSL_EVP_TEST/bin/evp_test" -config "$work/openssl.cnf" -provider rind "$work"/evppkey_*.txt
