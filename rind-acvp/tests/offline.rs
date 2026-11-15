// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

//! Runs aws-lc's `acvptool` offline on ACVP vector sets through `rind-acvp`,
//! once for each CPU path of the module this host can take, and checks every
//! answer.
//!
//! The sets are NIST's samples (`thirdparty/acvp/`), with the answers they
//! carry, and sets built here for what the samples lack: KAS-ECC-SSC on the
//! NIST curves from CAVP's ECDH vectors, PBKDF2 from Wycheproof's, and RSA
//! verification with the exponent the module takes from Wycheproof's. An
//! answer with nothing to compare, such as a generated key or a hedged
//! signature, is checked with aws-lc-rs.
//!
//! The large-data hash tests hash 15 GiB per hash, so they run only with
//! `SLOW_TESTS` set.

use std::collections::HashMap;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;

use aws_lc_rs::agreement;
use aws_lc_rs::signature as aws_signature;
use num_bigint::BigUint;
use serde_json::{Value, json};

/// A vector set to answer, and how to check its answers.
struct Set {
    /// The set as `acvptool` reads it, without its answers.
    prompt: Value,
    check: Check,
}

enum Check {
    /// Every answer must equal the expected set's.
    Answers(Value),
    /// The answers have no expected values; this checks each response.
    Validate(Box<Validate>),
}

/// Checks a response's group against the prompt's.
type Validate = dyn Fn(&Value, &Value) -> Result<(), String>;

