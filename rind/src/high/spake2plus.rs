// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

//! SPAKE2+ on P-256 (RFC 9383 and Matter's draft-01 key schedule).

use core::fmt;

use super::{digest, hkdf, hmac};
use crate::error::{Error, KeyFormatError};
use crate::low::{Entry, Zeroable, ct, ct_equal, zeroise_value};
use crate::mid::p256::{Affine, Scalar};
use crate::mid::rng::{RandomSource, SystemRandom};

/// How many bytes of context or identity one side may pass.
const MAX_LABEL: usize = 1024;

/// RFC 9383's P-256 point M, SEC1 compressed.
const M_COMPRESSED: [u8; 33] = [
    0x02, 0x88, 0x6e, 0x2f, 0x97, 0xac, 0xe4, 0x6e, 0x55, 0xba, 0x9d, 0xd7, 0x24, 0x25, 0x79, 0xf2,
    0x99, 0x3b, 0x64, 0xe1, 0x6e, 0xf3, 0xdc, 0xab, 0x95, 0xaf, 0xd4, 0x97, 0x33, 0x3d, 0x8f, 0xa1,
    0x2f,
];

/// RFC 9383's P-256 point N, SEC1 compressed.
const N_COMPRESSED: [u8; 33] = [
    0x03, 0xd8, 0xbb, 0xd6, 0xc6, 0x39, 0xc6, 0x29, 0x37, 0xb0, 0x4d, 0x99, 0x7f, 0x38, 0xc3, 0x77,
    0x07, 0x19, 0xc6, 0x29, 0xd7, 0x01, 0x4d, 0x49, 0xa2, 0x4b, 0x4f, 0x98, 0xba, 0xa1, 0x29, 0x2b,
    0x49,
];

/// Which key schedule a [`Suite`] runs. The transcript is the same for both.
#[derive(Clone, Copy, Debug)]
enum Schedule {
    /// RFC 9383: HKDF over the whole transcript hash.
    Rfc9383,
    /// draft-bar-cfrg-spake2plus-01: the transcript hash splits into Ka and Ke.
    Draft01,
}

/// A SPAKE2+ ciphersuite. Only this module's constants build one.
///
/// [`RFC9383`] and [`MATTER_PASE`] are the same type. A prover and a verifier
/// given different suites still exchange shares, and [`ProverAwaiting::finish`]
/// returns [`Error::BadSignature`].
#[derive(Clone, Copy, Debug)]
pub struct Suite {
    schedule: Schedule,
}

/// RFC 9383's P-256, SHA-256, HKDF-SHA256, HMAC-SHA256 suite.
pub static RFC9383: Suite = Suite {
    schedule: Schedule::Rfc9383,
};

/// Matter PASE: draft-bar-cfrg-spake2plus-01's P-256 SHA-256 suite.
///
/// The group operations, M, N, and the transcript match [`RFC9383`]. The key
/// schedule splits the transcript hash instead of feeding it to HKDF.
pub static MATTER_PASE: Suite = Suite {
    schedule: Schedule::Draft01,
};

/// A party's share, an uncompressed P-256 point.
#[derive(Clone, Copy, PartialEq, Eq)]
pub struct Share([u8; Affine::BYTES]);

impl Share {
    /// The length of an uncompressed share, 65 bytes.
    pub const BYTES: usize = Affine::BYTES;

    /// Decodes `bytes` as an uncompressed point on the curve.
    ///
    /// Fails with [`Error::KeyRejected`] when `bytes` is not that encoding of
    /// a point on P-256.
    pub fn from_bytes(bytes: &[u8]) -> Result<Self, Error> {
        let _entry = Entry::new_public();
        let point = Affine::from_uncompressed(bytes)?;
        let encoded = point.to_uncompressed();
        if encoded.as_slice() != bytes {
            return Err(KeyFormatError::NotOnCurve.into());
        }
        Ok(Self(encoded))
    }
}

impl AsRef<[u8]> for Share {
    fn as_ref(&self) -> &[u8] {
        &self.0
    }
}

impl fmt::Debug for Share {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_tuple("Share").field(&self.0).finish()
    }
}

/// A key-confirmation tag, the 32-byte HMAC-SHA256.
#[derive(Clone, Copy, PartialEq, Eq)]
pub struct Confirm([u8; 32]);

impl Confirm {
    /// The length of a confirmation tag, 32 bytes.
    pub const BYTES: usize = 32;

    /// Copies `bytes` when they are [`Self::BYTES`] long.
    ///
    /// Fails with [`Error::WrongLength`] otherwise.
    pub fn from_bytes(bytes: &[u8]) -> Result<Self, Error> {
        let bytes: [u8; Self::BYTES] = bytes.try_into().map_err(|_| Error::WrongLength)?;
        Ok(Self(bytes))
    }
}

impl AsRef<[u8]> for Confirm {
    fn as_ref(&self) -> &[u8] {
        &self.0
    }
}

impl fmt::Debug for Confirm {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_tuple("Confirm").field(&self.0).finish()
    }
}

/// The shared key. RFC 9383's is 32 bytes. Matter's is 16.
pub struct SharedKey {
    bytes: [u8; 32],
    len: u8,
}

impl SharedKey {
    fn new(bytes: &[u8]) -> Self {
        let mut stored = [0u8; 32];
        stored[..bytes.len()].copy_from_slice(bytes);
        Self {
            bytes: stored,
            len: bytes.len() as u8,
        }
    }
}

impl AsRef<[u8]> for SharedKey {
    fn as_ref(&self) -> &[u8] {
        &self.bytes[..usize::from(self.len)]
    }
}

impl fmt::Debug for SharedKey {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("SharedKey")
            .field("len", &self.len)
            .finish_non_exhaustive()
    }
}

impl Drop for SharedKey {
    fn drop(&mut self) {
        zeroise_value(self);
    }
}

impl Zeroable for SharedKey {}

/// The prover's password scalars `w0` and `w1`, wiped on drop under `wipe`.
pub struct ProverSecrets {
    w0: Scalar,
    w1: Scalar,
}

impl ProverSecrets {
    /// Reduces big-endian `w0` and `w1` mod the group order.
    ///
    /// Each is at most 128 bytes, so a stretch with 64 extra bits past the
    /// order fits. Fails with [`Error::WrongLength`] past that or when empty,
    /// and with [`Error::KeyRejected`] when either reduces to zero.
    pub fn new(w0: &[u8], w1: &[u8]) -> Result<Self, Error> {
        let _entry = Entry::new_secret();
        Ok(Self {
            w0: Scalar::from_be_reduced(w0)?,
            w1: Scalar::from_be_reduced(w1)?,
        })
    }

