//! Consumers of ring and aws-lc-rs moved onto rind by `[patch.crates-io]`.

use std::error::Error;
use std::net::{Ipv6Addr, SocketAddr};
use std::sync::Arc;
use std::time::Instant;

use bytes::BytesMut;
use quinn_proto::{
    ClientConfig, Connection, ConnectionHandle, DatagramEvent, Endpoint, EndpointConfig, Event,
    ServerConfig,
};
use rustls::RootCertStore;
use rustls::pki_types::PrivatePkcs8KeyDer;

const SERVER: SocketAddr = SocketAddr::new(std::net::IpAddr::V6(Ipv6Addr::LOCALHOST), 4433);
const CLIENT: SocketAddr = SocketAddr::new(std::net::IpAddr::V6(Ipv6Addr::LOCALHOST), 4434);

fn main() -> Result<(), Box<dyn Error>> {
    // Only rind's adapters have `cpu`, so this builds only with both patched.
    ring::cpu::check()?;
    aws_lc_rs::cpu::check()?;
    s2n_packets()?;
    jwt()?;
    quic_handshake()
}

fn s2n_packets() -> Result<(), Box<dyn Error>> {
    use s2n_codec::{Encoder, EncoderBuffer};
    use s2n_quic_core::crypto::{HeaderKey, InitialKey as _, Key, RetryKey as _, scatter};
    use s2n_quic_crypto::{initial::InitialKey, retry::RetryKey};

    let (mut client, client_header) = InitialKey::new_client(b"connection id");
    let (server, server_header) = InitialKey::new_server(b"connection id");
    let message = b"initial payload";
    let header = b"initial header";
    let mut packet = vec![0; message.len() + client.tag_len()];
    let mut encoder = EncoderBuffer::new(&mut packet);
    encoder.write_slice(message);
    client
        .encrypt(0, header, &mut scatter::Buffer::new(encoder))
        .map_err(|e| format!("s2n encrypt: {e:?}"))?;
    let sample = &packet[..client_header.sealing_sample_len()];
    assert_eq!(
        client_header.sealing_header_protection_mask(sample),
        server_header.opening_header_protection_mask(sample)
    );
    let mut tampered = packet.clone();
    tampered[0] ^= 1;
    assert!(server.decrypt(0, header, &mut tampered).is_err());
    server
        .decrypt(0, header, &mut packet)
        .map_err(|e| format!("s2n decrypt: {e:?}"))?;
    assert_eq!(&packet[..message.len()], message);

    let tag = RetryKey::generate_tag(header);
    RetryKey::validate(header, tag).map_err(|e| format!("s2n retry: {e:?}"))?;
    assert!(RetryKey::validate(b"altered header", tag).is_err());
    println!("s2n-quic Initial packet and Retry authenticated on rind");
    Ok(())
}

fn jwt() -> Result<(), Box<dyn Error>> {
    use aws_lc_rs::signature::{ECDSA_P256_SHA256_FIXED_SIGNING, EcdsaKeyPair, KeyPair};
    use jsonwebtoken::{Algorithm, DecodingKey, EncodingKey, Header, Validation, decode, encode};

    let alg = &ECDSA_P256_SHA256_FIXED_SIGNING;
    let pkcs8 = EcdsaKeyPair::generate_pkcs8(alg, &aws_lc_rs::rand::SystemRandom::new())?;
    let key = EcdsaKeyPair::from_pkcs8(alg, pkcs8.as_ref())?;
    let claims = serde_json::json!({"sub": "patch fixture"});
    let token = encode(
        &Header::new(Algorithm::ES256),
        &claims,
        &EncodingKey::from_ec_der(pkcs8.as_ref()),
    )?;
    // Test the signature without depending on the wall clock.
    let mut validation = Validation::new(Algorithm::ES256);
    validation.required_spec_claims.clear();
    validation.validate_exp = false;
    let public = DecodingKey::from_ec_der(key.public_key().as_ref());
    assert_eq!(
        decode::<serde_json::Value>(&token, &public, &validation)?.claims,
        claims
    );
    let altered = token.replacen(
        token.split('.').nth(1).ok_or("missing JWT claims")?,
        "e30",
        1,
    );
    assert!(decode::<serde_json::Value>(&altered, &public, &validation).is_err());
    println!("jsonwebtoken ES256 signed and verified on rind");
    Ok(())
}

