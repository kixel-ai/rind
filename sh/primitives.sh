#!/usr/bin/env bash
# What a diff can break inside rind, for the runs whose tests are slow (Intel
# SDE, qemu, Miri, ctgrind) and for benchmark dispatch, which run rind's tests
# for the changed primitives rather than all of them.
#
# Usage: sh/primitives.sh tests|filter|benches CHANGED_FILE [BACKEND]
#        sh/primitives.sh backends CHANGED_FILE
#        sh/primitives.sh check
#
# CHANGED_FILE lists the changed paths, one per line, as sh/changed.sh prints
# them; `-` reads them from stdin.
#   tests     libtest name filters, one per line, for `cargo test -- ...`
#   filter    the same as one nextest filterset, for `cargo nextest -E`
#   benches   rind-bench's bench targets, one per line
#   backends  the rind backends the diff compiles into: x86_64, aarch64, arm
#             (armv7), and portable
# BACKEND, one of those four, leaves out the paths that backend never
# compiles, for a run of that backend alone.
# tests, benches, and backends print `all` when the diff can reach every one,
# and `none` when it reaches none; filter prints `all()` or `none()`.
# check fails if the map names a bench target rind-bench lacks.
set -euo pipefail

usage="usage: sh/primitives.sh tests|filter|benches CHANGED_FILE [BACKEND], backends CHANGED_FILE, or check"
mode=${1:?$usage}
changed=${2:-}
backend=${3:-}
case "$mode" in
    tests | filter | benches) [[ $# -eq 2 || ($# -eq 3 && "$backend" =~ ^(x86_64|aarch64|arm|portable)$) ]] || {
        echo "$usage" >&2
        exit 2
    } ;;
    backends) [[ $# -eq 2 ]] || {
        echo "$usage" >&2
        exit 2
    } ;;
    check) [[ $# -eq 1 ]] || {
        echo "$usage" >&2
        exit 2
    } ;;
    *)
        echo "$usage" >&2
        exit 2
        ;;
esac

cd "$(git rev-parse --show-toplevel)"

# The map: a primitive, the paths under rind/src/ that implement it (matched
# case-insensitively, since aws-lc names some kernels in capitals), the
# substrings of the test names that check it, and the bench targets that time
# it. A hash or bignum kernel also selects the constructions that feed it
# secrets directly, such as HMAC, Ed25519, ML-KEM, or a curve, since only
# their tests mark those secrets. A path matching several primitives selects
# them all; a path under rind/src/ matching none, such as `lib.rs`, a `mod.rs`,
# or a CPU dispatch file, is shared and selects everything. Every selection
# also runs the CPU tests (`::cpu::`), which assert a run took the dispatch
# path its CI step names.
primitives=(
    'aes|aes|gcm|ghash|gmac|compute_iv|^cipher\.rs$|^aead(\.rs$|/)|aes gcm ghash gmac cipher aead quic key_wrap|aes_gcm cipher key_wrap'
    'chacha|chacha|poly1305|poly_hash|^aead(\.rs$|/)|chacha poly1305 aead quic|chacha20poly1305 xchacha20poly1305'
    'sha1|sha1|sha_armv4|^low/portable/sha\.rs$|sha1 digest hashes compress_blocks hmac hkdf pbkdf2|sha1 hmac'
    'sha2|sha256|sha512|sha_|sha-?2|^low/portable/sha\.rs$|^high/(digest|hash|hmac|hkdf|pbkdf2|hmac_drbg)\.rs$|sha2 sha256 sha384 sha512 digest hash hashes compress_blocks hmac hkdf pbkdf2 drbg ed25519|sha2 hmac hkdf pbkdf2 ed25519'
    'sha3|sha3|keccak|shake|sha3 shake keccak digest hashes mlkem ml_kem kem mldsa ml_dsa|sha3 mlkem768 mldsa'
    'md5|md5|md5 digest hashes compress_blocks|md5'
    # The NIST curves' shared code: ECDSA, ECDH, their encodings, and the
    # portable backend's group orders.
    'ec|^high/(ecdsa|agreement|curve|sec1)\.rs$|^high/ecdsa/|hash_to_curve|^low/generic/order\.rs$|p256 p384 p521 ecdsa agreement ecdh curve sec1 hash_to_curve|p256 p384 p521'
    'p256|p256|n256|nistz256|p256 ecdsa agreement ecdh hash_to_curve|p256'
    'p384|p384|n384|p384 ecdsa agreement ecdh|p384'
    'p521|p521|n521|p521 ecdsa agreement ecdh|p521'
    '25519|25519|edwards|ristretto|^high/agreement\.rs$|25519 edwards ristretto agreement|x25519 ed25519'
    # s2n-bignum's generic kernels that the curves call too, with secret
    # operands, and the point selection over their precomputed tables.
    'curve-bignum|bignum_(eq|mux|cmp_lt|modadd|modsub|modinv|montifier|montmul|demont|copy_row_from_table|point_select)|^low/generic/(bignum|mont)\.rs$|p256 p384 p521 ecdsa agreement ecdh hash_to_curve 25519 edwards ristretto|p256 p384 p521 x25519 ed25519'
    # aws-lc's `bn_` Montgomery kernels and RSAZ, s2n-bignum's generic
    # bignum routines, and the arithmetic over them.
    'rsa|rsa|bn_|mont|bignum|posint|extract_multiplier|^high/(oaep|pkcs1)\.rs$|rsa oaep pkcs1 pss posint bignum mont|rsa_priv rsa_pub rsa_gen'
    'mlkem|mlkem|^high/kem\.rs$|mlkem ml_kem kem|mlkem768'
    'mldsa|mldsa|mldsa ml_dsa|mldsa'
    'hpke|^high/hpke\.rs$|hpke|'
    'spake2plus|spake2plus|spake2plus|'
    'vrf|^high/vrf\.rs$|vrf|'
    'oprf|^high/oprf|oprf|'
)