/// Each tier of CPU features to deny, and whether this CPU has a feature.
type Tiers = (&'static [&'static [&'static str]], fn(&str) -> bool);

#[test]
fn every_cpu_path_answers_every_set() {
    let acvptool = acvptool();
    let sets = sets();
    let mut ran = 0;
    for mask in cpu_paths() {
        let label = if mask.is_empty() {
            "every feature".to_owned()
        } else {
            format!("without {}", mask.join(", "))
        };
        eprintln!("rind-acvp: {} sets, {label}", sets.len());
        let responses = run(&acvptool, &sets, &mask);
        let failures: Vec<String> = sets
            .iter()
            .zip(&responses)
            .filter_map(|(set, response)| {
                check(set, response).err().map(|error| {
                    format!(
                        "{} {}: {error}",
                        set.prompt["algorithm"].as_str().unwrap_or("?"),
                        set.prompt["mode"].as_str().unwrap_or("")
                    )
                })
            })
            .collect();
        assert!(failures.is_empty(), "{label}:\n{}", failures.join("\n"));
        ran += 1;
    }
    assert!(ran > 0);
}

/// `acvptool`: `$ACVPTOOL`, or the one on `$PATH`, which the dev shell
/// provides.
fn acvptool() -> PathBuf {
    if let Some(path) = std::env::var_os("ACVPTOOL") {
        return path.into();
    }
    let found = std::env::var_os("PATH").and_then(|paths| {
        std::env::split_paths(&paths)
            .map(|dir| dir.join("acvptool"))
            .find(|path| path.is_file())
    });
    found.expect("acvptool is not on $PATH: run in `nix develop`, or set $ACVPTOOL")
}

/// The `RIND_CPU_DISABLE_*` masks that reach each of the module's paths, of
/// the ones this CPU can take: every feature, then without AVX-512, then
/// the baseline the module requires. A mask that denies only features this
/// CPU lacks repeats the path before it, so it is skipped.
fn cpu_paths() -> Vec<Vec<&'static str>> {
    #[cfg(target_arch = "x86_64")]
    let (tiers, has): Tiers = (
        &[
            &[],
            &[
                "avx512f",
                "avx512bw",
                "avx512vl",
                "avx512dq",
                "avx512ifma",
                "avx512vbmi",
                "avx512vbmi2",
            ],
            &["vaes", "vpclmulqdq", "sha", "sha512", "intel"],
        ],
        |feature| match feature {
            "avx512f" => std::arch::is_x86_feature_detected!("avx512f"),
            "avx512bw" => std::arch::is_x86_feature_detected!("avx512bw"),
            "avx512vl" => std::arch::is_x86_feature_detected!("avx512vl"),
            "avx512dq" => std::arch::is_x86_feature_detected!("avx512dq"),
            "avx512ifma" => std::arch::is_x86_feature_detected!("avx512ifma"),
            "avx512vbmi" => std::arch::is_x86_feature_detected!("avx512vbmi"),
            "avx512vbmi2" => std::arch::is_x86_feature_detected!("avx512vbmi2"),
            "vaes" => std::arch::is_x86_feature_detected!("vaes"),
            "vpclmulqdq" => std::arch::is_x86_feature_detected!("vpclmulqdq"),
            "sha" => std::arch::is_x86_feature_detected!("sha"),
            "sha512" => std::arch::is_x86_feature_detected!("sha512"),
            // The vendor picks some paths, as an AMD CPU takes the other.
            "intel" => {
                // SAFETY: every x86_64 CPU has `cpuid`.
                #[allow(unused_unsafe)]
                let id = unsafe { std::arch::x86_64::__cpuid(0) };
                (id.ebx, id.edx, id.ecx) == (0x756e_6547, 0x4965_6e69, 0x6c65_746e)
            }
            _ => unreachable!(),
        },
    );
    #[cfg(target_arch = "aarch64")]
    let (tiers, has): Tiers = (&[&[], &["sha3"]], |feature| match feature {
        "sha3" => std::arch::is_aarch64_feature_detected!("sha3"),
        _ => unreachable!(),
    });
    let mut masks = Vec::new();
    let mut mask = Vec::new();
    for (i, tier) in tiers.iter().enumerate() {
        mask.extend_from_slice(tier);
        if i == 0 || tier.iter().any(|&feature| has(feature)) {
            masks.push(mask.clone());
        }
    }
    masks
}

/// Runs `acvptool` on every set at once, with `mask` denied, returning each
/// set's response in order.
fn run(acvptool: &Path, sets: &[Set], mask: &[&str]) -> Vec<Value> {
    let mut input = vec![json!({"acvVersion": "1.0"})];
    input.extend(sets.iter().enumerate().map(|(i, set)| {
        let mut prompt = set.prompt.clone();
        prompt["vsId"] = json!(i + 1);
        prompt
    }));
    let dir = Path::new(env!("CARGO_TARGET_TMPDIR"));
    let file = dir.join(format!("acvp-{}.json", std::process::id()));
    fs::write(&file, serde_json::to_vec(&input).unwrap()).unwrap();

    let mut command = Command::new(acvptool);
    command
        .arg("-wrapper")
        .arg(env!("CARGO_BIN_EXE_rind-acvp"))
        .arg("-json")
        .arg(&file);
    for feature in mask {
        command.env(format!("RIND_CPU_DISABLE_{feature}"), "1");
    }
    let output = command.output().expect("cannot run acvptool");
    fs::remove_file(&file).unwrap();
    assert!(
        output.status.success(),
        "acvptool failed:\n{}",
        String::from_utf8_lossy(&output.stderr)
    );
    let output: Vec<Value> = serde_json::from_slice(&output.stdout).unwrap();
    let mut responses: HashMap<u64, Value> = output
        .into_iter()
        .filter_map(|response| Some((response["vsId"].as_u64()?, response)))
        .collect();
    (1..=sets.len() as u64)
        .map(|id| responses.remove(&id).expect("a set with no response"))
        .collect()
}

/// Checks `response` to `set`: that it answers every test, and each answer.
fn check(set: &Set, response: &Value) -> Result<(), String> {
    let groups = |value: &Value| -> Vec<(u64, Vec<u64>)> {
        value["testGroups"]
            .as_array()
            .into_iter()
            .flatten()
            .map(|group| {
                let tests = group["tests"].as_array().into_iter().flatten();
                (
                    id(group, "tgId"),
                    tests.map(|test| id(test, "tcId")).collect(),
                )
            })
            .collect()
    };
    let (mut asked, mut answered) = (groups(&set.prompt), groups(response));
    asked.sort();
    answered.sort();
    if asked != answered {
        return Err("the response answers other tests than the set asks".into());
    }
    match &set.check {
        Check::Answers(expected) => subset(response, expected, "".into()),
        Check::Validate(validate) => {
            for group in response["testGroups"].as_array().unwrap() {
                let prompt = find(&set.prompt["testGroups"], "tgId", id(group, "tgId"));
                validate(prompt, group).map_err(|e| format!("tgId {}: {e}", id(group, "tgId")))?;
            }
            Ok(())
        }
    }
}

fn id(value: &Value, key: &str) -> u64 {
    value[key].as_u64().unwrap()
}

/// The element of `array` whose `key` is `id`.
fn find<'a>(array: &'a Value, key: &str, id: u64) -> &'a Value {
    array
        .as_array()
        .and_then(|array| array.iter().find(|v| v[key].as_u64() == Some(id)))
        .unwrap_or(&Value::Null)
}

/// Whether every field of `response` equals `expected`'s, recursively,
/// matching groups and tests by their ids and hex case-insensitively.
fn subset(response: &Value, expected: &Value, path: String) -> Result<(), String> {
    match (response, expected) {
        (Value::Object(response), Value::Object(expected)) => {
            for (key, value) in response {
                if key == "vsId" {
                    continue;
                }
                let path = format!("{path}/{key}");
                let Some(want) = expected.get(key) else {
                    return Err(format!("{path}: no expected value"));
                };
                subset(value, want, path)?;
            }
            Ok(())
        }
        (Value::Array(response), Value::Array(_)) => {
            for (i, value) in response.iter().enumerate() {
                let (key, want) = ["tgId", "tcId"]
                    .into_iter()
                    .find_map(|key| Some((key, find(expected, key, value[key].as_u64()?))))
                    .unwrap_or(("", &expected[i]));
                subset(value, want, format!("{path}[{key} {}]", value[key]))?;
            }
            Ok(())
        }
        (Value::String(a), Value::String(b)) if a.eq_ignore_ascii_case(b) => Ok(()),
        (a, b) if a == b => Ok(()),
        (a, b) => Err(format!("{path}: {a}, expected {b}")),
    }
}

