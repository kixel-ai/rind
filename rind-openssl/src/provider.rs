// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0
//! The provider itself: its entry point, its parameters, the algorithms it
//! registers, and the errors it raises on OpenSSL's queue.

use core::ffi::{CStr, c_int, c_void};
use std::ffi::CString;
use std::sync::Arc;

use crate::ffi::{
    Algorithm, CORE_NEW_ERROR, CORE_VSET_ERROR, CoreHandle, CoreNewError, CoreVsetError, Dispatch,
    INTEGER, Item, OP_KEYEXCH, OP_KEYMGMT, OP_SIGNATURE, PROVIDER_GET_PARAMS,
    PROVIDER_GET_REASON_STRINGS, PROVIDER_GETTABLE_PARAMS, PROVIDER_QUERY_OPERATION,
    PROVIDER_TEARDOWN, Param, ProviderGetParams, ProviderGetReasonStrings, ProviderGettableParams,
    ProviderQueryOperation, ProviderTeardown, UTF8_PTR, entry,
};
use crate::params::ParamsMut;
use crate::{ed25519, x25519};

/// One activation of the provider, in one OpenSSL library context: the
/// core's handle and the functions that raise errors through it.
pub(crate) struct Provider {
    handle: *const CoreHandle,
    new_error: CoreNewError,
    vset_error: CoreVsetError,
    /// Why rind refuses this CPU, if it does.
    refused: Option<String>,
}

// SAFETY: the core's handle and functions serve every thread for as long as
// the provider is active, which every object holding a `Provider` keeps it;
// the error queue they write is the calling thread's.
unsafe impl Send for Provider {}
// SAFETY: as for `Send`; a `Provider` is never written after it is made.
unsafe impl Sync for Provider {}

impl Provider {
    /// Raises `reason` on the calling thread's error queue, with `detail`.
    pub(crate) fn raise(&self, reason: Reason, detail: &str) {
        raise(self.handle, self.new_error, self.vset_error, reason, detail);
    }

    /// Whether rind runs on this CPU; if not, raises the error that names
    /// the feature it lacks.
    pub(crate) fn usable(&self) -> bool {
        match &self.refused {
            Some(detail) => {
                self.raise(Reason::MissingCpuFeature, detail);
                false
            }
            None => true,
        }
    }

    /// Whether rind refuses this CPU, raising nothing.
    pub(crate) fn refuses(&self) -> bool {
        self.refused.is_some()
    }

    /// The provider whose context OpenSSL passes, which the caller now holds
    /// a reference to as well.
    ///
    /// # Safety
    ///
    /// `provctx` is the context [`OSSL_provider_init`] returned, which
    /// OpenSSL has not torn down.
    pub(crate) unsafe fn from_context(provctx: *mut c_void) -> Arc<Self> {
        let provider = provctx.cast_const().cast::<Self>();
        // SAFETY: the context is a live `Arc<Provider>`, per the caller.
        unsafe {
            Arc::increment_strong_count(provider);
            Arc::from_raw(provider)
        }
    }

    /// 1 on success; otherwise 0, having raised the failure's error if it
    /// has one.
    pub(crate) fn status(&self, result: Result<(), Failure>) -> c_int {
        match result {
            Ok(()) => 1,
            Err(Failure::Raise(reason, detail)) => {
                self.raise(reason, &detail);
                0
            }
            Err(Failure::Quiet) => 0,
        }
    }
}

/// Why a call failed.
pub(crate) enum Failure {
    /// An error to raise on OpenSSL's queue, with its detail.
    Raise(Reason, String),
    /// A failure OpenSSL's default provider reports without an error, such
    /// as a signature that does not verify.
    Quiet,
}

impl Failure {
    pub(crate) fn invalid(detail: &str) -> Self {
        Self::Raise(Reason::InvalidArgument, detail.into())
    }

    pub(crate) fn unsupported(detail: &str) -> Self {
        Self::Raise(Reason::Unsupported, detail.into())
    }
}

impl From<rind::Error> for Failure {
    fn from(error: rind::Error) -> Self {
        let reason = match error {
            rind::Error::KeyRejected(_) => Reason::KeyRejected,
            rind::Error::Unsupported => Reason::Unsupported,
            _ => Reason::Failed,
        };
        Self::Raise(reason, error.to_string())
    }
}

