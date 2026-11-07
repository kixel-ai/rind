//! The little DER that aws-lc-rs's API needs rind-aws-lc-rs to read itself:
//! an RSA public key's fields, in PKCS#1 or a `SubjectPublicKeyInfo`. Every
//! byte read here is public.

use alloc::vec::Vec;

use crate::error::Unspecified;

const INTEGER: u8 = 0x02;
const BIT_STRING: u8 = 0x03;
const SEQUENCE: u8 = 0x30;

/// `rsaEncryption` with its `NULL` parameters, as an `AlgorithmIdentifier`'s
/// contents.
const RSA_ENCRYPTION: &[u8] = &[
    0x06, 0x09, 0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x01, 0x05, 0x00,
];

/// Reads a DER element tagged `tag` and returns its contents, refusing a
/// length that is not minimally encoded or takes over two bytes.
fn read<'a>(
    input: &mut untrusted::Reader<'a>,
    tag: u8,
) -> Result<untrusted::Input<'a>, Unspecified> {
    if input.read_byte()? != tag {
        return Err(Unspecified);
    }
    let len = match input.read_byte()? {
        len @ 0..=0x7f => usize::from(len),
        0x81 => match input.read_byte()? {
            len @ 0x80..=0xff => usize::from(len),
            _ => return Err(Unspecified),
        },
        0x82 => {
            let high = input.read_byte()?;
            let low = input.read_byte()?;
            match u16::from_be_bytes([high, low]) {
                len @ 0x100..=0xffff => usize::from(len),
                _ => return Err(Unspecified),
            }
        }
        _ => return Err(Unspecified),
    };
    Ok(input.read_bytes(len)?)
}

/// Reads a positive INTEGER and returns its magnitude, without the zero byte
/// DER adds when its top bit is set.
fn positive_integer<'a>(input: &mut untrusted::Reader<'a>) -> Result<&'a [u8], Unspecified> {
    let value = read(input, INTEGER)?.as_slice_less_safe();
    match value {
        [] | [0x80..=0xff, ..] => Err(Unspecified),
        [0, rest @ ..] => match rest {
            [0x80..=0xff, ..] => Ok(rest),
            _ => Err(Unspecified),
        },
        _ => Ok(value),
    }
}

/// Reads a PKCS#1 `RSAPublicKey`, returning the modulus and the exponent.
pub(crate) fn rsa_public_key(der: &[u8]) -> Result<(&[u8], &[u8]), Unspecified> {
    untrusted::Input::from(der).read_all(Unspecified, |input| {
        read(input, SEQUENCE)?.read_all(Unspecified, |input| {
            Ok((positive_integer(input)?, positive_integer(input)?))
        })
    })
}

/// The PKCS#1 `RSAPublicKey` in an `rsaEncryption` `SubjectPublicKeyInfo`.
pub(crate) fn rsa_spki(der: &[u8]) -> Result<&[u8], Unspecified> {
    untrusted::Input::from(der).read_all(Unspecified, |input| {
        read(input, SEQUENCE)?.read_all(Unspecified, |input| {
            if read(input, SEQUENCE)?.as_slice_less_safe() != RSA_ENCRYPTION {
                return Err(Unspecified);
            }
            match read(input, BIT_STRING)?.as_slice_less_safe() {
                [0, key @ ..] => Ok(key),
                _ => Err(Unspecified),
            }
        })
    })
}

/// Whether `der` is a `SubjectPublicKeyInfo` rather than PKCS#1: its first
/// field is a `SEQUENCE`, where PKCS#1's is an `INTEGER`.
pub(crate) fn is_spki(der: &[u8]) -> bool {
    let mut input = untrusted::Reader::new(untrusted::Input::from(der));
    read(&mut input, SEQUENCE)
        .map(|body| body.as_slice_less_safe().first() == Some(&SEQUENCE))
        .unwrap_or(false)
}

/// The bit length of a big-endian magnitude without leading zero bytes.
pub(crate) fn bits(magnitude: &[u8]) -> usize {
    8 * magnitude.len()
        - magnitude
            .first()
            .map_or(8, |top| top.leading_zeros() as usize)
}

/// Appends a DER element tagged `tag` holding `contents`.
fn write(output: &mut Vec<u8>, tag: u8, contents: &[u8]) {
    output.push(tag);
    match contents.len() {
        len @ 0..=0x7f => output.push(len as u8),
        len @ 0x80..=0xff => output.extend_from_slice(&[0x81, len as u8]),
        len => {
            let [high, low] = u16::try_from(len).unwrap_or(u16::MAX).to_be_bytes();
            output.extend_from_slice(&[0x82, high, low]);
        }
    }
    output.extend_from_slice(contents);
}

/// Encodes a positive INTEGER's contents from a magnitude without leading
/// zero bytes, adding the zero byte DER needs when its top bit is set.
fn integer(output: &mut Vec<u8>, magnitude: &[u8]) {
    let mut contents = Vec::with_capacity(magnitude.len() + 1);
    if magnitude.first().is_none_or(|top| top & 0x80 != 0) {
        contents.push(0);
    }
    contents.extend_from_slice(magnitude);
    write(output, INTEGER, &contents);
}

/// Encodes a PKCS#1 `RSAPublicKey` from its modulus and exponent.
pub(crate) fn rsa_public_key_encode(n: &[u8], e: &[u8]) -> Vec<u8> {
    let mut body = Vec::with_capacity(n.len() + e.len() + 8);
    integer(&mut body, n);
    integer(&mut body, e);
    let mut output = Vec::with_capacity(body.len() + 4);
    write(&mut output, SEQUENCE, &body);
    output
}

/// Wraps a PKCS#1 `RSAPublicKey` in an `rsaEncryption`
/// `SubjectPublicKeyInfo`.
pub(crate) fn rsa_spki_encode(pkcs1: &[u8]) -> Vec<u8> {
    let mut bits = Vec::with_capacity(pkcs1.len() + 1);
    bits.push(0);
    bits.extend_from_slice(pkcs1);
    let mut body = Vec::with_capacity(bits.len() + 24);
    write(&mut body, SEQUENCE, RSA_ENCRYPTION);
    write(&mut body, BIT_STRING, &bits);
    let mut output = Vec::with_capacity(body.len() + 4);
    write(&mut output, SEQUENCE, &body);
    output
}
