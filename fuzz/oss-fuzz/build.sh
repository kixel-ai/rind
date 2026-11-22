#!/bin/bash -eu
# OSS-Fuzz's build script for rind: every cargo-fuzz target, with the seed
# corpora sh/fuzz-seed.sh writes. This directory is what google/oss-fuzz's
# projects/rind copies; check it with that repo's `infra/helper.py check_build`.

cd "$SRC/rind"

# OSS-Fuzz's coverage build fails on debug assertions in std's
# instrumentation, as rustls's build notes.
if [ "$SANITIZER" = "coverage" ]; then
    export RUSTFLAGS="$RUSTFLAGS -C debug-assertions=no"
    export CFLAGS=""
fi

# OSS-Fuzz's runners lack the CPython the python target embeds. The fips
# target loads the FIPS module from beside itself.
export RUSTFLAGS="$RUSTFLAGS -Clink-arg=-Wl,-rpath,\$ORIGIN"
targets=$(cargo fuzz list | grep -vx python)
for target in $targets; do
    cargo fuzz build -O "$target"
done
sh/fuzz-seed.sh
find target/x86_64-unknown-linux-gnu/release/build -path '*/rind-fips*/out/lib/librind_fips_module.so' -exec cp {} "$OUT/" \;

for target in $targets; do
    cp "target/x86_64-unknown-linux-gnu/release/$target" "$OUT/"
    if [ -d "fuzz/corpus/$target" ]; then
        zip -qjr "$OUT/${target}_seed_corpus.zip" "fuzz/corpus/$target"
    fi
done
