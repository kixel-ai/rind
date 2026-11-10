// generated source. do not edit.
#![allow(non_upper_case_globals, unused_macros, unused_imports)]
use crate::low::macros::*;

// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

// ----------------------------------------------------------------------------
// Modular inverse modulo p_25519 = 2^255 - 19
// Input x[4]; output z[4]
//
// extern void bignum_inv_p25519(uint64_t z[static 4],const uint64_t x[static 4]);
//
// Assuming the 4-digit input x is coprime to p_25519, i.e. is not divisible
// by it, returns z < p_25519 such that x * z == 1 (mod p_25519). The input
// x does not need to be reduced modulo p_25519, but the output always is.
//
// Standard x86-64 ABI: RDI = z, RSI = x
// Microsoft x64 ABI:   RCX = z, RDX = x
// ----------------------------------------------------------------------------

// Size in bytes of a 64-bit word

macro_rules! N {
    () => {
        "8"
    };
}

// Pointer-offset pairs for temporaries on stack

macro_rules! f {
    () => {
        "rsp + 0"
    };
}
macro_rules! g { () => { Q!("rsp + (4 * " N!() ")") } }
macro_rules! u { () => { Q!("rsp + (8 * " N!() ")") } }
macro_rules! v { () => { Q!("rsp + (12 * " N!() ")") } }
macro_rules! tmp { () => { Q!("QWORD PTR [rsp + (16 * " N!() ")]") } }
macro_rules! tmp2 { () => { Q!("QWORD PTR [rsp + (17 * " N!() ")]") } }
macro_rules! i { () => { Q!("QWORD PTR [rsp + (18 * " N!() ")]") } }
macro_rules! d { () => { Q!("QWORD PTR [rsp + (19 * " N!() ")]") } }

macro_rules! mat { () => { Q!("rsp + (20 * " N!() ")") } }

// Backup for the input pointer

macro_rules! res { () => { Q!("QWORD PTR [rsp + (24 * " N!() ")]") } }

// Total size to reserve on the stack

macro_rules! NSPACE { () => { Q!("26 * " N!()) } }

// Syntactic variants to make x86_att version simpler to generate

macro_rules! F {
    () => {
        "0"
    };
}
macro_rules! G { () => { Q!("(4 * " N!() ")") } }
macro_rules! U { () => { Q!("(8 * " N!() ")") } }
macro_rules! V { () => { Q!("(12 * " N!() ")") } }
macro_rules! MAT { () => { Q!("(20 * " N!() ")") } }

macro_rules! ff {
    () => {
        "QWORD PTR [rsp]"
    };
}
macro_rules! gg { () => { Q!("QWORD PTR [rsp + (4 * " N!() ")]") } }

// Very similar to a subroutine call to the s2n-bignum word_divstep59.
// But different in register usage and returning the final matrix as
//
// [ r8   r10]
// [ r12  r14]
//
// and also returning the matrix still negated (which doesn't matter)

