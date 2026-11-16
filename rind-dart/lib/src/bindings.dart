// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

// Everything `package:rind/rind.dart` exports, in one library so its handles
// stay private to it.
library;

import 'dart:ffi';
import 'dart:typed_data';

import 'error.dart';
import 'native.dart';

part 'aead.dart';
part 'agreement.dart';
part 'cipher.dart';
part 'digest.dart';
part 'ffi.dart';
part 'hkdf.dart';
part 'hmac.dart';
part 'kem.dart';
part 'pbkdf2.dart';
part 'rand.dart';

extension on Handle {
  Pointer<Void> get _pointer => pointerOf(this);
}
