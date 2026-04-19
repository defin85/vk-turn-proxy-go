import 'package:flutter/material.dart';

import 'i18n/strings.g.dart';

class ShellText {
  const ShellText();

  String get close => t.shellTextClose;
  String get cancel => t.shellTextCancel;
  String get back => t.shellTextBack;
  String get save => t.shellTextSave;
  String get delete => t.shellTextDelete;
  String get newItem => t.shellTextNewItem;
  String get missing => t.shellTextMissing;
  String get unknownValue => t.shellTextUnknownValue;
  String get failureFallback => t.shellTextFailureFallback;
  String get retry => t.shellTextRetry;
  String get activity => t.shellTextActivity;
  String get diagnostics => t.shellTextDiagnostics;
  String get overview => t.shellTextOverview;
  String get events => t.shellTextEvents;
  String get templates => t.shellTextTemplates;
  String get available => t.shellTextAvailable;
  String get unavailable => t.shellTextUnavailable;
  String get openActivity => t.shellTextOpenActivity;
  String get openDiagnostics => t.shellTextOpenDiagnostics;
  String get openProfiles => t.shellTextOpenProfiles;
  String get resetLocalState => t.shellTextResetLocalState;
  String get forgetEmbeddedSignIn => t.shellTextForgetEmbeddedSignIn;
  String get embeddedBrowserStateTitle => t.shellTextEmbeddedBrowserStateTitle;
  String get embeddedBrowserStateBody => t.shellTextEmbeddedBrowserStateBody;
  String get embeddedBrowserStateHint => t.shellTextEmbeddedBrowserStateHint;
  String get importFromFile => t.shellTextImportFromFile;
  String get exportSavedProfile => t.shellTextExportSavedProfile;
  String get pasteEnvelope => t.shellTextPasteEnvelope;
  String get copyText => t.shellTextCopyText;
  String get saveFile => t.shellTextSaveFile;
  String get shareText => t.shellTextShareText;
  String get shareFile => t.shellTextShareFile;
  String get previewImport => t.shellTextPreviewImport;
  String get importProfile => t.shellTextImportProfile;
  String get portableProfileJson => t.shellTextPortableProfileJson;
  String get portableProfileEnvelope => t.shellTextPortableProfileEnvelope;
  String get noManagedProvidersAvailableYet =>
      t.shellTextNoManagedProvidersAvailableYet;
  String get selectedProviderNotAdvertisedByConnectedHost =>
      t.shellTextSelectedProviderNotAdvertisedByConnectedHost;
  String get selectedProviderNotAdvertisedByConnectedMobileHost =>
      t.shellTextSelectedProviderNotAdvertisedByConnectedMobileHost;
  String savedProfile(String profileLabel) =>
      t.shellTextSavedProfile(profileLabel: profileLabel);
  String savedMobileProfile(String profileLabel) =>
      t.shellTextSavedMobileProfile(profileLabel: profileLabel);
  String deletedProfile(String profileId) =>
      t.shellTextDeletedProfile(profileId: profileId);
  String deletedMobileProfile(String profileId) =>
      t.shellTextDeletedMobileProfile(profileId: profileId);
  String savedManagedProvider(String providerLabel) =>
      t.shellTextSavedManagedProvider(providerLabel: providerLabel);
  String deletedManagedProvider(String providerId) =>
      t.shellTextDeletedManagedProvider(providerId: providerId);
  String get saveOrSelectProfileBeforeExport =>
      t.shellTextSaveOrSelectProfileBeforeExport;
  String get selectedProfileDependsOnMissingManagedProviderSnapshot =>
      t.shellTextSelectedProfileDependsOnMissingManagedProviderSnapshot;
  String copiedPortableProfile(String profileLabel) =>
      t.shellTextCopiedPortableProfile(profileLabel: profileLabel);
  String copiedSecretBearingPortableProfile(String profileLabel) =>
      t.shellTextCopiedSecretBearingPortableProfile(profileLabel: profileLabel);
  String savedPortableProfile(String profileLabel, String path) =>
      t.shellTextSavedPortableProfile(profileLabel: profileLabel, path: path);
  String savedSecretBearingPortableProfile(String profileLabel, String path) =>
      t.shellTextSavedSecretBearingPortableProfile(
        profileLabel: profileLabel,
        path: path,
      );
  String sharedPortableProfileAsText(String profileLabel) =>
      t.shellTextSharedPortableProfileAsText(profileLabel: profileLabel);
  String sharedSecretBearingPortableProfileAsText(String profileLabel) =>
      t.shellTextSharedSecretBearingPortableProfileAsText(
        profileLabel: profileLabel,
      );
  String sharedPortableProfileAsFile(String profileLabel) =>
      t.shellTextSharedPortableProfileAsFile(profileLabel: profileLabel);
  String sharedSecretBearingPortableProfileAsFile(String profileLabel) =>
      t.shellTextSharedSecretBearingPortableProfileAsFile(
        profileLabel: profileLabel,
      );
  String importedProfile(String profileLabel) =>
      t.shellTextImportedProfile(profileLabel: profileLabel);
  String importedSecretBearingProfile(String profileLabel) =>
      t.shellTextImportedSecretBearingProfile(profileLabel: profileLabel);
  String startedSession(String sessionId) =>
      t.shellTextStartedSession(sessionId: sessionId);
  String startedMobileSession(String sessionId) =>
      t.shellTextStartedMobileSession(sessionId: sessionId);
  String stoppedSession(String sessionId) =>
      t.shellTextStoppedSession(sessionId: sessionId);
  String managedProviderNoLongerAvailable(String providerId) =>
      t.shellTextManagedProviderNoLongerAvailable(providerId: providerId);
  String appliedManagedProviderToActiveProfileDraft(String providerLabel) =>
      t.shellTextAppliedManagedProviderToActiveProfileDraft(
        providerLabel: providerLabel,
      );
  String appliedManagedProviderToActiveMobileProfileDraft(
    String providerLabel,
  ) => t.shellTextAppliedManagedProviderToActiveMobileProfileDraft(
    providerLabel: providerLabel,
  );
  String duplicatedItemLabel(String sourceLabel) =>
      t.shellTextDuplicatedItemLabel(sourceLabel: sourceLabel);
  String get duplicatedItemFallbackLabel =>
      t.shellTextDuplicatedItemFallbackLabel;
  String seededProfileCopyDraft(String profileLabel) =>
      t.shellTextSeededProfileCopyDraft(profileLabel: profileLabel);
  String seededManagedProviderDraftFromPreset(String presetTitle) =>
      t.shellTextSeededManagedProviderDraftFromPreset(presetTitle: presetTitle);
  String seededManagedProviderCopyDraft(String providerLabel) =>
      t.shellTextSeededManagedProviderCopyDraft(providerLabel: providerLabel);
  String cancelledResolution(String resolutionId) =>
      t.shellTextCancelledResolution(resolutionId: resolutionId);
  String cancelledMobileResolution(String resolutionId) =>
      t.shellTextCancelledMobileResolution(resolutionId: resolutionId);
  String startedSessionFromResolution(String sessionId, String resolutionId) =>
      t.shellTextStartedSessionFromResolution(
        sessionId: sessionId,
        resolutionId: resolutionId,
      );
  String startedMobileSessionFromResolution(
    String sessionId,
    String resolutionId,
  ) => t.shellTextStartedMobileSessionFromResolution(
    sessionId: sessionId,
    resolutionId: resolutionId,
  );
  String copiedHandoffLink(String resolutionId, String expiresAt) =>
      t.shellTextCopiedHandoffLink(
        resolutionId: resolutionId,
        expiresAt: expiresAt,
      );
  String sharedHandoffLink(String resolutionId, String expiresAt) =>
      t.shellTextSharedHandoffLink(
        resolutionId: resolutionId,
        expiresAt: expiresAt,
      );
  String resolutionNoLongerAvailable(String resolutionId) =>
      t.shellTextResolutionNoLongerAvailable(resolutionId: resolutionId);
  String resolutionDoesNotAdvertiseAction(
    String resolutionId,
    String actionLabel,
  ) => t.shellTextResolutionDoesNotAdvertiseAction(
    resolutionId: resolutionId,
    actionLabel: actionLabel,
  );
  String resolutionHasNoBrowserTarget(
    String resolutionId,
    String actionLabel,
  ) => t.shellTextResolutionHasNoBrowserTarget(
    resolutionId: resolutionId,
    actionLabel: actionLabel,
  );
  String openedResolutionAction(String resolutionId, String actionLabel) =>
      t.shellTextOpenedResolutionAction(
        actionLabel: actionLabel,
        resolutionId: resolutionId,
      );
  String failedToOpenResolutionAction(
    String resolutionId,
    String actionLabel,
  ) => t.shellTextFailedToOpenResolutionAction(
    actionLabel: actionLabel,
    resolutionId: resolutionId,
  );
  String cancelledChallenge(String challengeId) =>
      t.shellTextCancelledChallenge(challengeId: challengeId);
  String exportedDiagnostics(String path) =>
      t.shellTextExportedDiagnostics(path: path);
  String get eventStreamClosed => t.shellTextEventStreamClosed;
  String get localHostNotReady => t.shellTextLocalHostNotReady;
  String failedToRestoreDesktopShellState(Object error) =>
      t.shellTextFailedToRestoreDesktopShellState(error: error);
  String failedToPersistDesktopShellState(Object error) =>
      t.shellTextFailedToPersistDesktopShellState(error: error);
  String failedToPersistMobileShellState(Object error) =>
      t.shellTextFailedToPersistMobileShellState(error: error);
  String get clearedRememberedEmbeddedSignIn =>
      t.shellTextClearedRememberedEmbeddedSignIn;
  String failedToClearRememberedEmbeddedSignIn(Object error) =>
      t.shellTextFailedToClearRememberedEmbeddedSignIn(error: error);
  String platformTunnelReadyForLocalHost(String modeLabel) =>
      t.shellTextPlatformTunnelReadyForLocalHost(modeLabel: modeLabel);
  String platformTunnelBlocked({
    required String modeLabel,
    required String stageLabel,
    String? prerequisiteLabel,
    String? message,
  }) {
    final buffer = StringBuffer(
      t.shellTextPlatformTunnelBlockedBase(
        modeLabel: modeLabel,
        stageLabel: stageLabel,
      ),
    );
    if (prerequisiteLabel != null && prerequisiteLabel.isNotEmpty) {
      buffer.write(
        t.shellTextPlatformTunnelBlockedMissingPrerequisite(
          prerequisiteLabel: prerequisiteLabel,
        ),
      );
    }
    final trimmedMessage = message?.trim() ?? '';
    if (trimmedMessage.isNotEmpty) {
      buffer.write(' $trimmedMessage');
    }
    return buffer.toString();
  }