fn hex(value: &Value) -> Vec<u8> {
    hex::decode(value.as_str().unwrap_or_default()).unwrap()
}

/// `bytes` as a big-endian integer of `len` bytes.
fn padded(bytes: &[u8], len: usize) -> Vec<u8> {
    let start = bytes.iter().position(|&b| b != 0).unwrap_or(bytes.len());
    let bytes = &bytes[start..];
    let mut out = vec![0; len - bytes.len()];
    out.extend_from_slice(bytes);
    out
}

fn root() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR")).join("..")
}

fn read(path: &str) -> Value {
    let path = root().join(path);
    let file = fs::read(&path).unwrap_or_else(|e| panic!("{}: {e}", path.display()));
    serde_json::from_slice(&file).unwrap()
}

// The sets.

fn sets() -> Vec<Set> {
    let mut sets = Vec::new();
    let slow = std::env::var_os("SLOW_TESTS").is_some();
    for name in [
        "SHA2-256-1.0",
        "SHA2-384-1.0",
        "SHA2-512-1.0",
        "SHA2-512-256-1.0",
        "SHA3-256-2.0",
        "SHA3-384-2.0",
        "SHA3-512-2.0",
    ] {
        // The alternate Monte Carlo test is for an IUT that cannot hash
        // three digests at once; rind registers every length, so is sent
        // the standard one, the only one `acvptool` runs.
        sets.push(sample(name, |group, _| {
            group["mctVersion"] != "alternate" && (slow || group["testType"] != "LDT")
        }));
    }
    for name in [
        "HMAC-SHA-1-2.0",
        "HMAC-SHA2-256-2.0",
        "HMAC-SHA2-384-2.0",
        "HMAC-SHA2-512-2.0",
    ] {
        let mut set = sample(name, |_, _| true);
        for value in [
            &mut set.prompt,
            match &mut set.check {
                Check::Answers(expected) => expected,
                Check::Validate(_) => unreachable!(),
            },
        ] {
            hmac_revision_1(value);
        }
        sets.push(set);
    }
    for name in [
        "ACVP-AES-ECB-1.0",
        "ACVP-AES-CBC-1.0",
        "ACVP-AES-KW-1.0",
        "ACVP-AES-KWP-1.0",
        "hmacDRBG-1.0",
        "ECDSA-KeyVer-FIPS186-5",
        "ECDSA-SigVer-FIPS186-5",
        "EDDSA-KeyVer-1.0",
        "EDDSA-SigVer-1.0",
        "ML-KEM-keyGen-FIPS203",
        "ML-KEM-encapDecap-FIPS203-tr1",
        "ML-DSA-keyGen-FIPS204",
        "ML-DSA-sigGen-FIPS204",
        "ML-DSA-sigVer-FIPS204",
    ] {
        sets.push(sample(name, |_, _| true));
    }
    sets.push(kda_hkdf());
    // CTR's whole-byte payloads, the only ones rind registers.
    sets.push(sample("ACVP-AES-CTR-1.0", |_, test| {
        test["payloadLen"].as_u64().is_none_or(|bits| bits % 8 == 0)
    }));
    // The module opens AES-GCM with an IV it is given, and seals only with
    // IVs it generates.
    for name in ["ACVP-AES-GCM-1.0", "ACVP-AES-GMAC-1.0"] {
        sets.push(sample(name, |group, _| group["direction"] == "decrypt"));
    }
    // rind draws a scalar by rejection, FIPS 186-5's testing candidates.
    let mut key_gen = generated("ECDSA-KeyGen-FIPS186-5", ecdsa_key_gen);
    let groups = key_gen.prompt["testGroups"].as_array_mut().unwrap();
    groups.retain(|group| group["secretGenerationMode"] == "testing candidates");
    sets.push(key_gen);
    sets.push(generated("ECDSA-SigGen-FIPS186-5", ecdsa_sig_gen));
    sets.push(generated("EDDSA-KeyGen-1.0", ed25519_key_gen));
    sets.push(generated("EDDSA-SigGen-1.0", ed25519_sig_gen));
    sets.push(generated("RSA-KeyGen-FIPS186-5", rsa_key_gen));
    sets.push(generated("RSA-SigGen-FIPS186-5", rsa_sig_gen));
    sets.extend(kas_ecc_ssc());
    sets.push(pbkdf());
    sets.extend(rsa_sig_ver());
    sets
}

