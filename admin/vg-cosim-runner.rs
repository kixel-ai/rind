//! Runs each instruction of pyca/verified-garbage's (VG's) code on this CPU from
//! the start states `vg-cosim` (`proofs/verified-garbage/Cosim/`) writes, and
//! compares the state it leaves with the one VG's model says it does.
//!
//! `vg-cosim-runner --features` prints the CPU features this CPU has, by their
//! Rust `target_feature` names, comma-separated. `vg-cosim-runner` reads the
//! stream of cases from stdin and fails if any case differs, printing each.
//!
//! The instruction's machine code runs at a fixed address, `INSN`, in a page of
//! its own, between a prologue that loads every register the model has from
//! `IN`, and an epilogue that stores them to `OUT`, both in `global_asm!`
//! below. A branch case's target and a call's `ret` are at `TARGET`. The data
//! the model may access is a page at `DATA`, which the case gives in full and
//! is compared in full.

use std::io::{BufReader, Read, Write};

const CODE: usize = 0x10_0000_0000;
const INSN: usize = CODE + 0x1000;
const TARGET: usize = INSN + 0x100;
const DATA: usize = 0x20_0000_0000;
const DATA_LEN: usize = 2048;

unsafe extern "C" {
    fn mmap(addr: *mut u8, len: usize, prot: i32, flags: i32, fd: i32, off: i64) -> *mut u8;
    fn signal(sig: i32, handler: usize) -> usize;
    fn write(fd: i32, buf: *const u8, len: usize) -> isize;
    fn _exit(code: i32) -> !;
}

const PROT_RWX: i32 = 7;
const PROT_RW: i32 = 3;
const MAP_PRIVATE_ANON_FIXED_NOREPLACE: i32 = 0x02 | 0x20 | 0x100000;

/// The text of the block running, for a fault to print.
static mut RUNNING: [u8; 512] = [0; 512];
static mut RUNNING_LEN: usize = 0;

extern "C" fn fault(sig: i32) {
    let msg = b"vg-cosim-runner: the CPU faulted (signal ";
    let digits = [b'0' + (sig / 10) as u8, b'0' + (sig % 10) as u8, b')', b' ', b'i', b'n', b' '];
    // SAFETY: `RUNNING` is only written between cases, and this exits.
    unsafe {
        write(2, msg.as_ptr(), msg.len());
        write(2, digits.as_ptr(), digits.len());
        write(2, (&raw const RUNNING).cast(), RUNNING_LEN);
        write(2, b"\n".as_ptr(), 1);
        _exit(1);
    }
}

fn map(addr: usize, len: usize, prot: i32) {
    // SAFETY: a fixed mapping at an address nothing else uses, which
    // `MAP_FIXED_NOREPLACE` refuses rather than replaces.
    let p = unsafe { mmap(addr as *mut u8, len, prot, MAP_PRIVATE_ANON_FIXED_NOREPLACE, -1, 0) };
    assert_eq!(p as usize, addr, "vg-cosim-runner: cannot map {addr:#x}");
}

fn read_u8(r: &mut impl Read) -> u8 {
    let mut b = [0; 1];
    r.read_exact(&mut b).expect("vg-cosim-runner: truncated stream");
    b[0]
}

fn read_u16(r: &mut impl Read) -> usize {
    let mut b = [0; 2];
    r.read_exact(&mut b).expect("vg-cosim-runner: truncated stream");
    u16::from_le_bytes(b) as usize
}

fn read_u32(r: &mut impl Read) -> usize {
    let mut b = [0; 4];
    r.read_exact(&mut b).expect("vg-cosim-runner: truncated stream");
    u32::from_le_bytes(b) as usize
}

fn read_vec(r: &mut impl Read, n: usize) -> Vec<u8> {
    let mut v = vec![0; n];
    r.read_exact(&mut v).expect("vg-cosim-runner: truncated stream");
    v
}

/// A block's kind: falls through, a branch reporting whether it is taken, or a
/// call that returns.
const INSN_KIND: u8 = 0;
const BRANCH_KIND: u8 = 1;
const CALL_KIND: u8 = 2;