  String startedResolutionForProvider(
    String resolutionId,
    String providerName,
  ) => t.shellTextStartedResolutionForProvider(
    resolutionId: resolutionId,
    providerName: providerName,
  );
  String startedResolutionForProviderWithExternalBrowser(
    String resolutionId,
    String providerName,
  ) => t.shellTextStartedResolutionForProviderWithExternalBrowser(
    resolutionId: resolutionId,
    providerName: providerName,
  );
  String startedResolutionForProviderWithBrowserContinuation(
    String resolutionId,
    String providerName,
  ) => t.shellTextStartedResolutionForProviderWithBrowserContinuation(
    resolutionId: resolutionId,
    providerName: providerName,
  );
  String continuedChallenge(String challengeId) =>
      t.shellTextContinuedChallenge(challengeId: challengeId);
  String continuedChallengeWithExternalBrowser(
    String challengeId,
    String providerName,
  ) => t.shellTextContinuedChallengeWithExternalBrowser(
    challengeId: challengeId,
    providerName: providerName,
  );
  String continuedChallengeForResolution(
    String challengeId,
    String providerName,
  ) => t.shellTextContinuedChallengeForResolution(
    challengeId: challengeId,
    providerName: providerName,
  );
  String continuedChallengeForSession(
    String challengeId,
    String providerName,
  ) => t.shellTextContinuedChallengeForSession(
    challengeId: challengeId,
    providerName: providerName,
  );
  String desktopProviderSettingsRuntimeUnsupported({
    required String providerName,
    required String error,
  }) => t.shellTextDesktopProviderSettingsRuntimeUnsupported(
    providerName: providerName,
    error: error,
  );
  String mobileProviderSettingsRuntimeUnsupported({
    required String providerName,
    required String error,
  }) => t.shellTextMobileProviderSettingsRuntimeUnsupported(
    providerName: providerName,
    error: error,
  );
  String get selectedManagedProviderFamilyNotInSupportedCatalog =>
      t.shellTextSelectedManagedProviderFamilyNotInSupportedCatalog;
  String get selectedManagedProviderNotInSupportedCatalog =>
      t.shellTextSelectedManagedProviderNotInSupportedCatalog;
  String get managedProviderNotInSupportedCatalog =>
      t.shellTextManagedProviderNotInSupportedCatalog;
  String desktopReusableSettingsRuntimeUnsupported({
    required String providerName,
    required String error,
  }) => t.shellTextDesktopReusableSettingsRuntimeUnsupported(
    providerName: providerName,
    error: error,
  );
  String mobileReusableSettingsRuntimeUnsupported({
    required String providerName,
    required String error,
  }) => t.shellTextMobileReusableSettingsRuntimeUnsupported(
    providerName: providerName,
    error: error,
  );
  String connectedHostDoesNotAdvertiseProviderFamilyYet(String providerTitle) =>
      t.shellTextConnectedHostDoesNotAdvertiseProviderFamilyYet(
        providerTitle: providerTitle,
      );
  String get selectedTemplateFamilyNotInSupportedCatalog =>
      t.shellTextSelectedTemplateFamilyNotInSupportedCatalog;
  String get templateNotInSupportedCatalog =>
      t.shellTextTemplateNotInSupportedCatalog;
  String mobileTemplateRuntimeUnsupported({
    required String providerName,
    required String error,
  }) => t.shellTextMobileTemplateRuntimeUnsupported(
    providerName: providerName,
    error: error,
  );
  String get localHostShutdownRequested =>
      t.shellTextLocalHostShutdownRequested;
  String get noCompatibleLocalHostFound =>
      t.shellTextNoCompatibleLocalHostFound;
  String get localHostLaunchFailedWithoutReportedError =>
      t.shellTextLocalHostLaunchFailedWithoutReportedError;
  String localHostLaunchFailed(Object error) =>
      t.shellTextLocalHostLaunchFailed(error: error);
  String connectedToLocalHost(String listenAddress) =>
      t.shellTextConnectedToLocalHost(listenAddress: listenAddress);
  String launchedLocalHost(String description, String listenAddress) =>
      t.shellTextLaunchedLocalHost(
        description: description,
        listenAddress: listenAddress,
      );
  String sidecarLaunchCandidateEnvPath() =>
      t.shellTextSidecarLaunchCandidateEnvPath;
  String get sidecarLaunchCandidateNextToAppExecutable =>
      t.shellTextSidecarLaunchCandidateNextToAppExecutable;
  String get sidecarLaunchCandidateBundledFrameworks =>
      t.shellTextSidecarLaunchCandidateBundledFrameworks;
  String get sidecarLaunchCandidateFromPath =>
      t.shellTextSidecarLaunchCandidateFromPath;
  String get sidecarLaunchCandidateRepoLocalGoRun =>
      t.shellTextSidecarLaunchCandidateRepoLocalGoRun;
  String sidecarExitedBeforeReady(String description, int exitCode) =>
      t.shellTextSidecarExitedBeforeReady(
        description: description,
        exitCode: exitCode,
      );
  String providerExpectsLinkEntryOnlyDesktop({
    required String providerName,
    required String inputKind,
  }) => t.shellTextProviderExpectsLinkEntryOnlyDesktop(
    providerName: providerName,
    inputKind: inputKind,
  );
  String savedTemplate(String templateLabel) =>
      t.shellTextSavedTemplate(templateLabel: templateLabel);
  String deletedTemplate(String templateId) =>
      t.shellTextDeletedTemplate(templateId: templateId);
  String templateNoLongerAvailable(String templateId) =>
      t.shellTextTemplateNoLongerAvailable(templateId: templateId);
  String seededManagedProviderDraftFromTemplate(String templateLabel) =>
      t.shellTextSeededManagedProviderDraftFromTemplate(
        templateLabel: templateLabel,
      );
  String seededTemplateCopyDraft(String templateLabel) =>
      t.shellTextSeededTemplateCopyDraft(templateLabel: templateLabel);
  String get clearedLocalMobileShellState =>
      t.shellTextClearedLocalMobileShellState;
  String failedToClearLocalMobileShellState(Object error) =>
      t.shellTextFailedToClearLocalMobileShellState(error: error);
  String providerExpectsLinkEntryOnlyMobile({
    required String providerName,
    required String inputKind,
  }) => t.shellTextProviderExpectsLinkEntryOnlyMobile(
    providerName: providerName,
    inputKind: inputKind,
  );
  String resolutionUnavailableForPlatformTunnel({
    required String modeLabel,
    required String resolutionId,
    required String stage,
    required String message,
  }) => t.shellTextResolutionUnavailableForPlatformTunnel(
    modeLabel: modeLabel,
    resolutionId: resolutionId,
    stage: stage,
    message: message,
  );
  String challengeMustCompleteBeforeStarting(String modeLabel) =>
      t.shellTextChallengeMustCompleteBeforeStarting(modeLabel: modeLabel);
  String waitForProviderResolutionBeforeStarting(String modeLabel) =>
      t.shellTextWaitForProviderResolutionBeforeStarting(modeLabel: modeLabel);
  String startedMobileResolutionForProvider(
    String resolutionId,
    String providerName,
  ) => t.shellTextStartedMobileResolutionForProvider(
    resolutionId: resolutionId,
    providerName: providerName,
  );
  String startedMobileResolutionForProviderWithExternalBrowser(
    String resolutionId,
    String providerName,
  ) => t.shellTextStartedMobileResolutionForProviderWithExternalBrowser(
    resolutionId: resolutionId,
    providerName: providerName,
  );
  String startedMobileResolutionForProviderWithBrowserContinuation(
    String resolutionId,
    String providerName,
  ) => t.shellTextStartedMobileResolutionForProviderWithBrowserContinuation(
    resolutionId: resolutionId,
    providerName: providerName,
  );
  String resolutionStartedThenCompleteChallengeBeforeStarting(
    String startedNotice,
    String modeLabel,
  ) => t.shellTextResolutionStartedThenCompleteChallengeBeforeStarting(
    startedNotice: startedNotice,
    modeLabel: modeLabel,
  );
  String receivedPortableProfileForReview(String profileLabel) =>
      t.shellTextReceivedPortableProfileForReview(profileLabel: profileLabel);
  String receivedSecretBearingPortableProfileForReview(String profileLabel) =>
      t.shellTextReceivedSecretBearingPortableProfileForReview(
        profileLabel: profileLabel,
      );
  String connectedToMobileHostBridge(String baseUri) =>
      t.shellTextConnectedToMobileHostBridge(baseUri: baseUri);
  String get challengeHasNoBrowserHandoffUrl =>
      t.shellTextChallengeHasNoBrowserHandoffUrl;
  String openedMobileBrowserHandoff(String challengeKind) =>
      t.shellTextOpenedMobileBrowserHandoff(challengeKind: challengeKind);
  String get failedToOpenMobileBrowserHandoffUrl =>
      t.shellTextFailedToOpenMobileBrowserHandoffUrl;
  String platformTunnelDisconnected(String modeLabel) =>
      t.shellTextPlatformTunnelDisconnected(modeLabel: modeLabel);
  String selectAtLeastOneIncludedApp(String modeLabel) =>
      t.shellTextSelectAtLeastOneIncludedApp(modeLabel: modeLabel);
  String selectAtLeastOneExcludedApp(String modeLabel) =>
      t.shellTextSelectAtLeastOneExcludedApp(modeLabel: modeLabel);
  String get selectedMobileModeNotAdvertisedByConnectedHost =>
      t.shellTextSelectedMobileModeNotAdvertisedByConnectedHost;
  String modeDoesNotAdvertiseSupportedExecutionPath(String modeLabel) =>
      t.shellTextModeDoesNotAdvertiseSupportedExecutionPath(
        modeLabel: modeLabel,
      );
  String selectExecutionPathBeforeStarting(String modeLabel) =>
      t.shellTextSelectExecutionPathBeforeStarting(modeLabel: modeLabel);
  String get resetLocalMobileShellStateBeforeReconnecting =>
      t.shellTextResetLocalMobileShellStateBeforeReconnecting;
  String detectedBrowserReturnAndContinuedChallenge(
    String signalLabel,
    String challengeId,
  ) => t.shellTextDetectedBrowserReturnAndContinuedChallenge(
    signalLabel: signalLabel,
    challengeId: challengeId,
  );
  String completedInAppBrowserContinuation(String challengeId) =>
      t.shellTextCompletedInAppBrowserContinuation(challengeId: challengeId);
  String get resetLocalMobileShellStateBeforeRuntimeControlContinue =>
      t.shellTextResetLocalMobileShellStateBeforeRuntimeControlContinue;
  String get appLinkBrowserReturn => t.shellTextAppLinkBrowserReturn;
  String get universalLinkBrowserReturn =>
      t.shellTextUniversalLinkBrowserReturn;
  String get browserReturnOnAppResume => t.shellTextBrowserReturnOnAppResume;
  String get browserReturn => t.shellTextBrowserReturn;
  String get mobileHostBridgeNotReady => t.shellTextMobileHostBridgeNotReady;
  String get nativeMobileHostBridgeDidNotReturnHostConfiguration =>
      t.shellTextNativeMobileHostBridgeDidNotReturnHostConfiguration;
  String get nativeMobileHostBridgeReturnedEmptyHostUrl =>
      t.shellTextNativeMobileHostBridgeReturnedEmptyHostUrl;
  String nativeMobileHostBridgeReturnedInvalidHostUrl(String baseUrl) =>
      t.shellTextNativeMobileHostBridgeReturnedInvalidHostUrl(baseUrl: baseUrl);
  String get nativeMobileHostBridgePluginUnavailable =>
      t.shellTextNativeMobileHostBridgePluginUnavailable;
  String failedToResolveMobileHostBridgeFromNativePlatform(Object details) =>
      t.shellTextFailedToResolveMobileHostBridgeFromNativePlatform(
        details: details,
      );
  String get nativeMobileHostBridgePluginUnavailableForPermissionRequests =>
      t.shellTextNativeMobileHostBridgePluginUnavailableForPermissionRequests;
  String failedToRequestNativePlatformTunnelPermission(Object details) => t
      .shellTextFailedToRequestNativePlatformTunnelPermission(details: details);
  String get nativeMobileHostBridgeReturnedNoWebViewSnapshot =>
      t.shellTextNativeMobileHostBridgeReturnedNoWebViewSnapshot;
  String failedToInspectNativeWebView(Object details) =>
      t.shellTextFailedToInspectNativeWebView(details: details);
  String get vktpMobileHostUrlInvalid => t.shellTextVktpMobileHostUrlInvalid;
  String get nativeMobileHostBridgeDidNotProvideControlPlaneEndpoint =>
      t.shellTextNativeMobileHostBridgeDidNotProvideControlPlaneEndpoint;
  String get mobileHostBridgeNotConfigured =>
      t.shellTextMobileHostBridgeNotConfigured;
  String
  get nativeMobileHostBridgePluginUnavailableForInstalledAppInventory => t
      .shellTextNativeMobileHostBridgePluginUnavailableForInstalledAppInventory;
  String failedToListInstalledAppsFromNativePlatform(Object details) =>
      t.shellTextFailedToListInstalledAppsFromNativePlatform(details: details);
  String failedToRestoreMobileShellState(Object error) =>
      t.shellTextFailedToRestoreMobileShellState(error: error);
  String get providerDidNotReturnStartableArtifact =>
      t.shellTextProviderDidNotReturnStartableArtifact;
  String loopbackPeerBlockReason(String modeLabel, String peerAddress) =>
      t.shellTextLoopbackPeerBlockReason(
        modeLabel: modeLabel,
        peerAddress: peerAddress,
      );
  String get secureProfileSecretsUnavailable =>
      t.shellTextSecureProfileSecretsUnavailable;
  String secureProfileSecretsMissing(String profileId) =>
      t.shellTextSecureProfileSecretsMissing(profileId: profileId);
  String get secureDraftSecretsUnavailable =>
      t.shellTextSecureDraftSecretsUnavailable;
  String resolutionStartedThenWaitForFinishBeforeStarting(
    String startedNotice,
    String modeLabel,
  ) => t.shellTextResolutionStartedThenWaitForFinishBeforeStarting(
    startedNotice: startedNotice,
    modeLabel: modeLabel,
  );
  String get noReusableFieldsYet => t.shellTextNoReusableFieldsYet;
  String get schemaBlockedInShell => t.shellTextSchemaBlockedInShell;
  String get reusableFieldsReady => t.shellTextReusableFieldsReady;
  String get providerInput => t.shellTextProviderInput;
  String get providerLink => t.shellTextProviderLink;
  String get providerFamily => t.shellTextProviderFamily;
  String get providerType => t.shellTextProviderType;
  String get profileName => t.shellTextProfileName;
  String get localUdpListen => t.shellTextLocalUdpListen;
  String get peerAddress => t.shellTextPeerAddress;
  String get connections => t.shellTextConnections;
  String get turnMode => t.shellTextTurnMode;
  String get turnOverride => t.shellTextTurnOverride;
  String get turnPort => t.shellTextTurnPort;
  String get bindInterface => t.shellTextBindInterface;
  String get logLevel => t.shellTextLogLevel;
  String get dtlsEnabled => t.shellTextDtlsEnabled;
  String get resolveInvite => t.shellTextResolveInvite;
  String get resolveProfile => t.shellTextResolveProfile;
  String get notSet => t.shellTextNotSet;
  String get startSession => t.shellTextStartSession;
  String get saveProfile => t.shellTextSaveProfile;
  String get deleteProfile => t.shellTextDeleteProfile;
  String get freshDraft => t.shellTextFreshDraft;
  String get startSavedProfile => t.shellTextStartSavedProfile;
  String get exportPortableProfile => t.shellTextExportPortableProfile;
  String get importPortableProfile => t.shellTextImportPortableProfile;
  String get pastePortableProfileEnvelope =>
      t.shellTextPastePortableProfileEnvelope;
  String get previewOpensBeforeRecordsCreated =>
      t.shellTextPreviewOpensBeforeRecordsCreated;
  String get payloadInvalidOrUnsupported =>
      t.shellTextPayloadInvalidOrUnsupported;
  String providerAndSource({
    required String provider,
    required String source,
  }) => t.shellTextProviderAndSource(provider: provider, source: source);
  String providerLabel(String provider) =>
      t.shellTextProviderLabel(provider: provider);
  String sourceModeLabel(String mode) => t.shellTextSourceModeLabel(mode: mode);
  String managedProviderSnapshot(String name) =>
      t.shellTextManagedProviderSnapshot(name: name);
  String get portableExportSecretWarningDesktop =>
      t.shellTextPortableExportSecretWarningDesktop;
  String get portableExportSecretWarningMobile =>
      t.shellTextPortableExportSecretWarningMobile;
  String get portableExportSeparateFromRuntimeDesktop =>
      t.shellTextPortableExportSeparateFromRuntimeDesktop;
  String get portableExportSeparateFromRuntimeMobile =>
      t.shellTextPortableExportSeparateFromRuntimeMobile;
  String get portableQrCompactJson => t.shellTextPortableQrCompactJson;
  String portableQrUnavailableDesktop(int bytes) =>
      t.shellTextPortableQrUnavailableDesktop(bytes: bytes);
  String portableQrUnavailableMobile(int bytes) =>
      t.shellTextPortableQrUnavailableMobile(bytes: bytes);
  String get portableImportSecretWarning =>
      t.shellTextPortableImportSecretWarning;
  String get portableImportCreatesFreshIdsMobile =>
      t.shellTextPortableImportCreatesFreshIdsMobile;
  String get portableImportCreatesFreshIdsDesktop =>
      t.shellTextPortableImportCreatesFreshIdsDesktop;
  String get scanPortableProfileQr => t.shellTextScanPortableProfileQr;
  String get pointCameraAtPortableProfileQr =>
      t.shellTextPointCameraAtPortableProfileQr;
  String tagInput(String value) => t.shellTextTagInput(value: value);
  String tagAuth(String value) => t.shellTextTagAuth(value: value);
  String tagBrowser(String value) => t.shellTextTagBrowser(value: value);
  String tagFamily(String value) => t.shellTextTagFamily(value: value);
  String get browserNeedsExternal => t.shellTextBrowserNeedsExternal;
  String get browserAllowsEmbedded => t.shellTextBrowserAllowsEmbedded;
  String get browserNotRequired => t.shellTextBrowserNotRequired;
  String get browserContinuationMayAppear =>
      t.shellTextBrowserContinuationMayAppear;
  String get browserContinuationNotAdvertised =>
      t.shellTextBrowserContinuationNotAdvertised;