/// The fields of an answer, which a prompt leaves out, that `acvptool`
/// refuses to find in one: an AEAD's output, and `externalMu` outside the
/// internal interface, which `acvptool` would take as true or false.
fn strip_answers(prompt: &mut Value) {
    let algorithm = prompt["algorithm"].as_str().unwrap_or_default().to_owned();
    for group in prompt["testGroups"].as_array_mut().unwrap() {
        if algorithm.starts_with("ML-DSA") && group["signatureInterface"] == "external" {
            group.as_object_mut().unwrap().remove("externalMu");
        }
        let direction = group["direction"].as_str().unwrap_or_default().to_owned();
        let aead = [
            "ACVP-AES-GCM",
            "ACVP-AES-GMAC",
            "ACVP-AES-KW",
            "ACVP-AES-KWP",
        ];
        if !aead.contains(&algorithm.as_str()) {
            continue;
        }
        for test in group["tests"].as_array_mut().unwrap() {
            let test = test.as_object_mut().unwrap();
            match direction.as_str() {
                "decrypt" => {
                    test.remove("pt");
                }
                _ => {
                    test.remove("ct");
                    test.remove("tag");
                }
            }
        }
    }
}

/// HMAC's revision 2.0 set as revision 1.0, the one `acvptool` runs and
/// rind registers: each test its own group, which carries the lengths 2.0
/// gives each test.
fn hmac_revision_1(set: &mut Value) {
    set["revision"] = json!("1.0");
    let groups = set["testGroups"].as_array().unwrap().clone();
    let tests = groups.iter().flat_map(|group| {
        tests(group).iter().map(|test| {
            let mut group = group.clone();
            for length in ["msgLen", "keyLen", "macLen"] {
                group[length] = test[length].clone();
            }
            group["tgId"] = test["tcId"].clone();
            group["tests"] = json!([test]);
            group
        })
    });
    set["testGroups"] = Value::Array(tests.collect());
}

/// A NIST sample whose answers it carries, with the groups and tests `keep`
/// keeps.
fn sample(name: &str, keep: impl Fn(&Value, &Value) -> bool) -> Set {
    let mut expected = read(&format!("thirdparty/acvp/{name}.json"));
    for group in expected["testGroups"].as_array_mut().unwrap() {
        let tests = group["tests"].as_array().unwrap().clone();
        let kept = tests.into_iter().filter(|test| keep(group, test)).collect();
        group["tests"] = Value::Array(kept);
    }
    let groups = expected["testGroups"].as_array_mut().unwrap();
    groups.retain(|group| !group["tests"].as_array().unwrap().is_empty());
    let mut prompt = expected.clone();
    strip_answers(&mut prompt);
    Set {
        prompt,
        check: Check::Answers(expected),
    }
}

/// KDA's HKDF sample, every group of which has a hybrid shared secret, as
/// the ordinary one `acvptool` takes and rind registers: SP 800-56C's
/// `Z || T`, as one secret.
fn kda_hkdf() -> Set {
    let mut set = sample("KDA-HKDF-Sp800-56Cr2", |_, _| true);
    for group in set.prompt["testGroups"].as_array_mut().unwrap() {
        group["usesHybridSharedSecret"] = json!(false);
        for test in group["tests"].as_array_mut().unwrap() {
            let params = &mut test["kdfParameter"];
            if let Some(t) = params.as_object_mut().unwrap().remove("t") {
                let z = params["z"].as_str().unwrap().to_owned();
                params["z"] = json!(z + t.as_str().unwrap());
            }
        }
    }
    set
}

/// A NIST sample whose answers are generated, so `validate` checks each
/// group's.
fn generated(name: &str, validate: fn(&Value, &Value) -> Result<(), String>) -> Set {
    let mut prompt = read(&format!("thirdparty/acvp/{name}.json"));
    strip_answers(&mut prompt);
    Set {
        prompt,
        check: Check::Validate(Box::new(validate)),
    }
}

/// The prompt's test of `answer`.
fn asked<'a>(prompt: &'a Value, answer: &Value) -> &'a Value {
    find(&prompt["tests"], "tcId", id(answer, "tcId"))
}

fn tests(group: &Value) -> &Vec<Value> {
    group["tests"].as_array().unwrap()
}

fn ecdsa_curve(prompt: &Value) -> (usize, &'static aws_signature::EcdsaSigningAlgorithm) {
    match prompt["curve"].as_str().unwrap() {
        "P-256" => (32, &aws_signature::ECDSA_P256_SHA256_FIXED_SIGNING),
        "P-384" => (48, &aws_signature::ECDSA_P384_SHA384_FIXED_SIGNING),
        "P-521" => (66, &aws_signature::ECDSA_P521_SHA512_FIXED_SIGNING),
        curve => panic!("no curve {curve}"),
    }
}