macro_rules! divstep59 {
    ($din:expr, $fin:expr, $gin:expr) => { Q!(
        "mov rsi, " $din ";\n"
        "mov rdx, " $fin ";\n"
        "mov rcx, " $gin ";\n"
        "mov rbx, rdx;\n"
        "and rbx, 0xfffff;\n"
        "movabs rax, 0xfffffe0000000000;\n"
        "or rbx, rax;\n"
        "and rcx, 0xfffff;\n"
        "movabs rax, 0xc000000000000000;\n"
        "or rcx, rax;\n"
        "mov rax, 0xfffffffffffffffe;\n"
        "xor ebp, ebp;\n"
        "mov edx, 0x2;\n"
        "mov rdi, rbx;\n"
        "mov r8, rax;\n"
        "test rsi, rsi;\n"
        "cmovs r8, rbp;\n"
        "test rcx, 0x1;\n"
        "cmove r8, rbp;\n"
        "cmove rdi, rbp;\n"
        "xor rdi, r8;\n"
        "xor rsi, r8;\n"
        "bt r8, 0x3f;\n"
        "cmovb rbx, rcx;\n"
        "mov r8, rax;\n"
        "sub rsi, rax;\n"
        "lea rcx, [rcx + rdi];\n"
        "cmovs r8, rbp;\n"
        "mov rdi, rbx;\n"
        "test rcx, rdx;\n"
        "cmove r8, rbp;\n"
        "cmove rdi, rbp;\n"
        "sar rcx, 1;\n"
        "xor rdi, r8;\n"
        "xor rsi, r8;\n"
        "bt r8, 0x3f;\n"
        "cmovb rbx, rcx;\n"
        "mov r8, rax;\n"
        "sub rsi, rax;\n"
        "lea rcx, [rcx + rdi];\n"
        "cmovs r8, rbp;\n"
        "mov rdi, rbx;\n"
        "test rcx, rdx;\n"
        "cmove r8, rbp;\n"
        "cmove rdi, rbp;\n"
        "sar rcx, 1;\n"
        "xor rdi, r8;\n"
        "xor rsi, r8;\n"
        "bt r8, 0x3f;\n"
        "cmovb rbx, rcx;\n"
        "mov r8, rax;\n"
        "sub rsi, rax;\n"
        "lea rcx, [rcx + rdi];\n"
        "cmovs r8, rbp;\n"
        "mov rdi, rbx;\n"
        "test rcx, rdx;\n"
        "cmove r8, rbp;\n"
        "cmove rdi, rbp;\n"
        "sar rcx, 1;\n"
        "xor rdi, r8;\n"
        "xor rsi, r8;\n"
        "bt r8, 0x3f;\n"
        "cmovb rbx, rcx;\n"
        "mov r8, rax;\n"
        "sub rsi, rax;\n"
        "lea rcx, [rcx + rdi];\n"
        "cmovs r8, rbp;\n"
        "mov rdi, rbx;\n"
        "test rcx, rdx;\n"
        "cmove r8, rbp;\n"
        "cmove rdi, rbp;\n"
        "sar rcx, 1;\n"
        "xor rdi, r8;\n"
        "xor rsi, r8;\n"
        "bt r8, 0x3f;\n"
        "cmovb rbx, rcx;\n"
        "mov r8, rax;\n"
        "sub rsi, rax;\n"
        "lea rcx, [rcx + rdi];\n"
        "cmovs r8, rbp;\n"
        "mov rdi, rbx;\n"
        "test rcx, rdx;\n"
        "cmove r8, rbp;\n"
        "cmove rdi, rbp;\n"
        "sar rcx, 1;\n"
        "xor rdi, r8;\n"
        "xor rsi, r8;\n"
        "bt r8, 0x3f;\n"
        "cmovb rbx, rcx;\n"
        "mov r8, rax;\n"
        "sub rsi, rax;\n"
        "lea rcx, [rcx + rdi];\n"
        "cmovs r8, rbp;\n"
        "mov rdi, rbx;\n"
        "test rcx, rdx;\n"
        "cmove r8, rbp;\n"
        "cmove rdi, rbp;\n"
        "sar rcx, 1;\n"
        "xor rdi, r8;\n"
        "xor rsi, r8;\n"
        "bt r8, 0x3f;\n"
        "cmovb rbx, rcx;\n"
        "mov r8, rax;\n"
        "sub rsi, rax;\n"
        "lea rcx, [rcx + rdi];\n"
        "cmovs r8, rbp;\n"
        "mov rdi, rbx;\n"
        "test rcx, rdx;\n"
        "cmove r8, rbp;\n"
        "cmove rdi, rbp;\n"
        "sar rcx, 1;\n"
        "xor rdi, r8;\n"
        "xor rsi, r8;\n"
        "bt r8, 0x3f;\n"
        "cmovb rbx, rcx;\n"
        "mov r8, rax;\n"
        "sub rsi, rax;\n"
        "lea rcx, [rcx + rdi];\n"
        "cmovs r8, rbp;\n"
        "mov rdi, rbx;\n"
        "test rcx, rdx;\n"
        "cmove r8, rbp;\n"
        "cmove rdi, rbp;\n"
        "sar rcx, 1;\n"
        "xor rdi, r8;\n"
        "xor rsi, r8;\n"
        "bt r8, 0x3f;\n"
        "cmovb rbx, rcx;\n"
        "mov r8, rax;\n"
        "sub rsi, rax;\n"
        "lea rcx, [rcx + rdi];\n"
        "cmovs r8, rbp;\n"
        "mov rdi, rbx;\n"
        "test rcx, rdx;\n"
        "cmove r8, rbp;\n"
        "cmove rdi, rbp;\n"
        "sar rcx, 1;\n"
        "xor rdi, r8;\n"
        "xor rsi, r8;\n"
        "bt r8, 0x3f;\n"
        "cmovb rbx, rcx;\n"
        "mov r8, rax;\n"
        "sub rsi, rax;\n"
        "lea rcx, [rcx + rdi];\n"
        "cmovs r8, rbp;\n"
        "mov rdi, rbx;\n"
        "test rcx, rdx;\n"
        "cmove r8, rbp;\n"
        "cmove rdi, rbp;\n"
        "sar rcx, 1;\n"
        "xor rdi, r8;\n"
        "xor rsi, r8;\n"
        "bt r8, 0x3f;\n"
        "cmovb rbx, rcx;\n"
        "mov r8, rax;\n"
        "sub rsi, rax;\n"
        "lea rcx, [rcx + rdi];\n"
        "cmovs r8, rbp;\n"
        "mov rdi, rbx;\n"
        "test rcx, rdx;\n"
        "cmove r8, rbp;\n"
        "cmove rdi, rbp;\n"
        "sar rcx, 1;\n"
        "xor rdi, r8;\n"
        "xor rsi, r8;\n"
        "bt r8, 0x3f;\n"
        "cmovb rbx, rcx;\n"
        "mov r8, rax;\n"
        "sub rsi, rax;\n"
        "lea rcx, [rcx + rdi];\n"
        "cmovs r8, rbp;\n"
        "mov rdi, rbx;\n"
        "test rcx, rdx;\n"
        "cmove r8, rbp;\n"
        "cmove rdi, rbp;\n"
        "sar rcx, 1;\n"
        "xor rdi, r8;\n"
        "xor rsi, r8;\n"
        "bt r8, 0x3f;\n"
        "cmovb rbx, rcx;\n"
        "mov r8, rax;\n"
        "sub rsi, rax;\n"
        "lea rcx, [rcx + rdi];\n"
        "cmovs r8, rbp;\n"
        "mov rdi, rbx;\n"
        "test rcx, rdx;\n"
        "cmove r8, rbp;\n"
        "cmove rdi, rbp;\n"
        "sar rcx, 1;\n"
        "xor rdi, r8;\n"
        "xor rsi, r8;\n"
        "bt r8, 0x3f;\n"
        "cmovb rbx, rcx;\n"
        "mov r8, rax;\n"
        "sub rsi, rax;\n"
        "lea rcx, [rcx + rdi];\n"
        "cmovs r8, rbp;\n"
        "mov rdi, rbx;\n"
        "test rcx, rdx;\n"
        "cmove r8, rbp;\n"
        "cmove rdi, rbp;\n"
        "sar rcx, 1;\n"
        "xor rdi, r8;\n"
        "xor rsi, r8;\n"
        "bt r8, 0x3f;\n"
        "cmovb rbx, rcx;\n"
        "mov r8, rax;\n"
        "sub rsi, rax;\n"
        "lea rcx, [rcx + rdi];\n"
        "cmovs r8, rbp;\n"
        "mov rdi, rbx;\n"
        "test rcx, rdx;\n"
        "cmove r8, rbp;\n"
        "cmove rdi, rbp;\n"
        "sar rcx, 1;\n"
        "xor rdi, r8;\n"
        "xor rsi, r8;\n"
        "bt r8, 0x3f;\n"
        "cmovb rbx, rcx;\n"
        "mov r8, rax;\n"
        "sub rsi, rax;\n"
        "lea rcx, [rcx + rdi];\n"
        "cmovs r8, rbp;\n"
        "mov rdi, rbx;\n"
        "test rcx, rdx;\n"
        "cmove r8, rbp;\n"
        "cmove rdi, rbp;\n"
        "sar rcx, 1;\n"
        "xor rdi, r8;\n"
        "xor rsi, r8;\n"
        "bt r8, 0x3f;\n"
        "cmovb rbx, rcx;\n"
        "mov r8, rax;\n"
        "sub rsi, rax;\n"
        "lea rcx, [rcx + rdi];\n"
        "cmovs r8, rbp;\n"
        "mov rdi, rbx;\n"
        "test rcx, rdx;\n"
        "cmove r8, rbp;\n"
        "cmove rdi, rbp;\n"
        "sar rcx, 1;\n"
        "xor rdi, r8;\n"
        "xor rsi, r8;\n"
        "bt r8, 0x3f;\n"
        "cmovb rbx, rcx;\n"
        "mov r8, rax;\n"
        "sub rsi, rax;\n"
        "lea rcx, [rcx + rdi];\n"
        "cmovs r8, rbp;\n"
        "mov rdi, rbx;\n"
        "test rcx, rdx;\n"
        "cmove r8, rbp;\n"
        "cmove rdi, rbp;\n"
        "sar rcx, 1;\n"
        "xor rdi, r8;\n"
        "xor rsi, r8;\n"
        "bt r8, 0x3f;\n"
        "cmovb rbx, rcx;\n"
        "mov r8, rax;\n"
        "sub rsi, rax;\n"
        "lea rcx, [rcx + rdi];\n"
        "cmovs r8, rbp;\n"
        "mov rdi, rbx;\n"
        "test rcx, rdx;\n"
        "cmove r8, rbp;\n"
        "cmove rdi, rbp;\n"
        "sar rcx, 1;\n"
        "xor rdi, r8;\n"
        "xor rsi, r8;\n"
        "bt r8, 0x3f;\n"
        "cmovb rbx, rcx;\n"
        "mov r8, rax;\n"
        "sub rsi, rax;\n"
        "lea rcx, [rcx + rdi];\n"
        "sar rcx, 1;\n"
        "mov eax, 0x100000;\n"
        "lea rdx, [rbx + rax];\n"
        "lea rdi, [rcx + rax];\n"
        "shl rdx, 0x16;\n"
        "shl rdi, 0x16;\n"
        "sar rdx, 0x2b;\n"
        "sar rdi, 0x2b;\n"
        "movabs rax, 0x20000100000;\n"
        "lea rbx, [rbx + rax];\n"
        "lea rcx, [rcx + rax];\n"
        "sar rbx, 0x2a;\n"
        "sar rcx, 0x2a;\n"
        "mov [rsp + " MAT!() "], rdx;\n"
        "mov [rsp + " MAT!() "+ 0x8], rbx;\n"
        "mov [rsp + " MAT!() "+ 0x10], rdi;\n"
        "mov [rsp + " MAT!() "+ 0x18], rcx;\n"
        "mov r12, " $fin ";\n"
        "imul rdi, r12;\n"
        "imul r12, rdx;\n"
        "mov r13, " $gin ";\n"
        "imul rbx, r13;\n"
        "imul r13, rcx;\n"
        "add r12, rbx;\n"
        "add r13, rdi;\n"
        "sar r12, 0x14;\n"
        "sar r13, 0x14;\n"
        "mov rbx, r12;\n"
        "and rbx, 0xfffff;\n"
        "movabs rax, 0xfffffe0000000000;\n"
        "or rbx, rax;\n"
        "mov rcx, r13;\n"
        "and rcx, 0xfffff;\n"
        "movabs rax, 0xc000000000000000;\n"
        "or rcx, rax;\n"
        "mov rax, 0xfffffffffffffffe;\n"
        "mov edx, 0x2;\n"
        "mov rdi, rbx;\n"
        "mov r8, rax;\n"
        "test rsi, rsi;\n"
        "cmovs r8, rbp;\n"
        "test rcx, 0x1;\n"
        "cmove r8, rbp;\n"
        "cmove rdi, rbp;\n"
        "xor rdi, r8;\n"
        "xor rsi, r8;\n"
        "bt r8, 0x3f;\n"
        "cmovb rbx, rcx;\n"
        "mov r8, rax;\n"
        "sub rsi, rax;\n"
        "lea rcx, [rcx + rdi];\n"
        "cmovs r8, rbp;\n"
        "mov rdi, rbx;\n"
        "test rcx, rdx;\n"
        "cmove r8, rbp;\n"
        "cmove rdi, rbp;\n"
        "sar rcx, 1;\n"
        "xor rdi, r8;\n"
        "xor rsi, r8;\n"
        "bt r8, 0x3f;\n"
        "cmovb rbx, rcx;\n"
        "mov r8, rax;\n"
        "sub rsi, rax;\n"
        "lea rcx, [rcx + rdi];\n"
        "cmovs r8, rbp;\n"
        "mov rdi, rbx;\n"
        "test rcx, rdx;\n"
        "cmove r8, rbp;\n"
        "cmove rdi, rbp;\n"
        "sar rcx, 1;\n"
        "xor rdi, r8;\n"
        "xor rsi, r8;\n"
        "bt r8, 0x3f;\n"
        "cmovb rbx, rcx;\n"
        "mov r8, rax;\n"
        "sub rsi, rax;\n"
        "lea rcx, [rcx + rdi];\n"
        "cmovs r8, rbp;\n"
        "mov rdi, rbx;\n"
        "test rcx, rdx;\n"
        "cmove r8, rbp;\n"
        "cmove rdi, rbp;\n"
        "sar rcx, 1;\n"
        "xor rdi, r8;\n"
        "xor rsi, r8;\n"
        "bt r8, 0x3f;\n"
        "cmovb rbx, rcx;\n"
        "mov r8, rax;\n"
        "sub rsi, rax;\n"
        "lea rcx, [rcx + rdi];\n"
        "cmovs r8, rbp;\n"
        "mov rdi, rbx;\n"
        "test rcx, rdx;\n"
        "cmove r8, rbp;\n"
        "cmove rdi, rbp;\n"
        "sar rcx, 1;\n"
        "xor rdi, r8;\n"
        "xor rsi, r8;\n"
        "bt r8, 0x3f;\n"
        "cmovb rbx, rcx;\n"
        "mov r8, rax;\n"
        "sub rsi, rax;\n"
        "lea rcx, [rcx + rdi];\n"
        "cmovs r8, rbp;\n"
        "mov rdi, rbx;\n"
        "test rcx, rdx;\n"
        "cmove r8, rbp;\n"
        "cmove rdi, rbp;\n"
        "sar rcx, 1;\n"
        "xor rdi, r8;\n"
        "xor rsi, r8;\n"
        "bt r8, 0x3f;\n"
        "cmovb rbx, rcx;\n"
        "mov r8, rax;\n"
        "sub rsi, rax;\n"
        "lea rcx, [rcx + rdi];\n"
        "cmovs r8, rbp;\n"
        "mov rdi, rbx;\n"
        "test rcx, rdx;\n"
        "cmove r8, rbp;\n"
        "cmove rdi, rbp;\n"
        "sar rcx, 1;\n"
        "xor rdi, r8;\n"
        "xor rsi, r8;\n"
        "bt r8, 0x3f;\n"
        "cmovb rbx, rcx;\n"
        "mov r8, rax;\n"
        "sub rsi, rax;\n"
        "lea rcx, [rcx + rdi];\n"
        "cmovs r8, rbp;\n"
        "mov rdi, rbx;\n"
        "test rcx, rdx;\n"
        "cmove r8, rbp;\n"
        "cmove rdi, rbp;\n"
        "sar rcx, 1;\n"
        "xor rdi, r8;\n"
        "xor rsi, r8;\n"
        "bt r8, 0x3f;\n"
        "cmovb rbx, rcx;\n"
        "mov r8, rax;\n"
        "sub rsi, rax;\n"
        "lea rcx, [rcx + rdi];\n"
        "cmovs r8, rbp;\n"
        "mov rdi, rbx;\n"
        "test rcx, rdx;\n"
        "cmove r8, rbp;\n"
        "cmove rdi, rbp;\n"
        "sar rcx, 1;\n"
        "xor rdi, r8;\n"
        "xor rsi, r8;\n"
        "bt r8, 0x3f;\n"
        "cmovb rbx, rcx;\n"
        "mov r8, rax;\n"
        "sub rsi, rax;\n"
        "lea rcx, [rcx + rdi];\n"
        "cmovs r8, rbp;\n"
        "mov rdi, rbx;\n"
        "test rcx, rdx;\n"
        "cmove r8, rbp;\n"
        "cmove rdi, rbp;\n"
        "sar rcx, 1;\n"
        "xor rdi, r8;\n"
        "xor rsi, r8;\n"
        "bt r8, 0x3f;\n"
        "cmovb rbx, rcx;\n"
        "mov r8, rax;\n"
        "sub rsi, rax;\n"
        "lea rcx, [rcx + rdi];\n"
        "cmovs r8, rbp;\n"
        "mov rdi, rbx;\n"
        "test rcx, rdx;\n"
        "cmove r8, rbp;\n"
        "cmove rdi, rbp;\n"
        "sar rcx, 1;\n"
        "xor rdi, r8;\n"
        "xor rsi, r8;\n"
        "bt r8, 0x3f;\n"
        "cmovb rbx, rcx;\n"
        "mov r8, rax;\n"
        "sub rsi, rax;\n"
        "lea rcx, [rcx + rdi];\n"
        "cmovs r8, rbp;\n"
        "mov rdi, rbx;\n"
        "test rcx, rdx;\n"
        "cmove r8, rbp;\n"
        "cmove rdi, rbp;\n"
        "sar rcx, 1;\n"
        "xor rdi, r8;\n"
        "xor rsi, r8;\n"
        "bt r8, 0x3f;\n"
        "cmovb rbx, rcx;\n"
        "mov r8, rax;\n"
        "sub rsi, rax;\n"
        "lea rcx, [rcx + rdi];\n"
        "cmovs r8, rbp;\n"
        "mov rdi, rbx;\n"
        "test rcx, rdx;\n"
        "cmove r8, rbp;\n"
        "cmove rdi, rbp;\n"
        "sar rcx, 1;\n"
        "xor rdi, r8;\n"
        "xor rsi, r8;\n"
        "bt r8, 0x3f;\n"
        "cmovb rbx, rcx;\n"
        "mov r8, rax;\n"
        "sub rsi, rax;\n"
        "lea rcx, [rcx + rdi];\n"
        "cmovs r8, rbp;\n"
        "mov rdi, rbx;\n"
        "test rcx, rdx;\n"
        "cmove r8, rbp;\n"
        "cmove rdi, rbp;\n"
        "sar rcx, 1;\n"
        "xor rdi, r8;\n"
        "xor rsi, r8;\n"
        "bt r8, 0x3f;\n"
        "cmovb rbx, rcx;\n"
        "mov r8, rax;\n"
        "sub rsi, rax;\n"
        "lea rcx, [rcx + rdi];\n"
        "cmovs r8, rbp;\n"
        "mov rdi, rbx;\n"
        "test rcx, rdx;\n"
        "cmove r8, rbp;\n"
        "cmove rdi, rbp;\n"
        "sar rcx, 1;\n"
        "xor rdi, r8;\n"
        "xor rsi, r8;\n"
        "bt r8, 0x3f;\n"
        "cmovb rbx, rcx;\n"
        "mov r8, rax;\n"
        "sub rsi, rax;\n"
        "lea rcx, [rcx + rdi];\n"
        "cmovs r8, rbp;\n"
        "mov rdi, rbx;\n"
        "test rcx, rdx;\n"
        "cmove r8, rbp;\n"
        "cmove rdi, rbp;\n"
        "sar rcx, 1;\n"
        "xor rdi, r8;\n"
        "xor rsi, r8;\n"
        "bt r8, 0x3f;\n"
        "cmovb rbx, rcx;\n"
        "mov r8, rax;\n"
        "sub rsi, rax;\n"
        "lea rcx, [rcx + rdi];\n"
        "cmovs r8, rbp;\n"
        "mov rdi, rbx;\n"
        "test rcx, rdx;\n"
        "cmove r8, rbp;\n"
        "cmove rdi, rbp;\n"
        "sar rcx, 1;\n"
        "xor rdi, r8;\n"
        "xor rsi, r8;\n"
        "bt r8, 0x3f;\n"
        "cmovb rbx, rcx;\n"
        "mov r8, rax;\n"
        "sub rsi, rax;\n"
        "lea rcx, [rcx + rdi];\n"
        "cmovs r8, rbp;\n"
        "mov rdi, rbx;\n"
        "test rcx, rdx;\n"
        "cmove r8, rbp;\n"
        "cmove rdi, rbp;\n"
        "sar rcx, 1;\n"
        "xor rdi, r8;\n"
        "xor rsi, r8;\n"
        "bt r8, 0x3f;\n"
        "cmovb rbx, rcx;\n"
        "mov r8, rax;\n"
        "sub rsi, rax;\n"
        "lea rcx, [rcx + rdi];\n"
        "cmovs r8, rbp;\n"
        "mov rdi, rbx;\n"
        "test rcx, rdx;\n"
        "cmove r8, rbp;\n"
        "cmove rdi, rbp;\n"
        "sar rcx, 1;\n"
        "xor rdi, r8;\n"
        "xor rsi, r8;\n"
        "bt r8, 0x3f;\n"
        "cmovb rbx, rcx;\n"
        "mov r8, rax;\n"
        "sub rsi, rax;\n"
        "lea rcx, [rcx + rdi];\n"
        "cmovs r8, rbp;\n"
        "mov rdi, rbx;\n"
        "test rcx, rdx;\n"
        "cmove r8, rbp;\n"
        "cmove rdi, rbp;\n"
        "sar rcx, 1;\n"
        "xor rdi, r8;\n"
        "xor rsi, r8;\n"
        "bt r8, 0x3f;\n"
        "cmovb rbx, rcx;\n"
        "mov r8, rax;\n"
        "sub rsi, rax;\n"
        "lea rcx, [rcx + rdi];\n"
        "sar rcx, 1;\n"
        "mov eax, 0x100000;\n"
        "lea r8, [rbx + rax];\n"
        "lea r10, [rcx + rax];\n"
        "shl r8, 0x16;\n"
        "shl r10, 0x16;\n"
        "sar r8, 0x2b;\n"
        "sar r10, 0x2b;\n"
        "movabs rax, 0x20000100000;\n"
        "lea r15, [rbx + rax];\n"
        "lea r11, [rcx + rax];\n"
        "sar r15, 0x2a;\n"
        "sar r11, 0x2a;\n"
        "mov rbx, r13;\n"
        "mov rcx, r12;\n"
        "imul r12, r8;\n"
        "imul rbx, r15;\n"
        "add r12, rbx;\n"
        "imul r13, r11;\n"
        "imul rcx, r10;\n"
        "add r13, rcx;\n"
        "sar r12, 0x14;\n"
        "sar r13, 0x14;\n"
        "mov rbx, r12;\n"
        "and rbx, 0xfffff;\n"
        "movabs rax, 0xfffffe0000000000;\n"
        "or rbx, rax;\n"
        "mov rcx, r13;\n"
        "and rcx, 0xfffff;\n"
        "movabs rax, 0xc000000000000000;\n"
        "or rcx, rax;\n"
        "mov rax, [rsp + " MAT!() "];\n"
        "imul rax, r8;\n"
        "mov rdx, [rsp + " MAT!() "+ 0x10];\n"
        "imul rdx, r15;\n"
        "imul r8, [rsp + " MAT!() "+ 0x8];\n"
        "imul r15, [rsp + " MAT!() "+ 0x18];\n"
        "add r15, r8;\n"
        "lea r9, [rax + rdx];\n"
        "mov rax, [rsp + " MAT!() "];\n"
        "imul rax, r10;\n"
        "mov rdx, [rsp + " MAT!() "+ 0x10];\n"
        "imul rdx, r11;\n"
        "imul r10, [rsp + " MAT!() "+ 0x8];\n"
        "imul r11, [rsp + " MAT!() "+ 0x18];\n"
        "add r11, r10;\n"
        "lea r13, [rax + rdx];\n"
        "mov rax, 0xfffffffffffffffe;\n"
        "mov edx, 0x2;\n"
        "mov rdi, rbx;\n"
        "mov r8, rax;\n"
        "test rsi, rsi;\n"
        "cmovs r8, rbp;\n"
        "test rcx, 0x1;\n"
        "cmove r8, rbp;\n"
        "cmove rdi, rbp;\n"
        "xor rdi, r8;\n"
        "xor rsi, r8;\n"
        "bt r8, 0x3f;\n"
        "cmovb rbx, rcx;\n"
        "mov r8, rax;\n"
        "sub rsi, rax;\n"
        "lea rcx, [rcx + rdi];\n"
        "cmovs r8, rbp;\n"
        "mov rdi, rbx;\n"
        "test rcx, rdx;\n"
        "cmove r8, rbp;\n"
        "cmove rdi, rbp;\n"
        "sar rcx, 1;\n"
        "xor rdi, r8;\n"
        "xor rsi, r8;\n"
        "bt r8, 0x3f;\n"
        "cmovb rbx, rcx;\n"
        "mov r8, rax;\n"
        "sub rsi, rax;\n"
        "lea rcx, [rcx + rdi];\n"
        "cmovs r8, rbp;\n"
        "mov rdi, rbx;\n"
        "test rcx, rdx;\n"
        "cmove r8, rbp;\n"
        "cmove rdi, rbp;\n"
        "sar rcx, 1;\n"
        "xor rdi, r8;\n"
        "xor rsi, r8;\n"
        "bt r8, 0x3f;\n"
        "cmovb rbx, rcx;\n"
        "mov r8, rax;\n"
        "sub rsi, rax;\n"
        "lea rcx, [rcx + rdi];\n"
        "cmovs r8, rbp;\n"
        "mov rdi, rbx;\n"
        "test rcx, rdx;\n"
        "cmove r8, rbp;\n"
        "cmove rdi, rbp;\n"
        "sar rcx, 1;\n"
        "xor rdi, r8;\n"
        "xor rsi, r8;\n"
        "bt r8, 0x3f;\n"
        "cmovb rbx, rcx;\n"
        "mov r8, rax;\n"
        "sub rsi, rax;\n"
        "lea rcx, [rcx + rdi];\n"
        "cmovs r8, rbp;\n"
        "mov rdi, rbx;\n"
        "test rcx, rdx;\n"
        "cmove r8, rbp;\n"
        "cmove rdi, rbp;\n"
        "sar rcx, 1;\n"
        "xor rdi, r8;\n"
        "xor rsi, r8;\n"
        "bt r8, 0x3f;\n"
        "cmovb rbx, rcx;\n"
        "mov r8, rax;\n"
        "sub rsi, rax;\n"
        "lea rcx, [rcx + rdi];\n"
        "cmovs r8, rbp;\n"
        "mov rdi, rbx;\n"
        "test rcx, rdx;\n"
        "cmove r8, rbp;\n"
        "cmove rdi, rbp;\n"
        "sar rcx, 1;\n"
        "xor rdi, r8;\n"
        "xor rsi, r8;\n"
        "bt r8, 0x3f;\n"
        "cmovb rbx, rcx;\n"
        "mov r8, rax;\n"
        "sub rsi, rax;\n"
        "lea rcx, [rcx + rdi];\n"
        "cmovs r8, rbp;\n"
        "mov rdi, rbx;\n"
        "test rcx, rdx;\n"
        "cmove r8, rbp;\n"
        "cmove rdi, rbp;\n"
        "sar rcx, 1;\n"
        "xor rdi, r8;\n"
        "xor rsi, r8;\n"
        "bt r8, 0x3f;\n"
        "cmovb rbx, rcx;\n"
        "mov r8, rax;\n"
        "sub rsi, rax;\n"
        "lea rcx, [rcx + rdi];\n"
        "cmovs r8, rbp;\n"
        "mov rdi, rbx;\n"
        "test rcx, rdx;\n"
        "cmove r8, rbp;\n"
        "cmove rdi, rbp;\n"
        "sar rcx, 1;\n"
        "xor rdi, r8;\n"
        "xor rsi, r8;\n"
        "bt r8, 0x3f;\n"
        "cmovb rbx, rcx;\n"
        "mov r8, rax;\n"
        "sub rsi, rax;\n"
        "lea rcx, [rcx + rdi];\n"
        "cmovs r8, rbp;\n"
        "mov rdi, rbx;\n"
        "test rcx, rdx;\n"
        "cmove r8, rbp;\n"
        "cmove rdi, rbp;\n"
        "sar rcx, 1;\n"
        "xor rdi, r8;\n"
        "xor rsi, r8;\n"
        "bt r8, 0x3f;\n"
        "cmovb rbx, rcx;\n"
        "mov r8, rax;\n"
        "sub rsi, rax;\n"
        "lea rcx, [rcx + rdi];\n"
        "cmovs r8, rbp;\n"
        "mov rdi, rbx;\n"
        "test rcx, rdx;\n"
        "cmove r8, rbp;\n"
        "cmove rdi, rbp;\n"
        "sar rcx, 1;\n"
        "xor rdi, r8;\n"
        "xor rsi, r8;\n"
        "bt r8, 0x3f;\n"
        "cmovb rbx, rcx;\n"
        "mov r8, rax;\n"
        "sub rsi, rax;\n"
        "lea rcx, [rcx + rdi];\n"
        "cmovs r8, rbp;\n"
        "mov rdi, rbx;\n"
        "test rcx, rdx;\n"
        "cmove r8, rbp;\n"
        "cmove rdi, rbp;\n"
        "sar rcx, 1;\n"
        "xor rdi, r8;\n"
        "xor rsi, r8;\n"
        "bt r8, 0x3f;\n"
        "cmovb rbx, rcx;\n"
        "mov r8, rax;\n"
        "sub rsi, rax;\n"
        "lea rcx, [rcx + rdi];\n"
        "cmovs r8, rbp;\n"
        "mov rdi, rbx;\n"
        "test rcx, rdx;\n"
        "cmove r8, rbp;\n"
        "cmove rdi, rbp;\n"
        "sar rcx, 1;\n"
        "xor rdi, r8;\n"
        "xor rsi, r8;\n"
        "bt r8, 0x3f;\n"
        "cmovb rbx, rcx;\n"
        "mov r8, rax;\n"
        "sub rsi, rax;\n"
        "lea rcx, [rcx + rdi];\n"
        "cmovs r8, rbp;\n"
        "mov rdi, rbx;\n"
        "test rcx, rdx;\n"
        "cmove r8, rbp;\n"
        "cmove rdi, rbp;\n"
        "sar rcx, 1;\n"
        "xor rdi, r8;\n"
        "xor rsi, r8;\n"
        "bt r8, 0x3f;\n"
        "cmovb rbx, rcx;\n"
        "mov r8, rax;\n"
        "sub rsi, rax;\n"
        "lea rcx, [rcx + rdi];\n"
        "cmovs r8, rbp;\n"
        "mov rdi, rbx;\n"
        "test rcx, rdx;\n"
        "cmove r8, rbp;\n"
        "cmove rdi, rbp;\n"
        "sar rcx, 1;\n"
        "xor rdi, r8;\n"
        "xor rsi, r8;\n"
        "bt r8, 0x3f;\n"
        "cmovb rbx, rcx;\n"
        "mov r8, rax;\n"
        "sub rsi, rax;\n"
        "lea rcx, [rcx + rdi];\n"
        "cmovs r8, rbp;\n"
        "mov rdi, rbx;\n"
        "test rcx, rdx;\n"
        "cmove r8, rbp;\n"
        "cmove rdi, rbp;\n"
        "sar rcx, 1;\n"
        "xor rdi, r8;\n"
        "xor rsi, r8;\n"
        "bt r8, 0x3f;\n"
        "cmovb rbx, rcx;\n"
        "mov r8, rax;\n"
        "sub rsi, rax;\n"
        "lea rcx, [rcx + rdi];\n"
        "cmovs r8, rbp;\n"
        "mov rdi, rbx;\n"
        "test rcx, rdx;\n"
        "cmove r8, rbp;\n"
        "cmove rdi, rbp;\n"
        "sar rcx, 1;\n"
        "xor rdi, r8;\n"
        "xor rsi, r8;\n"
        "bt r8, 0x3f;\n"
        "cmovb rbx, rcx;\n"
        "mov r8, rax;\n"
        "sub rsi, rax;\n"
        "lea rcx, [rcx + rdi];\n"
        "cmovs r8, rbp;\n"
        "mov rdi, rbx;\n"
        "test rcx, rdx;\n"
        "cmove r8, rbp;\n"
        "cmove rdi, rbp;\n"
        "sar rcx, 1;\n"
        "xor rdi, r8;\n"
        "xor rsi, r8;\n"
        "bt r8, 0x3f;\n"
        "cmovb rbx, rcx;\n"
        "mov r8, rax;\n"
        "sub rsi, rax;\n"
        "lea rcx, [rcx + rdi];\n"
        "cmovs r8, rbp;\n"
        "mov rdi, rbx;\n"
        "test rcx, rdx;\n"
        "cmove r8, rbp;\n"
        "cmove rdi, rbp;\n"
        "sar rcx, 1;\n"
        "xor rdi, r8;\n"
        "xor rsi, r8;\n"
        "bt r8, 0x3f;\n"
        "cmovb rbx, rcx;\n"
        "mov r8, rax;\n"
        "sub rsi, rax;\n"
        "lea rcx, [rcx + rdi];\n"
        "cmovs r8, rbp;\n"
        "mov rdi, rbx;\n"
        "test rcx, rdx;\n"
        "cmove r8, rbp;\n"
        "cmove rdi, rbp;\n"
        "sar rcx, 1;\n"
        "xor rdi, r8;\n"
        "xor rsi, r8;\n"
        "bt r8, 0x3f;\n"
        "cmovb rbx, rcx;\n"
        "mov r8, rax;\n"
        "sub rsi, rax;\n"
        "lea rcx, [rcx + rdi];\n"
        "sar rcx, 1;\n"
        "mov eax, 0x100000;\n"
        "lea r8, [rbx + rax];\n"
        "lea r12, [rcx + rax];\n"
        "shl r8, 0x15;\n"
        "shl r12, 0x15;\n"
        "sar r8, 0x2b;\n"
        "sar r12, 0x2b;\n"
        "movabs rax, 0x20000100000;\n"
        "lea r10, [rbx + rax];\n"
        "lea r14, [rcx + rax];\n"
        "sar r10, 0x2b;\n"
        "sar r14, 0x2b;\n"
        "mov rax, r9;\n"
        "imul rax, r8;\n"
        "mov rdx, r13;\n"
        "imul rdx, r10;\n"
        "imul r8, r15;\n"
        "imul r10, r11;\n"
        "add r10, r8;\n"
        "lea r8, [rax + rdx];\n"
        "mov rax, r9;\n"
        "imul rax, r12;\n"
        "mov rdx, r13;\n"
        "imul rdx, r14;\n"
        "imul r12, r15;\n"
        "imul r14, r11;\n"
        "add r14, r12;\n"
        "lea r12, [rax + rdx]"
    )}
}

