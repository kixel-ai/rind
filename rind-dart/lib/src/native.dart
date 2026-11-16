// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

// The helpers that call the native functions in `rind-dart/src/lib.rs`,
// which `hook/build.dart` builds into this package's code asset.
//
// Calls that finish in microseconds are leaf calls, which read Dart's typed
// data in place. Those that can run for milliseconds or more (RSA key
// generation and private-key operations, and PBKDF2) are not, since a leaf
// call holds up garbage collection; they take copies in native memory.
//
// Status mapping lives in status.dart. The handle pointer stays here:
// `_newHandle` returns it and `_Handle` stores it, and a shared name for
// either would publish a native key pointer.

part of 'bindings.dart';

// Runs [call] with a slot for a handle, and returns the handle it stored.
Pointer<Void> _newHandle(int Function(Pointer<Pointer<Void>> slot) call) {
  final slot = malloc<Pointer<Void>>();
  try {
    check(call(slot));
    return slot.value;
  } finally {
    malloc.free(slot);
  }
}

// Copies [data] into zeroed native memory for a non-leaf call, freeing it
// after. `calloc` initializes the allocation: Rust borrows the pointer as
// `&mut [u8]`, including when the copy is an output buffer. A copy inside a
// call stays unwiped, as rind's own do.
T _native<T>(Uint8List data, T Function(Pointer<Uint8> pointer) call) {
  final pointer = calloc<Uint8>(data.isEmpty ? 1 : data.length);
  final view = pointer.asTypedList(data.length);
  try {
    view.setAll(0, data);
    return call(pointer);
  } finally {
    malloc.free(pointer);
  }
}

// A native object, freed by the finalizer this attaches.
abstract base class _Handle implements Finalizable {
  _Handle(this._pointer, NativeFinalizer finalizer) {
    finalizer.attach(this, _pointer, detach: this);
  }

  final Pointer<Void> _pointer;
}
