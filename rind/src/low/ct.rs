// Written for Graviola by Joe Birr-Pixton, 2025.
// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

cfg_if::cfg_if! {
    if #[cfg(feature = "__ctgrind")] {
        use crabgrind::{memcheck, valgrind};
        use core::mem::size_of_val;

        #[inline]
        pub(crate) fn secret_slice<T>(v: &[T]) {
            if let valgrind::RunningMode::Valgrind = valgrind::running_mode() {
                memcheck::mark_memory(
                    v.as_ptr().cast(),
                    size_of_val(v),
                    memcheck::MemState::Undefined,
                )
                .unwrap();
            }
        }

        #[inline]
        pub(crate) fn public_slice<T>(v: &[T]) {
            if let valgrind::RunningMode::Valgrind = valgrind::running_mode() {
                memcheck::mark_memory(
                    v.as_ptr().cast(),
                    size_of_val(v),
                    memcheck::MemState::Defined,
                )
                .unwrap();
            }
        }

        #[inline]
        #[must_use]
        pub(crate) fn into_secret<T>(v: T) -> T {
            if let valgrind::RunningMode::Valgrind = valgrind::running_mode() {
                memcheck::mark_memory(
                    (&v as *const T).cast(),
                    size_of_val(&v),
                    memcheck::MemState::Undefined,
                )
                .unwrap();
            }
            v
        }

        #[inline]
        #[must_use]
        pub(crate) fn into_public<T>(v: T) -> T {
            if let valgrind::RunningMode::Valgrind = valgrind::running_mode() {
                memcheck::mark_memory(
                    (&v as *const T).cast(),
                    size_of_val(&v),
                    memcheck::MemState::Defined,
                )
                .unwrap();
            }
            v
        }
    } else if #[cfg(test)] {
        // `admin/ct-binsec` replaces these markers with fresh secret or
        // public values, so BINSEC checks the policy valgrind does.
        use super::ct_binsec::{classify, declassify};
        use core::mem::size_of_val;

        #[inline]
        pub(crate) fn secret_slice<T>(v: &[T]) {
            classify(v.as_ptr().cast_mut().cast(), size_of_val(v));
        }

        #[inline]
        pub(crate) fn public_slice<T>(v: &[T]) {
            declassify(v.as_ptr().cast_mut().cast(), size_of_val(v));
        }

        #[inline]
        #[must_use]
        pub(crate) fn into_secret<T>(mut v: T) -> T {
            classify((&raw mut v).cast(), size_of_val(&v));
            v
        }

        #[inline]
        #[must_use]
        pub(crate) fn into_public<T>(mut v: T) -> T {
            declassify((&raw mut v).cast(), size_of_val(&v));
            v
        }
    } else {
        #[inline]
        pub(crate) fn secret_slice<T>(_v: &[T]) {}

        #[inline]
        pub(crate) fn public_slice<T>(_v: &[T]) {}

        #[inline]
        #[must_use]
        pub(crate) fn into_secret<T>(v: T) -> T { v }

        #[inline]
        #[must_use]
        pub(crate) fn into_public<T>(v: T) -> T { v }
    }
}

#[cfg(all(test, feature = "__ctgrind"))]
mod tests {
    use crabgrind::valgrind::{RunningMode, running_mode};

    /// Only `admin/ctgrind` builds `__ctgrind`, to run under valgrind. Run
    /// any other way, as by a target runner it did not replace, or built
    /// against crabgrind's stub header, whose requests do nothing, the
    /// suite would pass with no secret checked.
    #[test]
    fn runs_under_valgrind() {
        assert!(matches!(running_mode(), RunningMode::Valgrind));
    }
}
