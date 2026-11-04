// generated source. do not edit.
#![allow(non_upper_case_globals, unused_macros, unused_imports)]
use crate::low::macros::*;

// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

// ----------------------------------------------------------------------------
// Scalar multiplication for the edwards25519 standard basepoint
// Input scalar[4]; output res[8]
//
// extern void edwards25519_scalarmulbase_alt
//   (uint64_t res[static 8],const uint64_t scalar[static 4]);
//
// Given a scalar n, returns point (X,Y) = n * B where B = (...,4/5) is
// the standard basepoint for the edwards25519 (Ed25519) curve.
//
// Standard x86-64 ABI: RDI = res, RSI = scalar
// Microsoft x64 ABI:   RCX = res, RDX = scalar
// ----------------------------------------------------------------------------

// Size of individual field elements

macro_rules! NUMSIZE {
    () => {
        "32"
    };
}

// Pointer-offset pairs for result and temporaries on stack with some aliasing.
// The result "resx" assumes the "res" pointer has been preloaded into rbp.

macro_rules! resx { () => { Q!("rbp + (0 * " NUMSIZE!() ")") } }
macro_rules! resy { () => { Q!("rbp + (1 * " NUMSIZE!() ")") } }

macro_rules! scalar { () => { Q!("rsp + (0 * " NUMSIZE!() ")") } }

macro_rules! tabent { () => { Q!("rsp + (1 * " NUMSIZE!() ")") } }
macro_rules! ymx_2 { () => { Q!("rsp + (1 * " NUMSIZE!() ")") } }
macro_rules! xpy_2 { () => { Q!("rsp + (2 * " NUMSIZE!() ")") } }
macro_rules! kxy_2 { () => { Q!("rsp + (3 * " NUMSIZE!() ")") } }

macro_rules! t0 { () => { Q!("rsp + (4 * " NUMSIZE!() ")") } }
macro_rules! t1 { () => { Q!("rsp + (5 * " NUMSIZE!() ")") } }
macro_rules! t2 { () => { Q!("rsp + (6 * " NUMSIZE!() ")") } }
macro_rules! t3 { () => { Q!("rsp + (7 * " NUMSIZE!() ")") } }
macro_rules! t4 { () => { Q!("rsp + (8 * " NUMSIZE!() ")") } }
macro_rules! t5 { () => { Q!("rsp + (9 * " NUMSIZE!() ")") } }

macro_rules! acc { () => { Q!("rsp + (10 * " NUMSIZE!() ")") } }
macro_rules! x_1 { () => { Q!("rsp + (10 * " NUMSIZE!() ")") } }
macro_rules! y_1 { () => { Q!("rsp + (11 * " NUMSIZE!() ")") } }
macro_rules! z_1 { () => { Q!("rsp + (12 * " NUMSIZE!() ")") } }
macro_rules! w_1 { () => { Q!("rsp + (13 * " NUMSIZE!() ")") } }
macro_rules! x_3 { () => { Q!("rsp + (10 * " NUMSIZE!() ")") } }
macro_rules! y_3 { () => { Q!("rsp + (11 * " NUMSIZE!() ")") } }
macro_rules! z_3 { () => { Q!("rsp + (12 * " NUMSIZE!() ")") } }
macro_rules! w_3 { () => { Q!("rsp + (13 * " NUMSIZE!() ")") } }

// Stable homes for the input result pointer, and other variables

macro_rules! res { () => { Q!("QWORD PTR [rsp + 14 * " NUMSIZE!() "]") } }

macro_rules! i { () => { Q!("QWORD PTR [rsp + 14 * " NUMSIZE!() "+ 8]") } }

macro_rules! bias { () => { Q!("QWORD PTR [rsp + 14 * " NUMSIZE!() "+ 16]") } }

macro_rules! bf { () => { Q!("QWORD PTR [rsp + 14 * " NUMSIZE!() "+ 24]") } }
macro_rules! ix { () => { Q!("QWORD PTR [rsp + 14 * " NUMSIZE!() "+ 24]") } }

macro_rules! tab { () => { Q!("QWORD PTR [rsp + 15 * " NUMSIZE!() "]") } }

// Total size to reserve on the stack

macro_rules! NSPACE {
    () => {
        "488"
    };
}

// Syntactic variants to make x86_att version simpler to generate

macro_rules! SCALAR {
    () => {
        "0"
    };
}
macro_rules! TABENT { () => { Q!("(1 * " NUMSIZE!() ")") } }
macro_rules! ACC { () => { Q!("(10 * " NUMSIZE!() ")") } }
macro_rules! X3 { () => { Q!("(10 * " NUMSIZE!() ")") } }
macro_rules! Z3 { () => { Q!("(12 * " NUMSIZE!() ")") } }
macro_rules! W3 { () => { Q!("(13 * " NUMSIZE!() ")") } }

// Macro wrapping up the basic field multiplication, only trivially
// different from a pure function call to bignum_mul_p25519_alt.

macro_rules! mul_p25519 {
    ($P0:expr, $P1:expr, $P2:expr) => { Q!(
        "mov rax, [" $P1 "];\n"
        "mul QWORD PTR [" $P2 "];\n"
        "mov r8, rax;\n"
        "mov r9, rdx;\n"
        "xor r10, r10;\n"
        "xor r11, r11;\n"
        "mov rax, [" $P1 "];\n"
        "mul QWORD PTR [" $P2 "+ 0x8];\n"
        "add r9, rax;\n"
        "adc r10, rdx;\n"
        "mov rax, [" $P1 "+ 0x8];\n"
        "mul QWORD PTR [" $P2 "];\n"
        "add r9, rax;\n"
        "adc r10, rdx;\n"
        "adc r11, 0x0;\n"
        "xor r12, r12;\n"
        "mov rax, [" $P1 "];\n"
        "mul QWORD PTR [" $P2 "+ 0x10];\n"
        "add r10, rax;\n"
        "adc r11, rdx;\n"
        "adc r12, r12;\n"
        "mov rax, [" $P1 "+ 0x8];\n"
        "mul QWORD PTR [" $P2 "+ 0x8];\n"
        "add r10, rax;\n"
        "adc r11, rdx;\n"
        "adc r12, 0x0;\n"
        "mov rax, [" $P1 "+ 0x10];\n"
        "mul QWORD PTR [" $P2 "];\n"
        "add r10, rax;\n"
        "adc r11, rdx;\n"
        "adc r12, 0x0;\n"
        "xor r13, r13;\n"
        "mov rax, [" $P1 "];\n"
        "mul QWORD PTR [" $P2 "+ 0x18];\n"
        "add r11, rax;\n"
        "adc r12, rdx;\n"
        "adc r13, r13;\n"
        "mov rax, [" $P1 "+ 0x8];\n"
        "mul QWORD PTR [" $P2 "+ 0x10];\n"
        "add r11, rax;\n"
        "adc r12, rdx;\n"
        "adc r13, 0x0;\n"
        "mov rax, [" $P1 "+ 0x10];\n"
        "mul QWORD PTR [" $P2 "+ 0x8];\n"
        "add r11, rax;\n"
        "adc r12, rdx;\n"
        "adc r13, 0x0;\n"
        "mov rax, [" $P1 "+ 0x18];\n"
        "mul QWORD PTR [" $P2 "];\n"
        "add r11, rax;\n"
        "adc r12, rdx;\n"
        "adc r13, 0x0;\n"
        "xor r14, r14;\n"
        "mov rax, [" $P1 "+ 0x8];\n"
        "mul QWORD PTR [" $P2 "+ 0x18];\n"
        "add r12, rax;\n"
        "adc r13, rdx;\n"
        "adc r14, r14;\n"
        "mov rax, [" $P1 "+ 0x10];\n"
        "mul QWORD PTR [" $P2 "+ 0x10];\n"
        "add r12, rax;\n"
        "adc r13, rdx;\n"
        "adc r14, 0x0;\n"
        "mov rax, [" $P1 "+ 0x18];\n"
        "mul QWORD PTR [" $P2 "+ 0x8];\n"
        "add r12, rax;\n"
        "adc r13, rdx;\n"
        "adc r14, 0x0;\n"
        "xor r15, r15;\n"
        "mov rax, [" $P1 "+ 0x10];\n"
        "mul QWORD PTR [" $P2 "+ 0x18];\n"
        "add r13, rax;\n"
        "adc r14, rdx;\n"
        "adc r15, r15;\n"
        "mov rax, [" $P1 "+ 0x18];\n"
        "mul QWORD PTR [" $P2 "+ 0x10];\n"
        "add r13, rax;\n"
        "adc r14, rdx;\n"
        "adc r15, 0x0;\n"
        "mov rax, [" $P1 "+ 0x18];\n"
        "mul QWORD PTR [" $P2 "+ 0x18];\n"
        "add r14, rax;\n"
        "adc r15, rdx;\n"
        "mov esi, 0x26;\n"
        "mov rax, r12;\n"
        "mul rsi;\n"
        "add r8, rax;\n"
        "adc r9, rdx;\n"
        "sbb rcx, rcx;\n"
        "mov rax, r13;\n"
        "mul rsi;\n"
        "sub rdx, rcx;\n"
        "add r9, rax;\n"
        "adc r10, rdx;\n"
        "sbb rcx, rcx;\n"
        "mov rax, r14;\n"
        "mul rsi;\n"
        "sub rdx, rcx;\n"
        "add r10, rax;\n"
        "adc r11, rdx;\n"
        "sbb rcx, rcx;\n"
        "mov rax, r15;\n"
        "mul rsi;\n"
        "sub rdx, rcx;\n"
        "xor rcx, rcx;\n"
        "add r11, rax;\n"
        "mov r12, rdx;\n"
        "adc r12, rcx;\n"
        "shld r12, r11, 0x1;\n"
        "lea rax, [r12 + 0x1];\n"
        "mov esi, 0x13;\n"
        "bts r11, 63;\n"
        "imul rax, rsi;\n"
        "add r8, rax;\n"
        "adc r9, rcx;\n"
        "adc r10, rcx;\n"
        "adc r11, rcx;\n"
        "sbb rax, rax;\n"
        "not rax;\n"
        "and rax, rsi;\n"
        "sub r8, rax;\n"
        "sbb r9, rcx;\n"
        "sbb r10, rcx;\n"
        "sbb r11, rcx;\n"
        "btr r11, 63;\n"
        "mov [" $P0 "], r8;\n"
        "mov [" $P0 "+ 0x8], r9;\n"
        "mov [" $P0 "+ 0x10], r10;\n"
        "mov [" $P0 "+ 0x18], r11"
    )}
}

// A version of multiplication that only guarantees output < 2 * p_25519.
// This basically skips the +1 and final correction in quotient estimation.

macro_rules! mul_4 {
    ($P0:expr, $P1:expr, $P2:expr) => { Q!(
        "mov rax, [" $P1 "];\n"
        "mul QWORD PTR [" $P2 "];\n"
        "mov r8, rax;\n"
        "mov r9, rdx;\n"
        "xor r10, r10;\n"
        "xor r11, r11;\n"
        "mov rax, [" $P1 "];\n"
        "mul QWORD PTR [" $P2 "+ 0x8];\n"
        "add r9, rax;\n"
        "adc r10, rdx;\n"
        "mov rax, [" $P1 "+ 0x8];\n"
        "mul QWORD PTR [" $P2 "];\n"
        "add r9, rax;\n"
        "adc r10, rdx;\n"
        "adc r11, 0x0;\n"
        "xor r12, r12;\n"
        "mov rax, [" $P1 "];\n"
        "mul QWORD PTR [" $P2 "+ 0x10];\n"
        "add r10, rax;\n"
        "adc r11, rdx;\n"
        "adc r12, r12;\n"
        "mov rax, [" $P1 "+ 0x8];\n"
        "mul QWORD PTR [" $P2 "+ 0x8];\n"
        "add r10, rax;\n"
        "adc r11, rdx;\n"
        "adc r12, 0x0;\n"
        "mov rax, [" $P1 "+ 0x10];\n"
        "mul QWORD PTR [" $P2 "];\n"
        "add r10, rax;\n"
        "adc r11, rdx;\n"
        "adc r12, 0x0;\n"
        "xor r13, r13;\n"
        "mov rax, [" $P1 "];\n"
        "mul QWORD PTR [" $P2 "+ 0x18];\n"
        "add r11, rax;\n"
        "adc r12, rdx;\n"
        "adc r13, r13;\n"
        "mov rax, [" $P1 "+ 0x8];\n"
        "mul QWORD PTR [" $P2 "+ 0x10];\n"
        "add r11, rax;\n"
        "adc r12, rdx;\n"
        "adc r13, 0x0;\n"
        "mov rax, [" $P1 "+ 0x10];\n"
        "mul QWORD PTR [" $P2 "+ 0x8];\n"
        "add r11, rax;\n"
        "adc r12, rdx;\n"
        "adc r13, 0x0;\n"
        "mov rax, [" $P1 "+ 0x18];\n"
        "mul QWORD PTR [" $P2 "];\n"
        "add r11, rax;\n"
        "adc r12, rdx;\n"
        "adc r13, 0x0;\n"
        "xor r14, r14;\n"
        "mov rax, [" $P1 "+ 0x8];\n"
        "mul QWORD PTR [" $P2 "+ 0x18];\n"
        "add r12, rax;\n"
        "adc r13, rdx;\n"
        "adc r14, r14;\n"
        "mov rax, [" $P1 "+ 0x10];\n"
        "mul QWORD PTR [" $P2 "+ 0x10];\n"
        "add r12, rax;\n"
        "adc r13, rdx;\n"
        "adc r14, 0x0;\n"
        "mov rax, [" $P1 "+ 0x18];\n"
        "mul QWORD PTR [" $P2 "+ 0x8];\n"
        "add r12, rax;\n"
        "adc r13, rdx;\n"
        "adc r14, 0x0;\n"
        "xor r15, r15;\n"
        "mov rax, [" $P1 "+ 0x10];\n"
        "mul QWORD PTR [" $P2 "+ 0x18];\n"
        "add r13, rax;\n"
        "adc r14, rdx;\n"
        "adc r15, r15;\n"
        "mov rax, [" $P1 "+ 0x18];\n"
        "mul QWORD PTR [" $P2 "+ 0x10];\n"
        "add r13, rax;\n"
        "adc r14, rdx;\n"
        "adc r15, 0x0;\n"
        "mov rax, [" $P1 "+ 0x18];\n"
        "mul QWORD PTR [" $P2 "+ 0x18];\n"
        "add r14, rax;\n"
        "adc r15, rdx;\n"
        "mov ebx, 0x26;\n"
        "mov rax, r12;\n"
        "mul rbx;\n"
        "add r8, rax;\n"
        "adc r9, rdx;\n"
        "sbb rcx, rcx;\n"
        "mov rax, r13;\n"
        "mul rbx;\n"
        "sub rdx, rcx;\n"
        "add r9, rax;\n"
        "adc r10, rdx;\n"
        "sbb rcx, rcx;\n"
        "mov rax, r14;\n"
        "mul rbx;\n"
        "sub rdx, rcx;\n"
        "add r10, rax;\n"
        "adc r11, rdx;\n"
        "sbb rcx, rcx;\n"
        "mov rax, r15;\n"
        "mul rbx;\n"
        "sub rdx, rcx;\n"
        "xor rcx, rcx;\n"
        "add r11, rax;\n"
        "mov r12, rdx;\n"
        "adc r12, rcx;\n"
        "shld r12, r11, 0x1;\n"
        "btr r11, 0x3f;\n"
        "mov edx, 0x13;\n"
        "imul rdx, r12;\n"
        "add r8, rdx;\n"
        "adc r9, rcx;\n"
        "adc r10, rcx;\n"
        "adc r11, rcx;\n"
        "mov [" $P0 "], r8;\n"
        "mov [" $P0 "+ 0x8], r9;\n"
        "mov [" $P0 "+ 0x10], r10;\n"
        "mov [" $P0 "+ 0x18], r11"
    )}
}

