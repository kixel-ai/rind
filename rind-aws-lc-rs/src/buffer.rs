//! The byte buffer behind each serialized form, as aws-lc-rs has it.

use alloc::borrow::Cow;
use alloc::vec::Vec;
use core::fmt;
use core::marker::PhantomData;

use zeroize::Zeroize;

/// Bytes exposed by an encoding, wiped on drop when owned, since some hold a
/// private key. `T` tells the encodings apart.
pub struct Buffer<'a, T>(Cow<'a, [u8]>, PhantomData<T>);

impl<T> Buffer<'_, T> {
    pub(crate) fn new(owned: Vec<u8>) -> Self {
        Buffer(Cow::Owned(owned), PhantomData)
    }
}

impl<T> Drop for Buffer<'_, T> {
    fn drop(&mut self) {
        if let Cow::Owned(bytes) = &mut self.0 {
            bytes.zeroize();
        }
    }
}

impl<T> fmt::Debug for Buffer<'_, T> {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str("Buffer(...)")
    }
}

impl<T> AsRef<[u8]> for Buffer<'_, T> {
    fn as_ref(&self) -> &[u8] {
        &self.0
    }
}

/// Declares serialized forms, each a [`Buffer`] of its own type.
macro_rules! generated_encodings {
    ($(($name:ident, $name_type:ident)),* $(,)?) => {
        mod buffer_type {
            $(
                pub struct $name_type {
                    _priv: (),
                }
            )*
        }
        $(
            /// Serialized bytes.
            pub struct $name<'a>($crate::buffer::Buffer<'a, buffer_type::$name_type>);

            impl<'a> core::ops::Deref for $name<'a> {
                type Target = $crate::buffer::Buffer<'a, buffer_type::$name_type>;

                fn deref(&self) -> &Self::Target {
                    &self.0
                }
            }

            impl $name<'static> {
                #[allow(dead_code)]
                pub(crate) fn new(owned: alloc::vec::Vec<u8>) -> Self {
                    Self($crate::buffer::Buffer::new(owned))
                }
            }

            impl core::fmt::Debug for $name<'_> {
                fn fmt(&self, f: &mut core::fmt::Formatter<'_>) -> core::fmt::Result {
                    f.debug_struct(stringify!($name)).finish()
                }
            }

            impl<'a> From<$crate::buffer::Buffer<'a, buffer_type::$name_type>> for $name<'a> {
                fn from(value: $crate::buffer::Buffer<'a, buffer_type::$name_type>) -> Self {
                    Self(value)
                }
            }
        )*
    };
}
pub(crate) use generated_encodings;