fn hex(b: &[u8]) -> String {
    b.iter().map(|x| format!("{x:02x}")).collect()
}

#[cfg(target_arch = "x86_64")]
mod arch {
    //! x86-64: `rax`–`r15` in the model's order (`rax rcx rdx rbx rsp rbp rsi
    //! rdi r8`–`r15`, the encoding's), CF, ZF, SF and OF in a word, MXCSR, and
    //! `zmm0`–`zmm31`, or as much of them as the CPU has.

    pub const ARCH: u8 = 0;
    pub const REGS_LEN: usize = 16 * 8 + 4 + 4 + 32 * 64;
    const FLAGS: usize = 128;
    const MXCSR: usize = 132;
    const VEC: usize = 136;

    #[repr(C, align(64))]
    pub struct Regs(pub [u8; REGS_LEN]);

    #[unsafe(no_mangle)]
    pub static mut VG_IN: Regs = Regs([0; REGS_LEN]);
    #[unsafe(no_mangle)]
    pub static mut VG_OUT: Regs = Regs([0; REGS_LEN]);
    /// RFLAGS to load: CF, ZF, SF and OF from `VG_IN`, at bits 0, 6, 7 and 11,
    /// with bit 1, which is always set.
    #[unsafe(no_mangle)]
    pub static mut VG_RFLAGS: u64 = 0;
    /// What `lahf` and `seto` leave in `ax` at the end.
    #[unsafe(no_mangle)]
    pub static mut VG_AX: u64 = 0;
    #[unsafe(no_mangle)]
    pub static mut VG_MARKER: u64 = 0;
    #[unsafe(no_mangle)]
    pub static mut VG_HOST_RSP: u64 = 0;
    #[unsafe(no_mangle)]
    pub static mut VG_HOST_MXCSR: u32 = 0;
    #[unsafe(no_mangle)]
    pub static mut VG_INSN_PTR: u64 = super::INSN as u64;

    // Each variant loads and stores the vector registers the CPU has: with
    // AVX-512 all 512 bits of 32, with AVX 256 of 16, else 128 of 16. The
    // registers but `rax` load from `VG_IN` with `rax` as base, then `rsp`,
    // then `rax` itself; RFLAGS by `popfq` while `rsp` is still the host's.
    // Nothing after `popfq` changes the flags.
    macro_rules! trampoline {
        ($enter:literal, $leave0:literal, $leave1:literal, $load:literal, $store:literal) => {
            core::arch::global_asm!(
                concat!(".globl ", $enter),
                concat!($enter, ":"),
                "push rbx", "push rbp", "push r12", "push r13", "push r14", "push r15",
                "sub rsp, 8",
                "stmxcsr [rip + VG_HOST_MXCSR]",
                "mov [rip + VG_HOST_RSP], rsp",
                "lea rax, [rip + VG_IN]",
                $load,
                "ldmxcsr [rax + 132]",
                "push qword ptr [rip + VG_RFLAGS]",
                "popfq",
                "mov rcx, [rax + 8]", "mov rdx, [rax + 16]", "mov rbx, [rax + 24]",
                "mov rbp, [rax + 40]", "mov rsi, [rax + 48]", "mov rdi, [rax + 56]",
                "mov r8, [rax + 64]", "mov r9, [rax + 72]", "mov r10, [rax + 80]", "mov r11, [rax + 88]",
                "mov r12, [rax + 96]", "mov r13, [rax + 104]", "mov r14, [rax + 112]", "mov r15, [rax + 120]",
                "mov rsp, [rax + 32]",
                "mov rax, [rax]",
                "jmp qword ptr [rip + VG_INSN_PTR]",
                // Fallthrough, or a branch not taken.
                concat!(".globl ", $leave0),
                concat!($leave0, ":"),
                "mov [rip + VG_OUT], rax",
                "mov rax, 0",
                "mov [rip + VG_MARKER], rax",
                concat!("jmp 2f"),
                concat!(".globl ", $leave1),
                concat!($leave1, ":"),
                "mov [rip + VG_OUT], rax",
                "mov rax, 1",
                "mov [rip + VG_MARKER], rax",
                "2:",
                "lahf",
                "seto al",
                "mov [rip + VG_AX], rax",
                "lea rax, [rip + VG_OUT]",
                "mov [rax + 8], rcx", "mov [rax + 16], rdx", "mov [rax + 24], rbx", "mov [rax + 32], rsp",
                "mov [rax + 40], rbp", "mov [rax + 48], rsi", "mov [rax + 56], rdi",
                "mov [rax + 64], r8", "mov [rax + 72], r9", "mov [rax + 80], r10", "mov [rax + 88], r11",
                "mov [rax + 96], r12", "mov [rax + 104], r13", "mov [rax + 112], r14", "mov [rax + 120], r15",
                "stmxcsr [rax + 132]",
                $store,
                "mov rsp, [rip + VG_HOST_RSP]",
                "ldmxcsr [rip + VG_HOST_MXCSR]",
                "add rsp, 8",
                "pop r15", "pop r14", "pop r13", "pop r12", "pop rbp", "pop rbx",
                "ret",
            );
        };
    }