  String get desktopProfileWorkspaceTitle =>
      t.shellTextDesktopProfileWorkspaceTitle;
  String get desktopUnsavedDraft => t.shellTextDesktopUnsavedDraft;
  String get desktopSavedProfileWorkspace =>
      t.shellTextDesktopSavedProfileWorkspace;
  String get desktopSaveProfileFirst => t.shellTextDesktopSaveProfileFirst;
  String get desktopStartSessionFromSavedProfile =>
      t.shellTextDesktopStartSessionFromSavedProfile;
  String get desktopProfileSettings => t.shellTextDesktopProfileSettings;
  String get desktopChangeSource => t.shellTextDesktopChangeSource;
  String get desktopChangeSourceSubtitle =>
      t.shellTextDesktopChangeSourceSubtitle;
  String get desktopRuntimeDefaults => t.shellTextDesktopRuntimeDefaults;
  String get desktopRuntimeDefaultsSubtitle =>
      t.shellTextDesktopRuntimeDefaultsSubtitle;
  String get desktopProfileMaintenance => t.shellTextDesktopProfileMaintenance;
  String get desktopProfileMaintenanceSubtitle =>
      t.shellTextDesktopProfileMaintenanceSubtitle;
  String get desktopShowMaintenanceActions =>
      t.shellTextDesktopShowMaintenanceActions;
  String get desktopDeleteSavedProfileHint =>
      t.shellTextDesktopDeleteSavedProfileHint;
  String get desktopPortableTransferSubtitle =>
      t.shellTextDesktopPortableTransferSubtitle;
  String get desktopBrowserHandling => t.shellTextDesktopBrowserHandling;
  String get desktopBrowserHandlingSubtitle =>
      t.shellTextDesktopBrowserHandlingSubtitle;
  String get desktopProfileProviderSettings =>
      t.shellTextDesktopProfileProviderSettings;
  String desktopProviderSettingsSupportError({
    required String providerName,
    required String error,
  }) => t.shellTextDesktopProviderSettingsSupportError(
    providerName: providerName,
    error: error,
  );
  String get desktopProfileProviderSettingsHelp =>
      t.shellTextDesktopProfileProviderSettingsHelp;
  String get desktopNoSavedProviderRecords =>
      t.shellTextDesktopNoSavedProviderRecords;
  String get directInput => t.shellTextDirectInput;
  String get savedRecord => t.shellTextSavedRecord;
  String get desktopSavedRecordAttached =>
      t.shellTextDesktopSavedRecordAttached;
  String get desktopDraftOwnsProviderInput =>
      t.shellTextDesktopDraftOwnsProviderInput;

