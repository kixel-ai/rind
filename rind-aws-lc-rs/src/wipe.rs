//! The adapter's own copies of secrets, wiped on drop under the `wipe`
//! feature, as rind wipes its keys.

use core::ops::{Deref, DerefMut};

use zeroize::Zeroize;

/// A secret wiped on drop when the `wipe` feature is on.
#[derive(Clone)]
pub(crate) struct Wiped<T: Zeroize>(T);

impl<T: Zeroize> Wiped<T> {
    pub(crate) fn new(value: T) -> Self {
        Self(value)
    }
}

impl<T: Zeroize> Drop for Wiped<T> {
    fn drop(&mut self) {
        // `cfg!` rather than `#[cfg]` keeps the wipe type-checked in every
        // build; the optimizer drops it when the feature is off.
        if cfg!(feature = "wipe") {
            self.0.zeroize();
        }
    }
}

impl<T: Zeroize> Deref for Wiped<T> {
    type Target = T;

    fn deref(&self) -> &T {
        &self.0
    }
}

impl<T: Zeroize> DerefMut for Wiped<T> {
    fn deref_mut(&mut self) -> &mut T {
        &mut self.0
    }
}
