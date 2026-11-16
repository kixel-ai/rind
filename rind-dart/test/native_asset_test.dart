// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

import 'dart:io';

import 'package:test/test.dart';

/// The only code asset `hook/build.dart` registers.
const _registeredAsset = 'package:rind/src/bindings.dart';

void main() {
  test('every @Native resolves against the registered code asset', () {
    final nativeLibraries = <String>[];
    for (final file in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      final text = file.readAsStringSync();
      if (!text.contains('@Native')) continue;
      final library = _libraryFile(file, text);
      nativeLibraries.add(library.path);
      expect(
        _assetId(library),
        _registeredAsset,
        reason:
            '${file.path} points @Native at an asset the build hook '
            'does not register',
      );
      for (final id in _explicitAssetIds(text)) {
        expect(id, _registeredAsset, reason: file.path);
      }
    }
    expect(
      nativeLibraries.map((path) => path.split('/').last).toSet(),
      containsAll([
        'bindings.dart',
        'ecdsa.dart',
        'ed25519.dart',
        'rsa.dart',
        'status.dart',
      ]),
    );
  });

  test(
    'a fresh process resolves each signature library on its first rind call',
    () async {
      for (final name in ['ed25519', 'ecdsa', 'rsa']) {
        final result = await Process.run(Platform.resolvedExecutable, [
          'test/first_call/$name.dart',
        ]);
        expect(
          result.exitCode,
          0,
          reason: '$name\n${result.stdout}\n${result.stderr}',
        );
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

File _libraryFile(File file, String text) {
  final part = RegExp(
    r'''^part of ['"]([^'"]+)['"];''',
    multiLine: true,
  ).firstMatch(text);
  if (part == null) return file;
  return File('${file.parent.path}/${part.group(1)}');
}

// The asset id @Native uses when it sets no assetId: the library's
// DefaultAsset, or the library URI when that annotation is absent.
String _assetId(File library) {
  final text = library.readAsStringSync();
  final annotation = RegExp(
    r'''@DefaultAsset\(\s*['"]([^'"]+)['"]\s*\)''',
  ).firstMatch(text);
  if (annotation != null) return annotation.group(1)!;
  final relative = library.path.replaceAll('\\', '/').split('lib/').last;
  return 'package:rind/$relative';
}

Iterable<String> _explicitAssetIds(String text) => RegExp(
  r'''assetId:\s*['"]([^'"]+)['"]''',
).allMatches(text).map((match) => match.group(1)!);
