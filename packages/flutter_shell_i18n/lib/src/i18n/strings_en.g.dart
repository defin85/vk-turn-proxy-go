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

  /// en: 'Settings'
  String get commonSettings => 'Settings';

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

  /// en: 'Close'
  String get shellTextClose => 'Close';

  /// en: 'Cancel'
  String get shellTextCancel => 'Cancel';

  /// en: 'Back'
  String get shellTextBack => 'Back';

  /// en: 'Save'
  String get shellTextSave => 'Save';

  /// en: 'Delete'
  String get shellTextDelete => 'Delete';

  /// en: 'New'
  String get shellTextNewItem => 'New';

  /// en: 'missing'
  String get shellTextMissing => 'missing';

  /// en: 'unknown'
  String get shellTextUnknownValue => 'unknown';

  /// en: 'failure'
  String get shellTextFailureFallback => 'failure';

  /// en: 'Retry'
  String get shellTextRetry => 'Retry';

  /// en: 'Activity'
  String get shellTextActivity => 'Activity';

  /// en: 'Diagnostics'
  String get shellTextDiagnostics => 'Diagnostics';

  /// en: 'Overview'
  String get shellTextOverview => 'Overview';

  /// en: 'Events'
  String get shellTextEvents => 'Events';

  /// en: 'Templates'
  String get shellTextTemplates => 'Templates';

  /// en: 'Available'
  String get shellTextAvailable => 'Available';

  /// en: 'Unavailable'
  String get shellTextUnavailable => 'Unavailable';

  /// en: 'Open activity'
  String get shellTextOpenActivity => 'Open activity';

  /// en: 'Open diagnostics'
  String get shellTextOpenDiagnostics => 'Open diagnostics';

  /// en: 'Open profiles'
  String get shellTextOpenProfiles => 'Open profiles';

  /// en: 'Reset local state'
  String get shellTextResetLocalState => 'Reset local state';

  /// en: 'Forget embedded sign-in'
  String get shellTextForgetEmbeddedSignIn => 'Forget embedded sign-in';

  /// en: 'Embedded browser cookies and session'
  String get shellTextEmbeddedBrowserStateTitle =>
      'Embedded browser cookies and session';

  /// en: 'The in-app browser keeps its own app-owned cookies and storage. Rebooting the device does not clear this state.'
  String get shellTextEmbeddedBrowserStateBody =>
      'The in-app browser keeps its own app-owned cookies and storage. Rebooting the device does not clear this state.';

  /// en: 'Use this reset before a clean provider sign-in test or when an old VK session keeps getting reused. It only clears the embedded WebView inside this app.'
  String get shellTextEmbeddedBrowserStateHint =>
      'Use this reset before a clean provider sign-in test or when an old VK session keeps getting reused. It only clears the embedded WebView inside this app.';

  /// en: 'Import from file'
  String get shellTextImportFromFile => 'Import from file';

  /// en: 'Export saved profile'
  String get shellTextExportSavedProfile => 'Export saved profile';

  /// en: 'Selected profile'
  String get shellTextSelectedProfileActions => 'Selected profile';

  /// en: 'Make current'
  String get shellTextMakeCurrent => 'Make current';

  /// en: 'Copy profile'
  String get shellTextCopyProfile => 'Copy profile';

  /// en: 'Paste envelope'
  String get shellTextPasteEnvelope => 'Paste envelope';

  /// en: 'Copy text'
  String get shellTextCopyText => 'Copy text';

  /// en: 'Save file'
  String get shellTextSaveFile => 'Save file';

  /// en: 'Share text'
  String get shellTextShareText => 'Share text';

  /// en: 'Share file'
  String get shellTextShareFile => 'Share file';

  /// en: 'Preview import'
  String get shellTextPreviewImport => 'Preview import';

  /// en: 'Import profile'
  String get shellTextImportProfile => 'Import profile';

  /// en: 'Portable profile JSON'
  String get shellTextPortableProfileJson => 'Portable profile JSON';

  /// en: 'Portable profile envelope'
  String get shellTextPortableProfileEnvelope => 'Portable profile envelope';

  /// en: 'No managed providers are available yet.'
  String get shellTextNoManagedProvidersAvailableYet =>
      'No managed providers are available yet.';

  /// en: 'The selected provider is not advertised by the connected host.'
  String get shellTextSelectedProviderNotAdvertisedByConnectedHost =>
      'The selected provider is not advertised by the connected host.';

  /// en: 'The selected provider is not advertised by the connected mobile host.'
  String get shellTextSelectedProviderNotAdvertisedByConnectedMobileHost =>
      'The selected provider is not advertised by the connected mobile host.';

  /// en: 'Saved profile {profileLabel}.'
  String shellTextSavedProfile({required Object profileLabel}) =>
      'Saved profile ${profileLabel}.';

  /// en: 'Saved mobile profile {profileLabel}.'
  String shellTextSavedMobileProfile({required Object profileLabel}) =>
      'Saved mobile profile ${profileLabel}.';

  /// en: 'Deleted profile {profileId}.'
  String shellTextDeletedProfile({required Object profileId}) =>
      'Deleted profile ${profileId}.';

  /// en: 'Deleted mobile profile {profileId}.'
  String shellTextDeletedMobileProfile({required Object profileId}) =>
      'Deleted mobile profile ${profileId}.';

  /// en: '{sourceLabel} copy'
  String shellTextDuplicatedItemLabel({required Object sourceLabel}) =>
      '${sourceLabel} copy';

  /// en: 'Copied item'
  String get shellTextDuplicatedItemFallbackLabel => 'Copied item';

  /// en: 'Seeded a new profile draft from {profileLabel}.'
  String shellTextSeededProfileCopyDraft({required Object profileLabel}) =>
      'Seeded a new profile draft from ${profileLabel}.';

  /// en: 'Saved managed provider {providerLabel}.'
  String shellTextSavedManagedProvider({required Object providerLabel}) =>
      'Saved managed provider ${providerLabel}.';

  /// en: 'Deleted managed provider {providerId}.'
  String shellTextDeletedManagedProvider({required Object providerId}) =>
      'Deleted managed provider ${providerId}.';

  /// en: 'Seeded a new managed provider draft from {providerLabel}.'
  String shellTextSeededManagedProviderCopyDraft({
    required Object providerLabel,
  }) => 'Seeded a new managed provider draft from ${providerLabel}.';

  /// en: 'Save or select a profile before exporting it.'
  String get shellTextSaveOrSelectProfileBeforeExport =>
      'Save or select a profile before exporting it.';

  /// en: 'The selected profile depends on a managed provider snapshot that is no longer available locally.'
  String get shellTextSelectedProfileDependsOnMissingManagedProviderSnapshot =>
      'The selected profile depends on a managed provider snapshot that is no longer available locally.';

  /// en: 'Copied portable profile {profileLabel}.'
  String shellTextCopiedPortableProfile({required Object profileLabel}) =>
      'Copied portable profile ${profileLabel}.';

  /// en: 'Copied secret-bearing portable profile {profileLabel}. Treat the payload like a credential.'
  String shellTextCopiedSecretBearingPortableProfile({
    required Object profileLabel,
  }) =>
      'Copied secret-bearing portable profile ${profileLabel}. Treat the payload like a credential.';

  /// en: 'Saved portable profile {profileLabel} to {path}.'
  String shellTextSavedPortableProfile({
    required Object profileLabel,
    required Object path,
  }) => 'Saved portable profile ${profileLabel} to ${path}.';

  /// en: 'Saved secret-bearing portable profile {profileLabel} to {path}.'
  String shellTextSavedSecretBearingPortableProfile({
    required Object profileLabel,
    required Object path,
  }) => 'Saved secret-bearing portable profile ${profileLabel} to ${path}.';

  /// en: 'Shared portable profile {profileLabel} as text.'
  String shellTextSharedPortableProfileAsText({required Object profileLabel}) =>
      'Shared portable profile ${profileLabel} as text.';

  /// en: 'Shared secret-bearing portable profile {profileLabel} as text.'
  String shellTextSharedSecretBearingPortableProfileAsText({
    required Object profileLabel,
  }) => 'Shared secret-bearing portable profile ${profileLabel} as text.';

  /// en: 'Shared portable profile {profileLabel} as a file.'
  String shellTextSharedPortableProfileAsFile({required Object profileLabel}) =>
      'Shared portable profile ${profileLabel} as a file.';

  /// en: 'Shared secret-bearing portable profile {profileLabel} as a file.'
  String shellTextSharedSecretBearingPortableProfileAsFile({
    required Object profileLabel,
  }) => 'Shared secret-bearing portable profile ${profileLabel} as a file.';

  /// en: 'Imported profile {profileLabel}.'
  String shellTextImportedProfile({required Object profileLabel}) =>
      'Imported profile ${profileLabel}.';

  /// en: 'Imported secret-bearing profile {profileLabel}. Review provider input before sharing it further.'
  String shellTextImportedSecretBearingProfile({
    required Object profileLabel,
  }) =>
      'Imported secret-bearing profile ${profileLabel}. Review provider input before sharing it further.';

  /// en: 'Started session {sessionId}.'
  String shellTextStartedSession({required Object sessionId}) =>
      'Started session ${sessionId}.';

  /// en: 'Started mobile session {sessionId}.'
  String shellTextStartedMobileSession({required Object sessionId}) =>
      'Started mobile session ${sessionId}.';

  /// en: 'Stopped session {sessionId}.'
  String shellTextStoppedSession({required Object sessionId}) =>
      'Stopped session ${sessionId}.';

  /// en: 'Managed provider {providerId} is no longer available.'
  String shellTextManagedProviderNoLongerAvailable({
    required Object providerId,
  }) => 'Managed provider ${providerId} is no longer available.';

  /// en: 'Applied managed provider {providerLabel} to the active profile draft.'
  String shellTextAppliedManagedProviderToActiveProfileDraft({
    required Object providerLabel,
  }) =>
      'Applied managed provider ${providerLabel} to the active profile draft.';

  /// en: 'Applied managed provider {providerLabel} to the active mobile profile draft.'
  String shellTextAppliedManagedProviderToActiveMobileProfileDraft({
    required Object providerLabel,
  }) =>
      'Applied managed provider ${providerLabel} to the active mobile profile draft.';

  /// en: 'Seeded a new managed provider draft from the {presetTitle} preset.'
  String shellTextSeededManagedProviderDraftFromPreset({
    required Object presetTitle,
  }) => 'Seeded a new managed provider draft from the ${presetTitle} preset.';

  /// en: 'Cancelled resolution {resolutionId}.'
  String shellTextCancelledResolution({required Object resolutionId}) =>
      'Cancelled resolution ${resolutionId}.';

  /// en: 'Cancelled mobile resolution {resolutionId}.'
  String shellTextCancelledMobileResolution({required Object resolutionId}) =>
      'Cancelled mobile resolution ${resolutionId}.';

  /// en: 'Started session {sessionId} from resolution {resolutionId}. Ready is reported only after runtime startup succeeds.'
  String shellTextStartedSessionFromResolution({
    required Object sessionId,
    required Object resolutionId,
  }) =>
      'Started session ${sessionId} from resolution ${resolutionId}. Ready is reported only after runtime startup succeeds.';

  /// en: 'Started mobile session {sessionId} from resolution {resolutionId}. Ready is reported only after runtime startup succeeds.'
  String shellTextStartedMobileSessionFromResolution({
    required Object sessionId,
    required Object resolutionId,
  }) =>
      'Started mobile session ${sessionId} from resolution ${resolutionId}. Ready is reported only after runtime startup succeeds.';

  /// en: 'Copied handoff link for {resolutionId}. Expires {expiresAt}.'
  String shellTextCopiedHandoffLink({
    required Object resolutionId,
    required Object expiresAt,
  }) => 'Copied handoff link for ${resolutionId}. Expires ${expiresAt}.';

  /// en: 'Shared handoff link for {resolutionId}. Expires {expiresAt}.'
  String shellTextSharedHandoffLink({
    required Object resolutionId,
    required Object expiresAt,
  }) => 'Shared handoff link for ${resolutionId}. Expires ${expiresAt}.';

  /// en: 'Resolution {resolutionId} is no longer available.'
  String shellTextResolutionNoLongerAvailable({required Object resolutionId}) =>
      'Resolution ${resolutionId} is no longer available.';

  /// en: 'Resolution {resolutionId} does not advertise action "{actionLabel}".'
  String shellTextResolutionDoesNotAdvertiseAction({
    required Object resolutionId,
    required Object actionLabel,
  }) =>
      'Resolution ${resolutionId} does not advertise action "${actionLabel}".';

  /// en: 'Resolution {resolutionId} does not expose a browser target for action "{actionLabel}".'
  String shellTextResolutionHasNoBrowserTarget({
    required Object resolutionId,
    required Object actionLabel,
  }) =>
      'Resolution ${resolutionId} does not expose a browser target for action "${actionLabel}".';

  /// en: 'Opened action "{actionLabel}" for {resolutionId}.'
  String shellTextOpenedResolutionAction({
    required Object actionLabel,
    required Object resolutionId,
  }) => 'Opened action "${actionLabel}" for ${resolutionId}.';

  /// en: 'Failed to open action "{actionLabel}" for {resolutionId}.'
  String shellTextFailedToOpenResolutionAction({
    required Object actionLabel,
    required Object resolutionId,
  }) => 'Failed to open action "${actionLabel}" for ${resolutionId}.';

  /// en: 'Cancelled challenge {challengeId}.'
  String shellTextCancelledChallenge({required Object challengeId}) =>
      'Cancelled challenge ${challengeId}.';

  /// en: 'Exported diagnostics to {path}.'
  String shellTextExportedDiagnostics({required Object path}) =>
      'Exported diagnostics to ${path}.';

  /// en: 'event stream closed'
  String get shellTextEventStreamClosed => 'event stream closed';

  /// en: 'Local host is not ready.'
  String get shellTextLocalHostNotReady => 'Local host is not ready.';

  /// en: 'Failed to restore desktop shell state: {error}'
  String shellTextFailedToRestoreDesktopShellState({required Object error}) =>
      'Failed to restore desktop shell state: ${error}';

  /// en: 'Failed to persist desktop shell state: {error}'
  String shellTextFailedToPersistDesktopShellState({required Object error}) =>
      'Failed to persist desktop shell state: ${error}';

  /// en: 'Failed to persist mobile shell state: {error}'
  String shellTextFailedToPersistMobileShellState({required Object error}) =>
      'Failed to persist mobile shell state: ${error}';

  /// en: 'Cleared remembered embedded sign-in.'
  String get shellTextClearedRememberedEmbeddedSignIn =>
      'Cleared remembered embedded sign-in.';

  /// en: 'Failed to clear remembered embedded sign-in: {error}'
  String shellTextFailedToClearRememberedEmbeddedSignIn({
    required Object error,
  }) => 'Failed to clear remembered embedded sign-in: ${error}';

  /// en: '{modeLabel} is ready for the local host tunnel path.'
  String shellTextPlatformTunnelReadyForLocalHost({
    required Object modeLabel,
  }) => '${modeLabel} is ready for the local host tunnel path.';

  /// en: 'Started resolution {resolutionId} for {providerName}.'
  String shellTextStartedResolutionForProvider({
    required Object resolutionId,
    required Object providerName,
  }) => 'Started resolution ${resolutionId} for ${providerName}.';

  /// en: 'Started resolution {resolutionId} for {providerName}. Finish the required external browser steps before expecting a resolved artifact.'
  String shellTextStartedResolutionForProviderWithExternalBrowser({
    required Object resolutionId,
    required Object providerName,
  }) =>
      'Started resolution ${resolutionId} for ${providerName}. Finish the required external browser steps before expecting a resolved artifact.';

  /// en: 'Started resolution {resolutionId} for {providerName}. Continue any browser challenge flow before expecting a resolved artifact.'
  String shellTextStartedResolutionForProviderWithBrowserContinuation({
    required Object resolutionId,
    required Object providerName,
  }) =>
      'Started resolution ${resolutionId} for ${providerName}. Continue any browser challenge flow before expecting a resolved artifact.';

  /// en: 'Continued challenge {challengeId}.'
  String shellTextContinuedChallenge({required Object challengeId}) =>
      'Continued challenge ${challengeId}.';

  /// en: 'Continued challenge {challengeId}. Finish the external browser flow for {providerName} before expecting the next state transition.'
  String shellTextContinuedChallengeWithExternalBrowser({
    required Object challengeId,
    required Object providerName,
  }) =>
      'Continued challenge ${challengeId}. Finish the external browser flow for ${providerName} before expecting the next state transition.';

  /// en: 'Continued challenge {challengeId}. Finish the provider flow for {providerName} before expecting a resolved artifact.'
  String shellTextContinuedChallengeForResolution({
    required Object challengeId,
    required Object providerName,
  }) =>
      'Continued challenge ${challengeId}. Finish the provider flow for ${providerName} before expecting a resolved artifact.';

  /// en: 'Continued challenge {challengeId}. Finish the provider flow for {providerName} before expecting the session to reach ready.'
  String shellTextContinuedChallengeForSession({
    required Object challengeId,
    required Object providerName,
  }) =>
      'Continued challenge ${challengeId}. Finish the provider flow for ${providerName} before expecting the session to reach ready.';

  /// en: 'The connected desktop shell cannot render provider settings for {providerName}: {error}'
  String shellTextDesktopProviderSettingsRuntimeUnsupported({
    required Object providerName,
    required Object error,
  }) =>
      'The connected desktop shell cannot render provider settings for ${providerName}: ${error}';

  /// en: 'The connected mobile shell cannot render provider settings for {providerName}: {error}'
  String shellTextMobileProviderSettingsRuntimeUnsupported({
    required Object providerName,
    required Object error,
  }) =>
      'The connected mobile shell cannot render provider settings for ${providerName}: ${error}';

  /// en: 'The selected managed provider family is not part of the supported app catalog.'
  String get shellTextSelectedManagedProviderFamilyNotInSupportedCatalog =>
      'The selected managed provider family is not part of the supported app catalog.';

  /// en: 'The selected managed provider is not part of the supported app catalog.'
  String get shellTextSelectedManagedProviderNotInSupportedCatalog =>
      'The selected managed provider is not part of the supported app catalog.';

  /// en: 'This managed provider is not part of the supported app catalog.'
  String get shellTextManagedProviderNotInSupportedCatalog =>
      'This managed provider is not part of the supported app catalog.';

  /// en: 'The connected desktop shell cannot render reusable settings for {providerName}: {error}'
  String shellTextDesktopReusableSettingsRuntimeUnsupported({
    required Object providerName,
    required Object error,
  }) =>
      'The connected desktop shell cannot render reusable settings for ${providerName}: ${error}';

  /// en: 'The connected mobile shell cannot render reusable settings for {providerName}: {error}'
  String shellTextMobileReusableSettingsRuntimeUnsupported({
    required Object providerName,
    required Object error,
  }) =>
      'The connected mobile shell cannot render reusable settings for ${providerName}: ${error}';

  /// en: 'The connected host does not advertise the {providerTitle} provider family yet.'
  String shellTextConnectedHostDoesNotAdvertiseProviderFamilyYet({
    required Object providerTitle,
  }) =>
      'The connected host does not advertise the ${providerTitle} provider family yet.';

  /// en: 'The selected template family is not part of the supported app catalog.'
  String get shellTextSelectedTemplateFamilyNotInSupportedCatalog =>
      'The selected template family is not part of the supported app catalog.';

  /// en: 'This template is not part of the supported app catalog.'
  String get shellTextTemplateNotInSupportedCatalog =>
      'This template is not part of the supported app catalog.';

  /// en: 'The connected mobile shell cannot render reusable settings for {providerName}: {error}'
  String shellTextMobileTemplateRuntimeUnsupported({
    required Object providerName,
    required Object error,
  }) =>
      'The connected mobile shell cannot render reusable settings for ${providerName}: ${error}';

  /// en: 'Local host shutdown requested.'
  String get shellTextLocalHostShutdownRequested =>
      'Local host shutdown requested.';

  /// en: 'No compatible local host was found and no launch candidates are configured.'
  String get shellTextNoCompatibleLocalHostFound =>
      'No compatible local host was found and no launch candidates are configured.';

  /// en: 'Local host launch failed without a reported error.'
  String get shellTextLocalHostLaunchFailedWithoutReportedError =>
      'Local host launch failed without a reported error.';

  /// en: 'Local host launch failed: {error}'
  String shellTextLocalHostLaunchFailed({required Object error}) =>
      'Local host launch failed: ${error}';

  /// en: 'Connected to local host {listenAddress}'
  String shellTextConnectedToLocalHost({required Object listenAddress}) =>
      'Connected to local host ${listenAddress}';

  /// en: 'Launched {description} on {listenAddress}'
  String shellTextLaunchedLocalHost({
    required Object description,
    required Object listenAddress,
  }) => 'Launched ${description} on ${listenAddress}';

  /// en: 'GUI_SHELL_CLIENTD_PATH'
  String get shellTextSidecarLaunchCandidateEnvPath => 'GUI_SHELL_CLIENTD_PATH';

  /// en: 'sidecar next to app executable'
  String get shellTextSidecarLaunchCandidateNextToAppExecutable =>
      'sidecar next to app executable';

  /// en: 'bundled sidecar in Frameworks'
  String get shellTextSidecarLaunchCandidateBundledFrameworks =>
      'bundled sidecar in Frameworks';

  /// en: 'clientd from PATH'
  String get shellTextSidecarLaunchCandidateFromPath => 'clientd from PATH';

  /// en: 'repo-local go run fallback'
  String get shellTextSidecarLaunchCandidateRepoLocalGoRun =>
      'repo-local go run fallback';

  /// en: '{description} exited with code {exitCode} before the control plane became ready.'
  String shellTextSidecarExitedBeforeReady({
    required Object description,
    required Object exitCode,
  }) =>
      '${description} exited with code ${exitCode} before the control plane became ready.';

  /// en: '{providerName} expects {inputKind} input. This desktop shell currently supports link entry only.'
  String shellTextProviderExpectsLinkEntryOnlyDesktop({
    required Object providerName,
    required Object inputKind,
  }) =>
      '${providerName} expects ${inputKind} input. This desktop shell currently supports link entry only.';

  /// en: 'Saved template {templateLabel}.'
  String shellTextSavedTemplate({required Object templateLabel}) =>
      'Saved template ${templateLabel}.';

  /// en: 'Deleted template {templateId}.'
  String shellTextDeletedTemplate({required Object templateId}) =>
      'Deleted template ${templateId}.';

  /// en: 'Template {templateId} is no longer available.'
  String shellTextTemplateNoLongerAvailable({required Object templateId}) =>
      'Template ${templateId} is no longer available.';

  /// en: 'Seeded a new managed provider draft from the {templateLabel} template.'
  String shellTextSeededManagedProviderDraftFromTemplate({
    required Object templateLabel,
  }) =>
      'Seeded a new managed provider draft from the ${templateLabel} template.';

  /// en: 'Seeded a new template draft from {templateLabel}.'
  String shellTextSeededTemplateCopyDraft({required Object templateLabel}) =>
      'Seeded a new template draft from ${templateLabel}.';

  /// en: 'Cleared local mobile shell state.'
  String get shellTextClearedLocalMobileShellState =>
      'Cleared local mobile shell state.';

  /// en: 'Failed to clear local mobile shell state: {error}'
  String shellTextFailedToClearLocalMobileShellState({required Object error}) =>
      'Failed to clear local mobile shell state: ${error}';

  /// en: '{providerName} expects {inputKind} input. This mobile shell currently supports link entry only.'
  String shellTextProviderExpectsLinkEntryOnlyMobile({
    required Object providerName,
    required Object inputKind,
  }) =>
      '${providerName} expects ${inputKind} input. This mobile shell currently supports link entry only.';

  /// en: 'Cannot start {modeLabel} because resolution {resolutionId} ended at {stage}: {message}'
  String shellTextResolutionUnavailableForPlatformTunnel({
    required Object modeLabel,
    required Object resolutionId,
    required Object stage,
    required Object message,
  }) =>
      'Cannot start ${modeLabel} because resolution ${resolutionId} ended at ${stage}: ${message}';

  /// en: 'Complete the current provider challenge before starting {modeLabel}.'
  String shellTextChallengeMustCompleteBeforeStarting({
    required Object modeLabel,
  }) => 'Complete the current provider challenge before starting ${modeLabel}.';

  /// en: 'Wait for the current provider resolution before starting {modeLabel}.'
  String shellTextWaitForProviderResolutionBeforeStarting({
    required Object modeLabel,
  }) =>
      'Wait for the current provider resolution before starting ${modeLabel}.';

  /// en: 'Started mobile resolution {resolutionId} for {providerName}.'
  String shellTextStartedMobileResolutionForProvider({
    required Object resolutionId,
    required Object providerName,
  }) => 'Started mobile resolution ${resolutionId} for ${providerName}.';

  /// en: 'Started mobile resolution {resolutionId} for {providerName}. Expect an external browser step when the provider requires it.'
  String shellTextStartedMobileResolutionForProviderWithExternalBrowser({
    required Object resolutionId,
    required Object providerName,
  }) =>
      'Started mobile resolution ${resolutionId} for ${providerName}. Expect an external browser step when the provider requires it.';

  /// en: 'Started mobile resolution {resolutionId} for {providerName}. Complete any browser continuation before expecting a resolved artifact.'
  String shellTextStartedMobileResolutionForProviderWithBrowserContinuation({
    required Object resolutionId,
    required Object providerName,
  }) =>
      'Started mobile resolution ${resolutionId} for ${providerName}. Complete any browser continuation before expecting a resolved artifact.';

  /// en: '{startedNotice} Complete the current provider challenge before starting {modeLabel}.'
  String shellTextResolutionStartedThenCompleteChallengeBeforeStarting({
    required Object startedNotice,
    required Object modeLabel,
  }) =>
      '${startedNotice} Complete the current provider challenge before starting ${modeLabel}.';

  /// en: 'Received portable profile {profileLabel}. Review it before importing.'
  String shellTextReceivedPortableProfileForReview({
    required Object profileLabel,
  }) =>
      'Received portable profile ${profileLabel}. Review it before importing.';

  /// en: 'Received a secret-bearing portable profile {profileLabel}. Review it before importing.'
  String shellTextReceivedSecretBearingPortableProfileForReview({
    required Object profileLabel,
  }) =>
      'Received a secret-bearing portable profile ${profileLabel}. Review it before importing.';

  /// en: 'Connected to mobile host bridge {baseUri}'
  String shellTextConnectedToMobileHostBridge({required Object baseUri}) =>
      'Connected to mobile host bridge ${baseUri}';

  /// en: 'This challenge does not expose a browser handoff URL.'
  String get shellTextChallengeHasNoBrowserHandoffUrl =>
      'This challenge does not expose a browser handoff URL.';

  /// en: 'Opened mobile browser handoff for {challengeKind}. Return here after the browser step.'
  String shellTextOpenedMobileBrowserHandoff({required Object challengeKind}) =>
      'Opened mobile browser handoff for ${challengeKind}. Return here after the browser step.';

  /// en: 'Failed to open the mobile browser handoff URL.'
  String get shellTextFailedToOpenMobileBrowserHandoffUrl =>
      'Failed to open the mobile browser handoff URL.';

  /// en: '{modeLabel} disconnected.'
  String shellTextPlatformTunnelDisconnected({required Object modeLabel}) =>
      '${modeLabel} disconnected.';

  /// en: 'Select at least one app before starting {modeLabel} in included-apps mode.'
  String shellTextSelectAtLeastOneIncludedApp({required Object modeLabel}) =>
      'Select at least one app before starting ${modeLabel} in included-apps mode.';

  /// en: 'Select at least one app before starting {modeLabel} in excluded-apps mode.'
  String shellTextSelectAtLeastOneExcludedApp({required Object modeLabel}) =>
      'Select at least one app before starting ${modeLabel} in excluded-apps mode.';

  /// en: 'The selected mobile mode is not advertised by the connected host.'
  String get shellTextSelectedMobileModeNotAdvertisedByConnectedHost =>
      'The selected mobile mode is not advertised by the connected host.';

  /// en: '{modeLabel} does not advertise a supported execution path yet.'
  String shellTextModeDoesNotAdvertiseSupportedExecutionPath({
    required Object modeLabel,
  }) => '${modeLabel} does not advertise a supported execution path yet.';

  /// en: 'Select an execution path before starting {modeLabel}.'
  String shellTextSelectExecutionPathBeforeStarting({
    required Object modeLabel,
  }) => 'Select an execution path before starting ${modeLabel}.';

  /// en: 'Reset local mobile shell state before reconnecting.'
  String get shellTextResetLocalMobileShellStateBeforeReconnecting =>
      'Reset local mobile shell state before reconnecting.';

  /// en: 'Detected {signalLabel} and continued challenge {challengeId}.'
  String shellTextDetectedBrowserReturnAndContinuedChallenge({
    required Object signalLabel,
    required Object challengeId,
  }) => 'Detected ${signalLabel} and continued challenge ${challengeId}.';

  /// en: 'Completed the in-app browser continuation for challenge {challengeId}.'
  String shellTextCompletedInAppBrowserContinuation({
    required Object challengeId,
  }) =>
      'Completed the in-app browser continuation for challenge ${challengeId}.';

  /// en: 'Reset local mobile shell state before runtime control can continue.'
  String get shellTextResetLocalMobileShellStateBeforeRuntimeControlContinue =>
      'Reset local mobile shell state before runtime control can continue.';

  /// en: 'app-link browser return'
  String get shellTextAppLinkBrowserReturn => 'app-link browser return';

  /// en: 'universal-link browser return'
  String get shellTextUniversalLinkBrowserReturn =>
      'universal-link browser return';

  /// en: 'browser return on app resume'
  String get shellTextBrowserReturnOnAppResume =>
      'browser return on app resume';

  /// en: 'browser return'
  String get shellTextBrowserReturn => 'browser return';

  /// en: 'Mobile host bridge is not ready.'
  String get shellTextMobileHostBridgeNotReady =>
      'Mobile host bridge is not ready.';

  /// en: 'Native mobile host bridge did not return a host configuration.'
  String get shellTextNativeMobileHostBridgeDidNotReturnHostConfiguration =>
      'Native mobile host bridge did not return a host configuration.';

  /// en: 'Native mobile host bridge returned an empty host URL.'
  String get shellTextNativeMobileHostBridgeReturnedEmptyHostUrl =>
      'Native mobile host bridge returned an empty host URL.';

  /// en: 'Native mobile host bridge returned an invalid host URL: {baseUrl}'
  String shellTextNativeMobileHostBridgeReturnedInvalidHostUrl({
    required Object baseUrl,
  }) => 'Native mobile host bridge returned an invalid host URL: ${baseUrl}';

  /// en: 'Native mobile host bridge plugin is unavailable.'
  String get shellTextNativeMobileHostBridgePluginUnavailable =>
      'Native mobile host bridge plugin is unavailable.';

  /// en: 'Failed to resolve the mobile host bridge from the native platform: {details}'
  String shellTextFailedToResolveMobileHostBridgeFromNativePlatform({
    required Object details,
  }) =>
      'Failed to resolve the mobile host bridge from the native platform: ${details}';

  /// en: 'Native mobile host bridge plugin is unavailable for platform tunnel permission requests.'
  String
  get shellTextNativeMobileHostBridgePluginUnavailableForPermissionRequests =>
      'Native mobile host bridge plugin is unavailable for platform tunnel permission requests.';

  /// en: 'Failed to request native platform tunnel permission: {details}'
  String shellTextFailedToRequestNativePlatformTunnelPermission({
    required Object details,
  }) => 'Failed to request native platform tunnel permission: ${details}';

  /// en: 'Native mobile host bridge returned no WebView snapshot.'
  String get shellTextNativeMobileHostBridgeReturnedNoWebViewSnapshot =>
      'Native mobile host bridge returned no WebView snapshot.';

  /// en: 'Failed to inspect native WebView: {details}'
  String shellTextFailedToInspectNativeWebView({required Object details}) =>
      'Failed to inspect native WebView: ${details}';

  /// en: 'VKTP_MOBILE_HOST_URL is not a valid URI for the mobile host bridge.'
  String get shellTextVktpMobileHostUrlInvalid =>
      'VKTP_MOBILE_HOST_URL is not a valid URI for the mobile host bridge.';

  /// en: 'Native mobile host bridge did not provide a control-plane endpoint.'
  String get shellTextNativeMobileHostBridgeDidNotProvideControlPlaneEndpoint =>
      'Native mobile host bridge did not provide a control-plane endpoint.';

  /// en: 'Mobile host bridge is not configured. Package a compatible loopback host or set VKTP_MOBILE_HOST_URL for development.'
  String get shellTextMobileHostBridgeNotConfigured =>
      'Mobile host bridge is not configured. Package a compatible loopback host or set VKTP_MOBILE_HOST_URL for development.';

  /// en: 'Native mobile host bridge plugin is unavailable for installed-app inventory.'
  String
  get shellTextNativeMobileHostBridgePluginUnavailableForInstalledAppInventory =>
      'Native mobile host bridge plugin is unavailable for installed-app inventory.';

  /// en: 'Failed to list installed apps from the native platform: {details}'
  String shellTextFailedToListInstalledAppsFromNativePlatform({
    required Object details,
  }) => 'Failed to list installed apps from the native platform: ${details}';

  /// en: 'Failed to restore mobile shell state: {error}'
  String shellTextFailedToRestoreMobileShellState({required Object error}) =>
      'Failed to restore mobile shell state: ${error}';

  /// en: 'The provider did not return a startable artifact.'
  String get shellTextProviderDidNotReturnStartableArtifact =>
      'The provider did not return a startable artifact.';

  /// en: '{modeLabel} still points to loopback peer {peerAddress}. Configure an operator-managed remote peer endpoint before starting the mobile VPN path.'
  String shellTextLoopbackPeerBlockReason({
    required Object modeLabel,
    required Object peerAddress,
  }) =>
      '${modeLabel} still points to loopback peer ${peerAddress}. Configure an operator-managed remote peer endpoint before starting the mobile VPN path.';

  /// en: 'Secure profile secrets are unavailable. Restore secure storage or clear the saved mobile shell state.'
  String get shellTextSecureProfileSecretsUnavailable =>
      'Secure profile secrets are unavailable. Restore secure storage or clear the saved mobile shell state.';

  /// en: 'Secure profile secrets are missing for saved profile {profileId}.'
  String shellTextSecureProfileSecretsMissing({required Object profileId}) =>
      'Secure profile secrets are missing for saved profile ${profileId}.';

  /// en: 'Secure draft secrets are unavailable. Restore secure storage or reset the draft.'
  String get shellTextSecureDraftSecretsUnavailable =>
      'Secure draft secrets are unavailable. Restore secure storage or reset the draft.';

  /// en: '{startedNotice} Wait for the resolution to finish before starting {modeLabel}.'
  String shellTextResolutionStartedThenWaitForFinishBeforeStarting({
    required Object startedNotice,
    required Object modeLabel,
  }) =>
      '${startedNotice} Wait for the resolution to finish before starting ${modeLabel}.';

  /// en: 'No reusable fields yet'
  String get shellTextNoReusableFieldsYet => 'No reusable fields yet';

  /// en: 'Schema blocked in this shell'
  String get shellTextSchemaBlockedInShell => 'Schema blocked in this shell';

  /// en: 'Reusable fields ready'
  String get shellTextReusableFieldsReady => 'Reusable fields ready';

  /// en: 'Provider input'
  String get shellTextProviderInput => 'Provider input';

  /// en: 'Provider link'
  String get shellTextProviderLink => 'Provider link';

  /// en: 'Provider family'
  String get shellTextProviderFamily => 'Provider family';

  /// en: 'Provider type'
  String get shellTextProviderType => 'Provider type';

  /// en: 'Profile name'
  String get shellTextProfileName => 'Profile name';

  /// en: 'Local UDP listen'
  String get shellTextLocalUdpListen => 'Local UDP listen';

  /// en: 'Peer address'
  String get shellTextPeerAddress => 'Peer address';

  /// en: 'Connections'
  String get shellTextConnections => 'Connections';

  /// en: 'TURN mode'
  String get shellTextTurnMode => 'TURN mode';

  /// en: 'TURN override'
  String get shellTextTurnOverride => 'TURN override';

  /// en: 'TURN port'
  String get shellTextTurnPort => 'TURN port';

  /// en: 'Bind interface'
  String get shellTextBindInterface => 'Bind interface';

  /// en: 'Log level'
  String get shellTextLogLevel => 'Log level';

  /// en: 'DTLS enabled'
  String get shellTextDtlsEnabled => 'DTLS enabled';

  /// en: 'Resolve invite'
  String get shellTextResolveInvite => 'Resolve invite';

  /// en: 'Resolve profile'
  String get shellTextResolveProfile => 'Resolve profile';

  /// en: 'Not set'
  String get shellTextNotSet => 'Not set';

  /// en: 'Start session'
  String get shellTextStartSession => 'Start session';

  /// en: 'Save profile'
  String get shellTextSaveProfile => 'Save profile';

  /// en: 'Delete profile'
  String get shellTextDeleteProfile => 'Delete profile';

  /// en: 'Fresh draft'
  String get shellTextFreshDraft => 'Fresh draft';

  /// en: 'Start saved profile'
  String get shellTextStartSavedProfile => 'Start saved profile';

  /// en: 'Export portable profile'
  String get shellTextExportPortableProfile => 'Export portable profile';

  /// en: 'Import portable profile'
  String get shellTextImportPortableProfile => 'Import portable profile';

  /// en: 'Paste portable profile envelope'
  String get shellTextPastePortableProfileEnvelope =>
      'Paste portable profile envelope';

  /// en: 'Preview opens before any local records are created.'
  String get shellTextPreviewOpensBeforeRecordsCreated =>
      'Preview opens before any local records are created.';

  /// en: 'Payload is invalid or unsupported.'
  String get shellTextPayloadInvalidOrUnsupported =>
      'Payload is invalid or unsupported.';

  /// en: 'Provider: {provider} · Source: {source}'
  String shellTextProviderAndSource({
    required Object provider,
    required Object source,
  }) => 'Provider: ${provider} · Source: ${source}';

  /// en: 'Provider: {provider}'
  String shellTextProviderLabel({required Object provider}) =>
      'Provider: ${provider}';

  /// en: 'Source mode: {mode}'
  String shellTextSourceModeLabel({required Object mode}) =>
      'Source mode: ${mode}';

  /// en: 'Managed provider snapshot: {name}'
  String shellTextManagedProviderSnapshot({required Object name}) =>
      'Managed provider snapshot: ${name}';

  /// en: 'This payload is secret-bearing. Treat copied text, saved files, and QR screens like credentials.'
  String get shellTextPortableExportSecretWarningDesktop =>
      'This payload is secret-bearing. Treat copied text, saved files, and QR screens like credentials.';

  /// en: 'This payload is secret-bearing. Treat shared text, files, and QR screens like credentials.'
  String get shellTextPortableExportSecretWarningMobile =>
      'This payload is secret-bearing. Treat shared text, files, and QR screens like credentials.';

  /// en: 'Exported payload stays separate from ordinary shell persistence and runtime handoff export.'
  String get shellTextPortableExportSeparateFromRuntimeDesktop =>
      'Exported payload stays separate from ordinary shell persistence and runtime handoff export.';

  /// en: 'Portable transfer stays separate from ordinary shell persistence and runtime handoff export.'
  String get shellTextPortableExportSeparateFromRuntimeMobile =>
      'Portable transfer stays separate from ordinary shell persistence and runtime handoff export.';

  /// en: 'QR uses the same envelope in compact JSON form.'
  String get shellTextPortableQrCompactJson =>
      'QR uses the same envelope in compact JSON form.';

  /// en: 'QR is unavailable because this payload exceeds supported QR bounds ({bytes} bytes). File and text export stay available.'
  String shellTextPortableQrUnavailableDesktop({required Object bytes}) =>
      'QR is unavailable because this payload exceeds supported QR bounds (${bytes} bytes). File and text export stay available.';

  /// en: 'QR is unavailable because this payload exceeds supported QR bounds ({bytes} bytes). Text and file sharing stay available.'
  String shellTextPortableQrUnavailableMobile({required Object bytes}) =>
      'QR is unavailable because this payload exceeds supported QR bounds (${bytes} bytes). Text and file sharing stay available.';

  /// en: 'This import payload is secret-bearing. Confirm only if the source is trusted.'
  String get shellTextPortableImportSecretWarning =>
      'This import payload is secret-bearing. Confirm only if the source is trusted.';

  /// en: 'Import creates fresh local ids and does not auto-start runtime.'
  String get shellTextPortableImportCreatesFreshIdsMobile =>
      'Import creates fresh local ids and does not auto-start runtime.';

  /// en: 'Import creates new local records with fresh ids and does not auto-start runtime.'
  String get shellTextPortableImportCreatesFreshIdsDesktop =>
      'Import creates new local records with fresh ids and does not auto-start runtime.';

  /// en: 'Scan portable profile QR'
  String get shellTextScanPortableProfileQr => 'Scan portable profile QR';

  /// en: 'Point the camera at a portable profile QR code.'
  String get shellTextPointCameraAtPortableProfileQr =>
      'Point the camera at a portable profile QR code.';

  /// en: 'Input: {value}'
  String shellTextTagInput({required Object value}) => 'Input: ${value}';

  /// en: 'Auth: {value}'
  String shellTextTagAuth({required Object value}) => 'Auth: ${value}';

  /// en: 'Browser: {value}'
  String shellTextTagBrowser({required Object value}) => 'Browser: ${value}';

  /// en: 'Family: {value}'
  String shellTextTagFamily({required Object value}) => 'Family: ${value}';

  /// en: 'This provider requires an external browser when challenge continuation appears.'
  String get shellTextBrowserNeedsExternal =>
      'This provider requires an external browser when challenge continuation appears.';

  /// en: 'This provider allows an embedded browser surface, but the host still controls whether a browser challenge appears.'
  String get shellTextBrowserAllowsEmbedded =>
      'This provider allows an embedded browser surface, but the host still controls whether a browser challenge appears.';

  /// en: 'This provider does not report a required browser surface.'
  String get shellTextBrowserNotRequired =>
      'This provider does not report a required browser surface.';

  /// en: 'Browser continuation may appear for this provider.'
  String get shellTextBrowserContinuationMayAppear =>
      'Browser continuation may appear for this provider.';

  /// en: 'No browser challenge mode is currently advertised for this provider.'
  String get shellTextBrowserContinuationNotAdvertised =>
      'No browser challenge mode is currently advertised for this provider.';

  /// en: 'Profile workspace'
  String get shellTextDesktopProfileWorkspaceTitle => 'Profile workspace';

  /// en: 'Unsaved draft'
  String get shellTextDesktopUnsavedDraft => 'Unsaved draft';

  /// en: 'Saved profile workspace'
  String get shellTextDesktopSavedProfileWorkspace => 'Saved profile workspace';

  /// en: 'Save profile first'
  String get shellTextDesktopSaveProfileFirst => 'Save profile first';

  /// en: 'Start a session from this saved profile'
  String get shellTextDesktopStartSessionFromSavedProfile =>
      'Start a session from this saved profile';

  /// en: 'Profile settings'
  String get shellTextDesktopProfileSettings => 'Profile settings';

  /// en: 'Change source'
  String get shellTextDesktopChangeSource => 'Change source';

  /// en: 'Switch between a saved provider record and draft-owned input only when the profile needs a different source.'
  String get shellTextDesktopChangeSourceSubtitle =>
      'Switch between a saved provider record and draft-owned input only when the profile needs a different source.';

  /// en: 'Runtime defaults'
  String get shellTextDesktopRuntimeDefaults => 'Runtime defaults';

  /// en: 'These fields apply when the profile starts on this device.'
  String get shellTextDesktopRuntimeDefaultsSubtitle =>
      'These fields apply when the profile starts on this device.';

  /// en: 'Profile maintenance'
  String get shellTextDesktopProfileMaintenance => 'Profile maintenance';

  /// en: 'Keep destructive actions out of the main edit flow.'
  String get shellTextDesktopProfileMaintenanceSubtitle =>
      'Keep destructive actions out of the main edit flow.';

  /// en: 'Show maintenance actions'
  String get shellTextDesktopShowMaintenanceActions =>
      'Show maintenance actions';

  /// en: 'Delete the saved profile without crowding the action row.'
  String get shellTextDesktopDeleteSavedProfileHint =>
      'Delete the saved profile without crowding the action row.';

  /// en: 'Export the selected saved profile as an explicit transfer envelope, or preview an import before creating local records.'
  String get shellTextDesktopPortableTransferSubtitle =>
      'Export the selected saved profile as an explicit transfer envelope, or preview an import before creating local records.';

  /// en: 'Browser handling'
  String get shellTextDesktopBrowserHandling => 'Browser handling';

  /// en: 'Show this context only when the provider can hand off into a browser challenge.'
  String get shellTextDesktopBrowserHandlingSubtitle =>
      'Show this context only when the provider can hand off into a browser challenge.';

  /// en: 'Profile provider settings'
  String get shellTextDesktopProfileProviderSettings =>
      'Profile provider settings';

  /// en: 'This desktop shell cannot render the provider settings schema for {providerName}: {error}. Save and resolve stay blocked until the host advertises a supported schema subset.'
  String shellTextDesktopProviderSettingsSupportError({
    required Object providerName,
    required Object error,
  }) =>
      'This desktop shell cannot render the provider settings schema for ${providerName}: ${error}. Save and resolve stay blocked until the host advertises a supported schema subset.';

  /// en: 'Saved profile settings for the selected provider. Prompt-only values stay only in the active draft.'
  String get shellTextDesktopProfileProviderSettingsHelp =>
      'Saved profile settings for the selected provider. Prompt-only values stay only in the active draft.';

  /// en: 'No saved provider records are available yet.'
  String get shellTextDesktopNoSavedProviderRecords =>
      'No saved provider records are available yet.';

  /// en: 'Direct input'
  String get shellTextDirectInput => 'Direct input';

  /// en: 'Saved record'
  String get shellTextSavedRecord => 'Saved record';

  /// en: 'A saved provider record is attached to this draft.'
  String get shellTextDesktopSavedRecordAttached =>
      'A saved provider record is attached to this draft.';

  /// en: 'This draft keeps its own provider input.'
  String get shellTextDesktopDraftOwnsProviderInput =>
      'This draft keeps its own provider input.';

  /// en: 'Profiles'
  String get shellTextMobileProfilesTitleBar => 'Profiles';

  /// en: 'Provider details'
  String get shellTextMobileProviderDetails => 'Provider details';

  /// en: 'Browser policy, artifact families, and challenge guidance'
  String get shellTextMobileProviderDetailsSubtitle =>
      'Browser policy, artifact families, and challenge guidance';

  /// en: 'Provider settings'
  String get shellTextMobileProviderSettingsSection => 'Provider settings';

  /// en: 'Portable transfer'
  String get shellTextMobilePortableTransfer => 'Portable transfer';

  /// en: 'Unsupported schema subset blocks save and resolve'
  String get shellTextMobileProviderSettingsUnsupportedSubtitle =>
      'Unsupported schema subset blocks save and resolve';

  /// en: 'Required and retained provider-specific values'
  String get shellTextMobileProviderSettingsRetainedSubtitle =>
      'Required and retained provider-specific values';

  /// en: 'Advanced runtime controls'
  String get shellTextMobileAdvancedRuntimeControls =>
      'Advanced runtime controls';

  /// en: 'Transport overrides, local bind, and logging'
  String get shellTextMobileAdvancedRuntimeControlsSubtitle =>
      'Transport overrides, local bind, and logging';

  /// en: 'Export the selected saved profile through an explicit envelope, or preview an import before creating local records.'
  String get shellTextMobilePortableTransferSubtitle =>
      'Export the selected saved profile through an explicit envelope, or preview an import before creating local records.';

  /// en: 'This mobile shell cannot render the provider settings schema for {providerName}: {error}. Save and resolve stay blocked until the host advertises a supported schema subset.'
  String shellTextMobileProviderSettingsSupportError({
    required Object providerName,
    required Object error,
  }) =>
      'This mobile shell cannot render the provider settings schema for ${providerName}: ${error}. Save and resolve stay blocked until the host advertises a supported schema subset.';

  /// en: 'Profile-retained settings stay with the saved profile. Prompt-only values remain only in the in-memory draft used for immediate resolution starts.'
  String get shellTextMobileProviderSettingsRetainedHelp =>
      'Profile-retained settings stay with the saved profile. Prompt-only values remain only in the in-memory draft used for immediate resolution starts.';

  /// en: 'No saved profiles yet. Build the draft below, then save it for repeat starts.'
  String get shellTextMobileNoSavedProfilesYetBuildDraft =>
      'No saved profiles yet. Build the draft below, then save it for repeat starts.';

  /// en: 'Saved profiles'
  String get shellTextMobileSavedProfiles => 'Saved profiles';

  /// en: 'Provider mode'
  String get shellTextMobileProviderMode => 'Provider mode';

  /// en: 'No managed providers are available yet. Use custom mode for direct provider entry or create a provider record from the workflow library first.'
  String get shellTextMobileProviderModeNoManagedProviders =>
      'No managed providers are available yet. Use custom mode for direct provider entry or create a provider record from the workflow library first.';

  /// en: 'Custom provider'
  String get shellTextCustomProvider => 'Custom provider';

  /// en: 'Managed provider'
  String get shellTextManagedProvider => 'Managed provider';

  /// en: 'Managed mode snapshots values from a saved provider record, then keeps further profile edits local to this draft.'
  String get shellTextMobileManagedModeSummary =>
      'Managed mode snapshots values from a saved provider record, then keeps further profile edits local to this draft.';

  /// en: 'Custom mode lets you type a raw provider id and prompt-only inputs without mutating the managed provider catalog.'
  String get shellTextMobileCustomModeSummary =>
      'Custom mode lets you type a raw provider id and prompt-only inputs without mutating the managed provider catalog.';

  /// en: 'Managed provider'
  String get shellTextMobileManagedProviderDropdown => 'Managed provider';

  /// en: 'Edit provider'
  String get shellTextMobileEditProvider => 'Edit provider';

  /// en: 'New provider'
  String get shellTextMobileNewProvider => 'New provider';

  /// en: 'Edit this saved reusable provider.'
  String get shellTextMobileEditSavedReusableProvider =>
      'Edit this saved reusable provider.';

  /// en: 'Finish this saved reusable provider for later use in Profiles.'
  String get shellTextMobileFinishSavedReusableProvider =>
      'Finish this saved reusable provider for later use in Profiles.';

  /// en: 'Close provider editor'
  String get shellTextMobileCloseProviderEditor => 'Close provider editor';

  /// en: 'This build does not advertise any shipped provider families yet.'
  String get shellTextMobileNoShippedProviderFamilies =>
      'This build does not advertise any shipped provider families yet.';

  /// en: 'Provider name'
  String get shellTextMobileProviderName => 'Provider name';

  /// en: 'Shown in Profiles when choosing a saved reusable provider.'
  String get shellTextMobileProviderShownInProfiles =>
      'Shown in Profiles when choosing a saved reusable provider.';

  /// en: 'Chosen when this saved provider was created. Use this pane to name it and review reusable settings.'
  String get shellTextMobileProviderTypeChosenWhenCreated =>
      'Chosen when this saved provider was created. Use this pane to name it and review reusable settings.';

  /// en: 'This mobile shell cannot render the provider settings schema for {providerName}: {error}. Save stays blocked until the host advertises a supported schema subset.'
  String shellTextMobileProviderConfigSupportError({
    required Object providerName,
    required Object error,
  }) =>
      'This mobile shell cannot render the provider settings schema for ${providerName}: ${error}. Save stays blocked until the host advertises a supported schema subset.';

  /// en: 'Reusable provider settings'
  String get shellTextMobileReusableProviderSettings =>
      'Reusable provider settings';

  /// en: 'These reusable values are applied when this provider is used in a profile.'
  String get shellTextMobileReusableValuesAppliedToProfile =>
      'These reusable values are applied when this provider is used in a profile.';

  /// en: 'Save provider'
  String get shellTextMobileSaveProvider => 'Save provider';

  /// en: 'Save as template'
  String get shellTextMobileSaveAsTemplate => 'Save as template';

  /// en: 'Use in profile draft'
  String get shellTextMobileUseInProfileDraft => 'Use in profile draft';

  /// en: 'Delete provider'
  String get shellTextMobileDeleteProvider => 'Delete provider';

  /// en: 'Saved providers'
  String get shellTextSavedProviders => 'Saved providers';

  /// en: 'Selected provider'
  String get shellTextSelectedProviderActions => 'Selected provider';

  /// en: 'Copy provider'
  String get shellTextCopyProvider => 'Copy provider';

  /// en: 'Selected type'
  String get shellTextSelectedType => 'Selected type';

  /// en: 'Edit template'
  String get shellTextMobileEditTemplate => 'Edit template';

  /// en: 'New template'
  String get shellTextMobileNewTemplate => 'New template';

  /// en: 'Edit starting values for future providers.'
  String get shellTextMobileEditTemplateStartingValues =>
      'Edit starting values for future providers.';

  /// en: 'Save a starting point for future providers.'
  String get shellTextMobileSaveTemplateStartingPoint =>
      'Save a starting point for future providers.';

  /// en: 'Close template editor'
  String get shellTextMobileCloseTemplateEditor => 'Close template editor';

  /// en: 'Template name'
  String get shellTextMobileTemplateName => 'Template name';

  /// en: 'Shown when choosing a starting point for new providers.'
  String get shellTextMobileTemplateShownWhenChoosing =>
      'Shown when choosing a starting point for new providers.';

  /// en: 'Chosen when this template was created. Use this pane to name it and review reusable starting values.'
  String get shellTextMobileTemplateTypeChosenWhenCreated =>
      'Chosen when this template was created. Use this pane to name it and review reusable starting values.';

  /// en: 'These values prefill a new provider when this template is used.'
  String get shellTextMobileReusableValuesPrefillProvider =>
      'These values prefill a new provider when this template is used.';

  /// en: 'Save template'
  String get shellTextMobileSaveTemplate => 'Save template';

  /// en: 'Use template'
  String get shellTextMobileUseTemplate => 'Use template';

  /// en: 'Delete template'
  String get shellTextMobileDeleteTemplate => 'Delete template';

  /// en: 'Selected template'
  String get shellTextSelectedTemplateActions => 'Selected template';

  /// en: 'Copy template'
  String get shellTextCopyTemplate => 'Copy template';

  /// en: 'Provider record'
  String get shellTextDesktopProviderRecord => 'Provider record';

  /// en: 'New provider record'
  String get shellTextDesktopNewProviderRecord => 'New provider record';

  /// en: 'Edit one reusable provider record. The attached family is shown below and stays read-only here.'
  String get shellTextDesktopEditReusableProviderRecord =>
      'Edit one reusable provider record. The attached family is shown below and stays read-only here.';

  /// en: 'Create one reusable provider record. Choose its family separately, then edit the record parameters below.'
  String get shellTextDesktopCreateReusableProviderRecord =>
      'Create one reusable provider record. Choose its family separately, then edit the record parameters below.';

  /// en: 'Record parameters'
  String get shellTextDesktopRecordParameters => 'Record parameters';

  /// en: 'Parameters for {providerTitle}'
  String shellTextDesktopParametersFor({required Object providerTitle}) =>
      'Parameters for ${providerTitle}';

  /// en: 'Choose a provider family from the separate family list first. Record parameters will appear here afterwards.'
  String get shellTextDesktopChooseProviderFamilyFirst =>
      'Choose a provider family from the separate family list first. Record parameters will appear here afterwards.';

  /// en: 'Edit reusable parameters stored in this record for {providerTitle}. This does not change the family itself.'
  String shellTextDesktopEditReusableParametersFor({
    required Object providerTitle,
  }) =>
      'Edit reusable parameters stored in this record for ${providerTitle}. This does not change the family itself.';

  /// en: 'Use in profile draft'
  String get shellTextDesktopUseInProfileDraft => 'Use in profile draft';

  /// en: 'New record'
  String get shellTextDesktopNewRecord => 'New record';

  /// en: 'Record name'
  String get shellTextDesktopRecordName => 'Record name';

  /// en: 'Name this saved provider record first. Family choice and record parameters stay below.'
  String get shellTextDesktopRecordNameHelp =>
      'Name this saved provider record first. Family choice and record parameters stay below.';

  /// en: 'Attached family'
  String get shellTextDesktopAttachedFamily => 'Attached family';

  /// en: 'Families live in a separate chooser. The selected family is attached to this record and described here.'
  String get shellTextDesktopAttachedFamilyHelp =>
      'Families live in a separate chooser. The selected family is attached to this record and described here.';

  /// en: 'Family characteristics'
  String get shellTextDesktopFamilyCharacteristics => 'Family characteristics';

  /// en: 'Read-only characteristics from the selected family and current host overlay.'
  String get shellTextDesktopFamilyCharacteristicsHelp =>
      'Read-only characteristics from the selected family and current host overlay.';

  /// en: 'This desktop shell cannot render the provider settings schema for {providerName}: {error}. Save stays blocked until the host advertises a supported schema subset.'
  String shellTextDesktopProviderRecordSupportError({
    required Object providerName,
    required Object error,
  }) =>
      'This desktop shell cannot render the provider settings schema for ${providerName}: ${error}. Save stays blocked until the host advertises a supported schema subset.';

  /// en: 'No family attached yet'
  String get shellTextDesktopNoFamilyAttachedYet => 'No family attached yet';

  /// en: 'Selected family'
  String get shellTextDesktopSelectedFamily => 'Selected family';

  /// en: 'Open the separate family chooser before you continue with this provider record.'
  String get shellTextDesktopOpenFamilyChooserFirst =>
      'Open the separate family chooser before you continue with this provider record.';

  /// en: '{providerTitle} is attached to this record until you intentionally change it in the family chooser.'
  String shellTextDesktopFamilyAttachedToRecord({
    required Object providerTitle,
  }) =>
      '${providerTitle} is attached to this record until you intentionally change it in the family chooser.';

  /// en: 'Shipped by app'
  String get shellTextDesktopShippedByApp => 'Shipped by app';

  /// en: 'Host overlay: available'
  String get shellTextDesktopHostOverlayAvailable => 'Host overlay: available';

  /// en: 'Host overlay: unavailable'
  String get shellTextDesktopHostOverlayUnavailable =>
      'Host overlay: unavailable';

  /// en: 'Use the action strip above to choose a family. Families are read-only here.'
  String get shellTextDesktopUseActionStripToChooseFamily =>
      'Use the action strip above to choose a family. Families are read-only here.';

  /// en: 'Families stay read-only here. Change the attached family from the action strip above; edit this record's parameters below.'
  String get shellTextDesktopFamiliesReadonlyEditBelow =>
      'Families stay read-only here. Change the attached family from the action strip above; edit this record\'s parameters below.';

  /// en: 'Choose family'
  String get shellTextDesktopChooseFamily => 'Choose family';

  /// en: 'Save draft'
  String get shellTextDesktopSaveDraft => 'Save draft';

  /// en: 'Save record'
  String get shellTextDesktopSaveRecord => 'Save record';

  /// en: 'Read-only family'
  String get shellTextDesktopReadOnlyFamily => 'Read-only family';

  /// en: 'This card describes the attached family. Editable record parameters are shown below.'
  String get shellTextDesktopAttachedFamilyCardHelp =>
      'This card describes the attached family. Editable record parameters are shown below.';

  /// en: 'No editable parameters yet'
  String get shellTextDesktopNoEditableParametersYet =>
      'No editable parameters yet';

  /// en: 'No editable parameters'
  String get shellTextDesktopNoEditableParameters => 'No editable parameters';

  /// en: 'Editable parameters ready'
  String get shellTextDesktopEditableParametersReady =>
      'Editable parameters ready';

  /// en: 'No saved profiles yet.'
  String get shellTextDesktopNoSavedProfilesYetShort =>
      'No saved profiles yet.';

  /// en: 'This build does not advertise any shipped provider families yet.'
  String get shellTextDesktopNoShippedProviderFamilies =>
      'This build does not advertise any shipped provider families yet.';

  /// en: '{providerTitle} has no editable record parameters in this desktop shell.'
  String shellTextDesktopNoEditableRecordParameters({
    required Object providerTitle,
  }) =>
      '${providerTitle} has no editable record parameters in this desktop shell.';

  /// en: 'Saved profiles'
  String get shellTextDesktopSavedProfilesLibraryTitle => 'Saved profiles';

  /// en: 'Browse saved operator workspaces intentionally, then return to the active editor without leaving the main path permanently split.'
  String get shellTextDesktopSavedProfilesLibrarySubtitle =>
      'Browse saved operator workspaces intentionally, then return to the active editor without leaving the main path permanently split.';

  /// en: 'Return path stays explicit'
  String get shellTextDesktopReturnPathExplicitTitle =>
      'Return path stays explicit';

  /// en: 'Selecting a saved profile updates the active workflow and closes this secondary surface.'
  String get shellTextDesktopReturnPathExplicitMessage =>
      'Selecting a saved profile updates the active workflow and closes this secondary surface.';

  /// en: 'Provider records'
  String get shellTextDesktopProviderRecordsLibraryTitle => 'Provider records';

  /// en: 'Create a reusable provider record or reopen one you already saved.'
  String get shellTextDesktopProviderRecordsLibrarySubtitle =>
      'Create a reusable provider record or reopen one you already saved.';

  /// en: 'Records are separate from families'
  String get shellTextDesktopRecordsSeparateFromFamiliesTitle =>
      'Records are separate from families';

  /// en: 'Create a record here, then choose its family in the separate family chooser. Open an existing record to continue editing it.'
  String get shellTextDesktopRecordsSeparateFromFamiliesMessage =>
      'Create a record here, then choose its family in the separate family chooser. Open an existing record to continue editing it.';

  /// en: 'No provider records yet. Create one to choose a family and store reusable parameters.'
  String get shellTextDesktopNoProviderRecordsYet =>
      'No provider records yet. Create one to choose a family and store reusable parameters.';

  /// en: 'Start from a curated provider seed only when you intentionally ask for it.'
  String get shellTextDesktopNewFromPresetSubtitle =>
      'Start from a curated provider seed only when you intentionally ask for it.';

  /// en: 'Preset bootstrap stays explicit'
  String get shellTextDesktopPresetBootstrapExplicitTitle =>
      'Preset bootstrap stays explicit';

  /// en: 'Unavailable presets remain visible and honest here, but they no longer occupy the default provider workspace.'
  String get shellTextDesktopPresetBootstrapExplicitMessage =>
      'Unavailable presets remain visible and honest here, but they no longer occupy the default provider workspace.';

  /// en: 'Choose the shipped family here, then return to the provider record editor.'
  String get shellTextDesktopProviderFamiliesSubtitle =>
      'Choose the shipped family here, then return to the provider record editor.';

  /// en: 'Families are read-only here'
  String get shellTextDesktopFamiliesReadonlyHereTitle =>
      'Families are read-only here';

  /// en: 'This list belongs to the shipped shell. Choose a family here, then edit the selected record back in the record editor.'
  String get shellTextDesktopFamiliesReadonlyHereMessage =>
      'This list belongs to the shipped shell. Choose a family here, then edit the selected record back in the record editor.';

  /// en: 'Use preset'
  String get shellTextDesktopUsePreset => 'Use preset';

  /// en: 'launched'
  String get shellTextLaunched => 'launched';

  /// en: 'Choose a saved profile, or return to the active profile editor without losing the current draft.'
  String get shellTextDesktopSavedProfilesRouteDetail =>
      'Choose a saved profile, or return to the active profile editor without losing the current draft.';

  /// en: 'Managed records'
  String get shellTextDesktopManagedRecordsTitle => 'Managed records';

  /// en: 'Choose a reusable managed record for the active profile draft, or return without changing the draft.'
  String get shellTextDesktopManagedRecordsRouteDetail =>
      'Choose a reusable managed record for the active profile draft, or return without changing the draft.';

  /// en: 'Create a provider record here, or reopen one to edit it. Families stay in a separate chooser.'
  String get shellTextDesktopProviderRecordsRouteDetail =>
      'Create a provider record here, or reopen one to edit it. Families stay in a separate chooser.';

  /// en: 'Preset bootstrap'
  String get shellTextDesktopPresetBootstrapTitle => 'Preset bootstrap';

  /// en: 'Seed the provider workflow from a curated preset, then return to the managed-provider editor route.'
  String get shellTextDesktopPresetBootstrapRouteDetail =>
      'Seed the provider workflow from a curated preset, then return to the managed-provider editor route.';

  /// en: 'Choose a read-only shipped family here, then return to the provider record editor.'
  String get shellTextDesktopProviderFamiliesRouteDetail =>
      'Choose a read-only shipped family here, then return to the provider record editor.';

  /// en: 'Workflow readiness'
  String get shellTextDesktopWorkflowReadiness => 'Workflow readiness';

  /// en: '{ready}/{total} tunnel modes ready'
  String shellTextDesktopTunnelModesReadySummary({
    required Object ready,
    required Object total,
  }) => '${ready}/${total} tunnel modes ready';

  /// en: 'Platform tunnel summary'
  String get shellTextDesktopPlatformTunnelSummary => 'Platform tunnel summary';

  /// en: '{resolutions} resolutions · {sessions} sessions'
  String shellTextDesktopResolutionsSessionsCompact({
    required Object resolutions,
    required Object sessions,
  }) => '${resolutions} resolutions · ${sessions} sessions';

  /// en: 'Support context pinned'
  String get shellTextDesktopSupportContextPinned => 'Support context pinned';

  /// en: 'Support attention is required'
  String get shellTextDesktopSupportAttentionRequired =>
      'Support attention is required';

  /// en: 'Support context is warming up'
  String get shellTextDesktopSupportContextWarmingUp =>
      'Support context is warming up';

  /// en: 'Live work is active'
  String get shellTextDesktopLiveWorkActive => 'Live work is active';

  /// en: 'Support note'
  String get shellTextDesktopSupportNote => 'Support note';

  /// en: 'The local host is blocked or incompatible. Keep the recovery path visible from the primary workflow.'
  String get shellTextDesktopSupportBlockedDetail =>
      'The local host is blocked or incompatible. Keep the recovery path visible from the primary workflow.';

  /// en: 'Host negotiation is still in progress. Diagnostics stay one action away without reclaiming the full shell.'
  String get shellTextDesktopSupportBootingDetail =>
      'Host negotiation is still in progress. Diagnostics stay one action away without reclaiming the full shell.';

  /// en: 'Use Live work to inspect the current runtime without letting the support surface reclaim the full shell.'
  String get shellTextDesktopSupportReadyLiveDetail =>
      'Use Live work to inspect the current runtime without letting the support surface reclaim the full shell.';

  /// en: 'Use Diagnostics or Live work when you need deeper inspection. The main workflow remains primary.'
  String get shellTextDesktopSupportReadyIdleDetail =>
      'Use Diagnostics or Live work when you need deeper inspection. The main workflow remains primary.';

  /// en: 'Inspector'
  String get shellTextDesktopInspector => 'Inspector';

  /// en: 'Diagnostics and platform tunnel detail stay secondary to the main task canvas.'
  String get shellTextDesktopInspectorDiagnosticsSubtitle =>
      'Diagnostics and platform tunnel detail stay secondary to the main task canvas.';

  /// en: 'Live resolutions and sessions stay available on demand without reclaiming the full shell.'
  String get shellTextDesktopInspectorActivitySubtitle =>
      'Live resolutions and sessions stay available on demand without reclaiming the full shell.';

  /// en: 'Tunnel detail'
  String get shellTextDesktopTunnelDetail => 'Tunnel detail';

  /// en: 'Platform tunnel modes'
  String get shellTextDesktopPlatformTunnelModes => 'Platform tunnel modes';

  /// en: 'Fail-closed platform tunnel checks stay collapsed until you explicitly test startup.'
  String get shellTextDesktopFailClosedCompactUntilStartup =>
      'Fail-closed platform tunnel checks stay collapsed until you explicitly test startup.';

  /// en: 'The connected host only reports fail-closed platform tunnel modes, so this section stays compact until you explicitly test startup.'
  String get shellTextDesktopFailClosedSectionCompactUntilStartup =>
      'The connected host only reports fail-closed platform tunnel modes, so this section stays compact until you explicitly test startup.';

  /// en: 'The desktop shell reads typed host tunnel capabilities and startup stages instead of guessing system routing support from the OS or app bundle.'
  String get shellTextDesktopTypedHostTunnelSummary =>
      'The desktop shell reads typed host tunnel capabilities and startup stages instead of guessing system routing support from the OS or app bundle.';

  /// en: 'The connected host did not report any desktop platform tunnel modes.'
  String get shellTextDesktopNoPlatformTunnelModesReported =>
      'The connected host did not report any desktop platform tunnel modes.';

  /// en: 'Use Diagnostics -> Tunnel detail to inspect startup stages and fail-closed results for the reported modes.'
  String get shellTextDesktopUseDiagnosticsForReportedModes =>
      'Use Diagnostics -> Tunnel detail to inspect startup stages and fail-closed results for the reported modes.';

  /// en: 'All reported tunnel modes are still fail-closed; inspect Diagnostics -> Tunnel detail for the latest startup evidence.'
  String get shellTextDesktopAllModesFailClosedLatestEvidence =>
      'All reported tunnel modes are still fail-closed; inspect Diagnostics -> Tunnel detail for the latest startup evidence.';

  /// en: 'All reported tunnel modes are currently fail-closed. Use Diagnostics -> Tunnel detail when you want to test startup explicitly.'
  String get shellTextDesktopAllModesFailClosedTestStartup =>
      'All reported tunnel modes are currently fail-closed. Use Diagnostics -> Tunnel detail when you want to test startup explicitly.';

  /// en: 'The host reports that this mode is available.'
  String get shellTextDesktopHostModeAvailable =>
      'The host reports that this mode is available.';

  /// en: 'The host reports that this mode is unavailable.'
  String get shellTextDesktopHostModeUnavailable =>
      'The host reports that this mode is unavailable.';

  /// en: 'No startup request yet. Use the typed host contract to verify the fail-closed path.'
  String get shellTextDesktopNoStartupRequestYet =>
      'No startup request yet. Use the typed host contract to verify the fail-closed path.';

  /// en: 'No active or recent sessions yet.'
  String get shellTextDesktopNoSessionsYet =>
      'No active or recent sessions yet.';

  /// en: 'Typed state transitions and challenge updates from /v1/events.'
  String get shellTextDesktopEventStreamSubtitle =>
      'Typed state transitions and challenge updates from /v1/events.';

  /// en: 'The shell is reconnecting to the local host. Keep the editor surface stable while negotiation completes.'
  String get shellTextDesktopWorkflowAssuranceBooting =>
      'The shell is reconnecting to the local host. Keep the editor surface stable while negotiation completes.';

  /// en: 'The local host is blocked or incompatible. Keep the recovery path visible from the primary workflow surface.'
  String get shellTextDesktopWorkflowAssuranceBlocked =>
      'The local host is blocked or incompatible. Keep the recovery path visible from the primary workflow surface.';

  /// en: 'The local host is ready. Keep the current workflow dominant while live runtime detail stays one step away.'
  String get shellTextDesktopWorkflowAssuranceReadyLive =>
      'The local host is ready. Keep the current workflow dominant while live runtime detail stays one step away.';

  /// en: 'The local host is ready. Routine support stays compact so the active workflow keeps visual priority.'
  String get shellTextDesktopWorkflowAssuranceReadyIdle =>
      'The local host is ready. Routine support stays compact so the active workflow keeps visual priority.';

  /// en: 'Continue after browser step'
  String get shellTextContinueAfterBrowserStep => 'Continue after browser step';

  /// en: 'Continue in browser'
  String get shellTextContinueInBrowser => 'Continue in browser';

  /// en: 'Provider family: {familyTitle}'
  String shellTextProviderFamilyLabel({required Object familyTitle}) =>
      'Provider family: ${familyTitle}';

  /// en: 'App-owned managed record'
  String get shellTextAppOwnedManagedRecord => 'App-owned managed record';

  /// en: 'Selected family'
  String get shellTextSelectedFamily => 'Selected family';

  /// en: 'Open browser'
  String get shellTextMobileOpenBrowser => 'Open browser';

  /// en: 'Continue in app'
  String get shellTextMobileContinueInApp => 'Continue in app';

  /// en: 'Cancelled the in-app browser continuation for challenge {challengeId} and marked the challenge cancelled.'
  String shellTextChallengeContinuationCancelled({
    required Object challengeId,
  }) =>
      'Cancelled the in-app browser continuation for challenge ${challengeId} and marked the challenge cancelled.';

  /// en: 'In-app browser continuation failed: {error}. Marked challenge {challengeId} as cancelled.'
  String shellTextChallengeContinuationFailed({
    required Object error,
    required Object challengeId,
  }) =>
      'In-app browser continuation failed: ${error}. Marked challenge ${challengeId} as cancelled.';

  /// en: 'Edit profile'
  String get shellTextMobileEditProfile => 'Edit profile';

  /// en: 'Selected for Home'
  String get shellTextMobileSelectedForHome => 'Selected for Home';

  /// en: 'Turn on VPN'
  String get shellTextMobileTurnOnVpn => 'Turn on VPN';

  /// en: 'Turn off VPN'
  String get shellTextMobileTurnOffVpn => 'Turn off VPN';

  /// en: 'Providers'
  String get shellTextMobileProvidersTitle => 'Providers';

  /// en: 'Choose a saved reusable provider or add a new one for Profiles.'
  String get shellTextMobileProvidersSubtitle =>
      'Choose a saved reusable provider or add a new one for Profiles.';

  /// en: 'Add provider'
  String get shellTextMobileAddProvider => 'Add provider';

  /// en: 'Back to providers'
  String get shellTextMobileBackToProviders => 'Back to providers';

  /// en: 'No provider'
  String get shellTextMobileNoProvider => 'No provider';

  /// en: 'input configured'
  String get shellTextMobileInputConfigured => 'input configured';

  /// en: 'Support'
  String get shellTextSupportTitle => 'Support';

  /// en: 'Activity, failures, logs, and diagnostics stay explicit but secondary to the main VPN workflow.'
  String get shellTextSupportSubtitle =>
      'Activity, failures, logs, and diagnostics stay explicit but secondary to the main VPN workflow.';

  /// en: 'Routing'
  String get shellTextRoutingTitle => 'Routing';

  /// en: 'Choose the VPN profile and app scope.'
  String get shellTextRoutingSubtitle =>
      'Choose the VPN profile and app scope.';

  /// en: 'Routing profile'
  String get shellTextRoutingProfile => 'Routing profile';

  /// en: 'Standard'
  String get shellTextRoutingProfileStandard => 'Standard';

  /// en: 'Development Wi-Fi'
  String get shellTextRoutingProfileDevelopmentWifi => 'Development Wi-Fi';

  /// en: 'Use the normal Android system VPN routing behavior for this mode.'
  String get shellTextRoutingProfileStandardDescription =>
      'Use the normal Android system VPN routing behavior for this mode.';

  /// en: 'Preserve the active local Wi-Fi network outside the VPN so development tools stay reachable while the VPN remains active.'
  String get shellTextRoutingProfileDevelopmentWifiDescription =>
      'Preserve the active local Wi-Fi network outside the VPN so development tools stay reachable while the VPN remains active.';

  /// en: 'App scope'
  String get shellTextAppScope => 'App scope';

  /// en: '{modeLabel} scope'
  String shellTextModeScope({required Object modeLabel}) =>
      '${modeLabel} scope';

  /// en: 'All apps'
  String get shellTextAllApps => 'All apps';

  /// en: 'Included apps'
  String get shellTextIncludedApps => 'Included apps';

  /// en: 'Excluded apps'
  String get shellTextExcludedApps => 'Excluded apps';

  /// en: '{selectedCount} selected out of {totalCount} installed apps.'
  String shellTextRoutingScopeSummary({
    required Object selectedCount,
    required Object totalCount,
  }) => '${selectedCount} selected out of ${totalCount} installed apps.';

  /// en: 'Search apps'
  String get shellTextSearchApps => 'Search apps';

  /// en: '{visibleCount} visible of {totalCount}; {selectedCount} visible selected.'
  String shellTextRoutingVisibleAppsSummary({
    required Object visibleCount,
    required Object totalCount,
    required Object selectedCount,
  }) =>
      '${visibleCount} visible of ${totalCount}; ${selectedCount} visible selected.';

  /// en: 'Actions'
  String get shellTextBulkActions => 'Actions';

  /// en: 'Select visible'
  String get shellTextSelectVisibleApps => 'Select visible';

  /// en: 'Clear visible'
  String get shellTextClearVisibleApps => 'Clear visible';

  /// en: 'All installed apps will use the Android system VPN path for this mobile mode.'
  String get shellTextAllInstalledAppsUseVpnPath =>
      'All installed apps will use the Android system VPN path for this mobile mode.';

  /// en: 'Retry app scan'
  String get shellTextRetryAppScan => 'Retry app scan';

  /// en: 'No installed apps were reported by the Android shell bridge.'
  String get shellTextNoInstalledAppsReported =>
      'No installed apps were reported by the Android shell bridge.';

  /// en: 'No installed apps match this search.'
  String get shellTextNoInstalledAppsMatchSearch =>
      'No installed apps match this search.';

  /// en: 'No saved profiles yet'
  String get shellTextHomeNoSavedProfilesYet => 'No saved profiles yet';

  /// en: 'Create or import a profile first, then come back here for the fast VPN toggle.'
  String get shellTextHomeNoSavedProfilesMessage =>
      'Create or import a profile first, then come back here for the fast VPN toggle.';

  /// en: 'Current profile'
  String get shellTextCurrentProfile => 'Current profile';

  /// en: 'Listening on {address}'
  String shellTextListeningOn({required Object address}) =>
      'Listening on ${address}';

  /// en: 'Current mode'
  String get shellTextCurrentMode => 'Current mode';

  /// en: 'The connected host has not advertised a mobile tunnel mode yet.'
  String get shellTextNoMobileTunnelModeAdvertised =>
      'The connected host has not advertised a mobile tunnel mode yet.';

  /// en: 'Execution path'
  String get shellTextExecutionPath => 'Execution path';

  /// en: 'Provider step'
  String get shellTextProviderStepTone => 'Provider step';

  /// en: 'Connection live'
  String get shellTextConnectionLiveTone => 'Connection live';

  /// en: 'Setup needed'
  String get shellTextSetupNeededTone => 'Setup needed';

  /// en: 'Main action'
  String get shellTextMainActionTone => 'Main action';

  /// en: 'Finish provider validation'
  String get shellTextFinishProviderValidation => 'Finish provider validation';

  /// en: 'VPN is on'
  String get shellTextVpnIsOn => 'VPN is on';

  /// en: 'Profile required'
  String get shellTextProfileRequired => 'Profile required';

  /// en: 'VPN is off'
  String get shellTextVpnIsOff => 'VPN is off';

  /// en: 'Continue the provider flow in the in-app browser before VPN can start.'
  String get shellTextContinueProviderFlowInApp =>
      'Continue the provider flow in the in-app browser before VPN can start.';

  /// en: 'Open the required browser step from Home, then return here and confirm completion before VPN can start.'
  String get shellTextOpenRequiredBrowserStepFromHome =>
      'Open the required browser step from Home, then return here and confirm completion before VPN can start.';

  /// en: 'Disconnect the current mobile VPN path from here.'
  String get shellTextDisconnectCurrentMobileVpnPath =>
      'Disconnect the current mobile VPN path from here.';

  /// en: 'Choose or finish a profile in Profiles before starting the current mobile VPN path.'
  String get shellTextChooseOrFinishProfileBeforeStartingVpn =>
      'Choose or finish a profile in Profiles before starting the current mobile VPN path.';

  /// en: 'Start the current mobile VPN path from here.'
  String get shellTextStartCurrentMobileVpnPath =>
      'Start the current mobile VPN path from here.';

  /// en: 'Continue in Profiles'
  String get shellTextContinueInProfiles => 'Continue in Profiles';

  /// en: 'Challenge: {kind}'
  String shellTextChallengeKind({required Object kind}) => 'Challenge: ${kind}';

  /// en: 'I've completed it'
  String get shellTextIveCompletedIt => 'I\'ve completed it';

  /// en: 'Cancel challenge'
  String get shellTextCancelChallenge => 'Cancel challenge';

  /// en: 'Need deeper detail?'
  String get shellTextNeedDeeperDetail => 'Need deeper detail?';

  /// en: 'Resolutions {resolutions} · Sessions {sessions} · {liveSummary}'
  String shellTextResolutionsSessionsSummary({
    required Object resolutions,
    required Object sessions,
    required Object liveSummary,
  }) => 'Resolutions ${resolutions} · Sessions ${sessions} · ${liveSummary}';

  /// en: 'No startup request yet.'
  String get shellTextNoStartupRequestYetShort => 'No startup request yet.';

  /// en: 'Routing is unavailable for this mode'
  String get shellTextRoutingUnavailableForMode =>
      'Routing is unavailable for this mode';

  /// en: 'Only mobile modes that support per-app scope expose this surface. Pick another mode from home if the host advertises one.'
  String get shellTextRoutingUnavailableMessage =>
      'Only mobile modes that support per-app scope expose this surface. Pick another mode from home if the host advertises one.';

  /// en: 'No saved providers yet'
  String get shellTextNoSavedProvidersYet => 'No saved providers yet';

  /// en: 'Add a provider, then reuse it from Profiles.'
  String get shellTextNoSavedProvidersMessage =>
      'Add a provider, then reuse it from Profiles.';

  /// en: 'Type: {familyTitle}'
  String shellTextTypeLabel({required Object familyTitle}) =>
      'Type: ${familyTitle}';

  /// en: 'Used in Profiles'
  String get shellTextUsedInProfiles => 'Used in Profiles';

  /// en: 'Create provider'
  String get shellTextCreateProvider => 'Create provider';

  /// en: 'Choose a provider type and configure a new saved provider.'
  String get shellTextCreateProviderChooseType =>
      'Choose a provider type and configure a new saved provider.';

  /// en: 'Use a template to prefill a new provider. Templates are starting points, not saved providers.'
  String get shellTextCreateProviderUseTemplate =>
      'Use a template to prefill a new provider. Templates are starting points, not saved providers.';

  /// en: 'Choose a shipped preset to prefill a new provider. Presets are read-only starting points, not editable records.'
  String get shellTextCreateProviderUsePreset =>
      'Choose a shipped preset to prefill a new provider. Presets are read-only starting points, not editable records.';

  /// en: 'Provider types'
  String get shellTextProviderTypes => 'Provider types';

  /// en: 'Presets'
  String get shellTextPresets => 'Presets';

  /// en: 'This build does not advertise any shipped provider types yet.'
  String get shellTextNoShippedProviderTypesYet =>
      'This build does not advertise any shipped provider types yet.';

  /// en: 'Search templates'
  String get shellTextSearchTemplates => 'Search templates';

  /// en: 'My templates'
  String get shellTextMyTemplates => 'My templates';

  /// en: 'No saved templates yet. Save a provider as a template to reuse it here.'
  String get shellTextNoSavedTemplatesYet =>
      'No saved templates yet. Save a provider as a template to reuse it here.';

  /// en: 'Save a provider as a template to manage reusable starting values here.'
  String get shellTextNoSavedTemplatesMessage =>
      'Save a provider as a template to manage reusable starting values here.';

  /// en: 'No saved templates match the current search.'
  String get shellTextNoSavedTemplatesMatchSearch =>
      'No saved templates match the current search.';

  /// en: 'Prefills new providers'
  String get shellTextPrefillsNewProviders => 'Prefills new providers';

  /// en: 'Shipped templates'
  String get shellTextShippedTemplates => 'Shipped templates';

  /// en: 'Shipped presets'
  String get shellTextShippedPresets => 'Shipped presets';

  /// en: 'No shipped templates match the current search.'
  String get shellTextNoShippedTemplatesMatchSearch =>
      'No shipped templates match the current search.';

  /// en: 'Starting point for new providers'
  String get shellTextStartingPointForNewProviders =>
      'Starting point for new providers';

  /// en: 'Read-only shipped template'
  String get shellTextReadOnlyShippedTemplate => 'Read-only shipped template';

  /// en: 'Inspect provider resolutions and session state without crowding the main workflow.'
  String get shellTextActivityPageSubtitle =>
      'Inspect provider resolutions and session state without crowding the main workflow.';

  /// en: 'Resolutions ({count})'
  String shellTextResolutionsCount({required Object count}) =>
      'Resolutions (${count})';

  /// en: 'Sessions ({count})'
  String shellTextSessionsCount({required Object count}) =>
      'Sessions (${count})';

  /// en: 'Detailed host readiness, platform tunnel detail, and recent typed events.'
  String get shellTextDiagnosticsPageSubtitle =>
      'Detailed host readiness, platform tunnel detail, and recent typed events.';

  /// en: 'Events ({count})'
  String shellTextEventsCount({required Object count}) => 'Events (${count})';

  /// en: 'Waiting for mobile host bridge negotiation.'
  String get shellTextWaitingForMobileHostBridge =>
      'Waiting for mobile host bridge negotiation.';

  /// en: 'GUI {label}'
  String shellTextGuiBuildTag({required Object label}) => 'GUI ${label}';

  /// en: 'Host {label}'
  String shellTextHostBuildTag({required Object label}) => 'Host ${label}';

  /// en: 'Contract {version}'
  String shellTextContractTag({required Object version}) =>
      'Contract ${version}';

  /// en: 'Reconnect'
  String get shellTextReconnect => 'Reconnect';

  /// en: 'Refresh'
  String get shellTextRefresh => 'Refresh';

  /// en: 'Resolutions'
  String get shellTextResolutionsTitle => 'Resolutions';

  /// en: 'Resolve the invite first, then use the capability-gated action set to start on this device, export a handoff, or open provider-native targets.'
  String get shellTextResolutionsSubtitle =>
      'Resolve the invite first, then use the capability-gated action set to start on this device, export a handoff, or open provider-native targets.';

  /// en: 'No provider resolutions yet.'
  String get shellTextNoProviderResolutionsYet =>
      'No provider resolutions yet.';

  /// en: 'This mobile slice renders typed host capability and startup-stage results for the reported platform modes. Use the controls below to start or disconnect supported system-tunnel paths.'
  String get shellTextSystemTunnelBannerText =>
      'This mobile slice renders typed host capability and startup-stage results for the reported platform modes. Use the controls below to start or disconnect supported system-tunnel paths.';

  /// en: 'The connected mobile host did not report any platform tunnel modes.'
  String get shellTextNoPlatformTunnelModesReported =>
      'The connected mobile host did not report any platform tunnel modes.';

  /// en: 'available'
  String get shellTextAvailableLowercase => 'available';

  /// en: 'unavailable'
  String get shellTextUnavailableLowercase => 'unavailable';

  /// en: 'Disconnect VPN'
  String get shellTextDisconnectVpn => 'Disconnect VPN';

  /// en: 'Request startup'
  String get shellTextRequestStartup => 'Request startup';

  /// en: 'No startup request yet. Use the typed mobile host contract to verify the fail-closed path.'
  String get shellTextNoStartupRequestYet =>
      'No startup request yet. Use the typed mobile host contract to verify the fail-closed path.';

  /// en: 'TURN {address} | {username}'
  String shellTextTurnCredentialsSummary({
    required Object address,
    required Object username,
  }) => 'TURN ${address} | ${username}';

  /// en: '{stage}: {message}'
  String shellTextFailureSummary({
    required Object stage,
    required Object message,
  }) => '${stage}: ${message}';

  /// en: 'More challenge actions'
  String get shellTextMoreChallengeActions => 'More challenge actions';

  /// en: 'More resolution actions'
  String get shellTextMoreResolutionActions => 'More resolution actions';

  /// en: 'Start on this device'
  String get shellTextStartOnThisDevice => 'Start on this device';

  /// en: 'Share handoff'
  String get shellTextShareHandoff => 'Share handoff';

  /// en: 'Open room'
  String get shellTextOpenRoom => 'Open room';

  /// en: 'Open camera'
  String get shellTextOpenCamera => 'Open camera';

  /// en: 'Open archive'
  String get shellTextOpenArchive => 'Open archive';

  /// en: 'Copy handoff'
  String get shellTextCopyHandoff => 'Copy handoff';

  /// en: 'Cancel resolution'
  String get shellTextCancelResolution => 'Cancel resolution';

  /// en: 'Sessions'
  String get shellTextSessionsTitle => 'Sessions';

  /// en: 'No active or recent mobile sessions yet.'
  String get shellTextNoMobileSessionsYet =>
      'No active or recent mobile sessions yet.';

  /// en: 'listen {listen} | connections {connections}'
  String shellTextSessionListenConnections({
    required Object listen,
    required Object connections,
  }) => 'listen ${listen} | connections ${connections}';

  /// en: 'Updated {timestamp} | session {sessionId}'
  String shellTextSessionUpdated({
    required Object timestamp,
    required Object sessionId,
  }) => 'Updated ${timestamp} | session ${sessionId}';

  /// en: 'More session actions'
  String get shellTextMoreSessionActions => 'More session actions';

  /// en: 'Stop session'
  String get shellTextStopSession => 'Stop session';

  /// en: 'Export diagnostics'
  String get shellTextExportDiagnostics => 'Export diagnostics';

  /// en: 'Event stream'
  String get shellTextEventStream => 'Event stream';

  /// en: 'Typed state transitions and challenge updates from the mobile host bridge.'
  String get shellTextEventStreamSubtitle =>
      'Typed state transitions and challenge updates from the mobile host bridge.';

  /// en: 'No events yet.'
  String get shellTextNoEventsYet => 'No events yet.';

  /// en: 'Reset needed'
  String get shellTextResetNeeded => 'Reset needed';

  /// en: 'Host ready'
  String get shellTextHostReady => 'Host ready';

  /// en: 'Host incompatible'
  String get shellTextHostIncompatible => 'Host incompatible';

  /// en: 'Host blocked'
  String get shellTextHostBlocked => 'Host blocked';

  /// en: 'Connecting'
  String get shellTextConnecting => 'Connecting';

  /// en: 'Mobile host ready'
  String get shellTextMobileHostReady => 'Mobile host ready';

  /// en: 'Mobile host incompatible'
  String get shellTextMobileHostIncompatible => 'Mobile host incompatible';

  /// en: 'Mobile host blocked'
  String get shellTextMobileHostBlocked => 'Mobile host blocked';

  /// en: 'Connecting to mobile host'
  String get shellTextConnectingToMobileHost => 'Connecting to mobile host';

  /// en: 'Satisfied prerequisites: {prerequisites}'
  String shellTextSatisfiedPrerequisites({required Object prerequisites}) =>
      'Satisfied prerequisites: ${prerequisites}';

  /// en: 'Missing prerequisite: {prerequisite}'
  String shellTextMissingPrerequisite({required Object prerequisite}) =>
      'Missing prerequisite: ${prerequisite}';

  /// en: 'The mobile host reports that this mode is available.'
  String get shellTextMobileHostModeAvailable =>
      'The mobile host reports that this mode is available.';

  /// en: 'The mobile host reports that this mode is unavailable.'
  String get shellTextMobileHostModeUnavailable =>
      'The mobile host reports that this mode is unavailable.';

  /// en: '{modeLabel} reached ready state for the mobile host tunnel path.'
  String shellTextPlatformTunnelReady({required Object modeLabel}) =>
      '${modeLabel} reached ready state for the mobile host tunnel path.';

  /// en: '{modeLabel} is ready with the {profileLabel} routing profile.'
  String shellTextPlatformTunnelReadyWithRoutingProfile({
    required Object modeLabel,
    required Object profileLabel,
  }) => '${modeLabel} is ready with the ${profileLabel} routing profile.';

  /// en: 'Startup blocked at {stageLabel}.'
  String shellTextStartupBlockedAt({required Object stageLabel}) =>
      'Startup blocked at ${stageLabel}.';

  /// en: 'Unknown stage'
  String get shellTextUnknownStage => 'Unknown stage';

  /// en: 'No mobile tunnel mode is currently selected.'
  String get shellTextNoMobileTunnelModeSelected =>
      'No mobile tunnel mode is currently selected.';

  /// en: 'Android system VPN mode'
  String get shellTextAndroidSystemVpnMode => 'Android system VPN mode';

  /// en: 'Apple network extension mode'
  String get shellTextAppleNetworkExtensionMode =>
      'Apple network extension mode';

  /// en: 'Windows Wintun mode'
  String get shellTextWindowsWintunMode => 'Windows Wintun mode';

  /// en: 'Linux TUN mode'
  String get shellTextLinuxTunMode => 'Linux TUN mode';

  /// en: 'Per-app routing is unavailable for this mobile mode.'
  String get shellTextPerAppRoutingUnavailable =>
      'Per-app routing is unavailable for this mobile mode.';

  /// en: 'Restart {modeLabel} to apply the selected routing profile.'
  String shellTextRestartVpnToApplyRoutingProfile({
    required Object modeLabel,
  }) => 'Restart ${modeLabel} to apply the selected routing profile.';

  /// en: '{modeLabel} does not advertise the Development Wi-Fi routing profile on this host.'
  String shellTextDevelopmentWifiRoutingUnavailableForHost({
    required Object modeLabel,
  }) =>
      '${modeLabel} does not advertise the Development Wi-Fi routing profile on this host.';

  /// en: 'The saved Development Wi-Fi preference is unsupported by the connected host. Switch back to Standard or reconnect to a compatible host.'
  String get shellTextDevelopmentWifiRoutingSavedButUnsupported =>
      'The saved Development Wi-Fi preference is unsupported by the connected host. Switch back to Standard or reconnect to a compatible host.';

  /// en: '{profileLabel}. {scopeSummary}'
  String shellTextRoutingSummaryWithProfile({
    required Object profileLabel,
    required Object scopeSummary,
  }) => '${profileLabel}. ${scopeSummary}';

  /// en: 'Scope: all installed apps.'
  String get shellTextScopeAllInstalledApps => 'Scope: all installed apps.';

  /// en: 'Scope: included apps, but no apps are selected yet.'
  String get shellTextScopeIncludedAppsEmpty =>
      'Scope: included apps, but no apps are selected yet.';

  /// en: 'Scope: only {count} selected apps.'
  String shellTextScopeOnlySelectedApps({required Object count}) =>
      'Scope: only ${count} selected apps.';

  /// en: 'Scope: excluded apps, but no apps are selected yet.'
  String get shellTextScopeExcludedAppsEmpty =>
      'Scope: excluded apps, but no apps are selected yet.';

  /// en: 'Scope: all apps except {count} selected apps.'
  String shellTextScopeAllExceptSelectedApps({required Object count}) =>
      'Scope: all apps except ${count} selected apps.';

  /// en: 'WireGuard native over TURN datagram'
  String get shellTextWireGuardNativeOverTurnDatagram =>
      'WireGuard native over TURN datagram';

  /// en: 'WireGuard native over TURN DTLS overlay'
  String get shellTextWireGuardNativeOverTurnDtls =>
      'WireGuard native over TURN DTLS overlay';

  /// en: 'WireGuard native over WebRTC data channel'
  String get shellTextWireGuardNativeOverWebRtc =>
      'WireGuard native over WebRTC data channel';

  /// en: 'Custom packet overlay over TURN datagram'
  String get shellTextCustomOverlayOverTurnDatagram =>
      'Custom packet overlay over TURN datagram';

  /// en: 'Custom packet overlay over TURN DTLS overlay'
  String get shellTextCustomOverlayOverTurnDtls =>
      'Custom packet overlay over TURN DTLS overlay';

  /// en: 'Custom packet overlay over WebRTC data channel'
  String get shellTextCustomOverlayOverWebRtc =>
      'Custom packet overlay over WebRTC data channel';

  /// en: 'Proxy core adapter over TURN datagram'
  String get shellTextProxyCoreOverTurnDatagram =>
      'Proxy core adapter over TURN datagram';

  /// en: 'Proxy core adapter over TURN DTLS overlay'
  String get shellTextProxyCoreOverTurnDtls =>
      'Proxy core adapter over TURN DTLS overlay';

  /// en: 'Proxy core adapter over WebRTC data channel'
  String get shellTextProxyCoreOverWebRtc =>
      'Proxy core adapter over WebRTC data channel';

  /// en: 'TrustTunnel native over TURN datagram'
  String get shellTextTrustTunnelOverTurnDatagram =>
      'TrustTunnel native over TURN datagram';

  /// en: 'TrustTunnel native over TURN DTLS overlay'
  String get shellTextTrustTunnelOverTurnDtls =>
      'TrustTunnel native over TURN DTLS overlay';

  /// en: 'TrustTunnel native over WebRTC data channel'
  String get shellTextTrustTunnelOverWebRtc =>
      'TrustTunnel native over WebRTC data channel';

  /// en: 'This challenge does not advertise the app-owned browser metadata required for in-app continuation.'
  String get shellTextOwnedBrowserMissingMetadata =>
      'This challenge does not advertise the app-owned browser metadata required for in-app continuation.';

  /// en: 'This challenge does not expose an in-app browser URL.'
  String get shellTextOwnedBrowserMissingUrl =>
      'This challenge does not expose an in-app browser URL.';

  /// en: 'The embedded browser session did not expose any usable continuation evidence.'
  String get shellTextOwnedBrowserNoEvidence =>
      'The embedded browser session did not expose any usable continuation evidence.';

  /// en: 'This device cannot expose the desktop browser metadata required for the in-app VK flow. Update Android System WebView or Chrome and try again.'
  String get shellTextOwnedBrowserDesktopFingerprintUnavailable =>
      'This device cannot expose the desktop browser metadata required for the in-app VK flow. Update Android System WebView or Chrome and try again.';

  /// en: '{provider} challenge'
  String shellTextOwnedBrowserTitle({required Object provider}) =>
      '${provider} challenge';

  /// en: 'Open invite'
  String get shellTextOwnedBrowserOpenInvite => 'Open invite';

  /// en: 'Collecting...'
  String get shellTextOwnedBrowserCollecting => 'Collecting...';

  /// en: 'Continue'
  String get shellTextOwnedBrowserContinue => 'Continue';

  /// en: 'Complete the browser step in this in-app session, then continue.'
  String get shellTextOwnedBrowserFallbackPrompt =>
      'Complete the browser step in this in-app session, then continue.';

  /// en: 'Hide keyboard'
  String get shellTextOwnedBrowserHideKeyboard => 'Hide keyboard';

  /// en: '{modeLabel} blocked at {stageLabel}.'
  String shellTextPlatformTunnelBlockedBase({
    required Object modeLabel,
    required Object stageLabel,
  }) => '${modeLabel} blocked at ${stageLabel}.';

  /// en: ' Missing prerequisite: {prerequisiteLabel}.'
  String shellTextPlatformTunnelBlockedMissingPrerequisite({
    required Object prerequisiteLabel,
  }) => ' Missing prerequisite: ${prerequisiteLabel}.';

  /// en: 'No reusable settings yet. Save this as a named provider for Profiles.'
  String get shellTextMobileNoReusableSettingsYetNamedProviderUnnamed =>
      'No reusable settings yet. Save this as a named provider for Profiles.';

  /// en: 'No reusable settings yet. Save {providerTitle} as a named provider for Profiles.'
  String shellTextMobileNoReusableSettingsYetNamedProviderNamed({
    required Object providerTitle,
  }) =>
      'No reusable settings yet. Save ${providerTitle} as a named provider for Profiles.';

  /// en: 'No reusable settings yet. Save this template as a named starting point.'
  String get shellTextMobileNoReusableSettingsYetTemplateUnnamed =>
      'No reusable settings yet. Save this template as a named starting point.';

  /// en: 'No reusable settings yet. Save {providerTitle} as a named starting point.'
  String shellTextMobileNoReusableSettingsYetTemplateNamed({
    required Object providerTitle,
  }) =>
      'No reusable settings yet. Save ${providerTitle} as a named starting point.';

  /// en: '{modeLabel} is available for the connected host.'
  String shellTextDesktopCompactPlatformTunnelCapabilitySummaryAvailable({
    required Object modeLabel,
  }) => '${modeLabel} is available for the connected host.';

  /// en: '{modeLabel} is unavailable'
  String shellTextDesktopCompactPlatformTunnelCapabilitySummaryUnavailable({
    required Object modeLabel,
  }) => '${modeLabel} is unavailable';

  /// en: ' because {missingPrerequisite} is still missing.'
  String
  shellTextDesktopCompactPlatformTunnelCapabilitySummaryMissingPrerequisite({
    required Object missingPrerequisite,
  }) => ' because ${missingPrerequisite} is still missing.';

  /// en: ' for the connected host.'
  String
  get shellTextDesktopCompactPlatformTunnelCapabilitySummaryUnavailableSuffix =>
      ' for the connected host.';

  /// en: '{modeLabel} unavailable'
  String shellTextDesktopCompactPlatformTunnelStatusLabelUnavailable({
    required Object modeLabel,
  }) => '${modeLabel} unavailable';

  /// en: '{modeLabel}: {missing} missing'
  String shellTextDesktopCompactPlatformTunnelStatusLabelMissing({
    required Object modeLabel,
    required Object missing,
  }) => '${modeLabel}: ${missing} missing';

  /// en: '{modeLabel} reached ready state for the desktop host tunnel path.'
  String shellTextDesktopPlatformTunnelResultSummaryReady({
    required Object modeLabel,
  }) => '${modeLabel} reached ready state for the desktop host tunnel path.';

  /// en: 'Startup blocked at {stageLabel}.'
  String shellTextDesktopPlatformTunnelResultSummaryBlocked({
    required Object stageLabel,
  }) => 'Startup blocked at ${stageLabel}.';

  /// en: 'starting'
  String get shellTextStateStarting => 'starting';

  /// en: 'challenge required'
  String get shellTextStateChallengeRequired => 'challenge required';

  /// en: 'ready'
  String get shellTextStateReady => 'ready';

  /// en: 'retrying'
  String get shellTextStateRetrying => 'retrying';

  /// en: 'stopping'
  String get shellTextStateStopping => 'stopping';

  /// en: 'stopped'
  String get shellTextStateStopped => 'stopped';

  /// en: 'failed'
  String get shellTextStateFailed => 'failed';

  /// en: 'resolved'
  String get shellTextStateResolved => 'resolved';

  /// en: 'cancelled'
  String get shellTextStateCancelled => 'cancelled';

  /// en: 'expired'
  String get shellTextStateExpired => 'expired';

  /// en: 'host'
  String get shellTextExecutionOwnerHost => 'host';

  /// en: 'shell local'
  String get shellTextExecutionOwnerShellLocal => 'shell local';

  /// en: 'shell external'
  String get shellTextExecutionOwnerShellExternal => 'shell external';

  /// en: '{modeLabel}. {routingSummary}'
  String shellTextModeSummaryWithoutExecutionPath({
    required Object modeLabel,
    required Object routingSummary,
  }) => '${modeLabel}. ${routingSummary}';

  /// en: '{modeLabel}. {routingSummary} Execution path: {executionPath}.'
  String shellTextModeSummaryWithExecutionPath({
    required Object modeLabel,
    required Object routingSummary,
    required Object executionPath,
  }) => '${modeLabel}. ${routingSummary} Execution path: ${executionPath}.';

  /// en: 'Export expiry {timestamp}'
  String shellTextExportExpiry({required Object timestamp}) =>
      'Export expiry ${timestamp}';

  /// en: 'Export expiry {timestamp} via {source}'
  String shellTextExportExpiryWithSource({
    required Object timestamp,
    required Object source,
  }) => 'Export expiry ${timestamp} via ${source}';
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
          'appDesktopReferencesTitle' =>
            'vk-turn-proxy desktop shell references',
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
          'commonSettings' => 'Settings',
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
          'sharedPlatformTunnelStartupStageCapabilityCheck' =>
            'Capability check',
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
          'shellTextClose' => 'Close',
          'shellTextCancel' => 'Cancel',
          'shellTextBack' => 'Back',
          'shellTextSave' => 'Save',
          'shellTextDelete' => 'Delete',
          'shellTextNewItem' => 'New',
          'shellTextMissing' => 'missing',
          'shellTextUnknownValue' => 'unknown',
          'shellTextFailureFallback' => 'failure',
          'shellTextRetry' => 'Retry',
          'shellTextActivity' => 'Activity',
          'shellTextDiagnostics' => 'Diagnostics',
          'shellTextOverview' => 'Overview',
          'shellTextEvents' => 'Events',
          'shellTextTemplates' => 'Templates',
          'shellTextAvailable' => 'Available',
          'shellTextUnavailable' => 'Unavailable',
          'shellTextOpenActivity' => 'Open activity',
          'shellTextOpenDiagnostics' => 'Open diagnostics',
          'shellTextOpenProfiles' => 'Open profiles',
          'shellTextResetLocalState' => 'Reset local state',
          'shellTextForgetEmbeddedSignIn' => 'Forget embedded sign-in',
          'shellTextEmbeddedBrowserStateTitle' =>
            'Embedded browser cookies and session',
          'shellTextEmbeddedBrowserStateBody' =>
            'The in-app browser keeps its own app-owned cookies and storage. Rebooting the device does not clear this state.',
          'shellTextEmbeddedBrowserStateHint' =>
            'Use this reset before a clean provider sign-in test or when an old VK session keeps getting reused. It only clears the embedded WebView inside this app.',
          'shellTextImportFromFile' => 'Import from file',
          'shellTextExportSavedProfile' => 'Export saved profile',
          'shellTextSelectedProfileActions' => 'Selected profile',
          'shellTextMakeCurrent' => 'Make current',
          'shellTextCopyProfile' => 'Copy profile',
          'shellTextPasteEnvelope' => 'Paste envelope',
          'shellTextCopyText' => 'Copy text',
          'shellTextSaveFile' => 'Save file',
          'shellTextShareText' => 'Share text',
          'shellTextShareFile' => 'Share file',
          'shellTextPreviewImport' => 'Preview import',
          'shellTextImportProfile' => 'Import profile',
          'shellTextPortableProfileJson' => 'Portable profile JSON',
          'shellTextPortableProfileEnvelope' => 'Portable profile envelope',
          'shellTextNoManagedProvidersAvailableYet' =>
            'No managed providers are available yet.',
          'shellTextSelectedProviderNotAdvertisedByConnectedHost' =>
            'The selected provider is not advertised by the connected host.',
          'shellTextSelectedProviderNotAdvertisedByConnectedMobileHost' =>
            'The selected provider is not advertised by the connected mobile host.',
          'shellTextSavedProfile' =>
            ({required Object profileLabel}) =>
                'Saved profile ${profileLabel}.',
          'shellTextSavedMobileProfile' =>
            ({required Object profileLabel}) =>
                'Saved mobile profile ${profileLabel}.',
          'shellTextDeletedProfile' =>
            ({required Object profileId}) => 'Deleted profile ${profileId}.',
          'shellTextDeletedMobileProfile' =>
            ({required Object profileId}) =>
                'Deleted mobile profile ${profileId}.',
          'shellTextDuplicatedItemLabel' =>
            ({required Object sourceLabel}) => '${sourceLabel} copy',
          'shellTextDuplicatedItemFallbackLabel' => 'Copied item',
          'shellTextSeededProfileCopyDraft' =>
            ({required Object profileLabel}) =>
                'Seeded a new profile draft from ${profileLabel}.',
          'shellTextSavedManagedProvider' =>
            ({required Object providerLabel}) =>
                'Saved managed provider ${providerLabel}.',
          'shellTextDeletedManagedProvider' =>
            ({required Object providerId}) =>
                'Deleted managed provider ${providerId}.',
          'shellTextSeededManagedProviderCopyDraft' =>
            ({required Object providerLabel}) =>
                'Seeded a new managed provider draft from ${providerLabel}.',
          'shellTextSaveOrSelectProfileBeforeExport' =>
            'Save or select a profile before exporting it.',
          'shellTextSelectedProfileDependsOnMissingManagedProviderSnapshot' =>
            'The selected profile depends on a managed provider snapshot that is no longer available locally.',
          'shellTextCopiedPortableProfile' =>
            ({required Object profileLabel}) =>
                'Copied portable profile ${profileLabel}.',
          'shellTextCopiedSecretBearingPortableProfile' =>
            ({required Object profileLabel}) =>
                'Copied secret-bearing portable profile ${profileLabel}. Treat the payload like a credential.',
          'shellTextSavedPortableProfile' =>
            ({required Object profileLabel, required Object path}) =>
                'Saved portable profile ${profileLabel} to ${path}.',
          'shellTextSavedSecretBearingPortableProfile' =>
            ({required Object profileLabel, required Object path}) =>
                'Saved secret-bearing portable profile ${profileLabel} to ${path}.',
          'shellTextSharedPortableProfileAsText' =>
            ({required Object profileLabel}) =>
                'Shared portable profile ${profileLabel} as text.',
          'shellTextSharedSecretBearingPortableProfileAsText' =>
            ({required Object profileLabel}) =>
                'Shared secret-bearing portable profile ${profileLabel} as text.',
          'shellTextSharedPortableProfileAsFile' =>
            ({required Object profileLabel}) =>
                'Shared portable profile ${profileLabel} as a file.',
          'shellTextSharedSecretBearingPortableProfileAsFile' =>
            ({required Object profileLabel}) =>
                'Shared secret-bearing portable profile ${profileLabel} as a file.',
          'shellTextImportedProfile' =>
            ({required Object profileLabel}) =>
                'Imported profile ${profileLabel}.',
          'shellTextImportedSecretBearingProfile' =>
            ({required Object profileLabel}) =>
                'Imported secret-bearing profile ${profileLabel}. Review provider input before sharing it further.',
          'shellTextStartedSession' =>
            ({required Object sessionId}) => 'Started session ${sessionId}.',
          'shellTextStartedMobileSession' =>
            ({required Object sessionId}) =>
                'Started mobile session ${sessionId}.',
          'shellTextStoppedSession' =>
            ({required Object sessionId}) => 'Stopped session ${sessionId}.',
          'shellTextManagedProviderNoLongerAvailable' =>
            ({required Object providerId}) =>
                'Managed provider ${providerId} is no longer available.',
          'shellTextAppliedManagedProviderToActiveProfileDraft' =>
            ({required Object providerLabel}) =>
                'Applied managed provider ${providerLabel} to the active profile draft.',
          'shellTextAppliedManagedProviderToActiveMobileProfileDraft' =>
            ({required Object providerLabel}) =>
                'Applied managed provider ${providerLabel} to the active mobile profile draft.',
          'shellTextSeededManagedProviderDraftFromPreset' =>
            ({required Object presetTitle}) =>
                'Seeded a new managed provider draft from the ${presetTitle} preset.',
          'shellTextCancelledResolution' =>
            ({required Object resolutionId}) =>
                'Cancelled resolution ${resolutionId}.',
          'shellTextCancelledMobileResolution' =>
            ({required Object resolutionId}) =>
                'Cancelled mobile resolution ${resolutionId}.',
          'shellTextStartedSessionFromResolution' =>
            ({required Object sessionId, required Object resolutionId}) =>
                'Started session ${sessionId} from resolution ${resolutionId}. Ready is reported only after runtime startup succeeds.',
          'shellTextStartedMobileSessionFromResolution' =>
            ({required Object sessionId, required Object resolutionId}) =>
                'Started mobile session ${sessionId} from resolution ${resolutionId}. Ready is reported only after runtime startup succeeds.',
          'shellTextCopiedHandoffLink' =>
            ({required Object resolutionId, required Object expiresAt}) =>
                'Copied handoff link for ${resolutionId}. Expires ${expiresAt}.',
          'shellTextSharedHandoffLink' =>
            ({required Object resolutionId, required Object expiresAt}) =>
                'Shared handoff link for ${resolutionId}. Expires ${expiresAt}.',
          'shellTextResolutionNoLongerAvailable' =>
            ({required Object resolutionId}) =>
                'Resolution ${resolutionId} is no longer available.',
          'shellTextResolutionDoesNotAdvertiseAction' =>
            ({required Object resolutionId, required Object actionLabel}) =>
                'Resolution ${resolutionId} does not advertise action "${actionLabel}".',
          'shellTextResolutionHasNoBrowserTarget' =>
            ({required Object resolutionId, required Object actionLabel}) =>
                'Resolution ${resolutionId} does not expose a browser target for action "${actionLabel}".',
          'shellTextOpenedResolutionAction' =>
            ({required Object actionLabel, required Object resolutionId}) =>
                'Opened action "${actionLabel}" for ${resolutionId}.',
          'shellTextFailedToOpenResolutionAction' =>
            ({required Object actionLabel, required Object resolutionId}) =>
                'Failed to open action "${actionLabel}" for ${resolutionId}.',
          'shellTextCancelledChallenge' =>
            ({required Object challengeId}) =>
                'Cancelled challenge ${challengeId}.',
          'shellTextExportedDiagnostics' =>
            ({required Object path}) => 'Exported diagnostics to ${path}.',
          'shellTextEventStreamClosed' => 'event stream closed',
          'shellTextLocalHostNotReady' => 'Local host is not ready.',
          'shellTextFailedToRestoreDesktopShellState' =>
            ({required Object error}) =>
                'Failed to restore desktop shell state: ${error}',
          'shellTextFailedToPersistDesktopShellState' =>
            ({required Object error}) =>
                'Failed to persist desktop shell state: ${error}',
          'shellTextFailedToPersistMobileShellState' =>
            ({required Object error}) =>
                'Failed to persist mobile shell state: ${error}',
          'shellTextClearedRememberedEmbeddedSignIn' =>
            'Cleared remembered embedded sign-in.',
          'shellTextFailedToClearRememberedEmbeddedSignIn' =>
            ({required Object error}) =>
                'Failed to clear remembered embedded sign-in: ${error}',
          'shellTextPlatformTunnelReadyForLocalHost' =>
            ({required Object modeLabel}) =>
                '${modeLabel} is ready for the local host tunnel path.',
          'shellTextStartedResolutionForProvider' =>
            ({required Object resolutionId, required Object providerName}) =>
                'Started resolution ${resolutionId} for ${providerName}.',
          'shellTextStartedResolutionForProviderWithExternalBrowser' =>
            ({required Object resolutionId, required Object providerName}) =>
                'Started resolution ${resolutionId} for ${providerName}. Finish the required external browser steps before expecting a resolved artifact.',
          'shellTextStartedResolutionForProviderWithBrowserContinuation' =>
            ({required Object resolutionId, required Object providerName}) =>
                'Started resolution ${resolutionId} for ${providerName}. Continue any browser challenge flow before expecting a resolved artifact.',
          'shellTextContinuedChallenge' =>
            ({required Object challengeId}) =>
                'Continued challenge ${challengeId}.',
          'shellTextContinuedChallengeWithExternalBrowser' =>
            ({required Object challengeId, required Object providerName}) =>
                'Continued challenge ${challengeId}. Finish the external browser flow for ${providerName} before expecting the next state transition.',
          'shellTextContinuedChallengeForResolution' =>
            ({required Object challengeId, required Object providerName}) =>
                'Continued challenge ${challengeId}. Finish the provider flow for ${providerName} before expecting a resolved artifact.',
          'shellTextContinuedChallengeForSession' =>
            ({required Object challengeId, required Object providerName}) =>
                'Continued challenge ${challengeId}. Finish the provider flow for ${providerName} before expecting the session to reach ready.',
          'shellTextDesktopProviderSettingsRuntimeUnsupported' =>
            ({required Object providerName, required Object error}) =>
                'The connected desktop shell cannot render provider settings for ${providerName}: ${error}',
          'shellTextMobileProviderSettingsRuntimeUnsupported' =>
            ({required Object providerName, required Object error}) =>
                'The connected mobile shell cannot render provider settings for ${providerName}: ${error}',
          'shellTextSelectedManagedProviderFamilyNotInSupportedCatalog' =>
            'The selected managed provider family is not part of the supported app catalog.',
          'shellTextSelectedManagedProviderNotInSupportedCatalog' =>
            'The selected managed provider is not part of the supported app catalog.',
          'shellTextManagedProviderNotInSupportedCatalog' =>
            'This managed provider is not part of the supported app catalog.',
          'shellTextDesktopReusableSettingsRuntimeUnsupported' =>
            ({required Object providerName, required Object error}) =>
                'The connected desktop shell cannot render reusable settings for ${providerName}: ${error}',
          'shellTextMobileReusableSettingsRuntimeUnsupported' =>
            ({required Object providerName, required Object error}) =>
                'The connected mobile shell cannot render reusable settings for ${providerName}: ${error}',
          'shellTextConnectedHostDoesNotAdvertiseProviderFamilyYet' =>
            ({required Object providerTitle}) =>
                'The connected host does not advertise the ${providerTitle} provider family yet.',
          'shellTextSelectedTemplateFamilyNotInSupportedCatalog' =>
            'The selected template family is not part of the supported app catalog.',
          'shellTextTemplateNotInSupportedCatalog' =>
            'This template is not part of the supported app catalog.',
          'shellTextMobileTemplateRuntimeUnsupported' =>
            ({required Object providerName, required Object error}) =>
                'The connected mobile shell cannot render reusable settings for ${providerName}: ${error}',
          'shellTextLocalHostShutdownRequested' =>
            'Local host shutdown requested.',
          'shellTextNoCompatibleLocalHostFound' =>
            'No compatible local host was found and no launch candidates are configured.',
          'shellTextLocalHostLaunchFailedWithoutReportedError' =>
            'Local host launch failed without a reported error.',
          'shellTextLocalHostLaunchFailed' =>
            ({required Object error}) => 'Local host launch failed: ${error}',
          'shellTextConnectedToLocalHost' =>
            ({required Object listenAddress}) =>
                'Connected to local host ${listenAddress}',
          'shellTextLaunchedLocalHost' =>
            ({required Object description, required Object listenAddress}) =>
                'Launched ${description} on ${listenAddress}',
          'shellTextSidecarLaunchCandidateEnvPath' => 'GUI_SHELL_CLIENTD_PATH',
          'shellTextSidecarLaunchCandidateNextToAppExecutable' =>
            'sidecar next to app executable',
          'shellTextSidecarLaunchCandidateBundledFrameworks' =>
            'bundled sidecar in Frameworks',
          'shellTextSidecarLaunchCandidateFromPath' => 'clientd from PATH',
          'shellTextSidecarLaunchCandidateRepoLocalGoRun' =>
            'repo-local go run fallback',
          'shellTextSidecarExitedBeforeReady' =>
            ({required Object description, required Object exitCode}) =>
                '${description} exited with code ${exitCode} before the control plane became ready.',
          'shellTextProviderExpectsLinkEntryOnlyDesktop' =>
            ({required Object providerName, required Object inputKind}) =>
                '${providerName} expects ${inputKind} input. This desktop shell currently supports link entry only.',
          'shellTextSavedTemplate' =>
            ({required Object templateLabel}) =>
                'Saved template ${templateLabel}.',
          'shellTextDeletedTemplate' =>
            ({required Object templateId}) => 'Deleted template ${templateId}.',
          'shellTextTemplateNoLongerAvailable' =>
            ({required Object templateId}) =>
                'Template ${templateId} is no longer available.',
          'shellTextSeededManagedProviderDraftFromTemplate' =>
            ({required Object templateLabel}) =>
                'Seeded a new managed provider draft from the ${templateLabel} template.',
          'shellTextSeededTemplateCopyDraft' =>
            ({required Object templateLabel}) =>
                'Seeded a new template draft from ${templateLabel}.',
          'shellTextClearedLocalMobileShellState' =>
            'Cleared local mobile shell state.',
          'shellTextFailedToClearLocalMobileShellState' =>
            ({required Object error}) =>
                'Failed to clear local mobile shell state: ${error}',
          'shellTextProviderExpectsLinkEntryOnlyMobile' =>
            ({required Object providerName, required Object inputKind}) =>
                '${providerName} expects ${inputKind} input. This mobile shell currently supports link entry only.',
          'shellTextResolutionUnavailableForPlatformTunnel' =>
            ({
              required Object modeLabel,
              required Object resolutionId,
              required Object stage,
              required Object message,
            }) =>
                'Cannot start ${modeLabel} because resolution ${resolutionId} ended at ${stage}: ${message}',
          'shellTextChallengeMustCompleteBeforeStarting' =>
            ({required Object modeLabel}) =>
                'Complete the current provider challenge before starting ${modeLabel}.',
          'shellTextWaitForProviderResolutionBeforeStarting' =>
            ({required Object modeLabel}) =>
                'Wait for the current provider resolution before starting ${modeLabel}.',
          'shellTextStartedMobileResolutionForProvider' =>
            ({required Object resolutionId, required Object providerName}) =>
                'Started mobile resolution ${resolutionId} for ${providerName}.',
          'shellTextStartedMobileResolutionForProviderWithExternalBrowser' =>
            ({required Object resolutionId, required Object providerName}) =>
                'Started mobile resolution ${resolutionId} for ${providerName}. Expect an external browser step when the provider requires it.',
          'shellTextStartedMobileResolutionForProviderWithBrowserContinuation' =>
            ({required Object resolutionId, required Object providerName}) =>
                'Started mobile resolution ${resolutionId} for ${providerName}. Complete any browser continuation before expecting a resolved artifact.',
          'shellTextResolutionStartedThenCompleteChallengeBeforeStarting' =>
            ({required Object startedNotice, required Object modeLabel}) =>
                '${startedNotice} Complete the current provider challenge before starting ${modeLabel}.',
          'shellTextReceivedPortableProfileForReview' =>
            ({required Object profileLabel}) =>
                'Received portable profile ${profileLabel}. Review it before importing.',
          'shellTextReceivedSecretBearingPortableProfileForReview' =>
            ({required Object profileLabel}) =>
                'Received a secret-bearing portable profile ${profileLabel}. Review it before importing.',
          'shellTextConnectedToMobileHostBridge' =>
            ({required Object baseUri}) =>
                'Connected to mobile host bridge ${baseUri}',
          'shellTextChallengeHasNoBrowserHandoffUrl' =>
            'This challenge does not expose a browser handoff URL.',
          'shellTextOpenedMobileBrowserHandoff' =>
            ({required Object challengeKind}) =>
                'Opened mobile browser handoff for ${challengeKind}. Return here after the browser step.',
          'shellTextFailedToOpenMobileBrowserHandoffUrl' =>
            'Failed to open the mobile browser handoff URL.',
          'shellTextPlatformTunnelDisconnected' =>
            ({required Object modeLabel}) => '${modeLabel} disconnected.',
          'shellTextSelectAtLeastOneIncludedApp' =>
            ({required Object modeLabel}) =>
                'Select at least one app before starting ${modeLabel} in included-apps mode.',
          'shellTextSelectAtLeastOneExcludedApp' =>
            ({required Object modeLabel}) =>
                'Select at least one app before starting ${modeLabel} in excluded-apps mode.',
          'shellTextSelectedMobileModeNotAdvertisedByConnectedHost' =>
            'The selected mobile mode is not advertised by the connected host.',
          'shellTextModeDoesNotAdvertiseSupportedExecutionPath' =>
            ({required Object modeLabel}) =>
                '${modeLabel} does not advertise a supported execution path yet.',
          'shellTextSelectExecutionPathBeforeStarting' =>
            ({required Object modeLabel}) =>
                'Select an execution path before starting ${modeLabel}.',
          'shellTextResetLocalMobileShellStateBeforeReconnecting' =>
            'Reset local mobile shell state before reconnecting.',
          'shellTextDetectedBrowserReturnAndContinuedChallenge' =>
            ({required Object signalLabel, required Object challengeId}) =>
                'Detected ${signalLabel} and continued challenge ${challengeId}.',
          'shellTextCompletedInAppBrowserContinuation' =>
            ({required Object challengeId}) =>
                'Completed the in-app browser continuation for challenge ${challengeId}.',
          'shellTextResetLocalMobileShellStateBeforeRuntimeControlContinue' =>
            'Reset local mobile shell state before runtime control can continue.',
          'shellTextAppLinkBrowserReturn' => 'app-link browser return',
          'shellTextUniversalLinkBrowserReturn' =>
            'universal-link browser return',
          'shellTextBrowserReturnOnAppResume' => 'browser return on app resume',
          'shellTextBrowserReturn' => 'browser return',
          'shellTextMobileHostBridgeNotReady' =>
            'Mobile host bridge is not ready.',
          'shellTextNativeMobileHostBridgeDidNotReturnHostConfiguration' =>
            'Native mobile host bridge did not return a host configuration.',
          'shellTextNativeMobileHostBridgeReturnedEmptyHostUrl' =>
            'Native mobile host bridge returned an empty host URL.',
          'shellTextNativeMobileHostBridgeReturnedInvalidHostUrl' =>
            ({required Object baseUrl}) =>
                'Native mobile host bridge returned an invalid host URL: ${baseUrl}',
          'shellTextNativeMobileHostBridgePluginUnavailable' =>
            'Native mobile host bridge plugin is unavailable.',
          'shellTextFailedToResolveMobileHostBridgeFromNativePlatform' =>
            ({required Object details}) =>
                'Failed to resolve the mobile host bridge from the native platform: ${details}',
          'shellTextNativeMobileHostBridgePluginUnavailableForPermissionRequests' =>
            'Native mobile host bridge plugin is unavailable for platform tunnel permission requests.',
          'shellTextFailedToRequestNativePlatformTunnelPermission' =>
            ({required Object details}) =>
                'Failed to request native platform tunnel permission: ${details}',
          'shellTextNativeMobileHostBridgeReturnedNoWebViewSnapshot' =>
            'Native mobile host bridge returned no WebView snapshot.',
          'shellTextFailedToInspectNativeWebView' =>
            ({required Object details}) =>
                'Failed to inspect native WebView: ${details}',
          'shellTextVktpMobileHostUrlInvalid' =>
            'VKTP_MOBILE_HOST_URL is not a valid URI for the mobile host bridge.',
          'shellTextNativeMobileHostBridgeDidNotProvideControlPlaneEndpoint' =>
            'Native mobile host bridge did not provide a control-plane endpoint.',
          'shellTextMobileHostBridgeNotConfigured' =>
            'Mobile host bridge is not configured. Package a compatible loopback host or set VKTP_MOBILE_HOST_URL for development.',
          'shellTextNativeMobileHostBridgePluginUnavailableForInstalledAppInventory' =>
            'Native mobile host bridge plugin is unavailable for installed-app inventory.',
          'shellTextFailedToListInstalledAppsFromNativePlatform' =>
            ({required Object details}) =>
                'Failed to list installed apps from the native platform: ${details}',
          'shellTextFailedToRestoreMobileShellState' =>
            ({required Object error}) =>
                'Failed to restore mobile shell state: ${error}',
          'shellTextProviderDidNotReturnStartableArtifact' =>
            'The provider did not return a startable artifact.',
          'shellTextLoopbackPeerBlockReason' =>
            ({required Object modeLabel, required Object peerAddress}) =>
                '${modeLabel} still points to loopback peer ${peerAddress}. Configure an operator-managed remote peer endpoint before starting the mobile VPN path.',
          'shellTextSecureProfileSecretsUnavailable' =>
            'Secure profile secrets are unavailable. Restore secure storage or clear the saved mobile shell state.',
          'shellTextSecureProfileSecretsMissing' =>
            ({required Object profileId}) =>
                'Secure profile secrets are missing for saved profile ${profileId}.',
          'shellTextSecureDraftSecretsUnavailable' =>
            'Secure draft secrets are unavailable. Restore secure storage or reset the draft.',
          'shellTextResolutionStartedThenWaitForFinishBeforeStarting' =>
            ({required Object startedNotice, required Object modeLabel}) =>
                '${startedNotice} Wait for the resolution to finish before starting ${modeLabel}.',
          'shellTextNoReusableFieldsYet' => 'No reusable fields yet',
          'shellTextSchemaBlockedInShell' => 'Schema blocked in this shell',
          'shellTextReusableFieldsReady' => 'Reusable fields ready',
          'shellTextProviderInput' => 'Provider input',
          'shellTextProviderLink' => 'Provider link',
          'shellTextProviderFamily' => 'Provider family',
          'shellTextProviderType' => 'Provider type',
          'shellTextProfileName' => 'Profile name',
          'shellTextLocalUdpListen' => 'Local UDP listen',
          'shellTextPeerAddress' => 'Peer address',
          'shellTextConnections' => 'Connections',
          'shellTextTurnMode' => 'TURN mode',
          'shellTextTurnOverride' => 'TURN override',
          'shellTextTurnPort' => 'TURN port',
          'shellTextBindInterface' => 'Bind interface',
          'shellTextLogLevel' => 'Log level',
          'shellTextDtlsEnabled' => 'DTLS enabled',
          'shellTextResolveInvite' => 'Resolve invite',
          'shellTextResolveProfile' => 'Resolve profile',
          'shellTextNotSet' => 'Not set',
          'shellTextStartSession' => 'Start session',
          'shellTextSaveProfile' => 'Save profile',
          'shellTextDeleteProfile' => 'Delete profile',
          'shellTextFreshDraft' => 'Fresh draft',
          'shellTextStartSavedProfile' => 'Start saved profile',
          'shellTextExportPortableProfile' => 'Export portable profile',
          'shellTextImportPortableProfile' => 'Import portable profile',
          'shellTextPastePortableProfileEnvelope' =>
            'Paste portable profile envelope',
          'shellTextPreviewOpensBeforeRecordsCreated' =>
            'Preview opens before any local records are created.',
          'shellTextPayloadInvalidOrUnsupported' =>
            'Payload is invalid or unsupported.',
          'shellTextProviderAndSource' =>
            ({required Object provider, required Object source}) =>
                'Provider: ${provider} · Source: ${source}',
          'shellTextProviderLabel' =>
            ({required Object provider}) => 'Provider: ${provider}',
          'shellTextSourceModeLabel' =>
            ({required Object mode}) => 'Source mode: ${mode}',
          'shellTextManagedProviderSnapshot' =>
            ({required Object name}) => 'Managed provider snapshot: ${name}',
          'shellTextPortableExportSecretWarningDesktop' =>
            'This payload is secret-bearing. Treat copied text, saved files, and QR screens like credentials.',
          'shellTextPortableExportSecretWarningMobile' =>
            'This payload is secret-bearing. Treat shared text, files, and QR screens like credentials.',
          'shellTextPortableExportSeparateFromRuntimeDesktop' =>
            'Exported payload stays separate from ordinary shell persistence and runtime handoff export.',
          'shellTextPortableExportSeparateFromRuntimeMobile' =>
            'Portable transfer stays separate from ordinary shell persistence and runtime handoff export.',
          'shellTextPortableQrCompactJson' =>
            'QR uses the same envelope in compact JSON form.',
          'shellTextPortableQrUnavailableDesktop' =>
            ({required Object bytes}) =>
                'QR is unavailable because this payload exceeds supported QR bounds (${bytes} bytes). File and text export stay available.',
          'shellTextPortableQrUnavailableMobile' =>
            ({required Object bytes}) =>
                'QR is unavailable because this payload exceeds supported QR bounds (${bytes} bytes). Text and file sharing stay available.',
          'shellTextPortableImportSecretWarning' =>
            'This import payload is secret-bearing. Confirm only if the source is trusted.',
          'shellTextPortableImportCreatesFreshIdsMobile' =>
            'Import creates fresh local ids and does not auto-start runtime.',
          'shellTextPortableImportCreatesFreshIdsDesktop' =>
            'Import creates new local records with fresh ids and does not auto-start runtime.',
          'shellTextScanPortableProfileQr' => 'Scan portable profile QR',
          'shellTextPointCameraAtPortableProfileQr' =>
            'Point the camera at a portable profile QR code.',
          'shellTextTagInput' => ({required Object value}) => 'Input: ${value}',
          'shellTextTagAuth' => ({required Object value}) => 'Auth: ${value}',
          'shellTextTagBrowser' =>
            ({required Object value}) => 'Browser: ${value}',
          'shellTextTagFamily' =>
            ({required Object value}) => 'Family: ${value}',
          'shellTextBrowserNeedsExternal' =>
            'This provider requires an external browser when challenge continuation appears.',
          'shellTextBrowserAllowsEmbedded' =>
            'This provider allows an embedded browser surface, but the host still controls whether a browser challenge appears.',
          'shellTextBrowserNotRequired' =>
            'This provider does not report a required browser surface.',
          'shellTextBrowserContinuationMayAppear' =>
            'Browser continuation may appear for this provider.',
          'shellTextBrowserContinuationNotAdvertised' =>
            'No browser challenge mode is currently advertised for this provider.',
          'shellTextDesktopProfileWorkspaceTitle' => 'Profile workspace',
          'shellTextDesktopUnsavedDraft' => 'Unsaved draft',
          'shellTextDesktopSavedProfileWorkspace' => 'Saved profile workspace',
          'shellTextDesktopSaveProfileFirst' => 'Save profile first',
          'shellTextDesktopStartSessionFromSavedProfile' =>
            'Start a session from this saved profile',
          'shellTextDesktopProfileSettings' => 'Profile settings',
          'shellTextDesktopChangeSource' => 'Change source',
          'shellTextDesktopChangeSourceSubtitle' =>
            'Switch between a saved provider record and draft-owned input only when the profile needs a different source.',
          'shellTextDesktopRuntimeDefaults' => 'Runtime defaults',
          'shellTextDesktopRuntimeDefaultsSubtitle' =>
            'These fields apply when the profile starts on this device.',
          'shellTextDesktopProfileMaintenance' => 'Profile maintenance',
          'shellTextDesktopProfileMaintenanceSubtitle' =>
            'Keep destructive actions out of the main edit flow.',
          'shellTextDesktopShowMaintenanceActions' =>
            'Show maintenance actions',
          'shellTextDesktopDeleteSavedProfileHint' =>
            'Delete the saved profile without crowding the action row.',
          'shellTextDesktopPortableTransferSubtitle' =>
            'Export the selected saved profile as an explicit transfer envelope, or preview an import before creating local records.',
          'shellTextDesktopBrowserHandling' => 'Browser handling',
          'shellTextDesktopBrowserHandlingSubtitle' =>
            'Show this context only when the provider can hand off into a browser challenge.',
          'shellTextDesktopProfileProviderSettings' =>
            'Profile provider settings',
          'shellTextDesktopProviderSettingsSupportError' =>
            ({required Object providerName, required Object error}) =>
                'This desktop shell cannot render the provider settings schema for ${providerName}: ${error}. Save and resolve stay blocked until the host advertises a supported schema subset.',
          'shellTextDesktopProfileProviderSettingsHelp' =>
            'Saved profile settings for the selected provider. Prompt-only values stay only in the active draft.',
          'shellTextDesktopNoSavedProviderRecords' =>
            'No saved provider records are available yet.',
          'shellTextDirectInput' => 'Direct input',
          'shellTextSavedRecord' => 'Saved record',
          'shellTextDesktopSavedRecordAttached' =>
            'A saved provider record is attached to this draft.',
          'shellTextDesktopDraftOwnsProviderInput' =>
            'This draft keeps its own provider input.',
          'shellTextMobileProfilesTitleBar' => 'Profiles',
          'shellTextMobileProviderDetails' => 'Provider details',
          'shellTextMobileProviderDetailsSubtitle' =>
            'Browser policy, artifact families, and challenge guidance',
          'shellTextMobileProviderSettingsSection' => 'Provider settings',
          'shellTextMobilePortableTransfer' => 'Portable transfer',
          'shellTextMobileProviderSettingsUnsupportedSubtitle' =>
            'Unsupported schema subset blocks save and resolve',
          'shellTextMobileProviderSettingsRetainedSubtitle' =>
            'Required and retained provider-specific values',
          'shellTextMobileAdvancedRuntimeControls' =>
            'Advanced runtime controls',
          'shellTextMobileAdvancedRuntimeControlsSubtitle' =>
            'Transport overrides, local bind, and logging',
          'shellTextMobilePortableTransferSubtitle' =>
            'Export the selected saved profile through an explicit envelope, or preview an import before creating local records.',
          'shellTextMobileProviderSettingsSupportError' =>
            ({required Object providerName, required Object error}) =>
                'This mobile shell cannot render the provider settings schema for ${providerName}: ${error}. Save and resolve stay blocked until the host advertises a supported schema subset.',
          'shellTextMobileProviderSettingsRetainedHelp' =>
            'Profile-retained settings stay with the saved profile. Prompt-only values remain only in the in-memory draft used for immediate resolution starts.',
          'shellTextMobileNoSavedProfilesYetBuildDraft' =>
            'No saved profiles yet. Build the draft below, then save it for repeat starts.',
          'shellTextMobileSavedProfiles' => 'Saved profiles',
          'shellTextMobileProviderMode' => 'Provider mode',
          'shellTextMobileProviderModeNoManagedProviders' =>
            'No managed providers are available yet. Use custom mode for direct provider entry or create a provider record from the workflow library first.',
          'shellTextCustomProvider' => 'Custom provider',
          'shellTextManagedProvider' => 'Managed provider',
          'shellTextMobileManagedModeSummary' =>
            'Managed mode snapshots values from a saved provider record, then keeps further profile edits local to this draft.',
          'shellTextMobileCustomModeSummary' =>
            'Custom mode lets you type a raw provider id and prompt-only inputs without mutating the managed provider catalog.',
          'shellTextMobileManagedProviderDropdown' => 'Managed provider',
          'shellTextMobileEditProvider' => 'Edit provider',
          'shellTextMobileNewProvider' => 'New provider',
          'shellTextMobileEditSavedReusableProvider' =>
            'Edit this saved reusable provider.',
          'shellTextMobileFinishSavedReusableProvider' =>
            'Finish this saved reusable provider for later use in Profiles.',
          'shellTextMobileCloseProviderEditor' => 'Close provider editor',
          'shellTextMobileNoShippedProviderFamilies' =>
            'This build does not advertise any shipped provider families yet.',
          'shellTextMobileProviderName' => 'Provider name',
          'shellTextMobileProviderShownInProfiles' =>
            'Shown in Profiles when choosing a saved reusable provider.',
          'shellTextMobileProviderTypeChosenWhenCreated' =>
            'Chosen when this saved provider was created. Use this pane to name it and review reusable settings.',
          'shellTextMobileProviderConfigSupportError' =>
            ({required Object providerName, required Object error}) =>
                'This mobile shell cannot render the provider settings schema for ${providerName}: ${error}. Save stays blocked until the host advertises a supported schema subset.',
          'shellTextMobileReusableProviderSettings' =>
            'Reusable provider settings',
          'shellTextMobileReusableValuesAppliedToProfile' =>
            'These reusable values are applied when this provider is used in a profile.',
          'shellTextMobileSaveProvider' => 'Save provider',
          'shellTextMobileSaveAsTemplate' => 'Save as template',
          'shellTextMobileUseInProfileDraft' => 'Use in profile draft',
          'shellTextMobileDeleteProvider' => 'Delete provider',
          'shellTextSavedProviders' => 'Saved providers',
          'shellTextSelectedProviderActions' => 'Selected provider',
          'shellTextCopyProvider' => 'Copy provider',
          'shellTextSelectedType' => 'Selected type',
          'shellTextMobileEditTemplate' => 'Edit template',
          'shellTextMobileNewTemplate' => 'New template',
          'shellTextMobileEditTemplateStartingValues' =>
            'Edit starting values for future providers.',
          'shellTextMobileSaveTemplateStartingPoint' =>
            'Save a starting point for future providers.',
          'shellTextMobileCloseTemplateEditor' => 'Close template editor',
          'shellTextMobileTemplateName' => 'Template name',
          'shellTextMobileTemplateShownWhenChoosing' =>
            'Shown when choosing a starting point for new providers.',
          'shellTextMobileTemplateTypeChosenWhenCreated' =>
            'Chosen when this template was created. Use this pane to name it and review reusable starting values.',
          'shellTextMobileReusableValuesPrefillProvider' =>
            'These values prefill a new provider when this template is used.',
          'shellTextMobileSaveTemplate' => 'Save template',
          'shellTextMobileUseTemplate' => 'Use template',
          'shellTextMobileDeleteTemplate' => 'Delete template',
          'shellTextSelectedTemplateActions' => 'Selected template',
          'shellTextCopyTemplate' => 'Copy template',
          'shellTextDesktopProviderRecord' => 'Provider record',
          'shellTextDesktopNewProviderRecord' => 'New provider record',
          'shellTextDesktopEditReusableProviderRecord' =>
            'Edit one reusable provider record. The attached family is shown below and stays read-only here.',
          'shellTextDesktopCreateReusableProviderRecord' =>
            'Create one reusable provider record. Choose its family separately, then edit the record parameters below.',
          'shellTextDesktopRecordParameters' => 'Record parameters',
          'shellTextDesktopParametersFor' =>
            ({required Object providerTitle}) =>
                'Parameters for ${providerTitle}',
          'shellTextDesktopChooseProviderFamilyFirst' =>
            'Choose a provider family from the separate family list first. Record parameters will appear here afterwards.',
          'shellTextDesktopEditReusableParametersFor' =>
            ({required Object providerTitle}) =>
                'Edit reusable parameters stored in this record for ${providerTitle}. This does not change the family itself.',
          'shellTextDesktopUseInProfileDraft' => 'Use in profile draft',
          'shellTextDesktopNewRecord' => 'New record',
          'shellTextDesktopRecordName' => 'Record name',
          'shellTextDesktopRecordNameHelp' =>
            'Name this saved provider record first. Family choice and record parameters stay below.',
          'shellTextDesktopAttachedFamily' => 'Attached family',
          'shellTextDesktopAttachedFamilyHelp' =>
            'Families live in a separate chooser. The selected family is attached to this record and described here.',
          'shellTextDesktopFamilyCharacteristics' => 'Family characteristics',
          'shellTextDesktopFamilyCharacteristicsHelp' =>
            'Read-only characteristics from the selected family and current host overlay.',
          'shellTextDesktopProviderRecordSupportError' =>
            ({required Object providerName, required Object error}) =>
                'This desktop shell cannot render the provider settings schema for ${providerName}: ${error}. Save stays blocked until the host advertises a supported schema subset.',
          'shellTextDesktopNoFamilyAttachedYet' => 'No family attached yet',
          'shellTextDesktopSelectedFamily' => 'Selected family',
          'shellTextDesktopOpenFamilyChooserFirst' =>
            'Open the separate family chooser before you continue with this provider record.',
          'shellTextDesktopFamilyAttachedToRecord' =>
            ({required Object providerTitle}) =>
                '${providerTitle} is attached to this record until you intentionally change it in the family chooser.',
          'shellTextDesktopShippedByApp' => 'Shipped by app',
          'shellTextDesktopHostOverlayAvailable' => 'Host overlay: available',
          'shellTextDesktopHostOverlayUnavailable' =>
            'Host overlay: unavailable',
          'shellTextDesktopUseActionStripToChooseFamily' =>
            'Use the action strip above to choose a family. Families are read-only here.',
          'shellTextDesktopFamiliesReadonlyEditBelow' =>
            'Families stay read-only here. Change the attached family from the action strip above; edit this record\'s parameters below.',
          'shellTextDesktopChooseFamily' => 'Choose family',
          'shellTextDesktopSaveDraft' => 'Save draft',
          'shellTextDesktopSaveRecord' => 'Save record',
          'shellTextDesktopReadOnlyFamily' => 'Read-only family',
          'shellTextDesktopAttachedFamilyCardHelp' =>
            'This card describes the attached family. Editable record parameters are shown below.',
          'shellTextDesktopNoEditableParametersYet' =>
            'No editable parameters yet',
          'shellTextDesktopNoEditableParameters' => 'No editable parameters',
          'shellTextDesktopEditableParametersReady' =>
            'Editable parameters ready',
          'shellTextDesktopNoSavedProfilesYetShort' => 'No saved profiles yet.',
          'shellTextDesktopNoShippedProviderFamilies' =>
            'This build does not advertise any shipped provider families yet.',
          'shellTextDesktopNoEditableRecordParameters' =>
            ({required Object providerTitle}) =>
                '${providerTitle} has no editable record parameters in this desktop shell.',
          'shellTextDesktopSavedProfilesLibraryTitle' => 'Saved profiles',
          'shellTextDesktopSavedProfilesLibrarySubtitle' =>
            'Browse saved operator workspaces intentionally, then return to the active editor without leaving the main path permanently split.',
          'shellTextDesktopReturnPathExplicitTitle' =>
            'Return path stays explicit',
          'shellTextDesktopReturnPathExplicitMessage' =>
            'Selecting a saved profile updates the active workflow and closes this secondary surface.',
          'shellTextDesktopProviderRecordsLibraryTitle' => 'Provider records',
          'shellTextDesktopProviderRecordsLibrarySubtitle' =>
            'Create a reusable provider record or reopen one you already saved.',
          'shellTextDesktopRecordsSeparateFromFamiliesTitle' =>
            'Records are separate from families',
          'shellTextDesktopRecordsSeparateFromFamiliesMessage' =>
            'Create a record here, then choose its family in the separate family chooser. Open an existing record to continue editing it.',
          'shellTextDesktopNoProviderRecordsYet' =>
            'No provider records yet. Create one to choose a family and store reusable parameters.',
          'shellTextDesktopNewFromPresetSubtitle' =>
            'Start from a curated provider seed only when you intentionally ask for it.',
          'shellTextDesktopPresetBootstrapExplicitTitle' =>
            'Preset bootstrap stays explicit',
          'shellTextDesktopPresetBootstrapExplicitMessage' =>
            'Unavailable presets remain visible and honest here, but they no longer occupy the default provider workspace.',
          'shellTextDesktopProviderFamiliesSubtitle' =>
            'Choose the shipped family here, then return to the provider record editor.',
          'shellTextDesktopFamiliesReadonlyHereTitle' =>
            'Families are read-only here',
          'shellTextDesktopFamiliesReadonlyHereMessage' =>
            'This list belongs to the shipped shell. Choose a family here, then edit the selected record back in the record editor.',
          'shellTextDesktopUsePreset' => 'Use preset',
          'shellTextLaunched' => 'launched',
          'shellTextDesktopSavedProfilesRouteDetail' =>
            'Choose a saved profile, or return to the active profile editor without losing the current draft.',
          'shellTextDesktopManagedRecordsTitle' => 'Managed records',
          'shellTextDesktopManagedRecordsRouteDetail' =>
            'Choose a reusable managed record for the active profile draft, or return without changing the draft.',
          'shellTextDesktopProviderRecordsRouteDetail' =>
            'Create a provider record here, or reopen one to edit it. Families stay in a separate chooser.',
          'shellTextDesktopPresetBootstrapTitle' => 'Preset bootstrap',
          'shellTextDesktopPresetBootstrapRouteDetail' =>
            'Seed the provider workflow from a curated preset, then return to the managed-provider editor route.',
          'shellTextDesktopProviderFamiliesRouteDetail' =>
            'Choose a read-only shipped family here, then return to the provider record editor.',
          'shellTextDesktopWorkflowReadiness' => 'Workflow readiness',
          'shellTextDesktopTunnelModesReadySummary' =>
            ({required Object ready, required Object total}) =>
                '${ready}/${total} tunnel modes ready',
          'shellTextDesktopPlatformTunnelSummary' => 'Platform tunnel summary',
          'shellTextDesktopResolutionsSessionsCompact' =>
            ({required Object resolutions, required Object sessions}) =>
                '${resolutions} resolutions · ${sessions} sessions',
          'shellTextDesktopSupportContextPinned' => 'Support context pinned',
          'shellTextDesktopSupportAttentionRequired' =>
            'Support attention is required',
          'shellTextDesktopSupportContextWarmingUp' =>
            'Support context is warming up',
          'shellTextDesktopLiveWorkActive' => 'Live work is active',
          'shellTextDesktopSupportNote' => 'Support note',
          'shellTextDesktopSupportBlockedDetail' =>
            'The local host is blocked or incompatible. Keep the recovery path visible from the primary workflow.',
          'shellTextDesktopSupportBootingDetail' =>
            'Host negotiation is still in progress. Diagnostics stay one action away without reclaiming the full shell.',
          'shellTextDesktopSupportReadyLiveDetail' =>
            'Use Live work to inspect the current runtime without letting the support surface reclaim the full shell.',
          'shellTextDesktopSupportReadyIdleDetail' =>
            'Use Diagnostics or Live work when you need deeper inspection. The main workflow remains primary.',
          'shellTextDesktopInspector' => 'Inspector',
          'shellTextDesktopInspectorDiagnosticsSubtitle' =>
            'Diagnostics and platform tunnel detail stay secondary to the main task canvas.',
          'shellTextDesktopInspectorActivitySubtitle' =>
            'Live resolutions and sessions stay available on demand without reclaiming the full shell.',
          'shellTextDesktopTunnelDetail' => 'Tunnel detail',
          'shellTextDesktopPlatformTunnelModes' => 'Platform tunnel modes',
          'shellTextDesktopFailClosedCompactUntilStartup' =>
            'Fail-closed platform tunnel checks stay collapsed until you explicitly test startup.',
          'shellTextDesktopFailClosedSectionCompactUntilStartup' =>
            'The connected host only reports fail-closed platform tunnel modes, so this section stays compact until you explicitly test startup.',
          'shellTextDesktopTypedHostTunnelSummary' =>
            'The desktop shell reads typed host tunnel capabilities and startup stages instead of guessing system routing support from the OS or app bundle.',
          'shellTextDesktopNoPlatformTunnelModesReported' =>
            'The connected host did not report any desktop platform tunnel modes.',
          'shellTextDesktopUseDiagnosticsForReportedModes' =>
            'Use Diagnostics -> Tunnel detail to inspect startup stages and fail-closed results for the reported modes.',
          'shellTextDesktopAllModesFailClosedLatestEvidence' =>
            'All reported tunnel modes are still fail-closed; inspect Diagnostics -> Tunnel detail for the latest startup evidence.',
          'shellTextDesktopAllModesFailClosedTestStartup' =>
            'All reported tunnel modes are currently fail-closed. Use Diagnostics -> Tunnel detail when you want to test startup explicitly.',
          'shellTextDesktopHostModeAvailable' =>
            'The host reports that this mode is available.',
          'shellTextDesktopHostModeUnavailable' =>
            'The host reports that this mode is unavailable.',
          'shellTextDesktopNoStartupRequestYet' =>
            'No startup request yet. Use the typed host contract to verify the fail-closed path.',
          'shellTextDesktopNoSessionsYet' =>
            'No active or recent sessions yet.',
          'shellTextDesktopEventStreamSubtitle' =>
            'Typed state transitions and challenge updates from /v1/events.',
          'shellTextDesktopWorkflowAssuranceBooting' =>
            'The shell is reconnecting to the local host. Keep the editor surface stable while negotiation completes.',
          'shellTextDesktopWorkflowAssuranceBlocked' =>
            'The local host is blocked or incompatible. Keep the recovery path visible from the primary workflow surface.',
          'shellTextDesktopWorkflowAssuranceReadyLive' =>
            'The local host is ready. Keep the current workflow dominant while live runtime detail stays one step away.',
          'shellTextDesktopWorkflowAssuranceReadyIdle' =>
            'The local host is ready. Routine support stays compact so the active workflow keeps visual priority.',
          'shellTextContinueAfterBrowserStep' => 'Continue after browser step',
          'shellTextContinueInBrowser' => 'Continue in browser',
          'shellTextProviderFamilyLabel' =>
            ({required Object familyTitle}) =>
                'Provider family: ${familyTitle}',
          'shellTextAppOwnedManagedRecord' => 'App-owned managed record',
          'shellTextSelectedFamily' => 'Selected family',
          _ => null,
        } ??
        switch (path) {
          'shellTextMobileOpenBrowser' => 'Open browser',
          'shellTextMobileContinueInApp' => 'Continue in app',
          'shellTextChallengeContinuationCancelled' =>
            ({required Object challengeId}) =>
                'Cancelled the in-app browser continuation for challenge ${challengeId} and marked the challenge cancelled.',
          'shellTextChallengeContinuationFailed' =>
            ({required Object error, required Object challengeId}) =>
                'In-app browser continuation failed: ${error}. Marked challenge ${challengeId} as cancelled.',
          'shellTextMobileEditProfile' => 'Edit profile',
          'shellTextMobileSelectedForHome' => 'Selected for Home',
          'shellTextMobileTurnOnVpn' => 'Turn on VPN',
          'shellTextMobileTurnOffVpn' => 'Turn off VPN',
          'shellTextMobileProvidersTitle' => 'Providers',
          'shellTextMobileProvidersSubtitle' =>
            'Choose a saved reusable provider or add a new one for Profiles.',
          'shellTextMobileAddProvider' => 'Add provider',
          'shellTextMobileBackToProviders' => 'Back to providers',
          'shellTextMobileNoProvider' => 'No provider',
          'shellTextMobileInputConfigured' => 'input configured',
          'shellTextSupportTitle' => 'Support',
          'shellTextSupportSubtitle' =>
            'Activity, failures, logs, and diagnostics stay explicit but secondary to the main VPN workflow.',
          'shellTextRoutingTitle' => 'Routing',
          'shellTextRoutingSubtitle' => 'Choose the VPN profile and app scope.',
          'shellTextRoutingProfile' => 'Routing profile',
          'shellTextRoutingProfileStandard' => 'Standard',
          'shellTextRoutingProfileDevelopmentWifi' => 'Development Wi-Fi',
          'shellTextRoutingProfileStandardDescription' =>
            'Use the normal Android system VPN routing behavior for this mode.',
          'shellTextRoutingProfileDevelopmentWifiDescription' =>
            'Preserve the active local Wi-Fi network outside the VPN so development tools stay reachable while the VPN remains active.',
          'shellTextAppScope' => 'App scope',
          'shellTextModeScope' =>
            ({required Object modeLabel}) => '${modeLabel} scope',
          'shellTextAllApps' => 'All apps',
          'shellTextIncludedApps' => 'Included apps',
          'shellTextExcludedApps' => 'Excluded apps',
          'shellTextRoutingScopeSummary' =>
            ({required Object selectedCount, required Object totalCount}) =>
                '${selectedCount} selected out of ${totalCount} installed apps.',
          'shellTextSearchApps' => 'Search apps',
          'shellTextRoutingVisibleAppsSummary' =>
            ({
              required Object visibleCount,
              required Object totalCount,
              required Object selectedCount,
            }) =>
                '${visibleCount} visible of ${totalCount}; ${selectedCount} visible selected.',
          'shellTextBulkActions' => 'Actions',
          'shellTextSelectVisibleApps' => 'Select visible',
          'shellTextClearVisibleApps' => 'Clear visible',
          'shellTextAllInstalledAppsUseVpnPath' =>
            'All installed apps will use the Android system VPN path for this mobile mode.',
          'shellTextRetryAppScan' => 'Retry app scan',
          'shellTextNoInstalledAppsReported' =>
            'No installed apps were reported by the Android shell bridge.',
          'shellTextNoInstalledAppsMatchSearch' =>
            'No installed apps match this search.',
          'shellTextHomeNoSavedProfilesYet' => 'No saved profiles yet',
          'shellTextHomeNoSavedProfilesMessage' =>
            'Create or import a profile first, then come back here for the fast VPN toggle.',
          'shellTextCurrentProfile' => 'Current profile',
          'shellTextListeningOn' =>
            ({required Object address}) => 'Listening on ${address}',
          'shellTextCurrentMode' => 'Current mode',
          'shellTextNoMobileTunnelModeAdvertised' =>
            'The connected host has not advertised a mobile tunnel mode yet.',
          'shellTextExecutionPath' => 'Execution path',
          'shellTextProviderStepTone' => 'Provider step',
          'shellTextConnectionLiveTone' => 'Connection live',
          'shellTextSetupNeededTone' => 'Setup needed',
          'shellTextMainActionTone' => 'Main action',
          'shellTextFinishProviderValidation' => 'Finish provider validation',
          'shellTextVpnIsOn' => 'VPN is on',
          'shellTextProfileRequired' => 'Profile required',
          'shellTextVpnIsOff' => 'VPN is off',
          'shellTextContinueProviderFlowInApp' =>
            'Continue the provider flow in the in-app browser before VPN can start.',
          'shellTextOpenRequiredBrowserStepFromHome' =>
            'Open the required browser step from Home, then return here and confirm completion before VPN can start.',
          'shellTextDisconnectCurrentMobileVpnPath' =>
            'Disconnect the current mobile VPN path from here.',
          'shellTextChooseOrFinishProfileBeforeStartingVpn' =>
            'Choose or finish a profile in Profiles before starting the current mobile VPN path.',
          'shellTextStartCurrentMobileVpnPath' =>
            'Start the current mobile VPN path from here.',
          'shellTextContinueInProfiles' => 'Continue in Profiles',
          'shellTextChallengeKind' =>
            ({required Object kind}) => 'Challenge: ${kind}',
          'shellTextIveCompletedIt' => 'I\'ve completed it',
          'shellTextCancelChallenge' => 'Cancel challenge',
          'shellTextNeedDeeperDetail' => 'Need deeper detail?',
          'shellTextResolutionsSessionsSummary' =>
            ({
              required Object resolutions,
              required Object sessions,
              required Object liveSummary,
            }) =>
                'Resolutions ${resolutions} · Sessions ${sessions} · ${liveSummary}',
          'shellTextNoStartupRequestYetShort' => 'No startup request yet.',
          'shellTextRoutingUnavailableForMode' =>
            'Routing is unavailable for this mode',
          'shellTextRoutingUnavailableMessage' =>
            'Only mobile modes that support per-app scope expose this surface. Pick another mode from home if the host advertises one.',
          'shellTextNoSavedProvidersYet' => 'No saved providers yet',
          'shellTextNoSavedProvidersMessage' =>
            'Add a provider, then reuse it from Profiles.',
          'shellTextTypeLabel' =>
            ({required Object familyTitle}) => 'Type: ${familyTitle}',
          'shellTextUsedInProfiles' => 'Used in Profiles',
          'shellTextCreateProvider' => 'Create provider',
          'shellTextCreateProviderChooseType' =>
            'Choose a provider type and configure a new saved provider.',
          'shellTextCreateProviderUseTemplate' =>
            'Use a template to prefill a new provider. Templates are starting points, not saved providers.',
          'shellTextCreateProviderUsePreset' =>
            'Choose a shipped preset to prefill a new provider. Presets are read-only starting points, not editable records.',
          'shellTextProviderTypes' => 'Provider types',
          'shellTextPresets' => 'Presets',
          'shellTextNoShippedProviderTypesYet' =>
            'This build does not advertise any shipped provider types yet.',
          'shellTextSearchTemplates' => 'Search templates',
          'shellTextMyTemplates' => 'My templates',
          'shellTextNoSavedTemplatesYet' =>
            'No saved templates yet. Save a provider as a template to reuse it here.',
          'shellTextNoSavedTemplatesMessage' =>
            'Save a provider as a template to manage reusable starting values here.',
          'shellTextNoSavedTemplatesMatchSearch' =>
            'No saved templates match the current search.',
          'shellTextPrefillsNewProviders' => 'Prefills new providers',
          'shellTextShippedTemplates' => 'Shipped templates',
          'shellTextShippedPresets' => 'Shipped presets',
          'shellTextNoShippedTemplatesMatchSearch' =>
            'No shipped templates match the current search.',
          'shellTextStartingPointForNewProviders' =>
            'Starting point for new providers',
          'shellTextReadOnlyShippedTemplate' => 'Read-only shipped template',
          'shellTextActivityPageSubtitle' =>
            'Inspect provider resolutions and session state without crowding the main workflow.',
          'shellTextResolutionsCount' =>
            ({required Object count}) => 'Resolutions (${count})',
          'shellTextSessionsCount' =>
            ({required Object count}) => 'Sessions (${count})',
          'shellTextDiagnosticsPageSubtitle' =>
            'Detailed host readiness, platform tunnel detail, and recent typed events.',
          'shellTextEventsCount' =>
            ({required Object count}) => 'Events (${count})',
          'shellTextWaitingForMobileHostBridge' =>
            'Waiting for mobile host bridge negotiation.',
          'shellTextGuiBuildTag' => ({required Object label}) => 'GUI ${label}',
          'shellTextHostBuildTag' =>
            ({required Object label}) => 'Host ${label}',
          'shellTextContractTag' =>
            ({required Object version}) => 'Contract ${version}',
          'shellTextReconnect' => 'Reconnect',
          'shellTextRefresh' => 'Refresh',
          'shellTextResolutionsTitle' => 'Resolutions',
          'shellTextResolutionsSubtitle' =>
            'Resolve the invite first, then use the capability-gated action set to start on this device, export a handoff, or open provider-native targets.',
          'shellTextNoProviderResolutionsYet' => 'No provider resolutions yet.',
          'shellTextSystemTunnelBannerText' =>
            'This mobile slice renders typed host capability and startup-stage results for the reported platform modes. Use the controls below to start or disconnect supported system-tunnel paths.',
          'shellTextNoPlatformTunnelModesReported' =>
            'The connected mobile host did not report any platform tunnel modes.',
          'shellTextAvailableLowercase' => 'available',
          'shellTextUnavailableLowercase' => 'unavailable',
          'shellTextDisconnectVpn' => 'Disconnect VPN',
          'shellTextRequestStartup' => 'Request startup',
          'shellTextNoStartupRequestYet' =>
            'No startup request yet. Use the typed mobile host contract to verify the fail-closed path.',
          'shellTextTurnCredentialsSummary' =>
            ({required Object address, required Object username}) =>
                'TURN ${address} | ${username}',
          'shellTextFailureSummary' =>
            ({required Object stage, required Object message}) =>
                '${stage}: ${message}',
          'shellTextMoreChallengeActions' => 'More challenge actions',
          'shellTextMoreResolutionActions' => 'More resolution actions',
          'shellTextStartOnThisDevice' => 'Start on this device',
          'shellTextShareHandoff' => 'Share handoff',
          'shellTextOpenRoom' => 'Open room',
          'shellTextOpenCamera' => 'Open camera',
          'shellTextOpenArchive' => 'Open archive',
          'shellTextCopyHandoff' => 'Copy handoff',
          'shellTextCancelResolution' => 'Cancel resolution',
          'shellTextSessionsTitle' => 'Sessions',
          'shellTextNoMobileSessionsYet' =>
            'No active or recent mobile sessions yet.',
          'shellTextSessionListenConnections' =>
            ({required Object listen, required Object connections}) =>
                'listen ${listen} | connections ${connections}',
          'shellTextSessionUpdated' =>
            ({required Object timestamp, required Object sessionId}) =>
                'Updated ${timestamp} | session ${sessionId}',
          'shellTextMoreSessionActions' => 'More session actions',
          'shellTextStopSession' => 'Stop session',
          'shellTextExportDiagnostics' => 'Export diagnostics',
          'shellTextEventStream' => 'Event stream',
          'shellTextEventStreamSubtitle' =>
            'Typed state transitions and challenge updates from the mobile host bridge.',
          'shellTextNoEventsYet' => 'No events yet.',
          'shellTextResetNeeded' => 'Reset needed',
          'shellTextHostReady' => 'Host ready',
          'shellTextHostIncompatible' => 'Host incompatible',
          'shellTextHostBlocked' => 'Host blocked',
          'shellTextConnecting' => 'Connecting',
          'shellTextMobileHostReady' => 'Mobile host ready',
          'shellTextMobileHostIncompatible' => 'Mobile host incompatible',
          'shellTextMobileHostBlocked' => 'Mobile host blocked',
          'shellTextConnectingToMobileHost' => 'Connecting to mobile host',
          'shellTextSatisfiedPrerequisites' =>
            ({required Object prerequisites}) =>
                'Satisfied prerequisites: ${prerequisites}',
          'shellTextMissingPrerequisite' =>
            ({required Object prerequisite}) =>
                'Missing prerequisite: ${prerequisite}',
          'shellTextMobileHostModeAvailable' =>
            'The mobile host reports that this mode is available.',
          'shellTextMobileHostModeUnavailable' =>
            'The mobile host reports that this mode is unavailable.',
          'shellTextPlatformTunnelReady' =>
            ({required Object modeLabel}) =>
                '${modeLabel} reached ready state for the mobile host tunnel path.',
          'shellTextPlatformTunnelReadyWithRoutingProfile' =>
            ({required Object modeLabel, required Object profileLabel}) =>
                '${modeLabel} is ready with the ${profileLabel} routing profile.',
          'shellTextStartupBlockedAt' =>
            ({required Object stageLabel}) =>
                'Startup blocked at ${stageLabel}.',
          'shellTextUnknownStage' => 'Unknown stage',
          'shellTextNoMobileTunnelModeSelected' =>
            'No mobile tunnel mode is currently selected.',
          'shellTextAndroidSystemVpnMode' => 'Android system VPN mode',
          'shellTextAppleNetworkExtensionMode' =>
            'Apple network extension mode',
          'shellTextWindowsWintunMode' => 'Windows Wintun mode',
          'shellTextLinuxTunMode' => 'Linux TUN mode',
          'shellTextPerAppRoutingUnavailable' =>
            'Per-app routing is unavailable for this mobile mode.',
          'shellTextRestartVpnToApplyRoutingProfile' =>
            ({required Object modeLabel}) =>
                'Restart ${modeLabel} to apply the selected routing profile.',
          'shellTextDevelopmentWifiRoutingUnavailableForHost' =>
            ({required Object modeLabel}) =>
                '${modeLabel} does not advertise the Development Wi-Fi routing profile on this host.',
          'shellTextDevelopmentWifiRoutingSavedButUnsupported' =>
            'The saved Development Wi-Fi preference is unsupported by the connected host. Switch back to Standard or reconnect to a compatible host.',
          'shellTextRoutingSummaryWithProfile' =>
            ({required Object profileLabel, required Object scopeSummary}) =>
                '${profileLabel}. ${scopeSummary}',
          'shellTextScopeAllInstalledApps' => 'Scope: all installed apps.',
          'shellTextScopeIncludedAppsEmpty' =>
            'Scope: included apps, but no apps are selected yet.',
          'shellTextScopeOnlySelectedApps' =>
            ({required Object count}) => 'Scope: only ${count} selected apps.',
          'shellTextScopeExcludedAppsEmpty' =>
            'Scope: excluded apps, but no apps are selected yet.',
          'shellTextScopeAllExceptSelectedApps' =>
            ({required Object count}) =>
                'Scope: all apps except ${count} selected apps.',
          'shellTextWireGuardNativeOverTurnDatagram' =>
            'WireGuard native over TURN datagram',
          'shellTextWireGuardNativeOverTurnDtls' =>
            'WireGuard native over TURN DTLS overlay',
          'shellTextWireGuardNativeOverWebRtc' =>
            'WireGuard native over WebRTC data channel',
          'shellTextCustomOverlayOverTurnDatagram' =>
            'Custom packet overlay over TURN datagram',
          'shellTextCustomOverlayOverTurnDtls' =>
            'Custom packet overlay over TURN DTLS overlay',
          'shellTextCustomOverlayOverWebRtc' =>
            'Custom packet overlay over WebRTC data channel',
          'shellTextProxyCoreOverTurnDatagram' =>
            'Proxy core adapter over TURN datagram',
          'shellTextProxyCoreOverTurnDtls' =>
            'Proxy core adapter over TURN DTLS overlay',
          'shellTextProxyCoreOverWebRtc' =>
            'Proxy core adapter over WebRTC data channel',
          'shellTextTrustTunnelOverTurnDatagram' =>
            'TrustTunnel native over TURN datagram',
          'shellTextTrustTunnelOverTurnDtls' =>
            'TrustTunnel native over TURN DTLS overlay',
          'shellTextTrustTunnelOverWebRtc' =>
            'TrustTunnel native over WebRTC data channel',
          'shellTextOwnedBrowserMissingMetadata' =>
            'This challenge does not advertise the app-owned browser metadata required for in-app continuation.',
          'shellTextOwnedBrowserMissingUrl' =>
            'This challenge does not expose an in-app browser URL.',
          'shellTextOwnedBrowserNoEvidence' =>
            'The embedded browser session did not expose any usable continuation evidence.',
          'shellTextOwnedBrowserDesktopFingerprintUnavailable' =>
            'This device cannot expose the desktop browser metadata required for the in-app VK flow. Update Android System WebView or Chrome and try again.',
          'shellTextOwnedBrowserTitle' =>
            ({required Object provider}) => '${provider} challenge',
          'shellTextOwnedBrowserOpenInvite' => 'Open invite',
          'shellTextOwnedBrowserCollecting' => 'Collecting...',
          'shellTextOwnedBrowserContinue' => 'Continue',
          'shellTextOwnedBrowserFallbackPrompt' =>
            'Complete the browser step in this in-app session, then continue.',
          'shellTextOwnedBrowserHideKeyboard' => 'Hide keyboard',
          'shellTextPlatformTunnelBlockedBase' =>
            ({required Object modeLabel, required Object stageLabel}) =>
                '${modeLabel} blocked at ${stageLabel}.',
          'shellTextPlatformTunnelBlockedMissingPrerequisite' =>
            ({required Object prerequisiteLabel}) =>
                ' Missing prerequisite: ${prerequisiteLabel}.',
          'shellTextMobileNoReusableSettingsYetNamedProviderUnnamed' =>
            'No reusable settings yet. Save this as a named provider for Profiles.',
          'shellTextMobileNoReusableSettingsYetNamedProviderNamed' =>
            ({required Object providerTitle}) =>
                'No reusable settings yet. Save ${providerTitle} as a named provider for Profiles.',
          'shellTextMobileNoReusableSettingsYetTemplateUnnamed' =>
            'No reusable settings yet. Save this template as a named starting point.',
          'shellTextMobileNoReusableSettingsYetTemplateNamed' =>
            ({required Object providerTitle}) =>
                'No reusable settings yet. Save ${providerTitle} as a named starting point.',
          'shellTextDesktopCompactPlatformTunnelCapabilitySummaryAvailable' =>
            ({required Object modeLabel}) =>
                '${modeLabel} is available for the connected host.',
          'shellTextDesktopCompactPlatformTunnelCapabilitySummaryUnavailable' =>
            ({required Object modeLabel}) => '${modeLabel} is unavailable',
          'shellTextDesktopCompactPlatformTunnelCapabilitySummaryMissingPrerequisite' =>
            ({required Object missingPrerequisite}) =>
                ' because ${missingPrerequisite} is still missing.',
          'shellTextDesktopCompactPlatformTunnelCapabilitySummaryUnavailableSuffix' =>
            ' for the connected host.',
          'shellTextDesktopCompactPlatformTunnelStatusLabelUnavailable' =>
            ({required Object modeLabel}) => '${modeLabel} unavailable',
          'shellTextDesktopCompactPlatformTunnelStatusLabelMissing' =>
            ({required Object modeLabel, required Object missing}) =>
                '${modeLabel}: ${missing} missing',
          'shellTextDesktopPlatformTunnelResultSummaryReady' =>
            ({required Object modeLabel}) =>
                '${modeLabel} reached ready state for the desktop host tunnel path.',
          'shellTextDesktopPlatformTunnelResultSummaryBlocked' =>
            ({required Object stageLabel}) =>
                'Startup blocked at ${stageLabel}.',
          'shellTextStateStarting' => 'starting',
          'shellTextStateChallengeRequired' => 'challenge required',
          'shellTextStateReady' => 'ready',
          'shellTextStateRetrying' => 'retrying',
          'shellTextStateStopping' => 'stopping',
          'shellTextStateStopped' => 'stopped',
          'shellTextStateFailed' => 'failed',
          'shellTextStateResolved' => 'resolved',
          'shellTextStateCancelled' => 'cancelled',
          'shellTextStateExpired' => 'expired',
          'shellTextExecutionOwnerHost' => 'host',
          'shellTextExecutionOwnerShellLocal' => 'shell local',
          'shellTextExecutionOwnerShellExternal' => 'shell external',
          'shellTextModeSummaryWithoutExecutionPath' =>
            ({required Object modeLabel, required Object routingSummary}) =>
                '${modeLabel}. ${routingSummary}',
          'shellTextModeSummaryWithExecutionPath' =>
            ({
              required Object modeLabel,
              required Object routingSummary,
              required Object executionPath,
            }) =>
                '${modeLabel}. ${routingSummary} Execution path: ${executionPath}.',
          'shellTextExportExpiry' =>
            ({required Object timestamp}) => 'Export expiry ${timestamp}',
          'shellTextExportExpiryWithSource' =>
            ({required Object timestamp, required Object source}) =>
                'Export expiry ${timestamp} via ${source}',
          _ => null,
        };
  }
}