// Modular subtraction with double modulus 2 * p_25519 = 2^256 - 38

macro_rules! sub_twice4 {
    ($P0:expr, $P1:expr, $P2:expr) => { Q!(
        "mov r8, [" $P1 "];\n"
        "xor ebx, ebx;\n"
        "sub r8, [" $P2 "];\n"
        "mov r9, [" $P1 "+ 8];\n"
        "sbb r9, [" $P2 "+ 8];\n"
        "mov ecx, 38;\n"
        "mov r10, [" $P1 "+ 16];\n"
        "sbb r10, [" $P2 "+ 16];\n"
        "mov rax, [" $P1 "+ 24];\n"
        "sbb rax, [" $P2 "+ 24];\n"
        "cmovnc rcx, rbx;\n"
        "sub r8, rcx;\n"
        "sbb r9, rbx;\n"
        "sbb r10, rbx;\n"
        "sbb rax, rbx;\n"
        "mov [" $P0 "], r8;\n"
        "mov [" $P0 "+ 8], r9;\n"
        "mov [" $P0 "+ 16], r10;\n"
        "mov [" $P0 "+ 24], rax"
    )}
}

// Modular addition and doubling with double modulus 2 * p_25519 = 2^256 - 38.
// This only ensures that the result fits in 4 digits, not that it is reduced
// even w.r.t. double modulus. The result is always correct modulo provided
// the sum of the inputs is < 2^256 + 2^256 - 38, so in particular provided
// at least one of them is reduced double modulo.

macro_rules! add_twice4 {
    ($P0:expr, $P1:expr, $P2:expr) => { Q!(
        "mov r8, [" $P1 "];\n"
        "xor ecx, ecx;\n"
        "add r8, [" $P2 "];\n"
        "mov r9, [" $P1 "+ 0x8];\n"
        "adc r9, [" $P2 "+ 0x8];\n"
        "mov r10, [" $P1 "+ 0x10];\n"
        "adc r10, [" $P2 "+ 0x10];\n"
        "mov r11, [" $P1 "+ 0x18];\n"
        "adc r11, [" $P2 "+ 0x18];\n"
        "mov eax, 38;\n"
        "cmovnc rax, rcx;\n"
        "add r8, rax;\n"
        "adc r9, rcx;\n"
        "adc r10, rcx;\n"
        "adc r11, rcx;\n"
        "mov [" $P0 "], r8;\n"
        "mov [" $P0 "+ 0x8], r9;\n"
        "mov [" $P0 "+ 0x10], r10;\n"
        "mov [" $P0 "+ 0x18], r11"
    )}
}

macro_rules! double_twice4 {
    ($P0:expr, $P1:expr) => { Q!(
        "mov r8, [" $P1 "];\n"
        "xor ecx, ecx;\n"
        "add r8, r8;\n"
        "mov r9, [" $P1 "+ 0x8];\n"
        "adc r9, r9;\n"
        "mov r10, [" $P1 "+ 0x10];\n"
        "adc r10, r10;\n"
        "mov r11, [" $P1 "+ 0x18];\n"
        "adc r11, r11;\n"
        "mov eax, 38;\n"
        "cmovnc rax, rcx;\n"
        "add r8, rax;\n"
        "adc r9, rcx;\n"
        "adc r10, rcx;\n"
        "adc r11, rcx;\n"
        "mov [" $P0 "], r8;\n"
        "mov [" $P0 "+ 0x8], r9;\n"
        "mov [" $P0 "+ 0x10], r10;\n"
        "mov [" $P0 "+ 0x18], r11"
    )}
}

