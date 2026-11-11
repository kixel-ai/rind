//! A global allocator that hands back a copy of each block freed while it
//! runs an operation, for the zeroing tests to judge.
//!
//! It records only on the thread that asked, so the rest of the test binary,
//! and tests running beside it, allocate as they would under `System`.
//!
//! Is this sound? No: it reads a block the program has freed, including bytes
//! it never initialized, such as padding and a vector's spare capacity. It
//! reads them with volatile byte loads into plain integers before handing the
//! block back to `System`, so the compiler cannot assume their contents, and
//! the block is still allocated as far as the system allocator knows. Each
//! user's `detects_a_leak` checks it catches a missing wipe in practice.

use std::alloc::{GlobalAlloc, Layout, System};
use std::cell::{Cell, RefCell};

thread_local! {
    /// Whether this thread's frees are being recorded. Cleared while a record
    /// is made, so the record's own allocations are not recorded.
    static RECORDING: Cell<bool> = const { Cell::new(false) };
    static FREED: RefCell<Vec<Vec<u8>>> = const { RefCell::new(Vec::new()) };
}

pub struct Record;

// SAFETY: forwards every call to `System`, and only reads a block it is
// about to free; the module documentation explains what that read risks.
unsafe impl GlobalAlloc for Record {
    unsafe fn alloc(&self, layout: Layout) -> *mut u8 {
        // SAFETY: the caller's contract, passed on.
        unsafe { System.alloc(layout) }
    }

    // `realloc` is left to the default, which frees the old block here.
    unsafe fn dealloc(&self, ptr: *mut u8, layout: Layout) {
        if RECORDING.get() {
            RECORDING.set(false);
            // SAFETY: `ptr` is `layout.size()` bytes that `System` keeps
            // allocated until the call below.
            let block = (0..layout.size())
                .map(|i| unsafe { ptr.add(i).read_volatile() })
                .collect();
            FREED.with_borrow_mut(|freed| freed.push(block));
            RECORDING.set(true);
        }
        // SAFETY: the caller's contract, passed on.
        unsafe { System.dealloc(ptr, layout) }
    }
}

/// Runs `op`, returning its result and the blocks it freed on this thread, in
/// the order it freed them. The result is dropped after the recording stops.
pub fn freed<R>(op: impl FnOnce() -> R) -> (R, Vec<Vec<u8>>) {
    FREED.with_borrow_mut(Vec::clear);
    RECORDING.set(true);
    let result = op();
    RECORDING.set(false);
    (result, FREED.take())
}