fn point(x: &Value, y: &Value, len: usize) -> Vec<u8> {
    [&[4][..], &padded(&hex(x), len), &padded(&hex(y), len)].concat()
}

/// Each generated key's public point is its private scalar's.
fn ecdsa_key_gen(prompt: &Value, group: &Value) -> Result<(), String> {
    let (len, algorithm) = ecdsa_curve(prompt);
    for test in tests(group) {
        let d = padded(&hex(&test["d"]), len);
        let q = point(&test["qx"], &test["qy"], len);
        aws_signature::EcdsaKeyPair::from_private_key_and_public_key(algorithm, &d, &q)
            .map_err(|e| format!("tcId {}: {e}", id(test, "tcId")))?;
    }
    Ok(())
}

/// Each signature verifies under the group's key.
fn ecdsa_sig_gen(prompt: &Value, group: &Value) -> Result<(), String> {
    let (len, _) = ecdsa_curve(prompt);
    let algorithm = match (prompt["curve"].as_str(), prompt["hashAlg"].as_str()) {
        (Some("P-256"), Some("SHA2-256")) => &aws_signature::ECDSA_P256_SHA256_FIXED,
        (Some("P-384"), Some("SHA2-384")) => &aws_signature::ECDSA_P384_SHA384_FIXED,
        (Some("P-521"), Some("SHA2-512")) => &aws_signature::ECDSA_P521_SHA512_FIXED,
        pair => return Err(format!("no ECDSA {pair:?}")),
    };
    let key = point(&group["qx"], &group["qy"], len);
    for test in tests(group) {
        let signature = [padded(&hex(&test["r"]), len), padded(&hex(&test["s"]), len)].concat();
        aws_signature::UnparsedPublicKey::new(algorithm, &key)
            .verify(&hex(&asked(prompt, test)["message"]), &signature)
            .map_err(|e| format!("tcId {}: {e}", id(test, "tcId")))?;
    }
    Ok(())
}

/// Each generated public key is its seed's.
fn ed25519_key_gen(_: &Value, group: &Value) -> Result<(), String> {
    for test in tests(group) {
        aws_signature::Ed25519KeyPair::from_seed_and_public_key(&hex(&test["d"]), &hex(&test["q"]))
            .map_err(|e| format!("tcId {}: {e}", id(test, "tcId")))?;
    }
    Ok(())
}

/// Each signature verifies under the group's key.
fn ed25519_sig_gen(prompt: &Value, group: &Value) -> Result<(), String> {
    let key = hex(&group["q"]);
    for test in tests(group) {
        aws_signature::UnparsedPublicKey::new(&aws_signature::ED25519, &key)
            .verify(
                &hex(&asked(prompt, test)["message"]),
                &hex(&test["signature"]),
            )
            .map_err(|e| format!("tcId {}: {e}", id(test, "tcId")))?;
    }
    Ok(())
}

/// Each key is of the size asked, with exponent 65537, prime factors of
/// half its size, and a private exponent that inverts the public one.
fn rsa_key_gen(prompt: &Value, group: &Value) -> Result<(), String> {
    let bits = prompt["modulo"].as_u64().unwrap();
    let int = |value: &Value| BigUint::from_bytes_be(&hex(value));
    let one = BigUint::from(1u32);
    for test in tests(group) {
        let fail = |what: &str| Err(format!("tcId {}: {what}", id(test, "tcId")));
        let (e, p, q, n, d) = (
            int(&test["e"]),
            int(&test["p"]),
            int(&test["q"]),
            int(&test["n"]),
            int(&test["d"]),
        );
        if n.bits() != bits || p.bits() != bits / 2 || q.bits() != bits / 2 {
            return fail("sizes");
        }
        if e != BigUint::from(65537u32) || &p * &q != n {
            return fail("n is not p * q, or e is not 65537");
        }
        let (p1, q1) = (&p - &one, &q - &one);
        let lambda = &p1 * &q1 / gcd(p1.clone(), q1.clone());
        if &d * &e % &lambda != one || d >= lambda {
            return fail("d is not e's inverse modulo lcm(p - 1, q - 1)");
        }
        // Fermat to bases 2, 3, and 5, against a mix-up of p, q, and n.
        for prime in [&p, &q] {
            for base in [2u32, 3, 5] {
                if BigUint::from(base).modpow(&(prime - &one), prime) != one {
                    return fail("a factor is not prime");
                }
            }
        }
    }
    Ok(())
}

fn gcd(mut a: BigUint, mut b: BigUint) -> BigUint {
    while b != BigUint::ZERO {
        let r = &a % &b;
        a = b;
        b = r;
    }
    a
}

