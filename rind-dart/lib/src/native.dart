// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

// A native object. `_Handle` stores the key pointer, so it stays in this
// library: a shared class would publish it. `newHandle` only returns the
// pointer its caller's own native call stored, and `nativeCopy` only copies
// the caller's own bytes, so both live in status.dart.

part of 'bindings.dart';

// A native object, freed by the finalizer this attaches.
abstract base class _Handle implements Finalizable {
  _Handle(this._pointer, NativeFinalizer finalizer) {
    finalizer.attach(this, _pointer, detach: this);
  }

  final Pointer<Void> _pointer;
}
