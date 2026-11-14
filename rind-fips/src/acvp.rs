// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

//! The deterministic forms of the module's randomized services, which ACVP
//! drives with randomness of its own, from the module's ACVP build: for
//! `rind-acvp` only.
//!
//! FIPS 203 and 204 allow these forms only for testing, so the `__acvp`
//! feature that builds them is for testing only; no other build of the
//! module has them.

use ids::acvp as op;

use crate::Error;
use crate::ffi::{Bytes, Status, check, ids};
use crate::kem;
use crate::signature::sign::MlDsaParameterSet;

unsafe extern "C" {
    fn rind_fips_acvp(
        op: u32,
        param: u32,
        args: *const Bytes,
        nargs: usize,
        out: *mut u8,
        cap: usize,
        len: *mut usize,
    ) -> Status;
}

/// Runs `op` of `param` on `args`, into `out`, returning the length used.
fn call(op: u32, param: u32, args: &[&[u8]], out: &mut [u8]) -> Result<usize, Error> {
    let list = Bytes::list(args);
    let mut len = 0;
    // SAFETY: each byte string in `list` is borrowed from `args`, `out` is
    // writable for its length, and `len` is writable.
    check(unsafe {
        rind_fips_acvp(
            op,
            param,
            list.as_ptr(),
            list.len(),
            out.as_mut_ptr(),
            out.len(),
            &mut len,
        )
    })?;
    Ok(len)
}

/// Runs `op` of `param` on `args` for an output of up to `cap` bytes.
fn call_vec(op: u32, param: u32, args: &[&[u8]], cap: usize) -> Result<Vec<u8>, Error> {
    let mut out = vec![0; cap];
    let len = call(op, param, args, &mut out)?;
    out.truncate(len);
    Ok(out)
}

/// `out` split at `at`.
fn split(mut out: Vec<u8>, at: usize) -> (Vec<u8>, Vec<u8>) {
    let tail = out.split_off(at);
    (out, tail)
}

/// One prediction-resistant generate's inputs: the additional input and the
/// entropy it reseeds with first.
#[derive(Clone, Copy, Debug)]
pub struct Generate<'a> {
    /// The reseed's additional input.
    pub additional_input: &'a [u8],
    /// The reseed's entropy input.
    pub entropy: &'a [u8],
}