  String get mobileProfilesTitleBar => t.shellTextMobileProfilesTitleBar;
  String get selectedProfileActions => t.shellTextSelectedProfileActions;
  String get makeCurrent => t.shellTextMakeCurrent;
  String get copyProfile => t.shellTextCopyProfile;
  String get mobileProviderDetails => t.shellTextMobileProviderDetails;
  String get mobileProviderDetailsSubtitle =>
      t.shellTextMobileProviderDetailsSubtitle;
  String get mobileProviderSettingsSection =>
      t.shellTextMobileProviderSettingsSection;
  String get mobilePortableTransfer => t.shellTextMobilePortableTransfer;
  String get mobileProviderSettingsUnsupportedSubtitle =>
      t.shellTextMobileProviderSettingsUnsupportedSubtitle;
  String get mobileProviderSettingsRetainedSubtitle =>
      t.shellTextMobileProviderSettingsRetainedSubtitle;
  String get mobileAdvancedRuntimeControls =>
      t.shellTextMobileAdvancedRuntimeControls;
  String get mobileAdvancedRuntimeControlsSubtitle =>
      t.shellTextMobileAdvancedRuntimeControlsSubtitle;
  String get mobilePortableTransferSubtitle =>
      t.shellTextMobilePortableTransferSubtitle;
  String mobileProviderSettingsSupportError({
    required String providerName,
    required String error,
  }) => t.shellTextMobileProviderSettingsSupportError(
    providerName: providerName,
    error: error,
  );
  String get mobileProviderSettingsRetainedHelp =>
      t.shellTextMobileProviderSettingsRetainedHelp;
  String get mobileNoSavedProfilesYetBuildDraft =>
      t.shellTextMobileNoSavedProfilesYetBuildDraft;
  String get mobileSavedProfiles => t.shellTextMobileSavedProfiles;
  String get mobileProviderMode => t.shellTextMobileProviderMode;
  String get mobileProviderModeNoManagedProviders =>
      t.shellTextMobileProviderModeNoManagedProviders;
  String get customProvider => t.shellTextCustomProvider;
  String get managedProvider => t.shellTextManagedProvider;
  String get mobileManagedModeSummary => t.shellTextMobileManagedModeSummary;
  String get mobileCustomModeSummary => t.shellTextMobileCustomModeSummary;
  String get mobileManagedProviderDropdown =>
      t.shellTextMobileManagedProviderDropdown;

  String get mobileEditProvider => t.shellTextMobileEditProvider;
  String get mobileNewProvider => t.shellTextMobileNewProvider;
  String get mobileEditSavedReusableProvider =>
      t.shellTextMobileEditSavedReusableProvider;
  String get mobileFinishSavedReusableProvider =>
      t.shellTextMobileFinishSavedReusableProvider;
  String get mobileCloseProviderEditor => t.shellTextMobileCloseProviderEditor;
  String get mobileNoShippedProviderFamilies =>
      t.shellTextMobileNoShippedProviderFamilies;
  String get mobileProviderName => t.shellTextMobileProviderName;
  String get mobileProviderShownInProfiles =>
      t.shellTextMobileProviderShownInProfiles;
  String get mobileProviderTypeChosenWhenCreated =>
      t.shellTextMobileProviderTypeChosenWhenCreated;
  String mobileNoReusableSettingsYetNamedProvider(String providerTitle) =>
      providerTitle.isEmpty
      ? t.shellTextMobileNoReusableSettingsYetNamedProviderUnnamed
      : t.shellTextMobileNoReusableSettingsYetNamedProviderNamed(
          providerTitle: providerTitle,
        );