    /// Picks an ephemeral scalar and returns this prover's share.
    ///
    /// `context`, `id_prover`, and `id_verifier` go into the transcript under
    /// an 8-byte little-endian length, including when empty. Each is at most
    /// 1024 bytes.
    pub fn start(
        self,
        suite: &'static Suite,
        context: &[u8],
        id_prover: &[u8],
        id_verifier: &[u8],
    ) -> Result<(Share, ProverAwaiting), Error> {
        self.start_at(suite, context, id_prover, id_verifier, None)
    }

    fn start_at(
        self,
        suite: &'static Suite,
        context: &[u8],
        id_prover: &[u8],
        id_verifier: &[u8],
        scalar: Option<Scalar>,
    ) -> Result<(Share, ProverAwaiting), Error> {
        let _entry = Entry::new_secret();
        let labels = Labels::new(context, id_prover, id_verifier)?;
        let x = match scalar {
            Some(scalar) => scalar,
            None => random_scalar()?,
        };
        let (m, _) = points()?;
        let share = publish(m.mul(&self.w0).add(Affine::mul_base(&x)))?;
        let state = ProverAwaiting {
            schedule: suite.schedule,
            labels,
            w0: self.w0.copy(),
            w1: self.w1.copy(),
            x,
            share_p: share.0,
        };
        Ok((share, state))
    }
}

impl fmt::Debug for ProverSecrets {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("ProverSecrets").finish_non_exhaustive()
    }
}

impl Drop for ProverSecrets {
    fn drop(&mut self) {
        zeroise_value(self);
    }
}

impl Zeroable for ProverSecrets {}

/// The verifier's record, `w0` and `L = w1 * G`, wiped on drop under `wipe`.
pub struct VerifierRecord {
    w0: Scalar,
    l: Affine,
}

impl VerifierRecord {
    /// Builds a record from `w0` and `w1`, setting `L` to `w1` times the generator.
    ///
    /// The scalar rules are [`ProverSecrets::new`]'s.
    pub fn from_w1(w0: &[u8], w1: &[u8]) -> Result<Self, Error> {
        let _entry = Entry::new_secret();
        let w0 = Scalar::from_be_reduced(w0)?;
        let w1 = Scalar::from_be_reduced(w1)?;
        let l = publish_point(Affine::mul_base(&w1))?;
        Ok(Self { w0, l })
    }

    /// Loads a stored record: reduced `w0`, and uncompressed `l`.
    ///
    /// Fails with [`Error::KeyRejected`] when `l` is not on the curve.
    pub fn from_record(w0: &[u8], l: &[u8]) -> Result<Self, Error> {
        let _entry = Entry::new_secret();
        Ok(Self {
            w0: Scalar::from_be_reduced(w0)?,
            l: Affine::from_uncompressed(l)?,
        })
    }

    /// Answers `prover`'s share with this verifier's share and confirmation.
    ///
    /// The labels are the same strings the prover passed to [`ProverSecrets::start`].
    pub fn start(
        self,
        suite: &'static Suite,
        context: &[u8],
        id_prover: &[u8],
        id_verifier: &[u8],
        prover: &Share,
    ) -> Result<(Share, Confirm, VerifierAwaiting), Error> {
        self.start_at(suite, context, id_prover, id_verifier, prover, None)
    }

    fn start_at(
        self,
        suite: &'static Suite,
        context: &[u8],
        id_prover: &[u8],
        id_verifier: &[u8],
        prover: &Share,
        scalar: Option<Scalar>,
    ) -> Result<(Share, Confirm, VerifierAwaiting), Error> {
        let _entry = Entry::new_secret();
        let labels = Labels::new(context, id_prover, id_verifier)?;
        let y = match scalar {
            Some(scalar) => scalar,
            None => random_scalar()?,
        };
        let (m, n) = points()?;
        let peer = Affine::from_uncompressed(prover.as_ref())?;
        let share_v = publish(n.mul(&self.w0).add(Affine::mul_base(&y)))?;
        let diff = peer.add(m.mul(&self.w0).negate());
        let z = secret_point(diff.mul(&y))?;
        let v = secret_point(self.l.mul(&y))?;
        let keys = schedule_keys(
            suite.schedule,
            &transcript(
                &labels,
                prover.as_ref(),
                share_v.as_ref(),
                z.as_slice(),
                v.as_slice(),
                &self.w0,
            )?,
        )?;
        let confirm_v = mac(keys.verifier_key(), prover.as_ref());
        let confirm_p = mac(keys.prover_key(), share_v.as_ref());
        let mut shared = [0u8; 32];
        shared[..keys.shared().len()].copy_from_slice(keys.shared());
        let state = VerifierAwaiting {
            confirm_p: confirm_p.0,
            shared,
            shared_len: keys.shared().len() as u8,
        };
        Ok((share_v, confirm_v, state))
    }
}

impl fmt::Debug for VerifierRecord {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("VerifierRecord").finish_non_exhaustive()
    }
}

impl Drop for VerifierRecord {
    fn drop(&mut self) {
        zeroise_value(self);
    }
}

impl Zeroable for VerifierRecord {}

/// The prover, between its share and the verifier's confirmation.
pub struct ProverAwaiting {
    schedule: Schedule,
    labels: Labels,
    w0: Scalar,
    w1: Scalar,
    x: Scalar,
    share_p: [u8; Share::BYTES],
}

impl ProverAwaiting {
    /// Checks `confirm`, then returns this prover's confirmation and the shared key.
    ///
    /// Fails with [`Error::BadSignature`] when `confirm` is not the verifier's
    /// tag over this prover's share. The shared key is not returned on failure.
    pub fn finish(
        self,
        verifier: &Share,
        confirm: &Confirm,
    ) -> Result<(Confirm, SharedKey), Error> {
        let _entry = Entry::new_secret();
        let (_, n) = points()?;
        let peer = Affine::from_uncompressed(verifier.as_ref())?;
        let w0 = self.w0.copy();
        let diff = peer.add(n.mul(&w0).negate());
        let z = secret_point(diff.mul(&self.x))?;
        let v = secret_point(diff.mul(&self.w1))?;
        let keys = schedule_keys(
            self.schedule,
            &transcript(
                &self.labels,
                &self.share_p,
                verifier.as_ref(),
                z.as_slice(),
                v.as_slice(),
                &w0,
            )?,
        )?;
        let expect = mac(keys.verifier_key(), &self.share_p);
        let confirm_p = mac(keys.prover_key(), verifier.as_ref());
        let key = SharedKey::new(keys.shared());
        match ct::into_public(ct_equal(expect.as_ref(), confirm.as_ref())) {
            true => Ok((confirm_p, key)),
            false => Err(Error::BadSignature),
        }
    }
}

