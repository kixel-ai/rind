// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0
//! Reading and writing the `OSSL_PARAM` arrays OpenSSL passes, as its
//! `params.c` does for the types this provider takes and gives.
//!
//! OpenSSL vouches for an array's shape: each parameter's data is valid for
//! its size, and a null key ends it. Its values are the caller's, and are
//! checked as hostile.

use core::ffi::{CStr, c_int};
use core::marker::PhantomData;
use core::slice;

use crate::ffi::{INTEGER, OCTET_STRING, Param, UNSIGNED_INTEGER, UTF8_PTR, UTF8_STRING};

/// A parameter array OpenSSL passes in, or none.
#[derive(Clone, Copy)]
pub(crate) struct Params<'a> {
    first: *const Param,
    _array: PhantomData<&'a Param>,
}

impl<'a> Params<'a> {
    /// # Safety
    ///
    /// `first` is null or the start of a parameter array valid for `'a`.
    pub(crate) unsafe fn new(first: *const Param) -> Self {
        Self {
            first,
            _array: PhantomData,
        }
    }

    /// The first parameter named `name`, as `OSSL_PARAM_locate_const` finds it.
    pub(crate) fn find(self, name: &CStr) -> Option<&'a Param> {
        // SAFETY: the array is valid for `'a`, per `new`.
        unsafe { locate(self.first, name).as_ref() }
    }
}

/// The first parameter named `name` in the array at `first`, or null.
///
/// # Safety
///
/// `first` is null or the start of a parameter array.
unsafe fn locate(first: *const Param, name: &CStr) -> *const Param {
    let mut at = first;
    while !at.is_null() {
        // SAFETY: `at` is in the array, which has not ended yet.
        let key = unsafe { (*at).key };
        if key.is_null() {
            break;
        }
        // SAFETY: a parameter's key is a C string.
        if unsafe { CStr::from_ptr(key) } == name {
            return at;
        }
        // SAFETY: the array goes on to its terminator.
        at = unsafe { at.add(1) };
    }
    core::ptr::null()
}

/// A parameter array OpenSSL passes for this provider to fill, or none.
pub(crate) struct ParamsMut<'a> {
    first: *mut Param,
    _array: PhantomData<&'a mut Param>,
}

impl<'a> ParamsMut<'a> {
    /// # Safety
    ///
    /// `first` is null or the start of a writable parameter array valid for
    /// `'a`.
    pub(crate) unsafe fn new(first: *mut Param) -> Self {
        Self {
            first,
            _array: PhantomData,
        }
    }

    /// The first parameter named `name`, as `OSSL_PARAM_locate` finds it.
    pub(crate) fn find(&mut self, name: &CStr) -> Option<&mut Param> {
        // SAFETY: the array is valid and writable for `'a`, per `new`, and
        // `self` holds the only access to it.
        unsafe { locate(self.first, name).cast_mut().as_mut() }
    }
}

impl Param {
    /// The bytes of an `OSSL_PARAM_OCTET_STRING`, refused as another type or
    /// without data, as `OSSL_PARAM_get_octet_string` does.
    pub(crate) fn octets(&self) -> Option<&[u8]> {
        if self.data_type != OCTET_STRING || self.data.is_null() {
            return None;
        }
        // SAFETY: a parameter's data is valid for its size.
        Some(unsafe { slice::from_raw_parts(self.data.cast::<u8>(), self.data_size) })
    }

    /// The bytes of an `OSSL_PARAM_UTF8_STRING` up to its first NUL, refused
    /// as another type or without data.
    pub(crate) fn utf8(&self) -> Option<&[u8]> {
        if self.data_type != UTF8_STRING || self.data.is_null() {
            return None;
        }
        // SAFETY: a parameter's data is valid for its size.
        let bytes = unsafe { slice::from_raw_parts(self.data.cast::<u8>(), self.data_size) };
        Some(match bytes.iter().position(|&b| b == 0) {
            Some(end) => &bytes[..end],
            None => bytes,
        })
    }

    /// Sets an integer parameter of four or eight bytes, as
    /// `OSSL_PARAM_set_int` does; a null `data` asks only the size.
    pub(crate) fn set_int(&mut self, value: c_int) -> bool {
        let unsigned = match self.data_type {
            INTEGER => false,
            UNSIGNED_INTEGER if value >= 0 => true,
            _ => {
                self.return_size = 0;
                return false;
            }
        };
        self.return_size = 4;
        if self.data.is_null() {
            return true;
        }
        // SAFETY: a parameter's data is valid for its size, which each arm
        // checks, and OpenSSL aligns integer data for its type.
        unsafe {
            match (self.data_size, unsigned) {
                (4, false) => self.data.cast::<i32>().write(value),
                (4, true) => self.data.cast::<u32>().write(value as u32),
                (8, false) => self.data.cast::<i64>().write(value.into()),
                (8, true) => self.data.cast::<u64>().write(value as u64),
                _ => return false,
            }
        }
        self.return_size = self.data_size;
        true
    }

    /// Sets an `OSSL_PARAM_OCTET_STRING`, as `OSSL_PARAM_set_octet_string`
    /// does; a null `data` asks only the size.
    pub(crate) fn set_octets(&mut self, value: &[u8]) -> bool {
        self.set_string(value, OCTET_STRING)
    }