    // `.irp` repeats its body for each register, `\i` its number.
    trampoline!("vg_enter_zmm", "vg_leave0_zmm", "vg_leave1_zmm",
        ".irp i, 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31\nvmovdqu64 zmm\\i, [rax + 136 + \\i * 64]\n.endr",
        ".irp i, 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31\nvmovdqu64 [rax + 136 + \\i * 64], zmm\\i\n.endr");
    trampoline!("vg_enter_ymm", "vg_leave0_ymm", "vg_leave1_ymm",
        ".irp i, 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15\nvmovdqu ymm\\i, [rax + 136 + \\i * 64]\n.endr",
        ".irp i, 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15\nvmovdqu [rax + 136 + \\i * 64], ymm\\i\n.endr");
    trampoline!("vg_enter_xmm", "vg_leave0_xmm", "vg_leave1_xmm",
        ".irp i, 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15\nmovdqu xmm\\i, [rax + 136 + \\i * 64]\n.endr",
        ".irp i, 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15\nmovdqu [rax + 136 + \\i * 64], xmm\\i\n.endr");

    unsafe extern "C" {
        fn vg_enter_zmm();
        fn vg_leave0_zmm();
        fn vg_leave1_zmm();
        fn vg_enter_ymm();
        fn vg_leave0_ymm();
        fn vg_leave1_ymm();
        fn vg_enter_xmm();
        fn vg_leave0_xmm();
        fn vg_leave1_xmm();
    }

    /// The trampoline for the vector registers this CPU has, and how many bytes
    /// of each and how many of them it compares.
    pub struct Tramp {
        enter: unsafe extern "C" fn(),
        pub leave0: usize,
        pub leave1: usize,
        width: usize,
        count: usize,
    }

    pub fn tramp() -> Tramp {
        if std::arch::is_x86_feature_detected!("avx512f") {
            Tramp { enter: vg_enter_zmm, leave0: vg_leave0_zmm as *const () as usize, leave1: vg_leave1_zmm as *const () as usize, width: 64, count: 32 }
        } else if std::arch::is_x86_feature_detected!("avx") {
            Tramp { enter: vg_enter_ymm, leave0: vg_leave0_ymm as *const () as usize, leave1: vg_leave1_ymm as *const () as usize, width: 32, count: 16 }
        } else {
            Tramp { enter: vg_enter_xmm, leave0: vg_leave0_xmm as *const () as usize, leave1: vg_leave1_xmm as *const () as usize, width: 16, count: 16 }
        }
    }