fn quic_handshake() -> Result<(), Box<dyn Error>> {
    let cert = rcgen::generate_simple_self_signed(["localhost".to_owned()])?;
    let key = PrivatePkcs8KeyDer::from(cert.signing_key.serialize_der());
    let server_config = ServerConfig::with_single_cert(vec![cert.cert.der().clone()], key.into())?;
    let mut roots = RootCertStore::empty();
    roots.add(cert.cert.der().clone())?;
    let client_config = ClientConfig::with_root_certificates(Arc::new(roots))?;

    let now = Instant::now();
    let mut server = Endpoint::new(
        Arc::new(EndpointConfig::default()),
        Some(Arc::new(server_config)),
        true,
        None,
    );
    let mut client = Endpoint::new(Arc::new(EndpointConfig::default()), None, true, None);
    let (client_handle, client_conn) = client.connect(now, client_config, SERVER, "localhost")?;
    let mut client_side = (client_handle, client_conn);
    let mut server_side: Option<(ConnectionHandle, Connection)> = None;
    let (mut client_up, mut server_up) = (false, false);
    let mut retried = false;

    for _ in 0..16 {
        for datagram in drain(&mut client, &mut client_side, now) {
            let mut buf = Vec::new();
            match server.handle(now, CLIENT, None, None, datagram, &mut buf) {
                // A Retry runs quinn's address-validation token and Retry tag, both ring calls.
                Some(DatagramEvent::NewConnection(incoming))
                    if !incoming.remote_address_validated() =>
                {
                    let transmit = server
                        .retry(incoming, &mut buf)
                        .map_err(|e| format!("retry: {e:?}"))?;
                    deliver(
                        &mut client,
                        &mut client_side,
                        SERVER,
                        &buf[..transmit.size],
                        now,
                    );
                    retried = true;
                }
                Some(DatagramEvent::NewConnection(incoming)) => {
                    server_side = Some(
                        server
                            .accept(incoming, now, &mut buf, None)
                            .map_err(|e| e.cause)?,
                    );
                }
                Some(DatagramEvent::ConnectionEvent(_, event)) => {
                    server_side
                        .as_mut()
                        .ok_or("event before accept")?
                        .1
                        .handle_event(event);
                }
                Some(DatagramEvent::Response(transmit)) => {
                    deliver(
                        &mut client,
                        &mut client_side,
                        SERVER,
                        &buf[..transmit.size],
                        now,
                    );
                }
                None => {}
            }
        }
        if let Some(side) = server_side.as_mut() {
            for datagram in drain(&mut server, side, now) {
                deliver(&mut client, &mut client_side, SERVER, &datagram, now);
            }
            server_up |= connected(&mut side.1)?;
        }
        client_up |= connected(&mut client_side.1)?;
        if client_up && server_up {
            if !retried {
                return Err("the handshake skipped the Retry".into());
            }
            println!("QUIC handshake with a Retry completed on rind");
            return Ok(());
        }
    }
    Err("handshake did not complete".into())
}

/// Hands each pending endpoint event to its endpoint, then returns every datagram the connection would send.
fn drain(
    endpoint: &mut Endpoint,
    (handle, conn): &mut (ConnectionHandle, Connection),
    now: Instant,
) -> Vec<BytesMut> {
    while let Some(event) = conn.poll_endpoint_events() {
        if let Some(event) = endpoint.handle_event(*handle, event) {
            conn.handle_event(event);
        }
    }
    let mut out = Vec::new();
    let mut buf = Vec::new();
    while let Some(transmit) = conn.poll_transmit(now, 1, &mut buf) {
        out.push(BytesMut::from(&buf[..transmit.size]));
        buf.clear();
    }
    out
}

/// Passes one datagram from the server to the client's connection.
fn deliver(
    endpoint: &mut Endpoint,
    (_, conn): &mut (ConnectionHandle, Connection),
    from: SocketAddr,
    datagram: &[u8],
    now: Instant,
) {
    let mut buf = Vec::new();
    if let Some(DatagramEvent::ConnectionEvent(_, event)) =
        endpoint.handle(now, from, None, None, BytesMut::from(datagram), &mut buf)
    {
        conn.handle_event(event);
    }
}

/// Whether the connection has finished its handshake, failing if it was lost.
fn connected(conn: &mut Connection) -> Result<bool, Box<dyn Error>> {
    let mut up = false;
    while let Some(event) = conn.poll() {
        match event {
            Event::Connected => up = true,
            Event::ConnectionLost { reason } => {
                return Err(format!("connection lost: {reason}").into());
            }
            _ => {}
        }
    }
    Ok(up)
}
