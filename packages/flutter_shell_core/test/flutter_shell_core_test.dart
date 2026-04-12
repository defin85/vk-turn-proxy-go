import 'package:flutter_shell_core/flutter_shell_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('workspace scaffold package exports shared shell leaf modules', () {
    expect(kFlutterShellCorePackage, 'flutter_shell_core');
    expect(ControlPlaneClient.contractVersion, '1');
    expect(ProfileDraft.defaults().spec.listenAddress, '127.0.0.1:9001');
    expect(BuildIdentityEnvironment.revision, 'dev');
    expect(BuildIdentityEnvironment.dirty, isTrue);
  });
}
