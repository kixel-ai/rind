//! Every operation of rind's API that handles a secret, each timed once for
//! every secret input it takes.
//!
//! The fixed class holds one random secret, the random class a new one per
//! value. Every other input is the same for both. A comparison of a secret
//! against a presented value instead compares two wrong values, both
//! refused: the fixed one differs from the secret only in its last byte, and
//! the random ones almost always in their first. Whether a call fails is
//! public, but where the values first differ is not.
//!
//! Not timed, since rind's API cannot set their secrets: key generation and
//! encapsulation, which draw them from the system, and an ML-KEM
//! decapsulation key, which rind can neither import nor copy, so its fixed
//! class could not be separate values of one secret.

use std::num::NonZeroU32;
use std::sync::OnceLock;

use rind::{
    aead, agreement, cipher, constant_time, digest, hkdf, hmac, kem, key_wrap, pbkdf2, rsa,
    signature,
};

use crate::dudect::{Classes, Config, Report, classes, measure, measure_in_place};

pub struct Case {
    pub name: String,
    pub run: Box<dyn Fn(&Config) -> Report>,
}

fn case(name: impl Into<String>, run: impl Fn(&Config) -> Report + 'static) -> Case {
    Case {
        name: name.into(),
        run: Box::new(run),
    }
}

/// Values in each class of byte strings and cheap keys.
const VALUES: usize = 64;
/// Values in each class of RSA keys, which take seconds to generate.
const RSA_KEYS: usize = 4;
/// A message length that takes the bulk path of every cipher and leaves a
/// partial final block.
const LEN: usize = 1347;
const MESSAGE: &[u8] = b"a public message";
const AAD: &[u8] = b"public associated data";
const NONCE: [u8; 12] = [7; 12];

/// The planted leak, which must be seen, then the controls and every case.
pub fn all() -> Vec<Case> {
    let mut cases = vec![
        case("planted/early-exit-compare", |config| {
            let expected = random::<32>();
            measure(config, &mismatches(&expected), |b| {
                early_exit_eq(&expected, b)
            })
        }),
        // Both classes hold one secret, so nothing but the harness could
        // tell them apart: once with inputs copied, once with keys read in
        // place.
        case("control/sha256-same-input", |config| {
            let data = random_vec(LEN);
            let inputs = classes(VALUES, fixed(data.clone()), fixed(data));
            measure(config, &inputs, |data| {
                digest::digest(&digest::SHA256, data)
            })
        }),
        case("control/aes-128-gcm-same-key", |config| {
            let secret = random::<16>();
            let new = || aead::Key::new(&aead::AES_128_GCM, &secret).unwrap();
            let plaintext = random::<LEN>();
            measure_in_place(config, &classes(VALUES, new, new), |key| {
                let mut buf = plaintext;
                let nonce = aead::Nonce::assume_unique_for_key(NONCE);
                key.seal_in_place_separate_tag(nonce, AAD, &mut buf)
            })
        }),
        case("constant_time/verify", |config| {
            let expected = random::<32>();
            measure(config, &mismatches(&expected), |b| {
                constant_time::verify(&expected, b)
            })
        }),
    ];

    for (name, algorithm) in [
        ("md5", &digest::legacy::MD5),
        ("sha1", &digest::legacy::SHA1),
        ("sha256", &digest::SHA256),
        ("sha512", &digest::SHA512),
        ("sha3-256", &digest::SHA3_256),
    ] {
        cases.push(case(format!("digest/{name}"), move |config| {
            measure(config, &secrets(LEN), |data| {
                digest::digest(algorithm, data)
            })
        }));
    }

    hmac_cases(&mut cases);
    kdf_cases(&mut cases);
    aead_cases(&mut cases);
    cipher_cases(&mut cases);
    agreement_cases(&mut cases);
    kem_cases(&mut cases);
    rsa_cases(&mut cases);
    signature_cases(&mut cases);
    cases
}

