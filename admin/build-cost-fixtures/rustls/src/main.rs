use std::io::{Read, Write};
use std::net::TcpStream;
use std::sync::Arc;

use rustls::crypto::CryptoProvider;
use rustls::{ClientConfig, ClientConnection, RootCertStore, StreamOwned};

#[cfg(feature = "rind")]
fn provider() -> CryptoProvider {
    rind_rustls::default_provider().unwrap()
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
