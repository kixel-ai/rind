// Compiles Bun's pinned BoringSSL (oven-sh/boringssl) the way Bun's
// scripts/build/deps/boringssl.ts does: bcm + crypto sources and the
// pre-generated assembly, C++17, -O3, Bun's -march for the target.
use std::{env, path::PathBuf};

fn main() {
    let root = PathBuf::from(env::var("BORINGSSL_DIR").expect("BORINGSSL_DIR"));
    let json: serde_json::Value =
        serde_json::from_slice(&std::fs::read(root.join("gen/sources.json")).unwrap()).unwrap();
    let list = |k: &str, f: &str| -> Vec<String> {
        json[k][f].as_array().map(|a| a.iter().map(|v| v.as_str().unwrap().to_owned()).collect()).unwrap_or_default()
    };
    let arch = env::var("CARGO_CFG_TARGET_ARCH").unwrap();
    let os = env::var("CARGO_CFG_TARGET_OS").unwrap();
    let march: &[&str] = match (arch.as_str(), os.as_str()) {
        ("x86_64", _) => &["-march=nehalem"],
        ("aarch64", "macos") => &["-mcpu=apple-m1"],
        ("aarch64", _) => &["-march=armv8-a+crc", "-mtune=ampere1"],
        _ => &[],
    };
    let mut b = cc::Build::new();
    b.cpp(true)
        .include(root.join("include"))
        .define("BORINGSSL_IMPLEMENTATION", None)
        .define("NDEBUG", None)
        .opt_level(3)
        .flag("-std=c++17")
        .flag("-fno-exceptions")
        .flag("-fno-rtti")
        .flag("-fno-strict-aliasing")
        .flag("-fno-common")
        .flag("-fvisibility=hidden")
        .warnings(false);
    for f in march {
        b.flag(f);
    }
    for s in list("bcm", "srcs").iter().chain(list("crypto", "srcs").iter()) {
        b.file(root.join(s));
    }
    let mut a = cc::Build::new();
    a.include(root.join("include")).opt_level(3).warnings(false);
    for f in march {
        a.flag(f);
    }
    if os == "linux" {
        a.flag("-Wa,--noexecstack");
    }
    for s in list("bcm", "asm").iter().chain(list("crypto", "asm").iter()) {
        a.file(root.join(s));
    }
    b.compile("bssl_crypto");
    a.compile("bssl_asm");
    println!("cargo:rerun-if-env-changed=BORINGSSL_DIR");
}