fn hmac_cases(cases: &mut Vec<Case>) {
    cases.push(case("hmac/sha256/key", |config| {
        measure(config, &secrets(32), |key| {
            hmac::Key::new(&hmac::HMAC_SHA256, key)
        })
    }));
    for (name, algorithm) in [
        ("sha256", &hmac::HMAC_SHA256),
        ("sha512", &hmac::HMAC_SHA512),
    ] {
        cases.push(case(format!("hmac/{name}/sign"), move |config| {
            let keys = keys(32, |key| hmac::Key::new(algorithm, key));
            measure(config, &keys, |key| hmac::sign(key, MESSAGE))
        }));
    }
    cases.push(case("hmac/sha256/verify", |config| {
        let key = hmac::Key::new(&hmac::HMAC_SHA256, &random::<32>());
        let tag = hmac::sign(&key, MESSAGE);
        measure(config, &mismatches(tag.as_ref()), |tag| {
            hmac::verify(&key, MESSAGE, tag)
        })
    }));
}

fn kdf_cases(cases: &mut Vec<Case>) {
    let salt = || hkdf::Salt::new(&hkdf::HKDF_SHA256, b"public salt");
    cases.push(case("hkdf/sha256/extract", move |config| {
        let salt = salt();
        measure(config, &secrets(32), |secret| salt.extract(secret))
    }));
    cases.push(case("hkdf/sha256/expand", move |config| {
        let salt = salt();
        let prks = keys(32, |secret| salt.extract(secret));
        measure_in_place(config, &prks, |prk| {
            let mut out = [0; 32];
            prk.expand(&[b"public info"], out.len())
                .fill(&mut out)
                .map(|()| out)
        })
    }));

    let iterations = NonZeroU32::new(2).unwrap();
    cases.push(case("pbkdf2/sha256/derive", move |config| {
        measure(config, &secrets(16), |password| {
            let mut out = [0; 32];
            pbkdf2::Secret::new(&pbkdf2::PBKDF2_HMAC_SHA256, password)
                .derive(iterations, b"public salt", &mut out)
                .map(|()| out)
        })
    }));
    cases.push(case("pbkdf2/sha256/verify", move |config| {
        let secret = pbkdf2::Secret::new(&pbkdf2::PBKDF2_HMAC_SHA256, &random::<16>());
        let mut derived = [0; 32];
        secret
            .derive(iterations, b"public salt", &mut derived)
            .unwrap();
        measure(config, &mismatches(&derived), |derived| {
            secret.verify(iterations, b"public salt", derived)
        })
    }));
}

