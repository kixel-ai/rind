// Copyright (c) 2016-2022 INRIA, CMU and Microsoft Corporation
// Copyright (c) 2022-2023 HACL* Contributors
// Copyright 2023 Cryspen Sarl
// SPDX-License-Identifier: Apache-2.0
//
// ChaCha20's state setup, from HACL*'s verified `Hacl_Chacha20` as
// libcrux-chacha20poly1305 0.0.10 ships it (`src/hacl/chacha20.rs`), less
// the module paths, since libcrux does not export them. The keystream is
// aws-lc's, in `chacha_armv4`, which measured faster than HACL*'s block
// function at every length.

#![allow(non_snake_case)]
#![allow(non_upper_case_globals)]
#![allow(non_camel_case_types)]
#![allow(unused_assignments)]
#![allow(unreachable_patterns)]

use libcrux_hacl_rs::prelude::*;
use libcrux_macros as krml;

use super::chacha_armv4::chacha20_ctr32;
use super::cpu::HaveNeon;

pub(crate) const chacha20_constants: [u32; 4] =
    [0x61707865u32, 0x3320646eu32, 0x79622d32u32, 0x6b206574u32];

fn chacha20_init(ctx: &mut [u32], k: &[u8], n: &[u8], ctr: u32) {
    krml::unroll_for!(4, "i", 0u32, 1u32, {
        let x: u32 = (&chacha20_constants)[i as usize];
        let os: &mut [u32] = &mut (&mut ctx[0usize..])[0usize..];
        os[i as usize] = x
    });
    let uu____0: (&mut [u32], &mut [u32]) = ctx.split_at_mut(4usize);
    krml::unroll_for!(8, "i", 0u32, 1u32, {
        let bj: (&[u8], &[u8]) = k.split_at(i.wrapping_mul(4u32) as usize);
        let u: u32 = lowstar::endianness::load32_le(bj.1);
        let r: u32 = u;
        let x: u32 = r;
        let os: (&mut [u32], &mut [u32]) = uu____0.1.split_at_mut(0usize);
        os.1[i as usize] = x
    });
    ctx[12usize] = ctr;
    let uu____1: (&mut [u32], &mut [u32]) = ctx.split_at_mut(13usize);
    krml::unroll_for!(3, "i", 0u32, 1u32, {
        let bj: (&[u8], &[u8]) = n.split_at(i.wrapping_mul(4u32) as usize);
        let u: u32 = lowstar::endianness::load32_le(bj.1);
        let r: u32 = u;
        let x: u32 = r;
        let os: (&mut [u32], &mut [u32]) = uu____1.1.split_at_mut(0usize);
        os.1[i as usize] = x
    })
}

pub(crate) struct ChaCha20 {
    ctx: [u32; 16],
    neon: Option<HaveNeon>,
}

impl ChaCha20 {
    /// `nonce` is the little-endian block counter followed by the 96-bit nonce.
    pub(crate) fn new(key: &[u8; 32], nonce: &[u8; 16]) -> Self {
        let mut ctx = [0u32; 16];
        let (counter, nonce) = nonce.split_at(4);
        chacha20_init(
            &mut ctx,
            key,
            nonce,
            u32::from_le_bytes([counter[0], counter[1], counter[2], counter[3]]),
        );
        Self {
            ctx,
            neon: HaveNeon::check(),
        }
    }

    /// XORs the keystream into `buffer`, starting at the current block, then
    /// moves the counter past every block it touched.
    pub(crate) fn cipher(&mut self, buffer: &mut [u8]) {
        chacha20_ctr32(&self.ctx, buffer, self.neon);
        self.ctx[12] = self.ctx[12].wrapping_add(buffer.len().div_ceil(64) as u32);
    }
}
