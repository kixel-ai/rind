// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

// Runs the package's tests on the device: package:test's `test` and `group`
// declare into the enclosing group, which flutter_test runs.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../../test/rind_test.dart' as rind;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  group('rind', rind.main);
}
