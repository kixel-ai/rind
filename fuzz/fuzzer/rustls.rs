//! Feeds rind-rustls what a TLS or QUIC peer controls, through the traits
//! rustls calls, and compares each answer with rustls's own aws-lc-rs
//! provider. Then drives whole handshakes between two rind endpoints, editing
//! the bytes in flight, so the same code is reached through rustls's parsing.
//!
//! Keys come in the shapes rustls derives. rustls builds an `AeadKey` of
//! another length than 32 bytes only inside its key schedule, so records are
//! fuzzed under the 32-byte suites: the AES-128-GCM ones share their
//! decrypters, and reach them through QUIC's keys and the handshakes.

#![no_main]

use std::io::{Read, Write};
use std::sync::{Arc, OnceLock};

use libfuzzer_sys::{arbitrary, arbitrary::Arbitrary, fuzz_target};
use rustls::crypto::cipher::{
    AeadKey, InboundOpaqueMessage, Iv, MessageDecrypter, OutboundPlainMessage,
};
use rustls::crypto::{CryptoProvider, SupportedKxGroup, aws_lc_rs};
use rustls::pki_types::pem::PemObject;
use rustls::pki_types::{CertificateDer, PrivateKeyDer, SignatureVerificationAlgorithm};
use rustls::quic::{Keys, Version};
use rustls::server::WebPkiClientVerifier;
use rustls::{
    ClientConfig, ClientConnection, Connection, ContentType, Error, ProtocolVersion, RootCertStore,
    ServerConfig, ServerConnection, Side, SupportedCipherSuite,
};

mod edit;
use edit::Edit;

fuzz_target!(|input: Input| match input {
    Input::Record {
        suite,
        key,
        iv,
        seq,
        typ,
        plain,
        edit,
    } => record(suite, key, iv, seq, typ, &plain, &edit),
    Input::Packet {
        suite,
        version,
        dcid,
        packet_number,
        header,
        plain,
        edit,
    } => packet(suite, version, &dcid, packet_number, &header, &plain, &edit),
    Input::HeaderProtection {
        suite,
        dcid,
        sample,
        first,
        packet_number,
    } => header_protection(suite, &dcid, &sample, first, &packet_number),
    Input::KeyShare {
        group,
        server,
        share,
    } => key_share(group, server, share),
    Input::Ticket { plain, edit } => ticket(&plain, &edit),
    Input::Signature {
        algorithm,
        key,
        message,
        signature,
    } => verify(algorithm, key, &message, signature),
    Input::Handshake(handshake) => handshake.run(),
});

#[derive(Arbitrary, Debug)]
enum Input {
    /// A TLS record the peer sealed, then edited.
    Record {
        suite: u8,
        key: [u8; 32],
        iv: [u8; 12],
        seq: u64,
        typ: u8,
        plain: Vec<u8>,
        edit: Edit,
    },
    /// A QUIC packet under the initial keys for `dcid`, then edited.
    Packet {
        suite: u8,
        version: bool,
        dcid: Vec<u8>,
        packet_number: u64,
        header: Vec<u8>,
        plain: Vec<u8>,
        edit: Edit,
    },
    /// A QUIC header to unprotect; a packet number is at most 4 bytes.
    HeaderProtection {
        suite: u8,
        dcid: Vec<u8>,
        sample: [u8; 16],
        first: u8,
        packet_number: PacketNumber,
    },
    /// A peer's key share, completing the exchange as server or client.
    KeyShare {
        group: u8,
        server: bool,
        share: Share,
    },
    /// A session ticket the server issued, then edited.
    Ticket {
        plain: Vec<u8>,
        edit: Edit,
    },
    /// A peer's public key and signature for one algorithm.
    Signature {
        algorithm: u8,
        key: PeerKey,
        message: Vec<u8>,
        signature: PeerSignature,
    },
    Handshake(Handshake),
}