/// The reasons this provider raises errors for, which OpenSSL prints with
/// [`REASONS`]'s strings.
#[derive(Clone, Copy)]
#[repr(u32)]
pub(crate) enum Reason {
    /// The CPU lacks a feature rind requires.
    MissingCpuFeature = 1,
    /// rind refuses a key, such as one whose halves do not match.
    KeyRejected = 2,
    /// rind cannot back what the caller asks, such as Ed25519ph.
    Unsupported = 3,
    /// An argument OpenSSL's default provider refuses too.
    InvalidArgument = 4,
    /// rind failed, as when the system's random source does.
    Failed = 5,
}

static REASONS: [Item; 6] = [
    reason(Reason::MissingCpuFeature, c"rind does not run on this CPU"),
    reason(Reason::KeyRejected, c"key rejected"),
    reason(Reason::Unsupported, c"unsupported by rind"),
    reason(Reason::InvalidArgument, c"invalid argument"),
    reason(Reason::Failed, c"operation failed"),
    Item {
        id: 0,
        ptr: core::ptr::null(),
    },
];

const fn reason(reason: Reason, string: &'static CStr) -> Item {
    Item {
        id: reason as u32,
        ptr: string.as_ptr().cast(),
    }
}

/// Raises `reason` with `detail` through the core, as `ERR_raise_data` would.
fn raise(
    handle: *const CoreHandle,
    new_error: CoreNewError,
    vset_error: CoreVsetError,
    reason: Reason,
    detail: &str,
) {
    // OpenSSL formats the detail as printf does: doubling each `%` leaves no
    // conversion, so it reads none of the arguments.
    let format =
        CString::new(detail.replace('%', "%%").replace('\0', "")).expect("every NUL was removed");
    // A zeroed stand-in for the `va_list` the format never reads, larger and
    // more aligned than any target's.
    let mut arguments = [0u64; 4];
    // SAFETY: the core's functions take its handle, and `vset_error` reads
    // the format, a C string, and none of the arguments.
    unsafe {
        new_error(handle);
        vset_error(
            handle,
            reason as u32,
            format.as_ptr(),
            arguments.as_mut_ptr().cast(),
        );
    }
}

/// Starts the provider. If `check` fails, it starts refusing: each key it
/// would generate, read, or export and each signature and exchange fail
/// with `check`'s error instead, and its status is 0.
///
/// It does not refuse to start, since OpenSSL carries on without a provider
/// that does, even under `config_diagnostics`, from 3.0.13, 3.1.5, and 3.2.1
/// on: every key OpenSSL makes would then be the default provider's, which
/// is the fallback rind refuses.
///
/// # Safety
///
/// As for [`OSSL_provider_init`].
pub(crate) unsafe fn init(
    handle: *const CoreHandle,
    core: *const Dispatch,
    out: *mut *const Dispatch,
    provctx: *mut *mut c_void,
    check: impl FnOnce() -> Result<(), String>,
) -> c_int {
    let (mut new_error, mut vset_error) = (None, None);
    let mut at = core;
    while !at.is_null() {
        // SAFETY: the core's table runs to an entry with id 0.
        let entry = unsafe { &*at };
        if entry.id == 0 {
            break;
        }
        // SAFETY: the core gives each function with the signature its id
        // names.
        unsafe {
            match (entry.id, entry.function) {
                (CORE_NEW_ERROR, Some(function)) => {
                    new_error =
                        Some(core::mem::transmute::<unsafe extern "C" fn(), CoreNewError>(function))
                }
                (CORE_VSET_ERROR, Some(function)) => {
                    vset_error = Some(
                        core::mem::transmute::<unsafe extern "C" fn(), CoreVsetError>(function),
                    )
                }
                _ => {}
            }
        }
        // SAFETY: the table has not ended.
        at = unsafe { at.add(1) };
    }
    // Every OpenSSL 3 core offers both.
    let (Some(new_error), Some(vset_error)) = (new_error, vset_error) else {
        return 0;
    };
    let provider = Arc::new(Provider {
        handle,
        new_error,
        vset_error,
        refused: check().err(),
    });
    // SAFETY: the core passes both outputs to write.
    unsafe {
        *out = FUNCTIONS.as_ptr();
        *provctx = Arc::into_raw(provider).cast_mut().cast();
    }
    1
}

static FUNCTIONS: [Dispatch; 6] = [
    entry!(PROVIDER_TEARDOWN, teardown, ProviderTeardown),
    entry!(
        PROVIDER_GETTABLE_PARAMS,
        gettable_params,
        ProviderGettableParams
    ),
    entry!(PROVIDER_GET_PARAMS, get_params, ProviderGetParams),
    entry!(
        PROVIDER_QUERY_OPERATION,
        query_operation,
        ProviderQueryOperation
    ),
    entry!(
        PROVIDER_GET_REASON_STRINGS,
        reason_strings,
        ProviderGetReasonStrings
    ),
    Dispatch::END,
];