    pub fn features() -> Vec<&'static str> {
        macro_rules! has {
            ($($f:tt),*) => { [$(($f, std::arch::is_x86_feature_detected!($f))),*] };
        }
        has!("ssse3", "sse4.1", "sha", "aes", "pclmulqdq", "avx", "avx2", "vaes", "vpclmulqdq", "bmi1",
             "bmi2", "adx", "avx512f", "avx512vl", "avx512bw", "avx512ifma", "sha512")
            .into_iter().filter(|(_, on)| *on).map(|(f, _)| f).collect()
    }

    /// `jmp qword ptr [rip]` and the address: to `to`, from anywhere.
    pub fn jump(to: usize) -> Vec<u8> {
        let mut v = vec![0xFF, 0x25, 0, 0, 0, 0];
        v.extend_from_slice(&(to as u64).to_le_bytes());
        v
    }

    /// `ret`.
    pub const RET: &[u8] = &[0xC3];

    /// Runs the code at `INSN` from `regs`, giving the registers it leaves and
    /// the branch marker.
    pub fn run(t: &Tramp, regs: &[u8]) -> (Vec<u8>, u8) {
        // SAFETY: the trampolines read and write these only while they run,
        // and this thread is the only one.
        unsafe {
            let inp = &mut *(&raw mut VG_IN);
            inp.0.copy_from_slice(regs);
            let fl = u32::from_le_bytes(regs[FLAGS..FLAGS + 4].try_into().unwrap()) as u64;
            VG_RFLAGS = 2 | (fl & 1) | ((fl >> 1) & 1) << 6 | ((fl >> 2) & 1) << 7 | ((fl >> 3) & 1) << 11;
            let out = &mut *(&raw mut VG_OUT);
            out.0.fill(0);
            (t.enter)();
            // `lahf` gives SF:ZF:0:AF:0:PF:1:CF in AH; `seto` OF in AL.
            let ax = VG_AX;
            let ah = (ax >> 8) & 0xFF;
            let fl = (ah & 1) | ((ah >> 6) & 1) << 1 | ((ah >> 7) & 1) << 2 | (ax & 1) << 3;
            out.0[FLAGS..FLAGS + 4].copy_from_slice(&(fl as u32).to_le_bytes());
            (out.0.to_vec(), VG_MARKER as u8)
        }
    }

    /// The fields of the register state in which `got` differs from `want`,
    /// comparing the flags `mask` says are defined, and only the vector
    /// registers the trampoline loaded.
    pub fn diff(t: &Tramp, got: &[u8], want: &[u8], mask: u8) -> Vec<String> {
        const NAMES: [&str; 16] = ["rax", "rcx", "rdx", "rbx", "rsp", "rbp", "rsi", "rdi",
            "r8", "r9", "r10", "r11", "r12", "r13", "r14", "r15"];
        let mut d = vec![];
        for (i, n) in NAMES.iter().enumerate() {
            let (g, w) = (&got[8 * i..8 * i + 8], &want[8 * i..8 * i + 8]);
            if g != w {
                d.push(format!("{n}: {} (model {})", super::hex(&rev(g)), super::hex(&rev(w))));
            }
        }
        let (g, w) = (got[FLAGS] & mask, want[FLAGS] & mask);
        if g != w {
            d.push(format!("flags (CF ZF SF OF, defined {mask:04b}): {g:04b} (model {w:04b})"));
        }
        if got[MXCSR..MXCSR + 4] != want[MXCSR..MXCSR + 4] {
            d.push(format!("mxcsr: {} (model {})", super::hex(&rev(&got[MXCSR..MXCSR + 4])),
                super::hex(&rev(&want[MXCSR..MXCSR + 4]))));
        }
        for i in 0..t.count {
            let o = VEC + 64 * i;
            if got[o..o + t.width] != want[o..o + t.width] {
                d.push(format!("zmm{i}[{}:0]: {} (model {})", 8 * t.width - 1,
                    super::hex(&rev(&got[o..o + t.width])), super::hex(&rev(&want[o..o + t.width]))));
            }
        }
        d
    }

    fn rev(b: &[u8]) -> Vec<u8> {
        b.iter().rev().copied().collect()
    }
}

