// Written for Graviola by Joe Birr-Pixton, 2026.
// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

/// Unpack ML-KEM polynomial coefficients as 12-bit numbers
///
/// Input a[384] (bytes); output r[256] (signed 16-bit words)
///
/// This accepts an array of 384 bytes and unpacks them into 256 16-bit numbers
/// in the range 0 <= a[i] < 2^12 (typically they will be < 3329, the ML-KEM prime).
pub(crate) fn mlkem_frombytes(r: &mut [i16; 256], a: &[u8; 384]) {
    let (r_chunks, _) = r.as_chunks_mut::<2>();
    let (a_chunks, _) = a.as_chunks::<3>();
    for (r, a) in r_chunks.iter_mut().zip(a_chunks.iter()) {
        r[0] = (a[0] as i16) | (((a[1] & 0x0f) as i16) << 8);
        r[1] = ((a[1] >> 4) as i16) | ((a[2] as i16) << 4);
    }
}

/// Reorder ML-KEM polynomial coefficients for the current implementation
///
/// Input/output a[256] (signed 16-bit words)
///
/// This reorders coefficients from their natural order into the order
/// used by the rest of the implementation.  The x86_64 AVX2 version of this
/// function produces the layout required by the AVX2 NTT; this
/// implementation (and the functions it works alongside, like
/// [`mlkem_frombytes`]) uses the natural order, so there is nothing to do.
pub(crate) fn mlkem_unpack(_a: &mut [i16; 256]) {}

/// Compress ML-KEM polynomial coefficients to 10 bits each, and pack them
///
/// Input a[256] (signed 16-bit words, each in `[0, Q)`); output r[320] (bytes)
///
/// This is FIPS 203's `ByteEncode_10(Compress_10(a))`: each group of four
/// coefficients becomes five bytes, little-endian bit order per `BitsToBytes`.
pub(crate) fn mlkem_compress_d10(r: &mut [u8; 320], a: &[i16; 256]) {
    let (quads, _) = a.as_chunks::<4>();
    let (out_chunks, _) = r.as_chunks_mut::<5>();

    for (quad, out) in quads.iter().zip(out_chunks.iter_mut()) {
        let t0 = compress_10(quad[0]);
        let t1 = compress_10(quad[1]);
        let t2 = compress_10(quad[2]);
        let t3 = compress_10(quad[3]);

        out[0] = t0 as u8;
        out[1] = ((t0 >> 8) | (t1 << 2)) as u8;
        out[2] = ((t1 >> 6) | (t2 << 4)) as u8;
        out[3] = ((t2 >> 4) | (t3 << 6)) as u8;
        out[4] = (t3 >> 2) as u8;
    }
}

/// Compress ML-KEM polynomial coefficients to 4 bits each, and pack them
///
/// Input a[256] (signed 16-bit words, each in `[0, Q)`); output r[128] (bytes)
///
/// This is FIPS 203's `ByteEncode_4(Compress_4(a))`: each pair of
/// coefficients becomes one byte, low nibble first.
pub(crate) fn mlkem_compress_d4(r: &mut [u8; 128], a: &[i16; 256]) {
    let (pairs, _) = a.as_chunks::<2>();
    for (pair, byte) in pairs.iter().zip(r.iter_mut()) {
        *byte = compress_4(pair[0]) | (compress_4(pair[1]) << 4);
    }
}

const Q: i16 = 3329;
const Q_HALF: i16 = (Q + 1) / 2;

/// `Compress_4(x) = round((2^4 / q) * x) mod 2^4`, for x in [0, Q)
///
/// Division-free so no variable-time division instruction is emitted
/// (cf. KyberSlash); the constant is exact over the whole input range.
fn compress_4(x: i16) -> u8 {
    debug_assert!((0..Q).contains(&crate::low::ct::into_public(x)));
    let c = x as u64;
    let c = c << 4;
    let c = c.wrapping_add(Q_HALF as u64);
    let c = c.wrapping_mul(80635);
    let c = c >> 28;
    let c = c & 0xf;
    c as u8
}

/// `Compress_10(x) = round((2^10 / q) * x) mod 2^10`, for x in [0, Q)
fn compress_10(x: i16) -> u16 {
    debug_assert!((0..Q).contains(&crate::low::ct::into_public(x)));
    let c = x as u64;
    let c = c << 10;
    let c = c.wrapping_add(Q_HALF as u64);
    let c = c.wrapping_mul(1290167);
    let c = c >> 32;
    let c = c & 0x3ff;
    c as u16
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn unpacks_known_values() {
        let mut a = [0u8; 384];
        // first pair of coefficients: 0xabc and 0xdef, packed little-endian
        // per FIPS 203 ByteEncode_12
        a[0] = 0xbc;
        a[1] = 0xfa;
        a[2] = 0xde;

        let mut r = [0i16; 256];
        mlkem_frombytes(&mut r, &a);
        assert_eq!(r[0], 0xabc);
        assert_eq!(r[1], 0xdef);
        assert_eq!(&r[2..], &[0i16; 254]);
    }

    #[test]
    fn output_is_at_most_12_bits() {
        let a = [0xffu8; 384];
        let mut r = [0i16; 256];
        mlkem_frombytes(&mut r, &a);
        assert_eq!(r, [0xfff; 256]);
    }
}