impl fmt::Debug for ProverAwaiting {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("ProverAwaiting").finish_non_exhaustive()
    }
}

impl Drop for ProverAwaiting {
    fn drop(&mut self) {
        zeroise_value(self);
    }
}

impl Zeroable for ProverAwaiting {}

/// The verifier, waiting for the prover's confirmation.
pub struct VerifierAwaiting {
    confirm_p: [u8; Confirm::BYTES],
    shared: [u8; 32],
    shared_len: u8,
}

impl VerifierAwaiting {
    /// Returns the shared key when `confirm` is the prover's tag.
    ///
    /// Fails with [`Error::BadSignature`] otherwise, and the key is wiped.
    pub fn finish(self, confirm: &Confirm) -> Result<SharedKey, Error> {
        let _entry = Entry::new_secret();
        let key = SharedKey::new(&self.shared[..usize::from(self.shared_len)]);
        match ct::into_public(ct_equal(&self.confirm_p, confirm.as_ref())) {
            true => Ok(key),
            false => Err(Error::BadSignature),
        }
    }
}

impl fmt::Debug for VerifierAwaiting {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("VerifierAwaiting").finish_non_exhaustive()
    }
}

impl Drop for VerifierAwaiting {
    fn drop(&mut self) {
        zeroise_value(self);
    }
}

impl Zeroable for VerifierAwaiting {}

struct Label {
    bytes: [u8; MAX_LABEL],
    len: u16,
}

impl Label {
    fn new(bytes: &[u8]) -> Result<Self, Error> {
        if bytes.len() > MAX_LABEL {
            return Err(Error::WrongLength);
        }
        let mut stored = [0u8; MAX_LABEL];
        stored[..bytes.len()].copy_from_slice(bytes);
        Ok(Self {
            bytes: stored,
            len: bytes.len() as u16,
        })
    }

    fn as_slice(&self) -> &[u8] {
        &self.bytes[..usize::from(self.len)]
    }
}

struct Labels {
    context: Label,
    id_prover: Label,
    id_verifier: Label,
}

impl Labels {
    fn new(context: &[u8], id_prover: &[u8], id_verifier: &[u8]) -> Result<Self, Error> {
        Ok(Self {
            context: Label::new(context)?,
            id_prover: Label::new(id_prover)?,
            id_verifier: Label::new(id_verifier)?,
        })
    }
}

impl Zeroable for Label {}
impl Zeroable for Labels {}
impl Zeroable for Schedule {}
impl Zeroable for Confirm {}

struct Keys {
    prover: [u8; 32],
    prover_len: usize,
    verifier: [u8; 32],
    verifier_len: usize,
    shared: [u8; 32],
    shared_len: usize,
}

impl Keys {
    fn prover_key(&self) -> &[u8] {
        &self.prover[..self.prover_len]
    }

    fn verifier_key(&self) -> &[u8] {
        &self.verifier[..self.verifier_len]
    }

    fn shared(&self) -> &[u8] {
        &self.shared[..self.shared_len]
    }
}

fn points() -> Result<(Affine, Affine), Error> {
    Ok((
        Affine::from_compressed(&M_COMPRESSED)?,
        Affine::from_compressed(&N_COMPRESSED)?,
    ))
}

fn random_scalar() -> Result<Scalar, Error> {
    let mut rng = SystemRandom;
    for _ in 0..64 {
        let mut bytes = [0u8; Scalar::BYTES];
        rng.fill(&mut bytes)?;
        ct::secret_slice(&bytes);
        if let Ok(scalar) = Scalar::from_bytes_checked(&bytes) {
            return Ok(ct::into_secret(scalar));
        }
    }
    Err(Error::RngFailed)
}

struct EncodedPoint {
    bytes: [u8; Share::BYTES],
    len: u8,
}

impl EncodedPoint {
    fn as_slice(&self) -> &[u8] {
        &self.bytes[..usize::from(self.len)]
    }
}

/// SEC 1 encoding after a curve check. The identity, which an opposite sum
/// becomes, is the single octet `0x00`. `public` declassifies the bytes.
fn encode(point: Affine, public: bool) -> Result<EncodedPoint, Error> {
    let bytes = point.to_uncompressed();
    let zeros = [0u8; Share::BYTES - 1];
    // `(0, 0)` is the affine image of the identity, not a curve point.
    let identity = ct_equal(&bytes[1..], &zeros) & ct_equal(&bytes[..1], &[0x04]);
    if ct::into_public(identity) {
        let mut stored = [0u8; Share::BYTES];
        stored[0] = 0x00;
        if public {
            ct::public_slice(&stored[..1]);
        }
        return Ok(EncodedPoint {
            bytes: stored,
            len: 1,
        });
    }
    match ct::into_public(point.on_curve()) {
        true => {
            if public {
                ct::public_slice(&bytes);
            }
            Ok(EncodedPoint {
                bytes,
                len: Share::BYTES as u8,
            })
        }
        false => Err(Error::Fault),
    }
}

fn publish(point: Affine) -> Result<Share, Error> {
    let encoded = encode(point, true)?;
    if encoded.len != Share::BYTES as u8 {
        return Err(KeyFormatError::NotOnCurve.into());
    }
    let mut bytes = [0u8; Share::BYTES];
    bytes.copy_from_slice(&encoded.bytes);
    Ok(Share(bytes))
}

fn publish_point(point: Affine) -> Result<Affine, Error> {
    let bytes = publish(point)?;
    Affine::from_uncompressed(bytes.as_ref())
}

fn secret_point(point: Affine) -> Result<EncodedPoint, Error> {
    encode(point, false)
}

fn absorb(hash: &mut digest::Context, data: &[u8]) {
    hash.update(&(data.len() as u64).to_le_bytes());
    hash.update(data);
}

fn transcript(
    labels: &Labels,
    share_p: &[u8],
    share_v: &[u8],
    z: &[u8],
    v: &[u8],
    w0: &Scalar,
) -> Result<[u8; 32], Error> {
    let mut hash = digest::Context::new(&digest::SHA256);
    absorb(&mut hash, labels.context.as_slice());
    absorb(&mut hash, labels.id_prover.as_slice());
    absorb(&mut hash, labels.id_verifier.as_slice());
    let (m, n) = points()?;
    absorb(&mut hash, &m.to_uncompressed());
    absorb(&mut hash, &n.to_uncompressed());
    absorb(&mut hash, share_p);
    absorb(&mut hash, share_v);
    absorb(&mut hash, z);
    absorb(&mut hash, v);
    absorb(&mut hash, &w0.as_bytes());
    let digest = hash.finish();
    let mut out = [0u8; 32];
    out.copy_from_slice(digest.as_ref());
    Ok(out)
}