unsafe extern "C" fn teardown(provctx: *mut c_void) {
    if !provctx.is_null() {
        // SAFETY: the context is the `Arc` init made, which OpenSSL now
        // gives back.
        drop(unsafe { Arc::from_raw(provctx.cast_const().cast::<Provider>()) });
    }
}

const VERSION: &CStr =
    match CStr::from_bytes_with_nul(concat!(env!("CARGO_PKG_VERSION"), "\0").as_bytes()) {
        Ok(version) => version,
        Err(_) => panic!("the version holds no NUL"),
    };

static GETTABLE_PARAMS: [Param; 5] = [
    Param::describe(Some(c"name"), UTF8_PTR, 0),
    Param::describe(Some(c"version"), UTF8_PTR, 0),
    Param::describe(Some(c"buildinfo"), UTF8_PTR, 0),
    Param::describe(Some(c"status"), INTEGER, size_of::<c_int>()),
    Param::END,
];

unsafe extern "C" fn gettable_params(_provctx: *mut c_void) -> *const Param {
    GETTABLE_PARAMS.as_ptr()
}

unsafe extern "C" fn get_params(provctx: *mut c_void, params: *mut Param) -> c_int {
    // SAFETY: OpenSSL passes the provider's context and a writable array.
    let (provider, mut params) =
        unsafe { (Provider::from_context(provctx), ParamsMut::new(params)) };
    for (name, value) in [
        (c"name", c"rind"),
        (c"version", VERSION),
        (c"buildinfo", VERSION),
    ] {
        if let Some(param) = params.find(name)
            && !param.set_utf8_ptr(value)
        {
            return 0;
        }
    }
    // OpenSSL's FIPS provider reports 0 while it refuses to run, too.
    if let Some(param) = params.find(c"status")
        && !param.set_int(provider.refused.is_none().into())
    {
        return 0;
    }
    1
}

static KEYMGMT: [Algorithm; 3] = [
    Algorithm::new(c"X25519:1.3.101.110", &x25519::KEYMGMT),
    Algorithm::new(c"ED25519:1.3.101.112", &ed25519::KEYMGMT),
    Algorithm::END,
];

static KEYEXCH: [Algorithm; 2] = [
    Algorithm::new(c"X25519:1.3.101.110", &x25519::KEYEXCH),
    Algorithm::END,
];

static SIGNATURE: [Algorithm; 2] = [
    Algorithm::new(c"ED25519:1.3.101.112", &ed25519::SIGNATURE),
    Algorithm::END,
];

unsafe extern "C" fn query_operation(
    _provctx: *mut c_void,
    operation: c_int,
    no_store: *mut c_int,
) -> *const Algorithm {
    if !no_store.is_null() {
        // SAFETY: OpenSSL passes a flag to write. The lists never change, so
        // it may cache what they hold.
        unsafe { *no_store = 0 };
    }
    match operation {
        OP_KEYMGMT => KEYMGMT.as_ptr(),
        OP_KEYEXCH => KEYEXCH.as_ptr(),
        OP_SIGNATURE => SIGNATURE.as_ptr(),
        _ => core::ptr::null(),
    }
}

unsafe extern "C" fn reason_strings(_provctx: *mut c_void) -> *const Item {
    REASONS.as_ptr()
}

#[cfg(all(test, unix))]
mod tests {
    use core::ffi::c_char;
    use core::ptr::{null, null_mut};

    use openssl_sys::{
        BIO, BIO_free_all, BIO_new_mem_buf, ERR_get_error_all, EVP_MD_CTX, EVP_MD_CTX_free,
        EVP_MD_CTX_new, EVP_PKEY, EVP_PKEY_CTX, EVP_PKEY_CTX_free, EVP_PKEY_CTX_new_from_name,
        EVP_PKEY_free, EVP_PKEY_generate, EVP_PKEY_get_raw_public_key, EVP_PKEY_keygen_init,
        EVP_PKEY_new_raw_private_key_ex, OSSL_LIB_CTX, OSSL_LIB_CTX_free, OSSL_LIB_CTX_new,
        OSSL_PROVIDER, OSSL_PROVIDER_load, OSSL_PROVIDER_unload,
    };