    /// Sets an `OSSL_PARAM_UTF8_STRING`, NUL-terminated if it fits, as
    /// `OSSL_PARAM_set_utf8_string` does.
    pub(crate) fn set_utf8(&mut self, value: &CStr) -> bool {
        self.set_string(value.to_bytes(), UTF8_STRING)
    }

    fn set_string(&mut self, value: &[u8], data_type: u32) -> bool {
        self.return_size = value.len();
        if self.data.is_null() {
            return true;
        }
        if self.data_type != data_type || self.data_size < value.len() {
            return false;
        }
        // SAFETY: a parameter's data is valid for its size, which holds
        // `value`, and is the caller's own buffer, apart from `value`.
        unsafe {
            core::ptr::copy_nonoverlapping(value.as_ptr(), self.data.cast::<u8>(), value.len());
            if data_type == UTF8_STRING && self.data_size > value.len() {
                self.data.cast::<u8>().add(value.len()).write(0);
            }
        }
        true
    }

    /// Points an `OSSL_PARAM_UTF8_PTR` at `value`, as
    /// `OSSL_PARAM_set_utf8_ptr` does.
    pub(crate) fn set_utf8_ptr(&mut self, value: &'static CStr) -> bool {
        self.return_size = value.to_bytes().len();
        if self.data_type != UTF8_PTR {
            return false;
        }
        if !self.data.is_null() {
            // SAFETY: a `UTF8_PTR` parameter's data holds a pointer, which
            // OpenSSL aligns.
            unsafe {
                self.data
                    .cast::<*const core::ffi::c_char>()
                    .write(value.as_ptr())
            };
        }
        true
    }
}

#[cfg(test)]
mod tests {
    use core::ffi::c_void;

    use super::*;

    fn param(key: &'static CStr, data_type: u32, data: *mut c_void, data_size: usize) -> Param {
        Param {
            key: key.as_ptr(),
            data_type,
            data,
            data_size,
            return_size: crate::ffi::UNMODIFIED,
        }
    }

    #[test]
    fn find_takes_the_first_match() {
        let mut first = [1u8];
        let mut second = [2u8];
        let params = [
            param(c"pub", OCTET_STRING, first.as_mut_ptr().cast(), 1),
            param(c"pub", OCTET_STRING, second.as_mut_ptr().cast(), 1),
            Param::END,
        ];
        // SAFETY: the array is terminated and outlives its use.
        let params = unsafe { Params::new(params.as_ptr()) };
        assert_eq!(params.find(c"pub").unwrap().octets(), Some(&[1u8][..]));
        assert!(params.find(c"priv").is_none());
        // SAFETY: a null array is none.
        let none = unsafe { Params::new(core::ptr::null()) };
        assert!(none.find(c"pub").is_none());
    }

    #[test]
    fn reads_refuse_another_type() {
        let mut data = *b"x25519\0junk";
        let utf8 = param(c"group", UTF8_STRING, data.as_mut_ptr().cast(), data.len());
        assert_eq!(utf8.utf8(), Some(&b"x25519"[..]));
        assert_eq!(utf8.octets(), None);
        let missing = param(c"pub", OCTET_STRING, core::ptr::null_mut(), 0);
        assert_eq!(missing.octets(), None);
    }

    #[test]
    fn set_int_fits_four_or_eight_bytes() {
        let mut four = 0i32;
        let mut p = param(c"bits", INTEGER, (&raw mut four).cast(), 4);
        assert!(p.set_int(253));
        assert_eq!((four, p.return_size), (253, 4));

        let mut eight = 0u64;
        let mut p = param(c"bits", UNSIGNED_INTEGER, (&raw mut eight).cast(), 8);
        assert!(p.set_int(253));
        assert_eq!((eight, p.return_size), (253, 8));
        assert!(!p.set_int(-1));

        let mut two = 0u16;
        let mut p = param(c"bits", INTEGER, (&raw mut two).cast(), 2);
        assert!(!p.set_int(1));

        let mut p = param(c"bits", OCTET_STRING, (&raw mut four).cast(), 4);
        assert!(!p.set_int(1));
    }

    #[test]
    fn set_octets_asks_size_then_fills() {
        let mut p = param(c"pub", OCTET_STRING, core::ptr::null_mut(), 0);
        assert!(p.set_octets(&[7; 32]));
        assert_eq!(p.return_size, 32);

        let mut short = [0u8; 31];
        let mut p = param(c"pub", OCTET_STRING, short.as_mut_ptr().cast(), 31);
        assert!(!p.set_octets(&[7; 32]));

        let mut buf = [0u8; 40];
        let mut p = param(c"pub", OCTET_STRING, buf.as_mut_ptr().cast(), 40);
        assert!(p.set_octets(&[7; 32]));
        assert_eq!(p.return_size, 32);
        assert_eq!((&buf[..32], buf[32]), (&[7; 32][..], 0));
    }

    #[test]
    fn set_utf8_terminates_when_it_fits() {
        let mut buf = [0xffu8; 4];
        let mut p = param(c"mandatory-digest", UTF8_STRING, buf.as_mut_ptr().cast(), 4);
        assert!(p.set_utf8(c""));
        assert_eq!((buf[0], p.return_size), (0, 0));
    }
}
