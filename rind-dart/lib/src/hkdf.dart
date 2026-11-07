// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

part of 'bindings.dart';

/// An HKDF algorithm.
final class HkdfAlgorithm {
  const HkdfAlgorithm._(this._hmac);

  final HmacAlgorithm _hmac;

  /// HKDF-SHA256.
  static const sha256 = HkdfAlgorithm._(HmacAlgorithm.sha256);

  /// HKDF-SHA384.
  static const sha384 = HkdfAlgorithm._(HmacAlgorithm.sha384);

  /// HKDF-SHA512.
  static const sha512 = HkdfAlgorithm._(HmacAlgorithm.sha512);

  @override
  String toString() => 'HKDF-${_hmac.toString().substring(5)}';
}

/// HKDF-SHA1, which only legacy protocols should use.
const hkdfSha1 = HkdfAlgorithm._(hmacSha1);

/// An HKDF salt, which extracts a [HkdfPrk] from a secret.
final class HkdfSalt extends _Handle {
  /// Makes a salt for [algorithm] from [value], which may be empty.
  HkdfSalt(HkdfAlgorithm algorithm, Uint8List value)
    : super(
        _newHandle(
          (out) => _hkdfSaltNew(
            algorithm._hmac._id,
            value.address,
            value.length,
            out,
          ),
        ),
        _hkdfSaltFinalizer,
      );

  /// Extracts a pseudorandom key from [secret] (HKDF-Extract).
  HkdfPrk extract(Uint8List secret) => HkdfPrk._(
    _newHandle(
      (out) => _hkdfExtract(_pointer, secret.address, secret.length, out),
    ),
  );
}

/// A pseudorandom key, which expands into any number of keys.
final class HkdfPrk extends _Handle {
  HkdfPrk._(Pointer<Void> pointer) : super(pointer, _hkdfPrkFinalizer);

  /// Derives [length] bytes for the concatenation of [info] (HKDF-Expand),
  /// throwing [RindError.wrongLength] past 255 hash outputs.
  Uint8List expand(List<Uint8List> info, int length) {
    final joined = BytesBuilder(copy: false);
    info.forEach(joined.add);
    final infoBytes = joined.takeBytes();
    return _output(
      length,
      (out) => _hkdfExpand(
        _pointer,
        infoBytes.address,
        infoBytes.length,
        out.address,
        out.length,
      ),
    );
  }
}
