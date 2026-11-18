#!/usr/bin/env bash
# Sourced by every flake dev shell. Cargo looks up cargo-<subcommand> in
# $CARGO_HOME/bin before PATH, unless that directory is already on PATH, so a
# host rustup's cargo-fmt and cargo-clippy shadow the shell's (UPSTREAM.md,
# "Cargo runs $CARGO_HOME/bin's subcommands before PATH's"). Point CARGO_HOME
# at a per-checkout directory whose bin/ is never copied from the host, and
# reuse the host's registry and git caches through symlinks. The host home is
# not written. Run this file to self-test; the dev shell sources it.
#
# sh/dart-library.sh runs cargo-zigbuild by name, and other tools arrive
# through `cargo install` into the host bin. That bin is appended to PATH when
# it is not already there, after the toolchain the shell put first, so those
# tools still run and a rustup shim loses to the flake's binary.

on_path() {
    local dir=$1 rest=${PATH-} entry
    while true; do
        entry=${rest%%:*}
        [[ "$entry" == "$dir" ]] && return 0
        [[ "$rest" == *:* ]] || return 1
        rest=${rest#*:}
    done
}

abs_path() {
    case "$1" in
        /*) printf '%s\n' "$1" ;;
        *) printf '%s\n' "$PWD/$1" ;;
    esac
}

rind_dev_cargo_home() {
    local cache_root repo toplevel key dev_cargo host_cargo name src dst current

    if [[ -n "${XDG_CACHE_HOME:-}" ]]; then
        cache_root=$XDG_CACHE_HOME
    elif [[ -n "${HOME:-}" ]]; then
        cache_root=$HOME/.cache
    else
        echo "error: HOME is unset; cannot choose a dev-shell CARGO_HOME" >&2
        return 1
    fi
    cache_root=$(abs_path "$cache_root")

    repo=$PWD
    if command -v git >/dev/null 2>&1; then
        toplevel=$(git rev-parse --show-toplevel 2>/dev/null || true)
        [[ -z "$toplevel" ]] || repo=$toplevel
    fi
    if command -v cksum >/dev/null 2>&1 && command -v awk >/dev/null 2>&1; then
        key=$(printf '%s' "$repo" | cksum | awk '{print $1}')
        dev_cargo="$cache_root/rind/dev-cargo-$key"
    else
        dev_cargo="$cache_root/rind/dev-cargo"
    fi

    # A CARGO_HOME that is not already the dev-shell directory is the host
    # home, including one a nested `nix develop` was given. Once this hook has
    # pointed CARGO_HOME at the dev-shell directory, the host home is the one
    # recorded for it.
    host_cargo=
    if [[ -n "${CARGO_HOME:-}" && "$(abs_path "$CARGO_HOME")" != "$dev_cargo" ]]; then
        host_cargo=$CARGO_HOME
    elif [[ -n "${RIND_HOST_CARGO_HOME:-}" ]]; then
        host_cargo=$RIND_HOST_CARGO_HOME
    elif [[ -f "$dev_cargo/.rind-host-cargo" ]]; then
        IFS= read -r host_cargo <"$dev_cargo/.rind-host-cargo" || true
    fi
    if [[ -z "$host_cargo" || "$(abs_path "$host_cargo")" == "$dev_cargo" ]]; then
        if [[ -z "${HOME:-}" ]]; then
            echo "error: HOME is unset; cannot find the host cargo home" >&2
            return 1
        fi
        host_cargo=$HOME/.cargo
    fi
    host_cargo=$(abs_path "$host_cargo")
    if [[ "$host_cargo" == "$dev_cargo" ]]; then
        echo "error: the dev-shell CARGO_HOME would be the host cargo home ($host_cargo)" >&2
        return 1
    fi

    # mkdir -p would follow either link and write into the host home.
    if [[ -L "$dev_cargo" || -L "$dev_cargo/bin" ]]; then
        echo "error: $dev_cargo must be a real directory, not a symlink into a cargo home" >&2
        return 1
    fi
    mkdir -p "$dev_cargo/bin"
    printf '%s\n' "$host_cargo" >"$dev_cargo/.rind-host-cargo"

    for name in registry git; do
        src="$host_cargo/$name"
        dst="$dev_cargo/$name"
        if [[ -d "$src" && -w "$src" ]]; then
            if [[ -L "$dst" ]]; then
                current=$(readlink "$dst")
                if [[ "$current" != "$src" ]]; then
                    rm -- "$dst"
                    ln -s "$src" "$dst"
                fi
            elif [[ ! -e "$dst" ]]; then
                ln -s "$src" "$dst"
            fi
        elif [[ -L "$dst" ]]; then
            # The previous host's cache, or a link whose target is gone.
            rm -- "$dst"
        fi
    done

    export CARGO_HOME=$dev_cargo
    export RIND_HOST_CARGO_HOME=$host_cargo
    if [[ -d "$host_cargo/bin" ]] && ! on_path "$host_cargo/bin"; then
        if [[ -n "${PATH:-}" ]]; then
            PATH="$PATH:$host_cargo/bin"
        else
            PATH="$host_cargo/bin"
        fi
        export PATH
    fi
}

# Each case is its own subshell so the HOME and CARGO_HOME it exports stay there.
# shellcheck disable=SC2030,SC2031
self_test() {
    local tmp here real_cargo flake
    tmp=$(mktemp -d)
    # shellcheck disable=SC2064 # expand now: $tmp is this run's directory
    trap "chmod -R u+w '$tmp' 2>/dev/null || true; rm -rf '$tmp'" EXIT
    here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
    real_cargo=$(command -v cargo || true)

    fail() {
        echo "dev-cargo-home: self-test: $*" >&2
        exit 1
    }

    manifest() {
        local dir=$1 p
        (
            cd "$dir"
            find . -print | LC_ALL=C sort | while IFS= read -r p; do
                if [[ -L "$p" ]]; then
                    printf 'L %s -> %s\n' "$p" "$(readlink "$p")"
                elif [[ -f "$p" ]]; then
                    printf 'F %s %s\n' "$p" "$(cksum <"$p" | awk '{print $1}')"
                else
                    printf 'D %s\n' "$p"
                fi
            done
        )
    }

    plant_host() {
        local root=$1
        mkdir -p "$root/bin" "$root/registry/cache" "$root/git/db"
        echo marker >"$root/registry/cache/keep"
        echo marker >"$root/git/db/keep"
        echo canary >"$root/canary"
        cat >"$root/bin/cargo" <<'EOF'
#!/bin/sh
echo "rustup-cargo" >&2
exit 99
EOF
        cat >"$root/bin/cargo-fmt" <<'EOF'
#!/bin/sh
echo "rustfmt 1.11.0-stable (0ef1bc3860 2026-11-09)"
EOF
        cat >"$root/bin/cargo-clippy" <<'EOF'
#!/bin/sh
echo "clippy 0.1.100 (0ef1bc3860 2026-11-09)"
EOF
        cat >"$root/bin/cargo-deny" <<'EOF'
#!/bin/sh
echo "cargo-deny 0.18.0-host"
EOF
        cat >"$root/bin/cargo-zigbuild" <<'EOF'
#!/bin/sh
echo "cargo-zigbuild 0.20.1"
EOF
        chmod +x "$root/bin/"*
    }

    plant_flake() {
        local bin=$1
        mkdir -p "$bin"
        # The same rule this file exists for, measured on Cargo 1.83: search
        # $CARGO_HOME/bin first unless that directory is already a PATH entry,
        # then PATH in order.
        cat >"$bin/cargo" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cmd=${1:?}
shift
name="cargo-${cmd}"
home=${CARGO_HOME:-$HOME/.cargo}
home_bin="$home/bin"
found=0
rest=${PATH-}
entry=
while true; do
    entry=${rest%%:*}
    [[ "$entry" == "$home_bin" ]] && found=1
    [[ "$rest" == *:* ]] || break
    rest=${rest#*:}
done
search=()
if ((found == 0)); then
    search+=("$home_bin")
fi
rest=${PATH-}
while true; do
    entry=${rest%%:*}
    search+=("$entry")
    [[ "$rest" == *:* ]] || break
    rest=${rest#*:}
done
for dir in "${search[@]}"; do
    if [[ -n "$dir" && -x "$dir/$name" ]]; then
        exec "$dir/$name" "$@"
    fi
done
echo "no $name" >&2
exit 127
EOF
        cat >"$bin/cargo-fmt" <<'EOF'
#!/bin/sh
echo "rustfmt 1.9.0-stable (48a229ceae 2026-09-01)"
EOF
        cat >"$bin/cargo-clippy" <<'EOF'
#!/bin/sh
echo "clippy 0.1.98 (48a229ceae 2026-09-01)"
EOF
        cat >"$bin/cargo-deny" <<'EOF'
#!/bin/sh
echo "cargo-deny 0.19.0-flake"
EOF
        cat >"$bin/rustc" <<'EOF'
#!/bin/sh
echo "rustc 1.98.1 (48a229cea 2026-09-01)"
EOF
        chmod +x "$bin"/*
    }

    flake=$tmp/flake/bin
    plant_flake "$flake"
    local path="$flake:/usr/bin:/bin"

    # The bug, and the check that catches it: shims win, sh/toolchain.sh fails.
    (
        local host=$tmp/bug/home/.cargo before after err status fmt
        plant_host "$host"
        before=$(manifest "$host")
        fmt=$(
            unset RUSTUP_TOOLCHAIN
            export HOME=$tmp/bug/home CARGO_HOME=$host PATH=$path
            cargo fmt --version
        ) || fail "stub cargo fmt failed before the hook"
        [[ "$fmt" == "rustfmt 1.11.0-stable (0ef1bc3860 2026-11-09)" ]] ||
            fail "before the hook, cargo fmt is '$fmt'"
        status=0
        err=$(
            unset RUSTUP_TOOLCHAIN
            export HOME=$tmp/bug/home CARGO_HOME=$host PATH=$path
            "$here/toolchain.sh" 2>&1
        ) || status=$?
        [[ "$status" -eq 1 ]] || fail "toolchain check passed while rustup's fmt was in front (status $status)"
        [[ "$err" == *"cargo fmt --version"* ]] || fail "toolchain check did not name cargo fmt: $err"
        after=$(manifest "$host")
        [[ "$before" == "$after" ]] || fail "looking up cargo fmt wrote into the host cargo home"
    ) || exit 1

    # The fix: flake fmt and clippy, host-only cargo-zigbuild still runs, the
    # flake's cargo-deny wins over the host's, and the host home is unchanged.
    (
        local home=$tmp/fix/home host before after dev fmt clippy deny zig which_cargo
        plant_host "$home/.cargo"
        host=$home/.cargo
        before=$(manifest "$host")
        unset CARGO_HOME RIND_HOST_CARGO_HOME GIT_DIR GIT_WORK_TREE RUSTUP_TOOLCHAIN
        export HOME=$home XDG_CACHE_HOME=$tmp/fix/xdg PATH=$path
        rind_dev_cargo_home
        dev=$CARGO_HOME
        fmt=$(cargo fmt --version) || fail "cargo fmt failed after the hook"
        clippy=$(cargo clippy --version) || fail "cargo clippy failed after the hook"
        deny=$(cargo deny --version) || fail "cargo deny failed after the hook"
        zig=$(cargo zigbuild --version) || fail "cargo zigbuild failed after the hook"
        [[ "$fmt" == "rustfmt 1.9.0-stable (48a229ceae 2026-09-01)" ]] || fail "cargo fmt is '$fmt'"
        [[ "$clippy" == "clippy 0.1.98 (48a229ceae 2026-09-01)" ]] || fail "cargo clippy is '$clippy'"
        [[ "$deny" == "cargo-deny 0.19.0-flake" ]] || fail "flake cargo-deny lost: '$deny'"
        [[ "$zig" == "cargo-zigbuild 0.20.1" ]] || fail "host cargo-zigbuild did not run: '$zig'"
        which_cargo=$(command -v cargo) || fail "cargo is not on PATH"
        [[ "$which_cargo" == "$flake/cargo" ]] || fail "cargo resolved to '$which_cargo'"
        [[ ! -e "$dev/bin/cargo-fmt" && ! -e "$dev/bin/cargo-clippy" ]] ||
            fail "the dev bin holds a fmt or clippy shim"
        [[ -L "$dev/registry" && "$(readlink "$dev/registry")" == "$host/registry" ]] ||
            fail "registry is not a symlink to the host cache"
        [[ -L "$dev/git" && "$(readlink "$dev/git")" == "$host/git" ]] ||
            fail "git is not a symlink to the host cache"
        [[ "$(cat "$dev/.rind-host-cargo")" == "$host" ]] || fail "host marker is wrong"
        "$here/toolchain.sh" || fail "toolchain check failed after the hook"
        rind_dev_cargo_home
        [[ "$CARGO_HOME" == "$dev" ]] || fail "a second hook changed CARGO_HOME"
        [[ "$(readlink "$CARGO_HOME/registry")" == "$host/registry" ]] || fail "a second hook moved registry"
        after=$(manifest "$host")
        [[ "$before" == "$after" ]] || fail "the hook wrote into the host cargo home"
        # A cache cargo already filled is kept when the host later gains one.
    ) || exit 1

    # CI's shape: the host bin is already on PATH, behind the flake. Cargo
    # must still run the flake's fmt, and the hook must not duplicate the bin.
    (
        local home=$tmp/ci/home host dev fmt rest entry n
        plant_host "$home/.cargo"
        host=$home/.cargo
        unset CARGO_HOME RIND_HOST_CARGO_HOME RUSTUP_TOOLCHAIN
        export HOME=$home XDG_CACHE_HOME=$tmp/ci/xdg PATH="$path:$host/bin"
        rind_dev_cargo_home
        dev=$CARGO_HOME
        fmt=$(cargo fmt --version) || fail "ci-shaped cargo fmt failed"
        [[ "$fmt" == rustfmt\ 1.9.0-stable* ]] || fail "ci-shaped cargo fmt is '$fmt'"
        n=0
        rest=$PATH
        while true; do
            entry=${rest%%:*}
            [[ "$entry" == "$host/bin" ]] && n=$((n + 1))
            [[ "$rest" == *:* ]] || break
            rest=${rest#*:}
        done
        [[ "$n" -eq 1 ]] || fail "host bin appears on PATH $n times"
        [[ "$dev" != "$host" ]] || fail "ci-shaped hook kept the host CARGO_HOME"
    ) || exit 1

    # A CARGO_HOME that is not ~/.cargo, a missing home that must not be
    # created, a read-only registry, and a dev registry cargo already owns.
    (
        local custom=$tmp/custom dev before after
        plant_host "$custom"
        before=$(manifest "$custom")
        unset RIND_HOST_CARGO_HOME RUSTUP_TOOLCHAIN
        export HOME=$tmp/custom-home XDG_CACHE_HOME=$tmp/custom-xdg PATH=$path CARGO_HOME=$custom
        mkdir -p "$HOME"
        rind_dev_cargo_home
        dev=$CARGO_HOME
        [[ "$(readlink "$dev/registry")" == "$custom/registry" ]] || fail "custom registry was not linked"
        [[ ! -e "$HOME/.cargo" ]] || fail "the hook created ~/.cargo"
        after=$(manifest "$custom")
        [[ "$before" == "$after" ]] || fail "custom home changed"
    ) || exit 1

    (
        local missing=$tmp/missing-home/nowhere dev
        unset RIND_HOST_CARGO_HOME RUSTUP_TOOLCHAIN
        export HOME=$tmp/missing-home XDG_CACHE_HOME=$tmp/missing-xdg PATH=$path CARGO_HOME=$missing
        mkdir -p "$HOME"
        rind_dev_cargo_home
        dev=$CARGO_HOME
        [[ ! -e "$missing" ]] || fail "the hook created the missing host cargo home"
        [[ -d "$dev/bin" && ! -e "$dev/registry" && ! -e "$dev/git" ]] ||
            fail "a missing host still produced registry or git links"
    ) || exit 1

    if [[ "$(id -u)" -ne 0 ]]; then
        (
            local home=$tmp/ro/home host dev
            plant_host "$home/.cargo"
            host=$home/.cargo
            chmod a-w "$host/registry"
            unset CARGO_HOME RIND_HOST_CARGO_HOME RUSTUP_TOOLCHAIN
            export HOME=$home XDG_CACHE_HOME=$tmp/ro/xdg PATH=$path
            rind_dev_cargo_home
            dev=$CARGO_HOME
            [[ ! -e "$dev/registry" ]] || fail "a read-only registry was linked"
            [[ -L "$dev/git" ]] || fail "a writable git cache was not linked"
            chmod u+w "$host/registry"
        ) || exit 1
    fi

    (
        local home=$tmp/keep/home dev
        unset CARGO_HOME RIND_HOST_CARGO_HOME RUSTUP_TOOLCHAIN
        export HOME=$home XDG_CACHE_HOME=$tmp/keep/xdg PATH=$path
        mkdir -p "$home"
        rind_dev_cargo_home
        dev=$CARGO_HOME
        mkdir -p "$dev/registry/cache"
        echo mine >"$dev/registry/cache/mine"
        mkdir -p "$home/.cargo/registry/cache"
        rind_dev_cargo_home
        [[ ! -L "$dev/registry" && "$(cat "$dev/registry/cache/mine")" == mine ]] ||
            fail "an existing dev registry was replaced"
    ) || exit 1

    # Two checkouts do not share a bin, so one `cargo install` of cargo-fmt
    # cannot shadow the other's flake.
    (
        local home_a home_b
        mkdir -p "$tmp/repo-a" "$tmp/repo-b"
        git -C "$tmp/repo-a" init -q
        git -C "$tmp/repo-b" init -q
        home_a=$(
            unset CARGO_HOME RIND_HOST_CARGO_HOME GIT_DIR GIT_WORK_TREE
            export HOME=$tmp/repos/home XDG_CACHE_HOME=$tmp/repos/xdg PATH=$path
            cd "$tmp/repo-a"
            rind_dev_cargo_home
            printf '%s' "$CARGO_HOME"
        )
        home_b=$(
            unset CARGO_HOME RIND_HOST_CARGO_HOME GIT_DIR GIT_WORK_TREE
            export HOME=$tmp/repos/home XDG_CACHE_HOME=$tmp/repos/xdg PATH=$path
            cd "$tmp/repo-b"
            rind_dev_cargo_home
            printf '%s' "$CARGO_HOME"
        )
        [[ -n "$home_a" && "$home_a" != "$home_b" ]] || fail "checkouts share CARGO_HOME ($home_a)"
        [[ "$home_a" == "$tmp/repos/xdg/"* && "$home_b" == "$tmp/repos/xdg/"* ]] ||
            fail "CARGO_HOME is not under the XDG cache"
        [[ ! -e "$tmp/repo-a/.cargo" && ! -e "$tmp/repo-b/.cargo" ]] ||
            fail "the hook wrote a cargo home into a checkout"
    ) || exit 1

    # Switching the host home retargets the links; a host with no cache drops them.
    (
        local dev before_one before_two after_one after_two
        plant_host "$tmp/switch/one"
        plant_host "$tmp/switch/two"
        mkdir -p "$tmp/switch/none/bin"
        before_one=$(manifest "$tmp/switch/one")
        before_two=$(manifest "$tmp/switch/two")
        unset RIND_HOST_CARGO_HOME RUSTUP_TOOLCHAIN
        export HOME=$tmp/switch/home XDG_CACHE_HOME=$tmp/switch/xdg PATH=$path
        export CARGO_HOME=$tmp/switch/one
        rind_dev_cargo_home
        dev=$CARGO_HOME
        [[ "$(readlink "$dev/registry")" == "$tmp/switch/one/registry" ]] ||
            fail "first host registry was not linked"
        unset RIND_HOST_CARGO_HOME
        export CARGO_HOME=$tmp/switch/two
        rind_dev_cargo_home
        [[ "$(readlink "$dev/registry")" == "$tmp/switch/two/registry" ]] ||
            fail "registry stayed on the first host"
        unset RIND_HOST_CARGO_HOME
        export CARGO_HOME=$tmp/switch/none
        rind_dev_cargo_home
        [[ ! -e "$dev/registry" && ! -L "$dev/registry" ]] ||
            fail "a host with no registry left the old link in place"
        after_one=$(manifest "$tmp/switch/one")
        after_two=$(manifest "$tmp/switch/two")
        [[ "$before_one" == "$after_one" && "$before_two" == "$after_two" ]] ||
            fail "switching hosts wrote into a host cargo home"
    ) || exit 1

    # A bin that is a symlink into the host must not be followed.
    (
        local home=$tmp/link/home host dev status err
        plant_host "$home/.cargo"
        host=$home/.cargo
        unset CARGO_HOME RIND_HOST_CARGO_HOME RUSTUP_TOOLCHAIN
        export HOME=$home XDG_CACHE_HOME=$tmp/link/xdg PATH=$path
        rind_dev_cargo_home
        dev=$CARGO_HOME
        rm -rf "${dev:?}/bin"
        ln -s "$host/bin" "$dev/bin"
        status=0
        err=$(rind_dev_cargo_home 2>&1) || status=$?
        [[ "$status" -eq 1 ]] || fail "a symlinked bin was accepted (status $status)"
        [[ "$err" == *symlink* ]] || fail "refusal did not say why: $err"
        [[ -x "$host/bin/cargo-fmt" && ! -e "$host/bin/planted-by-hook" ]] ||
            fail "refusing a symlink still wrote into the host bin"
    ) || exit 1

    if [[ -n "$real_cargo" && -x "$real_cargo" ]]; then
        (
            local home=$tmp/real/home host before after fmt clippy
            plant_host "$home/.cargo"
            host=$home/.cargo
            before=$(manifest "$host")
            fmt=$(
                unset RUSTUP_TOOLCHAIN
                export HOME=$home CARGO_HOME=$host PATH=$path
                "$real_cargo" fmt --version
            ) || fail "real cargo fmt failed in the bug case"
            [[ "$fmt" == *1.11.0-stable* ]] || fail "real cargo did not prefer the shim: '$fmt'"
            unset CARGO_HOME RIND_HOST_CARGO_HOME RUSTUP_TOOLCHAIN
            export HOME=$home XDG_CACHE_HOME=$tmp/real/xdg PATH=$path
            rind_dev_cargo_home
            fmt=$("$real_cargo" fmt --version) || fail "real cargo fmt failed after the hook"
            clippy=$("$real_cargo" clippy --version) || fail "real cargo clippy failed after the hook"
            [[ "$fmt" == *1.9.0-stable* ]] || fail "real cargo fmt after the hook is '$fmt'"
            [[ "$clippy" == *0.1.98* ]] || fail "real cargo clippy after the hook is '$clippy'"
            after=$(manifest "$host")
            [[ "$before" == "$after" ]] || fail "real cargo fmt wrote into the host cargo home"
        ) || exit 1
    fi

    echo "dev-cargo-home: self-test ok"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    set -euo pipefail
    case "${1:-}" in
        --self-test) self_test ;;
        *)
            echo "usage: sh/dev-cargo-home.sh --self-test" >&2
            exit 2
            ;;
    esac
else
    rind_dev_cargo_home
fi