fn aead_cases(cases: &mut Vec<Case>) {
    for (name, algorithm) in [
        ("aes-128-gcm", &aead::AES_128_GCM),
        ("aes-192-gcm", &aead::AES_192_GCM),
        ("aes-256-gcm", &aead::AES_256_GCM),
        ("chacha20-poly1305", &aead::CHACHA20_POLY1305),
    ] {
        let len = algorithm.key_len();
        let new = move |key: &[u8]| aead::Key::new(algorithm, key).unwrap();
        let nonce = || aead::Nonce::assume_unique_for_key(NONCE);

        cases.push(case(format!("aead/{name}/key"), move |config| {
            measure(config, &secrets(len), |key| aead::Key::new(algorithm, key))
        }));
        cases.push(case(format!("aead/{name}/seal-key"), move |config| {
            let plaintext = random::<LEN>();
            measure_in_place(config, &keys(len, new), |key| {
                let mut buf = plaintext;
                key.seal_in_place_separate_tag(nonce(), AAD, &mut buf)
            })
        }));
        cases.push(case(format!("aead/{name}/seal-plaintext"), move |config| {
            let key = new(&random::<32>()[..len]);
            let plaintexts = classes(VALUES, fixed(random::<LEN>()), random::<LEN>);
            measure(config, &plaintexts, |plaintext| {
                let mut buf = *plaintext;
                key.seal_in_place_separate_tag(nonce(), AAD, &mut buf)
            })
        }));
        cases.push(case(
            format!("aead/{name}/open-ciphertext"),
            move |config| {
                let key = new(&random::<32>()[..len]);
                let seal = || {
                    let mut buf = random::<LEN>();
                    let tag = key.seal_in_place_separate_tag(nonce(), AAD, &mut buf);
                    (buf, tag.unwrap())
                };
                let ciphertexts = classes(VALUES, fixed(seal()), seal);
                measure(config, &ciphertexts, |(ciphertext, tag)| {
                    let mut buf = *ciphertext;
                    key.open_in_place_separate_tag(nonce(), AAD, *tag, &mut buf)
                        .map(|plaintext| plaintext[0])
                })
            },
        ));
        cases.push(case(format!("aead/{name}/open-tag"), move |config| {
            let key = new(&random::<32>()[..len]);
            let mut ciphertext = random::<LEN>();
            let tag = key
                .seal_in_place_separate_tag(nonce(), AAD, &mut ciphertext)
                .unwrap();
            measure(config, &mismatches(tag.as_ref()), |tag| {
                let mut buf = ciphertext;
                let tag = aead::Tag::try_from(&tag[..]).unwrap();
                key.open_in_place_separate_tag(nonce(), AAD, tag, &mut buf)
                    .map(|plaintext| plaintext[0])
            })
        }));
    }

    cases.push(case("aead/xchacha20-poly1305/seal-key", |config| {
        let keys = keys(32, |key| {
            aead::RandomizedNonceKey::new(key.try_into().unwrap())
        });
        let plaintext = random::<LEN>();
        measure_in_place(config, &keys, |key| {
            let mut buf = Vec::with_capacity(LEN + 16);
            buf.extend_from_slice(&plaintext);
            key.seal_in_place_append_tag(AAD, &mut buf)
        })
    }));

    // WebCrypto's AES-GCM: any IV length, truncated tags.
    cases.push(case("aead/gcm-truncated/open-tag", |config| {
        use aead::gcm::{Iv, Key, TagLength};
        let key = Key::new(&cipher::AES_128, &random::<16>(), TagLength::Truncated96).unwrap();
        let iv = random::<16>();
        let mut ciphertext = random::<LEN>();
        let tag = key
            .seal_in_place_separate_tag(
                Iv::assume_unique_for_key(&iv).unwrap(),
                AAD,
                &mut ciphertext,
            )
            .unwrap();
        measure(config, &mismatches(tag.as_ref()), |tag| {
            let mut buf = ciphertext;
            let iv = Iv::assume_unique_for_key(&iv).unwrap();
            key.open_in_place_separate_tag(iv, AAD, tag, &mut buf)
                .map(|plaintext| plaintext[0])
        })
    }));

    for (name, algorithm) in [
        ("aes-128", &aead::quic::AES_128),
        ("aes-256", &aead::quic::AES_256),
        ("chacha20", &aead::quic::CHACHA20),
    ] {
        cases.push(case(format!("quic/{name}/mask"), move |config| {
            let sample = random::<{ aead::quic::SAMPLE_LEN }>();
            measure(config, &secrets(algorithm.key_len()), |key| {
                aead::quic::HeaderProtectionKey::new(algorithm, key).map(|key| key.mask(&sample))
            })
        }));
    }
}