#[derive(Arbitrary, Debug)]
enum PacketNumber {
    One([u8; 1]),
    Two([u8; 2]),
    Three([u8; 3]),
    Four([u8; 4]),
}

/// A key share: the fuzzer's bytes, or a valid one edited.
#[derive(Arbitrary, Debug)]
enum Share {
    Raw(Vec<u8>),
    Edited(Edit),
}

/// A public key: the fuzzer's bytes, or one of the test keys edited.
#[derive(Arbitrary, Debug)]
enum PeerKey {
    Raw(Vec<u8>),
    Test(u8, Edit),
}

/// A signature: the fuzzer's bytes, or the test key's over the message, edited.
#[derive(Arbitrary, Debug)]
enum PeerSignature {
    Raw(Vec<u8>),
    Signed(Edit),
}

fn rind() -> &'static CryptoProvider {
    static PROVIDER: OnceLock<CryptoProvider> = OnceLock::new();
    PROVIDER.get_or_init(rind_rustls::default_provider)
}

fn baseline() -> &'static CryptoProvider {
    static PROVIDER: OnceLock<CryptoProvider> = OnceLock::new();
    PROVIDER.get_or_init(aws_lc_rs::default_provider)
}

/// The suite in aws-lc-rs's provider with `ours`'s identifier.
fn baseline_suite(ours: SupportedCipherSuite) -> SupportedCipherSuite {
    *aws_lc_rs::ALL_CIPHER_SUITES
        .iter()
        .find(|theirs| theirs.suite() == ours.suite())
        .expect("aws-lc-rs has every suite rind-rustls has")
}

/// What a decrypter returned, comparable across providers.
type Opened = Result<(ContentType, ProtocolVersion, Vec<u8>), Error>;

fn open(decrypter: &mut dyn MessageDecrypter, typ: ContentType, record: &[u8], seq: u64) -> Opened {
    let mut payload = record.to_vec();
    let opened = decrypter
        .decrypt(
            InboundOpaqueMessage::new(typ, ProtocolVersion::TLSv1_2, &mut payload),
            seq,
        )
        .map(|m| (m.typ, m.version, m.payload.to_vec()));
    if let Err(Error::DecryptError) = opened {
        assert_no_plaintext(record, &payload);
    }
    opened
}

/// A record that fails to open leaves each byte as the peer sent it or zero.
fn assert_no_plaintext(sent: &[u8], left: &[u8]) {
    assert!(
        sent.iter().zip(left).all(|(s, l)| s == l || *l == 0),
        "a failed open left other bytes than the peer's"
    );
}