  String mobileProviderConfigSupportError({
    required String providerName,
    required String error,
  }) => t.shellTextMobileProviderConfigSupportError(
    providerName: providerName,
    error: error,
  );
  String get mobileReusableProviderSettings =>
      t.shellTextMobileReusableProviderSettings;
  String get mobileReusableValuesAppliedToProfile =>
      t.shellTextMobileReusableValuesAppliedToProfile;
  String get mobileSaveProvider => t.shellTextMobileSaveProvider;
  String get mobileSaveAsTemplate => t.shellTextMobileSaveAsTemplate;
  String get mobileUseInProfileDraft => t.shellTextMobileUseInProfileDraft;
  String get mobileDeleteProvider => t.shellTextMobileDeleteProvider;
  String get savedProviders => t.shellTextSavedProviders;
  String get selectedProviderActions => t.shellTextSelectedProviderActions;
  String get copyProvider => t.shellTextCopyProvider;
  String get selectedType => t.shellTextSelectedType;
  String get mobileEditTemplate => t.shellTextMobileEditTemplate;
  String get mobileNewTemplate => t.shellTextMobileNewTemplate;
  String get mobileEditTemplateStartingValues =>
      t.shellTextMobileEditTemplateStartingValues;
  String get mobileSaveTemplateStartingPoint =>
      t.shellTextMobileSaveTemplateStartingPoint;
  String get mobileCloseTemplateEditor => t.shellTextMobileCloseTemplateEditor;
  String get mobileTemplateName => t.shellTextMobileTemplateName;
  String get mobileTemplateShownWhenChoosing =>
      t.shellTextMobileTemplateShownWhenChoosing;
  String get mobileTemplateTypeChosenWhenCreated =>
      t.shellTextMobileTemplateTypeChosenWhenCreated;
  String mobileNoReusableSettingsYetTemplate(String providerTitle) =>
      providerTitle.isEmpty
      ? t.shellTextMobileNoReusableSettingsYetTemplateUnnamed
      : t.shellTextMobileNoReusableSettingsYetTemplateNamed(
          providerTitle: providerTitle,
        );

  String get mobileReusableValuesPrefillProvider =>
      t.shellTextMobileReusableValuesPrefillProvider;
  String get mobileSaveTemplate => t.shellTextMobileSaveTemplate;
  String get mobileUseTemplate => t.shellTextMobileUseTemplate;
  String get mobileDeleteTemplate => t.shellTextMobileDeleteTemplate;
  String get selectedTemplateActions => t.shellTextSelectedTemplateActions;
  String get copyTemplate => t.shellTextCopyTemplate;

  String get desktopProviderRecord => t.shellTextDesktopProviderRecord;
  String get desktopNewProviderRecord => t.shellTextDesktopNewProviderRecord;
  String get desktopEditReusableProviderRecord =>
      t.shellTextDesktopEditReusableProviderRecord;
  String get desktopCreateReusableProviderRecord =>
      t.shellTextDesktopCreateReusableProviderRecord;
  String get desktopRecordParameters => t.shellTextDesktopRecordParameters;
  String desktopParametersFor(String providerTitle) =>
      t.shellTextDesktopParametersFor(providerTitle: providerTitle);
  String get desktopChooseProviderFamilyFirst =>
      t.shellTextDesktopChooseProviderFamilyFirst;
  String desktopEditReusableParametersFor(String providerTitle) =>
      t.shellTextDesktopEditReusableParametersFor(providerTitle: providerTitle);
  String get desktopUseInProfileDraft => t.shellTextDesktopUseInProfileDraft;
  String get desktopNewRecord => t.shellTextDesktopNewRecord;
  String get desktopRecordName => t.shellTextDesktopRecordName;
  String get desktopRecordNameHelp => t.shellTextDesktopRecordNameHelp;
  String get desktopAttachedFamily => t.shellTextDesktopAttachedFamily;
  String get desktopAttachedFamilyHelp => t.shellTextDesktopAttachedFamilyHelp;
  String get desktopFamilyCharacteristics =>
      t.shellTextDesktopFamilyCharacteristics;
  String get desktopFamilyCharacteristicsHelp =>
      t.shellTextDesktopFamilyCharacteristicsHelp;
  String desktopProviderRecordSupportError({
    required String providerName,
    required String error,
  }) => t.shellTextDesktopProviderRecordSupportError(
    providerName: providerName,
    error: error,
  );
  String get desktopNoFamilyAttachedYet =>
      t.shellTextDesktopNoFamilyAttachedYet;
  String get desktopSelectedFamily => t.shellTextDesktopSelectedFamily;
  String get desktopOpenFamilyChooserFirst =>
      t.shellTextDesktopOpenFamilyChooserFirst;
  String desktopFamilyAttachedToRecord(String providerTitle) =>
      t.shellTextDesktopFamilyAttachedToRecord(providerTitle: providerTitle);
  String get desktopShippedByApp => t.shellTextDesktopShippedByApp;
  String get desktopHostOverlayAvailable =>
      t.shellTextDesktopHostOverlayAvailable;
  String get desktopHostOverlayUnavailable =>
      t.shellTextDesktopHostOverlayUnavailable;
  String get desktopUseActionStripToChooseFamily =>
      t.shellTextDesktopUseActionStripToChooseFamily;
  String get desktopFamiliesReadonlyEditBelow =>
      t.shellTextDesktopFamiliesReadonlyEditBelow;
  String get desktopChooseFamily => t.shellTextDesktopChooseFamily;
  String get desktopSaveDraft => t.shellTextDesktopSaveDraft;
  String get desktopSaveRecord => t.shellTextDesktopSaveRecord;
  String get desktopReadOnlyFamily => t.shellTextDesktopReadOnlyFamily;
  String get desktopAttachedFamilyCardHelp =>
      t.shellTextDesktopAttachedFamilyCardHelp;
  String get desktopNoEditableParametersYet =>
      t.shellTextDesktopNoEditableParametersYet;
  String get desktopNoEditableParameters =>
      t.shellTextDesktopNoEditableParameters;
  String get desktopEditableParametersReady =>
      t.shellTextDesktopEditableParametersReady;
  String get desktopNoSavedProfilesYetShort =>
      t.shellTextDesktopNoSavedProfilesYetShort;
  String get desktopNoShippedProviderFamilies =>
      t.shellTextDesktopNoShippedProviderFamilies;
  String desktopNoEditableRecordParameters(String providerTitle) => t
      .shellTextDesktopNoEditableRecordParameters(providerTitle: providerTitle);
  String get desktopSavedProfilesLibraryTitle =>
      t.shellTextDesktopSavedProfilesLibraryTitle;
  String get desktopSavedProfilesLibrarySubtitle =>
      t.shellTextDesktopSavedProfilesLibrarySubtitle;
  String get desktopReturnPathExplicitTitle =>
      t.shellTextDesktopReturnPathExplicitTitle;
  String get desktopReturnPathExplicitMessage =>
      t.shellTextDesktopReturnPathExplicitMessage;
  String get desktopProviderRecordsLibraryTitle =>
      t.shellTextDesktopProviderRecordsLibraryTitle;
  String get desktopProviderRecordsLibrarySubtitle =>
      t.shellTextDesktopProviderRecordsLibrarySubtitle;
  String get desktopRecordsSeparateFromFamiliesTitle =>
      t.shellTextDesktopRecordsSeparateFromFamiliesTitle;
  String get desktopRecordsSeparateFromFamiliesMessage =>
      t.shellTextDesktopRecordsSeparateFromFamiliesMessage;
  String get desktopNoProviderRecordsYet =>
      t.shellTextDesktopNoProviderRecordsYet;
  String get desktopNewFromPresetSubtitle =>
      t.shellTextDesktopNewFromPresetSubtitle;
  String get desktopPresetBootstrapExplicitTitle =>
      t.shellTextDesktopPresetBootstrapExplicitTitle;
  String get desktopPresetBootstrapExplicitMessage =>
      t.shellTextDesktopPresetBootstrapExplicitMessage;
  String get desktopProviderFamiliesSubtitle =>
      t.shellTextDesktopProviderFamiliesSubtitle;
  String get desktopFamiliesReadonlyHereTitle =>
      t.shellTextDesktopFamiliesReadonlyHereTitle;
  String get desktopFamiliesReadonlyHereMessage =>
      t.shellTextDesktopFamiliesReadonlyHereMessage;
  String get desktopUsePreset => t.shellTextDesktopUsePreset;
  String get launched => t.shellTextLaunched;
  String get desktopSavedProfilesRouteDetail =>
      t.shellTextDesktopSavedProfilesRouteDetail;
  String get desktopManagedRecordsTitle =>
      t.shellTextDesktopManagedRecordsTitle;
  String get desktopManagedRecordsRouteDetail =>
      t.shellTextDesktopManagedRecordsRouteDetail;
  String get desktopProviderRecordsRouteDetail =>
      t.shellTextDesktopProviderRecordsRouteDetail;
  String get desktopPresetBootstrapTitle =>
      t.shellTextDesktopPresetBootstrapTitle;
  String get desktopPresetBootstrapRouteDetail =>
      t.shellTextDesktopPresetBootstrapRouteDetail;
  String get desktopProviderFamiliesRouteDetail =>
      t.shellTextDesktopProviderFamiliesRouteDetail;
  String get desktopWorkflowReadiness => t.shellTextDesktopWorkflowReadiness;
  String desktopTunnelModesReadySummary(int ready, int total) =>
      t.shellTextDesktopTunnelModesReadySummary(ready: ready, total: total);
  String get desktopPlatformTunnelSummary =>
      t.shellTextDesktopPlatformTunnelSummary;
  String desktopResolutionsSessionsCompact(int resolutions, int sessions) =>
      t.shellTextDesktopResolutionsSessionsCompact(
        resolutions: resolutions,
        sessions: sessions,
      );
  String get desktopSupportContextPinned =>
      t.shellTextDesktopSupportContextPinned;
  String get desktopSupportAttentionRequired =>
      t.shellTextDesktopSupportAttentionRequired;
  String get desktopSupportContextWarmingUp =>
      t.shellTextDesktopSupportContextWarmingUp;
  String get desktopLiveWorkActive => t.shellTextDesktopLiveWorkActive;
  String get desktopSupportNote => t.shellTextDesktopSupportNote;
  String get desktopSupportBlockedDetail =>
      t.shellTextDesktopSupportBlockedDetail;
  String get desktopSupportBootingDetail =>
      t.shellTextDesktopSupportBootingDetail;
  String get desktopSupportReadyLiveDetail =>
      t.shellTextDesktopSupportReadyLiveDetail;
  String get desktopSupportReadyIdleDetail =>
      t.shellTextDesktopSupportReadyIdleDetail;
  String get desktopInspector => t.shellTextDesktopInspector;
  String get desktopInspectorDiagnosticsSubtitle =>
      t.shellTextDesktopInspectorDiagnosticsSubtitle;
  String get desktopInspectorActivitySubtitle =>
      t.shellTextDesktopInspectorActivitySubtitle;
  String get desktopTunnelDetail => t.shellTextDesktopTunnelDetail;
  String get desktopPlatformTunnelModes =>
      t.shellTextDesktopPlatformTunnelModes;
  String get desktopFailClosedCompactUntilStartup =>
      t.shellTextDesktopFailClosedCompactUntilStartup;
  String get desktopFailClosedSectionCompactUntilStartup =>
      t.shellTextDesktopFailClosedSectionCompactUntilStartup;
  String get desktopTypedHostTunnelSummary =>
      t.shellTextDesktopTypedHostTunnelSummary;
  String get desktopNoPlatformTunnelModesReported =>
      t.shellTextDesktopNoPlatformTunnelModesReported;
  String get desktopUseDiagnosticsForReportedModes =>
      t.shellTextDesktopUseDiagnosticsForReportedModes;
  String get desktopAllModesFailClosedLatestEvidence =>
      t.shellTextDesktopAllModesFailClosedLatestEvidence;
  String get desktopAllModesFailClosedTestStartup =>
      t.shellTextDesktopAllModesFailClosedTestStartup;
  String get desktopHostModeAvailable => t.shellTextDesktopHostModeAvailable;
  String get desktopHostModeUnavailable =>
      t.shellTextDesktopHostModeUnavailable;
  String get desktopNoStartupRequestYet =>
      t.shellTextDesktopNoStartupRequestYet;
  String get desktopNoSessionsYet => t.shellTextDesktopNoSessionsYet;
  String get desktopEventStreamSubtitle =>
      t.shellTextDesktopEventStreamSubtitle;
  String get desktopWorkflowAssuranceBooting =>
      t.shellTextDesktopWorkflowAssuranceBooting;
  String get desktopWorkflowAssuranceBlocked =>
      t.shellTextDesktopWorkflowAssuranceBlocked;
  String get desktopWorkflowAssuranceReadyLive =>
      t.shellTextDesktopWorkflowAssuranceReadyLive;
  String get desktopWorkflowAssuranceReadyIdle =>
      t.shellTextDesktopWorkflowAssuranceReadyIdle;
  String desktopPlatformTunnelCapabilitySummary({
    required bool available,
    List<String> satisfiedPrerequisites = const <String>[],
    String? missingPrerequisite,
  }) {
    if (available && satisfiedPrerequisites.isNotEmpty) {
      return this.satisfiedPrerequisites(satisfiedPrerequisites.join(', '));
    }
    if (!available && missingPrerequisite != null) {
      return this.missingPrerequisite(missingPrerequisite);
    }
    return available ? desktopHostModeAvailable : desktopHostModeUnavailable;
  }

