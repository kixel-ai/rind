// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

// Status mapping for a native call. This library holds no key pointer: the
// library that owns a handle keeps that pointer private.
//
// `hook/build.dart` registers one code asset. The annotation names it,
// because this library's own URI is not that asset.
@DefaultAsset('package:rind/src/bindings.dart')
library;

import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'error.dart';

/// Returns a non-negative [status], or throws for a negative one.
int check(int status) {
  if (status >= 0) return status;
  if (status == -10) throw StateError('rind binding bug: ${_lastMessage()}');
  throw RindException(
    RindError.values[-status - 1],
    status == -2 ? _lastMessage() : null,
  );
}

String _lastMessage() {
  final out = Uint8List(256);
  final len = _message(out.address, out.length);
  return utf8.decode(
    out.sublist(0, len < out.length ? len : out.length),
    allowMalformed: true,
  );
}

/// Allocates [length] bytes and returns what [call] wrote into them.
Uint8List output(int length, int Function(Uint8List out) call) {
  final out = Uint8List(length);
  return out.sublist(0, check(call(out)));
}

/// The longest key export, an RSA-8192 PKCS#8 key, fits in this many bytes.
const exportLength = 8192;

/// Frees one native handle.
typedef HandleFree = Void Function(Pointer<Void>);

/// Builds the finalizer that runs [free] when its handle is collected.
NativeFinalizer finalizer(Pointer<NativeFunction<HandleFree>> free) =>
    NativeFinalizer(free);

@Native<IntPtr Function(Pointer<Uint8>, Size)>(
  symbol: 'rind_dart_message',
  isLeaf: true,
)
external int _message(Pointer<Uint8> out, int outLen);