# Outside rind/src/, these reach every test and bench: the dependencies, the
# toolchain, the test vectors, rind's manifest, build script, and test
# harnesses, and the scripts that run these suites.
shared='^(Cargo\.(toml|lock)$|flake\.(nix|lock)$|rust-toolchain(\.toml)?$|\.cargo/|thirdparty/|rind/(Cargo\.toml$|build\.rs$|tests/|src/(test|testdata)/|src/test\.rs$)|sh/(primitives|changed|qemu|armv7|miri)\.sh$|admin/(ctgrind|x86-cpu)|\.github/workflows/(x86-cpu|ctgrind|miri|build|bench)\.yml$)'

if [[ "$mode" == check ]]; then
    mapfile -t targets < <(cargo metadata --format-version 1 --no-deps --locked |
        jq -r '.packages[] | select(.name == "rind-bench") | .targets[] | select(.kind == ["bench"]) | .name')
    status=0
    for entry in "${primitives[@]}"; do
        name=${entry%%|*}
        for bench in ${entry##*|}; do
            if ! printf '%s\n' "${targets[@]}" | grep -qxF "$bench"; then
                echo "error: sh/primitives.sh maps $name to bench target $bench, which rind-bench lacks" >&2
                status=1
            fi
        done
    done
    exit "$status"
fi

[[ "$changed" != - ]] || changed=/dev/stdin

declare -A tests=() benches=() backends=()
all_tests='' all_benches='' all_backends=''
shopt -s nocasematch
while IFS= read -r path; do
    [[ -n "$path" ]] || continue
    if [[ "$path" =~ $shared ]]; then
        all_tests=1 all_benches=1 all_backends=1
        continue
    fi
    # A bench target times what it names, and its harness every one.
    if [[ "$path" == rind-bench/* ]]; then
        if [[ "$path" =~ ^rind-bench/benches/([a-z0-9_]+)\.rs$ ]]; then
            benches[${BASH_REMATCH[1]}]=1
        else
            all_benches=1
        fi
        continue
    fi
    # These suites test the adapters too, and rind-bench times two of them.
    # A Rust crate nested in one, such as the FIPS module in rind-fips/module/,
    # counts as the adapter; Dart's lib/src/ does not.
    if [[ "$path" =~ ^rind-([a-z0-9-]+)/((src/|tests/|build\.rs$|Cargo\.toml$)|([^/]+/)+(src/.*\.rs$|build\.rs$|Cargo\.toml$)) ]]; then
        all_tests=1
        name=${BASH_REMATCH[1]//-/_}
        [[ ! -f "rind-bench/benches/$name.rs" ]] || benches[$name]=1
        continue
    fi
    if [[ "$path" != rind/src/* ]]; then
        # rind's README is its crate docs, which these suites never run.
        [[ "$path" != rind/* || "$path" =~ ^rind/[^/]+\.md$ ]] || all_tests=1 all_benches=1 all_backends=1
        continue
    fi
    rel=${path#rind/src/}

    # The backends: each low/ directory compiles into its own, but armv7
    # builds on the portable backend's, and aarch64 shares armv7's qemu
    # constant-time hooks. mid/portable/ swaps in for both.
    case "$rel" in
        low/x86_64/*) reach=(x86_64) ;;
        low/aarch64/*) reach=(aarch64) ;;
        low/arm/ct_qemu.rs) reach=(arm aarch64) ;;
        low/arm/*) reach=(arm) ;;
        low/portable/* | mid/portable/*) reach=(arm portable) ;;
        *) reach=() ;;
    esac
    if ((${#reach[@]} == 0)); then
        all_backends=1
    else
        for name in "${reach[@]}"; do backends[$name]=1; done
        if [[ -n "$backend" && " ${reach[*]} " != *" $backend "* ]]; then
            continue
        fi
    fi

    matched=
    for entry in "${primitives[@]}"; do
        # The pattern is every field between the name and the last two.
        rest=${entry#*|}
        bench_names=${rest##*|}
        rest=${rest%|*}
        test_names=${rest##*|}
        pattern=${rest%|*}
        if [[ "$rel" =~ $pattern ]]; then
            matched=1
            for name in $test_names; do tests[$name]=1; done
            for name in $bench_names; do benches[$name]=1; done
        fi
    done
    [[ -n "$matched" ]] || all_tests=1 all_benches=1
done <"$changed"
shopt -u nocasematch

# Prints `all`, `none`, or the set's keys, sorted.
emit() {
    local all=$1
    shift
    if [[ -n "$all" ]]; then
        echo all
    elif (($# == 0)); then
        echo none
    else
        printf '%s\n' "$@" | sort
    fi
}

case "$mode" in
    tests) emit "$all_tests" ${tests[@]+"${!tests[@]}"} ${tests[@]+::cpu::} ;;
    filter)
        if [[ -n "$all_tests" ]]; then
            echo 'all()'
        elif ((${#tests[@]} == 0)); then
            echo 'none()'
        else
            mapfile -t names < <(printf '%s\n' "${!tests[@]}" ::cpu:: | sort)
            printf -v expr 'test(~%s) | ' "${names[@]}"
            echo "${expr% | }"
        fi
        ;;
    benches) emit "$all_benches" ${benches[@]+"${!benches[@]}"} ;;
    backends) emit "$all_backends" ${backends[@]+"${!backends[@]}"} ;;
esac
