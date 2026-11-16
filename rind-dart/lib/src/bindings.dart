// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

// One library, so these native handles and helpers stay private to it.
// The signature libraries are separate and keep their own handles private
// the same way. Public libraries export their names from here.
library;

import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'error.dart';

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