fn expand(prk: &hkdf::Prk, info: &[u8], out: &mut [u8]) -> Result<(), Error> {
    prk.expand(&[info], out.len())
        .fill(out)
        .map_err(|_| Error::Fault)
}

fn schedule_keys(schedule: Schedule, transcript_hash: &[u8; 32]) -> Result<Keys, Error> {
    let mut keys = Keys {
        prover: [0; 32],
        prover_len: 0,
        verifier: [0; 32],
        verifier_len: 0,
        shared: [0; 32],
        shared_len: 0,
    };
    match schedule {
        Schedule::Rfc9383 => {
            let prk = hkdf::Salt::new(&hkdf::HKDF_SHA256, b"").extract(transcript_hash);
            let mut confirm = [0u8; 64];
            expand(&prk, b"ConfirmationKeys", &mut confirm)?;
            keys.prover.copy_from_slice(&confirm[..32]);
            keys.prover_len = 32;
            keys.verifier.copy_from_slice(&confirm[32..]);
            keys.verifier_len = 32;
            expand(&prk, b"SharedKey", &mut keys.shared)?;
            keys.shared_len = 32;
        }
        Schedule::Draft01 => {
            // Appendix B's hash splits as Ka || Ke. Ka is 16 bytes.
            let prk = hkdf::Salt::new(&hkdf::HKDF_SHA256, b"").extract(&transcript_hash[..16]);
            let mut confirm = [0u8; 32];
            expand(&prk, b"ConfirmationKeys", &mut confirm)?;
            keys.prover[..16].copy_from_slice(&confirm[..16]);
            keys.prover_len = 16;
            keys.verifier[..16].copy_from_slice(&confirm[16..]);
            keys.verifier_len = 16;
            keys.shared[..16].copy_from_slice(&transcript_hash[16..]);
            keys.shared_len = 16;
        }
    }
    Ok(keys)
}

fn mac(key: &[u8], message: &[u8]) -> Confirm {
    let tag = hmac::sign(&hmac::Key::new(&hmac::HMAC_SHA256, key), message);
    let mut bytes = [0u8; Confirm::BYTES];
    bytes.copy_from_slice(tag.as_ref());
    ct::public_slice(&bytes);
    Confirm(bytes)
}

#[cfg(test)]
#[cfg_attr(coverage_nightly, coverage(off))]
mod tests {
    use super::*;

    fn hex(s: &str) -> Vec<u8> {
        hex::decode(s).unwrap()
    }

    fn scalar(s: &str) -> Scalar {
        Scalar::from_be_reduced(&hex(s)).unwrap()
    }

    struct Vector {
        suite: &'static Suite,
        context: &'static [u8],
        id_prover: &'static [u8],
        id_verifier: &'static [u8],
        w0: &'static str,
        w1: &'static str,
        l: &'static str,
        x: &'static str,
        y: &'static str,
        share_p: &'static str,
        share_v: &'static str,
        confirm_p: &'static str,
        confirm_v: &'static str,
        shared: &'static str,
    }

    fn run(vector: &Vector) {
        let prover = ProverSecrets::new(&hex(vector.w0), &hex(vector.w1)).unwrap();
        let from_w1 = VerifierRecord::from_w1(&hex(vector.w0), &hex(vector.w1)).unwrap();
        let loaded = VerifierRecord::from_record(&hex(vector.w0), &hex(vector.l)).unwrap();
        assert_eq!(
            from_w1.l.to_uncompressed().as_slice(),
            hex(vector.l).as_slice()
        );

        let (share_p, prover) = prover
            .start_at(
                vector.suite,
                vector.context,
                vector.id_prover,
                vector.id_verifier,
                Some(scalar(vector.x)),
            )
            .unwrap();
        assert_eq!(share_p.as_ref(), hex(vector.share_p).as_slice());

        let (share_v, confirm_v, _) = loaded
            .start_at(
                vector.suite,
                vector.context,
                vector.id_prover,
                vector.id_verifier,
                &share_p,
                Some(scalar(vector.y)),
            )
            .unwrap();
        assert_eq!(share_v.as_ref(), hex(vector.share_v).as_slice());
        assert_eq!(confirm_v.as_ref(), hex(vector.confirm_v).as_slice());

        let (confirm_p, key_p) = prover.finish(&share_v, &confirm_v).unwrap();
        assert_eq!(confirm_p.as_ref(), hex(vector.confirm_p).as_slice());
        assert_eq!(key_p.as_ref(), hex(vector.shared).as_slice());

        let (share_v, confirm_v, verifier) = from_w1
            .start_at(
                vector.suite,
                vector.context,
                vector.id_prover,
                vector.id_verifier,
                &share_p,
                Some(scalar(vector.y)),
            )
            .unwrap();
        let key_v = verifier.finish(&confirm_p).unwrap();
        assert_eq!(share_v.as_ref(), hex(vector.share_v).as_slice());
        assert_eq!(confirm_v.as_ref(), hex(vector.confirm_v).as_slice());
        assert_eq!(key_v.as_ref(), key_p.as_ref());
    }

    #[test]
    fn rfc9383() {
        run(&Vector {
            suite: &RFC9383,
            context: b"SPAKE2+-P256-SHA256-HKDF-SHA256-HMAC-SHA256 Test Vectors",
            id_prover: b"client",
            id_verifier: b"server",
            w0: "bb8e1bbcf3c48f62c08db243652ae55d3e5586053fca77102994f23ad95491b3",
            w1: "7e945f34d78785b8a3ef44d0df5a1a97d6b3b460409a345ca7830387a74b1dba",
            l: "04eb7c9db3d9a9eb1f8adab81b5794c1f13ae3e225efbe91ea487425854c7fc00f00bfedcbd09b2400142d40a14f2064ef31dfaa903b91d1faea7093d835966efd",
            x: "d1232c8e8693d02368976c174e2088851b8365d0d79a9eee709c6a05a2fad539",
            y: "717a72348a182085109c8d3917d6c43d59b224dc6a7fc4f0483232fa6516d8b3",
            share_p: "04ef3bd051bf78a2234ec0df197f7828060fe9856503579bb1733009042c15c0c1de127727f418b5966afadfdd95a6e4591d171056b333dab97a79c7193e341727",
            share_v: "04c0f65da0d11927bdf5d560c69e1d7d939a05b0e88291887d679fcadea75810fb5cc1ca7494db39e82ff2f50665255d76173e09986ab46742c798a9a68437b048",
            confirm_p: "926cc713504b9b4d76c9162ded04b5493e89109f6d89462cd33adc46fda27527",
            confirm_v: "9747bcc4f8fe9f63defee53ac9b07876d907d55047e6ff2def2e7529089d3e68",
            shared: "0c5f8ccd1413423a54f6c1fb26ff01534a87f893779c6e68666d772bfd91f3e7",
        });
    }