fn record(suite: u8, key: [u8; 32], iv: [u8; 12], seq: u64, typ: u8, plain: &[u8], edit: &Edit) {
    let suites = rind_rustls::ALL_CIPHER_SUITES
        .iter()
        .filter(|suite| match suite {
            SupportedCipherSuite::Tls13(s) => s.aead_alg.key_len() == 32,
            SupportedCipherSuite::Tls12(s) => s.aead_alg.key_block_shape().enc_key_len == 32,
        })
        .collect::<Vec<_>>();
    let ours = *suites[usize::from(suite) % suites.len()];
    // The types a TLS 1.3 peer seals: rustls refuses any other inside a record.
    let typ = [
        ContentType::Alert,
        ContentType::Handshake,
        ContentType::ApplicationData,
    ][usize::from(typ) % 3];
    let message = OutboundPlainMessage {
        typ,
        version: ProtocolVersion::TLSv1_2,
        payload: plain.into(),
    };

    let (sealed, mut decrypters) = match (ours, baseline_suite(ours)) {
        (SupportedCipherSuite::Tls13(ours), SupportedCipherSuite::Tls13(theirs)) => {
            let sealed = theirs
                .aead_alg
                .encrypter(AeadKey::from(key), Iv::new(iv))
                .encrypt(message, seq)
                .unwrap();
            let decrypters =
                [ours, theirs].map(|s| s.aead_alg.decrypter(AeadKey::from(key), Iv::new(iv)));
            (sealed, decrypters)
        }
        (SupportedCipherSuite::Tls12(ours), SupportedCipherSuite::Tls12(theirs)) => {
            let shape = ours.aead_alg.key_block_shape();
            let (fixed, explicit) = iv.split_at(shape.fixed_iv_len);
            let explicit = &explicit[..shape.explicit_nonce_len];
            let sealed = theirs
                .aead_alg
                .encrypter(AeadKey::from(key), fixed, explicit)
                .encrypt(message, seq)
                .unwrap();
            let decrypters =
                [ours, theirs].map(|s| s.aead_alg.decrypter(AeadKey::from(key), fixed));
            (sealed, decrypters)
        }
        _ => unreachable!("a suite's version matches aws-lc-rs's"),
    };

    let mut record = sealed.payload.as_ref().to_vec();
    let edited = edit.apply(&mut record);
    let [ours, theirs] = &mut decrypters;
    let opened = open(ours.as_mut(), sealed.typ, &record, seq);
    assert_eq!(opened, open(theirs.as_mut(), sealed.typ, &record, seq));
    if !edited && plain.len() > 16384 {
        // rustls refuses a plaintext over its 16 KiB fragment limit once it opens.
        assert_eq!(opened, Err(Error::PeerSentOversizedRecord));
    } else if !edited {
        let (opened_typ, _, payload) = opened.expect("an unedited record opens");
        assert_eq!((opened_typ, payload.as_slice()), (typ, plain));
    }
}

/// The QUIC suites, and each one's initial keys for `dcid` in both providers.
fn quic_keys(suite: u8, version: Version, dcid: &[u8]) -> [Keys; 2] {
    let suites = rind_rustls::ALL_CIPHER_SUITES
        .iter()
        .filter_map(|suite| suite.tls13())
        .collect::<Vec<_>>();
    let ours = suites[usize::from(suite) % suites.len()];
    let theirs = baseline_suite(SupportedCipherSuite::Tls13(ours))
        .tls13()
        .unwrap();
    [ours, theirs].map(|s| s.quic_suite().unwrap().keys(dcid, Side::Client, version))
}

fn packet(
    suite: u8,
    version: bool,
    dcid: &[u8],
    packet_number: u64,
    header: &[u8],
    plain: &[u8],
    edit: &Edit,
) {
    let version = if version { Version::V2 } else { Version::V1 };
    let [ours, theirs] = quic_keys(suite, version, dcid);

    let mut sealed = plain.to_vec();
    let tag = theirs
        .local
        .packet
        .encrypt_in_place(packet_number, header, &mut sealed)
        .unwrap();
    sealed.extend_from_slice(tag.as_ref());
    let edited = edit.apply(&mut sealed);

    let open = |keys: &Keys| {
        let mut payload = sealed.clone();
        let opened = keys
            .local
            .packet
            .decrypt_in_place(packet_number, header, &mut payload)
            .map(<[u8]>::to_vec);
        if opened.is_err() {
            assert_no_plaintext(&sealed, &payload);
        }
        opened
    };
    let opened = open(&ours);
    assert_eq!(opened, open(&theirs));
    if !edited {
        assert_eq!(opened.expect("an unedited packet opens"), plain);
    }
}

fn header_protection(
    suite: u8,
    dcid: &[u8],
    sample: &[u8; 16],
    first: u8,
    packet_number: &PacketNumber,
) {
    let packet_number = match packet_number {
        PacketNumber::One(pn) => &pn[..],
        PacketNumber::Two(pn) => &pn[..],
        PacketNumber::Three(pn) => &pn[..],
        PacketNumber::Four(pn) => &pn[..],
    };
    let [ours, theirs] = quic_keys(suite, Version::V1, dcid);
    let unprotect = |keys: &Keys| {
        let (mut first, mut packet_number) = (first, packet_number.to_vec());
        keys.remote
            .header
            .decrypt_in_place(sample, &mut first, &mut packet_number)
            .map(|()| (first, packet_number))
    };
    assert_eq!(unprotect(&ours), unprotect(&theirs));
}