/// Modular inverse modulo p_25519 = 2^255 - 19
///
/// Input x[4]; output z[4]
///
/// Assuming the 4-digit input x is coprime to p_25519, i.e. is not divisible
/// by it, returns z < p_25519 such that x * z == 1 (mod p_25519). The input
/// x does not need to be reduced modulo p_25519, but the output always is.
#[inline(never)]
pub(crate) fn bignum_inv_p25519(z: &mut [u64; 4], x: &[u64; 4]) {
    // SAFETY: inline assembly. see [crate::low::inline_assembly_safety] for safety info.
    unsafe {
        core::arch::asm!(

        Q!("    endbr64         " ),

        // Save registers and make room for temporaries

        Q!("    push            " "rbx"),
        Q!("    push            " "rbp"),
        Q!("    push            " "r12"),
        Q!("    push            " "r13"),
        Q!("    push            " "r14"),
        Q!("    push            " "r15"),

        Q!("    sub             " "rsp, " NSPACE!()),

        // Save the return pointer for the end so we can overwrite rdi later

        Q!("    mov             " res!() ", rdi"),

        // Copy the input and the prime into the main f and g variables.
        // Make sure x is reduced so that g <= f as assumed in the bound proof.

        Q!("    xor             " "eax, eax"),
        Q!("    lea             " "rcx, [rax -19]"),
        Q!("    not             " "rax"),
        Q!("    mov             " "[rsp + " F!() "], rcx"),
        Q!("    mov             " "[rsp + " F!() "+ 8], rax"),
        Q!("    mov             " "[rsp + " F!() "+ 16], rax"),
        Q!("    btr             " "rax, 63"),
        Q!("    mov             " "[rsp + " F!() "+ 24], rax"),

        Q!("    mov             " "rdx, [rsi]"),
        Q!("    mov             " "rcx, [rsi + 0x8]"),
        Q!("    mov             " "r8, [rsi + 0x10]"),
        Q!("    mov             " "r9, [rsi + 0x18]"),
        Q!("    mov             " "eax, 0x1"),
        Q!("    xor             " "r10d, r10d"),
        Q!("    bts             " "r9, 0x3f"),
        Q!("    adc             " "rax, r10"),
        Q!("    imul            " "rax, rax, 19"),
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
        Q!("    mov             " "[rsp + " G!() "], rdx"),
        Q!("    mov             " "[rsp + " G!() "+ 0x8], rcx"),
        Q!("    mov             " "[rsp + " G!() "+ 0x10], r8"),
        Q!("    mov             " "[rsp + " G!() "+ 0x18], r9"),

        // Also maintain weakly reduced < 2*p_25519 vector [u,v] such that
        // [f,g] == x * 2^{590-59*i} * [u,v] (mod p_25519)
        // starting with [p_25519,x] == x * 2^{590-59*0} * [0,2^-590] (mod p_25519)

        Q!("    xor             " "eax, eax"),
        Q!("    mov             " "[rsp + " U!() "], rax"),
        Q!("    mov             " "[rsp + " U!() "+ 8], rax"),
        Q!("    mov             " "[rsp + " U!() "+ 16], rax"),
        Q!("    mov             " "[rsp + " U!() "+ 24], rax"),

        Q!("    mov             " "rax, 0xa0f99e2375022099"),
        Q!("    mov             " "[rsp + " V!() "], rax"),
        Q!("    mov             " "rax, 0xa8c68f3f1d132595"),
        Q!("    mov             " "[rsp + " V!() "+ 8], rax"),
        Q!("    mov             " "rax, 0x6c6c893805ac5242"),
        Q!("    mov             " "[rsp + " V!() "+ 16], rax"),
        Q!("    mov             " "rax, 0x276508b241770615"),
        Q!("    mov             " "[rsp + " V!() "+ 24], rax"),

        // Start of main loop. We jump into the middle so that the divstep
        // portion is common to the special tenth iteration after a uniform
        // first 9.

        Q!("    mov             " i!() ", 10"),
        Q!("    mov             " d!() ", 1"),
        Q!("    jmp             " Label!("Lbignum_inv_p25519_midloop", 2, After)),

        Q!(Label!("Lbignum_inv_p25519_loop", 3) ":"),

        // Separate out the matrix into sign-magnitude pairs

        Q!("    mov             " "r9, r8"),
        Q!("    sar             " "r9, 63"),
        Q!("    xor             " "r8, r9"),
        Q!("    sub             " "r8, r9"),

        Q!("    mov             " "r11, r10"),
        Q!("    sar             " "r11, 63"),
        Q!("    xor             " "r10, r11"),
        Q!("    sub             " "r10, r11"),

        Q!("    mov             " "r13, r12"),
        Q!("    sar             " "r13, 63"),
        Q!("    xor             " "r12, r13"),
        Q!("    sub             " "r12, r13"),

        Q!("    mov             " "r15, r14"),
        Q!("    sar             " "r15, 63"),
        Q!("    xor             " "r14, r15"),
        Q!("    sub             " "r14, r15"),

        // Adjust the initial values to allow for complement instead of negation
        // This initial offset is the same for [f,g] and [u,v] compositions.
        // Save it in temporary storage for the [u,v] part and do [f,g] first.

        Q!("    mov             " "rax, r8"),
        Q!("    and             " "rax, r9"),
        Q!("    mov             " "rdi, r10"),
        Q!("    and             " "rdi, r11"),
        Q!("    add             " "rdi, rax"),
        Q!("    mov             " tmp!() ", rdi"),

        Q!("    mov             " "rax, r12"),
        Q!("    and             " "rax, r13"),
        Q!("    mov             " "rsi, r14"),
        Q!("    and             " "rsi, r15"),
        Q!("    add             " "rsi, rax"),
        Q!("    mov             " tmp2!() ", rsi"),

        // Now the computation of the updated f and g values. This maintains a
        // 2-word carry between stages so we can conveniently insert the shift
        // right by 59 before storing back, and not overwrite digits we need
        // again of the old f and g values.
        //
        // Digit 0 of [f,g]

        Q!("    xor             " "ebx, ebx"),
        Q!("    mov             " "rax, [rsp + " F!() "]"),
        Q!("    xor             " "rax, r9"),
        Q!("    mul             " "r8"),
        Q!("    add             " "rdi, rax"),
        Q!("    adc             " "rbx, rdx"),
        Q!("    mov             " "rax, [rsp + " G!() "]"),
        Q!("    xor             " "rax, r11"),
        Q!("    mul             " "r10"),
        Q!("    add             " "rdi, rax"),
        Q!("    adc             " "rbx, rdx"),

        Q!("    xor             " "ebp, ebp"),
        Q!("    mov             " "rax, [rsp + " F!() "]"),
        Q!("    xor             " "rax, r13"),
        Q!("    mul             " "r12"),
        Q!("    add             " "rsi, rax"),
        Q!("    adc             " "rbp, rdx"),
        Q!("    mov             " "rax, [rsp + " G!() "]"),
        Q!("    xor             " "rax, r15"),
        Q!("    mul             " "r14"),
        Q!("    add             " "rsi, rax"),
        Q!("    adc             " "rbp, rdx"),

        // Digit 1 of [f,g]

        Q!("    xor             " "ecx, ecx"),
        Q!("    mov             " "rax, [rsp + " F!() "+ " N!() "]"),
        Q!("    xor             " "rax, r9"),
        Q!("    mul             " "r8"),
        Q!("    add             " "rbx, rax"),
        Q!("    adc             " "rcx, rdx"),
        Q!("    mov             " "rax, [rsp + " G!() "+ " N!() "]"),
        Q!("    xor             " "rax, r11"),
        Q!("    mul             " "r10"),
        Q!("    add             " "rbx, rax"),
        Q!("    adc             " "rcx, rdx"),
        Q!("    shrd            " "rdi, rbx, 59"),
        Q!("    mov             " "[rsp + " F!() "], rdi"),

        Q!("    xor             " "edi, edi"),
        Q!("    mov             " "rax, [rsp + " F!() "+ " N!() "]"),
        Q!("    xor             " "rax, r13"),
        Q!("    mul             " "r12"),
        Q!("    add             " "rbp, rax"),
        Q!("    adc             " "rdi, rdx"),
        Q!("    mov             " "rax, [rsp + " G!() "+ " N!() "]"),
        Q!("    xor             " "rax, r15"),
        Q!("    mul             " "r14"),
        Q!("    add             " "rbp, rax"),
        Q!("    adc             " "rdi, rdx"),
        Q!("    shrd            " "rsi, rbp, 59"),
        Q!("    mov             " "[rsp + " G!() "], rsi"),

        // Digit 2 of [f,g]

        Q!("    xor             " "esi, esi"),
        Q!("    mov             " "rax, [rsp + " F!() "+ 2 * " N!() "]"),
        Q!("    xor             " "rax, r9"),
        Q!("    mul             " "r8"),
        Q!("    add             " "rcx, rax"),
        Q!("    adc             " "rsi, rdx"),
        Q!("    mov             " "rax, [rsp + " G!() "+ 2 * " N!() "]"),
        Q!("    xor             " "rax, r11"),
        Q!("    mul             " "r10"),
        Q!("    add             " "rcx, rax"),
        Q!("    adc             " "rsi, rdx"),
        Q!("    shrd            " "rbx, rcx, 59"),
        Q!("    mov             " "[rsp + " F!() "+ " N!() "], rbx"),

        Q!("    xor             " "ebx, ebx"),
        Q!("    mov             " "rax, [rsp + " F!() "+ 2 * " N!() "]"),
        Q!("    xor             " "rax, r13"),
        Q!("    mul             " "r12"),
        Q!("    add             " "rdi, rax"),
        Q!("    adc             " "rbx, rdx"),
        Q!("    mov             " "rax, [rsp + " G!() "+ 2 * " N!() "]"),
        Q!("    xor             " "rax, r15"),
        Q!("    mul             " "r14"),
        Q!("    add             " "rdi, rax"),
        Q!("    adc             " "rbx, rdx"),
        Q!("    shrd            " "rbp, rdi, 59"),
        Q!("    mov             " "[rsp + " G!() "+ " N!() "], rbp"),

        // Digits 3 and 4 of [f,g]

        Q!("    mov             " "rax, [rsp + " F!() "+ 3 * " N!() "]"),
        Q!("    xor             " "rax, r9"),
        Q!("    mov             " "rbp, rax"),
        Q!("    sar             " "rbp, 63"),
        Q!("    and             " "rbp, r8"),
        Q!("    neg             " "rbp"),
        Q!("    mul             " "r8"),
        Q!("    add             " "rsi, rax"),
        Q!("    adc             " "rbp, rdx"),
        Q!("    mov             " "rax, [rsp + " G!() "+ 3 * " N!() "]"),
        Q!("    xor             " "rax, r11"),
        Q!("    mov             " "rdx, rax"),
        Q!("    sar             " "rdx, 63"),
        Q!("    and             " "rdx, r10"),
        Q!("    sub             " "rbp, rdx"),
        Q!("    mul             " "r10"),
        Q!("    add             " "rsi, rax"),
        Q!("    adc             " "rbp, rdx"),
        Q!("    shrd            " "rcx, rsi, 59"),
        Q!("    mov             " "[rsp + " F!() "+ 2 * " N!() "], rcx"),
        Q!("    shrd            " "rsi, rbp, 59"),

        Q!("    mov             " "rax, [rsp + " F!() "+ 3 * " N!() "]"),
        Q!("    mov             " "[rsp + " F!() "+ 3 * " N!() "], rsi"),

        Q!("    xor             " "rax, r13"),
        Q!("    mov             " "rsi, rax"),
        Q!("    sar             " "rsi, 63"),
        Q!("    and             " "rsi, r12"),
        Q!("    neg             " "rsi"),
        Q!("    mul             " "r12"),
        Q!("    add             " "rbx, rax"),
        Q!("    adc             " "rsi, rdx"),
        Q!("    mov             " "rax, [rsp + " G!() "+ 3 * " N!() "]"),
        Q!("    xor             " "rax, r15"),
        Q!("    mov             " "rdx, rax"),
        Q!("    sar             " "rdx, 63"),
        Q!("    and             " "rdx, r14"),
        Q!("    sub             " "rsi, rdx"),
        Q!("    mul             " "r14"),
        Q!("    add             " "rbx, rax"),
        Q!("    adc             " "rsi, rdx"),
        Q!("    shrd            " "rdi, rbx, 59"),
        Q!("    mov             " "[rsp + " G!() "+ 2 * " N!() "], rdi"),
        Q!("    shrd            " "rbx, rsi, 59"),
        Q!("    mov             " "[rsp + " G!() "+ 3 * " N!() "], rbx"),

        // Get the initial carries back from storage and do the [u,v] accumulation

        Q!("    mov             " "rbx, " tmp!()),
        Q!("    mov             " "rbp, " tmp2!()),

        // Digit 0 of [u,v]

        Q!("    xor             " "ecx, ecx"),
        Q!("    mov             " "rax, [rsp + " U!() "]"),
        Q!("    xor             " "rax, r9"),
        Q!("    mul             " "r8"),
        Q!("    add             " "rbx, rax"),
        Q!("    adc             " "rcx, rdx"),
        Q!("    mov             " "rax, [rsp + " V!() "]"),
        Q!("    xor             " "rax, r11"),
        Q!("    mul             " "r10"),
        Q!("    add             " "rbx, rax"),
        Q!("    adc             " "rcx, rdx"),

        Q!("    xor             " "esi, esi"),
        Q!("    mov             " "rax, [rsp + " U!() "]"),
        Q!("    xor             " "rax, r13"),
        Q!("    mul             " "r12"),
        Q!("    mov             " "[rsp + " U!() "], rbx"),
        Q!("    add             " "rbp, rax"),
        Q!("    adc             " "rsi, rdx"),
        Q!("    mov             " "rax, [rsp + " V!() "]"),
        Q!("    xor             " "rax, r15"),
        Q!("    mul             " "r14"),
        Q!("    add             " "rbp, rax"),
        Q!("    adc             " "rsi, rdx"),
        Q!("    mov             " "[rsp + " V!() "], rbp"),

        // Digit 1 of [u,v]

        Q!("    xor             " "ebx, ebx"),
        Q!("    mov             " "rax, [rsp + " U!() "+ " N!() "]"),
        Q!("    xor             " "rax, r9"),
        Q!("    mul             " "r8"),
        Q!("    add             " "rcx, rax"),
        Q!("    adc             " "rbx, rdx"),
        Q!("    mov             " "rax, [rsp + " V!() "+ " N!() "]"),
        Q!("    xor             " "rax, r11"),
        Q!("    mul             " "r10"),
        Q!("    add             " "rcx, rax"),
        Q!("    adc             " "rbx, rdx"),

        Q!("    xor             " "ebp, ebp"),
        Q!("    mov             " "rax, [rsp + " U!() "+ " N!() "]"),
        Q!("    xor             " "rax, r13"),
        Q!("    mul             " "r12"),
        Q!("    mov             " "[rsp + " U!() "+ " N!() "], rcx"),
        Q!("    add             " "rsi, rax"),
        Q!("    adc             " "rbp, rdx"),
        Q!("    mov             " "rax, [rsp + " V!() "+ " N!() "]"),
        Q!("    xor             " "rax, r15"),
        Q!("    mul             " "r14"),
        Q!("    add             " "rsi, rax"),
        Q!("    adc             " "rbp, rdx"),
        Q!("    mov             " "[rsp + " V!() "+ " N!() "], rsi"),

        // Digit 2 of [u,v]

        Q!("    xor             " "ecx, ecx"),
        Q!("    mov             " "rax, [rsp + " U!() "+ 2 * " N!() "]"),
        Q!("    xor             " "rax, r9"),
        Q!("    mul             " "r8"),
        Q!("    add             " "rbx, rax"),
        Q!("    adc             " "rcx, rdx"),
        Q!("    mov             " "rax, [rsp + " V!() "+ 2 * " N!() "]"),
        Q!("    xor             " "rax, r11"),
        Q!("    mul             " "r10"),
        Q!("    add             " "rbx, rax"),
        Q!("    adc             " "rcx, rdx"),

        Q!("    xor             " "esi, esi"),
        Q!("    mov             " "rax, [rsp + " U!() "+ 2 * " N!() "]"),
        Q!("    xor             " "rax, r13"),
        Q!("    mul             " "r12"),
        Q!("    mov             " "[rsp + " U!() "+ 2 * " N!() "], rbx"),
        Q!("    add             " "rbp, rax"),
        Q!("    adc             " "rsi, rdx"),
        Q!("    mov             " "rax, [rsp + " V!() "+ 2 * " N!() "]"),
        Q!("    xor             " "rax, r15"),
        Q!("    mul             " "r14"),
        Q!("    add             " "rbp, rax"),
        Q!("    adc             " "rsi, rdx"),
        Q!("    mov             " "[rsp + " V!() "+ 2 * " N!() "], rbp"),

        // Digits 3 and 4 of u (top is unsigned)

        Q!("    mov             " "rax, [rsp + " U!() "+ 3 * " N!() "]"),
        Q!("    xor             " "rax, r9"),
        Q!("    mov             " "rbx, r9"),
        Q!("    and             " "rbx, r8"),
        Q!("    neg             " "rbx"),
        Q!("    mul             " "r8"),
        Q!("    add             " "rcx, rax"),
        Q!("    adc             " "rbx, rdx"),
        Q!("    mov             " "rax, [rsp + " V!() "+ 3 * " N!() "]"),
        Q!("    xor             " "rax, r11"),
        Q!("    mov             " "rdx, r11"),
        Q!("    and             " "rdx, r10"),
        Q!("    sub             " "rbx, rdx"),
        Q!("    mul             " "r10"),
        Q!("    add             " "rcx, rax"),
        Q!("    adc             " "rdx, rbx"),

        // Modular reduction of u

        Q!("    mov             " "rbx, rdx"),
        Q!("    shld            " "rdx, rcx, 1"),
        Q!("    sar             " "rbx, 63"),
        Q!("    add             " "rdx, rbx"),
        Q!("    mov             " "eax, 19"),
        Q!("    imul            " "rdx"),
        Q!("    mov             " "r8, [rsp + " U!() "]"),
        Q!("    add             " "r8, rax"),
        Q!("    mov             " "[rsp + " U!() "], r8"),
        Q!("    mov             " "r8, [rsp + " U!() "+ " N!() "]"),
        Q!("    adc             " "r8, rdx"),
        Q!("    mov             " "[rsp + " U!() "+ " N!() "], r8"),
        Q!("    mov             " "r8, [rsp + " U!() "+ 2 * " N!() "]"),
        Q!("    adc             " "r8, rbx"),
        Q!("    mov             " "[rsp + " U!() "+ 2 * " N!() "], r8"),
        Q!("    adc             " "rcx, rbx"),
        Q!("    shl             " "rax, 63"),
        Q!("    add             " "rcx, rax"),

        // Preload for last use of old u digit 3

        Q!("    mov             " "rax, [rsp + " U!() "+ 3 * " N!() "]"),
        Q!("    mov             " "[rsp + " U!() "+ 3 * " N!() "], rcx"),

        // Digits 3 and 4 of v (top is unsigned)

        Q!("    xor             " "rax, r13"),
        Q!("    mov             " "rcx, r13"),
        Q!("    and             " "rcx, r12"),
        Q!("    neg             " "rcx"),
        Q!("    mul             " "r12"),
        Q!("    add             " "rsi, rax"),
        Q!("    adc             " "rcx, rdx"),
        Q!("    mov             " "rax, [rsp + " V!() "+ 3 * " N!() "]"),
        Q!("    xor             " "rax, r15"),
        Q!("    mov             " "rdx, r15"),
        Q!("    and             " "rdx, r14"),
        Q!("    sub             " "rcx, rdx"),
        Q!("    mul             " "r14"),
        Q!("    add             " "rsi, rax"),
        Q!("    adc             " "rdx, rcx"),

        // Modular reduction of v

        Q!("    mov             " "rcx, rdx"),
        Q!("    shld            " "rdx, rsi, 1"),
        Q!("    sar             " "rcx, 63"),
        Q!("    mov             " "eax, 19"),
        Q!("    add             " "rdx, rcx"),
        Q!("    imul            " "rdx"),
        Q!("    mov             " "r8, [rsp + " V!() "]"),
        Q!("    add             " "r8, rax"),
        Q!("    mov             " "[rsp + " V!() "], r8"),
        Q!("    mov             " "r8, [rsp + " V!() "+ " N!() "]"),
        Q!("    adc             " "r8, rdx"),
        Q!("    mov             " "[rsp + " V!() "+ " N!() "], r8"),
        Q!("    mov             " "r8, [rsp + " V!() "+ 2 * " N!() "]"),
        Q!("    adc             " "r8, rcx"),
        Q!("    mov             " "[rsp + " V!() "+ 2 * " N!() "], r8"),
        Q!("    adc             " "rsi, rcx"),
        Q!("    shl             " "rax, 63"),
        Q!("    add             " "rsi, rax"),
        Q!("    mov             " "[rsp + " V!() "+ 3 * " N!() "], rsi"),

        Q!(Label!("Lbignum_inv_p25519_midloop", 2) ":"),

        divstep59!(d!(), ff!(), gg!()),
        Q!("    mov             " d!() ", rsi"),

        // Next iteration

        Q!("    dec             " i!()),
        Q!("    jnz             " Label!("Lbignum_inv_p25519_loop", 3, Before)),

        // The 10th and last iteration does not need anything except the
        // u value and the sign of f; the latter can be obtained from the
        // lowest word of f. So it's done differently from the main loop.
        // Find the sign of the new f. For this we just need one digit
        // since we know (for in-scope cases) that f is either +1 or -1.
        // We don't explicitly shift right by 59 either, but looking at
        // bit 63 (or any bit >= 60) of the unshifted result is enough
        // to distinguish -1 from +1; this is then made into a mask.

        Q!("    mov             " "rax, [rsp + " F!() "]"),
        Q!("    mov             " "rcx, [rsp + " G!() "]"),
        Q!("    imul            " "rax, r8"),
        Q!("    imul            " "rcx, r10"),
        Q!("    add             " "rax, rcx"),
        Q!("    sar             " "rax, 63"),

        // Now separate out the matrix into sign-magnitude pairs
        // and adjust each one based on the sign of f.
        //
        // Note that at this point we expect |f|=1 and we got its
        // sign above, so then since [f,0] == x * [u,v] (mod p_25519)
        // we want to flip the sign of u according to that of f.

        Q!("    mov             " "r9, r8"),
        Q!("    sar             " "r9, 63"),
        Q!("    xor             " "r8, r9"),
        Q!("    sub             " "r8, r9"),
        Q!("    xor             " "r9, rax"),

        Q!("    mov             " "r11, r10"),
        Q!("    sar             " "r11, 63"),
        Q!("    xor             " "r10, r11"),
        Q!("    sub             " "r10, r11"),
        Q!("    xor             " "r11, rax"),

        Q!("    mov             " "r13, r12"),
        Q!("    sar             " "r13, 63"),
        Q!("    xor             " "r12, r13"),
        Q!("    sub             " "r12, r13"),
        Q!("    xor             " "r13, rax"),

        Q!("    mov             " "r15, r14"),
        Q!("    sar             " "r15, 63"),
        Q!("    xor             " "r14, r15"),
        Q!("    sub             " "r14, r15"),
        Q!("    xor             " "r15, rax"),

        // Adjust the initial value to allow for complement instead of negation

        Q!("    mov             " "rax, r8"),
        Q!("    and             " "rax, r9"),
        Q!("    mov             " "r12, r10"),
        Q!("    and             " "r12, r11"),
        Q!("    add             " "r12, rax"),

        // Digit 0 of [u]

        Q!("    xor             " "r13d, r13d"),
        Q!("    mov             " "rax, [rsp + " U!() "]"),
        Q!("    xor             " "rax, r9"),
        Q!("    mul             " "r8"),
        Q!("    add             " "r12, rax"),
        Q!("    adc             " "r13, rdx"),
        Q!("    mov             " "rax, [rsp + " V!() "]"),
        Q!("    xor             " "rax, r11"),
        Q!("    mul             " "r10"),
        Q!("    add             " "r12, rax"),
        Q!("    adc             " "r13, rdx"),

        // Digit 1 of [u]

        Q!("    xor             " "r14d, r14d"),
        Q!("    mov             " "rax, [rsp + " U!() "+ " N!() "]"),
        Q!("    xor             " "rax, r9"),
        Q!("    mul             " "r8"),
        Q!("    add             " "r13, rax"),
        Q!("    adc             " "r14, rdx"),
        Q!("    mov             " "rax, [rsp + " V!() "+ " N!() "]"),
        Q!("    xor             " "rax, r11"),
        Q!("    mul             " "r10"),
        Q!("    add             " "r13, rax"),
        Q!("    adc             " "r14, rdx"),

        // Digit 2 of [u]

        Q!("    xor             " "r15d, r15d"),
        Q!("    mov             " "rax, [rsp + " U!() "+ 2 * " N!() "]"),
        Q!("    xor             " "rax, r9"),
        Q!("    mul             " "r8"),
        Q!("    add             " "r14, rax"),
        Q!("    adc             " "r15, rdx"),
        Q!("    mov             " "rax, [rsp + " V!() "+ 2 * " N!() "]"),
        Q!("    xor             " "rax, r11"),
        Q!("    mul             " "r10"),
        Q!("    add             " "r14, rax"),
        Q!("    adc             " "r15, rdx"),

        // Digits 3 and 4 of u (top is unsigned)

        Q!("    mov             " "rax, [rsp + " U!() "+ 3 * " N!() "]"),
        Q!("    xor             " "rax, r9"),
        Q!("    and             " "r9, r8"),
        Q!("    neg             " "r9"),
        Q!("    mul             " "r8"),
        Q!("    add             " "r15, rax"),
        Q!("    adc             " "r9, rdx"),
        Q!("    mov             " "rax, [rsp + " V!() "+ 3 * " N!() "]"),
        Q!("    xor             " "rax, r11"),
        Q!("    mov             " "rdx, r11"),
        Q!("    and             " "rdx, r10"),
        Q!("    sub             " "r9, rdx"),
        Q!("    mul             " "r10"),
        Q!("    add             " "r15, rax"),
        Q!("    adc             " "r9, rdx"),

        // Modular reduction of u, this time strictly 2^255-19.

        Q!("    mov             " "rax, r9"),
        Q!("    shld            " "rax, r15, 1"),
        Q!("    sar             " "r9, 63"),
        Q!("    mov             " "ebx, 19"),
        Q!("    lea             " "rax, [rax + r9 + 1]"),
        Q!("    imul            " "rbx"),
        Q!("    xor             " "ebp, ebp"),
        Q!("    add             " "r12, rax"),
        Q!("    adc             " "r13, rdx"),
        Q!("    adc             " "r14, r9"),
        Q!("    adc             " "r15, r9"),
        Q!("    shl             " "rax, 63"),
        Q!("    add             " "r15, rax"),
        Q!("    cmovns          " "rbx, rbp"),
        Q!("    sub             " "r12, rbx"),
        Q!("    sbb             " "r13, rbp"),
        Q!("    sbb             " "r14, rbp"),
        Q!("    sbb             " "r15, rbp"),
        Q!("    btr             " "r15, 0x3f"),

        // Store it back to the final output

        Q!("    mov             " "rdi, " res!()),
        Q!("    mov             " "[rdi], r12"),
        Q!("    mov             " "[rdi + " N!() "], r13"),
        Q!("    mov             " "[rdi + 2 * " N!() "], r14"),
        Q!("    mov             " "[rdi + 3 * " N!() "], r15"),

        // Restore stack and registers

        Q!("    add             " "rsp, " NSPACE!()),

        Q!("    pop             " "r15"),
        Q!("    pop             " "r14"),
        Q!("    pop             " "r13"),
        Q!("    pop             " "r12"),
        Q!("    pop             " "rbp"),
        Q!("    pop             " "rbx"),

        inout("rdi") z.as_mut_ptr() => _,
        inout("rsi") x.as_ptr() => _,
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

#[cfg(test)]
#[cfg_attr(coverage_nightly, coverage(off))]
#[test]
fn abi() {
    crate::low::abi::call!(bignum_inv_p25519, &mut [0; 4], &[0; 4]);
}
