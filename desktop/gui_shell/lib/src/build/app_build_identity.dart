import 'package:gui_shell/src/control/control_plane_models.dart';
import 'package:gui_shell/src/build/version_defaults.g.dart';

class AppBuildIdentity {
  static const BuildIdentity current = BuildIdentity(
    product: String.fromEnvironment(
      'VKTP_PRODUCT_NAME',
      defaultValue: kVersionManifestProduct,
    ),
    version: String.fromEnvironment(
      'VKTP_PRODUCT_VERSION',
      defaultValue: kVersionManifestVersion,
    ),
    buildNumber: String.fromEnvironment(
      'VKTP_BUILD_NUMBER',
      defaultValue: kVersionManifestBuildNumber,
    ),
    revision: String.fromEnvironment('VKTP_REVISION', defaultValue: 'dev'),
    dirty: bool.fromEnvironment('VKTP_DIRTY', defaultValue: true),
    builtAt: String.fromEnvironment('VKTP_BUILT_AT'),
    role: String.fromEnvironment(
      'VKTP_ARTIFACT_ROLE',
      defaultValue: 'gui_shell',
    ),
    target: String.fromEnvironment(
      'VKTP_ARTIFACT_TARGET',
      defaultValue: 'desktop/dev',
    ),
  );

  const AppBuildIdentity._();
}
