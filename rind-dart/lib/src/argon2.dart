// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

part of 'bindings.dart';

/// How much memory and time Argon2id spends: RFC 9106's `m`, `t`, and `p`.
///
/// Deriving and verifying take these from the caller, never from the value
/// they check, so only the caller sets what a call costs: about its memory,
/// held for the call, and its passes times that much hashing.
final class Argon2Params extends _Handle {
  /// Takes [memoryKib] KiB of memory, [passes] passes over it, and [lanes]
  /// lanes.
  ///
  /// Throws [RindError.unsupported] below RFC 9106's minimums (one pass, one
  /// lane, and 8 KiB per lane) or with 2^24 lanes or more, and a
  /// [RangeError] for a value that does not fit in 32 bits. The memory is
  /// used in whole multiples of 4 KiB per lane, rounding down.
  Argon2Params(int memoryKib, int passes, int lanes)
    : super(
        _newHandle((out) {
          RangeError.checkValueInInterval(
            memoryKib,
            0,
            0xffffffff,
            'memoryKib',
          );
          RangeError.checkValueInInterval(passes, 0, 0xffffffff, 'passes');
          RangeError.checkValueInInterval(lanes, 0, 0xffffffff, 'lanes');
          return _argon2ParamsNew(memoryKib, passes, lanes, out);
        }),
        _argon2ParamsFinalizer,
      );

  /// RFC 9106's first recommendation: 2 GiB, one pass, and four lanes.
  static final firstRecommended = Argon2Params(1 << 21, 1, 4);

  /// RFC 9106's second recommendation, for when 2 GiB is too much: 64 MiB,
  /// three passes, and four lanes.
  static final secondRecommended = Argon2Params(1 << 16, 3, 4);
}

/// A password, kept for every salt and cost it derives with.
///
/// Deriving takes as long and as much memory as its [Argon2Params] ask, so
/// run it off the UI isolate, as with `Isolate.run`. The lanes are filled one
/// after another, on the calling thread.
final class Argon2Secret extends _Handle {
  /// Keeps a copy of [password], which may be any length below 2^32 bytes.
  Argon2Secret(Uint8List password)
    : super(
        _newHandle(
          (out) => _argon2SecretNew(password.address, password.length, out),
        ),
        _argon2SecretFinalizer,
      );

  /// Derives a [length]-byte key from [salt] at the cost [params] sets.
  ///
  /// Give each password its own [salt], such as 16 random bytes stored with
  /// the key. Throws [RindError.wrongLength] if [length] is below 4 or
  /// [salt] below 8 bytes, or either is 2^32 or more, and
  /// [RindError.outOfMemory] if the memory [params] asks for cannot be
  /// allocated.
  Uint8List derive(Argon2Params params, Uint8List salt, int length) {
    return _native(salt, (saltPointer) {
      return _native(Uint8List(length), (out) {
        _check(
          _argon2Derive(
            _pointer,
            params._pointer,
            saltPointer,
            salt.length,
            out,
            length,
          ),
        );
        return Uint8List.fromList(out.asTypedList(length));
      });
    });
  }

  /// Checks in constant time that [previouslyDerived] is what [derive] makes
  /// for [params] and [salt], throwing [RindError.badSignature] if not.
  ///
  /// The key derived is as long as [previouslyDerived]; otherwise this
  /// throws as [derive] does.
  void verify(
    Argon2Params params,
    Uint8List salt,
    Uint8List previouslyDerived,
  ) {
    _native(salt, (saltPointer) {
      _native(previouslyDerived, (previous) {
        _check(
          _argon2Verify(
            _pointer,
            params._pointer,
            saltPointer,
            salt.length,
            previous,
            previouslyDerived.length,
          ),
        );
      });
    });
  }
}
