// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

//! A public key's `SubjectPublicKeyInfo` (RFC 5280), which names its
//! algorithm.

use super::asn1::{self, Type, pkix};
use crate::error::{Error, KeyFormatError};

/// Decodes a `SubjectPublicKeyInfo` naming one of `algorithms` with
/// `parameters`, and returns the key it holds.
pub(crate) fn decode<'a>(
    der: &'a [u8],
    algorithms: &[&asn1::ObjectId],
    parameters: Option<asn1::Any<'_>>,
) -> Result<&'a [u8], Error> {
    let spki = pkix::SubjectPublicKeyInfo::from_bytes(der).map_err(KeyFormatError::Asn1)?;
    match algorithms.contains(&&spki.algorithm.algorithm) && spki.algorithm.parameters == parameters
    {
        true => Ok(spki.subjectPublicKey.as_octets()),
        false => Err(KeyFormatError::MismatchedSpkiAlgorithm.into()),
    }
}

/// Encodes `key` as a `SubjectPublicKeyInfo` naming `algorithm` with
/// `parameters`.
///
/// The encoding is written to the start of `output`, and the used span is
/// returned. [`Error::WrongLength`] is returned if `output` is too short.
pub(crate) fn encode<'a>(
    key: &[u8],
    algorithm: &asn1::ObjectId,
    parameters: Option<asn1::Any<'_>>,
    output: &'a mut [u8],
) -> Result<&'a [u8], Error> {
    let spki = pkix::SubjectPublicKeyInfo {
        algorithm: pkix::AlgorithmIdentifier {
            algorithm: algorithm.clone(),
            parameters,
        },
        subjectPublicKey: asn1::BitString::new(key),
    };
    let len = spki
        .encode(&mut asn1::Encoder::new(output))
        .map_err(|_| Error::WrongLength)?;
    Ok(&output[..len])
}
