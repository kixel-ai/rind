// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

// The helpers that call the native functions in `rind-dart/src/lib.rs`,
// which `hook/build.dart` builds into this package's code asset.
//
// Calls that finish in microseconds are leaf calls, which read Dart's typed
// data in place. Those that can run for milliseconds or more (RSA key
// generation and private-key operations, and PBKDF2) are not, since a leaf
// call holds up garbage collection; they take copies in native memory.

library;

import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'error.dart';

/// A native function that frees a handle.
typedef Free = Void Function(Pointer<Void>);

/// Runs [call] with a slot for a handle, and returns the handle it stored.
Pointer<Void> newHandle(int Function(Pointer<Pointer<Void>> slot) call) {
  final slot = malloc<Pointer<Void>>();
  try {
    check(call(slot));
    return slot.value;
  } finally {
    malloc.free(slot);
  }
}

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

/// Allocates [length] bytes, calls [call] with them, and returns the bytes it
/// says it wrote.
Uint8List output(int length, int Function(Uint8List out) call) {
  final out = Uint8List(length);
  return out.sublist(0, check(call(out)));
}

/// Copies [data] to native memory for a non-leaf call, freeing it after. A
/// copy inside a call stays unwiped, as rind's own do.
T native<T>(Uint8List data, T Function(Pointer<Uint8> pointer) call) {
  final pointer = malloc<Uint8>(data.isEmpty ? 1 : data.length);
  final view = pointer.asTypedList(data.length);
  try {
    view.setAll(0, data);
    return call(pointer);
  } finally {
    malloc.free(pointer);
  }
}

/// A native object, freed with a [NativeFinalizer] when this is collected.
abstract base class Handle implements Finalizable {
  /// Wraps a native object, freed with [finalizer] when this is collected.
  Handle(this._pointer, NativeFinalizer finalizer) {
    finalizer.attach(this, _pointer, detach: this);
  }

  final Pointer<Void> _pointer;
}

/// The native object [handle] holds, for the libraries that define handles.
Pointer<Void> pointerOf(Handle handle) => handle._pointer;

/// The longest key export, an RSA-8192 PKCS#8 key, fits in this many bytes.
const exportLength = 8192;

/// RSA-8192's modulus length, which bounds RSA's signatures, ciphertexts,
/// and plaintexts.
const modulusLength = 1024;

/// A finalizer that frees a handle with [free].
NativeFinalizer finalizer(Pointer<NativeFunction<Free>> free) =>
    NativeFinalizer(free);

@Native<IntPtr Function(Pointer<Uint8>, Size)>(
  symbol: 'rind_dart_message',
  isLeaf: true,
)
external int _message(Pointer<Uint8> out, int outLen);
