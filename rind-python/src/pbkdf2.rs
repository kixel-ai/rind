// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0
use std::num::NonZeroU32;

use pyo3::exceptions::PyValueError;
use pyo3::prelude::*;
use pyo3::types::PyBytes;
use rind::pbkdf2;

use crate::{Bytes, algorithm, constants, error, submodule};

algorithm!(
    /// A PBKDF2 algorithm.
    Algorithm(pbkdf2::Algorithm) as "pyrind.pbkdf2"."Algorithm" {}
);

fn iterations_of(iterations: u32) -> PyResult<NonZeroU32> {
    NonZeroU32::new(iterations).ok_or_else(|| PyValueError::new_err("iterations must be at least 1"))
}

/// A password keyed into HMAC once, which derives keys for any salt and
/// iteration count.
///
/// Both calls release the GIL while they run.
#[pyclass(frozen, module = "pyrind.pbkdf2")]
struct Secret(Box<pbkdf2::Secret>);

#[pymethods]
impl Secret {
    /// Keys `algorithm` with `secret`, a password of any length.
    #[new]
    fn new(algorithm: &Bound<'_, Algorithm>, secret: Bytes<'_>) -> Self {
        Self(Box::new(pbkdf2::Secret::new(algorithm.get().inner, &secret)))
    }

    /// Derives `length` bytes for `salt` with `iterations`.
    fn derive<'py>(
        &self,
        py: Python<'py>,
        iterations: u32,
        salt: Bytes<'_>,
        length: usize,
    ) -> PyResult<Bound<'py, PyBytes>> {
        let iterations = iterations_of(iterations)?;
        PyBytes::new_with(py, length, |out| {
            py.detach(|| self.0.derive(iterations, &salt, out))
                .map_err(error)
        })
    }

    /// Checks in constant time that `previously_derived` is what `derive`
    /// returns for `salt` and `iterations`; raises `BadSignature` otherwise.
    fn verify(
        &self,
        py: Python<'_>,
        iterations: u32,
        salt: Bytes<'_>,
        previously_derived: Bytes<'_>,
    ) -> PyResult<()> {
        let iterations = iterations_of(iterations)?;
        py.detach(|| self.0.verify(iterations, &salt, &previously_derived))
            .map_err(error)
    }
}

pub(crate) fn register(m: &Bound<'_, PyModule>) -> PyResult<()> {
    m.add_class::<Algorithm>()?;
    m.add_class::<Secret>()?;
    constants!(m, Algorithm, "pyrind.pbkdf2", {
        PBKDF2_HMAC_SHA256 => &pbkdf2::PBKDF2_HMAC_SHA256,
        PBKDF2_HMAC_SHA384 => &pbkdf2::PBKDF2_HMAC_SHA384,
        PBKDF2_HMAC_SHA512 => &pbkdf2::PBKDF2_HMAC_SHA512,
    });
    submodule(m, "pyrind.pbkdf2.legacy", |legacy| {
        constants!(legacy, Algorithm, "pyrind.pbkdf2.legacy", {
            PBKDF2_HMAC_SHA1 => &pbkdf2::legacy::PBKDF2_HMAC_SHA1,
        });
        Ok(())
    })
}