  String desktopCompactPlatformTunnelCapabilitySummary({
    required String modeLabel,
    required bool available,
    String? missingPrerequisite,
    String? message,
  }) {
    final buffer = StringBuffer(
      available
          ? t.shellTextDesktopCompactPlatformTunnelCapabilitySummaryAvailable(
              modeLabel: modeLabel,
            )
          : t.shellTextDesktopCompactPlatformTunnelCapabilitySummaryUnavailable(
              modeLabel: modeLabel,
            ),
    );
    if (missingPrerequisite != null && missingPrerequisite.isNotEmpty) {
      buffer.write(
        t.shellTextDesktopCompactPlatformTunnelCapabilitySummaryMissingPrerequisite(
          missingPrerequisite: missingPrerequisite,
        ),
      );
    } else if (!available) {
      buffer.write(
        t.shellTextDesktopCompactPlatformTunnelCapabilitySummaryUnavailableSuffix,
      );
    }
    final normalizedMessage = message?.trim() ?? '';
    if (normalizedMessage.isNotEmpty) {
      buffer.write(' $normalizedMessage');
    }
    return buffer.toString();
  }

  String desktopCompactPlatformTunnelStatusLabel({
    required String modeLabel,
    String? missingPrerequisite,
  }) {
    final missing = missingPrerequisite?.trim() ?? '';
    if (missing.isEmpty) {
      return t.shellTextDesktopCompactPlatformTunnelStatusLabelUnavailable(
        modeLabel: modeLabel,
      );
    }
    return t.shellTextDesktopCompactPlatformTunnelStatusLabelMissing(
      modeLabel: modeLabel,
      missing: missing,
    );
  }

  String desktopPlatformTunnelResultSummary({
    required String modeLabel,
    required bool ready,
    required String stageLabel,
    String? missingPrerequisite,
    String? message,
  }) {
    if (ready) {
      return t.shellTextDesktopPlatformTunnelResultSummaryReady(
        modeLabel: modeLabel,
      );
    }
    final buffer = StringBuffer(
      t.shellTextDesktopPlatformTunnelResultSummaryBlocked(
        stageLabel: stageLabel,
      ),
    );
    final missing = missingPrerequisite?.trim() ?? '';
    if (missing.isNotEmpty) {
      buffer.write(' ${this.missingPrerequisite(missing)}.');
    }
    final normalizedMessage = message?.trim() ?? '';
    if (normalizedMessage.isNotEmpty) {
      buffer.write(' $normalizedMessage');
    }
    return buffer.toString();
  }

  String get continueAfterBrowserStep => t.shellTextContinueAfterBrowserStep;
  String get continueInBrowser => t.shellTextContinueInBrowser;
  String providerFamilyLabel(String familyTitle) =>
      t.shellTextProviderFamilyLabel(familyTitle: familyTitle);
  String get appOwnedManagedRecord => t.shellTextAppOwnedManagedRecord;
  String get selectedFamily => t.shellTextSelectedFamily;