    #[test]
    fn draft01() {
        run(&Vector {
            suite: &MATTER_PASE,
            context: b"SPAKE2+-P256-SHA256-HKDF draft-01",
            id_prover: b"client",
            id_verifier: b"server",
            w0: "e6887cf9bdfb7579c69bf47928a84514b5e355ac034863f7ffaf4390e67d798c",
            w1: "24b5ae4abda868ec9336ffc3b78ee31c5755bef1759227ef5372ca139b94e512",
            l: "0495645cfb74df6e58f9748bb83a86620bab7c82e107f57d6870da8cbcb2ff9f7063a14b6402c62f99afcb9706a4d1a143273259fe76f1c605a3639745a92154b9",
            x: "8b0f3f383905cf3a3bb955ef8fb62e24849dd349a05ca79aafb18041d30cbdb6",
            y: "2e0895b0e763d6d5a9564433e64ac3cac74ff897f6c3445247ba1bab40082a91",
            share_p: "04af09987a593d3bac8694b123839422c3cc87e37d6b41c1d630f000dd64980e537ae704bcede04ea3bec9b7475b32fa2ca3b684be14d11645e38ea6609eb39e7e",
            share_v: "04417592620aebf9fd203616bbb9f121b730c258b286f890c5f19fea833a9c900cbe9057bc549a3e19975be9927f0e7614f08d1f0a108eede5fd7eb5624584a4f4",
            confirm_p: "d4376f2da9c72226dd151b77c2919071155fc22a2068d90b5faa6c78c11e77dd",
            confirm_v: "0660a680663e8c5695956fb22dff298b1d07a526cf3cc591adfecd1f6ef6e02e",
            shared: "801db297654816eb4f02868129b9dc89",
        });
        // The same password with an empty verifier identity, appendix B's second vector.
        run(&Vector {
            suite: &MATTER_PASE,
            context: b"SPAKE2+-P256-SHA256-HKDF draft-01",
            id_prover: b"client",
            id_verifier: b"",
            w0: "e6887cf9bdfb7579c69bf47928a84514b5e355ac034863f7ffaf4390e67d798c",
            w1: "24b5ae4abda868ec9336ffc3b78ee31c5755bef1759227ef5372ca139b94e512",
            l: "0495645cfb74df6e58f9748bb83a86620bab7c82e107f57d6870da8cbcb2ff9f7063a14b6402c62f99afcb9706a4d1a143273259fe76f1c605a3639745a92154b9",
            x: "ec82d9258337f61239c9cd68e8e532a3a6b83d12d2b1ca5d543f44def17dfb8d",
            y: "eac3f7de4b198d5fe25c443c0cd4963807add767815dd02a6f0133b4bc2c9eb0",
            share_p: "04230779960824076d3666a7418e4d433e2fa15b06176eabdd572f43a32ecc79a192b243d2624310a7356273b86e5fd9bd627d3ade762baeff1a320d4ad7a4e47f",
            share_v: "044558642e71b616b248c9583bd6d7aa1b3952c6df6a9f7492a06035ca5d92522d84443de7aa20a59380fa4de6b7438d925dbfb7f1cfe60d79acf961ee33988c7d",
            confirm_p: "e1b9258807ba4750dae1d7f3c3c294f13dc4fa60cde346d5de7d200e2f8fd3fc",
            confirm_v: "b9c39dfa49c47757de778d9bedeaca2448b905be19a43b94ee24b770208135e3",
            shared: "6989d8f9177ef7df67da437987f07255",
        });
    }

