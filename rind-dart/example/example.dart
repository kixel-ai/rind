// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

import 'dart:convert';
import 'dart:typed_data';

import 'package:rind/rind.dart';

void main() {
  final key = Uint8List(32);
  fillRandom(key);

  final aead = AeadKey(AeadAlgorithm.chacha20Poly1305, key);
  // Never reuse a nonce with one key; RandomizedNonceKey picks its own.
  final nonce = Nonce.assumeUniqueForKey(Uint8List(12));
  final sealed = aead.seal(nonce, utf8.encode('hello'));
  print(utf8.decode(aead.open(nonce, sealed)));

  // Each signature algorithm has a key pair and a public key; the peer
  // parses the public key from its encoding or its SubjectPublicKeyInfo.
  final ecdsa = EcdsaKeyPair.generate(EcdsaSigningAlgorithm.p256Sha256Asn1);
  EcdsaPublicKey(
    EcdsaVerificationAlgorithm.p256Sha256Asn1,
    ecdsa.publicKey.bytes,
  ).verify(utf8.encode('hello'), ecdsa.sign(utf8.encode('hello')));

  final ed25519 = Ed25519KeyPair.generate();
  Ed25519PublicKey.fromSpki(
    ed25519.publicKey.toSpki(),
  ).verify(utf8.encode('hello'), ed25519.sign(utf8.encode('hello')));

  // An RSA public key verifies with any algorithm whose modulus floor it
  // meets.
  final rsa = RsaKeyPair.generate(RsaKeySize.rsa2048);
  RsaPublicKey(rsa.publicKey.bytes).verify(
    RsaVerificationAlgorithm.pssSha256,
    utf8.encode('hello'),
    rsa.sign(RsaSigningAlgorithm.pssSha256, utf8.encode('hello')),
  );

  final oaep = RsaDecryptingKey.generate(
    OaepAlgorithm.sha256,
    RsaKeySize.rsa2048,
  );
  final ciphertext = RsaEncryptingKey.fromSpki(
    OaepAlgorithm.sha256,
    oaep.publicKey.toSpki(),
  ).encrypt(utf8.encode('hello'));
  print(utf8.decode(oaep.decrypt(ciphertext)));
}
