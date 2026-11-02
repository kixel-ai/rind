{
  description = "rind - pure-Rust cryptography for MoQ";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # The quest CLI, which also serves the quest guide and skills the stubs in
    # .claude/skills call. Bump the rev to upgrade them.
    quest = {
      url = "github:moq-dev/quest/782132ecd41fa26d5eea7e627170e6749f29aad8";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
  };

  outputs =
    {
      nixpkgs,
      flake-utils,
      rust-overlay,
      quest,
      ...
    }:
    flake-utils.lib.eachSystem
      [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ]
      (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ (import rust-overlay) ];
          };

          # Pinned build toolchain so `nix develop` and CI compile against the
          # same rustc. The workspace declares a lower floor (rust-version),
          # which `devShells.msrv` builds with. No rust-toolchain.toml: it
          # would override the nightly jobs' toolchains.
          rust-stable = pkgs.rust-bin.stable."1.98.1";
          rust-toolchain = rust-stable.minimal.override {
            # `minimal` rather than `default`, which adds offline HTML docs to
            # a closure every CI job downloads.
            extensions = [
              "rustfmt"
              "clippy"
              "rust-src"
              "rust-analyzer"
            ];
            # The gate lints rind's other backends without their C toolchains.
            targets = [
              "aarch64-unknown-linux-gnu"
              "armv7-unknown-linux-gnueabihf"
            ];
          };

          quest-cli = quest.packages.${system}.default;

          # rind itself builds for armv7 without C. Only its tests need this
          # ARM C toolchain, for the aws-lc-rs dev-dependency they check
          # against, so it lives in `devShells.armv7` and nothing rind ships
          # links it.
          armv7-cc = pkgs.pkgsCross.armv7l-hf-multiplatform.stdenv.cc;
          armv7-prefix = "${armv7-cc}/bin/${armv7-cc.targetPrefix}";

          # Intel SDE, which `x86-cpu.yml` and `admin/x86-cpu` run to emulate
          # each Intel CPU model. Its license allows use and redistribution
          # only unmodified, so its 64-bit launcher runs as shipped in an FHS
          # sandbox for its /lib64 loader, rather than patched for Nix. The
          # kit's `sde` launcher is 32-bit; `sde64` takes the same arguments.
          # Ubuntu's AppArmor denies the sandbox its user namespace until
          # `kernel.apparmor_restrict_unprivileged_userns=0`, as x86-cpu.yml sets.
          sde = pkgs.buildFHSEnv {
            name = "sde";
            runScript = "${
              pkgs.fetchFromGitHub {
                owner = "ctz";
                repo = "intel-sde";
                # SDE 9.53.0.
                rev = "1e06cc8cf49bb3b9004737e4f69bcf12f80e0bca";
                hash = "sha256-KjemFD8imYo22rlnfKQbRPfmuMdVNaljqQSwyQxzo90=";
              }
            }/sde64";
          };
        in
        {
          devShells = {
            default = pkgs.mkShell {
              packages =
                with pkgs;
                [
                  rust-toolchain
                  just
                  git
                  jq
                  # aws-lc-rs (dev-dependency, the differential-test oracle),
                  # libfuzzer-sys, and the OpenSSL benchmarks build C.
                  cmake
                  pkg-config
                  openssl
                  cargo-deny
                  cargo-nextest
                  cargo-semver-checks
                  # Linters used by `just check` and `just fix`, which skip a
                  # module whose tools aren't on $PATH. CI sets CI_STRICT=1, which
                  # turns that skip into an error (see sh/dispatch.sh).
                  shellcheck
                  actionlint
                  # sh/alert.sh reads the workflows.
                  yq-go
                  nixfmt
                  # admin/ scripts.
                  python3
                  cargo-modules
                  quest-cli
                  # rind-instant-acme's end-to-end test issues a certificate from it.
                  pebble
                ]
                ++ pkgs.lib.optionals (!pkgs.stdenv.hostPlatform.isDarwin) [
                  # Marked broken on Darwin in nixpkgs.
                  release-plz
                  # admin/ctgrind's constant-time checks.
                  valgrind
                ];

              # What sh/dispatch.sh checks before a scoped `just check` or `just
              # fix`. IN_NIX_SHELL would also pass inside another project's shell.
              env.IN_RIND_DEV_SHELL = "1";
            };

            # The nightly MSRV job builds in it. The workspace's rust-version
            # names a minor release, which resolves to its latest patch, as
            # rustup does. The extra targets let it check rind's other
            # backends, which `check` does without a C toolchain.
            msrv = pkgs.mkShell {
              packages = [
                (pkgs.rust-bin.fromRustupToolchain {
                  channel = (builtins.fromTOML (builtins.readFile ./Cargo.toml)).workspace.package.rust-version;
                  profile = "minimal";
                  targets = [
                    "aarch64-unknown-linux-gnu"
                    "armv7-unknown-linux-gnueabihf"
                  ];
                })
              ];
            };
          }
          # `just armv7` enters it to lint and test the armv7 build under qemu.
          # A separate shell because the ARM C toolchain, qemu-user, and the
          # armv7 standard libraries add about 700 MB, which every other CI job
          # would download. Linux only, since qemu-user needs a Linux host.
          // pkgs.lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
            armv7 = pkgs.mkShell {
              packages = [
                (rust-stable.minimal.override {
                  extensions = [ "clippy" ];
                  targets = [
                    "armv7-unknown-linux-gnueabihf"
                    "armv7-linux-androideabi"
                  ];
                })
                armv7-cc
                pkgs.qemu-user
              ];

              env = {
                CC_armv7_unknown_linux_gnueabihf = "${armv7-prefix}cc";
                CXX_armv7_unknown_linux_gnueabihf = "${armv7-prefix}c++";
                AR_armv7_unknown_linux_gnueabihf = "${armv7-prefix}ar";
                CARGO_TARGET_ARMV7_UNKNOWN_LINUX_GNUEABIHF_LINKER = "${armv7-prefix}cc";
                # The wrapper links against the store's armhf glibc by absolute
                # path, so qemu needs no sysroot.
                CARGO_TARGET_ARMV7_UNKNOWN_LINUX_GNUEABIHF_RUNNER = "qemu-arm";
              };
            };
          }
          # `x86-cpu.yml` and `admin/x86-cpu sde-scan` run the tests and
          # `rind-cpuid` under `sde` in it. SDE runs only on x86_64.
          // pkgs.lib.optionalAttrs (system == "x86_64-linux") {
            sde = pkgs.mkShell {
              packages = with pkgs; [
                rust-toolchain
                # aws-lc-rs and the OpenSSL benchmarks build C.
                cmake
                pkg-config
                openssl
                python3
                sde
              ];

              # What `admin/x86-cpu sde-scan` checks before entering this shell.
              env.IN_RIND_SDE_SHELL = "1";
            };
          };

          formatter = pkgs.nixfmt-tree;
        }
      );
}
