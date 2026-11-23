// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

use core::marker::PhantomData;

/// Reports whether rind runs AES on CPU instructions, as aws-lc's `EVP_has_aes_hardware` does.
///
/// Where it doesn't, ChaCha20-Poly1305 is faster than AES-GCM, so a protocol
/// that negotiates between them should prefer it.
#[must_use]
pub fn has_aes_hardware() -> bool {
    #[cfg(any(rind_backend = "arm", rind_backend = "aarch64"))]
    return super::HaveCryptoExt::check().is_some();
    #[cfg(rind_backend = "x86_64")]
    return super::x86_64::cpu::HaveAesHardware::check().is_some();
    #[cfg(rind_backend = "portable")]
    return false;
}

/// Holds data-independent timing (DIT) on for this thread until dropped.
///
/// On Apple's platforms, every rind call that handles a secret runs with DIT,
/// turning it on at entry and back off on return. On Apple's M1 that costs
/// about 55 ns a call, a fifth of sealing a 1350-byte QUIC packet, so
/// holding a guard across a batch of calls pays it once instead, for calls
/// made directly or through an adapter such as rind-rustls. Everywhere else
/// rind sets no DIT, and the guard does nothing.
///
/// Everything the thread runs while a guard is held runs with DIT, rind's
/// code or not. DIT stays on until the thread's last guard drops, in
/// whatever order they drop, and then turns off only if the first guard
/// found it off.
///
/// ```
/// use rind::aead::{AES_128_GCM, Key, Nonce};
///
/// let key = Key::new(&AES_128_GCM, &[0x42; 16]).unwrap();
/// let mut packets = [[0u8; 1200]; 4];
///
/// let _dit = rind::cpu::Dit::hold();
/// for (number, packet) in packets.iter_mut().enumerate() {
///     let mut nonce = [0u8; 12];
///     nonce[4..].copy_from_slice(&(number as u64).to_be_bytes());
///     let nonce = Nonce::assume_unique_for_key(nonce);
///     key.seal_in_place_separate_tag(nonce, b"header", packet)
///         .unwrap();
/// }
/// ```
///
/// A QUIC sender protects each packet twice: it seals the payload, then
/// masks the header with a sample of the ciphertext. Each is a call that
/// sets DIT, and the mask itself is a few nanoseconds of work beside the
/// toggle, so one guard over a burst of packets saves two toggles a packet:
///
/// ```
/// use rind::aead::quic::{AES_128, HeaderProtectionKey, SAMPLE_LEN};
/// use rind::aead::{AES_128_GCM, Key, Nonce};
///
/// let packet_key = Key::new(&AES_128_GCM, &[0x42; 16]).unwrap();
/// let header_key = HeaderProtectionKey::new(&AES_128, &[0x24; 16]).unwrap();
/// let iv = [0x11; 12];
/// // Each packet: a 1-byte flags field, an 8-byte connection id, a 4-byte
/// // packet number, then the payload.
/// const PN: core::ops::Range<usize> = 9..13;
/// let mut burst = [[0u8; 1200]; 8];
///
/// let _dit = rind::cpu::Dit::hold();
/// for (number, packet) in (0u64..).zip(burst.iter_mut()) {
///     packet[0] = 0x43;
///     packet[PN].copy_from_slice(&(number as u32).to_be_bytes());
///     let (header, payload) = packet.split_at_mut(PN.end);
///     let (payload, tag) = payload.split_at_mut(payload.len() - 16);
///     let nonce = Nonce::from_sequence(&iv, number);
///     let sealed = packet_key
///         .seal_in_place_separate_tag(nonce, header, payload)
///         .unwrap();
///     tag.copy_from_slice(sealed.as_ref());
///     // RFC 9001, section 5.4.2: the sample starts 4 bytes past the start
///     // of the packet number.
///     let sample: &[u8; SAMPLE_LEN] = packet[PN.start + 4..][..SAMPLE_LEN].try_into().unwrap();
///     let mask = header_key.mask(sample);
///     packet[0] ^= mask[0] & 0x1f;
///     for (byte, m) in packet[PN].iter_mut().zip(&mask[1..]) {
///         *byte ^= m;
///     }
/// }
/// ```
///
/// A thread that does nothing but such work, such as a dedicated packet
/// thread, can hold one guard for its whole life instead, made at the top of
/// the thread's function.
///
/// The guard only adds DIT. Every rind call that handles a secret still sets
/// it on entry if it finds it off, so a call made outside any guard is as
/// protected as one inside.
///
/// DIT belongs to a thread, so the guard can't leave the one that made it,
/// nor live across an `.await` in a task a multi-threaded runtime may move:
///
/// ```compile_fail,E0277
/// let dit = rind::cpu::Dit::hold();
/// std::thread::spawn(move || drop(dit));
/// ```
#[must_use = "DIT turns back off when the guard drops"]
#[derive(Debug)]
pub struct Dit {
    // Neither `Send` nor `Sync`: dropping it on another thread would count
    // against that thread's guards.
    _thread: PhantomData<*const ()>,
}

impl Dit {
    /// Turns DIT on for this thread, if rind sets it here, until the guard drops.
    pub fn hold() -> Self {
        #[cfg(rind_dit)]
        {
            let (guards, cpu_state) = DIT_GUARDS.get();
            let cpu_state = if guards == 0 {
                super::enter_cpu_state()
            } else {
                cpu_state
            };
            // Saturating, here and in `drop`: past `usize::MAX` guards the
            // count is inexact and DIT may turn off early, which costs speed
            // but never safety, since every rind call sets DIT itself.
            DIT_GUARDS.set((guards.saturating_add(1), cpu_state));
        }
        #[cfg(test)]
        super::entry::model::enter();
        Self {
            _thread: PhantomData,
        }
    }
}

impl Drop for Dit {
    fn drop(&mut self) {
        #[cfg(rind_dit)]
        {
            let (guards, cpu_state) = DIT_GUARDS.get();
            DIT_GUARDS.set((guards.saturating_sub(1), cpu_state));
            if guards == 1 {
                super::entry::leave_secret(cpu_state);
            }
        }
        #[cfg(test)]
        super::entry::model::leave();
    }
}

// Counted only where rind sets DIT, on Apple's aarch64 platforms, which all
// have threads and `std` (and under `--cfg rind_dit_everywhere`, only with
// `std`); elsewhere the guard holds nothing.
#[cfg(rind_dit)]
std::thread_local! {
    // This thread's live guards, and what the first one's `enter_cpu_state`
    // returned, for the last one to drop to restore.
    static DIT_GUARDS: core::cell::Cell<(usize, u32)> = const { core::cell::Cell::new((0, 0)) };
}

#[cfg(test)]
#[cfg_attr(coverage_nightly, coverage(off))]
mod tests {
    #[cfg(not(rind_backend = "portable"))]
    use crate::low::AesKey;

    /// The flag agrees with the AES keys run, whichever features are denied.
    #[test]
    fn has_aes_hardware_matches_keys() {
        #[cfg(not(rind_backend = "portable"))]
        let hardware = matches!(AesKey::new(&[0; 16]), AesKey::Hw(_));
        #[cfg(rind_backend = "portable")]
        let hardware = false;
        assert_eq!(super::has_aes_hardware(), hardware);
    }
}
