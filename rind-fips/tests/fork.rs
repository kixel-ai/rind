// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

//! A process that forks while another of its threads draws randomness or
//! runs the self-tests leaves the child a module it can use: the child draws
//! or tests on a thread of its own and exits through the module's
//! destructor, which wipes every instance. Without the module's fork
//! handlers, the child would inherit a lock held by a thread it lacks and
//! hang. The wait for each child has no deadline of its own: the test
//! runner's hang bound ends a hung one, sized for how slow each run may be,
//! such as under Intel SDE, where a child that first runs the self-tests
//! takes seconds.
#![cfg(rind_fips_module)]

use std::sync::Arc;
use std::sync::atomic::{AtomicBool, Ordering};
use std::thread;

unsafe extern "C" {
    fn fork() -> i32;
    fn waitpid(pid: i32, status: *mut i32, options: i32) -> i32;
}

/// Forks 32 times while `busy` runs in a loop on another thread, checking
/// that each child runs `child` on a new thread, which must succeed, and
/// exits.
fn fork_while(busy: fn(), child: fn() -> bool) {
    let stop = Arc::new(AtomicBool::new(false));
    let worker = thread::spawn({
        let stop = stop.clone();
        move || {
            while !stop.load(Ordering::Relaxed) {
                busy();
            }
        }
    });

    // The worker holds the module's locks for most of each call, so some of
    // these forks land inside one.
    for _ in 0..32 {
        // SAFETY: the child only runs `child` on a new thread and exits.
        let pid = unsafe { fork() };
        assert!(pid >= 0, "fork failed");
        if pid == 0 {
            let ok = thread::spawn(child).join().unwrap_or(false);
            std::process::exit(if ok { 0 } else { 1 });
        }

        let mut status = 0;
        // SAFETY: `pid` is our child, and `status` writable.
        let reaped = unsafe { waitpid(pid, &mut status, 0) };
        assert_eq!(reaped, pid, "waitpid failed");
        assert_eq!(status, 0, "the forked child failed or did not exit");
    }

    stop.store(true, Ordering::Relaxed);
    worker.join().unwrap();
}

fn draw() -> bool {
    rind_fips::rand::fill(&mut [0u8; 32]).is_ok()
}

#[test]
fn a_child_forked_mid_draw_draws_and_exits() {
    fork_while(
        || {
            draw();
        },
        draw,
    );
}

// The self-tests hold their lock while any runs, which `self_test` does for
// every test, so most of these forks land inside one.
#[test]
fn a_child_forked_mid_self_test_tests_and_exits() {
    fork_while(rind_fips::self_test, || {
        rind_fips::self_test();
        true
    });
}