    use super::*;

    type Init = unsafe extern "C" fn(
        *const CoreHandle,
        *const Dispatch,
        *mut *const Dispatch,
        *mut *mut c_void,
    ) -> c_int;

    // What `openssl-sys` does not bind, in OpenSSL 3.0.
    unsafe extern "C" {
        fn OSSL_PROVIDER_add_builtin(
            ctx: *mut OSSL_LIB_CTX,
            name: *const c_char,
            init: Init,
        ) -> c_int;
        fn OSSL_LIB_CTX_load_config(ctx: *mut OSSL_LIB_CTX, file: *const c_char) -> c_int;
        fn OSSL_PROVIDER_get_params(provider: *const OSSL_PROVIDER, params: *mut Param) -> c_int;
        fn ERR_error_string_n(error: core::ffi::c_ulong, buf: *mut c_char, len: usize);
        fn PEM_read_bio_PrivateKey_ex(
            bio: *mut BIO,
            out: *mut *mut EVP_PKEY,
            callback: *mut c_void,
            arg: *mut c_void,
            ctx: *mut OSSL_LIB_CTX,
            propq: *const c_char,
        ) -> *mut EVP_PKEY;
        fn EVP_PKEY_CTX_new_from_pkey(
            ctx: *mut OSSL_LIB_CTX,
            pkey: *mut EVP_PKEY,
            propq: *const c_char,
        ) -> *mut EVP_PKEY_CTX;
        fn EVP_PKEY_derive_init(ctx: *mut EVP_PKEY_CTX) -> c_int;
        fn EVP_DigestSignInit_ex(
            ctx: *mut EVP_MD_CTX,
            pctx: *mut *mut EVP_PKEY_CTX,
            mdname: *const c_char,
            libctx: *mut OSSL_LIB_CTX,
            props: *const c_char,
            pkey: *mut EVP_PKEY,
            params: *const Param,
        ) -> c_int;
    }

    /// RFC 8410's example Ed25519 private key.
    const ED25519_PEM: &[u8] = b"-----BEGIN PRIVATE KEY-----
MC4CAQAwBQYDK2VwBCIEINTuctv5E1hK1bbY8fdp+K06/nwoy/HU++CXqI9EdVhC
-----END PRIVATE KEY-----
";

    const MISSING: &str = "rind requires neon CPU support on aarch64";

    /// The provider on a CPU rind refuses, as on an AArch64 one without NEON.
    unsafe extern "C" fn refusing(
        handle: *const CoreHandle,
        core: *const Dispatch,
        out: *mut *const Dispatch,
        provctx: *mut *mut c_void,
    ) -> c_int {
        // SAFETY: OpenSSL calls this as it would `OSSL_provider_init`.
        unsafe { init(handle, core, out, provctx, || Err(MISSING.into())) }
    }

    /// The first error on OpenSSL's queue, with its data, which empties it.
    fn first_error() -> String {
        let (mut data, mut flags) = (null(), 0);
        // SAFETY: each output is writable or null.
        let code =
            unsafe { ERR_get_error_all(null_mut(), null_mut(), null_mut(), &mut data, &mut flags) };
        let mut text = [0 as c_char; 256];
        // SAFETY: the buffer is writable for its length, and OpenSSL writes a
        // C string to it; the data is one or null.
        let out = unsafe {
            ERR_error_string_n(code, text.as_mut_ptr(), text.len());
            let mut out = CStr::from_ptr(text.as_ptr()).to_string_lossy().into_owned();
            if !data.is_null() {
                out = format!("{out}: {}", CStr::from_ptr(data).to_string_lossy());
            }
            out
        };
        // SAFETY: it only empties this thread's queue.
        unsafe { openssl_sys::ERR_clear_error() };
        out
    }