/// Each signature verifies under the group's key.
fn rsa_sig_gen(prompt: &Value, group: &Value) -> Result<(), String> {
    let algorithm = match (prompt["sigType"].as_str(), prompt["hashAlg"].as_str()) {
        (Some("pkcs1v1.5"), Some("SHA2-256")) => &aws_signature::RSA_PKCS1_2048_8192_SHA256,
        (Some("pkcs1v1.5"), Some("SHA2-384")) => &aws_signature::RSA_PKCS1_2048_8192_SHA384,
        (Some("pkcs1v1.5"), Some("SHA2-512")) => &aws_signature::RSA_PKCS1_2048_8192_SHA512,
        (Some("pss"), Some("SHA2-256")) => &aws_signature::RSA_PSS_2048_8192_SHA256,
        (Some("pss"), Some("SHA2-384")) => &aws_signature::RSA_PSS_2048_8192_SHA384,
        (Some("pss"), Some("SHA2-512")) => &aws_signature::RSA_PSS_2048_8192_SHA512,
        pair => return Err(format!("no RSA {pair:?}")),
    };
    let key = aws_signature::RsaPublicKeyComponents {
        n: hex(&group["n"]),
        e: hex(&group["e"]),
    };
    for test in tests(group) {
        key.verify(
            algorithm,
            &hex(&asked(prompt, test)["message"]),
            &hex(&test["signature"]),
        )
        .map_err(|e| format!("tcId {}: {e}", id(test, "tcId")))?;
    }
    Ok(())
}

/// A set built here, which `acvptool` takes as one of the algorithm's.
fn built(algorithm: &str, mode: Option<&str>, revision: &str, groups: Vec<Value>) -> Value {
    let mut set = json!({"algorithm": algorithm, "revision": revision, "testGroups": groups});
    if let Some(mode) = mode {
        set["mode"] = json!(mode);
    }
    set
}

/// KAS-ECC-SSC with ephemeral keys on each NIST curve: CAVP's ECDH primitive
/// vectors, half with a corrupted shared secret, which the module must
/// refuse; then shared secrets with keys the test generates.
fn kas_ecc_ssc() -> Vec<Set> {
    let text = fs::read_to_string(
        root().join("thirdparty/vectors/cavp/ecdh/KAS_ECC_CDH_PrimitiveTest.txt"),
    )
    .unwrap();
    let mut val = Vec::new();
    let mut aft = Vec::new();
    let mut servers = HashMap::new();
    let mut curve = "";
    let mut fields = HashMap::new();
    let mut tc = 0u64;
    for line in text.lines() {
        if let Some(name) = line.strip_prefix('[').and_then(|l| l.strip_suffix(']')) {
            curve = name;
            continue;
        }
        let Some((key, value)) = line.split_once(" = ") else {
            continue;
        };
        if !["P-256", "P-384", "P-521"].contains(&curve) {
            continue;
        }
        fields.insert(key.to_owned(), value.to_owned());
        if key != "ZIUT" {
            continue;
        }
        tc += 1;
        let mut z = fields["ZIUT"].clone();
        let refused = tc.is_multiple_of(2);
        if refused {
            // Flip the last byte.
            let last = u8::from_str_radix(&z[z.len() - 2..], 16).unwrap() ^ 1;
            z.replace_range(z.len() - 2.., &format!("{last:02x}"));
        }
        val.push((
            curve,
            json!({
                "tcId": tc,
                "ephemeralPublicServerX": fields["QCAVSx"],
                "ephemeralPublicServerY": fields["QCAVSy"],
                "ephemeralPrivateIut": fields["dIUT"],
                "ephemeralPublicIutX": fields["QIUTx"],
                "ephemeralPublicIutY": fields["QIUTy"],
                "z": z,
                "testPassed": !refused,
            }),
        ));
    }
    for (curve, algorithm, len) in [
        ("P-256", &agreement::ECDH_P256, 32),
        ("P-384", &agreement::ECDH_P384, 48),
        ("P-521", &agreement::ECDH_P521, 66),
    ] {
        for _ in 0..10 {
            tc += 1;
            let key = agreement::PrivateKey::generate(algorithm).unwrap();
            let public = key.compute_public_key().unwrap();
            let (x, y) = public.as_ref()[1..].split_at(len);
            aft.push((
                curve,
                json!({
                    "tcId": tc,
                    "ephemeralPublicServerX": hex::encode(x),
                    "ephemeralPublicServerY": hex::encode(y),
                }),
            ));
            servers.insert(tc, (key, algorithm, len));
        }
    }
    let group = |tg: u64, kind: &str, curve: &str, tests: Vec<Value>| {
        json!({
            "tgId": tg,
            "testType": kind,
            "domainParameterGenerationMode": curve,
            "kasRole": if tg.is_multiple_of(2) { "responder" } else { "initiator" },
            "scheme": "ephemeralUnified",
            "tests": tests,
        })
    };
    let by_curve = |tests: &[(&str, Value)], curve: &str| -> Vec<Value> {
        tests
            .iter()
            .filter(|(c, _)| *c == curve)
            .map(|(_, t)| t.clone())
            .collect()
    };
    let curves = ["P-256", "P-384", "P-521"];
    let val_groups: Vec<Value> = curves
        .iter()
        .zip(1..)
        .map(|(curve, tg)| group(tg, "VAL", curve, by_curve(&val, curve)))
        .collect();
    let aft_groups: Vec<Value> = curves
        .iter()
        .zip(4..)
        .map(|(curve, tg)| group(tg, "AFT", curve, by_curve(&aft, curve)))
        .collect();

    let expected = built("KAS-ECC-SSC", None, "Sp800-56Ar3", val_groups.clone());
    let mut prompt = expected.clone();
    for test in prompt["testGroups"]
        .as_array_mut()
        .unwrap()
        .iter_mut()
        .flat_map(|group| group["tests"].as_array_mut().unwrap())
    {
        let test = test.as_object_mut().unwrap();
        for answer in ["ephemeralPublicIutX", "ephemeralPublicIutY", "testPassed"] {
            test.remove(answer);
        }
    }
    let validate = move |_: &Value, group: &Value| -> Result<(), String> {
        for test in tests(group) {
            let (key, algorithm, len) = &servers[&id(test, "tcId")];
            let iut = point(
                &test["ephemeralPublicIutX"],
                &test["ephemeralPublicIutY"],
                *len,
            );
            let z = agreement::agree(
                key,
                agreement::UnparsedPublicKey::new(algorithm, &iut),
                "the IUT's public key",
                |z| Ok(z.to_vec()),
            )?;
            if z != hex(&test["z"]) {
                return Err(format!("tcId {}: another shared secret", id(test, "tcId")));
            }
        }
        Ok(())
    };
    vec![
        Set {
            prompt,
            check: Check::Answers(expected),
        },
        Set {
            prompt: built("KAS-ECC-SSC", None, "Sp800-56Ar3", aft_groups),
            check: Check::Validate(Box::new(validate)),
        },
    ]
}

