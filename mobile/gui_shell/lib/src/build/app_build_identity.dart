import 'package:mobile_gui_shell/src/build/version_defaults.g.dart';
import 'package:flutter_shell_core/build_identity.dart';

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
    revision: BuildIdentityEnvironment.revision,
    dirty: BuildIdentityEnvironment.dirty,
    builtAt: BuildIdentityEnvironment.builtAt,
    role: String.fromEnvironment(
      'VKTP_ARTIFACT_ROLE',
      defaultValue: 'mobile_gui_shell',
    ),
    target: String.fromEnvironment(
      'VKTP_ARTIFACT_TARGET',
      defaultValue: 'mobile/dev',
    ),
  );

  const AppBuildIdentity._();
}