fn cipher_cases(cases: &mut Vec<Case>) {
    for (name, algorithm, len) in [
        ("aes-128", &cipher::AES_128, 16),
        ("aes-192", &cipher::AES_192, 24),
        ("aes-256", &cipher::AES_256, 32),
    ] {
        cases.push(case(format!("cipher/{name}/key"), move |config| {
            let block = random::<16>();
            measure(config, &secrets(len), |key| {
                let mut block = block;
                cipher::Aes::new(algorithm, key).map(|aes| {
                    aes.encrypt_block(&mut block);
                    block
                })
            })
        }));
    }
    cases.push(case("cipher/aes-256/block", |config| {
        let aes = cipher::Aes::new(&cipher::AES_256, &random::<32>()).unwrap();
        let blocks = classes(VALUES, fixed(random::<16>()), random::<16>);
        measure(config, &blocks, |block| {
            let mut block = *block;
            aes.encrypt_block(&mut block);
            block
        })
    }));
    cases.push(case("cipher/aes-128-ctr/key", |config| {
        let counter = random::<16>();
        measure(config, &secrets(16), |key| {
            let mut buf = [0; 256];
            cipher::AesCtr::new(&cipher::AES_128, key, 32)
                .and_then(|ctr| ctr.apply_keystream(&counter, &mut buf))
                .map(|()| buf)
        })
    }));
    cases.push(case("cipher/chacha20/key", |config| {
        measure(config, &secrets(32), |key| {
            let mut buf = [0; 256];
            cipher::ChaCha20::new(key[..].try_into().unwrap())
                .apply_keystream(&NONCE, 0, &mut buf)
                .map(|()| buf)
        })
    }));

    let iv = [9; 16];
    cases.push(case("cipher/aes-128-cbc/encrypt", move |config| {
        let key = cipher::AesCbcEncryptingKey::new(&cipher::AES_128, &random::<16>()).unwrap();
        let plaintexts = classes(VALUES, fixed(random::<256>()), random::<256>);
        measure(config, &plaintexts, |plaintext| {
            let mut buf = *plaintext;
            key.encrypt_blocks(&iv, &mut buf).map(|()| buf)
        })
    }));
    // Padding a decryption refuses: a valid padding's length is public once
    // the call returns, but which bytes broke an invalid one is not.
    cases.push(case("cipher/aes-128-cbc/decrypt-padding", move |config| {
        let secret = random::<16>();
        let encrypt = cipher::AesCbcEncryptingKey::new(&cipher::AES_128, &secret).unwrap();
        let decrypt = cipher::AesCbcDecryptingKey::new(&cipher::AES_128, &secret).unwrap();
        let invalid = || loop {
            let mut buf = random::<64>();
            if !valid_padding(&buf) {
                encrypt.encrypt_blocks(&iv, &mut buf).unwrap();
                return buf;
            }
        };
        let ciphertexts = classes(VALUES, fixed(invalid()), invalid);
        measure(config, &ciphertexts, |ciphertext| {
            let mut buf = *ciphertext;
            decrypt
                .decrypt(&iv, &mut buf)
                .map(|plaintext| plaintext.len())
        })
    }));

    let wrap_key = || key_wrap::AesKek::new(&key_wrap::AES_256, &random::<32>()).unwrap();
    cases.push(case("key-wrap/aes-256/wrap-kek", |config| {
        let keys = keys(32, |kek| {
            key_wrap::AesKek::new(&key_wrap::AES_256, kek).unwrap()
        });
        let key = random::<32>();
        measure_in_place(config, &keys, |kek| {
            let mut wrapped = [0; 40];
            kek.wrap(&key, &mut wrapped).map(|()| wrapped)
        })
    }));
    cases.push(case("key-wrap/aes-256/wrap-key", move |config| {
        let kek = wrap_key();
        measure(
            config,
            &classes(VALUES, fixed(random::<32>()), random::<32>),
            |key| {
                let mut wrapped = [0; 40];
                kek.wrap(key, &mut wrapped).map(|()| wrapped)
            },
        )
    }));
    cases.push(case("key-wrap/aes-256/unwrap-integrity", move |config| {
        let kek = wrap_key();
        let mut wrapped = [0; 40];
        kek.wrap(&random::<32>(), &mut wrapped).unwrap();
        measure(config, &mismatches(&wrapped), |wrapped| {
            let mut key = [0; 32];
            kek.unwrap(wrapped, &mut key).map(|()| key)
        })
    }));
    cases.push(case(
        "key-wrap/aes-256/unwrap-padded-integrity",
        move |config| {
            let kek = wrap_key();
            let mut wrapped = [0; 32];
            kek.wrap_padded(&random::<20>(), &mut wrapped).unwrap();
            measure(config, &mismatches(&wrapped), |wrapped| {
                let mut key = [0; 24];
                kek.unwrap_padded(wrapped, &mut key).map(|key| key.len())
            })
        },
    ));
}