fn wycheproof(name: &str) -> Value {
    read(&format!(
        "thirdparty/vectors/wycheproof/testvectors_v1/{name}.json"
    ))
}

/// PBKDF2 from Wycheproof's vectors that SP 800-132's bounds, which the
/// module enforces, admit: passwords of 14 bytes or more, salts of 16 or
/// more, keys of 14 or more, and at least 1000 iterations.
fn pbkdf() -> Set {
    let mut groups = Vec::new();
    for (file, hash) in [
        ("pbkdf2_hmacsha1_test", "SHA-1"),
        ("pbkdf2_hmacsha256_test", "SHA2-256"),
        ("pbkdf2_hmacsha384_test", "SHA2-384"),
        ("pbkdf2_hmacsha512_test", "SHA2-512"),
    ] {
        let mut kept = Vec::new();
        for test in wycheproof(file)["testGroups"]
            .as_array()
            .unwrap()
            .iter()
            .flat_map(tests)
        {
            let password = hex(&test["password"]);
            let (salt, dk) = (hex(&test["salt"]), hex(&test["dk"]));
            let iterations = test["iterationCount"].as_u64().unwrap();
            let admitted = password.len() >= 14 && salt.len() >= 16 && dk.len() >= 14;
            // ACVP carries the password as text.
            let Ok(password) = String::from_utf8(password) else {
                continue;
            };
            if test["result"] != "valid" || !admitted || iterations < 1000 {
                continue;
            }
            kept.push(json!({
                "tcId": groups.len() as u64 * 1000 + id(test, "tcId"),
                "keyLen": dk.len() * 8,
                "salt": hex::encode(&salt),
                "password": password,
                "iterationCount": iterations,
                "derivedKey": hex::encode(&dk),
            }));
        }
        assert!(!kept.is_empty(), "{file}: no test the module admits");
        groups.push(json!({
            "tgId": groups.len() + 1,
            "testType": "AFT",
            "hmacAlg": hash,
            "tests": kept,
        }));
    }
    let expected = built("PBKDF", None, "1.0", groups);
    let mut prompt = expected.clone();
    for group in prompt["testGroups"].as_array_mut().unwrap() {
        for test in group["tests"].as_array_mut().unwrap() {
            test.as_object_mut().unwrap().remove("derivedKey");
        }
    }
    Set {
        prompt,
        check: Check::Answers(expected),
    }
}

