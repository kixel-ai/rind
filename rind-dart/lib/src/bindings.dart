// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

// One library, so these native handles stay private to it. The signature
// libraries are separate and keep their own handles private the same way.
// Public libraries export their names from here. Status mapping, and the
// helpers that only return or copy the caller's own pointer, live in
// status.dart. The handle class stays here.
//
// `hook/build.dart` registers one code asset, this library's URI. Naming it
// keeps that id if this file moves.
@DefaultAsset('package:rind/src/bindings.dart')
library;

import 'dart:ffi';
import 'dart:typed_data';

import 'error.dart';
import 'status.dart';

part 'aead.dart';
part 'agreement.dart';
part 'cipher.dart';
part 'digest.dart';
part 'ffi.dart';
part 'hkdf.dart';
part 'hmac.dart';
part 'kem.dart';
part 'native.dart';
part 'pbkdf2.dart';
part 'rand.dart';