/// ACVP's prediction-resistance test of the module's DRBG, HMAC_DRBG over
/// SHA-512: instantiates with `entropy`, `nonce`, and `personalization`,
/// runs both `generates`, and writes the second's output to `out`.
pub fn drbg(
    entropy: &[u8],
    nonce: &[u8],
    personalization: &[u8],
    generates: [Generate<'_>; 2],
    out: &mut [u8],
) -> Result<(), Error> {
    let [first, second] = generates;
    call(
        op::DRBG,
        0,
        &[
            entropy,
            nonce,
            personalization,
            first.additional_input,
            first.entropy,
            second.additional_input,
            second.entropy,
        ],
        out,
    )
    .map(drop)
}

/// The lengths of the encapsulation key, decapsulation key, ciphertext, and
/// shared secret of `algorithm`.
fn ml_kem_lens(algorithm: &kem::Algorithm) -> Result<[usize; 4], Error> {
    match algorithm.id {
        ids::kem::ML_KEM_768 => Ok([1184, 2400, 1088, 32]),
        _ => Err(Error::Unsupported),
    }
}

/// FIPS 203's `ML-KEM.KeyGen_internal` from seeds `d` and `z`: the
/// encapsulation key and the expanded decapsulation key.
pub fn ml_kem_key_gen(
    algorithm: &kem::Algorithm,
    d: &[u8],
    z: &[u8],
) -> Result<(Vec<u8>, Vec<u8>), Error> {
    let [ek, dk, ..] = ml_kem_lens(algorithm)?;
    let out = call_vec(op::ML_KEM_KEY_GEN, algorithm.id, &[d, z], ek + dk)?;
    Ok(split(out, ek))
}

/// FIPS 203's `ML-KEM.Encaps_internal` of message `m` to encapsulation key
/// `ek`, after its input check: the ciphertext and the shared secret.
pub fn ml_kem_encap(
    algorithm: &kem::Algorithm,
    ek: &[u8],
    m: &[u8],
) -> Result<(Vec<u8>, Vec<u8>), Error> {
    let [.., ciphertext, secret] = ml_kem_lens(algorithm)?;
    let out = call_vec(
        op::ML_KEM_ENCAP,
        algorithm.id,
        &[ek, m],
        ciphertext + secret,
    )?;
    Ok(split(out, ciphertext))
}

/// FIPS 203's `ML-KEM.Decaps_internal` of `ciphertext` with expanded
/// decapsulation key `dk`, after their input checks: the shared secret.
pub fn ml_kem_decap(
    algorithm: &kem::Algorithm,
    dk: &[u8],
    ciphertext: &[u8],
) -> Result<Vec<u8>, Error> {
    let [.., secret] = ml_kem_lens(algorithm)?;
    call_vec(op::ML_KEM_DECAP, algorithm.id, &[dk, ciphertext], secret)
}

/// FIPS 203's encapsulation key check.
pub fn ml_kem_check_encapsulation_key(algorithm: &kem::Algorithm, ek: &[u8]) -> Result<(), Error> {
    call(
        op::ML_KEM_CHECK_ENCAPSULATION_KEY,
        algorithm.id,
        &[ek],
        &mut [],
    )
    .map(drop)
}

/// FIPS 203's decapsulation key check.
pub fn ml_kem_check_decapsulation_key(algorithm: &kem::Algorithm, dk: &[u8]) -> Result<(), Error> {
    call(
        op::ML_KEM_CHECK_DECAPSULATION_KEY,
        algorithm.id,
        &[dk],
        &mut [],
    )
    .map(drop)
}

/// What an ML-DSA signature is over, by the interface ACVP tests.
#[derive(Clone, Copy, Debug)]
pub enum MlDsaMessage<'a> {
    /// FIPS 204's external interface, pure ML-DSA: a message under a
    /// context of at most 255 bytes.
    External {
        /// The context string.
        context: &'a [u8],
        /// The message.
        message: &'a [u8],
    },
    /// The internal interface's `M'`, taken as is.
    Internal(&'a [u8]),
    /// The message representative `mu`, computed elsewhere.
    Mu(&'a [u8]),
}

impl<'a> MlDsaMessage<'a> {
    /// The interface's byte, the message, and the context.
    fn args(self) -> ([u8; 1], &'a [u8], &'a [u8]) {
        use ids::ml_dsa_interface::*;
        match self {
            Self::External { context, message } => ([EXTERNAL], message, context),
            Self::Internal(message) => ([INTERNAL], message, &[]),
            Self::Mu(mu) => ([MU], mu, &[]),
        }
    }
}

/// The public key, expanded private key, and signature lengths of `P`.
fn ml_dsa_lens<P: MlDsaParameterSet>() -> [usize; 3] {
    match P::ID {
        ids::ml_dsa::ML_DSA_44 => [1312, 2560, 2420],
        ids::ml_dsa::ML_DSA_65 => [1952, 4032, 3309],
        _ => [2592, 4896, 4627],
    }
}

/// FIPS 204's `ML-DSA.KeyGen_internal` from `seed`: the public key and the
/// expanded private key.
pub fn ml_dsa_key_gen<P: MlDsaParameterSet>(seed: &[u8]) -> Result<(Vec<u8>, Vec<u8>), Error> {
    let [pk, sk, _] = ml_dsa_lens::<P>();
    let out = call_vec(op::ML_DSA_KEY_GEN, P::ID, &[seed], pk + sk)?;
    Ok(split(out, pk))
}

/// FIPS 204's `ML-DSA.Sign_internal` with expanded private key `sk` over
/// `message`, with randomness `rnd`, all zeros for the deterministic variant.
pub fn ml_dsa_sign<P: MlDsaParameterSet>(
    sk: &[u8],
    message: MlDsaMessage<'_>,
    rnd: &[u8],
) -> Result<Vec<u8>, Error> {
    let (interface, message, context) = message.args();
    let [.., len] = ml_dsa_lens::<P>();
    call_vec(
        op::ML_DSA_SIGN,
        P::ID,
        &[sk, rnd, &interface, message, context],
        len,
    )
}

/// FIPS 204's `ML-DSA.Verify_internal` of `signature` over `message` under
/// public key `pk`.
pub fn ml_dsa_verify<P: MlDsaParameterSet>(
    pk: &[u8],
    message: MlDsaMessage<'_>,
    signature: &[u8],
) -> Result<(), Error> {
    let (interface, message, context) = message.args();
    call(
        op::ML_DSA_VERIFY,
        P::ID,
        &[pk, signature, &interface, message, context],
        &mut [],
    )
    .map(drop)
}
