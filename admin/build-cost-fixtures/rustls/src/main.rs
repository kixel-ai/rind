use std::io::{Read, Write};
use std::net::TcpStream;
use std::sync::Arc;

use rustls::crypto::CryptoProvider;
use rustls::{ClientConfig, ClientConnection, RootCertStore, StreamOwned};

#[cfg(feature = "rind")]
fn provider() -> CryptoProvider {
    rind_rustls::default_provider().unwrap()
}

/// One TLS 1.3 suite, X25519, and ECDSA P-256 alone, so it reaches only a
/// host whose whole chain signs with P-256.
#[cfg(feature = "rind-lean")]
fn provider() -> CryptoProvider {
    use rind_rustls::{cipher_suite, kx_group, sign, verify};
    use rustls::SignatureScheme;
    use rustls::crypto::WebPkiSupportedAlgorithms;

    static P256: WebPkiSupportedAlgorithms = WebPkiSupportedAlgorithms {
        all: &[verify::ECDSA_P256_SHA256],
        mapping: &[(
            SignatureScheme::ECDSA_NISTP256_SHA256,
            &[verify::ECDSA_P256_SHA256],
        )],
    };
    CryptoProvider {
        cipher_suites: vec![cipher_suite::TLS13_AES_128_GCM_SHA256],
        kx_groups: vec![kx_group::X25519],
        signature_verification_algorithms: P256,
        key_provider: sign::ECDSA_P256,
        ..rind_rustls::empty_provider().unwrap()
    }
}

#[cfg(feature = "aws-lc-rs")]
fn provider() -> CryptoProvider {
    rustls::crypto::aws_lc_rs::default_provider()
}

#[cfg(feature = "ring")]
fn provider() -> CryptoProvider {
    rustls::crypto::ring::default_provider()
}

/// Fetches `/` from the host named by the first argument over HTTPS.
fn main() {
    let Some(host) = std::env::args().nth(1) else {
        eprintln!("usage: build-cost-rustls <host>");
        return;
    };

    let roots = RootCertStore {
        roots: webpki_roots::TLS_SERVER_ROOTS.to_vec(),
    };
    let config = ClientConfig::builder_with_provider(Arc::new(provider()))
        .with_safe_default_protocol_versions()
        .unwrap()
        .with_root_certificates(roots)
        .with_no_client_auth();
    let server_name = host.clone().try_into().unwrap();
    let connection = ClientConnection::new(Arc::new(config), server_name).unwrap();
    let socket = TcpStream::connect((host.as_str(), 443)).unwrap();
    let mut tls = StreamOwned::new(connection, socket);

    write!(
        tls,
        "GET / HTTP/1.1\r\nHost: {host}\r\nConnection: close\r\n\r\n"
    )
    .unwrap();
    let mut response = Vec::new();
    tls.read_to_end(&mut response).unwrap();
    println!(
        "{}",
        String::from_utf8_lossy(&response)
            .lines()
            .next()
            .unwrap_or("")
    );
}