/// Scalar multiplication for the edwards25519 standard basepoint
///
/// Input scalar[4]; output res[8]
///
/// Given a scalar n, returns point (X,Y) = n * B where B = (...,4/5) is
/// the standard basepoint for the edwards25519 (Ed25519) curve.
#[inline(never)]
pub(crate) fn edwards25519_scalarmulbase_alt(res: &mut [u64; 8], scalar: &[u64; 4]) {
    // SAFETY: inline assembly. see [crate::low::inline_assembly_safety] for safety info.
    unsafe {
        core::arch::asm!(

        Q!("    endbr64         " ),

        // In this case the Windows form literally makes a subroutine call.
        // This avoids hassle arising from keeping code and data together.

        // Save registers, make room for temps, preserve input arguments.

        Q!("    push            " "rbx"),
        Q!("    push            " "rbp"),
        Q!("    push            " "r12"),
        Q!("    push            " "r13"),
        Q!("    push            " "r14"),
        Q!("    push            " "r15"),
        Q!("    sub             " "rsp, " NSPACE!()),

        // Move the output pointer to a stable place

        Q!("    mov             " res!() ", rdi"),

        // Copy the input scalar x to its local variable while reducing it
        // modulo 2^252 + m where m = 27742317777372353535851937790883648493;
        // this is the order of the basepoint so this doesn't change the result.
        // First do q = floor(x/2^252) and x' = x - q * (2^252 + m), which gives
        // an initial result -15 * m <= x' < 2^252

        Q!("    mov             " "r8, [rsi]"),
        Q!("    mov             " "r9, [rsi + 8]"),
        Q!("    mov             " "r10, [rsi + 16]"),
        Q!("    mov             " "r11, [rsi + 24]"),

        Q!("    mov             " "rcx, r11"),
        Q!("    shr             " "rcx, 60"),

        Q!("    mov             " "rax, 0x5812631a5cf5d3ed"),
        Q!("    mul             " "rcx"),
        Q!("    mov             " "r12, rax"),
        Q!("    mov             " "r13, rdx"),
        Q!("    mov             " "rax, 0x14def9dea2f79cd6"),
        Q!("    mul             " "rcx"),
        Q!("    add             " "r13, rax"),
        Q!("    adc             " "rdx, 0"),
        Q!("    shl             " "rcx, 60"),

        Q!("    sub             " "r8, r12"),
        Q!("    sbb             " "r9, r13"),
        Q!("    sbb             " "r10, rdx"),
        Q!("    sbb             " "r11, rcx"),

        // If x' < 0 then just directly negate it; this makes sure the
        // reduced argument is strictly 0 <= x' < 2^252, but now we need
        // to record (done via bit 255 of the reduced scalar, which is
        // ignored in the main loop) when we negated so we can flip
        // the end result to compensate.

        Q!("    sbb             " "rax, rax"),

        Q!("    xor             " "r8, rax"),
        Q!("    xor             " "r9, rax"),
        Q!("    xor             " "r10, rax"),
        Q!("    xor             " "r11, rax"),

        Q!("    neg             " "rax"),
        Q!("    adc             " "r8, 0"),
        Q!("    adc             " "r9, 0"),
        Q!("    adc             " "r10, 0"),
        Q!("    adc             " "r11, 0"),

        Q!("    shl             " "rax, 63"),
        Q!("    or              " "r11, rax"),

        // And before we store the scalar, test and reset bit 251 to
        // initialize the main loop just below.

        Q!("    mov             " "[rsp + " SCALAR!() "], r8"),
        Q!("    mov             " "[rsp + " SCALAR!() "+ 8], r9"),
        Q!("    mov             " "[rsp + " SCALAR!() "+ 16], r10"),
        Q!("    btr             " "r11, 59"),
        Q!("    mov             " "[rsp + " SCALAR!() "+ 24], r11"),

        // The main part of the computation is in extended-projective coordinates
        // (X,Y,Z,T), representing an affine point on the edwards25519 curve
        // (x,y) via x = X/Z, y = Y/Z and x * y = T/Z (so X * Y = T * Z).
        // In comments B means the standard basepoint (x,4/5) =
        // (0x216....f25d51a,0x6666..666658).
        //
        // Initialize accumulator "acc" to either 0 or 2^251 * B depending on
        // bit 251 of the (reduced) scalar. That leaves bits 0..250 to handle.

        Q!("    lea             " "r10, [rip + {edwards25519_scalarmulbase_alt_constant}]"),
        Q!("    lea             " "r11, [r10 + 8 * 12]"),

        Q!("    mov             " "rax, [r10]"),
        Q!("    mov             " "rcx, [r11]"),
        Q!("    cmovc           " "rax, rcx"),
        Q!("    mov             " "[rsp + " ACC!() "], rax"),

        Q!("    mov             " "rax, [r10 + 8 * 1]"),
        Q!("    mov             " "rcx, [r11 + 8 * 1]"),
        Q!("    cmovc           " "rax, rcx"),
        Q!("    mov             " "[rsp + " ACC!() "+ 8], rax"),

        Q!("    mov             " "rax, [r10 + 8 * 2]"),
        Q!("    mov             " "rcx, [r11 + 8 * 2]"),
        Q!("    cmovc           " "rax, rcx"),
        Q!("    mov             " "[rsp + " ACC!() "+ 16], rax"),

        Q!("    mov             " "rax, [r10 + 8 * 3]"),
        Q!("    mov             " "rcx, [r11 + 8 * 3]"),
        Q!("    cmovc           " "rax, rcx"),
        Q!("    mov             " "[rsp + " ACC!() "+ 24], rax"),

        Q!("    mov             " "rax, [r10 + 8 * 4]"),
        Q!("    mov             " "rcx, [r11 + 8 * 4]"),
        Q!("    cmovc           " "rax, rcx"),
        Q!("    mov             " "[rsp + " ACC!() "+ 32], rax"),

        Q!("    mov             " "rax, [r10 + 8 * 5]"),
        Q!("    mov             " "rcx, [r11 + 8 * 5]"),
        Q!("    cmovc           " "rax, rcx"),
        Q!("    mov             " "[rsp + " ACC!() "+ 40], rax"),

        Q!("    mov             " "rax, [r10 + 8 * 6]"),
        Q!("    mov             " "rcx, [r11 + 8 * 6]"),
        Q!("    cmovc           " "rax, rcx"),
        Q!("    mov             " "[rsp + " ACC!() "+ 48], rax"),

        Q!("    mov             " "rax, [r10 + 8 * 7]"),
        Q!("    mov             " "rcx, [r11 + 8 * 7]"),
        Q!("    cmovc           " "rax, rcx"),
        Q!("    mov             " "[rsp + " ACC!() "+ 56], rax"),

        Q!("    mov             " "eax, 1"),
        Q!("    mov             " "[rsp + " ACC!() "+ 64], rax"),
        Q!("    mov             " "eax, 0"),
        Q!("    mov             " "[rsp + " ACC!() "+ 72], rax"),
        Q!("    mov             " "[rsp + " ACC!() "+ 80], rax"),
        Q!("    mov             " "[rsp + " ACC!() "+ 88], rax"),

        Q!("    mov             " "rax, [r10 + 8 * 8]"),
        Q!("    mov             " "rcx, [r11 + 8 * 8]"),
        Q!("    cmovc           " "rax, rcx"),
        Q!("    mov             " "[rsp + " ACC!() "+ 96], rax"),

        Q!("    mov             " "rax, [r10 + 8 * 9]"),
        Q!("    mov             " "rcx, [r11 + 8 * 9]"),
        Q!("    cmovc           " "rax, rcx"),
        Q!("    mov             " "[rsp + " ACC!() "+ 104], rax"),

        Q!("    mov             " "rax, [r10 + 8 * 10]"),
        Q!("    mov             " "rcx, [r11 + 8 * 10]"),
        Q!("    cmovc           " "rax, rcx"),
        Q!("    mov             " "[rsp + " ACC!() "+ 112], rax"),

        Q!("    mov             " "rax, [r10 + 8 * 11]"),
        Q!("    mov             " "rcx, [r11 + 8 * 11]"),
        Q!("    cmovc           " "rax, rcx"),
        Q!("    mov             " "[rsp + " ACC!() "+ 120], rax"),

        // The counter "i" tracks the bit position for which the scalar has
        // already been absorbed, starting at 0 and going up in chunks of 4.
        //
        // The pointer "tab" points at the current block of the table for
        // multiples (2^i * j) * B at the current bit position i; 1 <= j <= 8.
        //
        // The bias is always either 0 and 1 and needs to be added to the
        // partially processed scalar implicitly. This is used to absorb 4 bits
        // of scalar per iteration from 3-bit table indexing by exploiting
        // negation: (16 * h + l) * B = (16 * (h + 1) - (16 - l)) * B is used
        // when l >= 9. Note that we can't have any bias left over at the
        // end because we made sure bit 251 is clear in the reduced scalar.

        Q!("    mov             " i!() ", 0"),
        Q!("    lea             " "rax, [r10 + 8 * 24]"),
        Q!("    mov             " tab!() ", rax"),
        Q!("    mov             " bias!() ", 0"),

        // Start of the main loop, repeated 63 times for i = 4, 8, ..., 252

        Q!(Label!("Ledwards25519_scalarmulbase_alt_scalarloop", 2) ":"),

        // Look at the next 4-bit field "bf", adding the previous bias as well.
        // Choose the table index "ix" as bf when bf <= 8 and 16 - bf for bf >= 9,
        // setting the bias to 1 for the next iteration in the latter case.

        Q!("    mov             " "rax, " i!()),
        Q!("    mov             " "rcx, rax"),
        Q!("    shr             " "rax, 6"),
        Q!("    mov             " "rax, [rsp + 8 * rax]"),
        Q!("    shr             " "rax, cl"),
        Q!("    and             " "rax, 15"),
        Q!("    add             " "rax, " bias!()),
        Q!("    mov             " bf!() ", rax"),

        Q!("    cmp             " bf!() ", 9"),
        Q!("    sbb             " "rax, rax"),
        Q!("    inc             " "rax"),
        Q!("    mov             " bias!() ", rax"),

        Q!("    mov             " "rdi, 16"),
        Q!("    sub             " "rdi, " bf!()),
        Q!("    cmp             " bias!() ", 0"),
        Q!("    cmovz           " "rdi, " bf!()),
        Q!("    mov             " ix!() ", rdi"),

        // Perform constant-time lookup in the table to get element number "ix".
        // The table entry for the affine point (x,y) is actually a triple
        // (y - x,x + y,2 * d * x * y) to precompute parts of the addition.
        // Note that "ix" can be 0, so we set up the appropriate identity first.

        Q!("    mov             " "eax, 1"),
        Q!("    xor             " "ebx, ebx"),
        Q!("    xor             " "ecx, ecx"),
        Q!("    xor             " "edx, edx"),
        Q!("    mov             " "r8d, 1"),
        Q!("    xor             " "r9d, r9d"),
        Q!("    xor             " "r10d, r10d"),
        Q!("    xor             " "r11d, r11d"),
        Q!("    xor             " "r12d, r12d"),
        Q!("    xor             " "r13d, r13d"),
        Q!("    xor             " "r14d, r14d"),
        Q!("    xor             " "r15d, r15d"),

        Q!("    mov             " "rbp, " tab!()),

        Q!("    cmp             " ix!() ", 1"),
        Q!("    mov             " "rsi, [rbp]"),
        Q!("    cmovz           " "rax, rsi"),
        Q!("    mov             " "rsi, [rbp + 8]"),
        Q!("    cmovz           " "rbx, rsi"),
        Q!("    mov             " "rsi, [rbp + 16]"),
        Q!("    cmovz           " "rcx, rsi"),
        Q!("    mov             " "rsi, [rbp + 24]"),
        Q!("    cmovz           " "rdx, rsi"),
        Q!("    mov             " "rsi, [rbp + 32]"),
        Q!("    cmovz           " "r8, rsi"),
        Q!("    mov             " "rsi, [rbp + 40]"),
        Q!("    cmovz           " "r9, rsi"),
        Q!("    mov             " "rsi, [rbp + 48]"),
        Q!("    cmovz           " "r10, rsi"),
        Q!("    mov             " "rsi, [rbp + 56]"),
        Q!("    cmovz           " "r11, rsi"),
        Q!("    mov             " "rsi, [rbp + 64]"),
        Q!("    cmovz           " "r12, rsi"),
        Q!("    mov             " "rsi, [rbp + 72]"),
        Q!("    cmovz           " "r13, rsi"),
        Q!("    mov             " "rsi, [rbp + 80]"),
        Q!("    cmovz           " "r14, rsi"),
        Q!("    mov             " "rsi, [rbp + 88]"),
        Q!("    cmovz           " "r15, rsi"),
        Q!("    add             " "rbp, 96"),

        Q!("    cmp             " ix!() ", 2"),
        Q!("    mov             " "rsi, [rbp]"),
        Q!("    cmovz           " "rax, rsi"),
        Q!("    mov             " "rsi, [rbp + 8]"),
        Q!("    cmovz           " "rbx, rsi"),
        Q!("    mov             " "rsi, [rbp + 16]"),
        Q!("    cmovz           " "rcx, rsi"),
        Q!("    mov             " "rsi, [rbp + 24]"),
        Q!("    cmovz           " "rdx, rsi"),
        Q!("    mov             " "rsi, [rbp + 32]"),
        Q!("    cmovz           " "r8, rsi"),
        Q!("    mov             " "rsi, [rbp + 40]"),
        Q!("    cmovz           " "r9, rsi"),
        Q!("    mov             " "rsi, [rbp + 48]"),
        Q!("    cmovz           " "r10, rsi"),
        Q!("    mov             " "rsi, [rbp + 56]"),
        Q!("    cmovz           " "r11, rsi"),
        Q!("    mov             " "rsi, [rbp + 64]"),
        Q!("    cmovz           " "r12, rsi"),
        Q!("    mov             " "rsi, [rbp + 72]"),
        Q!("    cmovz           " "r13, rsi"),
        Q!("    mov             " "rsi, [rbp + 80]"),
        Q!("    cmovz           " "r14, rsi"),
        Q!("    mov             " "rsi, [rbp + 88]"),
        Q!("    cmovz           " "r15, rsi"),
        Q!("    add             " "rbp, 96"),

        Q!("    cmp             " ix!() ", 3"),
        Q!("    mov             " "rsi, [rbp]"),
        Q!("    cmovz           " "rax, rsi"),
        Q!("    mov             " "rsi, [rbp + 8]"),
        Q!("    cmovz           " "rbx, rsi"),
        Q!("    mov             " "rsi, [rbp + 16]"),
        Q!("    cmovz           " "rcx, rsi"),
        Q!("    mov             " "rsi, [rbp + 24]"),
        Q!("    cmovz           " "rdx, rsi"),
        Q!("    mov             " "rsi, [rbp + 32]"),
        Q!("    cmovz           " "r8, rsi"),
        Q!("    mov             " "rsi, [rbp + 40]"),
        Q!("    cmovz           " "r9, rsi"),
        Q!("    mov             " "rsi, [rbp + 48]"),
        Q!("    cmovz           " "r10, rsi"),
        Q!("    mov             " "rsi, [rbp + 56]"),
        Q!("    cmovz           " "r11, rsi"),
        Q!("    mov             " "rsi, [rbp + 64]"),
        Q!("    cmovz           " "r12, rsi"),
        Q!("    mov             " "rsi, [rbp + 72]"),
        Q!("    cmovz           " "r13, rsi"),
        Q!("    mov             " "rsi, [rbp + 80]"),
        Q!("    cmovz           " "r14, rsi"),
        Q!("    mov             " "rsi, [rbp + 88]"),
        Q!("    cmovz           " "r15, rsi"),
        Q!("    add             " "rbp, 96"),

        Q!("    cmp             " ix!() ", 4"),
        Q!("    mov             " "rsi, [rbp]"),
        Q!("    cmovz           " "rax, rsi"),
        Q!("    mov             " "rsi, [rbp + 8]"),
        Q!("    cmovz           " "rbx, rsi"),
        Q!("    mov             " "rsi, [rbp + 16]"),
        Q!("    cmovz           " "rcx, rsi"),
        Q!("    mov             " "rsi, [rbp + 24]"),
        Q!("    cmovz           " "rdx, rsi"),
        Q!("    mov             " "rsi, [rbp + 32]"),
        Q!("    cmovz           " "r8, rsi"),
        Q!("    mov             " "rsi, [rbp + 40]"),
        Q!("    cmovz           " "r9, rsi"),
        Q!("    mov             " "rsi, [rbp + 48]"),
        Q!("    cmovz           " "r10, rsi"),
        Q!("    mov             " "rsi, [rbp + 56]"),
        Q!("    cmovz           " "r11, rsi"),
        Q!("    mov             " "rsi, [rbp + 64]"),
        Q!("    cmovz           " "r12, rsi"),
        Q!("    mov             " "rsi, [rbp + 72]"),
        Q!("    cmovz           " "r13, rsi"),
        Q!("    mov             " "rsi, [rbp + 80]"),
        Q!("    cmovz           " "r14, rsi"),
        Q!("    mov             " "rsi, [rbp + 88]"),
        Q!("    cmovz           " "r15, rsi"),
        Q!("    add             " "rbp, 96"),

        Q!("    cmp             " ix!() ", 5"),
        Q!("    mov             " "rsi, [rbp]"),
        Q!("    cmovz           " "rax, rsi"),
        Q!("    mov             " "rsi, [rbp + 8]"),
        Q!("    cmovz           " "rbx, rsi"),
        Q!("    mov             " "rsi, [rbp + 16]"),
        Q!("    cmovz           " "rcx, rsi"),
        Q!("    mov             " "rsi, [rbp + 24]"),
        Q!("    cmovz           " "rdx, rsi"),
        Q!("    mov             " "rsi, [rbp + 32]"),
        Q!("    cmovz           " "r8, rsi"),
        Q!("    mov             " "rsi, [rbp + 40]"),
        Q!("    cmovz           " "r9, rsi"),
        Q!("    mov             " "rsi, [rbp + 48]"),
        Q!("    cmovz           " "r10, rsi"),
        Q!("    mov             " "rsi, [rbp + 56]"),
        Q!("    cmovz           " "r11, rsi"),
        Q!("    mov             " "rsi, [rbp + 64]"),
        Q!("    cmovz           " "r12, rsi"),
        Q!("    mov             " "rsi, [rbp + 72]"),
        Q!("    cmovz           " "r13, rsi"),
        Q!("    mov             " "rsi, [rbp + 80]"),
        Q!("    cmovz           " "r14, rsi"),
        Q!("    mov             " "rsi, [rbp + 88]"),
        Q!("    cmovz           " "r15, rsi"),
        Q!("    add             " "rbp, 96"),

        Q!("    cmp             " ix!() ", 6"),
        Q!("    mov             " "rsi, [rbp]"),
        Q!("    cmovz           " "rax, rsi"),
        Q!("    mov             " "rsi, [rbp + 8]"),
        Q!("    cmovz           " "rbx, rsi"),
        Q!("    mov             " "rsi, [rbp + 16]"),
        Q!("    cmovz           " "rcx, rsi"),
        Q!("    mov             " "rsi, [rbp + 24]"),
        Q!("    cmovz           " "rdx, rsi"),
        Q!("    mov             " "rsi, [rbp + 32]"),
        Q!("    cmovz           " "r8, rsi"),
        Q!("    mov             " "rsi, [rbp + 40]"),
        Q!("    cmovz           " "r9, rsi"),
        Q!("    mov             " "rsi, [rbp + 48]"),
        Q!("    cmovz           " "r10, rsi"),
        Q!("    mov             " "rsi, [rbp + 56]"),
        Q!("    cmovz           " "r11, rsi"),
        Q!("    mov             " "rsi, [rbp + 64]"),
        Q!("    cmovz           " "r12, rsi"),
        Q!("    mov             " "rsi, [rbp + 72]"),
        Q!("    cmovz           " "r13, rsi"),
        Q!("    mov             " "rsi, [rbp + 80]"),
        Q!("    cmovz           " "r14, rsi"),
        Q!("    mov             " "rsi, [rbp + 88]"),
        Q!("    cmovz           " "r15, rsi"),
        Q!("    add             " "rbp, 96"),

        Q!("    cmp             " ix!() ", 7"),
        Q!("    mov             " "rsi, [rbp]"),
        Q!("    cmovz           " "rax, rsi"),
        Q!("    mov             " "rsi, [rbp + 8]"),
        Q!("    cmovz           " "rbx, rsi"),
        Q!("    mov             " "rsi, [rbp + 16]"),
        Q!("    cmovz           " "rcx, rsi"),
        Q!("    mov             " "rsi, [rbp + 24]"),
        Q!("    cmovz           " "rdx, rsi"),
        Q!("    mov             " "rsi, [rbp + 32]"),
        Q!("    cmovz           " "r8, rsi"),
        Q!("    mov             " "rsi, [rbp + 40]"),
        Q!("    cmovz           " "r9, rsi"),
        Q!("    mov             " "rsi, [rbp + 48]"),
        Q!("    cmovz           " "r10, rsi"),
        Q!("    mov             " "rsi, [rbp + 56]"),
        Q!("    cmovz           " "r11, rsi"),
        Q!("    mov             " "rsi, [rbp + 64]"),
        Q!("    cmovz           " "r12, rsi"),
        Q!("    mov             " "rsi, [rbp + 72]"),
        Q!("    cmovz           " "r13, rsi"),
        Q!("    mov             " "rsi, [rbp + 80]"),
        Q!("    cmovz           " "r14, rsi"),
        Q!("    mov             " "rsi, [rbp + 88]"),
        Q!("    cmovz           " "r15, rsi"),
        Q!("    add             " "rbp, 96"),

        Q!("    cmp             " ix!() ", 8"),
        Q!("    mov             " "rsi, [rbp]"),
        Q!("    cmovz           " "rax, rsi"),
        Q!("    mov             " "rsi, [rbp + 8]"),
        Q!("    cmovz           " "rbx, rsi"),
        Q!("    mov             " "rsi, [rbp + 16]"),
        Q!("    cmovz           " "rcx, rsi"),
        Q!("    mov             " "rsi, [rbp + 24]"),
        Q!("    cmovz           " "rdx, rsi"),
        Q!("    mov             " "rsi, [rbp + 32]"),
        Q!("    cmovz           " "r8, rsi"),
        Q!("    mov             " "rsi, [rbp + 40]"),
        Q!("    cmovz           " "r9, rsi"),
        Q!("    mov             " "rsi, [rbp + 48]"),
        Q!("    cmovz           " "r10, rsi"),
        Q!("    mov             " "rsi, [rbp + 56]"),
        Q!("    cmovz           " "r11, rsi"),
        Q!("    mov             " "rsi, [rbp + 64]"),
        Q!("    cmovz           " "r12, rsi"),
        Q!("    mov             " "rsi, [rbp + 72]"),
        Q!("    cmovz           " "r13, rsi"),
        Q!("    mov             " "rsi, [rbp + 80]"),
        Q!("    cmovz           " "r14, rsi"),
        Q!("    mov             " "rsi, [rbp + 88]"),
        Q!("    cmovz           " "r15, rsi"),

        Q!("    add             " "rbp, 96"),
        Q!("    mov             " tab!() ", rbp"),

        // We now have the triple from the table in registers as follows
        //
        //      [rdx;rcx;rbx;rax] = y - x
        //      [r11;r10;r9;r8] = x + y
        //      [r15;r14;r13;r12] = 2 * d * x * y
        //
        // In case bias = 1 we need to negate this. For Edwards curves
        // -(x,y) = (-x,y), i.e. we need to negate the x coordinate.
        // In this processed encoding, that amounts to swapping the
        // first two fields and negating the third.
        //
        // The optional negation here also pretends bias = 0 whenever
        // ix = 0 so that it doesn't need to handle the case of zero
        // inputs, since no non-trivial table entries are zero. Note
        // that in the zero case the whole negation is trivial, and
        // so indeed is the swapping.

        Q!("    cmp             " bias!() ", 0"),

        Q!("    mov             " "rsi, rax"),
        Q!("    cmovnz          " "rsi, r8"),
        Q!("    cmovnz          " "r8, rax"),
        Q!("    mov             " "[rsp + " TABENT!() "], rsi"),
        Q!("    mov             " "[rsp + " TABENT!() "+ 32], r8"),

        Q!("    mov             " "rsi, rbx"),
        Q!("    cmovnz          " "rsi, r9"),
        Q!("    cmovnz          " "r9, rbx"),
        Q!("    mov             " "[rsp + " TABENT!() "+ 8], rsi"),
        Q!("    mov             " "[rsp + " TABENT!() "+ 40], r9"),

        Q!("    mov             " "rsi, rcx"),
        Q!("    cmovnz          " "rsi, r10"),
        Q!("    cmovnz          " "r10, rcx"),
        Q!("    mov             " "[rsp + " TABENT!() "+ 16], rsi"),
        Q!("    mov             " "[rsp + " TABENT!() "+ 48], r10"),

        Q!("    mov             " "rsi, rdx"),
        Q!("    cmovnz          " "rsi, r11"),
        Q!("    cmovnz          " "r11, rdx"),
        Q!("    mov             " "[rsp + " TABENT!() "+ 24], rsi"),
        Q!("    mov             " "[rsp + " TABENT!() "+ 56], r11"),

        Q!("    mov             " "rax, -19"),
        Q!("    mov             " "rbx, -1"),
        Q!("    mov             " "rcx, -1"),
        Q!("    mov             " "rdx, 0x7fffffffffffffff"),
        Q!("    sub             " "rax, r12"),
        Q!("    sbb             " "rbx, r13"),
        Q!("    sbb             " "rcx, r14"),
        Q!("    sbb             " "rdx, r15"),

        Q!("    mov             " "r8, " ix!()),
        Q!("    mov             " "r9, " bias!()),
        Q!("    test            " "r8, r8"),
        Q!("    cmovz           " "r9, r8"),
        Q!("    test            " "r9, r9"),

        Q!("    cmovz           " "rax, r12"),
        Q!("    cmovz           " "rbx, r13"),
        Q!("    cmovz           " "rcx, r14"),
        Q!("    cmovz           " "rdx, r15"),
        Q!("    mov             " "[rsp + " TABENT!() "+ 64], rax"),
        Q!("    mov             " "[rsp + " TABENT!() "+ 72], rbx"),
        Q!("    mov             " "[rsp + " TABENT!() "+ 80], rcx"),
        Q!("    mov             " "[rsp + " TABENT!() "+ 88], rdx"),

        // Extended-projective and precomputed mixed addition.
        // This is effectively the same as calling the standalone
        // function edwards25519_pepadd(acc,acc,tabent), but we
        // only retain slightly weaker normalization < 2 * p_25519
        // throughout the inner loop, so the computation is
        // slightly different, and faster overall.

        double_twice4!(t0!(), z_1!()),
        sub_twice4!(t1!(), y_1!(), x_1!()),
        add_twice4!(t2!(), y_1!(), x_1!()),
        mul_4!(t3!(), w_1!(), kxy_2!()),
        mul_4!(t1!(), t1!(), ymx_2!()),
        mul_4!(t2!(), t2!(), xpy_2!()),
        sub_twice4!(t4!(), t0!(), t3!()),
        add_twice4!(t0!(), t0!(), t3!()),
        sub_twice4!(t5!(), t2!(), t1!()),
        add_twice4!(t1!(), t2!(), t1!()),
        mul_4!(z_3!(), t4!(), t0!()),
        mul_4!(x_3!(), t5!(), t4!()),
        mul_4!(y_3!(), t0!(), t1!()),
        mul_4!(w_3!(), t5!(), t1!()),

        // End of the main loop; move on by 4 bits.

        Q!("    add             " i!() ", 4"),
        Q!("    cmp             " i!() ", 252"),
        Q!("    jc              " Label!("Ledwards25519_scalarmulbase_alt_scalarloop", 2, Before)),

        // Insert the optional negation of the projective X coordinate, and
        // so by extension the final affine x coordinate x = X/Z and thus
        // the point P = (x,y). We only know X < 2 * p_25519, so we do the
        // negation as 2 * p_25519 - X to keep it nonnegative. From this
        // point on we don't need any normalization of the coordinates
        // except for making sure that they fit in 4 digits.

        Q!("    mov             " "r8, [rsp + " X3!() "]"),
        Q!("    mov             " "r9, [rsp + " X3!() "+ 8]"),
        Q!("    mov             " "r10, [rsp + " X3!() "+ 16]"),
        Q!("    mov             " "r11, [rsp + " X3!() "+ 24]"),
        Q!("    mov             " "r12, 0xffffffffffffffda"),
        Q!("    sub             " "r12, r8"),
        Q!("    mov             " "r13, 0xffffffffffffffff"),
        Q!("    sbb             " "r13, r9"),
        Q!("    mov             " "r14, 0xffffffffffffffff"),
        Q!("    sbb             " "r14, r10"),
        Q!("    mov             " "r15, 0xffffffffffffffff"),
        Q!("    sbb             " "r15, r11"),
        Q!("    mov             " "rax, [rsp + " SCALAR!() "+ 24]"),
        Q!("    bt              " "rax, 63"),
        Q!("    cmovc           " "r8, r12"),
        Q!("    cmovc           " "r9, r13"),
        Q!("    cmovc           " "r10, r14"),
        Q!("    cmovc           " "r11, r15"),
        Q!("    mov             " "[rsp + " X3!() "], r8"),
        Q!("    mov             " "[rsp + " X3!() "+ 8], r9"),
        Q!("    mov             " "[rsp + " X3!() "+ 16], r10"),
        Q!("    mov             " "[rsp + " X3!() "+ 24], r11"),

        // Now we need to map out of the extended-projective representation
        // (X,Y,Z,W) back to the affine form (x,y) = (X/Z,Y/Z). This means
        // first calling the modular inverse to get w_3 = 1/z_3.

        Q!("    lea             " "rdi, [rsp + " W3!() "]"),
        Q!("    lea             " "rsi, [rsp + " Z3!() "]"),

        // Inline copy of bignum_inv_p25519, identical except for stripping out
        // the prologue and epilogue saving and restoring registers and making
        // and reclaiming room on the stack. For more details and explanations see
        // "x86/curve25519/bignum_inv_p25519.S". Note that the stack it uses for
        // its own temporaries is 208 bytes, so it has no effect on variables
        // that are needed in the rest of our computation here: res, x_3, y_3,
        // z_3 and w_3.

        Q!("    mov             " "[rsp + 0xc0], rdi"),
        Q!("    xor             " "eax, eax"),
        Q!("    lea             " "rcx, [rax -0x13]"),
        Q!("    not             " "rax"),
        Q!("    mov             " "[rsp], rcx"),
        Q!("    mov             " "[rsp + 0x8], rax"),
        Q!("    mov             " "[rsp + 0x10], rax"),
        Q!("    btr             " "rax, 0x3f"),
        Q!("    mov             " "[rsp + 0x18], rax"),
        Q!("    mov             " "rdx, [rsi]"),
        Q!("    mov             " "rcx, [rsi + 0x8]"),
        Q!("    mov             " "r8, [rsi + 0x10]"),
        Q!("    mov             " "r9, [rsi + 0x18]"),
        Q!("    mov             " "eax, 0x1"),
        Q!("    xor             " "r10d, r10d"),
        Q!("    bts             " "r9, 0x3f"),
        Q!("    adc             " "rax, r10"),
        Q!("    imul            " "rax, rax, 0x13"),
        Q!("    add             " "rdx, rax"),
        Q!("    adc             " "rcx, r10"),
        Q!("    adc             " "r8, r10"),
        Q!("    adc             " "r9, r10"),
        Q!("    mov             " "eax, 0x13"),
        Q!("    cmovb           " "rax, r10"),
        Q!("    sub             " "rdx, rax"),
        Q!("    sbb             " "rcx, r10"),
        Q!("    sbb             " "r8, r10"),
        Q!("    sbb             " "r9, r10"),
        Q!("    btr             " "r9, 0x3f"),
        Q!("    mov             " "[rsp + 0x20], rdx"),
        Q!("    mov             " "[rsp + 0x28], rcx"),
        Q!("    mov             " "[rsp + 0x30], r8"),
        Q!("    mov             " "[rsp + 0x38], r9"),
        Q!("    xor             " "eax, eax"),
        Q!("    mov             " "[rsp + 0x40], rax"),
        Q!("    mov             " "[rsp + 0x48], rax"),
        Q!("    mov             " "[rsp + 0x50], rax"),
        Q!("    mov             " "[rsp + 0x58], rax"),
        Q!("    movabs          " "rax, 0xa0f99e2375022099"),
        Q!("    mov             " "[rsp + 0x60], rax"),
        Q!("    movabs          " "rax, 0xa8c68f3f1d132595"),
        Q!("    mov             " "[rsp + 0x68], rax"),
        Q!("    movabs          " "rax, 0x6c6c893805ac5242"),
        Q!("    mov             " "[rsp + 0x70], rax"),
        Q!("    movabs          " "rax, 0x276508b241770615"),
        Q!("    mov             " "[rsp + 0x78], rax"),
        Q!("    mov             " "QWORD PTR [rsp + 0x90], 0xa"),
        Q!("    mov             " "QWORD PTR [rsp + 0x98], 0x1"),
        Q!("    jmp             " Label!("Ledwards25519_scalarmulbase_alt_midloop", 3, After)),
        Q!(Label!("Ledwards25519_scalarmulbase_alt_inverseloop", 4) ":"),
        Q!("    mov             " "r9, r8"),
        Q!("    sar             " "r9, 0x3f"),
        Q!("    xor             " "r8, r9"),
        Q!("    sub             " "r8, r9"),
        Q!("    mov             " "r11, r10"),
        Q!("    sar             " "r11, 0x3f"),
        Q!("    xor             " "r10, r11"),
        Q!("    sub             " "r10, r11"),
        Q!("    mov             " "r13, r12"),
        Q!("    sar             " "r13, 0x3f"),
        Q!("    xor             " "r12, r13"),
        Q!("    sub             " "r12, r13"),
        Q!("    mov             " "r15, r14"),
        Q!("    sar             " "r15, 0x3f"),
        Q!("    xor             " "r14, r15"),
        Q!("    sub             " "r14, r15"),
        Q!("    mov             " "rax, r8"),
        Q!("    and             " "rax, r9"),
        Q!("    mov             " "rdi, r10"),
        Q!("    and             " "rdi, r11"),
        Q!("    add             " "rdi, rax"),
        Q!("    mov             " "[rsp + 0x80], rdi"),
        Q!("    mov             " "rax, r12"),
        Q!("    and             " "rax, r13"),
        Q!("    mov             " "rsi, r14"),
        Q!("    and             " "rsi, r15"),
        Q!("    add             " "rsi, rax"),
        Q!("    mov             " "[rsp + 0x88], rsi"),
        Q!("    xor             " "ebx, ebx"),
        Q!("    mov             " "rax, [rsp]"),
        Q!("    xor             " "rax, r9"),
        Q!("    mul             " "r8"),
        Q!("    add             " "rdi, rax"),
        Q!("    adc             " "rbx, rdx"),
        Q!("    mov             " "rax, [rsp + 0x20]"),
        Q!("    xor             " "rax, r11"),
        Q!("    mul             " "r10"),
        Q!("    add             " "rdi, rax"),
        Q!("    adc             " "rbx, rdx"),
        Q!("    xor             " "ebp, ebp"),
        Q!("    mov             " "rax, [rsp]"),
        Q!("    xor             " "rax, r13"),
        Q!("    mul             " "r12"),
        Q!("    add             " "rsi, rax"),
        Q!("    adc             " "rbp, rdx"),
        Q!("    mov             " "rax, [rsp + 0x20]"),
        Q!("    xor             " "rax, r15"),
        Q!("    mul             " "r14"),
        Q!("    add             " "rsi, rax"),
        Q!("    adc             " "rbp, rdx"),
        Q!("    xor             " "ecx, ecx"),
        Q!("    mov             " "rax, [rsp + 0x8]"),
        Q!("    xor             " "rax, r9"),
        Q!("    mul             " "r8"),
        Q!("    add             " "rbx, rax"),
        Q!("    adc             " "rcx, rdx"),
        Q!("    mov             " "rax, [rsp + 0x28]"),
        Q!("    xor             " "rax, r11"),
        Q!("    mul             " "r10"),
        Q!("    add             " "rbx, rax"),
        Q!("    adc             " "rcx, rdx"),
        Q!("    shrd            " "rdi, rbx, 0x3b"),
        Q!("    mov             " "[rsp], rdi"),
        Q!("    xor             " "edi, edi"),
        Q!("    mov             " "rax, [rsp + 0x8]"),
        Q!("    xor             " "rax, r13"),
        Q!("    mul             " "r12"),
        Q!("    add             " "rbp, rax"),
        Q!("    adc             " "rdi, rdx"),
        Q!("    mov             " "rax, [rsp + 0x28]"),
        Q!("    xor             " "rax, r15"),
        Q!("    mul             " "r14"),
        Q!("    add             " "rbp, rax"),
        Q!("    adc             " "rdi, rdx"),
        Q!("    shrd            " "rsi, rbp, 0x3b"),
        Q!("    mov             " "[rsp + 0x20], rsi"),
        Q!("    xor             " "esi, esi"),
        Q!("    mov             " "rax, [rsp + 0x10]"),
        Q!("    xor             " "rax, r9"),
        Q!("    mul             " "r8"),
        Q!("    add             " "rcx, rax"),
        Q!("    adc             " "rsi, rdx"),
        Q!("    mov             " "rax, [rsp + 0x30]"),
        Q!("    xor             " "rax, r11"),
        Q!("    mul             " "r10"),
        Q!("    add             " "rcx, rax"),
        Q!("    adc             " "rsi, rdx"),
        Q!("    shrd            " "rbx, rcx, 0x3b"),
        Q!("    mov             " "[rsp + 0x8], rbx"),
        Q!("    xor             " "ebx, ebx"),
        Q!("    mov             " "rax, [rsp + 0x10]"),
        Q!("    xor             " "rax, r13"),
        Q!("    mul             " "r12"),
        Q!("    add             " "rdi, rax"),
        Q!("    adc             " "rbx, rdx"),
        Q!("    mov             " "rax, [rsp + 0x30]"),
        Q!("    xor             " "rax, r15"),
        Q!("    mul             " "r14"),
        Q!("    add             " "rdi, rax"),
        Q!("    adc             " "rbx, rdx"),
        Q!("    shrd            " "rbp, rdi, 0x3b"),
        Q!("    mov             " "[rsp + 0x28], rbp"),
        Q!("    mov             " "rax, [rsp + 0x18]"),
        Q!("    xor             " "rax, r9"),
        Q!("    mov             " "rbp, rax"),
        Q!("    sar             " "rbp, 0x3f"),
        Q!("    and             " "rbp, r8"),
        Q!("    neg             " "rbp"),
        Q!("    mul             " "r8"),
        Q!("    add             " "rsi, rax"),
        Q!("    adc             " "rbp, rdx"),
        Q!("    mov             " "rax, [rsp + 0x38]"),
        Q!("    xor             " "rax, r11"),
        Q!("    mov             " "rdx, rax"),
        Q!("    sar             " "rdx, 0x3f"),
        Q!("    and             " "rdx, r10"),
        Q!("    sub             " "rbp, rdx"),
        Q!("    mul             " "r10"),
        Q!("    add             " "rsi, rax"),
        Q!("    adc             " "rbp, rdx"),
        Q!("    shrd            " "rcx, rsi, 0x3b"),
        Q!("    mov             " "[rsp + 0x10], rcx"),
        Q!("    shrd            " "rsi, rbp, 0x3b"),
        Q!("    mov             " "rax, [rsp + 0x18]"),
        Q!("    mov             " "[rsp + 0x18], rsi"),
        Q!("    xor             " "rax, r13"),
        Q!("    mov             " "rsi, rax"),
        Q!("    sar             " "rsi, 0x3f"),
        Q!("    and             " "rsi, r12"),
        Q!("    neg             " "rsi"),
        Q!("    mul             " "r12"),
        Q!("    add             " "rbx, rax"),
        Q!("    adc             " "rsi, rdx"),
        Q!("    mov             " "rax, [rsp + 0x38]"),
        Q!("    xor             " "rax, r15"),
        Q!("    mov             " "rdx, rax"),
        Q!("    sar             " "rdx, 0x3f"),
        Q!("    and             " "rdx, r14"),
        Q!("    sub             " "rsi, rdx"),
        Q!("    mul             " "r14"),
        Q!("    add             " "rbx, rax"),
        Q!("    adc             " "rsi, rdx"),
        Q!("    shrd            " "rdi, rbx, 0x3b"),
        Q!("    mov             " "[rsp + 0x30], rdi"),
        Q!("    shrd            " "rbx, rsi, 0x3b"),
        Q!("    mov             " "[rsp + 0x38], rbx"),
        Q!("    mov             " "rbx, [rsp + 0x80]"),
        Q!("    mov             " "rbp, [rsp + 0x88]"),
        Q!("    xor             " "ecx, ecx"),
        Q!("    mov             " "rax, [rsp + 0x40]"),
        Q!("    xor             " "rax, r9"),
        Q!("    mul             " "r8"),
        Q!("    add             " "rbx, rax"),
        Q!("    adc             " "rcx, rdx"),
        Q!("    mov             " "rax, [rsp + 0x60]"),
        Q!("    xor             " "rax, r11"),
        Q!("    mul             " "r10"),
        Q!("    add             " "rbx, rax"),
        Q!("    adc             " "rcx, rdx"),
        Q!("    xor             " "esi, esi"),
        Q!("    mov             " "rax, [rsp + 0x40]"),
        Q!("    xor             " "rax, r13"),
        Q!("    mul             " "r12"),
        Q!("    mov             " "[rsp + 0x40], rbx"),
        Q!("    add             " "rbp, rax"),
        Q!("    adc             " "rsi, rdx"),
        Q!("    mov             " "rax, [rsp + 0x60]"),
        Q!("    xor             " "rax, r15"),
        Q!("    mul             " "r14"),
        Q!("    add             " "rbp, rax"),
        Q!("    adc             " "rsi, rdx"),
        Q!("    mov             " "[rsp + 0x60], rbp"),
        Q!("    xor             " "ebx, ebx"),
        Q!("    mov             " "rax, [rsp + 0x48]"),
        Q!("    xor             " "rax, r9"),
        Q!("    mul             " "r8"),
        Q!("    add             " "rcx, rax"),
        Q!("    adc             " "rbx, rdx"),
        Q!("    mov             " "rax, [rsp + 0x68]"),
        Q!("    xor             " "rax, r11"),
        Q!("    mul             " "r10"),
        Q!("    add             " "rcx, rax"),
        Q!("    adc             " "rbx, rdx"),
        Q!("    xor             " "ebp, ebp"),
        Q!("    mov             " "rax, [rsp + 0x48]"),
        Q!("    xor             " "rax, r13"),
        Q!("    mul             " "r12"),
        Q!("    mov             " "[rsp + 0x48], rcx"),
        Q!("    add             " "rsi, rax"),
        Q!("    adc             " "rbp, rdx"),
        Q!("    mov             " "rax, [rsp + 0x68]"),
        Q!("    xor             " "rax, r15"),
        Q!("    mul             " "r14"),
        Q!("    add             " "rsi, rax"),
        Q!("    adc             " "rbp, rdx"),
        Q!("    mov             " "[rsp + 0x68], rsi"),
        Q!("    xor             " "ecx, ecx"),
        Q!("    mov             " "rax, [rsp + 0x50]"),
        Q!("    xor             " "rax, r9"),
        Q!("    mul             " "r8"),
        Q!("    add             " "rbx, rax"),
        Q!("    adc             " "rcx, rdx"),
        Q!("    mov             " "rax, [rsp + 0x70]"),
        Q!("    xor             " "rax, r11"),
        Q!("    mul             " "r10"),
        Q!("    add             " "rbx, rax"),
        Q!("    adc             " "rcx, rdx"),
        Q!("    xor             " "esi, esi"),
        Q!("    mov             " "rax, [rsp + 0x50]"),
        Q!("    xor             " "rax, r13"),
        Q!("    mul             " "r12"),
        Q!("    mov             " "[rsp + 0x50], rbx"),
        Q!("    add             " "rbp, rax"),
        Q!("    adc             " "rsi, rdx"),
        Q!("    mov             " "rax, [rsp + 0x70]"),
        Q!("    xor             " "rax, r15"),
        Q!("    mul             " "r14"),
        Q!("    add             " "rbp, rax"),
        Q!("    adc             " "rsi, rdx"),
        Q!("    mov             " "[rsp + 0x70], rbp"),
        Q!("    mov             " "rax, [rsp + 0x58]"),
        Q!("    xor             " "rax, r9"),
        Q!("    mov             " "rbx, r9"),
        Q!("    and             " "rbx, r8"),
        Q!("    neg             " "rbx"),
        Q!("    mul             " "r8"),
        Q!("    add             " "rcx, rax"),
        Q!("    adc             " "rbx, rdx"),
        Q!("    mov             " "rax, [rsp + 0x78]"),
        Q!("    xor             " "rax, r11"),
        Q!("    mov             " "rdx, r11"),
        Q!("    and             " "rdx, r10"),
        Q!("    sub             " "rbx, rdx"),
        Q!("    mul             " "r10"),
        Q!("    add             " "rcx, rax"),
        Q!("    adc             " "rdx, rbx"),
        Q!("    mov             " "rbx, rdx"),
        Q!("    shld            " "rdx, rcx, 0x1"),
        Q!("    sar             " "rbx, 0x3f"),
        Q!("    add             " "rdx, rbx"),
        Q!("    mov             " "eax, 0x13"),
        Q!("    imul            " "rdx"),
        Q!("    mov             " "r8, [rsp + 0x40]"),
        Q!("    add             " "r8, rax"),
        Q!("    mov             " "[rsp + 0x40], r8"),
        Q!("    mov             " "r8, [rsp + 0x48]"),
        Q!("    adc             " "r8, rdx"),
        Q!("    mov             " "[rsp + 0x48], r8"),
        Q!("    mov             " "r8, [rsp + 0x50]"),
        Q!("    adc             " "r8, rbx"),
        Q!("    mov             " "[rsp + 0x50], r8"),
        Q!("    adc             " "rcx, rbx"),
        Q!("    shl             " "rax, 0x3f"),
        Q!("    add             " "rcx, rax"),
        Q!("    mov             " "rax, [rsp + 0x58]"),
        Q!("    mov             " "[rsp + 0x58], rcx"),
        Q!("    xor             " "rax, r13"),
        Q!("    mov             " "rcx, r13"),
        Q!("    and             " "rcx, r12"),
        Q!("    neg             " "rcx"),
        Q!("    mul             " "r12"),
        Q!("    add             " "rsi, rax"),
        Q!("    adc             " "rcx, rdx"),
        Q!("    mov             " "rax, [rsp + 0x78]"),
        Q!("    xor             " "rax, r15"),
        Q!("    mov             " "rdx, r15"),
        Q!("    and             " "rdx, r14"),
        Q!("    sub             " "rcx, rdx"),
        Q!("    mul             " "r14"),
        Q!("    add             " "rsi, rax"),
        Q!("    adc             " "rdx, rcx"),
        Q!("    mov             " "rcx, rdx"),
        Q!("    shld            " "rdx, rsi, 0x1"),
        Q!("    sar             " "rcx, 0x3f"),
        Q!("    mov             " "eax, 0x13"),
        Q!("    add             " "rdx, rcx"),
        Q!("    imul            " "rdx"),
        Q!("    mov             " "r8, [rsp + 0x60]"),
        Q!("    add             " "r8, rax"),
        Q!("    mov             " "[rsp + 0x60], r8"),
        Q!("    mov             " "r8, [rsp + 0x68]"),
        Q!("    adc             " "r8, rdx"),
        Q!("    mov             " "[rsp + 0x68], r8"),
        Q!("    mov             " "r8, [rsp + 0x70]"),
        Q!("    adc             " "r8, rcx"),
        Q!("    mov             " "[rsp + 0x70], r8"),
        Q!("    adc             " "rsi, rcx"),
        Q!("    shl             " "rax, 0x3f"),
        Q!("    add             " "rsi, rax"),
        Q!("    mov             " "[rsp + 0x78], rsi"),
        Q!(Label!("Ledwards25519_scalarmulbase_alt_midloop", 3) ":"),
        Q!("    mov             " "rsi, [rsp + 0x98]"),
        Q!("    mov             " "rdx, [rsp]"),
        Q!("    mov             " "rcx, [rsp + 0x20]"),
        Q!("    mov             " "rbx, rdx"),
        Q!("    and             " "rbx, 0xfffff"),
        Q!("    movabs          " "rax, 0xfffffe0000000000"),
        Q!("    or              " "rbx, rax"),
        Q!("    and             " "rcx, 0xfffff"),
        Q!("    movabs          " "rax, 0xc000000000000000"),
        Q!("    or              " "rcx, rax"),
        Q!("    mov             " "rax, 0xfffffffffffffffe"),
        Q!("    xor             " "ebp, ebp"),
        Q!("    mov             " "edx, 0x2"),
        Q!("    mov             " "rdi, rbx"),
        Q!("    mov             " "r8, rax"),
        Q!("    test            " "rsi, rsi"),
        Q!("    cmovs           " "r8, rbp"),
        Q!("    test            " "rcx, 0x1"),
        Q!("    cmove           " "r8, rbp"),
        Q!("    cmove           " "rdi, rbp"),
        Q!("    xor             " "rdi, r8"),
        Q!("    xor             " "rsi, r8"),
        Q!("    bt              " "r8, 0x3f"),
        Q!("    cmovb           " "rbx, rcx"),
        Q!("    mov             " "r8, rax"),
        Q!("    sub             " "rsi, rax"),
        Q!("    lea             " "rcx, [rcx + rdi]"),
        Q!("    cmovs           " "r8, rbp"),
        Q!("    mov             " "rdi, rbx"),
        Q!("    test            " "rcx, rdx"),
        Q!("    cmove           " "r8, rbp"),
        Q!("    cmove           " "rdi, rbp"),
        Q!("    sar             " "rcx, 1"),
        Q!("    xor             " "rdi, r8"),
        Q!("    xor             " "rsi, r8"),
        Q!("    bt              " "r8, 0x3f"),
        Q!("    cmovb           " "rbx, rcx"),
        Q!("    mov             " "r8, rax"),
        Q!("    sub             " "rsi, rax"),
        Q!("    lea             " "rcx, [rcx + rdi]"),
        Q!("    cmovs           " "r8, rbp"),
        Q!("    mov             " "rdi, rbx"),
        Q!("    test            " "rcx, rdx"),
        Q!("    cmove           " "r8, rbp"),
        Q!("    cmove           " "rdi, rbp"),
        Q!("    sar             " "rcx, 1"),
        Q!("    xor             " "rdi, r8"),
        Q!("    xor             " "rsi, r8"),
        Q!("    bt              " "r8, 0x3f"),
        Q!("    cmovb           " "rbx, rcx"),
        Q!("    mov             " "r8, rax"),
        Q!("    sub             " "rsi, rax"),
        Q!("    lea             " "rcx, [rcx + rdi]"),
        Q!("    cmovs           " "r8, rbp"),
        Q!("    mov             " "rdi, rbx"),
        Q!("    test            " "rcx, rdx"),
        Q!("    cmove           " "r8, rbp"),
        Q!("    cmove           " "rdi, rbp"),
        Q!("    sar             " "rcx, 1"),
        Q!("    xor             " "rdi, r8"),
        Q!("    xor             " "rsi, r8"),
        Q!("    bt              " "r8, 0x3f"),
        Q!("    cmovb           " "rbx, rcx"),
        Q!("    mov             " "r8, rax"),
        Q!("    sub             " "rsi, rax"),
        Q!("    lea             " "rcx, [rcx + rdi]"),
        Q!("    cmovs           " "r8, rbp"),
        Q!("    mov             " "rdi, rbx"),
        Q!("    test            " "rcx, rdx"),
        Q!("    cmove           " "r8, rbp"),
        Q!("    cmove           " "rdi, rbp"),
        Q!("    sar             " "rcx, 1"),
        Q!("    xor             " "rdi, r8"),
        Q!("    xor             " "rsi, r8"),
        Q!("    bt              " "r8, 0x3f"),
        Q!("    cmovb           " "rbx, rcx"),
        Q!("    mov             " "r8, rax"),
        Q!("    sub             " "rsi, rax"),
        Q!("    lea             " "rcx, [rcx + rdi]"),
        Q!("    cmovs           " "r8, rbp"),
        Q!("    mov             " "rdi, rbx"),
        Q!("    test            " "rcx, rdx"),
        Q!("    cmove           " "r8, rbp"),
        Q!("    cmove           " "rdi, rbp"),
        Q!("    sar             " "rcx, 1"),
        Q!("    xor             " "rdi, r8"),
        Q!("    xor             " "rsi, r8"),
        Q!("    bt              " "r8, 0x3f"),
        Q!("    cmovb           " "rbx, rcx"),
        Q!("    mov             " "r8, rax"),
        Q!("    sub             " "rsi, rax"),
        Q!("    lea             " "rcx, [rcx + rdi]"),
        Q!("    cmovs           " "r8, rbp"),
        Q!("    mov             " "rdi, rbx"),
        Q!("    test            " "rcx, rdx"),
        Q!("    cmove           " "r8, rbp"),
        Q!("    cmove           " "rdi, rbp"),
        Q!("    sar             " "rcx, 1"),
        Q!("    xor             " "rdi, r8"),
        Q!("    xor             " "rsi, r8"),
        Q!("    bt              " "r8, 0x3f"),
        Q!("    cmovb           " "rbx, rcx"),
        Q!("    mov             " "r8, rax"),
        Q!("    sub             " "rsi, rax"),
        Q!("    lea             " "rcx, [rcx + rdi]"),
        Q!("    cmovs           " "r8, rbp"),
        Q!("    mov             " "rdi, rbx"),
        Q!("    test            " "rcx, rdx"),
        Q!("    cmove           " "r8, rbp"),
        Q!("    cmove           " "rdi, rbp"),
        Q!("    sar             " "rcx, 1"),
        Q!("    xor             " "rdi, r8"),
        Q!("    xor             " "rsi, r8"),
        Q!("    bt              " "r8, 0x3f"),
        Q!("    cmovb           " "rbx, rcx"),
        Q!("    mov             " "r8, rax"),
        Q!("    sub             " "rsi, rax"),
        Q!("    lea             " "rcx, [rcx + rdi]"),
        Q!("    cmovs           " "r8, rbp"),
        Q!("    mov             " "rdi, rbx"),
        Q!("    test            " "rcx, rdx"),
        Q!("    cmove           " "r8, rbp"),
        Q!("    cmove           " "rdi, rbp"),
        Q!("    sar             " "rcx, 1"),
        Q!("    xor             " "rdi, r8"),
        Q!("    xor             " "rsi, r8"),
        Q!("    bt              " "r8, 0x3f"),
        Q!("    cmovb           " "rbx, rcx"),
        Q!("    mov             " "r8, rax"),
        Q!("    sub             " "rsi, rax"),
        Q!("    lea             " "rcx, [rcx + rdi]"),
        Q!("    cmovs           " "r8, rbp"),
        Q!("    mov             " "rdi, rbx"),
        Q!("    test            " "rcx, rdx"),
        Q!("    cmove           " "r8, rbp"),
        Q!("    cmove           " "rdi, rbp"),
        Q!("    sar             " "rcx, 1"),
        Q!("    xor             " "rdi, r8"),
        Q!("    xor             " "rsi, r8"),
        Q!("    bt              " "r8, 0x3f"),
        Q!("    cmovb           " "rbx, rcx"),
        Q!("    mov             " "r8, rax"),
        Q!("    sub             " "rsi, rax"),
        Q!("    lea             " "rcx, [rcx + rdi]"),
        Q!("    cmovs           " "r8, rbp"),
        Q!("    mov             " "rdi, rbx"),
        Q!("    test            " "rcx, rdx"),
        Q!("    cmove           " "r8, rbp"),
        Q!("    cmove           " "rdi, rbp"),
        Q!("    sar             " "rcx, 1"),
        Q!("    xor             " "rdi, r8"),
        Q!("    xor             " "rsi, r8"),
        Q!("    bt              " "r8, 0x3f"),
        Q!("    cmovb           " "rbx, rcx"),
        Q!("    mov             " "r8, rax"),
        Q!("    sub             " "rsi, rax"),
        Q!("    lea             " "rcx, [rcx + rdi]"),
        Q!("    cmovs           " "r8, rbp"),
        Q!("    mov             " "rdi, rbx"),
        Q!("    test            " "rcx, rdx"),
        Q!("    cmove           " "r8, rbp"),
        Q!("    cmove           " "rdi, rbp"),
        Q!("    sar             " "rcx, 1"),
        Q!("    xor             " "rdi, r8"),
        Q!("    xor             " "rsi, r8"),
        Q!("    bt              " "r8, 0x3f"),
        Q!("    cmovb           " "rbx, rcx"),
        Q!("    mov             " "r8, rax"),
        Q!("    sub             " "rsi, rax"),
        Q!("    lea             " "rcx, [rcx + rdi]"),
        Q!("    cmovs           " "r8, rbp"),
        Q!("    mov             " "rdi, rbx"),
        Q!("    test            " "rcx, rdx"),
        Q!("    cmove           " "r8, rbp"),
        Q!("    cmove           " "rdi, rbp"),
        Q!("    sar             " "rcx, 1"),
        Q!("    xor             " "rdi, r8"),
        Q!("    xor             " "rsi, r8"),
        Q!("    bt              " "r8, 0x3f"),
        Q!("    cmovb           " "rbx, rcx"),
        Q!("    mov             " "r8, rax"),
        Q!("    sub             " "rsi, rax"),
        Q!("    lea             " "rcx, [rcx + rdi]"),
        Q!("    cmovs           " "r8, rbp"),
        Q!("    mov             " "rdi, rbx"),
        Q!("    test            " "rcx, rdx"),
        Q!("    cmove           " "r8, rbp"),
        Q!("    cmove           " "rdi, rbp"),
        Q!("    sar             " "rcx, 1"),
        Q!("    xor             " "rdi, r8"),
        Q!("    xor             " "rsi, r8"),
        Q!("    bt              " "r8, 0x3f"),
        Q!("    cmovb           " "rbx, rcx"),
        Q!("    mov             " "r8, rax"),
        Q!("    sub             " "rsi, rax"),
        Q!("    lea             " "rcx, [rcx + rdi]"),
        Q!("    cmovs           " "r8, rbp"),
        Q!("    mov             " "rdi, rbx"),
        Q!("    test            " "rcx, rdx"),
        Q!("    cmove           " "r8, rbp"),
        Q!("    cmove           " "rdi, rbp"),
        Q!("    sar             " "rcx, 1"),
        Q!("    xor             " "rdi, r8"),
        Q!("    xor             " "rsi, r8"),
        Q!("    bt              " "r8, 0x3f"),
        Q!("    cmovb           " "rbx, rcx"),
        Q!("    mov             " "r8, rax"),
        Q!("    sub             " "rsi, rax"),
        Q!("    lea             " "rcx, [rcx + rdi]"),
        Q!("    cmovs           " "r8, rbp"),
        Q!("    mov             " "rdi, rbx"),
        Q!("    test            " "rcx, rdx"),
        Q!("    cmove           " "r8, rbp"),
        Q!("    cmove           " "rdi, rbp"),
        Q!("    sar             " "rcx, 1"),
        Q!("    xor             " "rdi, r8"),
        Q!("    xor             " "rsi, r8"),
        Q!("    bt              " "r8, 0x3f"),
        Q!("    cmovb           " "rbx, rcx"),
        Q!("    mov             " "r8, rax"),
        Q!("    sub             " "rsi, rax"),
        Q!("    lea             " "rcx, [rcx + rdi]"),
        Q!("    cmovs           " "r8, rbp"),
        Q!("    mov             " "rdi, rbx"),
        Q!("    test            " "rcx, rdx"),
        Q!("    cmove           " "r8, rbp"),
        Q!("    cmove           " "rdi, rbp"),
        Q!("    sar             " "rcx, 1"),
        Q!("    xor             " "rdi, r8"),
        Q!("    xor             " "rsi, r8"),
        Q!("    bt              " "r8, 0x3f"),
        Q!("    cmovb           " "rbx, rcx"),
        Q!("    mov             " "r8, rax"),
        Q!("    sub             " "rsi, rax"),
        Q!("    lea             " "rcx, [rcx + rdi]"),
        Q!("    cmovs           " "r8, rbp"),
        Q!("    mov             " "rdi, rbx"),
        Q!("    test            " "rcx, rdx"),
        Q!("    cmove           " "r8, rbp"),
        Q!("    cmove           " "rdi, rbp"),
        Q!("    sar             " "rcx, 1"),
        Q!("    xor             " "rdi, r8"),
        Q!("    xor             " "rsi, r8"),
        Q!("    bt              " "r8, 0x3f"),
        Q!("    cmovb           " "rbx, rcx"),
        Q!("    mov             " "r8, rax"),
        Q!("    sub             " "rsi, rax"),
        Q!("    lea             " "rcx, [rcx + rdi]"),
        Q!("    cmovs           " "r8, rbp"),
        Q!("    mov             " "rdi, rbx"),
        Q!("    test            " "rcx, rdx"),
        Q!("    cmove           " "r8, rbp"),
        Q!("    cmove           " "rdi, rbp"),
        Q!("    sar             " "rcx, 1"),
        Q!("    xor             " "rdi, r8"),
        Q!("    xor             " "rsi, r8"),
        Q!("    bt              " "r8, 0x3f"),
        Q!("    cmovb           " "rbx, rcx"),
        Q!("    mov             " "r8, rax"),
        Q!("    sub             " "rsi, rax"),
        Q!("    lea             " "rcx, [rcx + rdi]"),
        Q!("    cmovs           " "r8, rbp"),
        Q!("    mov             " "rdi, rbx"),
        Q!("    test            " "rcx, rdx"),
        Q!("    cmove           " "r8, rbp"),
        Q!("    cmove           " "rdi, rbp"),
        Q!("    sar             " "rcx, 1"),
        Q!("    xor             " "rdi, r8"),
        Q!("    xor             " "rsi, r8"),
        Q!("    bt              " "r8, 0x3f"),
        Q!("    cmovb           " "rbx, rcx"),
        Q!("    mov             " "r8, rax"),
        Q!("    sub             " "rsi, rax"),
        Q!("    lea             " "rcx, [rcx + rdi]"),
        Q!("    sar             " "rcx, 1"),
        Q!("    mov             " "eax, 0x100000"),
        Q!("    lea             " "rdx, [rbx + rax]"),
        Q!("    lea             " "rdi, [rcx + rax]"),
        Q!("    shl             " "rdx, 0x16"),
        Q!("    shl             " "rdi, 0x16"),
        Q!("    sar             " "rdx, 0x2b"),
        Q!("    sar             " "rdi, 0x2b"),
        Q!("    movabs          " "rax, 0x20000100000"),
        Q!("    lea             " "rbx, [rbx + rax]"),
        Q!("    lea             " "rcx, [rcx + rax]"),
        Q!("    sar             " "rbx, 0x2a"),
        Q!("    sar             " "rcx, 0x2a"),
        Q!("    mov             " "[rsp + 0xa0], rdx"),
        Q!("    mov             " "[rsp + 0xa8], rbx"),
        Q!("    mov             " "[rsp + 0xb0], rdi"),
        Q!("    mov             " "[rsp + 0xb8], rcx"),
        Q!("    mov             " "r12, [rsp]"),
        Q!("    imul            " "rdi, r12"),
        Q!("    imul            " "r12, rdx"),
        Q!("    mov             " "r13, [rsp + 0x20]"),
        Q!("    imul            " "rbx, r13"),
        Q!("    imul            " "r13, rcx"),
        Q!("    add             " "r12, rbx"),
        Q!("    add             " "r13, rdi"),
        Q!("    sar             " "r12, 0x14"),
        Q!("    sar             " "r13, 0x14"),
        Q!("    mov             " "rbx, r12"),
        Q!("    and             " "rbx, 0xfffff"),
        Q!("    movabs          " "rax, 0xfffffe0000000000"),
        Q!("    or              " "rbx, rax"),
        Q!("    mov             " "rcx, r13"),
        Q!("    and             " "rcx, 0xfffff"),
        Q!("    movabs          " "rax, 0xc000000000000000"),
        Q!("    or              " "rcx, rax"),
        Q!("    mov             " "rax, 0xfffffffffffffffe"),
        Q!("    mov             " "edx, 0x2"),
        Q!("    mov             " "rdi, rbx"),
        Q!("    mov             " "r8, rax"),
        Q!("    test            " "rsi, rsi"),
        Q!("    cmovs           " "r8, rbp"),
        Q!("    test            " "rcx, 0x1"),
        Q!("    cmove           " "r8, rbp"),
        Q!("    cmove           " "rdi, rbp"),
        Q!("    xor             " "rdi, r8"),
        Q!("    xor             " "rsi, r8"),
        Q!("    bt              " "r8, 0x3f"),
        Q!("    cmovb           " "rbx, rcx"),
        Q!("    mov             " "r8, rax"),
        Q!("    sub             " "rsi, rax"),
        Q!("    lea             " "rcx, [rcx + rdi]"),
        Q!("    cmovs           " "r8, rbp"),
        Q!("    mov             " "rdi, rbx"),
        Q!("    test            " "rcx, rdx"),
        Q!("    cmove           " "r8, rbp"),
        Q!("    cmove           " "rdi, rbp"),
        Q!("    sar             " "rcx, 1"),
        Q!("    xor             " "rdi, r8"),
        Q!("    xor             " "rsi, r8"),
        Q!("    bt              " "r8, 0x3f"),
        Q!("    cmovb           " "rbx, rcx"),
        Q!("    mov             " "r8, rax"),
        Q!("    sub             " "rsi, rax"),
        Q!("    lea             " "rcx, [rcx + rdi]"),
        Q!("    cmovs           " "r8, rbp"),
        Q!("    mov             " "rdi, rbx"),
        Q!("    test            " "rcx, rdx"),
        Q!("    cmove           " "r8, rbp"),
        Q!("    cmove           " "rdi, rbp"),
        Q!("    sar             " "rcx, 1"),
        Q!("    xor             " "rdi, r8"),
        Q!("    xor             " "rsi, r8"),
        Q!("    bt              " "r8, 0x3f"),
        Q!("    cmovb           " "rbx, rcx"),
        Q!("    mov             " "r8, rax"),
        Q!("    sub             " "rsi, rax"),
        Q!("    lea             " "rcx, [rcx + rdi]"),
        Q!("    cmovs           " "r8, rbp"),
        Q!("    mov             " "rdi, rbx"),
        Q!("    test            " "rcx, rdx"),
        Q!("    cmove           " "r8, rbp"),
        Q!("    cmove           " "rdi, rbp"),
        Q!("    sar             " "rcx, 1"),
        Q!("    xor             " "rdi, r8"),
        Q!("    xor             " "rsi, r8"),
        Q!("    bt              " "r8, 0x3f"),
        Q!("    cmovb           " "rbx, rcx"),
        Q!("    mov             " "r8, rax"),
        Q!("    sub             " "rsi, rax"),
        Q!("    lea             " "rcx, [rcx + rdi]"),
        Q!("    cmovs           " "r8, rbp"),
        Q!("    mov             " "rdi, rbx"),
        Q!("    test            " "rcx, rdx"),
        Q!("    cmove           " "r8, rbp"),
        Q!("    cmove           " "rdi, rbp"),
        Q!("    sar             " "rcx, 1"),
        Q!("    xor             " "rdi, r8"),
        Q!("    xor             " "rsi, r8"),
        Q!("    bt              " "r8, 0x3f"),
        Q!("    cmovb           " "rbx, rcx"),
        Q!("    mov             " "r8, rax"),
        Q!("    sub             " "rsi, rax"),
        Q!("    lea             " "rcx, [rcx + rdi]"),
        Q!("    cmovs           " "r8, rbp"),
        Q!("    mov             " "rdi, rbx"),
        Q!("    test            " "rcx, rdx"),
        Q!("    cmove           " "r8, rbp"),
        Q!("    cmove           " "rdi, rbp"),
        Q!("    sar             " "rcx, 1"),
        Q!("    xor             " "rdi, r8"),
        Q!("    xor             " "rsi, r8"),
        Q!("    bt              " "r8, 0x3f"),
        Q!("    cmovb           " "rbx, rcx"),
        Q!("    mov             " "r8, rax"),
        Q!("    sub             " "rsi, rax"),
        Q!("    lea             " "rcx, [rcx + rdi]"),
        Q!("    cmovs           " "r8, rbp"),
        Q!("    mov             " "rdi, rbx"),
        Q!("    test            " "rcx, rdx"),
        Q!("    cmove           " "r8, rbp"),
        Q!("    cmove           " "rdi, rbp"),
        Q!("    sar             " "rcx, 1"),
        Q!("    xor             " "rdi, r8"),
        Q!("    xor             " "rsi, r8"),
        Q!("    bt              " "r8, 0x3f"),
        Q!("    cmovb           " "rbx, rcx"),
        Q!("    mov             " "r8, rax"),
        Q!("    sub             " "rsi, rax"),
        Q!("    lea             " "rcx, [rcx + rdi]"),
        Q!("    cmovs           " "r8, rbp"),
        Q!("    mov             " "rdi, rbx"),
        Q!("    test            " "rcx, rdx"),
        Q!("    cmove           " "r8, rbp"),
        Q!("    cmove           " "rdi, rbp"),
        Q!("    sar             " "rcx, 1"),
        Q!("    xor             " "rdi, r8"),
        Q!("    xor             " "rsi, r8"),
        Q!("    bt              " "r8, 0x3f"),
        Q!("    cmovb           " "rbx, rcx"),
        Q!("    mov             " "r8, rax"),
        Q!("    sub             " "rsi, rax"),
        Q!("    lea             " "rcx, [rcx + rdi]"),
        Q!("    cmovs           " "r8, rbp"),
        Q!("    mov             " "rdi, rbx"),
        Q!("    test            " "rcx, rdx"),
        Q!("    cmove           " "r8, rbp"),
        Q!("    cmove           " "rdi, rbp"),
        Q!("    sar             " "rcx, 1"),
        Q!("    xor             " "rdi, r8"),
        Q!("    xor             " "rsi, r8"),
        Q!("    bt              " "r8, 0x3f"),
        Q!("    cmovb           " "rbx, rcx"),
        Q!("    mov             " "r8, rax"),
        Q!("    sub             " "rsi, rax"),
        Q!("    lea             " "rcx, [rcx + rdi]"),
        Q!("    cmovs           " "r8, rbp"),
        Q!("    mov             " "rdi, rbx"),
        Q!("    test            " "rcx, rdx"),
        Q!("    cmove           " "r8, rbp"),
        Q!("    cmove           " "rdi, rbp"),
        Q!("    sar             " "rcx, 1"),
        Q!("    xor             " "rdi, r8"),
        Q!("    xor             " "rsi, r8"),
        Q!("    bt              " "r8, 0x3f"),
        Q!("    cmovb           " "rbx, rcx"),
        Q!("    mov             " "r8, rax"),
        Q!("    sub             " "rsi, rax"),
        Q!("    lea             " "rcx, [rcx + rdi]"),
        Q!("    cmovs           " "r8, rbp"),
        Q!("    mov             " "rdi, rbx"),
        Q!("    test            " "rcx, rdx"),
        Q!("    cmove           " "r8, rbp"),
        Q!("    cmove           " "rdi, rbp"),
        Q!("    sar             " "rcx, 1"),
        Q!("    xor             " "rdi, r8"),
        Q!("    xor             " "rsi, r8"),
        Q!("    bt              " "r8, 0x3f"),
        Q!("    cmovb           " "rbx, rcx"),
        Q!("    mov             " "r8, rax"),
        Q!("    sub             " "rsi, rax"),
        Q!("    lea             " "rcx, [rcx + rdi]"),
        Q!("    cmovs           " "r8, rbp"),
        Q!("    mov             " "rdi, rbx"),
        Q!("    test            " "rcx, rdx"),
        Q!("    cmove           " "r8, rbp"),
        Q!("    cmove           " "rdi, rbp"),
        Q!("    sar             " "rcx, 1"),
        Q!("    xor             " "rdi, r8"),
        Q!("    xor             " "rsi, r8"),
        Q!("    bt              " "r8, 0x3f"),
        Q!("    cmovb           " "rbx, rcx"),
        Q!("    mov             " "r8, rax"),
        Q!("    sub             " "rsi, rax"),
        Q!("    lea             " "rcx, [rcx + rdi]"),
        Q!("    cmovs           " "r8, rbp"),
        Q!("    mov             " "rdi, rbx"),
        Q!("    test            " "rcx, rdx"),
        Q!("    cmove           " "r8, rbp"),
        Q!("    cmove           " "rdi, rbp"),
        Q!("    sar             " "rcx, 1"),
        Q!("    xor             " "rdi, r8"),
        Q!("    xor             " "rsi, r8"),
        Q!("    bt              " "r8, 0x3f"),
        Q!("    cmovb           " "rbx, rcx"),
        Q!("    mov             " "r8, rax"),
        Q!("    sub             " "rsi, rax"),
        Q!("    lea             " "rcx, [rcx + rdi]"),
        Q!("    cmovs           " "r8, rbp"),
        Q!("    mov             " "rdi, rbx"),
        Q!("    test            " "rcx, rdx"),
        Q!("    cmove           " "r8, rbp"),
        Q!("    cmove           " "rdi, rbp"),
        Q!("    sar             " "rcx, 1"),
        Q!("    xor             " "rdi, r8"),
        Q!("    xor             " "rsi, r8"),
        Q!("    bt              " "r8, 0x3f"),
        Q!("    cmovb           " "rbx, rcx"),
        Q!("    mov             " "r8, rax"),
        Q!("    sub             " "rsi, rax"),
        Q!("    lea             " "rcx, [rcx + rdi]"),
        Q!("    cmovs           " "r8, rbp"),
        Q!("    mov             " "rdi, rbx"),
        Q!("    test            " "rcx, rdx"),
        Q!("    cmove           " "r8, rbp"),
        Q!("    cmove           " "rdi, rbp"),
        Q!("    sar             " "rcx, 1"),
        Q!("    xor             " "rdi, r8"),
        Q!("    xor             " "rsi, r8"),
        Q!("    bt              " "r8, 0x3f"),
        Q!("    cmovb           " "rbx, rcx"),
        Q!("    mov             " "r8, rax"),
        Q!("    sub             " "rsi, rax"),
        Q!("    lea             " "rcx, [rcx + rdi]"),
        Q!("    cmovs           " "r8, rbp"),
        Q!("    mov             " "rdi, rbx"),
        Q!("    test            " "rcx, rdx"),
        Q!("    cmove           " "r8, rbp"),
        Q!("    cmove           " "rdi, rbp"),
        Q!("    sar             " "rcx, 1"),
        Q!("    xor             " "rdi, r8"),
        Q!("    xor             " "rsi, r8"),
        Q!("    bt              " "r8, 0x3f"),
        Q!("    cmovb           " "rbx, rcx"),
        Q!("    mov             " "r8, rax"),
        Q!("    sub             " "rsi, rax"),
        Q!("    lea             " "rcx, [rcx + rdi]"),
        Q!("    cmovs           " "r8, rbp"),
        Q!("    mov             " "rdi, rbx"),
        Q!("    test            " "rcx, rdx"),
        Q!("    cmove           " "r8, rbp"),
        Q!("    cmove           " "rdi, rbp"),
        Q!("    sar             " "rcx, 1"),
        Q!("    xor             " "rdi, r8"),
        Q!("    xor             " "rsi, r8"),
        Q!("    bt              " "r8, 0x3f"),
        Q!("    cmovb           " "rbx, rcx"),
        Q!("    mov             " "r8, rax"),
        Q!("    sub             " "rsi, rax"),
        Q!("    lea             " "rcx, [rcx + rdi]"),
        Q!("    cmovs           " "r8, rbp"),
        Q!("    mov             " "rdi, rbx"),
        Q!("    test            " "rcx, rdx"),
        Q!("    cmove           " "r8, rbp"),
        Q!("    cmove           " "rdi, rbp"),
        Q!("    sar             " "rcx, 1"),
        Q!("    xor             " "rdi, r8"),
        Q!("    xor             " "rsi, r8"),
        Q!("    bt              " "r8, 0x3f"),
        Q!("    cmovb           " "rbx, rcx"),
        Q!("    mov             " "r8, rax"),
        Q!("    sub             " "rsi, rax"),
        Q!("    lea             " "rcx, [rcx + rdi]"),
        Q!("    cmovs           " "r8, rbp"),
        Q!("    mov             " "rdi, rbx"),
        Q!("    test            " "rcx, rdx"),
        Q!("    cmove           " "r8, rbp"),
        Q!("    cmove           " "rdi, rbp"),
        Q!("    sar             " "rcx, 1"),
        Q!("    xor             " "rdi, r8"),
        Q!("    xor             " "rsi, r8"),
        Q!("    bt              " "r8, 0x3f"),
        Q!("    cmovb           " "rbx, rcx"),
        Q!("    mov             " "r8, rax"),
        Q!("    sub             " "rsi, rax"),
        Q!("    lea             " "rcx, [rcx + rdi]"),
        Q!("    cmovs           " "r8, rbp"),
        Q!("    mov             " "rdi, rbx"),
        Q!("    test            " "rcx, rdx"),
        Q!("    cmove           " "r8, rbp"),
        Q!("    cmove           " "rdi, rbp"),
        Q!("    sar             " "rcx, 1"),
        Q!("    xor             " "rdi, r8"),
        Q!("    xor             " "rsi, r8"),
        Q!("    bt              " "r8, 0x3f"),
        Q!("    cmovb           " "rbx, rcx"),
        Q!("    mov             " "r8, rax"),
        Q!("    sub             " "rsi, rax"),
        Q!("    lea             " "rcx, [rcx + rdi]"),
        Q!("    sar             " "rcx, 1"),
        Q!("    mov             " "eax, 0x100000"),
        Q!("    lea             " "r8, [rbx + rax]"),
        Q!("    lea             " "r10, [rcx + rax]"),
        Q!("    shl             " "r8, 0x16"),
        Q!("    shl             " "r10, 0x16"),
        Q!("    sar             " "r8, 0x2b"),
        Q!("    sar             " "r10, 0x2b"),
        Q!("    movabs          " "rax, 0x20000100000"),
        Q!("    lea             " "r15, [rbx + rax]"),
        Q!("    lea             " "r11, [rcx + rax]"),
        Q!("    sar             " "r15, 0x2a"),
        Q!("    sar             " "r11, 0x2a"),
        Q!("    mov             " "rbx, r13"),
        Q!("    mov             " "rcx, r12"),
        Q!("    imul            " "r12, r8"),
        Q!("    imul            " "rbx, r15"),
        Q!("    add             " "r12, rbx"),
        Q!("    imul            " "r13, r11"),
        Q!("    imul            " "rcx, r10"),
        Q!("    add             " "r13, rcx"),
        Q!("    sar             " "r12, 0x14"),
        Q!("    sar             " "r13, 0x14"),
        Q!("    mov             " "rbx, r12"),
        Q!("    and             " "rbx, 0xfffff"),
        Q!("    movabs          " "rax, 0xfffffe0000000000"),
        Q!("    or              " "rbx, rax"),
        Q!("    mov             " "rcx, r13"),
        Q!("    and             " "rcx, 0xfffff"),
        Q!("    movabs          " "rax, 0xc000000000000000"),
        Q!("    or              " "rcx, rax"),
        Q!("    mov             " "rax, [rsp + 0xa0]"),
        Q!("    imul            " "rax, r8"),
        Q!("    mov             " "rdx, [rsp + 0xb0]"),
        Q!("    imul            " "rdx, r15"),
        Q!("    imul            " "r8, [rsp + 0xa8]"),
        Q!("    imul            " "r15, [rsp + 0xb8]"),
        Q!("    add             " "r15, r8"),
        Q!("    lea             " "r9, [rax + rdx]"),
        Q!("    mov             " "rax, [rsp + 0xa0]"),
        Q!("    imul            " "rax, r10"),
        Q!("    mov             " "rdx, [rsp + 0xb0]"),
        Q!("    imul            " "rdx, r11"),
        Q!("    imul            " "r10, [rsp + 0xa8]"),
        Q!("    imul            " "r11, [rsp + 0xb8]"),
        Q!("    add             " "r11, r10"),
        Q!("    lea             " "r13, [rax + rdx]"),
        Q!("    mov             " "rax, 0xfffffffffffffffe"),
        Q!("    mov             " "edx, 0x2"),
        Q!("    mov             " "rdi, rbx"),
        Q!("    mov             " "r8, rax"),
        Q!("    test            " "rsi, rsi"),
        Q!("    cmovs           " "r8, rbp"),
        Q!("    test            " "rcx, 0x1"),
        Q!("    cmove           " "r8, rbp"),
        Q!("    cmove           " "rdi, rbp"),
        Q!("    xor             " "rdi, r8"),
        Q!("    xor             " "rsi, r8"),
        Q!("    bt              " "r8, 0x3f"),
        Q!("    cmovb           " "rbx, rcx"),
        Q!("    mov             " "r8, rax"),
        Q!("    sub             " "rsi, rax"),
        Q!("    lea             " "rcx, [rcx + rdi]"),
        Q!("    cmovs           " "r8, rbp"),
        Q!("    mov             " "rdi, rbx"),
        Q!("    test            " "rcx, rdx"),
        Q!("    cmove           " "r8, rbp"),
        Q!("    cmove           " "rdi, rbp"),
        Q!("    sar             " "rcx, 1"),
        Q!("    xor             " "rdi, r8"),
        Q!("    xor             " "rsi, r8"),
        Q!("    bt              " "r8, 0x3f"),
        Q!("    cmovb           " "rbx, rcx"),
        Q!("    mov             " "r8, rax"),
        Q!("    sub             " "rsi, rax"),
        Q!("    lea             " "rcx, [rcx + rdi]"),
        Q!("    cmovs           " "r8, rbp"),
        Q!("    mov             " "rdi, rbx"),
        Q!("    test            " "rcx, rdx"),
        Q!("    cmove           " "r8, rbp"),
        Q!("    cmove           " "rdi, rbp"),
        Q!("    sar             " "rcx, 1"),
        Q!("    xor             " "rdi, r8"),
        Q!("    xor             " "rsi, r8"),
        Q!("    bt              " "r8, 0x3f"),
        Q!("    cmovb           " "rbx, rcx"),
        Q!("    mov             " "r8, rax"),
        Q!("    sub             " "rsi, rax"),
        Q!("    lea             " "rcx, [rcx + rdi]"),
        Q!("    cmovs           " "r8, rbp"),
        Q!("    mov             " "rdi, rbx"),
        Q!("    test            " "rcx, rdx"),
        Q!("    cmove           " "r8, rbp"),
        Q!("    cmove           " "rdi, rbp"),
        Q!("    sar             " "rcx, 1"),
        Q!("    xor             " "rdi, r8"),
        Q!("    xor             " "rsi, r8"),
        Q!("    bt              " "r8, 0x3f"),
        Q!("    cmovb           " "rbx, rcx"),
        Q!("    mov             " "r8, rax"),
        Q!("    sub             " "rsi, rax"),
        Q!("    lea             " "rcx, [rcx + rdi]"),
        Q!("    cmovs           " "r8, rbp"),
        Q!("    mov             " "rdi, rbx"),
        Q!("    test            " "rcx, rdx"),
        Q!("    cmove           " "r8, rbp"),
        Q!("    cmove           " "rdi, rbp"),
        Q!("    sar             " "rcx, 1"),
        Q!("    xor             " "rdi, r8"),
        Q!("    xor             " "rsi, r8"),
        Q!("    bt              " "r8, 0x3f"),
        Q!("    cmovb           " "rbx, rcx"),
        Q!("    mov             " "r8, rax"),
        Q!("    sub             " "rsi, rax"),
        Q!("    lea             " "rcx, [rcx + rdi]"),
        Q!("    cmovs           " "r8, rbp"),
        Q!("    mov             " "rdi, rbx"),
        Q!("    test            " "rcx, rdx"),
        Q!("    cmove           " "r8, rbp"),
        Q!("    cmove           " "rdi, rbp"),
        Q!("    sar             " "rcx, 1"),
        Q!("    xor             " "rdi, r8"),
        Q!("    xor             " "rsi, r8"),
        Q!("    bt              " "r8, 0x3f"),
        Q!("    cmovb           " "rbx, rcx"),
        Q!("    mov             " "r8, rax"),
        Q!("    sub             " "rsi, rax"),
        Q!("    lea             " "rcx, [rcx + rdi]"),
        Q!("    cmovs           " "r8, rbp"),
        Q!("    mov             " "rdi, rbx"),
        Q!("    test            " "rcx, rdx"),
        Q!("    cmove           " "r8, rbp"),
        Q!("    cmove           " "rdi, rbp"),
        Q!("    sar             " "rcx, 1"),
        Q!("    xor             " "rdi, r8"),
        Q!("    xor             " "rsi, r8"),
        Q!("    bt              " "r8, 0x3f"),
        Q!("    cmovb           " "rbx, rcx"),
        Q!("    mov             " "r8, rax"),
        Q!("    sub             " "rsi, rax"),
        Q!("    lea             " "rcx, [rcx + rdi]"),
        Q!("    cmovs           " "r8, rbp"),
        Q!("    mov             " "rdi, rbx"),
        Q!("    test            " "rcx, rdx"),
        Q!("    cmove           " "r8, rbp"),
        Q!("    cmove           " "rdi, rbp"),
        Q!("    sar             " "rcx, 1"),
        Q!("    xor             " "rdi, r8"),
        Q!("    xor             " "rsi, r8"),
        Q!("    bt              " "r8, 0x3f"),
        Q!("    cmovb           " "rbx, rcx"),
        Q!("    mov             " "r8, rax"),
        Q!("    sub             " "rsi, rax"),
        Q!("    lea             " "rcx, [rcx + rdi]"),
        Q!("    cmovs           " "r8, rbp"),
        Q!("    mov             " "rdi, rbx"),
        Q!("    test            " "rcx, rdx"),
        Q!("    cmove           " "r8, rbp"),
        Q!("    cmove           " "rdi, rbp"),
        Q!("    sar             " "rcx, 1"),
        Q!("    xor             " "rdi, r8"),
        Q!("    xor             " "rsi, r8"),
        Q!("    bt              " "r8, 0x3f"),
        Q!("    cmovb           " "rbx, rcx"),
        Q!("    mov             " "r8, rax"),
        Q!("    sub             " "rsi, rax"),
        Q!("    lea             " "rcx, [rcx + rdi]"),
        Q!("    cmovs           " "r8, rbp"),
        Q!("    mov             " "rdi, rbx"),
        Q!("    test            " "rcx, rdx"),
        Q!("    cmove           " "r8, rbp"),
        Q!("    cmove           " "rdi, rbp"),
        Q!("    sar             " "rcx, 1"),
        Q!("    xor             " "rdi, r8"),
        Q!("    xor             " "rsi, r8"),
        Q!("    bt              " "r8, 0x3f"),
        Q!("    cmovb           " "rbx, rcx"),
        Q!("    mov             " "r8, rax"),
        Q!("    sub             " "rsi, rax"),
        Q!("    lea             " "rcx, [rcx + rdi]"),
        Q!("    cmovs           " "r8, rbp"),
        Q!("    mov             " "rdi, rbx"),
        Q!("    test            " "rcx, rdx"),
        Q!("    cmove           " "r8, rbp"),
        Q!("    cmove           " "rdi, rbp"),
        Q!("    sar             " "rcx, 1"),
        Q!("    xor             " "rdi, r8"),
        Q!("    xor             " "rsi, r8"),
        Q!("    bt              " "r8, 0x3f"),
        Q!("    cmovb           " "rbx, rcx"),
        Q!("    mov             " "r8, rax"),
        Q!("    sub             " "rsi, rax"),
        Q!("    lea             " "rcx, [rcx + rdi]"),
        Q!("    cmovs           " "r8, rbp"),
        Q!("    mov             " "rdi, rbx"),
        Q!("    test            " "rcx, rdx"),
        Q!("    cmove           " "r8, rbp"),
        Q!("    cmove           " "rdi, rbp"),
        Q!("    sar             " "rcx, 1"),
        Q!("    xor             " "rdi, r8"),
        Q!("    xor             " "rsi, r8"),
        Q!("    bt              " "r8, 0x3f"),
        Q!("    cmovb           " "rbx, rcx"),
        Q!("    mov             " "r8, rax"),
        Q!("    sub             " "rsi, rax"),
        Q!("    lea             " "rcx, [rcx + rdi]"),
        Q!("    cmovs           " "r8, rbp"),
        Q!("    mov             " "rdi, rbx"),
        Q!("    test            " "rcx, rdx"),
        Q!("    cmove           " "r8, rbp"),
        Q!("    cmove           " "rdi, rbp"),
        Q!("    sar             " "rcx, 1"),
        Q!("    xor             " "rdi, r8"),
        Q!("    xor             " "rsi, r8"),
        Q!("    bt              " "r8, 0x3f"),
        Q!("    cmovb           " "rbx, rcx"),
        Q!("    mov             " "r8, rax"),
        Q!("    sub             " "rsi, rax"),
        Q!("    lea             " "rcx, [rcx + rdi]"),
        Q!("    cmovs           " "r8, rbp"),
        Q!("    mov             " "rdi, rbx"),
        Q!("    test            " "rcx, rdx"),
        Q!("    cmove           " "r8, rbp"),
        Q!("    cmove           " "rdi, rbp"),
        Q!("    sar             " "rcx, 1"),
        Q!("    xor             " "rdi, r8"),
        Q!("    xor             " "rsi, r8"),
        Q!("    bt              " "r8, 0x3f"),
        Q!("    cmovb           " "rbx, rcx"),
        Q!("    mov             " "r8, rax"),
        Q!("    sub             " "rsi, rax"),
        Q!("    lea             " "rcx, [rcx + rdi]"),
        Q!("    cmovs           " "r8, rbp"),
        Q!("    mov             " "rdi, rbx"),
        Q!("    test            " "rcx, rdx"),
        Q!("    cmove           " "r8, rbp"),
        Q!("    cmove           " "rdi, rbp"),
        Q!("    sar             " "rcx, 1"),
        Q!("    xor             " "rdi, r8"),
        Q!("    xor             " "rsi, r8"),
        Q!("    bt              " "r8, 0x3f"),
        Q!("    cmovb           " "rbx, rcx"),
        Q!("    mov             " "r8, rax"),
        Q!("    sub             " "rsi, rax"),
        Q!("    lea             " "rcx, [rcx + rdi]"),
        Q!("    cmovs           " "r8, rbp"),
        Q!("    mov             " "rdi, rbx"),
        Q!("    test            " "rcx, rdx"),
        Q!("    cmove           " "r8, rbp"),
        Q!("    cmove           " "rdi, rbp"),
        Q!("    sar             " "rcx, 1"),
        Q!("    xor             " "rdi, r8"),
        Q!("    xor             " "rsi, r8"),
        Q!("    bt              " "r8, 0x3f"),
        Q!("    cmovb           " "rbx, rcx"),
        Q!("    mov             " "r8, rax"),
        Q!("    sub             " "rsi, rax"),
        Q!("    lea             " "rcx, [rcx + rdi]"),
        Q!("    cmovs           " "r8, rbp"),
        Q!("    mov             " "rdi, rbx"),
        Q!("    test            " "rcx, rdx"),
        Q!("    cmove           " "r8, rbp"),
        Q!("    cmove           " "rdi, rbp"),
        Q!("    sar             " "rcx, 1"),
        Q!("    xor             " "rdi, r8"),
        Q!("    xor             " "rsi, r8"),
        Q!("    bt              " "r8, 0x3f"),
        Q!("    cmovb           " "rbx, rcx"),
        Q!("    mov             " "r8, rax"),
        Q!("    sub             " "rsi, rax"),
        Q!("    lea             " "rcx, [rcx + rdi]"),
        Q!("    cmovs           " "r8, rbp"),
        Q!("    mov             " "rdi, rbx"),
        Q!("    test            " "rcx, rdx"),
        Q!("    cmove           " "r8, rbp"),
        Q!("    cmove           " "rdi, rbp"),
        Q!("    sar             " "rcx, 1"),
        Q!("    xor             " "rdi, r8"),
        Q!("    xor             " "rsi, r8"),
        Q!("    bt              " "r8, 0x3f"),
        Q!("    cmovb           " "rbx, rcx"),
        Q!("    mov             " "r8, rax"),
        Q!("    sub             " "rsi, rax"),
        Q!("    lea             " "rcx, [rcx + rdi]"),
        Q!("    cmovs           " "r8, rbp"),
        Q!("    mov             " "rdi, rbx"),
        Q!("    test            " "rcx, rdx"),
        Q!("    cmove           " "r8, rbp"),
        Q!("    cmove           " "rdi, rbp"),
        Q!("    sar             " "rcx, 1"),
        Q!("    xor             " "rdi, r8"),
        Q!("    xor             " "rsi, r8"),
        Q!("    bt              " "r8, 0x3f"),
        Q!("    cmovb           " "rbx, rcx"),
        Q!("    mov             " "r8, rax"),
        Q!("    sub             " "rsi, rax"),
        Q!("    lea             " "rcx, [rcx + rdi]"),
        Q!("    sar             " "rcx, 1"),
        Q!("    mov             " "eax, 0x100000"),
        Q!("    lea             " "r8, [rbx + rax]"),
        Q!("    lea             " "r12, [rcx + rax]"),
        Q!("    shl             " "r8, 0x15"),
        Q!("    shl             " "r12, 0x15"),
        Q!("    sar             " "r8, 0x2b"),
        Q!("    sar             " "r12, 0x2b"),
        Q!("    movabs          " "rax, 0x20000100000"),
        Q!("    lea             " "r10, [rbx + rax]"),
        Q!("    lea             " "r14, [rcx + rax]"),
        Q!("    sar             " "r10, 0x2b"),
        Q!("    sar             " "r14, 0x2b"),
        Q!("    mov             " "rax, r9"),
        Q!("    imul            " "rax, r8"),
        Q!("    mov             " "rdx, r13"),
        Q!("    imul            " "rdx, r10"),
        Q!("    imul            " "r8, r15"),
        Q!("    imul            " "r10, r11"),
        Q!("    add             " "r10, r8"),
        Q!("    lea             " "r8, [rax + rdx]"),
        Q!("    mov             " "rax, r9"),
        Q!("    imul            " "rax, r12"),
        Q!("    mov             " "rdx, r13"),
        Q!("    imul            " "rdx, r14"),
        Q!("    imul            " "r12, r15"),
        Q!("    imul            " "r14, r11"),
        Q!("    add             " "r14, r12"),
        Q!("    lea             " "r12, [rax + rdx]"),
        Q!("    mov             " "[rsp + 0x98], rsi"),
        Q!("    dec             " "QWORD PTR [rsp + 0x90]"),
        Q!("    jne             " Label!("Ledwards25519_scalarmulbase_alt_inverseloop", 4, Before)),
        Q!("    mov             " "rax, [rsp]"),
        Q!("    mov             " "rcx, [rsp + 0x20]"),
        Q!("    imul            " "rax, r8"),
        Q!("    imul            " "rcx, r10"),
        Q!("    add             " "rax, rcx"),
        Q!("    sar             " "rax, 0x3f"),
        Q!("    mov             " "r9, r8"),
        Q!("    sar             " "r9, 0x3f"),
        Q!("    xor             " "r8, r9"),
        Q!("    sub             " "r8, r9"),
        Q!("    xor             " "r9, rax"),
        Q!("    mov             " "r11, r10"),
        Q!("    sar             " "r11, 0x3f"),
        Q!("    xor             " "r10, r11"),
        Q!("    sub             " "r10, r11"),
        Q!("    xor             " "r11, rax"),
        Q!("    mov             " "r13, r12"),
        Q!("    sar             " "r13, 0x3f"),
        Q!("    xor             " "r12, r13"),
        Q!("    sub             " "r12, r13"),
        Q!("    xor             " "r13, rax"),
        Q!("    mov             " "r15, r14"),
        Q!("    sar             " "r15, 0x3f"),
        Q!("    xor             " "r14, r15"),
        Q!("    sub             " "r14, r15"),
        Q!("    xor             " "r15, rax"),
        Q!("    mov             " "rax, r8"),
        Q!("    and             " "rax, r9"),
        Q!("    mov             " "r12, r10"),
        Q!("    and             " "r12, r11"),
        Q!("    add             " "r12, rax"),
        Q!("    xor             " "r13d, r13d"),
        Q!("    mov             " "rax, [rsp + 0x40]"),
        Q!("    xor             " "rax, r9"),
        Q!("    mul             " "r8"),
        Q!("    add             " "r12, rax"),
        Q!("    adc             " "r13, rdx"),
        Q!("    mov             " "rax, [rsp + 0x60]"),
        Q!("    xor             " "rax, r11"),
        Q!("    mul             " "r10"),
        Q!("    add             " "r12, rax"),
        Q!("    adc             " "r13, rdx"),
        Q!("    xor             " "r14d, r14d"),
        Q!("    mov             " "rax, [rsp + 0x48]"),
        Q!("    xor             " "rax, r9"),
        Q!("    mul             " "r8"),
        Q!("    add             " "r13, rax"),
        Q!("    adc             " "r14, rdx"),
        Q!("    mov             " "rax, [rsp + 0x68]"),
        Q!("    xor             " "rax, r11"),
        Q!("    mul             " "r10"),
        Q!("    add             " "r13, rax"),
        Q!("    adc             " "r14, rdx"),
        Q!("    xor             " "r15d, r15d"),
        Q!("    mov             " "rax, [rsp + 0x50]"),
        Q!("    xor             " "rax, r9"),
        Q!("    mul             " "r8"),
        Q!("    add             " "r14, rax"),
        Q!("    adc             " "r15, rdx"),
        Q!("    mov             " "rax, [rsp + 0x70]"),
        Q!("    xor             " "rax, r11"),
        Q!("    mul             " "r10"),
        Q!("    add             " "r14, rax"),
        Q!("    adc             " "r15, rdx"),
        Q!("    mov             " "rax, [rsp + 0x58]"),
        Q!("    xor             " "rax, r9"),
        Q!("    and             " "r9, r8"),
        Q!("    neg             " "r9"),
        Q!("    mul             " "r8"),
        Q!("    add             " "r15, rax"),
        Q!("    adc             " "r9, rdx"),
        Q!("    mov             " "rax, [rsp + 0x78]"),
        Q!("    xor             " "rax, r11"),
        Q!("    mov             " "rdx, r11"),
        Q!("    and             " "rdx, r10"),
        Q!("    sub             " "r9, rdx"),
        Q!("    mul             " "r10"),
        Q!("    add             " "r15, rax"),
        Q!("    adc             " "r9, rdx"),
        Q!("    mov             " "rax, r9"),
        Q!("    shld            " "rax, r15, 0x1"),
        Q!("    sar             " "r9, 0x3f"),
        Q!("    mov             " "ebx, 0x13"),
        Q!("    lea             " "rax, [rax + r9 + 0x1]"),
        Q!("    imul            " "rbx"),
        Q!("    xor             " "ebp, ebp"),
        Q!("    add             " "r12, rax"),
        Q!("    adc             " "r13, rdx"),
        Q!("    adc             " "r14, r9"),
        Q!("    adc             " "r15, r9"),
        Q!("    shl             " "rax, 0x3f"),
        Q!("    add             " "r15, rax"),
        Q!("    cmovns          " "rbx, rbp"),
        Q!("    sub             " "r12, rbx"),
        Q!("    sbb             " "r13, rbp"),
        Q!("    sbb             " "r14, rbp"),
        Q!("    sbb             " "r15, rbp"),
        Q!("    btr             " "r15, 0x3f"),
        Q!("    mov             " "rdi, [rsp + 0xc0]"),
        Q!("    mov             " "[rdi], r12"),
        Q!("    mov             " "[rdi + 0x8], r13"),
        Q!("    mov             " "[rdi + 0x10], r14"),
        Q!("    mov             " "[rdi + 0x18], r15"),

        // The final result is x = X * inv(Z), y = Y * inv(Z).
        // These are the only operations in the whole computation that
        // fully reduce modulo p_25519 since now we want the canonical
        // answer as output.

        Q!("    mov             " "rbp, " res!()),
        mul_p25519!(resx!(), x_3!(), w_3!()),
        mul_p25519!(resy!(), y_3!(), w_3!()),

        // Restore stack and registers

        Q!("    add             " "rsp, " NSPACE!()),

        Q!("    pop             " "r15"),
        Q!("    pop             " "r14"),
        Q!("    pop             " "r13"),
        Q!("    pop             " "r12"),
        Q!("    pop             " "rbp"),
        Q!("    pop             " "rbx"),
        inout("rdi") res.as_mut_ptr() => _,
        inout("rsi") scalar.as_ptr() => _,
        edwards25519_scalarmulbase_alt_constant = sym super::edwards25519_scalarmulbase::edwards25519_scalarmulbase_constant,
        // clobbers
        out("r10") _,
        out("r11") _,
        out("r12") _,
        out("r13") _,
        out("r14") _,
        out("r15") _,
        out("r8") _,
        out("r9") _,
        out("rax") _,
        out("rcx") _,
        out("rdx") _,
            )
    };
}

// ****************************************************************************
// The precomputed data (all read-only).
// ****************************************************************************
