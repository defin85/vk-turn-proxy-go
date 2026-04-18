///
/// Generated file. Do not edit.
///
// coverage:ignore-file
// ignore_for_file: type=lint, unused_import

part of 'strings.g.dart';

// Path: <root>
typedef TranslationsEn = Translations; // ignore: unused_element

class Translations with BaseTranslations<AppLocale, Translations> {
  /// Returns the current translations of the given [context].
  ///
  /// Usage:
  /// final t = Translations.of(context);
  static Translations of(BuildContext context) =>
      InheritedLocaleData.of<AppLocale, Translations>(context).translations;

  /// You can call this constructor and build your own translation instance of this locale.
  /// Constructing via the enum [AppLocale.build] is preferred.
  Translations({
    Map<String, Node>? overrides,
    PluralResolver? cardinalResolver,
    PluralResolver? ordinalResolver,
    TranslationMetadata<AppLocale, Translations>? meta,
  }) : assert(
         overrides == null,
         'Set "translation_overrides: true" in order to enable this feature.',
       ),
       $meta =
           meta ??
           TranslationMetadata(
             locale: AppLocale.en,
             overrides: overrides ?? {},
             cardinalResolver: cardinalResolver,
             ordinalResolver: ordinalResolver,
           ) {
    $meta.setFlatMapFunction(_flatMapFunction);
  }

  /// Metadata for the translations of <en>.
  @override
  final TranslationMetadata<AppLocale, Translations> $meta;

  /// Access flat map
  dynamic operator [](String key) => $meta.getTranslation(key);

  late final Translations _root = this; // ignore: unused_field

  Translations $copyWith({
    TranslationMetadata<AppLocale, Translations>? meta,
  }) => Translations(meta: meta ?? this.$meta);

  // Translations

  /// en: 'vk-turn-proxy desktop shell'
  String get appDesktopTitle => 'vk-turn-proxy desktop shell';

  /// en: 'vk-turn-proxy desktop shell references'
  String get appDesktopReferencesTitle =>
      'vk-turn-proxy desktop shell references';

  /// en: 'vk-turn-proxy mobile shell'
  String get appMobileTitle => 'vk-turn-proxy mobile shell';

  /// en: 'Language'
  String get localeMenuLabel => 'Language';

  /// en: 'Switch language'
  String get localeSwitchTooltip => 'Switch language';

  /// en: 'System default'
  String get localeSystemDefault => 'System default';

  /// en: 'English'
  String get localeEnglish => 'English';

  /// en: 'Russian'
  String get localeRussian => 'Russian';

  /// en: 'Home'
  String get commonHome => 'Home';

  /// en: 'Profiles'
  String get commonProfiles => 'Profiles';

  /// en: 'Providers'
  String get commonProviders => 'Providers';

  /// en: 'Routing'
  String get commonRouting => 'Routing';

  /// en: 'Support'
  String get commonSupport => 'Support';

  /// en: 'Diagnostics'
  String get commonDiagnostics => 'Diagnostics';

  /// en: 'Live work'
  String get commonLiveWork => 'Live work';

  /// en: 'Reconnect'
  String get commonReconnect => 'Reconnect';

  /// en: 'Refresh'
  String get commonRefresh => 'Refresh';

  /// en: 'Workflows'
  String get commonWorkflows => 'Workflows';

  /// en: 'Quick actions'
  String get commonQuickActions => 'Quick actions';

  /// en: 'Saved profiles'
  String get commonSavedProfiles => 'Saved profiles';

  /// en: 'Provider records'
  String get commonProviderRecords => 'Provider records';

  /// en: 'New draft'
  String get commonNewDraft => 'New draft';

  /// en: 'New from preset'
  String get commonNewFromPreset => 'New from preset';

  /// en: 'Provider families'
  String get commonProviderFamilies => 'Provider families';

  /// en: 'Open workflows'
  String get commonOpenWorkflowsTooltip => 'Open workflows';

  /// en: 'Home'
  String get mobileHomeTitle => 'Home';

  /// en: 'Pick a profile, finish any provider browser step from here, then turn the current mobile VPN path on or off.'
  String get mobileHomeSubtitle =>
      'Pick a profile, finish any provider browser step from here, then turn the current mobile VPN path on or off.';