fn key_share(group: u8, server: bool, share: Share) {
    let ours = rind_rustls::ALL_KX_GROUPS[usize::from(group) % rind_rustls::ALL_KX_GROUPS.len()];
    let theirs = *aws_lc_rs::ALL_KX_GROUPS
        .iter()
        .find(|theirs| theirs.name() == ours.name())
        .expect("aws-lc-rs has every group rind-rustls has");

    let share = match share {
        Share::Raw(share) => share,
        Share::Edited(edit) => {
            // A client's share is its public key; a server's answers the client's.
            let client = theirs.start().unwrap();
            let mut share = match server {
                true => client.pub_key().to_vec(),
                false => theirs.start_and_complete(client.pub_key()).unwrap().pub_key,
            };
            edit.apply(&mut share);
            share
        }
    };

    // The secrets are random, so only whether each accepts the share compares.
    let complete = |group: &dyn SupportedKxGroup| match server {
        true => group.start_and_complete(&share).map(|_| ()),
        false => group.start().unwrap().complete(&share).map(|_| ()),
    };
    assert_eq!(complete(ours), complete(theirs), "{:?}", ours.name());
}

fn ticket(plain: &[u8], edit: &Edit) {
    let ticketer = rind_rustls::Ticketer::new().unwrap();
    let Some(mut ticket) = ticketer.encrypt(plain) else {
        return;
    };
    let edited = edit.apply(&mut ticket);
    let opened = ticketer.decrypt(&ticket);
    match edited {
        true => assert_eq!(opened, None, "an edited ticket opened"),
        // The ticketer refuses an empty ticket it sealed, as rustls never seals one.
        false => assert_eq!(opened.as_deref(), (!plain.is_empty()).then_some(plain)),
    }
}

/// The certificates and keys for each type of key rind-rustls verifies.
const KEYS: [(&str, &str, &str); 5] = [
    (
        include_str!("../../rind-rustls/tests/keys/ecdsa-p256/end.fullchain"),
        include_str!("../../rind-rustls/tests/keys/ecdsa-p256/end.key"),
        include_str!("../../rind-rustls/tests/keys/ecdsa-p256/ca.cert"),
    ),
    (
        include_str!("../../rind-rustls/tests/keys/ecdsa-p384/end.fullchain"),
        include_str!("../../rind-rustls/tests/keys/ecdsa-p384/end.key"),
        include_str!("../../rind-rustls/tests/keys/ecdsa-p384/ca.cert"),
    ),
    (
        include_str!("../../rind-rustls/tests/keys/ecdsa-p521/end.fullchain"),
        include_str!("../../rind-rustls/tests/keys/ecdsa-p521/end.key"),
        include_str!("../../rind-rustls/tests/keys/ecdsa-p521/ca.cert"),
    ),
    (
        include_str!("../../rind-rustls/tests/keys/ed25519/end.fullchain"),
        include_str!("../../rind-rustls/tests/keys/ed25519/end.key"),
        include_str!("../../rind-rustls/tests/keys/ed25519/ca.cert"),
    ),
    (
        include_str!("../../rind-rustls/tests/keys/rsa-2048/end.fullchain"),
        include_str!("../../rind-rustls/tests/keys/rsa-2048/end.key"),
        include_str!("../../rind-rustls/tests/keys/rsa-2048/ca.cert"),
    ),
];

fn chain(index: usize) -> Vec<CertificateDer<'static>> {
    CertificateDer::pem_slice_iter(KEYS[index].0.as_bytes())
        .collect::<Result<_, _>>()
        .unwrap()
}