/// RSA verification of Wycheproof's signatures under keys with exponent
/// 65537, which the module requires: FIPS 186-5's sizes and hashes, and
/// FIPS 186-4's legacy 1024-bit keys and SHA-1 from their signing vectors,
/// half corrupted. Wycheproof's "acceptable" signatures are left out.
fn rsa_sig_ver() -> Vec<Set> {
    let mut current = Vec::new();
    let mut legacy = Vec::new();
    let mut tc = 0u64;
    let mut add = |groups: &mut Vec<Value>,
                   scheme: &str,
                   hash: &str,
                   key: &Value,
                   tests: Vec<(Vec<u8>, Vec<u8>, bool)>| {
        if key["publicExponent"] != "010001" || tests.is_empty() {
            return;
        }
        let n = hex(&key["modulus"]);
        let n = &n[n.iter().position(|&b| b != 0).unwrap()..];
        let tests: Vec<Value> = tests
            .into_iter()
            .map(|(message, signature, valid)| {
                tc += 1;
                json!({
                    "tcId": tc,
                    "message": hex::encode(message),
                    "signature": hex::encode(signature),
                    "testPassed": valid,
                })
            })
            .collect();
        let mut group = json!({
            "tgId": groups.len() + 1,
            "testType": "GDT",
            "sigType": scheme,
            "modulo": n.len() * 8,
            "hashAlg": hash,
            "n": hex::encode(n),
            "e": "010001",
            "tests": tests,
        });
        if scheme == "pss" {
            group["maskFunction"] = json!("mgf1");
        }
        groups.push(group);
    };
    let acvp_hash = |sha: &str| match sha {
        "SHA-1" => Some("SHA-1"),
        "SHA-256" => Some("SHA2-256"),
        "SHA-384" => Some("SHA2-384"),
        "SHA-512" => Some("SHA2-512"),
        _ => None,
    };
    let verify_files = [
        "rsa_signature_2048_sha256_test",
        "rsa_signature_2048_sha384_test",
        "rsa_signature_2048_sha512_test",
        "rsa_signature_3072_sha256_test",
        "rsa_signature_3072_sha384_test",
        "rsa_signature_3072_sha512_test",
        "rsa_signature_4096_sha256_test",
        "rsa_signature_4096_sha384_test",
        "rsa_signature_4096_sha512_test",
        "rsa_pss_2048_sha256_mgf1_32_test",
        "rsa_pss_2048_sha384_mgf1_48_test",
        "rsa_pss_3072_sha256_mgf1_32_test",
        "rsa_pss_4096_sha256_mgf1_32_test",
        "rsa_pss_4096_sha384_mgf1_48_test",
        "rsa_pss_4096_sha512_mgf1_64_test",
    ];
    for file in verify_files {
        let scheme = if file.starts_with("rsa_pss") {
            "pss"
        } else {
            "pkcs1v1.5"
        };
        for group in wycheproof(file)["testGroups"].as_array().unwrap() {
            let hash = acvp_hash(group["sha"].as_str().unwrap()).unwrap();
            let tests = tests(group)
                .iter()
                .filter(|test| test["result"] != "acceptable")
                .map(|test| {
                    (
                        hex(&test["msg"]),
                        hex(&test["sig"]),
                        test["result"] == "valid",
                    )
                })
                .collect();
            add(&mut current, scheme, hash, &group["publicKey"], tests);
        }
    }
    for file in [
        "rsa_pkcs1_1024_sig_gen_test",
        "rsa_pkcs1_2048_sig_gen_test",
        "rsa_pkcs1_3072_sig_gen_test",
        "rsa_pkcs1_4096_sig_gen_test",
    ] {
        for group in wycheproof(file)["testGroups"].as_array().unwrap() {
            let sha = group["sha"].as_str().unwrap();
            let legacy_hash = if file.contains("_1024_") {
                ["SHA-1", "SHA-256", "SHA-512"].contains(&sha)
            } else {
                sha == "SHA-1"
            };
            if !legacy_hash {
                continue;
            }
            let tests = tests(group)
                .iter()
                // Wycheproof finds these weak, as "acceptable", but each
                // signs its message.
                .filter(|test| test["result"] != "invalid")
                .enumerate()
                .map(|(i, test)| {
                    let mut signature = hex(&test["sig"]);
                    let valid = i % 2 == 0;
                    if !valid {
                        let last = signature.len() - 1;
                        signature[last] ^= 1;
                    }
                    (hex(&test["msg"]), signature, valid)
                })
                .collect();
            add(
                &mut legacy,
                "pkcs1v1.5",
                acvp_hash(sha).unwrap(),
                &group["privateKey"],
                tests,
            );
        }
    }
    [("FIPS186-5", current), ("FIPS186-4", legacy)]
        .into_iter()
        .map(|(revision, groups)| {
            assert!(!groups.is_empty(), "no RSA {revision} verification");
            let expected = built("RSA", Some("sigVer"), revision, groups);
            let mut prompt = expected.clone();
            for group in prompt["testGroups"].as_array_mut().unwrap() {
                for test in group["tests"].as_array_mut().unwrap() {
                    test.as_object_mut().unwrap().remove("testPassed");
                }
            }
            Set {
                prompt,
                check: Check::Answers(expected),
            }
        })
        .collect()
}