  String get mobileOpenBrowser => t.shellTextMobileOpenBrowser;
  String get mobileContinueInApp => t.shellTextMobileContinueInApp;
  String challengeContinuationCancelled(String challengeId) =>
      t.shellTextChallengeContinuationCancelled(challengeId: challengeId);
  String challengeContinuationFailed({
    required String challengeId,
    required Object error,
  }) => t.shellTextChallengeContinuationFailed(
    error: error,
    challengeId: challengeId,
  );
  String get mobileEditProfile => t.shellTextMobileEditProfile;
  String get mobileSelectedForHome => t.shellTextMobileSelectedForHome;
  String get mobileTurnOnVpn => t.shellTextMobileTurnOnVpn;
  String get mobileTurnOffVpn => t.shellTextMobileTurnOffVpn;
  String get mobileProvidersTitle => t.shellTextMobileProvidersTitle;
  String get mobileProvidersSubtitle => t.shellTextMobileProvidersSubtitle;
  String get mobileAddProvider => t.shellTextMobileAddProvider;
  String get mobileBackToProviders => t.shellTextMobileBackToProviders;
  String get mobileNoProvider => t.shellTextMobileNoProvider;
  String get mobileInputConfigured => t.shellTextMobileInputConfigured;
  String get supportTitle => t.shellTextSupportTitle;
  String get supportSubtitle => t.shellTextSupportSubtitle;
  String get routingTitle => t.shellTextRoutingTitle;
  String get routingSubtitle => t.shellTextRoutingSubtitle;
  String get routingProfile => t.shellTextRoutingProfile;
  String get routingProfileStandard => t.shellTextRoutingProfileStandard;
  String get routingProfileDevelopmentWifi =>
      t.shellTextRoutingProfileDevelopmentWifi;
  String get routingProfileStandardDescription =>
      t.shellTextRoutingProfileStandardDescription;
  String get routingProfileDevelopmentWifiDescription =>
      t.shellTextRoutingProfileDevelopmentWifiDescription;
  String get appScope => t.shellTextAppScope;
  String modeScope(String modeLabel) =>
      t.shellTextModeScope(modeLabel: modeLabel);
  String get allApps => t.shellTextAllApps;
  String get includedApps => t.shellTextIncludedApps;
  String get excludedApps => t.shellTextExcludedApps;
  String routingScopeSummary({
    required int selectedCount,
    required int totalCount,
  }) => t.shellTextRoutingScopeSummary(
    selectedCount: selectedCount,
    totalCount: totalCount,
  );
  String get searchApps => t.shellTextSearchApps;
  String routingVisibleAppsSummary({
    required int visibleCount,
    required int totalCount,
    required int selectedCount,
  }) => t.shellTextRoutingVisibleAppsSummary(
    visibleCount: visibleCount,
    totalCount: totalCount,
    selectedCount: selectedCount,
  );
  String get bulkActions => t.shellTextBulkActions;
  String get selectVisibleApps => t.shellTextSelectVisibleApps;
  String get clearVisibleApps => t.shellTextClearVisibleApps;
  String get allInstalledAppsUseVpnPath =>
      t.shellTextAllInstalledAppsUseVpnPath;
  String get retryAppScan => t.shellTextRetryAppScan;
  String get noInstalledAppsReported => t.shellTextNoInstalledAppsReported;
  String get noInstalledAppsMatchSearch =>
      t.shellTextNoInstalledAppsMatchSearch;
  String get homeNoSavedProfilesYet => t.shellTextHomeNoSavedProfilesYet;
  String get homeNoSavedProfilesMessage =>
      t.shellTextHomeNoSavedProfilesMessage;
  String get currentProfile => t.shellTextCurrentProfile;
  String listeningOn(String address) =>
      t.shellTextListeningOn(address: address);
  String get currentMode => t.shellTextCurrentMode;
  String get noMobileTunnelModeAdvertised =>
      t.shellTextNoMobileTunnelModeAdvertised;
  String get executionPath => t.shellTextExecutionPath;
  String get providerStepTone => t.shellTextProviderStepTone;
  String get connectionLiveTone => t.shellTextConnectionLiveTone;
  String get setupNeededTone => t.shellTextSetupNeededTone;
  String get mainActionTone => t.shellTextMainActionTone;
  String get finishProviderValidation => t.shellTextFinishProviderValidation;
  String get vpnIsOn => t.shellTextVpnIsOn;
  String get profileRequired => t.shellTextProfileRequired;
  String get vpnIsOff => t.shellTextVpnIsOff;
  String get continueProviderFlowInApp => t.shellTextContinueProviderFlowInApp;
  String get openRequiredBrowserStepFromHome =>
      t.shellTextOpenRequiredBrowserStepFromHome;
  String get disconnectCurrentMobileVpnPath =>
      t.shellTextDisconnectCurrentMobileVpnPath;
  String get chooseOrFinishProfileBeforeStartingVpn =>
      t.shellTextChooseOrFinishProfileBeforeStartingVpn;
  String get startCurrentMobileVpnPath => t.shellTextStartCurrentMobileVpnPath;
  String get continueInProfiles => t.shellTextContinueInProfiles;
  String challengeKind(String kind) => t.shellTextChallengeKind(kind: kind);
  String get iveCompletedIt => t.shellTextIveCompletedIt;
  String get cancelChallenge => t.shellTextCancelChallenge;
  String get needDeeperDetail => t.shellTextNeedDeeperDetail;
  String resolutionsSessionsSummary({
    required int resolutions,
    required int sessions,
    required String liveSummary,
  }) => t.shellTextResolutionsSessionsSummary(
    resolutions: resolutions,
    sessions: sessions,
    liveSummary: liveSummary,
  );
  String get noStartupRequestYetShort => t.shellTextNoStartupRequestYetShort;
  String get routingUnavailableForMode => t.shellTextRoutingUnavailableForMode;
  String get routingUnavailableMessage => t.shellTextRoutingUnavailableMessage;
  String get noSavedProvidersYet => t.shellTextNoSavedProvidersYet;
  String get noSavedProvidersMessage => t.shellTextNoSavedProvidersMessage;
  String typeLabel(String familyTitle) =>
      t.shellTextTypeLabel(familyTitle: familyTitle);
  String get usedInProfiles => t.shellTextUsedInProfiles;
  String get createProvider => t.shellTextCreateProvider;
  String get createProviderChooseType => t.shellTextCreateProviderChooseType;
  String get createProviderUseTemplate => t.shellTextCreateProviderUseTemplate;
  String get createProviderUsePreset => t.shellTextCreateProviderUsePreset;
  String get providerTypes => t.shellTextProviderTypes;
  String get presets => t.shellTextPresets;
  String get noShippedProviderTypesYet => t.shellTextNoShippedProviderTypesYet;
  String get searchTemplates => t.shellTextSearchTemplates;
  String get myTemplates => t.shellTextMyTemplates;
  String get noSavedTemplatesYet => t.shellTextNoSavedTemplatesYet;
  String get noSavedTemplatesMessage => t.shellTextNoSavedTemplatesMessage;
  String get noSavedTemplatesMatchSearch =>
      t.shellTextNoSavedTemplatesMatchSearch;
  String get prefillsNewProviders => t.shellTextPrefillsNewProviders;
  String get shippedTemplates => t.shellTextShippedTemplates;
  String get shippedPresets => t.shellTextShippedPresets;
  String get noShippedTemplatesMatchSearch =>
      t.shellTextNoShippedTemplatesMatchSearch;
  String get startingPointForNewProviders =>
      t.shellTextStartingPointForNewProviders;
  String get readOnlyShippedTemplate => t.shellTextReadOnlyShippedTemplate;
  String get activityPageSubtitle => t.shellTextActivityPageSubtitle;
  String resolutionsCount(int count) =>
      t.shellTextResolutionsCount(count: count);
  String sessionsCount(int count) => t.shellTextSessionsCount(count: count);
  String get diagnosticsPageSubtitle => t.shellTextDiagnosticsPageSubtitle;
  String eventsCount(int count) => t.shellTextEventsCount(count: count);
  String get waitingForMobileHostBridge =>
      t.shellTextWaitingForMobileHostBridge;
  String guiBuildTag(String label) => t.shellTextGuiBuildTag(label: label);
  String hostBuildTag(String label) => t.shellTextHostBuildTag(label: label);
  String contractTag(String version) =>
      t.shellTextContractTag(version: version);
  String get reconnect => t.shellTextReconnect;
  String get refresh => t.shellTextRefresh;
  String get resolutionsTitle => t.shellTextResolutionsTitle;
  String get resolutionsSubtitle => t.shellTextResolutionsSubtitle;
  String get noProviderResolutionsYet => t.shellTextNoProviderResolutionsYet;
  String get systemTunnelBannerText => t.shellTextSystemTunnelBannerText;
  String get noPlatformTunnelModesReported =>
      t.shellTextNoPlatformTunnelModesReported;
  String get availableLowercase => t.shellTextAvailableLowercase;
  String get unavailableLowercase => t.shellTextUnavailableLowercase;
  String get disconnectVpn => t.shellTextDisconnectVpn;
  String get requestStartup => t.shellTextRequestStartup;
  String get noStartupRequestYet => t.shellTextNoStartupRequestYet;
  String turnCredentialsSummary({
    required String address,
    required String username,
  }) => t.shellTextTurnCredentialsSummary(address: address, username: username);
  String exportExpiry({required String timestamp, String? source}) =>
      source == null
      ? t.shellTextExportExpiry(timestamp: timestamp)
      : t.shellTextExportExpiryWithSource(timestamp: timestamp, source: source);