    /// Every vector in connectedhomeip `src/crypto/tests/SPAKE2P_RFC_test_vectors.h`.
    ///
    /// That is the set Matter's PASE tests run. The first two are also
    /// draft-01 appendix B, covered by [`draft01`].
    #[test]
    fn connectedhomeip() {
        let context: &[u8] = b"SPAKE2+-P256-SHA256-HKDF draft-01";
        let w0 = "e6887cf9bdfb7579c69bf47928a84514b5e355ac034863f7ffaf4390e67d798c";
        let w1 = "24b5ae4abda868ec9336ffc3b78ee31c5755bef1759227ef5372ca139b94e512";
        let l = "0495645cfb74df6e58f9748bb83a86620bab7c82e107f57d6870da8cbcb2ff9f7063a14b6402c62f99afcb9706a4d1a143273259fe76f1c605a3639745a92154b9";
        let cases = [
            (
                b"client".as_slice(),
                b"server".as_slice(),
                "8b0f3f383905cf3a3bb955ef8fb62e24849dd349a05ca79aafb18041d30cbdb6",
                "2e0895b0e763d6d5a9564433e64ac3cac74ff897f6c3445247ba1bab40082a91",
                "04af09987a593d3bac8694b123839422c3cc87e37d6b41c1d630f000dd64980e537ae704bcede04ea3bec9b7475b32fa2ca3b684be14d11645e38ea6609eb39e7e",
                "04417592620aebf9fd203616bbb9f121b730c258b286f890c5f19fea833a9c900cbe9057bc549a3e19975be9927f0e7614f08d1f0a108eede5fd7eb5624584a4f4",
                "d4376f2da9c72226dd151b77c2919071155fc22a2068d90b5faa6c78c11e77dd",
                "0660a680663e8c5695956fb22dff298b1d07a526cf3cc591adfecd1f6ef6e02e",
                "801db297654816eb4f02868129b9dc89",
            ),
            (
                b"client".as_slice(),
                b"".as_slice(),
                "ec82d9258337f61239c9cd68e8e532a3a6b83d12d2b1ca5d543f44def17dfb8d",
                "eac3f7de4b198d5fe25c443c0cd4963807add767815dd02a6f0133b4bc2c9eb0",
                "04230779960824076d3666a7418e4d433e2fa15b06176eabdd572f43a32ecc79a192b243d2624310a7356273b86e5fd9bd627d3ade762baeff1a320d4ad7a4e47f",
                "044558642e71b616b248c9583bd6d7aa1b3952c6df6a9f7492a06035ca5d92522d84443de7aa20a59380fa4de6b7438d925dbfb7f1cfe60d79acf961ee33988c7d",
                "e1b9258807ba4750dae1d7f3c3c294f13dc4fa60cde346d5de7d200e2f8fd3fc",
                "b9c39dfa49c47757de778d9bedeaca2448b905be19a43b94ee24b770208135e3",
                "6989d8f9177ef7df67da437987f07255",
            ),
            (
                b"".as_slice(),
                b"server".as_slice(),
                "ba0f0f5b78ef23fd07868e46aeca63b51fda519a3420501acbe23d53c2918748",
                "39397fbe6db47e9fbd1a263d79f5d0aaa44df26ce755f78e092644b434533a42",
                "04c14d28f4370fea20745106cea58bcfb60f2949fa4e131b9aff5ea13fd5aa79d507ae1d229e447e000f15eb78a9a32c2b88652e3411642043c1b2b7992cf2d4de",
                "04d1bee3120fd87e86fe189cb952dc688823080e62524dd2c08dffe3d22a0a8986aa64c9fe0191033cafbc9bcaefc8e2ba8ba860cd127af9efdd7f1c3a41920fe8",
                "e564c93b3015efb946dc16d642bbe7d1c8da5be164ed9fc3bae4e0ff86e1bd3c",
                "072a94d9a54edc201d8891534c2317cadf3ea3792827f479e873f93e90f21552",
                "2ea40e4badfa5452b5744dc5983e99ba",
            ),
            (
                b"".as_slice(),
                b"".as_slice(),
                "5b478619804f4938d361fbba3a20648725222f0a54cc4c876139efe7d9a21786",
                "766770dad8c8eecba936823c0aed044b8c3c4f7655e8beec44a15dcbcaf78e5e",
                "04a6db23d001723fb01fcfc9d08746c3c2a0a3feff8635d29cad2853e7358623425cf39712e928054561ba71e2dc11f300f1760e71eb177021a8f85e78689071cd",
                "04390d29bf185c3abf99f150ae7c13388c82b6be0c07b1b8d90d26853e84374bbdc82becdb978ca3792f472424106a2578012752c11938fcf60a41df75ff7cf947",
                "71d9412779b6c45a2c615c9df3f1fd93dc0aaf63104da8ece4aa1b5a3a415fea",
                "095dc0400355cc233fde7437811815b3c1524aae80fd4e6810cf531cf11d20e3",
                "ea3276d68334576097e04b19ee5a3a8b",
            ),
        ];
        for (id_prover, id_verifier, x, y, share_p, share_v, confirm_p, confirm_v, shared) in cases
        {
            run(&Vector {
                suite: &MATTER_PASE,
                context,
                id_prover,
                id_verifier,
                w0,
                w1,
                l,
                x,
                y,
                share_p,
                share_v,
                confirm_p,
                confirm_v,
                shared,
            });
        }
    }

    /// A handshake pakery-spake2plus has not published as a vector.
    #[test]
    #[cfg(not(miri))]
    fn matches_pakery() {
        use p256::elliptic_curve::ff::PrimeField;
        use pakery_crypto::{
            HkdfSha256, HmacSha256, P256Group, SPAKE2_P256_M_COMPRESSED, SPAKE2_P256_N_COMPRESSED,
            Sha256Hash,
        };
        use pakery_spake2plus::registration::compute_verifier;
        use pakery_spake2plus::{Prover, Spake2PlusCiphersuite, Verifier};

        struct Pakery;
        impl Spake2PlusCiphersuite for Pakery {
            type Group = P256Group;
            type Hash = Sha256Hash;
            type Kdf = HkdfSha256;
            type Mac = HmacSha256;
            const NH: usize = 32;
            const M_BYTES: &'static [u8] = &SPAKE2_P256_M_COMPRESSED;
            const N_BYTES: &'static [u8] = &SPAKE2_P256_N_COMPRESSED;
        }

        fn sc(bytes: &[u8; 32]) -> p256::Scalar {
            p256::Scalar::from_repr((*bytes).into()).unwrap()
        }

        let w0 = [0x42; 32];
        let w1 = [0x24; 32];
        let x = [0x07; 32];
        let y = [0x0b; 32];
        let context = b"not a published vector";
        let id_prover = b"prover";
        let id_verifier = b"";

        let (share_p, prover) = ProverSecrets::new(&w0, &w1)
            .unwrap()
            .start_at(
                &RFC9383,
                context,
                id_prover,
                id_verifier,
                Some(scalar_bytes(&x)),
            )
            .unwrap();
        let l = compute_verifier::<Pakery>(&sc(&w1));
        let (share_v, confirm_v, _) = VerifierRecord::from_record(&w0, &l)
            .unwrap()
            .start_at(
                &RFC9383,
                context,
                id_prover,
                id_verifier,
                &share_p,
                Some(scalar_bytes(&y)),
            )
            .unwrap();
        let (confirm_p, key) = prover.finish(&share_v, &confirm_v).unwrap();

        let (their_p, their_prover) = Prover::<Pakery>::start_with_scalar(
            &sc(&w0),
            &sc(&w1),
            &sc(&x),
            context,
            id_prover,
            id_verifier,
        )
        .unwrap();
        assert_eq!(share_p.as_ref(), their_p.as_slice());
        let (their_v, their_confirm_v, their_verifier) = Verifier::<Pakery>::start_with_scalar(
            &their_p,
            &sc(&w0),
            &l,
            &sc(&y),
            context,
            id_prover,
            id_verifier,
        )
        .unwrap();
        assert_eq!(share_v.as_ref(), their_v.as_slice());
        assert_eq!(confirm_v.as_ref(), their_confirm_v.as_slice());
        let their_out = their_prover.finish(&their_v, &their_confirm_v).unwrap();
        assert_eq!(confirm_p.as_ref(), their_out.confirm_p.as_slice());
        assert_eq!(key.as_ref(), their_out.session_key.as_bytes());
        let their_key = their_verifier.finish(confirm_p.as_ref()).unwrap();
        assert_eq!(key.as_ref(), their_key.session_key.as_bytes());
    }

    fn scalar_bytes(bytes: &[u8; 32]) -> Scalar {
        Scalar::from_be_reduced(bytes).unwrap()
    }

