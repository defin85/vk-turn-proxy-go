export 'control_plane_models.dart' show BuildIdentity;

abstract final class BuildIdentityEnvironment {
  static const String revision = String.fromEnvironment(
    'VKTP_REVISION',
    defaultValue: 'dev',
  );
  static const bool dirty = bool.fromEnvironment(
    'VKTP_DIRTY',
    defaultValue: true,
  );
  static const String builtAt = String.fromEnvironment('VKTP_BUILT_AT');
}