fn agreement_cases(cases: &mut Vec<Case>) {
    for (name, algorithm) in [
        ("x25519", &agreement::X25519),
        ("p256", &agreement::ECDH_P256),
        ("p384", &agreement::ECDH_P384),
        ("p521", &agreement::ECDH_P521),
    ] {
        let generate = move || agreement::PrivateKey::generate(algorithm).unwrap();
        let scalar = move || generate().to_scalar().as_ref().to_vec();
        let from_scalar = move |s: &[u8]| agreement::PrivateKey::from_scalar(algorithm, s);

        cases.push(case(
            format!("agreement/{name}/public-key"),
            move |config| {
                let scalars = classes(VALUES, fixed(scalar()), scalar);
                measure(config, &scalars, |s| {
                    from_scalar(s).map(|key| key.public_key())
                })
            },
        ));
        cases.push(case(format!("agreement/{name}/agree-key"), move |config| {
            let peer = generate().public_key();
            let fixed_scalar = scalar();
            let keys = classes(
                VALUES,
                || from_scalar(&fixed_scalar).unwrap(),
                || from_scalar(&scalar()).unwrap(),
            );
            measure_in_place(config, &keys, |key| key.agree(peer.as_ref()))
        }));
        cases.push(case(
            format!("agreement/{name}/agree-peer"),
            move |config| {
                let key = generate();
                let peer = move || generate().public_key().as_ref().to_vec();
                let peers = classes(VALUES, fixed(peer()), peer);
                measure(config, &peers, |peer| key.agree(peer))
            },
        ));
    }
}

fn kem_cases(cases: &mut Vec<Case>) {
    let setup = || {
        let key = kem::DecapsulationKey::generate(&kem::ML_KEM_768).unwrap();
        let public = key.public_key();
        let encapsulate = move || public.encapsulate().unwrap().0.as_ref().to_vec();
        (key, encapsulate)
    };
    cases.push(case("kem/ml-kem-768/decapsulate", move |config| {
        let (key, encapsulate) = setup();
        let ciphertexts = classes(VALUES, fixed(encapsulate()), encapsulate);
        measure(config, &ciphertexts, |c| key.decapsulate(c))
    }));
    // A tampered ciphertext must cost what a valid one does, or the implicit
    // rejection that hides it is undone.
    cases.push(case("kem/ml-kem-768/decapsulate-reject", move |config| {
        let (key, encapsulate) = setup();
        let valid = encapsulate();
        let tampered = || {
            let mut c = valid.clone();
            let [at, flip] = random::<2>();
            let at = usize::from(at) * c.len() / 256;
            c[at] ^= flip | 1;
            c
        };
        let ciphertexts = classes(VALUES, fixed(valid.clone()), tampered);
        measure(config, &ciphertexts, |c| key.decapsulate(c))
    }));
}