    #[test]
    fn rejects_a_bad_confirmation_and_a_bad_share() {
        let w0 = [0x11; 40];
        let w1 = [0x22; 40];
        let prover = ProverSecrets::new(&w0, &w1).unwrap();
        let verifier = VerifierRecord::from_w1(&w0, &w1).unwrap();
        let (share_p, prover_state) = prover.start(&RFC9383, b"ctx", b"a", b"b").unwrap();
        let (share_v, confirm_v, _) = verifier
            .start(&RFC9383, b"ctx", b"a", b"b", &share_p)
            .unwrap();
        let mut bad = confirm_v.0;
        bad[0] ^= 1;
        assert_eq!(
            prover_state.finish(&share_v, &Confirm(bad)).err(),
            Some(Error::BadSignature)
        );

        let prover = ProverSecrets::new(&w0, &w1).unwrap();
        let verifier = VerifierRecord::from_w1(&w0, &w1).unwrap();
        let (share_p, prover_state) = prover.start(&RFC9383, b"ctx", b"a", b"b").unwrap();
        let (share_v, confirm_v, verifier_state) = verifier
            .start(&RFC9383, b"ctx", b"a", b"b", &share_p)
            .unwrap();
        let (confirm_p, _) = prover_state.finish(&share_v, &confirm_v).unwrap();
        let mut bad = confirm_p.0;
        bad[3] ^= 0x80;
        assert_eq!(
            verifier_state.finish(&Confirm(bad)).err(),
            Some(Error::BadSignature)
        );

        let mut off = share_p.0;
        off[10] ^= 1;
        assert!(Share::from_bytes(&off).is_err());
        assert!(Share::from_bytes(&off[..64]).is_err());
        assert!(Confirm::from_bytes(&[0; 16]).is_err());
        assert!(ProverSecrets::new(&[], &w1).is_err());
        assert!(ProverSecrets::new(&[0; 32], &w1).is_err());
        assert!(VerifierRecord::from_w1(&w0, &[0; 129]).is_err());
        let prover = ProverSecrets::new(&w0, &w1).unwrap();
        assert_eq!(
            prover.start(&RFC9383, &[0; MAX_LABEL + 1], b"", b"").err(),
            Some(Error::WrongLength)
        );
    }

    /// RFC 9383 still evaluates `X - w0*M` when `X` is `-w0*M` (a doubling)
    /// or `w0*M` (the identity). The confirmation is the one those points
    /// produce, and the identity is the SEC 1 octet `0x00`.
    #[test]
    fn exceptional_peer_share_follows_rfc9383() {
        let w0 = [0x31u8; 40];
        let w1 = [0x41u8; 40];
        let w0s = Scalar::from_be_reduced(&w0).unwrap();
        let w1s = Scalar::from_be_reduced(&w1).unwrap();
        let y = scalar("000000000000000000000000000000000000000000000000000000000000000b");
        let x = scalar("0000000000000000000000000000000000000000000000000000000000000007");
        let two = Scalar::from_be_reduced(&[2]).unwrap();
        let (m, n) = points().unwrap();
        let labels = Labels::new(b"ctx", b"client", b"").unwrap();

        let negated = m.mul(&w0s).negate();
        let share_x = Share(negated.to_uncompressed());
        let share_v = Share(n.mul(&w0s).add(Affine::mul_base(&y)).to_uncompressed());
        let z = negated.mul(&two).mul(&y);
        let v = Affine::mul_base(&w1s).mul(&y);
        let tt = transcript(
            &labels,
            share_x.as_ref(),
            share_v.as_ref(),
            &z.to_uncompressed(),
            &v.to_uncompressed(),
            &w0s,
        )
        .unwrap();
        let keys = schedule_keys(Schedule::Rfc9383, &tt).unwrap();
        let verifier = VerifierRecord::from_w1(&w0, &w1).unwrap();
        let (got_share, got_confirm, state) = verifier
            .start_at(&RFC9383, b"ctx", b"client", b"", &share_x, Some(y.copy()))
            .unwrap();
        assert_eq!(got_share.as_ref(), share_v.as_ref());
        assert_eq!(
            got_confirm.as_ref(),
            mac(keys.verifier_key(), share_x.as_ref()).as_ref()
        );
        let key = state
            .finish(&mac(keys.prover_key(), share_v.as_ref()))
            .unwrap();
        assert_eq!(key.as_ref(), keys.shared());

        // X = w0*M makes Z the identity. SEC 1 encodes it as one zero byte.
        let share_x = Share(m.mul(&w0s).to_uncompressed());
        let v = Affine::mul_base(&w1s).mul(&y);
        let tt = transcript(
            &labels,
            share_x.as_ref(),
            share_v.as_ref(),
            &[0x00],
            &v.to_uncompressed(),
            &w0s,
        )
        .unwrap();
        let keys = schedule_keys(Schedule::Rfc9383, &tt).unwrap();
        let verifier = VerifierRecord::from_w1(&w0, &w1).unwrap();
        let (_, got_confirm, _) = verifier
            .start_at(&RFC9383, b"ctx", b"client", b"", &share_x, Some(y.copy()))
            .unwrap();
        assert_eq!(
            got_confirm.as_ref(),
            mac(keys.verifier_key(), share_x.as_ref()).as_ref()
        );

        // The prover's subtraction, Y = -w0*N.
        let prover = ProverSecrets::new(&w0, &w1).unwrap();
        let (share_p, prover) = prover
            .start_at(&RFC9383, b"ctx", b"client", b"", Some(x.copy()))
            .unwrap();
        let negated = n.mul(&w0s).negate();
        let share_y = Share(negated.to_uncompressed());
        let diff = negated.mul(&two);
        let z = diff.mul(&x);
        let v = diff.mul(&w1s);
        let tt = transcript(
            &labels,
            share_p.as_ref(),
            share_y.as_ref(),
            &z.to_uncompressed(),
            &v.to_uncompressed(),
            &w0s,
        )
        .unwrap();
        let keys = schedule_keys(Schedule::Rfc9383, &tt).unwrap();
        let (confirm_p, key) = prover
            .finish(&share_y, &mac(keys.verifier_key(), share_p.as_ref()))
            .unwrap();
        assert_eq!(
            confirm_p.as_ref(),
            mac(keys.prover_key(), share_y.as_ref()).as_ref()
        );
        assert_eq!(key.as_ref(), keys.shared());
    }