  /// en: 'Profiles'
  String get mobileProfilesTitle => 'Profiles';

  /// en: 'Choose a saved profile or add a new one for Home.'
  String get mobileProfilesSubtitle =>
      'Choose a saved profile or add a new one for Home.';

  /// en: 'Import invite'
  String get mobileProfilesImportInvite => 'Import invite';

  /// en: 'Routing'
  String get mobileProfilesRouting => 'Routing';

  /// en: 'Profiles actions'
  String get mobileProfilesActionsTooltip => 'Profiles actions';

  /// en: 'Add profile'
  String get mobileProfilesAddProfile => 'Add profile';

  /// en: 'No saved profiles yet'
  String get mobileProfilesEmptyTitle => 'No saved profiles yet';

  /// en: 'Create or import a profile, then use Home for the one-tap VPN workflow.'
  String get mobileProfilesEmptyMessage =>
      'Create or import a profile, then use Home for the one-tap VPN workflow.';

  /// en: 'Desktop control shell'
  String get desktopShellLabel => 'Desktop control shell';

  /// en: 'Connecting to local host'
  String get desktopStatusConnectingTitle => 'Connecting to local host';

  /// en: 'Local host ready'
  String get desktopStatusReadyTitle => 'Local host ready';

  /// en: 'Local host blocked'
  String get desktopStatusBlockedTitle => 'Local host blocked';

  /// en: 'Starting local host and negotiating capabilities.'
  String get desktopStatusStartingDetail =>
      'Starting local host and negotiating capabilities.';

  /// en: 'Connected to local host.'
  String get desktopStatusConnectedDetail => 'Connected to local host.';

  /// en: 'Waiting for local host negotiation.'
  String get desktopStatusWaitingDetail =>
      'Waiting for local host negotiation.';

  /// en: 'Focused editor stays primary; diagnostics and live work stay secondary until needed.'
  String get desktopReadyWorkflowDetail =>
      'Focused editor stays primary; diagnostics and live work stay secondary until needed.';

  /// en: 'Profile editing'
  String get desktopSectionProfilesSubtitle => 'Profile editing';

  /// en: 'Provider records'
  String get desktopSectionProvidersSubtitle => 'Provider records';

  /// en: 'no auth requirement reported'
  String get sharedProviderAuthPostureNotApplicable =>
      'no auth requirement reported';

  /// en: 'guest auth'
  String get sharedProviderAuthPostureGuest => 'guest auth';

  /// en: 'account auth'
  String get sharedProviderAuthPostureAccount => 'account auth';

  /// en: 'guest or account auth'
  String get sharedProviderAuthPostureGuestOrAccount => 'guest or account auth';

  /// en: 'static secret input'
  String get sharedProviderAuthPostureStaticSecret => 'static secret input';

  /// en: 'no browser requirement reported'
  String get sharedProviderBrowserPolicyNotRequired =>
      'no browser requirement reported';

  /// en: 'external browser required'
  String get sharedProviderBrowserPolicyExternalRequired =>
      'external browser required';

  /// en: 'embedded browser allowed'
  String get sharedProviderBrowserPolicyEmbeddedAllowed =>
      'embedded browser allowed';

  /// en: 'Generic TURN'
  String get sharedArtifactFamilyGenericTurn => 'Generic TURN';

  /// en: 'Conference room'
  String get sharedArtifactFamilyConferenceRoom => 'Conference room';

  /// en: 'Camera stream'
  String get sharedArtifactFamilyCameraStream => 'Camera stream';

  /// en: 'Start on this device'
  String get sharedArtifactActionStartOnThisDevice => 'Start on this device';

  /// en: 'Export handoff'
  String get sharedArtifactActionExportHandoff => 'Export handoff';

  /// en: 'Open room'
  String get sharedArtifactActionOpenRoom => 'Open room';

  /// en: 'Open camera'
  String get sharedArtifactActionOpenCamera => 'Open camera';

  /// en: 'Open archive'
  String get sharedArtifactActionOpenArchive => 'Open archive';

  /// en: 'Android VPN Service'
  String get sharedPlatformTunnelModeAndroidVpnService => 'Android VPN Service';