fn private_key(index: usize) -> PrivateKeyDer<'static> {
    PrivateKeyDer::from_pem_slice(KEYS[index].1.as_bytes()).unwrap()
}

fn verify(algorithm: u8, key: PeerKey, message: &[u8], signature: PeerSignature) {
    let all = rind().signature_verification_algorithms.all;
    let ours = all[usize::from(algorithm) % all.len()];
    let theirs = *baseline()
        .signature_verification_algorithms
        .all
        .iter()
        .find(|theirs| {
            theirs.public_key_alg_id() == ours.public_key_alg_id()
                && theirs.signature_alg_id() == ours.signature_alg_id()
        })
        .expect("aws-lc-rs verifies every algorithm rind-rustls does");

    let (public_key, signature) = match key {
        PeerKey::Raw(public_key) => {
            let signature = match signature {
                PeerSignature::Raw(signature) => signature,
                PeerSignature::Signed(_) => return,
            };
            (public_key, signature)
        }
        PeerKey::Test(index, edit) => {
            let signer = baseline()
                .key_provider
                .load_private_key(private_key(usize::from(index) % KEYS.len()))
                .unwrap();
            let mut public_key = subject_public_key(signer.public_key().unwrap().as_ref());
            edit.apply(&mut public_key);
            let signature = match signature {
                PeerSignature::Raw(signature) => signature,
                PeerSignature::Signed(edit) => {
                    // The scheme that verifies with `ours`, if this key signs it.
                    let schemes = rind()
                        .signature_verification_algorithms
                        .mapping
                        .iter()
                        .filter(|(_, algorithms)| {
                            algorithms.iter().any(|a| {
                                a.signature_alg_id() == ours.signature_alg_id()
                                    && a.public_key_alg_id() == ours.public_key_alg_id()
                            })
                        })
                        .map(|(scheme, _)| *scheme)
                        .collect::<Vec<_>>();
                    let Some(signer) = signer.choose_scheme(&schemes) else {
                        return;
                    };
                    let mut signature = signer.sign(message).unwrap();
                    edit.apply(&mut signature);
                    signature
                }
            };
            (public_key, signature)
        }
    };

    let verify = |algorithm: &dyn SignatureVerificationAlgorithm| {
        algorithm
            .verify_signature(&public_key, message, &signature)
            .is_ok()
    };
    assert_eq!(verify(ours), verify(theirs), "{ours:?}");
}

/// The `subjectPublicKey` bits of a DER `SubjectPublicKeyInfo`, which is what
/// webpki hands a verifier.
fn subject_public_key(spki: &[u8]) -> Vec<u8> {
    // Each element's header: its tag, then a length of one byte or a long form.
    fn header(der: &[u8]) -> (usize, usize) {
        match der[1] {
            len @ 0..=0x7f => (2, usize::from(len)),
            long => {
                let n = usize::from(long & 0x7f);
                let len = der[2..2 + n]
                    .iter()
                    .fold(0, |len, b| len << 8 | usize::from(*b));
                (2 + n, len)
            }
        }
    }
    let (outer, _) = header(spki);
    let fields = &spki[outer..];
    let (algorithm_header, algorithm_len) = header(fields);
    let bits = &fields[algorithm_header + algorithm_len..];
    let (bits_header, bits_len) = header(bits);
    // The first content byte counts the unused bits, which are none.
    bits[bits_header + 1..bits_header + bits_len].to_vec()
}

/// A handshake between a rind client and a rind server, with the bytes of
/// each flight the edits name changed in flight.
#[derive(Arbitrary, Debug)]
struct Handshake {
    tls13: bool,
    suite: u8,
    group: u8,
    key: u8,
    client_auth: bool,
    edits: Vec<(u8, Edit)>,
}

