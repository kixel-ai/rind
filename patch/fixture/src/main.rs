//! A QUIC handshake through quinn-proto, rustls, and rcgen on their `ring`
//! features, which a `[patch.crates-io]` of ring moves onto rind.

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
    // Only rind-ring has `cpu`, so this builds only with ring patched.
    ring::cpu::check()?;

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
