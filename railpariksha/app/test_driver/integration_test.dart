// Bridges `flutter drive` to the integration_test package so
// integration_test/golden_path_test.dart can run in --release mode on a
// device/emulator. `flutter test` (used initially) doesn't accept --release
// at all -- only `flutter drive` does, which needs this driver file.
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver();