impl Handshake {
    fn run(&self) {
        let key = usize::from(self.key) % KEYS.len();
        let rsa = key == 4;
        let suites = rind_rustls::ALL_CIPHER_SUITES
            .iter()
            .filter(|suite| match suite {
                SupportedCipherSuite::Tls13(_) => self.tls13,
                // TLS 1.2 binds the suite to the certificate's key type.
                SupportedCipherSuite::Tls12(s) => {
                    !self.tls13
                        && (s.sign.contains(&rustls::SignatureScheme::RSA_PSS_SHA256) == rsa)
                }
            })
            .collect::<Vec<_>>();
        let suite = *suites[usize::from(self.suite) % suites.len()];
        let groups = rind_rustls::ALL_KX_GROUPS
            .iter()
            .filter(|group| self.tls13 || group.usable_for_version(ProtocolVersion::TLSv1_2))
            .collect::<Vec<_>>();
        let group = *groups[usize::from(self.group) % groups.len()];

        let provider = Arc::new(CryptoProvider {
            cipher_suites: vec![suite],
            kx_groups: vec![group],
            ..rind_rustls::default_provider()
        });
        let versions: &[&rustls::SupportedProtocolVersion] = match self.tls13 {
            true => &[&rustls::version::TLS13],
            false => &[&rustls::version::TLS12],
        };
        let mut roots = RootCertStore::empty();
        roots
            .add(CertificateDer::from_pem_slice(KEYS[key].2.as_bytes()).unwrap())
            .unwrap();
        let roots = Arc::new(roots);

        let server = ServerConfig::builder_with_provider(provider.clone())
            .with_protocol_versions(versions)
            .unwrap();
        let server = match self.client_auth {
            true => server.with_client_cert_verifier(
                WebPkiClientVerifier::builder_with_provider(roots.clone(), provider.clone())
                    .build()
                    .unwrap(),
            ),
            false => server.with_no_client_auth(),
        };
        let server = server
            .with_single_cert(chain(key), private_key(key))
            .unwrap();

        let client = ClientConfig::builder_with_provider(provider)
            .with_protocol_versions(versions)
            .unwrap()
            .with_root_certificates(roots);
        let client = match self.client_auth {
            true => client
                .with_client_auth_cert(chain(key), private_key(key))
                .unwrap(),
            false => client.with_no_client_auth(),
        };

        let mut client = Connection::from(
            ClientConnection::new(Arc::new(client), "testserver.com".try_into().unwrap()).unwrap(),
        );
        let mut server = Connection::from(ServerConnection::new(Arc::new(server)).unwrap());
        client.writer().write_all(b"from client").unwrap();
        server.writer().write_all(b"from server").unwrap();

        // Each turn moves one flight each way, until neither has more to send or one fails.
        for turn in 0..8u8 {
            let to_server = self.flight(&mut client, 2 * turn);
            let to_client = self.flight(&mut server, 2 * turn + 1);
            if to_server.is_empty() && to_client.is_empty() {
                return;
            }
            if deliver(&mut server, &to_server).is_err()
                || deliver(&mut client, &to_client).is_err()
            {
                return;
            }
        }
    }

    /// What `from` sends next, edited if the edits name flight `index`.
    fn flight(&self, from: &mut Connection, index: u8) -> Vec<u8> {
        let mut bytes = Vec::new();
        while from.wants_write() {
            from.write_tls(&mut bytes).unwrap();
        }
        for (flight, edit) in &self.edits {
            if flight % 16 == index {
                edit.apply(&mut bytes);
            }
        }
        bytes
    }
}

/// Hands `bytes` to `to` and reads what it decrypted, failing as it does.
fn deliver(to: &mut Connection, mut bytes: &[u8]) -> Result<(), ()> {
    while !bytes.is_empty() {
        to.read_tls(&mut bytes).map_err(|_| ())?;
        to.process_new_packets().map_err(|_| ())?;
    }
    let mut data = Vec::new();
    let _ = to.reader().read_to_end(&mut data);
    Ok(())
}