  String failureSummary({required String stage, required String message}) =>
      t.shellTextFailureSummary(stage: stage, message: message);
  String sessionStateLabel(String value) => switch (value) {
    'starting' => t.shellTextStateStarting,
    'challenge_required' => t.shellTextStateChallengeRequired,
    'ready' => t.shellTextStateReady,
    'retrying' => t.shellTextStateRetrying,
    'stopping' => t.shellTextStateStopping,
    'stopped' => t.shellTextStateStopped,
    'failed' => t.shellTextStateFailed,
    _ => value,
  };

  String resolutionStateLabel(String value) => switch (value) {
    'starting' => t.shellTextStateStarting,
    'challenge_required' => t.shellTextStateChallengeRequired,
    'resolved' => t.shellTextStateResolved,
    'failed' => t.shellTextStateFailed,
    'cancelled' => t.shellTextStateCancelled,
    'expired' => t.shellTextStateExpired,
    _ => value,
  };

  String actionExecutionOwnerLabel(String value) => switch (value) {
    'host' => t.shellTextExecutionOwnerHost,
    'shell_local' => t.shellTextExecutionOwnerShellLocal,
    'shell_external' => t.shellTextExecutionOwnerShellExternal,
    _ => value,
  };

  String get moreChallengeActions => t.shellTextMoreChallengeActions;
  String get moreResolutionActions => t.shellTextMoreResolutionActions;
  String get startOnThisDevice => t.shellTextStartOnThisDevice;
  String get shareHandoff => t.shellTextShareHandoff;
  String get openRoom => t.shellTextOpenRoom;
  String get openCamera => t.shellTextOpenCamera;
  String get openArchive => t.shellTextOpenArchive;
  String get copyHandoff => t.shellTextCopyHandoff;
  String get cancelResolution => t.shellTextCancelResolution;
  String get sessionsTitle => t.shellTextSessionsTitle;
  String get noMobileSessionsYet => t.shellTextNoMobileSessionsYet;
  String sessionListenConnections({
    required String listen,
    required int connections,
  }) => t.shellTextSessionListenConnections(
    listen: listen,
    connections: connections,
  );
  String sessionUpdated({
    required String timestamp,
    required String sessionId,
  }) => t.shellTextSessionUpdated(timestamp: timestamp, sessionId: sessionId);
  String get moreSessionActions => t.shellTextMoreSessionActions;
  String get stopSession => t.shellTextStopSession;
  String get exportDiagnostics => t.shellTextExportDiagnostics;
  String get eventStream => t.shellTextEventStream;
  String get eventStreamSubtitle => t.shellTextEventStreamSubtitle;
  String get noEventsYet => t.shellTextNoEventsYet;
  String get resetNeeded => t.shellTextResetNeeded;
  String get hostReady => t.shellTextHostReady;
  String get hostIncompatible => t.shellTextHostIncompatible;
  String get hostBlocked => t.shellTextHostBlocked;
  String get connecting => t.shellTextConnecting;
  String get mobileHostReady => t.shellTextMobileHostReady;
  String get mobileHostIncompatible => t.shellTextMobileHostIncompatible;
  String get mobileHostBlocked => t.shellTextMobileHostBlocked;
  String get connectingToMobileHost => t.shellTextConnectingToMobileHost;
  String satisfiedPrerequisites(String prerequisites) =>
      t.shellTextSatisfiedPrerequisites(prerequisites: prerequisites);
  String missingPrerequisite(String prerequisite) =>
      t.shellTextMissingPrerequisite(prerequisite: prerequisite);
  String get mobileHostModeAvailable => t.shellTextMobileHostModeAvailable;
  String get mobileHostModeUnavailable => t.shellTextMobileHostModeUnavailable;
  String platformTunnelReady(String modeLabel) =>
      t.shellTextPlatformTunnelReady(modeLabel: modeLabel);
  String platformTunnelReadyWithRoutingProfile({
    required String modeLabel,
    required String profileLabel,
  }) => t.shellTextPlatformTunnelReadyWithRoutingProfile(
    modeLabel: modeLabel,
    profileLabel: profileLabel,
  );
  String startupBlockedAt(String stageLabel) =>
      t.shellTextStartupBlockedAt(stageLabel: stageLabel);
  String get unknownStage => t.shellTextUnknownStage;
  String get noMobileTunnelModeSelected =>
      t.shellTextNoMobileTunnelModeSelected;
  String get androidSystemVpnMode => t.shellTextAndroidSystemVpnMode;
  String get appleNetworkExtensionMode => t.shellTextAppleNetworkExtensionMode;
  String get windowsWintunMode => t.shellTextWindowsWintunMode;
  String get linuxTunMode => t.shellTextLinuxTunMode;
  String modeSummary({
    required String modeLabel,
    required String routingSummary,
    String? executionPath,
  }) => executionPath == null
      ? t.shellTextModeSummaryWithoutExecutionPath(
          modeLabel: modeLabel,
          routingSummary: routingSummary,
        )
      : t.shellTextModeSummaryWithExecutionPath(
          modeLabel: modeLabel,
          routingSummary: routingSummary,
          executionPath: executionPath,
        );

  String get perAppRoutingUnavailable => t.shellTextPerAppRoutingUnavailable;
  String restartVpnToApplyRoutingProfile(String modeLabel) =>
      t.shellTextRestartVpnToApplyRoutingProfile(modeLabel: modeLabel);
  String developmentWifiRoutingUnavailableForHost(String modeLabel) =>
      t.shellTextDevelopmentWifiRoutingUnavailableForHost(modeLabel: modeLabel);
  String get developmentWifiRoutingSavedButUnsupported =>
      t.shellTextDevelopmentWifiRoutingSavedButUnsupported;
  String routingSummaryWithProfile({
    required String profileLabel,
    required String scopeSummary,
  }) => t.shellTextRoutingSummaryWithProfile(
    profileLabel: profileLabel,
    scopeSummary: scopeSummary,
  );
  String get scopeAllInstalledApps => t.shellTextScopeAllInstalledApps;
  String get scopeIncludedAppsEmpty => t.shellTextScopeIncludedAppsEmpty;
  String scopeOnlySelectedApps(int count) =>
      t.shellTextScopeOnlySelectedApps(count: count);
  String get scopeExcludedAppsEmpty => t.shellTextScopeExcludedAppsEmpty;
  String scopeAllExceptSelectedApps(int count) =>
      t.shellTextScopeAllExceptSelectedApps(count: count);
  String get wireGuardNativeOverTurnDatagram =>
      t.shellTextWireGuardNativeOverTurnDatagram;
  String get wireGuardNativeOverTurnDtls =>
      t.shellTextWireGuardNativeOverTurnDtls;
  String get wireGuardNativeOverWebRtc => t.shellTextWireGuardNativeOverWebRtc;
  String get customOverlayOverTurnDatagram =>
      t.shellTextCustomOverlayOverTurnDatagram;
  String get customOverlayOverTurnDtls => t.shellTextCustomOverlayOverTurnDtls;
  String get customOverlayOverWebRtc => t.shellTextCustomOverlayOverWebRtc;
  String get proxyCoreOverTurnDatagram => t.shellTextProxyCoreOverTurnDatagram;
  String get proxyCoreOverTurnDtls => t.shellTextProxyCoreOverTurnDtls;
  String get proxyCoreOverWebRtc => t.shellTextProxyCoreOverWebRtc;
  String get trustTunnelOverTurnDatagram =>
      t.shellTextTrustTunnelOverTurnDatagram;
  String get trustTunnelOverTurnDtls => t.shellTextTrustTunnelOverTurnDtls;
  String get trustTunnelOverWebRtc => t.shellTextTrustTunnelOverWebRtc;
  String get ownedBrowserMissingMetadata =>
      t.shellTextOwnedBrowserMissingMetadata;
  String get ownedBrowserMissingUrl => t.shellTextOwnedBrowserMissingUrl;
  String get ownedBrowserNoEvidence => t.shellTextOwnedBrowserNoEvidence;
  String ownedBrowserTitle(String provider) =>
      t.shellTextOwnedBrowserTitle(provider: provider);
  String get ownedBrowserOpenInvite => t.shellTextOwnedBrowserOpenInvite;
  String get ownedBrowserCollecting => t.shellTextOwnedBrowserCollecting;
  String get ownedBrowserContinue => t.shellTextOwnedBrowserContinue;
  String get ownedBrowserFallbackPrompt =>
      t.shellTextOwnedBrowserFallbackPrompt;
  String get ownedBrowserHideKeyboard => t.shellTextOwnedBrowserHideKeyboard;
}

ShellText get currentShellText => const ShellText();

extension BuildContextShellTextX on BuildContext {
  ShellText get shellText => currentShellText;
}
