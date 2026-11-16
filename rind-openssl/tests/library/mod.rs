// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0
//! Finds the shared library this build made, for the tests to load.

use std::path::PathBuf;
use std::time::SystemTime;

/// The shared library the test build made.
///
/// Cargo's layout through 1.100 put it beside the test binary. Since 1.101
/// it keeps each unit's output in `build/<package>/<hash>/out`, so it sits
/// in a sibling of the test binary's directory instead, and nothing names
/// which: Cargo hands a test no path to its package's own library. Each
/// build with other features or flags, such as `cargo test
/// --no-default-features`, leaves a library of its own there; the newest is
/// the one the latest build made.
pub fn find() -> PathBuf {
    let name = format!(
        "{}rind_openssl{}",
        std::env::consts::DLL_PREFIX,
        std::env::consts::DLL_SUFFIX
    );
    let exe = std::env::current_exe().unwrap();
    let beside = exe.with_file_name(&name);
    if beside.exists() {
        return beside;
    }
    let units = exe.ancestors().nth(3).unwrap_or_else(|| {
        panic!("{} is too shallow to find {name} from", exe.display());
    });
    let mut found: Vec<(SystemTime, PathBuf)> = std::fs::read_dir(units)
        .unwrap_or_else(|error| panic!("cannot list {}: {error}", units.display()))
        .filter_map(|unit| {
            let path = unit.ok()?.path().join("out").join(&name);
            Some((path.metadata().ok()?.modified().ok()?, path))
        })
        .collect();
    found.sort();
    match found.pop() {
        Some((_, path)) => path,
        None => panic!(
            "no {name} beside {} or in a sibling of its directory",
            exe.display()
        ),
    }
}
