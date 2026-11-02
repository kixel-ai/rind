// Written for Graviola by Joe Birr-Pixton, 2024.
// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

#[derive(Clone)]
pub(crate) struct Blockwise<const N: usize> {
    buffer: [u8; N],
    used: usize,
}

impl<const N: usize> Blockwise<N> {
    pub(crate) const fn new() -> Self {
        Self {
            buffer: [0u8; N],
            used: 0,
        }
    }

    pub(crate) const fn used(&self) -> usize {
        self.used
    }

    #[cfg(not(target_arch = "arm"))]
    pub(crate) fn add(&mut self, bytes: &[u8]) {
        if self.used == 0 {
            self.add_trailing(bytes);
        } else {
            self.add_leading(bytes);
        }
    }

    /// Adds `bytes`, passing each run of whole blocks to `blocks` in order and
    /// holding the rest.
    pub(crate) fn update(&mut self, bytes: &[u8], blocks: impl FnMut(&[u8])) {
        let used = self.used;
        // A short update, such as a one-byte one, only copies. Storing
        // `used` first, and leaving blocks to another function, lets it
        // save no registers and tail-call the copy.
        if bytes.len() < N - used {
            self.used = used + bytes.len();
            self.buffer[used..used + bytes.len()].copy_from_slice(bytes);
        } else {
            self.complete_blocks(bytes, blocks);
        }
    }

    #[inline(never)]
    fn complete_blocks(&mut self, mut bytes: &[u8], mut blocks: impl FnMut(&[u8])) {
        let used = self.used;
        if used > 0 {
            let (head, rest) = bytes.split_at(N - used);
            self.buffer[used..].copy_from_slice(head);
            blocks(&self.buffer);
            bytes = rest;
        }

        let (whole, rest) = bytes.split_at(bytes.len() - bytes.len() % N);
        if !whole.is_empty() {
            blocks(whole);
        }
        self.buffer[..rest.len()].copy_from_slice(rest);
        self.used = rest.len();
    }

    pub(crate) fn add_leading<'a>(&mut self, bytes: &'a [u8]) -> &'a [u8] {
        if self.used == 0 {
            return bytes;
        }

        let space = N - self.used;
        let take = core::cmp::min(bytes.len(), space);
        let (taken, returned) = bytes.split_at(take);
        self.buffer[self.used..self.used + take].copy_from_slice(taken);
        self.used += take;
        returned
    }

    pub(crate) fn take(&mut self) -> Option<[u8; N]> {
        if self.used == N {
            self.used = 0;
            Some(self.buffer)
        } else {
            None
        }
    }

    // Only Poly1305's tail reads it.
    #[cfg(any(target_arch = "x86_64", all(target_arch = "aarch64", test)))]
    pub(crate) fn peek_remaining(&self) -> Option<&[u8]> {
        if self.used > 0 {
            Some(&self.buffer[..self.used])
        } else {
            None
        }
    }

    /// The bytes held short of a whole block.
    pub(crate) fn buffered(&self) -> &[u8] {
        &self.buffer[..self.used]
    }

    pub(crate) fn add_trailing(&mut self, trailing: &[u8]) {
        self.buffer[..trailing.len()].copy_from_slice(trailing);
        self.used += trailing.len();
    }
}
