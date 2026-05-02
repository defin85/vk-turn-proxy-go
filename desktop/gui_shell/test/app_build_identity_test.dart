import 'package:flutter_test/flutter_test.dart';
import 'package:gui_shell/src/build/app_build_identity.dart';
import 'package:gui_shell/src/build/version_defaults.g.dart';

void main() {
  test('app build identity falls back to version manifest defaults', () {
    expect(AppBuildIdentity.current.product, kVersionManifestProduct);
    expect(AppBuildIdentity.current.version, kVersionManifestVersion);
    expect(AppBuildIdentity.current.buildNumber, kVersionManifestBuildNumber);
    expect(AppBuildIdentity.current.revision, 'dev');
    expect(AppBuildIdentity.current.dirty, isTrue);
  });
}