  /// en: 'Apple Network Extension'
  String get sharedPlatformTunnelModeAppleNetworkExtension =>
      'Apple Network Extension';

  /// en: 'Windows Wintun'
  String get sharedPlatformTunnelModeWindowsWintun => 'Windows Wintun';

  /// en: 'Linux TUN'
  String get sharedPlatformTunnelModeLinuxTun => 'Linux TUN';

  /// en: 'permission'
  String get sharedPlatformTunnelPrerequisitePermission => 'permission';

  /// en: 'entitlement'
  String get sharedPlatformTunnelPrerequisiteEntitlement => 'entitlement';

  /// en: 'privileged extension'
  String get sharedPlatformTunnelPrerequisitePrivilegedExtension =>
      'privileged extension';

  /// en: 'driver'
  String get sharedPlatformTunnelPrerequisiteDriver => 'driver';

  /// en: 'route exclusion'
  String get sharedPlatformTunnelPrerequisiteRouteExclusion =>
      'route exclusion';

  /// en: 'DNS bypass'
  String get sharedPlatformTunnelPrerequisiteDnsBypass => 'DNS bypass';

  /// en: 'app routing policy'
  String get sharedPlatformTunnelPrerequisiteAppRoutingPolicy =>
      'app routing policy';

  /// en: 'host implementation'
  String get sharedPlatformTunnelPrerequisiteHostImplementation =>
      'host implementation';

  /// en: 'Capability check'
  String get sharedPlatformTunnelStartupStageCapabilityCheck =>
      'Capability check';

  /// en: 'Permission acquire'
  String get sharedPlatformTunnelStartupStagePermissionAcquire =>
      'Permission acquire';

  /// en: 'Entitlement acquire'
  String get sharedPlatformTunnelStartupStageEntitlementAcquire =>
      'Entitlement acquire';

  /// en: 'Driver check'
  String get sharedPlatformTunnelStartupStageDriverCheck => 'Driver check';

  /// en: 'Route validation'
  String get sharedPlatformTunnelStartupStageRouteValidate =>
      'Route validation';

  /// en: 'Host bring-up'
  String get sharedPlatformTunnelStartupStageHostBringup => 'Host bring-up';

  /// en: 'Runtime attach'
  String get sharedPlatformTunnelStartupStageRuntimeAttach => 'Runtime attach';

  /// en: 'Available'
  String get sharedProviderConfigAvailabilityStateAvailable => 'Available';

  /// en: 'Provider missing'
  String get sharedProviderConfigAvailabilityStateProviderUnavailable =>
      'Provider missing';

  /// en: 'Schema unsupported'
  String get sharedProviderConfigAvailabilityStateSchemaUnsupported =>
      'Schema unsupported';

  /// en: 'Settings invalid'
  String get sharedProviderConfigAvailabilityStateSettingsInvalid =>
      'Settings invalid';

  /// en: 'VK Calls'
  String get sharedCatalogPresetVkDefaultTitle => 'VK Calls';

  /// en: 'Seed a managed VK provider entry for browser-first invite workflows.'
  String get sharedCatalogPresetVkDefaultDescription =>
      'Seed a managed VK provider entry for browser-first invite workflows.';

  /// en: 'VK Calls'
  String get sharedCatalogPresetVkDefaultSuggestedProfileName => 'VK Calls';

  /// en: 'Generic TURN'
  String get sharedCatalogPresetGenericTurnDefaultTitle => 'Generic TURN';

  /// en: 'Seed a managed Generic TURN provider entry for static TURN handoff workflows.'
  String get sharedCatalogPresetGenericTurnDefaultDescription =>
      'Seed a managed Generic TURN provider entry for static TURN handoff workflows.';

  /// en: 'Generic TURN'
  String get sharedCatalogPresetGenericTurnDefaultSuggestedProfileName =>
      'Generic TURN';

  /// en: 'VK Calls'
  String get sharedCatalogSupportedProviderVkTitle => 'VK Calls';

  /// en: 'Invite-first provider with browser-mediated continuation that resolves into transport-ready TURN credentials.'
  String get sharedCatalogSupportedProviderVkDescription =>
      'Invite-first provider with browser-mediated continuation that resolves into transport-ready TURN credentials.';

