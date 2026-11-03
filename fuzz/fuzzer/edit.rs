//! Tampering with a valid message, so a target reaches the paths past its
//! length and format checks.

use libfuzzer_sys::{arbitrary, arbitrary::Arbitrary};

/// Bytes to flip in a message, then how many to cut from its end.
#[derive(Arbitrary, Debug)]
pub struct Edit {
    flips: Vec<(u16, u8)>,
    cut: u8,
}

impl Edit {
    /// Applies this edit to `bytes`, returning whether it changed them.
    pub fn apply(&self, bytes: &mut Vec<u8>) -> bool {
        let original = bytes.clone();
        if !bytes.is_empty() {
            for &(index, xor) in &self.flips {
                let index = usize::from(index) % bytes.len();
                bytes[index] ^= xor;
            }
        }
        bytes.truncate(bytes.len().saturating_sub(usize::from(self.cut)));
        *bytes != original
    }
}
