import 'package:flutter_test/flutter_test.dart';
import 'package:gui_shell/src/build/app_build_identity.dart';

void main() {
  test('app build identity falls back to version manifest defaults', () {
    expect(AppBuildIdentity.current.product, 'RelayDock');
    expect(AppBuildIdentity.current.version, '0.1.0');
    expect(AppBuildIdentity.current.buildNumber, '1');
    expect(AppBuildIdentity.current.revision, 'dev');
    expect(AppBuildIdentity.current.dirty, isTrue);
  });
}