  /// en: 'VK Calls'
  String get sharedCatalogSupportedProviderVkSuggestedManagedProviderName =>
      'VK Calls';

  /// en: 'Generic TURN'
  String get sharedCatalogSupportedProviderGenericTurnTitle => 'Generic TURN';

  /// en: 'Static TURN handoff for deterministic transport testing and operator-driven runtime startup.'
  String get sharedCatalogSupportedProviderGenericTurnDescription =>
      'Static TURN handoff for deterministic transport testing and operator-driven runtime startup.';

  /// en: 'Generic TURN'
  String
  get sharedCatalogSupportedProviderGenericTurnSuggestedManagedProviderName =>
      'Generic TURN';
}

/// The flat map containing all translations for locale <en>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on Translations {
  dynamic _flatMapFunction(String path) {
    return switch (path) {
      'appDesktopTitle' => 'vk-turn-proxy desktop shell',
      'appDesktopReferencesTitle' => 'vk-turn-proxy desktop shell references',
      'appMobileTitle' => 'vk-turn-proxy mobile shell',
      'localeMenuLabel' => 'Language',
      'localeSwitchTooltip' => 'Switch language',
      'localeSystemDefault' => 'System default',
      'localeEnglish' => 'English',
      'localeRussian' => 'Russian',
      'commonHome' => 'Home',
      'commonProfiles' => 'Profiles',
      'commonProviders' => 'Providers',
      'commonRouting' => 'Routing',
      'commonSupport' => 'Support',
      'commonDiagnostics' => 'Diagnostics',
      'commonLiveWork' => 'Live work',
      'commonReconnect' => 'Reconnect',
      'commonRefresh' => 'Refresh',
      'commonWorkflows' => 'Workflows',
      'commonQuickActions' => 'Quick actions',
      'commonSavedProfiles' => 'Saved profiles',
      'commonProviderRecords' => 'Provider records',
      'commonNewDraft' => 'New draft',
      'commonNewFromPreset' => 'New from preset',
      'commonProviderFamilies' => 'Provider families',
      'commonOpenWorkflowsTooltip' => 'Open workflows',
      'mobileHomeTitle' => 'Home',
      'mobileHomeSubtitle' =>
        'Pick a profile, finish any provider browser step from here, then turn the current mobile VPN path on or off.',
      'mobileProfilesTitle' => 'Profiles',
      'mobileProfilesSubtitle' =>
        'Choose a saved profile or add a new one for Home.',
      'mobileProfilesImportInvite' => 'Import invite',
      'mobileProfilesRouting' => 'Routing',
      'mobileProfilesActionsTooltip' => 'Profiles actions',
      'mobileProfilesAddProfile' => 'Add profile',
      'mobileProfilesEmptyTitle' => 'No saved profiles yet',
      'mobileProfilesEmptyMessage' =>
        'Create or import a profile, then use Home for the one-tap VPN workflow.',
      'desktopShellLabel' => 'Desktop control shell',
      'desktopStatusConnectingTitle' => 'Connecting to local host',
      'desktopStatusReadyTitle' => 'Local host ready',
      'desktopStatusBlockedTitle' => 'Local host blocked',
      'desktopStatusStartingDetail' =>
        'Starting local host and negotiating capabilities.',
      'desktopStatusConnectedDetail' => 'Connected to local host.',
      'desktopStatusWaitingDetail' => 'Waiting for local host negotiation.',
      'desktopReadyWorkflowDetail' =>
        'Focused editor stays primary; diagnostics and live work stay secondary until needed.',
      'desktopSectionProfilesSubtitle' => 'Profile editing',
      'desktopSectionProvidersSubtitle' => 'Provider records',
      'sharedProviderAuthPostureNotApplicable' =>
        'no auth requirement reported',
      'sharedProviderAuthPostureGuest' => 'guest auth',
      'sharedProviderAuthPostureAccount' => 'account auth',
      'sharedProviderAuthPostureGuestOrAccount' => 'guest or account auth',
      'sharedProviderAuthPostureStaticSecret' => 'static secret input',
      'sharedProviderBrowserPolicyNotRequired' =>
        'no browser requirement reported',
      'sharedProviderBrowserPolicyExternalRequired' =>
        'external browser required',
      'sharedProviderBrowserPolicyEmbeddedAllowed' =>
        'embedded browser allowed',
      'sharedArtifactFamilyGenericTurn' => 'Generic TURN',
      'sharedArtifactFamilyConferenceRoom' => 'Conference room',
      'sharedArtifactFamilyCameraStream' => 'Camera stream',
      'sharedArtifactActionStartOnThisDevice' => 'Start on this device',
      'sharedArtifactActionExportHandoff' => 'Export handoff',
      'sharedArtifactActionOpenRoom' => 'Open room',
      'sharedArtifactActionOpenCamera' => 'Open camera',
      'sharedArtifactActionOpenArchive' => 'Open archive',
      'sharedPlatformTunnelModeAndroidVpnService' => 'Android VPN Service',
      'sharedPlatformTunnelModeAppleNetworkExtension' =>
        'Apple Network Extension',
      'sharedPlatformTunnelModeWindowsWintun' => 'Windows Wintun',
      'sharedPlatformTunnelModeLinuxTun' => 'Linux TUN',
      'sharedPlatformTunnelPrerequisitePermission' => 'permission',
      'sharedPlatformTunnelPrerequisiteEntitlement' => 'entitlement',
      'sharedPlatformTunnelPrerequisitePrivilegedExtension' =>
        'privileged extension',
      'sharedPlatformTunnelPrerequisiteDriver' => 'driver',
      'sharedPlatformTunnelPrerequisiteRouteExclusion' => 'route exclusion',
      'sharedPlatformTunnelPrerequisiteDnsBypass' => 'DNS bypass',
      'sharedPlatformTunnelPrerequisiteAppRoutingPolicy' =>
        'app routing policy',
      'sharedPlatformTunnelPrerequisiteHostImplementation' =>
        'host implementation',
      'sharedPlatformTunnelStartupStageCapabilityCheck' => 'Capability check',
      'sharedPlatformTunnelStartupStagePermissionAcquire' =>
        'Permission acquire',
      'sharedPlatformTunnelStartupStageEntitlementAcquire' =>
        'Entitlement acquire',
      'sharedPlatformTunnelStartupStageDriverCheck' => 'Driver check',
      'sharedPlatformTunnelStartupStageRouteValidate' => 'Route validation',
      'sharedPlatformTunnelStartupStageHostBringup' => 'Host bring-up',
      'sharedPlatformTunnelStartupStageRuntimeAttach' => 'Runtime attach',
      'sharedProviderConfigAvailabilityStateAvailable' => 'Available',
      'sharedProviderConfigAvailabilityStateProviderUnavailable' =>
        'Provider missing',
      'sharedProviderConfigAvailabilityStateSchemaUnsupported' =>
        'Schema unsupported',
      'sharedProviderConfigAvailabilityStateSettingsInvalid' =>
        'Settings invalid',
      'sharedCatalogPresetVkDefaultTitle' => 'VK Calls',
      'sharedCatalogPresetVkDefaultDescription' =>
        'Seed a managed VK provider entry for browser-first invite workflows.',
      'sharedCatalogPresetVkDefaultSuggestedProfileName' => 'VK Calls',
      'sharedCatalogPresetGenericTurnDefaultTitle' => 'Generic TURN',
      'sharedCatalogPresetGenericTurnDefaultDescription' =>
        'Seed a managed Generic TURN provider entry for static TURN handoff workflows.',
      'sharedCatalogPresetGenericTurnDefaultSuggestedProfileName' =>
        'Generic TURN',
      'sharedCatalogSupportedProviderVkTitle' => 'VK Calls',
      'sharedCatalogSupportedProviderVkDescription' =>
        'Invite-first provider with browser-mediated continuation that resolves into transport-ready TURN credentials.',
      'sharedCatalogSupportedProviderVkSuggestedManagedProviderName' =>
        'VK Calls',
      'sharedCatalogSupportedProviderGenericTurnTitle' => 'Generic TURN',
      'sharedCatalogSupportedProviderGenericTurnDescription' =>
        'Static TURN handoff for deterministic transport testing and operator-driven runtime startup.',
      'sharedCatalogSupportedProviderGenericTurnSuggestedManagedProviderName' =>
        'Generic TURN',
      _ => null,
    };
  }
}