fn main() {
    if std::env::args().nth(1).as_deref() == Some("--features") {
        println!("{}", arch::features().join(","));
        return;
    }
    let t = arch::tramp();
    map(CODE, 0x10000, PROT_RWX);
    map(DATA, DATA_LEN, PROT_RW);
    for sig in [4, 7, 8, 11] {
        // SAFETY: `fault` only writes to stderr and exits.
        unsafe { signal(sig, fault as *const () as usize) };
    }
    let mut r = BufReader::with_capacity(1 << 20, std::io::stdin().lock());
    let magic = read_vec(&mut r, 4);
    assert_eq!(magic, b"VGCS", "vg-cosim-runner: not a stream of cases");
    assert_eq!(read_u8(&mut r), arch::ARCH, "vg-cosim-runner: the cases are for another target");
    let state_len = read_u32(&mut r);
    assert_eq!(state_len, arch::REGS_LEN + DATA_LEN, "vg-cosim-runner: the cases' states differ from this runner's");
    let (mut blocks, mut cases, mut failed) = (0usize, 0usize, 0usize);
    let stderr = std::io::stderr();
    while read_u8(&mut r) == 1 {
        let len = read_u16(&mut r);
        let text = read_vec(&mut r, len);
        let kind = read_u8(&mut r);
        let len = read_u16(&mut r);
        let code = read_vec(&mut r, len);
        let n = read_u32(&mut r);
        // SAFETY: the code page is this program's, mapped above, and nothing
        // runs from it while it is written.
        unsafe {
            let len = text.len().min(512);
            (&mut *(&raw mut RUNNING))[..len].copy_from_slice(&text[..len]);
            RUNNING_LEN = len;
            let page = std::slice::from_raw_parts_mut(INSN as *mut u8, 0x1000);
            page.fill(0xCC);
            page[..code.len()].copy_from_slice(&code);
            let after = arch::jump(t.leave0);
            page[code.len()..code.len() + after.len()].copy_from_slice(&after);
            let target: &[u8] = match kind {
                BRANCH_KIND => &arch::jump(t.leave1),
                CALL_KIND => arch::RET,
                INSN_KIND => &[],
                _ => panic!("vg-cosim-runner: unknown kind {kind}"),
            };
            page[TARGET - INSN..TARGET - INSN + target.len()].copy_from_slice(target);
        }
        let mut shown = 0;
        for c in 0..n {
            let start = read_vec(&mut r, state_len);
            let want = read_vec(&mut r, state_len);
            let marker = read_u8(&mut r);
            let mask = read_u8(&mut r);
            // SAFETY: the data page is this program's, mapped above.
            let data = unsafe { std::slice::from_raw_parts_mut(DATA as *mut u8, DATA_LEN) };
            data.copy_from_slice(&start[arch::REGS_LEN..]);
            let (got, got_marker) = arch::run(&t, &start[..arch::REGS_LEN]);
            let mut d = arch::diff(&t, &got, &want[..arch::REGS_LEN], mask);
            if kind == BRANCH_KIND && got_marker != marker {
                d.push(format!("branch: {} (model {})", if got_marker == 1 { "taken" } else { "not taken" },
                    if marker == 1 { "taken" } else { "not taken" }));
            }
            for (o, (g, w)) in data.iter().zip(&want[arch::REGS_LEN..]).enumerate() {
                if g != w {
                    d.push(format!("data[{o}]: {g:02x} (model {w:02x})"));
                }
            }
            cases += 1;
            if !d.is_empty() {
                failed += 1;
                if shown < 3 {
                    shown += 1;
                    let mut e = stderr.lock();
                    writeln!(e, "vg-cosim-runner: {} ({}), case {c}:", String::from_utf8_lossy(&text), hex(&code)).unwrap();
                    writeln!(e, "  start: {}", hex(&start[..arch::REGS_LEN.min(136)])).unwrap();
                    for l in d.iter().take(12) {
                        writeln!(e, "  {l}").unwrap();
                    }
                }
            }
        }
        blocks += 1;
    }
    eprintln!("vg-cosim-runner: {blocks} instructions, {cases} cases, {failed} differ from the model");
    if failed > 0 {
        std::process::exit(1);
    }
}
