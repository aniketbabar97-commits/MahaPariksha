// Bridges `flutter drive` to the integration_test package so
// integration_test/golden_path_test.dart can run in --profile mode (same R8/
// minification as --release on Android, but flutter drive itself refuses
// literal --release for non-web targets) on a device/emulator. `flutter test`
// (used initially) doesn't accept build-mode flags at all -- only
// `flutter drive` does, which needs this driver file.
import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

// Screenshots the test takes (binding.takeScreenshot) land in app/screenshots/; the release
// workflow uploads that folder, so every build comes with real-emulator renders of the main screens.
Future<void> main() => integrationDriver(
      onScreenshot: (name, bytes, [args]) async {
        final f = File('screenshots/$name.png');
        f.parent.createSync(recursive: true);
        f.writeAsBytesSync(bytes);
        return true;
      },
    );