fn rsa_cases(cases: &mut Vec<Case>) {
    for (bits, size) in RSA_SIZES {
        let name = |op: &str| format!("rsa-{bits}/{op}");
        cases.push(case(name("from-pkcs8"), move |config| {
            measure(config, rsa_keys(size), |der| {
                signature::RsaKeyPair::from_pkcs8(der)
            })
        }));
        cases.push(case(name("sign-key"), move |config| {
            let keys = rsa_keys(size).each_ref().map(|ders| {
                ders.iter()
                    .map(|der| signature::RsaKeyPair::from_pkcs8(der).unwrap())
                    .collect()
            });
            measure_in_place(config, &keys, |key| {
                key.sign(&signature::sign::RSA_PKCS1_SHA256, MESSAGE)
            })
        }));
        cases.push(case(name("sign-message"), move |config| {
            let key = signature::RsaKeyPair::from_pkcs8(&rsa_keys(size)[0][0]).unwrap();
            let messages = classes(VALUES, fixed(random::<32>()), random::<32>);
            measure(config, &messages, |message| {
                key.sign(&signature::sign::RSA_PKCS1_SHA256, message)
            })
        }));
        cases.push(case(name("oaep-decrypt-key"), move |config| {
            let message = random::<32>();
            let keys = rsa_keys(size).each_ref().map(|ders| {
                ders.iter()
                    .map(|der| {
                        let key = rsa::DecryptingKey::from_pkcs8(&rsa::OAEP_SHA256, der).unwrap();
                        let c = key.public_key().encrypt(&message, b"").unwrap();
                        (key, c)
                    })
                    .collect()
            });
            measure_in_place(config, &keys, |(key, c)| key.decrypt(c.as_ref(), b""))
        }));
        cases.push(case(name("oaep-decrypt-ciphertext"), move |config| {
            let key =
                rsa::DecryptingKey::from_pkcs8(&rsa::OAEP_SHA256, &rsa_keys(size)[0][0]).unwrap();
            let public = key.public_key();
            let encrypt = || {
                public
                    .encrypt(&random::<32>(), b"")
                    .unwrap()
                    .as_ref()
                    .to_vec()
            };
            let ciphertexts = classes(VALUES, fixed(encrypt()), encrypt);
            measure(config, &ciphertexts, |c| key.decrypt(c, b""))
        }));
    }
}

/// The sizes with their own code: on x86_64, aws-lc's RSAZ for 2048, its
/// AVX-512 RSAZ for 2048, 3072, and 4096, and the generic exponentiation the
/// others share with CPUs that lack them.
const RSA_SIZES: [(u32, rsa::KeySize); 3] = [
    (2048, rsa::KeySize::Rsa2048),
    (3072, rsa::KeySize::Rsa3072),
    (4096, rsa::KeySize::Rsa4096),
];

/// PKCS#8 encodings of RSA keys of `size`, generated once. The random keys
/// encode to the fixed key's length, since a component's length is public in
/// practice and would otherwise be what the parse's time depends on.
fn rsa_keys(size: rsa::KeySize) -> &'static Classes<Vec<u8>> {
    static KEYS: [OnceLock<Classes<Vec<u8>>>; 3] = [const { OnceLock::new() }; 3];
    let i = RSA_SIZES.iter().position(|&(_, s)| s == size).unwrap();
    KEYS[i].get_or_init(|| {
        let generate = || {
            signature::RsaKeyPair::generate(size)
                .unwrap()
                .to_pkcs8()
                .as_ref()
                .to_vec()
        };
        let fixed_key = generate();
        let len = fixed_key.len();
        classes(RSA_KEYS, fixed(fixed_key), || {
            std::iter::repeat_with(generate)
                .find(|der| der.len() == len)
                .unwrap()
        })
    })
}