    /// On a CPU rind refuses, the README's configuration still loads, and
    /// each use of rind's algorithms fails with rind's error rather than
    /// fall back to the default provider, even with a key the default
    /// provider made. The default provider keeps the rest.
    #[test]
    fn a_refused_cpu_fails_each_use_with_rinds_error() {
        // SAFETY: each call takes the context, live until freed, and C
        // strings; each key made is freed.
        unsafe {
            let ctx = OSSL_LIB_CTX_new();
            assert!(!ctx.is_null());
            // A built-in provider of the configuration's name stands in for
            // its module.
            assert_eq!(
                OSSL_PROVIDER_add_builtin(ctx, c"rind".as_ptr(), refusing),
                1
            );
            let config = concat!(env!("CARGO_MANIFEST_DIR"), "/openssl.cnf\0");
            assert_eq!(
                OSSL_LIB_CTX_load_config(ctx, config.as_ptr().cast()),
                1,
                "{}",
                first_error()
            );

            let mut status: c_int = -1;
            let mut params = [
                Param {
                    key: c"status".as_ptr(),
                    data_type: INTEGER,
                    data: (&raw mut status).cast(),
                    data_size: size_of::<c_int>(),
                    return_size: crate::ffi::UNMODIFIED,
                },
                Param::END,
            ];
            let provider = OSSL_PROVIDER_load(ctx, c"rind".as_ptr());
            assert!(!provider.is_null());
            assert_eq!(OSSL_PROVIDER_get_params(provider, params.as_mut_ptr()), 1);
            assert_eq!(status, 0);
            OSSL_PROVIDER_unload(provider);

            let generate = |algorithm: &CStr| {
                let pctx = EVP_PKEY_CTX_new_from_name(ctx, algorithm.as_ptr(), null());
                assert!(!pctx.is_null());
                let mut key: *mut EVP_PKEY = null_mut();
                let ok = EVP_PKEY_keygen_init(pctx) == 1 && EVP_PKEY_generate(pctx, &mut key) == 1;
                EVP_PKEY_CTX_free(pctx);
                EVP_PKEY_free(key);
                ok
            };
            let refusal = format!("rind does not run on this CPU: {MISSING}");
            let refused = |what: &str| {
                let error = first_error();
                assert!(error.contains(&refusal), "{what}: {error}");
            };
            // Each use of a key, which OpenSSL starts by moving the key to
            // the operation's provider, rind.
            let sign_fails = |key: *mut EVP_PKEY, propq: &CStr| {
                let md = EVP_MD_CTX_new();
                let ok =
                    EVP_DigestSignInit_ex(md, null_mut(), null(), ctx, propq.as_ptr(), key, null());
                EVP_MD_CTX_free(md);
                ok != 1
            };
            let derive_fails = |key: *mut EVP_PKEY| {
                let pctx = EVP_PKEY_CTX_new_from_pkey(ctx, key, null());
                let ok = !pctx.is_null() && EVP_PKEY_derive_init(pctx) == 1;
                EVP_PKEY_CTX_free(pctx);
                !ok
            };
            let read_fails = |key: *mut EVP_PKEY| {
                let (mut out, mut len) = ([0u8; 32], 32);
                EVP_PKEY_get_raw_public_key(key, out.as_mut_ptr(), &mut len) != 1
            };
            for algorithm in [c"ED25519", c"X25519"] {
                assert!(!generate(algorithm));
                refused("generate");

                // Importing lands, empty, so the key's every use fails.
                let key = EVP_PKEY_new_raw_private_key_ex(
                    ctx,
                    algorithm.as_ptr(),
                    null(),
                    [9; 32].as_ptr(),
                    32,
                );
                assert!(!key.is_null(), "{}", first_error());
                assert!(read_fails(key));
                refused("read");
                match algorithm == c"ED25519" {
                    true => assert!(sign_fails(key, c"")),
                    false => assert!(derive_fails(key)),
                }
                refused("use");
                EVP_PKEY_free(key);

                // A key the default provider made, asked for by name.
                let key = EVP_PKEY_new_raw_private_key_ex(
                    ctx,
                    algorithm.as_ptr(),
                    c"provider=default".as_ptr(),
                    [9; 32].as_ptr(),
                    32,
                );
                assert!(!key.is_null(), "{}", first_error());
                match algorithm == c"ED25519" {
                    true => assert!(sign_fails(key, c"")),
                    false => assert!(derive_fails(key)),
                }
                refused("a default provider key");
                EVP_PKEY_free(key);
            }

            // A decoded key, which the default provider's decoder makes and
            // keeps.
            let bio = BIO_new_mem_buf(ED25519_PEM.as_ptr().cast(), ED25519_PEM.len() as c_int);
            let key =
                PEM_read_bio_PrivateKey_ex(bio, null_mut(), null_mut(), null_mut(), ctx, null());
            BIO_free_all(bio);
            assert!(!key.is_null(), "{}", first_error());
            assert!(sign_fails(key, c""));
            refused("a decoded key");
            EVP_PKEY_free(key);

            assert!(generate(c"X448"), "{}", first_error());
            OSSL_LIB_CTX_free(ctx);
        }
    }
}
