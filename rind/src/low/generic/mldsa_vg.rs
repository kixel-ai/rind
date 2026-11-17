// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

//! Where pyca/verified-garbage's ML-DSA signing does not run, or was slower
//! than rind's: proofs no CPU can give, so callers keep rind's arithmetic.

/// Proof that VG's signing runs here, which it never does.
#[derive(Clone, Copy, Debug)]
pub(crate) enum Sign {}

impl Sign {
    pub(crate) fn check() -> Option<Self> {
        None
    }

    pub(crate) fn sign44(self, _: &[u8; 2560], _: &[u8; 64], _: &[u8; 32]) -> Option<[u8; 2420]> {
        match self {}
    }

    pub(crate) fn sign65(self, _: &[u8; 4032], _: &[u8; 64], _: &[u8; 32]) -> Option<[u8; 3309]> {
        match self {}
    }

    pub(crate) fn sign87(self, _: &[u8; 4896], _: &[u8; 64], _: &[u8; 32]) -> Option<[u8; 4627]> {
        match self {}
    }
}