fn signature_cases(cases: &mut Vec<Case>) {
    for (name, algorithm) in [
        ("p256", &signature::sign::ECDSA_P256_SHA256_FIXED),
        ("p384", &signature::sign::ECDSA_P384_SHA384_FIXED),
        ("p521", &signature::sign::ECDSA_P521_SHA512_FIXED),
    ] {
        let der = move || {
            signature::EcdsaKeyPair::generate(algorithm)
                .unwrap()
                .to_pkcs8()
                .as_ref()
                .to_vec()
        };
        let from = move |der: &[u8]| signature::EcdsaKeyPair::from_pkcs8(algorithm, der).unwrap();

        cases.push(case(format!("ecdsa/{name}/from-pkcs8"), move |config| {
            let ders = classes(VALUES, fixed(der()), der);
            measure(config, &ders, |der| {
                signature::EcdsaKeyPair::from_pkcs8(algorithm, der)
            })
        }));
        cases.push(case(format!("ecdsa/{name}/sign-key"), move |config| {
            let fixed_der = der();
            let keys = classes(VALUES, || from(&fixed_der), || from(&der()));
            measure_in_place(config, &keys, |key| key.sign(MESSAGE))
        }));
        cases.push(case(format!("ecdsa/{name}/sign-message"), move |config| {
            let key = from(&der());
            let messages = classes(VALUES, fixed(random::<32>()), random::<32>);
            measure(config, &messages, |message| key.sign(message))
        }));
    }

    let seed = || {
        signature::Ed25519KeyPair::generate()
            .unwrap()
            .to_seed()
            .as_ref()
            .to_vec()
    };
    let from = |seed: &[u8]| signature::Ed25519KeyPair::from_seed(seed).unwrap();
    cases.push(case("ed25519/from-seed", move |config| {
        let seeds = classes(VALUES, fixed(seed()), seed);
        measure(config, &seeds, |seed| {
            signature::Ed25519KeyPair::from_seed(seed)
        })
    }));
    cases.push(case("ed25519/sign-key", move |config| {
        let fixed_seed = seed();
        let keys = classes(VALUES, || from(&fixed_seed), || from(&seed()));
        measure_in_place(config, &keys, |key| key.sign(MESSAGE))
    }));
    // The message picks the nonce, so it is a secret input too.
    cases.push(case("ed25519/sign-message", move |config| {
        let key = from(&seed());
        let messages = classes(VALUES, fixed(random::<32>()), random::<32>);
        measure(config, &messages, |message| key.sign(message))
    }));
}

fn random<const N: usize>() -> [u8; N] {
    let mut bytes = [0; N];
    rind::rand::fill(&mut bytes).unwrap();
    bytes
}

fn random_vec(len: usize) -> Vec<u8> {
    let mut bytes = vec![0; len];
    rind::rand::fill(&mut bytes).unwrap();
    bytes
}

/// A function that clones `value`, for a fixed class.
fn fixed<T: Clone>(value: T) -> impl FnMut() -> T {
    move || value.clone()
}

/// Secret byte strings of `len`.
fn secrets(len: usize) -> Classes<Vec<u8>> {
    classes(VALUES, fixed(random_vec(len)), || random_vec(len))
}

/// Keys made by `new` from secrets of `len` bytes.
fn keys<K>(len: usize, new: impl Fn(&[u8]) -> K) -> Classes<K> {
    let secret = random_vec(len);
    classes(VALUES, || new(&secret), || new(&random_vec(len)))
}

/// Wrong values to compare `expected` with: the fixed one differs only in
/// its last byte.
fn mismatches(expected: &[u8]) -> Classes<Vec<u8>> {
    let mut last = expected.to_vec();
    *last.last_mut().unwrap() ^= 1;
    classes(VALUES, fixed(last), || {
        loop {
            let value = random_vec(expected.len());
            if value != expected {
                return value;
            }
        }
    })
}

/// A comparison that stops at the first difference, which the harness must
/// find.
#[inline(never)]
fn early_exit_eq(a: &[u8], b: &[u8]) -> bool {
    // `black_box` keeps the compiler from turning the loop into `bcmp`,
    // whose wide loads compare 32 bytes without exiting early.
    a.len() == b.len() && a.iter().zip(b).all(|(x, y)| std::hint::black_box(*x) == *y)
}

/// Whether the last block of `plaintext` ends in valid PKCS#7 padding.
fn valid_padding(plaintext: &[u8]) -> bool {
    let n = usize::from(*plaintext.last().unwrap());
    (1..=16).contains(&n)
        && plaintext[plaintext.len() - n..]
            .iter()
            .all(|&b| usize::from(b) == n)
}