    #[test]
    fn suites_do_not_agree() {
        let w0 = [0x31; 32];
        let w1 = [0x41; 32];
        let x = scalar("0000000000000000000000000000000000000000000000000000000000000007");
        let y = scalar("000000000000000000000000000000000000000000000000000000000000000b");
        let mut keys = Vec::new();
        for suite in [&RFC9383, &MATTER_PASE] {
            let prover = ProverSecrets::new(&w0, &w1).unwrap();
            let verifier = VerifierRecord::from_w1(&w0, &w1).unwrap();
            let (share_p, prover) = prover
                .start_at(suite, b"ctx", b"client", b"", Some(x.copy()))
                .unwrap();
            let (share_v, confirm_v, verifier) = verifier
                .start_at(suite, b"ctx", b"client", b"", &share_p, Some(y.copy()))
                .unwrap();
            let (confirm_p, key) = prover.finish(&share_v, &confirm_v).unwrap();
            let other = verifier.finish(&confirm_p).unwrap();
            assert_eq!(key.as_ref(), other.as_ref());
            keys.push(key.as_ref().to_vec());
        }
        assert_ne!(keys[0], keys[1]);
    }

    /// The two schedules are one type, so a mixed handshake compiles. The
    /// confirmation check is what refuses it.
    #[test]
    fn mixed_suites_fail_confirmation() {
        let w0 = [0x31u8; 32];
        let w1 = [0x41u8; 32];
        let x = scalar("0000000000000000000000000000000000000000000000000000000000000007");
        let y = scalar("000000000000000000000000000000000000000000000000000000000000000b");
        let prover = ProverSecrets::new(&w0, &w1).unwrap();
        let verifier = VerifierRecord::from_w1(&w0, &w1).unwrap();
        let (share_p, prover) = prover
            .start_at(&RFC9383, b"ctx", b"client", b"", Some(x))
            .unwrap();
        let (share_v, confirm_v, _) = verifier
            .start_at(&MATTER_PASE, b"ctx", b"client", b"", &share_p, Some(y))
            .unwrap();
        assert_eq!(
            prover.finish(&share_v, &confirm_v).err(),
            Some(Error::BadSignature)
        );
    }

    /// Matter PASE, through `matter-crypto` 0.5.1's public state machine with
    /// its test scalars. The context is SHA-256 of "CHIP PAKE V1 Commissioning",
    /// and both identities are empty.
    #[test]
    #[cfg(not(miri))]
    fn matches_matter_crypto() {
        use core::num::NonZeroU32;

        let pin = 202_021u32;
        let salt = [0x42u8; 16];
        let mut stretched = [0u8; 80];
        crate::pbkdf2::Secret::new(&crate::pbkdf2::PBKDF2_HMAC_SHA256, &pin.to_le_bytes())
            .derive(NonZeroU32::new(1000).unwrap(), &salt, &mut stretched)
            .unwrap();
        let (w0, w1) = stretched.split_at(40);
        let verifier_blob = matter_crypto::pake_passcode_verifier(pin, &salt, 1000).unwrap();
        let record = VerifierRecord::from_w1(w0, w1).unwrap();
        assert_eq!(
            &verifier_blob[..32],
            Scalar::from_be_reduced(w0).unwrap().as_bytes()
        );
        assert_eq!(&verifier_blob[32..], record.l.to_uncompressed().as_slice());

        let mut x_bytes = [0u8; 32];
        x_bytes[31] = 7;
        let mut y_bytes = [0u8; 32];
        y_bytes[31] = 11;
        let params = matter_crypto::PasePbkdfParams {
            iterations: 1000,
            salt: salt.to_vec(),
        };
        let mut their_prover =
            matter_crypto::test_support::prover_with_scalar(pin, params.clone(), x_bytes).unwrap();
        let w0_be: [u8; 32] = verifier_blob[..32].try_into().unwrap();
        let l: [u8; 65] = verifier_blob[32..].try_into().unwrap();
        let mut their_verifier =
            matter_crypto::test_support::verifier_with_scalar(w0_be, l, params, y_bytes).unwrap();
        let pake1 = their_prover.start().unwrap();
        their_verifier.handle_pake1(&pake1).unwrap();
        let pake2 = their_verifier.next_message().unwrap();
        their_prover.handle_pake2(&pake2).unwrap();
        let pake3 = their_prover.next_message().unwrap();
        their_verifier.handle_pake3(&pake3).unwrap();
        let their_key = their_prover.finish().unwrap();
        assert_eq!(their_key.ke, their_verifier.finish().unwrap().ke);

        let mut ctx = digest::Context::new(&digest::SHA256);
        ctx.update(b"CHIP PAKE V1 Commissioning");
        let context = ctx.finish();
        let prover = ProverSecrets::new(w0, w1).unwrap();
        let verifier = VerifierRecord::from_record(w0, &l).unwrap();
        let (share_p, prover) = prover
            .start_at(
                &MATTER_PASE,
                context.as_ref(),
                b"",
                b"",
                Some(Scalar::from_be_reduced(&x_bytes).unwrap()),
            )
            .unwrap();
        let (share_v, confirm_v, verifier) = verifier
            .start_at(
                &MATTER_PASE,
                context.as_ref(),
                b"",
                b"",
                &share_p,
                Some(Scalar::from_be_reduced(&y_bytes).unwrap()),
            )
            .unwrap();
        let (confirm_p, key) = prover.finish(&share_v, &confirm_v).unwrap();
        assert_eq!(key.as_ref(), verifier.finish(&confirm_p).unwrap().as_ref());
        assert_eq!(key.as_ref(), their_key.ke.as_slice());
    }

    #[test]
    fn secrets_stay_secret() {
        // Under `admin/ctgrind`, nothing may branch on w0, w1, or the
        // ephemeral scalars until the confirmation tags and, in this test,
        // the shared key are declassified.
        let w0 = [0x5a; 40];
        let w1 = [0xa5; 40];
        ct::secret_slice(&w0);
        ct::secret_slice(&w1);
        for suite in [&RFC9383, &MATTER_PASE] {
            let prover = ProverSecrets::new(&w0, &w1).unwrap();
            let verifier = VerifierRecord::from_w1(&w0, &w1).unwrap();
            let (share_p, prover) = prover
                .start(suite, b"CHIP", b"commissionee", b"commissioner")
                .unwrap();
            let (share_v, confirm_v, verifier) = verifier
                .start(suite, b"CHIP", b"commissionee", b"commissioner", &share_p)
                .unwrap();
            let (confirm_p, key_p) = prover.finish(&share_v, &confirm_v).unwrap();
            let key_v = verifier.finish(&confirm_p).unwrap();
            ct::public_slice(key_p.as_ref());
            ct::public_slice(key_v.as_ref());
            assert_eq!(key_p.as_ref(), key_v.as_ref());
        }
    }
}
