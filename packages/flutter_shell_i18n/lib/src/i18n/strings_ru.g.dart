///
/// Generated file. Do not edit.
///
// coverage:ignore-file
// ignore_for_file: type=lint, unused_import

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:slang/generated.dart';
import 'strings.g.dart';

// Path: <root>
class TranslationsRu extends Translations
    with BaseTranslations<AppLocale, Translations> {
  /// You can call this constructor and build your own translation instance of this locale.
  /// Constructing via the enum [AppLocale.build] is preferred.
  TranslationsRu({
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
             locale: AppLocale.ru,
             overrides: overrides ?? {},
             cardinalResolver: cardinalResolver,
             ordinalResolver: ordinalResolver,
           ),
       super(
         cardinalResolver: cardinalResolver,
         ordinalResolver: ordinalResolver,
       ) {
    super.$meta.setFlatMapFunction(
      $meta.getTranslation,
    ); // copy base translations to super.$meta
    $meta.setFlatMapFunction(_flatMapFunction);
  }

  /// Metadata for the translations of <ru>.
  @override
  final TranslationMetadata<AppLocale, Translations> $meta;

  /// Access flat map
  @override
  dynamic operator [](String key) =>
      $meta.getTranslation(key) ?? super.$meta.getTranslation(key);

  late final TranslationsRu _root = this; // ignore: unused_field

  @override
  TranslationsRu $copyWith({
    TranslationMetadata<AppLocale, Translations>? meta,
  }) => TranslationsRu(meta: meta ?? this.$meta);

  // Translations
  @override
  String get appDesktopTitle => 'vk-turn-proxy настольная оболочка';
  @override
  String get appDesktopReferencesTitle =>
      'vk-turn-proxy примеры настольной оболочки';
  @override
  String get appMobileTitle => 'vk-turn-proxy мобильная оболочка';
  @override
  String get localeMenuLabel => 'Язык';
  @override
  String get localeSwitchTooltip => 'Сменить язык';
  @override
  String get localeSystemDefault => 'Системный';
  @override
  String get localeEnglish => 'Английский';
  @override
  String get localeRussian => 'Русский';
  @override
  String get commonHome => 'Главная';
  @override
  String get commonProfiles => 'Профили';
  @override
  String get commonProviders => 'Провайдеры';
  @override
  String get commonRouting => 'Маршрутизация';
  @override
  String get commonSupport => 'Поддержка';
  @override
  String get commonDiagnostics => 'Диагностика';
  @override
  String get commonLiveWork => 'Текущая работа';
  @override
  String get commonReconnect => 'Переподключить';
  @override
  String get commonRefresh => 'Обновить';
  @override
  String get commonWorkflows => 'Рабочие процессы';
  @override
  String get commonQuickActions => 'Быстрые действия';
  @override
  String get commonSavedProfiles => 'Сохраненные профили';
  @override
  String get commonProviderRecords => 'Записи провайдеров';
  @override
  String get commonNewDraft => 'Новый черновик';
  @override
  String get commonNewFromPreset => 'Новый из пресета';
  @override
  String get commonProviderFamilies => 'Семейства провайдеров';
  @override
  String get commonOpenWorkflowsTooltip => 'Открыть рабочие процессы';
  @override
  String get mobileHomeTitle => 'Главная';
  @override
  String get mobileHomeSubtitle =>
      'Выберите профиль, завершите шаг провайдера в браузере и отсюда включайте или выключайте текущий путь VPN на мобильном устройстве.';
  @override
  String get mobileProfilesTitle => 'Профили';
  @override
  String get mobileProfilesSubtitle =>
      'Выберите сохраненный профиль или добавьте новый для главного экрана.';
  @override
  String get mobileProfilesImportInvite => 'Импортировать инвайт';
  @override
  String get mobileProfilesRouting => 'Маршрутизация';
  @override
  String get mobileProfilesActionsTooltip => 'Действия профилей';
  @override
  String get mobileProfilesAddProfile => 'Добавить профиль';
  @override
  String get mobileProfilesEmptyTitle => 'Сохраненных профилей пока нет';
  @override
  String get mobileProfilesEmptyMessage =>
      'Создайте или импортируйте профиль, затем используйте главный экран для быстрого запуска VPN одним нажатием.';
  @override
  String get desktopShellLabel => 'Настольная оболочка управления';
  @override
  String get desktopStatusConnectingTitle => 'Подключение к локальному хосту';
  @override
  String get desktopStatusReadyTitle => 'Локальный хост готов';
  @override
  String get desktopStatusBlockedTitle => 'Локальный хост заблокирован';
  @override
  String get desktopStatusStartingDetail =>
      'Запуск локального хоста и согласование возможностей.';
  @override
  String get desktopStatusConnectedDetail => 'Подключено к локальному хосту.';
  @override
  String get desktopStatusWaitingDetail =>
      'Ожидание согласования с локальным хостом.';
  @override
  String get desktopReadyWorkflowDetail =>
      'Основным остается сфокусированный редактор; диагностика и текущая работа остаются вторичными, пока не понадобятся.';
  @override
  String get desktopSectionProfilesSubtitle => 'Редактирование профилей';
  @override
  String get desktopSectionProvidersSubtitle => 'Записи провайдеров';
  @override
  String get sharedProviderAuthPostureNotApplicable =>
      'требование к авторизации не указано';
  @override
  String get sharedProviderAuthPostureGuest => 'гостевая авторизация';
  @override
  String get sharedProviderAuthPostureAccount => 'авторизация по аккаунту';
  @override
  String get sharedProviderAuthPostureGuestOrAccount => 'гость или аккаунт';
  @override
  String get sharedProviderAuthPostureStaticSecret => 'статический секрет';
  @override
  String get sharedProviderBrowserPolicyNotRequired => 'браузер не требуется';
  @override
  String get sharedProviderBrowserPolicyExternalRequired =>
      'нужен внешний браузер';
  @override
  String get sharedProviderBrowserPolicyEmbeddedAllowed =>
      'разрешен встроенный браузер';
  @override
  String get sharedArtifactFamilyGenericTurn => 'Generic TURN';
  @override
  String get sharedArtifactFamilyConferenceRoom => 'Комната конференции';
  @override
  String get sharedArtifactFamilyCameraStream => 'Поток камеры';
  @override
  String get sharedArtifactActionStartOnThisDevice =>
      'Запустить на этом устройстве';
  @override
  String get sharedArtifactActionExportHandoff =>
      'Экспортировать пакет handoff';
  @override
  String get sharedArtifactActionOpenRoom => 'Открыть комнату';
  @override
  String get sharedArtifactActionOpenCamera => 'Открыть камеру';
  @override
  String get sharedArtifactActionOpenArchive => 'Открыть архив';
  @override
  String get sharedPlatformTunnelModeAndroidVpnService => 'Android VPN Service';
  @override
  String get sharedPlatformTunnelModeAppleNetworkExtension =>
      'Apple Network Extension';
  @override
  String get sharedPlatformTunnelModeWindowsWintun => 'Windows Wintun';
  @override
  String get sharedPlatformTunnelModeLinuxTun => 'Linux TUN';
  @override
  String get sharedPlatformTunnelPrerequisitePermission => 'разрешение';
  @override
  String get sharedPlatformTunnelPrerequisiteEntitlement => 'право доступа';
  @override
  String get sharedPlatformTunnelPrerequisitePrivilegedExtension =>
      'привилегированное расширение';
  @override
  String get sharedPlatformTunnelPrerequisiteDriver => 'драйвер';
  @override
  String get sharedPlatformTunnelPrerequisiteRouteExclusion =>
      'исключение маршрута';
  @override
  String get sharedPlatformTunnelPrerequisiteDnsBypass => 'обход DNS';
  @override
  String get sharedPlatformTunnelPrerequisiteAppRoutingPolicy =>
      'политика маршрутизации приложений';
  @override
  String get sharedPlatformTunnelPrerequisiteHostImplementation =>
      'реализация хоста';
  @override
  String get sharedPlatformTunnelStartupStageCapabilityCheck =>
      'Проверка возможностей';
  @override
  String get sharedPlatformTunnelStartupStagePermissionAcquire =>
      'Получение разрешения';
  @override
  String get sharedPlatformTunnelStartupStageEntitlementAcquire =>
      'Получение права доступа';
  @override
  String get sharedPlatformTunnelStartupStageDriverCheck => 'Проверка драйвера';
  @override
  String get sharedPlatformTunnelStartupStageRouteValidate =>
      'Проверка маршрута';
  @override
  String get sharedPlatformTunnelStartupStageHostBringup => 'Подъем хоста';
  @override
  String get sharedPlatformTunnelStartupStageRuntimeAttach =>
      'Подключение рантайма';
  @override
  String get sharedProviderConfigAvailabilityStateAvailable => 'Доступно';
  @override
  String get sharedProviderConfigAvailabilityStateProviderUnavailable =>
      'Провайдер недоступен';
  @override
  String get sharedProviderConfigAvailabilityStateSchemaUnsupported =>
      'Схема не поддерживается';
  @override
  String get sharedProviderConfigAvailabilityStateSettingsInvalid =>
      'Настройки невалидны';
  @override
  String get sharedCatalogPresetVkDefaultTitle => 'VK Calls';
  @override
  String get sharedCatalogPresetVkDefaultDescription =>
      'Создать управляемую запись провайдера VK для рабочего процесса с инвайтом и шагом в браузере.';
  @override
  String get sharedCatalogPresetVkDefaultSuggestedProfileName => 'VK Calls';
  @override
  String get sharedCatalogPresetGenericTurnDefaultTitle => 'Generic TURN';
  @override
  String get sharedCatalogPresetGenericTurnDefaultDescription =>
      'Создать управляемую запись Generic TURN для рабочего процесса со статической передачей TURN-параметров.';
  @override
  String get sharedCatalogPresetGenericTurnDefaultSuggestedProfileName =>
      'Generic TURN';
  @override
  String get sharedCatalogSupportedProviderVkTitle => 'VK Calls';
  @override
  String get sharedCatalogSupportedProviderVkDescription =>
      'Провайдер с инвайтом на первом шаге и продолжением через браузер, который приводит к готовым для транспорта учетным данным TURN.';
  @override
  String get sharedCatalogSupportedProviderVkSuggestedManagedProviderName =>
      'VK Calls';
  @override
  String get sharedCatalogSupportedProviderGenericTurnTitle => 'Generic TURN';
  @override
  String get sharedCatalogSupportedProviderGenericTurnDescription =>
      'Статическая передача TURN-параметров для детерминированного тестирования транспорта и запуска рантайма под управлением оператора.';
  @override
  String
  get sharedCatalogSupportedProviderGenericTurnSuggestedManagedProviderName =>
      'Generic TURN';
  @override
  String get shellTextClose => 'Закрыть';
  @override
  String get shellTextCancel => 'Отмена';
  @override
  String get shellTextBack => 'Назад';
  @override
  String get shellTextSave => 'Сохранить';
  @override
  String get shellTextDelete => 'Удалить';
  @override
  String get shellTextNewItem => 'Новый';
  @override
  String get shellTextMissing => 'отсутствует';
  @override
  String get shellTextUnknownValue => 'неизвестно';
  @override
  String get shellTextFailureFallback => 'сбой';
  @override
  String get shellTextRetry => 'Повторить';
  @override
  String get shellTextActivity => 'Активность';
  @override
  String get shellTextDiagnostics => 'Диагностика';
  @override
  String get shellTextOverview => 'Обзор';
  @override
  String get shellTextEvents => 'События';
  @override
  String get shellTextTemplates => 'Шаблоны';
  @override
  String get shellTextAvailable => 'Доступно';
  @override
  String get shellTextUnavailable => 'Недоступно';
  @override
  String get shellTextOpenActivity => 'Открыть активность';
  @override
  String get shellTextOpenDiagnostics => 'Открыть диагностику';
  @override
  String get shellTextOpenProfiles => 'Открыть профили';
  @override
  String get shellTextResetLocalState => 'Сбросить локальное состояние';
  @override
  String get shellTextImportFromFile => 'Импорт из файла';
  @override
  String get shellTextExportSavedProfile =>
      'Экспортировать сохраненный профиль';
  @override
  String get shellTextPasteEnvelope => 'Вставить конверт';
  @override
  String get shellTextCopyText => 'Копировать текст';
  @override
  String get shellTextSaveFile => 'Сохранить файл';
  @override
  String get shellTextShareText => 'Поделиться текстом';
  @override
  String get shellTextShareFile => 'Поделиться файлом';
  @override
  String get shellTextPreviewImport => 'Предпросмотр импорта';
  @override
  String get shellTextImportProfile => 'Импортировать профиль';
  @override
  String get shellTextPortableProfileJson => 'JSON переносимого профиля';
  @override
  String get shellTextPortableProfileEnvelope => 'Конверт переносимого профиля';
  @override
  String get shellTextNoManagedProvidersAvailableYet =>
      'Управляемые провайдеры пока недоступны.';
  @override
  String get shellTextSelectedProviderNotAdvertisedByConnectedHost =>
      'Выбранный провайдер не объявлен подключенным хостом.';
  @override
  String get shellTextSelectedProviderNotAdvertisedByConnectedMobileHost =>
      'Выбранный провайдер не объявлен подключенным мобильным хостом.';
  @override
  String shellTextSavedProfile({required Object profileLabel}) =>
      'Профиль ${profileLabel} сохранен.';
  @override
  String shellTextSavedMobileProfile({required Object profileLabel}) =>
      'Мобильный профиль ${profileLabel} сохранен.';
  @override
  String shellTextDeletedProfile({required Object profileId}) =>
      'Профиль ${profileId} удален.';
  @override
  String shellTextDeletedMobileProfile({required Object profileId}) =>
      'Мобильный профиль ${profileId} удален.';
  @override
  String shellTextSavedManagedProvider({required Object providerLabel}) =>
      'Управляемый провайдер ${providerLabel} сохранен.';
  @override
  String shellTextDeletedManagedProvider({required Object providerId}) =>
      'Управляемый провайдер ${providerId} удален.';
  @override
  String get shellTextSaveOrSelectProfileBeforeExport =>
      'Сохраните профиль или выберите уже сохраненный профиль перед экспортом.';
  @override
  String get shellTextSelectedProfileDependsOnMissingManagedProviderSnapshot =>
      'Выбранный профиль зависит от снимка управляемого провайдера, который больше недоступен локально.';
  @override
  String shellTextCopiedPortableProfile({required Object profileLabel}) =>
      'Переносимый профиль ${profileLabel} скопирован.';
  @override
  String shellTextCopiedSecretBearingPortableProfile({
    required Object profileLabel,
  }) =>
      'Скопирован переносимый профиль с секретами ${profileLabel}. Относитесь к этому пакету как к учетным данным.';
  @override
  String shellTextSavedPortableProfile({
    required Object profileLabel,
    required Object path,
  }) => 'Переносимый профиль ${profileLabel} сохранен в ${path}.';
  @override
  String shellTextSavedSecretBearingPortableProfile({
    required Object profileLabel,
    required Object path,
  }) => 'Переносимый профиль с секретами ${profileLabel} сохранен в ${path}.';
  @override
  String shellTextSharedPortableProfileAsText({required Object profileLabel}) =>
      'Переносимый профиль ${profileLabel} отправлен как текст.';
  @override
  String shellTextSharedSecretBearingPortableProfileAsText({
    required Object profileLabel,
  }) => 'Переносимый профиль с секретами ${profileLabel} отправлен как текст.';
  @override
  String shellTextSharedPortableProfileAsFile({required Object profileLabel}) =>
      'Переносимый профиль ${profileLabel} отправлен как файл.';
  @override
  String shellTextSharedSecretBearingPortableProfileAsFile({
    required Object profileLabel,
  }) => 'Переносимый профиль с секретами ${profileLabel} отправлен как файл.';
  @override
  String shellTextImportedProfile({required Object profileLabel}) =>
      'Профиль ${profileLabel} импортирован.';
  @override
  String shellTextImportedSecretBearingProfile({
    required Object profileLabel,
  }) =>
      'Импортирован профиль с секретами ${profileLabel}. Проверьте ввод провайдера, прежде чем делиться им дальше.';
  @override
  String shellTextStartedSession({required Object sessionId}) =>
      'Сессия ${sessionId} запущена.';
  @override
  String shellTextStartedMobileSession({required Object sessionId}) =>
      'Мобильная сессия ${sessionId} запущена.';
  @override
  String shellTextStoppedSession({required Object sessionId}) =>
      'Сессия ${sessionId} остановлена.';
  @override
  String shellTextManagedProviderNoLongerAvailable({
    required Object providerId,
  }) => 'Управляемый провайдер ${providerId} больше недоступен.';
  @override
  String shellTextAppliedManagedProviderToActiveProfileDraft({
    required Object providerLabel,
  }) =>
      'Управляемый провайдер ${providerLabel} применен к активному черновику профиля.';
  @override
  String shellTextAppliedManagedProviderToActiveMobileProfileDraft({
    required Object providerLabel,
  }) =>
      'Управляемый провайдер ${providerLabel} применен к активному черновику мобильного профиля.';
  @override
  String shellTextSeededManagedProviderDraftFromPreset({
    required Object presetTitle,
  }) =>
      'Новый черновик управляемого провайдера создан из пресета ${presetTitle}.';
  @override
  String shellTextCancelledResolution({required Object resolutionId}) =>
      'Разрешение ${resolutionId} отменено.';
  @override
  String shellTextCancelledMobileResolution({required Object resolutionId}) =>
      'Мобильное разрешение ${resolutionId} отменено.';
  @override
  String shellTextStartedSessionFromResolution({
    required Object sessionId,
    required Object resolutionId,
  }) =>
      'Сессия ${sessionId} запущена из разрешения ${resolutionId}. Готовность будет показана только после успешного запуска рантайма.';
  @override
  String shellTextStartedMobileSessionFromResolution({
    required Object sessionId,
    required Object resolutionId,
  }) =>
      'Мобильная сессия ${sessionId} запущена из разрешения ${resolutionId}. Готовность будет показана только после успешного запуска рантайма.';
  @override
  String shellTextCopiedHandoffLink({
    required Object resolutionId,
    required Object expiresAt,
  }) =>
      'Ссылка handoff для ${resolutionId} скопирована. Истекает ${expiresAt}.';
  @override
  String shellTextSharedHandoffLink({
    required Object resolutionId,
    required Object expiresAt,
  }) => 'Ссылка handoff для ${resolutionId} отправлена. Истекает ${expiresAt}.';
  @override
  String shellTextResolutionNoLongerAvailable({required Object resolutionId}) =>
      'Разрешение ${resolutionId} больше недоступно.';
  @override
  String shellTextResolutionDoesNotAdvertiseAction({
    required Object resolutionId,
    required Object actionLabel,
  }) => 'Разрешение ${resolutionId} не объявляет действие "${actionLabel}".';
  @override
  String shellTextResolutionHasNoBrowserTarget({
    required Object resolutionId,
    required Object actionLabel,
  }) =>
      'Разрешение ${resolutionId} не предоставляет браузерную цель для действия "${actionLabel}".';
  @override
  String shellTextOpenedResolutionAction({
    required Object actionLabel,
    required Object resolutionId,
  }) => 'Открыто действие "${actionLabel}" для ${resolutionId}.';
  @override
  String shellTextFailedToOpenResolutionAction({
    required Object actionLabel,
    required Object resolutionId,
  }) => 'Не удалось открыть действие "${actionLabel}" для ${resolutionId}.';
  @override
  String shellTextCancelledChallenge({required Object challengeId}) =>
      'Проверка ${challengeId} отменена.';
  @override
  String shellTextExportedDiagnostics({required Object path}) =>
      'Диагностика экспортирована в ${path}.';
  @override
  String get shellTextEventStreamClosed => 'поток событий закрыт';
  @override
  String get shellTextLocalHostNotReady => 'Локальный хост не готов.';
  @override
  String shellTextFailedToRestoreDesktopShellState({required Object error}) =>
      'Не удалось восстановить состояние настольной оболочки: ${error}';
  @override
  String shellTextFailedToPersistDesktopShellState({required Object error}) =>
      'Не удалось сохранить состояние настольной оболочки: ${error}';
  @override
  String shellTextFailedToPersistMobileShellState({required Object error}) =>
      'Не удалось сохранить состояние мобильной оболочки: ${error}';
  @override
  String shellTextPlatformTunnelReadyForLocalHost({
    required Object modeLabel,
  }) => '${modeLabel} готов для туннельного пути локального хоста.';
  @override
  String shellTextStartedResolutionForProvider({
    required Object resolutionId,
    required Object providerName,
  }) => 'Разрешение ${resolutionId} для ${providerName} запущено.';
  @override
  String shellTextStartedResolutionForProviderWithExternalBrowser({
    required Object resolutionId,
    required Object providerName,
  }) =>
      'Разрешение ${resolutionId} для ${providerName} запущено. Завершите обязательные шаги во внешнем браузере, прежде чем ожидать готовый артефакт.';
  @override
  String shellTextStartedResolutionForProviderWithBrowserContinuation({
    required Object resolutionId,
    required Object providerName,
  }) =>
      'Разрешение ${resolutionId} для ${providerName} запущено. Завершите возможный браузерный шаг проверки, прежде чем ожидать готовый артефакт.';
  @override
  String shellTextContinuedChallenge({required Object challengeId}) =>
      'Проверка ${challengeId} продолжена.';
  @override
  String shellTextContinuedChallengeWithExternalBrowser({
    required Object challengeId,
    required Object providerName,
  }) =>
      'Проверка ${challengeId} продолжена. Завершите внешний браузерный шаг для ${providerName}, прежде чем ожидать следующий переход состояния.';
  @override
  String shellTextContinuedChallengeForResolution({
    required Object challengeId,
    required Object providerName,
  }) =>
      'Проверка ${challengeId} продолжена. Завершите поток провайдера для ${providerName}, прежде чем ожидать готовый артефакт.';
  @override
  String shellTextContinuedChallengeForSession({
    required Object challengeId,
    required Object providerName,
  }) =>
      'Проверка ${challengeId} продолжена. Завершите поток провайдера для ${providerName}, прежде чем ожидать перехода сессии в состояние готовности.';
  @override
  String shellTextDesktopProviderSettingsRuntimeUnsupported({
    required Object providerName,
    required Object error,
  }) =>
      'Подключенная настольная оболочка не может отрисовать настройки провайдера для ${providerName}: ${error}';
  @override
  String shellTextMobileProviderSettingsRuntimeUnsupported({
    required Object providerName,
    required Object error,
  }) =>
      'Подключенная мобильная оболочка не может отрисовать настройки провайдера для ${providerName}: ${error}';
  @override
  String get shellTextSelectedManagedProviderFamilyNotInSupportedCatalog =>
      'Выбранное семейство управляемого провайдера не входит в поддерживаемый каталог приложения.';
  @override
  String get shellTextSelectedManagedProviderNotInSupportedCatalog =>
      'Выбранный управляемый провайдер не входит в поддерживаемый каталог приложения.';
  @override
  String get shellTextManagedProviderNotInSupportedCatalog =>
      'Этот управляемый провайдер не входит в поддерживаемый каталог приложения.';
  @override
  String shellTextDesktopReusableSettingsRuntimeUnsupported({
    required Object providerName,
    required Object error,
  }) =>
      'Подключенная настольная оболочка не может отрисовать переиспользуемые настройки для ${providerName}: ${error}';
  @override
  String shellTextMobileReusableSettingsRuntimeUnsupported({
    required Object providerName,
    required Object error,
  }) =>
      'Подключенная мобильная оболочка не может отрисовать переиспользуемые настройки для ${providerName}: ${error}';
  @override
  String shellTextConnectedHostDoesNotAdvertiseProviderFamilyYet({
    required Object providerTitle,
  }) =>
      'Подключенный хост пока не объявляет семейство провайдера ${providerTitle}.';
  @override
  String get shellTextSelectedTemplateFamilyNotInSupportedCatalog =>
      'Выбранное семейство шаблона не входит в поддерживаемый каталог приложения.';
  @override
  String get shellTextTemplateNotInSupportedCatalog =>
      'Этот шаблон не входит в поддерживаемый каталог приложения.';
  @override
  String shellTextMobileTemplateRuntimeUnsupported({
    required Object providerName,
    required Object error,
  }) =>
      'Подключенная мобильная оболочка не может отрисовать переиспользуемые настройки для ${providerName}: ${error}';
  @override
  String get shellTextLocalHostShutdownRequested =>
      'Запрошено завершение локального хоста.';
  @override
  String get shellTextNoCompatibleLocalHostFound =>
      'Совместимый локальный хост не найден, и кандидаты на запуск не настроены.';
  @override
  String get shellTextLocalHostLaunchFailedWithoutReportedError =>
      'Запуск локального хоста завершился неудачно без сообщенной ошибки.';
  @override
  String shellTextLocalHostLaunchFailed({required Object error}) =>
      'Не удалось запустить локальный хост: ${error}';
  @override
  String shellTextConnectedToLocalHost({required Object listenAddress}) =>
      'Подключено к локальному хосту ${listenAddress}';
  @override
  String shellTextLaunchedLocalHost({
    required Object description,
    required Object listenAddress,
  }) => 'Запущен ${description} на ${listenAddress}';
  @override
  String get shellTextSidecarLaunchCandidateEnvPath => 'GUI_SHELL_CLIENTD_PATH';
  @override
  String get shellTextSidecarLaunchCandidateNextToAppExecutable =>
      'sidecar рядом с исполняемым файлом приложения';
  @override
  String get shellTextSidecarLaunchCandidateBundledFrameworks =>
      'встроенный sidecar в Frameworks';
  @override
  String get shellTextSidecarLaunchCandidateFromPath => 'clientd из PATH';
  @override
  String get shellTextSidecarLaunchCandidateRepoLocalGoRun =>
      'локальный repo fallback через go run';
  @override
  String shellTextSidecarExitedBeforeReady({
    required Object description,
    required Object exitCode,
  }) =>
      '${description} завершился с кодом ${exitCode} до того, как control plane стал готов.';
  @override
  String shellTextProviderExpectsLinkEntryOnlyDesktop({
    required Object providerName,
    required Object inputKind,
  }) =>
      '${providerName} ожидает ввод типа ${inputKind}. Эта настольная оболочка сейчас поддерживает только ввод ссылки.';
  @override
  String shellTextSavedTemplate({required Object templateLabel}) =>
      'Шаблон ${templateLabel} сохранен.';
  @override
  String shellTextDeletedTemplate({required Object templateId}) =>
      'Шаблон ${templateId} удален.';
  @override
  String shellTextTemplateNoLongerAvailable({required Object templateId}) =>
      'Шаблон ${templateId} больше недоступен.';
  @override
  String shellTextSeededManagedProviderDraftFromTemplate({
    required Object templateLabel,
  }) =>
      'Новый черновик управляемого провайдера создан из шаблона ${templateLabel}.';
  @override
  String get shellTextClearedLocalMobileShellState =>
      'Локальное состояние мобильной оболочки очищено.';
  @override
  String shellTextFailedToClearLocalMobileShellState({required Object error}) =>
      'Не удалось очистить локальное состояние мобильной оболочки: ${error}';
  @override
  String shellTextProviderExpectsLinkEntryOnlyMobile({
    required Object providerName,
    required Object inputKind,
  }) =>
      '${providerName} ожидает ввод типа ${inputKind}. Эта мобильная оболочка сейчас поддерживает только ввод ссылки.';
  @override
  String shellTextResolutionUnavailableForPlatformTunnel({
    required Object modeLabel,
    required Object resolutionId,
    required Object stage,
    required Object message,
  }) =>
      'Нельзя запустить ${modeLabel}, потому что разрешение ${resolutionId} завершилось на этапе ${stage}: ${message}';
  @override
  String shellTextChallengeMustCompleteBeforeStarting({
    required Object modeLabel,
  }) =>
      'Завершите текущую проверку провайдера, прежде чем запускать ${modeLabel}.';
  @override
  String shellTextWaitForProviderResolutionBeforeStarting({
    required Object modeLabel,
  }) =>
      'Дождитесь завершения текущего разрешения провайдера, прежде чем запускать ${modeLabel}.';
  @override
  String shellTextStartedMobileResolutionForProvider({
    required Object resolutionId,
    required Object providerName,
  }) => 'Мобильное разрешение ${resolutionId} для ${providerName} запущено.';
  @override
  String shellTextStartedMobileResolutionForProviderWithExternalBrowser({
    required Object resolutionId,
    required Object providerName,
  }) =>
      'Мобильное разрешение ${resolutionId} для ${providerName} запущено. Ожидайте шаг во внешнем браузере, если он требуется провайдеру.';
  @override
  String shellTextStartedMobileResolutionForProviderWithBrowserContinuation({
    required Object resolutionId,
    required Object providerName,
  }) =>
      'Мобильное разрешение ${resolutionId} для ${providerName} запущено. Завершите возможное продолжение в браузере, прежде чем ожидать готовый артефакт.';
  @override
  String shellTextResolutionStartedThenCompleteChallengeBeforeStarting({
    required Object startedNotice,
    required Object modeLabel,
  }) =>
      '${startedNotice} Завершите текущую проверку провайдера, прежде чем запускать ${modeLabel}.';
  @override
  String shellTextReceivedPortableProfileForReview({
    required Object profileLabel,
  }) =>
      'Получен переносимый профиль ${profileLabel}. Просмотрите его перед импортом.';
  @override
  String shellTextReceivedSecretBearingPortableProfileForReview({
    required Object profileLabel,
  }) =>
      'Получен переносимый профиль с секретами ${profileLabel}. Просмотрите его перед импортом.';
  @override
  String shellTextConnectedToMobileHostBridge({required Object baseUri}) =>
      'Подключено к мосту мобильного хоста ${baseUri}';
  @override
  String get shellTextChallengeHasNoBrowserHandoffUrl =>
      'Эта проверка не предоставляет URL для передачи в браузер.';
  @override
  String shellTextOpenedMobileBrowserHandoff({required Object challengeKind}) =>
      'Открыт переход в мобильный браузер для ${challengeKind}. Вернитесь сюда после шага в браузере.';
  @override
  String get shellTextFailedToOpenMobileBrowserHandoffUrl =>
      'Не удалось открыть URL передачи в мобильный браузер.';
  @override
  String shellTextPlatformTunnelDisconnected({required Object modeLabel}) =>
      '${modeLabel} отключен.';
  @override
  String shellTextSelectAtLeastOneIncludedApp({required Object modeLabel}) =>
      'Выберите хотя бы одно приложение перед запуском ${modeLabel} в режиме включенных приложений.';
  @override
  String shellTextSelectAtLeastOneExcludedApp({required Object modeLabel}) =>
      'Выберите хотя бы одно приложение перед запуском ${modeLabel} в режиме исключенных приложений.';
  @override
  String get shellTextSelectedMobileModeNotAdvertisedByConnectedHost =>
      'Выбранный мобильный режим не объявлен подключенным хостом.';
  @override
  String shellTextModeDoesNotAdvertiseSupportedExecutionPath({
    required Object modeLabel,
  }) => '${modeLabel} пока не объявляет поддерживаемый путь выполнения.';
  @override
  String shellTextSelectExecutionPathBeforeStarting({
    required Object modeLabel,
  }) => 'Выберите путь выполнения перед запуском ${modeLabel}.';
  @override
  String get shellTextResetLocalMobileShellStateBeforeReconnecting =>
      'Сбросьте локальное состояние мобильной оболочки перед переподключением.';
  @override
  String shellTextDetectedBrowserReturnAndContinuedChallenge({
    required Object signalLabel,
    required Object challengeId,
  }) =>
      'Обнаружен сигнал "${signalLabel}", и проверка ${challengeId} продолжена.';
  @override
  String shellTextCompletedInAppBrowserContinuation({
    required Object challengeId,
  }) =>
      'Продолжение во встроенном браузере для проверки ${challengeId} завершено.';
  @override
  String get shellTextResetLocalMobileShellStateBeforeRuntimeControlContinue =>
      'Сбросьте локальное состояние мобильной оболочки, прежде чем управление рантаймом сможет продолжиться.';
  @override
  String get shellTextAppLinkBrowserReturn => 'возврат из браузера по app-link';
  @override
  String get shellTextUniversalLinkBrowserReturn =>
      'возврат из браузера по universal-link';
  @override
  String get shellTextBrowserReturnOnAppResume =>
      'возврат из браузера при возобновлении приложения';
  @override
  String get shellTextBrowserReturn => 'возврат из браузера';
  @override
  String get shellTextMobileHostBridgeNotReady =>
      'Мост мобильного хоста не готов.';
  @override
  String get shellTextNativeMobileHostBridgeDidNotReturnHostConfiguration =>
      'Нативный мост мобильного хоста не вернул конфигурацию хоста.';
  @override
  String get shellTextNativeMobileHostBridgeReturnedEmptyHostUrl =>
      'Нативный мост мобильного хоста вернул пустой URL хоста.';
  @override
  String shellTextNativeMobileHostBridgeReturnedInvalidHostUrl({
    required Object baseUrl,
  }) =>
      'Нативный мост мобильного хоста вернул некорректный URL хоста: ${baseUrl}';
  @override
  String get shellTextNativeMobileHostBridgePluginUnavailable =>
      'Плагин нативного моста мобильного хоста недоступен.';
  @override
  String shellTextFailedToResolveMobileHostBridgeFromNativePlatform({
    required Object details,
  }) =>
      'Не удалось определить мост мобильного хоста через нативную платформу: ${details}';
  @override
  String
  get shellTextNativeMobileHostBridgePluginUnavailableForPermissionRequests =>
      'Плагин нативного моста мобильного хоста недоступен для запросов разрешения на платформенный туннель.';
  @override
  String shellTextFailedToRequestNativePlatformTunnelPermission({
    required Object details,
  }) =>
      'Не удалось запросить разрешение на платформенный туннель у нативной платформы: ${details}';
  @override
  String get shellTextNativeMobileHostBridgeReturnedNoWebViewSnapshot =>
      'Нативный мост мобильного хоста не вернул снимок WebView.';
  @override
  String shellTextFailedToInspectNativeWebView({required Object details}) =>
      'Не удалось проинспектировать нативный WebView: ${details}';
  @override
  String get shellTextVktpMobileHostUrlInvalid =>
      'VKTP_MOBILE_HOST_URL не является корректным URI для моста мобильного хоста.';
  @override
  String get shellTextNativeMobileHostBridgeDidNotProvideControlPlaneEndpoint =>
      'Нативный мост мобильного хоста не предоставил endpoint control plane.';
  @override
  String get shellTextMobileHostBridgeNotConfigured =>
      'Мост мобильного хоста не настроен. Упакуйте совместимый loopback host или задайте VKTP_MOBILE_HOST_URL для разработки.';
  @override
  String
  get shellTextNativeMobileHostBridgePluginUnavailableForInstalledAppInventory =>
      'Плагин нативного моста мобильного хоста недоступен для инвентаря установленных приложений.';
  @override
  String shellTextFailedToListInstalledAppsFromNativePlatform({
    required Object details,
  }) =>
      'Не удалось получить список установленных приложений от нативной платформы: ${details}';
  @override
  String shellTextFailedToRestoreMobileShellState({required Object error}) =>
      'Не удалось восстановить состояние мобильной оболочки: ${error}';
  @override
  String get shellTextProviderDidNotReturnStartableArtifact =>
      'Провайдер не вернул артефакт, пригодный для запуска.';
  @override
  String shellTextLoopbackPeerBlockReason({
    required Object modeLabel,
    required Object peerAddress,
  }) =>
      '${modeLabel} все еще указывает на loopback peer ${peerAddress}. Настройте оператором управляемый удаленный peer endpoint перед запуском мобильного VPN-пути.';
  @override
  String get shellTextSecureProfileSecretsUnavailable =>
      'Защищенные секреты профилей недоступны. Восстановите secure storage или очистите сохраненное состояние мобильной оболочки.';
  @override
  String shellTextSecureProfileSecretsMissing({required Object profileId}) =>
      'Защищенные секреты отсутствуют для сохраненного профиля ${profileId}.';
  @override
  String get shellTextSecureDraftSecretsUnavailable =>
      'Защищенные секреты черновика недоступны. Восстановите secure storage или сбросьте черновик.';
  @override
  String shellTextResolutionStartedThenWaitForFinishBeforeStarting({
    required Object startedNotice,
    required Object modeLabel,
  }) =>
      '${startedNotice} Дождитесь завершения разрешения, прежде чем запускать ${modeLabel}.';
  @override
  String get shellTextNoReusableFieldsYet => 'Переиспользуемых полей пока нет';
  @override
  String get shellTextSchemaBlockedInShell =>
      'Схема заблокирована в этой оболочке';
  @override
  String get shellTextReusableFieldsReady => 'Переиспользуемые поля готовы';
  @override
  String get shellTextProviderInput => 'Ввод провайдера';
  @override
  String get shellTextProviderLink => 'Ссылка провайдера';
  @override
  String get shellTextProviderFamily => 'Семейство провайдера';
  @override
  String get shellTextProviderType => 'Тип провайдера';
  @override
  String get shellTextProfileName => 'Имя профиля';
  @override
  String get shellTextLocalUdpListen => 'Локальный UDP-адрес';
  @override
  String get shellTextPeerAddress => 'Адрес удаленного узла';
  @override
  String get shellTextConnections => 'Соединения';
  @override
  String get shellTextTurnMode => 'Режим TURN';
  @override
  String get shellTextTurnOverride => 'Переопределение TURN';
  @override
  String get shellTextTurnPort => 'Порт TURN';
  @override
  String get shellTextBindInterface => 'Интерфейс привязки';
  @override
  String get shellTextLogLevel => 'Уровень логов';
  @override
  String get shellTextDtlsEnabled => 'DTLS включен';
  @override
  String get shellTextResolveInvite => 'Разрешить инвайт';
  @override
  String get shellTextResolveProfile => 'Разрешить профиль';
  @override
  String get shellTextNotSet => 'Не задано';
  @override
  String get shellTextStartSession => 'Запустить сессию';
  @override
  String get shellTextSaveProfile => 'Сохранить профиль';
  @override
  String get shellTextDeleteProfile => 'Удалить профиль';
  @override
  String get shellTextFreshDraft => 'Новый черновик';
  @override
  String get shellTextStartSavedProfile => 'Запустить сохраненный профиль';
  @override
  String get shellTextExportPortableProfile =>
      'Экспортировать переносимый профиль';
  @override
  String get shellTextImportPortableProfile =>
      'Импортировать переносимый профиль';
  @override
  String get shellTextPastePortableProfileEnvelope =>
      'Вставить конверт переносимого профиля';
  @override
  String get shellTextPreviewOpensBeforeRecordsCreated =>
      'Предпросмотр открывается до создания любых локальных записей.';
  @override
  String get shellTextPayloadInvalidOrUnsupported =>
      'Payload невалиден или не поддерживается.';
  @override
  String shellTextProviderAndSource({
    required Object provider,
    required Object source,
  }) => 'Провайдер: ${provider} · Источник: ${source}';
  @override
  String shellTextProviderLabel({required Object provider}) =>
      'Провайдер: ${provider}';
  @override
  String shellTextSourceModeLabel({required Object mode}) =>
      'Режим источника: ${mode}';
  @override
  String shellTextManagedProviderSnapshot({required Object name}) =>
      'Снимок управляемого провайдера: ${name}';
  @override
  String get shellTextPortableExportSecretWarningDesktop =>
      'Этот пакет содержит секреты. Относитесь к скопированному тексту, сохраненным файлам и QR-экрану как к учетным данным.';
  @override
  String get shellTextPortableExportSecretWarningMobile =>
      'Этот пакет содержит секреты. Относитесь к отправляемому тексту, файлам и QR-экрану как к учетным данным.';
  @override
  String get shellTextPortableExportSeparateFromRuntimeDesktop =>
      'Экспортированный пакет остается отдельным от обычного сохранения оболочки и экспорта пакета handoff рантайма.';
  @override
  String get shellTextPortableExportSeparateFromRuntimeMobile =>
      'Передача переносимого профиля остается отдельной от обычного сохранения оболочки и экспорта пакета handoff рантайма.';
  @override
  String get shellTextPortableQrCompactJson =>
      'QR использует тот же конверт в компактной форме JSON.';
  @override
  String shellTextPortableQrUnavailableDesktop({required Object bytes}) =>
      'QR недоступен, потому что пакет превышает поддерживаемый размер QR (${bytes} байт). Экспорт в файл и текст остаются доступны.';
  @override
  String shellTextPortableQrUnavailableMobile({required Object bytes}) =>
      'QR недоступен, потому что пакет превышает поддерживаемый размер QR (${bytes} байт). Отправка текста и файла остается доступной.';
  @override
  String get shellTextPortableImportSecretWarning =>
      'Этот импортируемый пакет содержит секреты. Подтверждайте только если источник доверенный.';
  @override
  String get shellTextPortableImportCreatesFreshIdsMobile =>
      'Импорт создает новые локальные идентификаторы и не запускает рантайм автоматически.';
  @override
  String get shellTextPortableImportCreatesFreshIdsDesktop =>
      'Импорт создает новые локальные записи с новыми идентификаторами и не запускает рантайм автоматически.';
  @override
  String get shellTextScanPortableProfileQr =>
      'Сканировать QR переносимого профиля';
  @override
  String get shellTextPointCameraAtPortableProfileQr =>
      'Наведите камеру на QR-код переносимого профиля.';
  @override
  String shellTextTagInput({required Object value}) => 'Ввод: ${value}';
  @override
  String shellTextTagAuth({required Object value}) => 'Авторизация: ${value}';
  @override
  String shellTextTagBrowser({required Object value}) => 'Браузер: ${value}';
  @override
  String shellTextTagFamily({required Object value}) => 'Семейство: ${value}';
  @override
  String get shellTextBrowserNeedsExternal =>
      'Этот провайдер требует внешний браузер, когда появляется продолжение проверки.';
  @override
  String get shellTextBrowserAllowsEmbedded =>
      'Этот провайдер разрешает встроенный браузер, но хост все равно решает, появится ли браузерная проверка.';
  @override
  String get shellTextBrowserNotRequired =>
      'Этот провайдер не сообщает о требуемом браузерном интерфейсе.';
  @override
  String get shellTextBrowserContinuationMayAppear =>
      'Для этого провайдера может появиться продолжение в браузере.';
  @override
  String get shellTextBrowserContinuationNotAdvertised =>
      'Для этого провайдера сейчас не объявлен режим браузерной проверки.';
  @override
  String get shellTextDesktopProfileWorkspaceTitle =>
      'Рабочее пространство профиля';
  @override
  String get shellTextDesktopUnsavedDraft => 'Несохраненный черновик';
  @override
  String get shellTextDesktopSavedProfileWorkspace =>
      'Рабочее пространство сохраненного профиля';
  @override
  String get shellTextDesktopSaveProfileFirst => 'Сначала сохраните профиль';
  @override
  String get shellTextDesktopStartSessionFromSavedProfile =>
      'Запустить сессию из этого сохраненного профиля';
  @override
  String get shellTextDesktopProfileSettings => 'Настройки профиля';
  @override
  String get shellTextDesktopChangeSource => 'Сменить источник';
  @override
  String get shellTextDesktopChangeSourceSubtitle =>
      'Переключайтесь между сохраненной записью провайдера и вводом, принадлежащим черновику, только когда профилю нужен другой источник.';
  @override
  String get shellTextDesktopRuntimeDefaults =>
      'Параметры runtime по умолчанию';
  @override
  String get shellTextDesktopRuntimeDefaultsSubtitle =>
      'Эти поля применяются, когда профиль запускается на этом устройстве.';
  @override
  String get shellTextDesktopProfileMaintenance => 'Обслуживание профиля';
  @override
  String get shellTextDesktopProfileMaintenanceSubtitle =>
      'Держите разрушительные действия вне основного потока редактирования.';
  @override
  String get shellTextDesktopShowMaintenanceActions =>
      'Показать действия обслуживания';
  @override
  String get shellTextDesktopDeleteSavedProfileHint =>
      'Удалите сохраненный профиль, не загромождая строку действий.';
  @override
  String get shellTextDesktopPortableTransferSubtitle =>
      'Экспортируйте выбранный сохраненный профиль как явный конверт переноса или просмотрите импорт до создания локальных записей.';
  @override
  String get shellTextDesktopBrowserHandling => 'Работа с браузером';
  @override
  String get shellTextDesktopBrowserHandlingSubtitle =>
      'Показывайте этот контекст только тогда, когда провайдер может передать управление в браузерную проверку.';
  @override
  String get shellTextDesktopProfileProviderSettings =>
      'Настройки провайдера профиля';
  @override
  String shellTextDesktopProviderSettingsSupportError({
    required Object providerName,
    required Object error,
  }) =>
      'Эта настольная оболочка не может отрисовать схему настроек провайдера для ${providerName}: ${error}. Сохранение и разрешение остаются заблокированы, пока хост не объявит поддерживаемое подмножество схемы.';
  @override
  String get shellTextDesktopProfileProviderSettingsHelp =>
      'Сохраненные настройки профиля для выбранного провайдера. Значения только для запроса остаются только в активном черновике.';
  @override
  String get shellTextDesktopNoSavedProviderRecords =>
      'Сохраненных записей провайдеров пока нет.';
  @override
  String get shellTextDirectInput => 'Прямой ввод';
  @override
  String get shellTextSavedRecord => 'Сохраненная запись';
  @override
  String get shellTextDesktopSavedRecordAttached =>
      'К этому черновику прикреплена сохраненная запись провайдера.';
  @override
  String get shellTextDesktopDraftOwnsProviderInput =>
      'Этот черновик хранит собственный ввод провайдера.';
  @override
  String get shellTextMobileProfilesTitleBar => 'Профили';
  @override
  String get shellTextMobileProviderDetails => 'Детали провайдера';
  @override
  String get shellTextMobileProviderDetailsSubtitle =>
      'Политика браузера, семейства артефактов и подсказки по проверке';
  @override
  String get shellTextMobileProviderSettingsSection => 'Настройки провайдера';
  @override
  String get shellTextMobilePortableTransfer => 'Переносимый профиль';
  @override
  String get shellTextMobileProviderSettingsUnsupportedSubtitle =>
      'Неподдерживаемое подмножество схемы блокирует сохранение и разрешение';
  @override
  String get shellTextMobileProviderSettingsRetainedSubtitle =>
      'Обязательные и сохраняемые значения, специфичные для провайдера';
  @override
  String get shellTextMobileAdvancedRuntimeControls =>
      'Расширенные настройки рантайма';
  @override
  String get shellTextMobileAdvancedRuntimeControlsSubtitle =>
      'Переопределения транспорта, локальная привязка и логирование';
  @override
  String get shellTextMobilePortableTransferSubtitle =>
      'Экспортируйте выбранный сохраненный профиль через явный конверт или просмотрите импорт до создания локальных записей.';
  @override
  String shellTextMobileProviderSettingsSupportError({
    required Object providerName,
    required Object error,
  }) =>
      'Эта мобильная оболочка не может отрисовать схему настроек провайдера для ${providerName}: ${error}. Сохранение и разрешение остаются заблокированы, пока хост не объявит поддерживаемое подмножество схемы.';
  @override
  String get shellTextMobileProviderSettingsRetainedHelp =>
      'Настройки, сохраняемые вместе с профилем, остаются в сохраненном профиле. Значения только для запроса остаются только в памяти черновика для немедленного запуска разрешения.';
  @override
  String get shellTextMobileNoSavedProfilesYetBuildDraft =>
      'Сохраненных профилей пока нет. Соберите черновик ниже и сохраните его для повторных запусков.';
  @override
  String get shellTextMobileSavedProfiles => 'Сохраненные профили';
  @override
  String get shellTextMobileProviderMode => 'Режим провайдера';
  @override
  String get shellTextMobileProviderModeNoManagedProviders =>
      'Управляемые провайдеры пока недоступны. Используйте пользовательский режим для прямого ввода провайдера или сначала создайте запись провайдера из библиотеки рабочих процессов.';
  @override
  String get shellTextCustomProvider => 'Свой провайдер';
  @override
  String get shellTextManagedProvider => 'Управляемый провайдер';
  @override
  String get shellTextMobileManagedModeSummary =>
      'Управляемый режим копирует значения из сохраненной записи провайдера, а дальнейшие изменения профиля оставляет локальными для этого черновика.';
  @override
  String get shellTextMobileCustomModeSummary =>
      'Пользовательский режим позволяет ввести исходный идентификатор провайдера и значения только для запроса без изменения каталога управляемых провайдеров.';
  @override
  String get shellTextMobileManagedProviderDropdown => 'Управляемый провайдер';
  @override
  String get shellTextMobileEditProvider => 'Редактировать провайдера';
  @override
  String get shellTextMobileNewProvider => 'Новый провайдер';
  @override
  String get shellTextMobileEditSavedReusableProvider =>
      'Редактируйте этот сохраненный переиспользуемый провайдер.';
  @override
  String get shellTextMobileFinishSavedReusableProvider =>
      'Завершите этот сохраненный переиспользуемый провайдер для дальнейшего использования в Профилях.';
  @override
  String get shellTextMobileCloseProviderEditor =>
      'Закрыть редактор провайдера';
  @override
  String get shellTextMobileNoShippedProviderFamilies =>
      'Эта сборка пока не объявляет ни одного встроенного семейства провайдеров.';
  @override
  String get shellTextMobileProviderName => 'Имя провайдера';
  @override
  String get shellTextMobileProviderShownInProfiles =>
      'Показывается в Профилях при выборе сохраненного переиспользуемого провайдера.';
  @override
  String get shellTextMobileProviderTypeChosenWhenCreated =>
      'Выбирается при создании этого сохраненного провайдера. Используйте эту панель, чтобы задать имя и просмотреть переиспользуемые настройки.';
  @override
  String shellTextMobileProviderConfigSupportError({
    required Object providerName,
    required Object error,
  }) =>
      'Эта мобильная оболочка не может отрисовать схему настроек провайдера для ${providerName}: ${error}. Сохранение остается заблокированным, пока хост не объявит поддерживаемое подмножество схемы.';
  @override
  String get shellTextMobileReusableProviderSettings =>
      'Переиспользуемые настройки провайдера';
  @override
  String get shellTextMobileReusableValuesAppliedToProfile =>
      'Эти переиспользуемые значения применяются, когда этот провайдер используется в профиле.';
  @override
  String get shellTextMobileSaveProvider => 'Сохранить провайдера';
  @override
  String get shellTextMobileSaveAsTemplate => 'Сохранить как шаблон';
  @override
  String get shellTextMobileUseInProfileDraft =>
      'Использовать в черновике профиля';
  @override
  String get shellTextMobileDeleteProvider => 'Удалить провайдера';
  @override
  String get shellTextSelectedType => 'Выбранный тип';
  @override
  String get shellTextMobileEditTemplate => 'Редактировать шаблон';
  @override
  String get shellTextMobileNewTemplate => 'Новый шаблон';
  @override
  String get shellTextMobileEditTemplateStartingValues =>
      'Редактируйте стартовые значения для будущих провайдеров.';
  @override
  String get shellTextMobileSaveTemplateStartingPoint =>
      'Сохраните стартовую точку для будущих провайдеров.';
  @override
  String get shellTextMobileCloseTemplateEditor => 'Закрыть редактор шаблона';
  @override
  String get shellTextMobileTemplateName => 'Имя шаблона';
  @override
  String get shellTextMobileTemplateShownWhenChoosing =>
      'Показывается при выборе стартовой точки для новых провайдеров.';
  @override
  String get shellTextMobileTemplateTypeChosenWhenCreated =>
      'Выбирается при создании этого шаблона. Используйте эту панель, чтобы задать имя и просмотреть переиспользуемые стартовые значения.';
  @override
  String get shellTextMobileReusableValuesPrefillProvider =>
      'Эти значения предзаполняют нового провайдера при использовании шаблона.';
  @override
  String get shellTextMobileSaveTemplate => 'Сохранить шаблон';
  @override
  String get shellTextMobileUseTemplate => 'Использовать шаблон';
  @override
  String get shellTextMobileDeleteTemplate => 'Удалить шаблон';
  @override
  String get shellTextDesktopProviderRecord => 'Запись провайдера';
  @override
  String get shellTextDesktopNewProviderRecord => 'Новая запись провайдера';
  @override
  String get shellTextDesktopEditReusableProviderRecord =>
      'Редактируйте одну переиспользуемую запись провайдера. Прикрепленное семейство показано ниже и остается здесь только для чтения.';
  @override
  String get shellTextDesktopCreateReusableProviderRecord =>
      'Создайте одну переиспользуемую запись провайдера. Отдельно выберите семейство, затем редактируйте параметры записи ниже.';
  @override
  String get shellTextDesktopRecordParameters => 'Параметры записи';
  @override
  String shellTextDesktopParametersFor({required Object providerTitle}) =>
      'Параметры для ${providerTitle}';
  @override
  String get shellTextDesktopChooseProviderFamilyFirst =>
      'Сначала выберите семейство провайдера в отдельном списке. После этого здесь появятся параметры записи.';
  @override
  String shellTextDesktopEditReusableParametersFor({
    required Object providerTitle,
  }) =>
      'Редактируйте переиспользуемые параметры, сохраненные в этой записи для ${providerTitle}. Это не меняет само семейство.';
  @override
  String get shellTextDesktopUseInProfileDraft =>
      'Использовать в черновике профиля';
  @override
  String get shellTextDesktopNewRecord => 'Новая запись';
  @override
  String get shellTextDesktopRecordName => 'Имя записи';
  @override
  String get shellTextDesktopRecordNameHelp =>
      'Сначала задайте имя этой сохраненной записи провайдера. Выбор семейства и параметры записи находятся ниже.';
  @override
  String get shellTextDesktopAttachedFamily => 'Прикрепленное семейство';
  @override
  String get shellTextDesktopAttachedFamilyHelp =>
      'Семейства выбираются в отдельном списке. Выбранное семейство прикрепляется к этой записи и описывается здесь.';
  @override
  String get shellTextDesktopFamilyCharacteristics =>
      'Характеристики семейства';
  @override
  String get shellTextDesktopFamilyCharacteristicsHelp =>
      'Характеристики только для чтения из выбранного семейства и текущего хост-оверлея.';
  @override
  String shellTextDesktopProviderRecordSupportError({
    required Object providerName,
    required Object error,
  }) =>
      'Эта настольная оболочка не может отрисовать схему настроек провайдера для ${providerName}: ${error}. Сохранение остается заблокированным, пока хост не объявит поддерживаемое подмножество схемы.';
  @override
  String get shellTextDesktopNoFamilyAttachedYet =>
      'Семейство пока не прикреплено';
  @override
  String get shellTextDesktopSelectedFamily => 'Выбранное семейство';
  @override
  String get shellTextDesktopOpenFamilyChooserFirst =>
      'Откройте отдельный список семейств, прежде чем продолжить работу с этой записью провайдера.';
  @override
  String shellTextDesktopFamilyAttachedToRecord({
    required Object providerTitle,
  }) =>
      '${providerTitle} прикреплено к этой записи, пока вы намеренно не измените его в списке семейств.';
  @override
  String get shellTextDesktopShippedByApp => 'Поставляется приложением';
  @override
  String get shellTextDesktopHostOverlayAvailable => 'Host overlay: доступен';
  @override
  String get shellTextDesktopHostOverlayUnavailable =>
      'Host overlay: недоступен';
  @override
  String get shellTextDesktopUseActionStripToChooseFamily =>
      'Используйте панель действий выше, чтобы выбрать семейство. Здесь семейства только для чтения.';
  @override
  String get shellTextDesktopFamiliesReadonlyEditBelow =>
      'Здесь семейства остаются только для чтения. Меняйте прикрепленное семейство через панель действий выше, а параметры этой записи редактируйте ниже.';
  @override
  String get shellTextDesktopChooseFamily => 'Выбрать семейство';
  @override
  String get shellTextDesktopSaveDraft => 'Сохранить черновик';
  @override
  String get shellTextDesktopSaveRecord => 'Сохранить запись';
  @override
  String get shellTextDesktopReadOnlyFamily => 'Семейство только для чтения';
  @override
  String get shellTextDesktopAttachedFamilyCardHelp =>
      'Эта карточка описывает прикрепленное семейство. Ниже показаны редактируемые параметры записи.';
  @override
  String get shellTextDesktopNoEditableParametersYet =>
      'Редактируемых параметров пока нет';
  @override
  String get shellTextDesktopNoEditableParameters =>
      'Редактируемых параметров нет';
  @override
  String get shellTextDesktopEditableParametersReady =>
      'Редактируемые параметры готовы';
  @override
  String get shellTextDesktopNoSavedProfilesYetShort =>
      'Сохраненных профилей пока нет.';
  @override
  String get shellTextDesktopNoShippedProviderFamilies =>
      'Эта сборка пока не объявляет ни одного встроенного семейства провайдеров.';
  @override
  String shellTextDesktopNoEditableRecordParameters({
    required Object providerTitle,
  }) =>
      '${providerTitle} не имеет редактируемых параметров записи в этой настольной оболочке.';
  @override
  String get shellTextDesktopSavedProfilesLibraryTitle => 'Сохраненные профили';
  @override
  String get shellTextDesktopSavedProfilesLibrarySubtitle =>
      'Осознанно просматривайте сохраненные рабочие пространства оператора, а затем возвращайтесь в активный редактор, не оставляя основной путь навсегда разделенным.';
  @override
  String get shellTextDesktopReturnPathExplicitTitle =>
      'Путь возврата остается явным';
  @override
  String get shellTextDesktopReturnPathExplicitMessage =>
      'Выбор сохраненного профиля обновляет активный рабочий процесс и закрывает эту вторичную поверхность.';
  @override
  String get shellTextDesktopProviderRecordsLibraryTitle =>
      'Записи провайдеров';
  @override
  String get shellTextDesktopProviderRecordsLibrarySubtitle =>
      'Создайте переиспользуемую запись провайдера или откройте уже сохраненную.';
  @override
  String get shellTextDesktopRecordsSeparateFromFamiliesTitle =>
      'Записи отделены от семейств';
  @override
  String get shellTextDesktopRecordsSeparateFromFamiliesMessage =>
      'Создайте здесь запись, затем выберите ее семейство в отдельном списке семейств. Откройте существующую запись, чтобы продолжить ее редактирование.';
  @override
  String get shellTextDesktopNoProviderRecordsYet =>
      'Записей провайдеров пока нет. Создайте запись, чтобы выбрать семейство и сохранить переиспользуемые параметры.';
  @override
  String get shellTextDesktopNewFromPresetSubtitle =>
      'Начинайте с подготовленной заготовки провайдера только когда намеренно этого хотите.';
  @override
  String get shellTextDesktopPresetBootstrapExplicitTitle =>
      'Запуск из пресета остается явным';
  @override
  String get shellTextDesktopPresetBootstrapExplicitMessage =>
      'Недоступные пресеты остаются здесь видимыми и честными, но больше не занимают рабочее пространство провайдера по умолчанию.';
  @override
  String get shellTextDesktopProviderFamiliesSubtitle =>
      'Выберите здесь поставляемое семейство, затем вернитесь в редактор записи провайдера.';
  @override
  String get shellTextDesktopFamiliesReadonlyHereTitle =>
      'Здесь семейства только для чтения';
  @override
  String get shellTextDesktopFamiliesReadonlyHereMessage =>
      'Этот список принадлежит встроенной оболочке. Выберите здесь семейство, затем редактируйте выбранную запись в редакторе записи.';
  @override
  String get shellTextDesktopUsePreset => 'Использовать пресет';
  @override
  String get shellTextLaunched => 'запущен';
  @override
  String get shellTextDesktopSavedProfilesRouteDetail =>
      'Выберите сохраненный профиль или вернитесь в активный редактор профиля, не теряя текущий черновик.';
  @override
  String get shellTextDesktopManagedRecordsTitle => 'Управляемые записи';
  @override
  String get shellTextDesktopManagedRecordsRouteDetail =>
      'Выберите переиспользуемую управляемую запись для активного черновика профиля или вернитесь без изменения черновика.';
  @override
  String get shellTextDesktopProviderRecordsRouteDetail =>
      'Создайте здесь запись провайдера или заново откройте существующую для редактирования. Семейства остаются в отдельном списке выбора.';
  @override
  String get shellTextDesktopPresetBootstrapTitle => 'Запуск из пресета';
  @override
  String get shellTextDesktopPresetBootstrapRouteDetail =>
      'Запустите рабочий процесс провайдера из подготовленного пресета, затем вернитесь в маршрут редактора управляемого провайдера.';
  @override
  String get shellTextDesktopProviderFamiliesRouteDetail =>
      'Выберите здесь встроенное семейство только для чтения, затем вернитесь в редактор записи провайдера.';
  @override
  String get shellTextDesktopWorkflowReadiness =>
      'Готовность рабочего процесса';
  @override
  String shellTextDesktopTunnelModesReadySummary({
    required Object ready,
    required Object total,
  }) => '${ready}/${total} туннельных режимов готовы';
  @override
  String get shellTextDesktopPlatformTunnelSummary =>
      'Сводка платформенных туннельных режимов';
  @override
  String shellTextDesktopResolutionsSessionsCompact({
    required Object resolutions,
    required Object sessions,
  }) => '${resolutions} резолюций · ${sessions} сессий';
  @override
  String get shellTextDesktopSupportContextPinned =>
      'Контекст поддержки закреплен';
  @override
  String get shellTextDesktopSupportAttentionRequired =>
      'Требуется внимание поддержки';
  @override
  String get shellTextDesktopSupportContextWarmingUp =>
      'Контекст поддержки прогревается';
  @override
  String get shellTextDesktopLiveWorkActive => 'Текущая работа активна';
  @override
  String get shellTextDesktopSupportNote => 'Заметка поддержки';
  @override
  String get shellTextDesktopSupportBlockedDetail =>
      'Локальный хост заблокирован или несовместим. Держите путь восстановления видимым из основного рабочего процесса.';
  @override
  String get shellTextDesktopSupportBootingDetail =>
      'Согласование с хостом все еще идет. Диагностика остается в одном действии, не перехватывая всю оболочку.';
  @override
  String get shellTextDesktopSupportReadyLiveDetail =>
      'Используйте Текущую работу, чтобы просмотреть текущий рантайм, не позволяя поверхности поддержки перехватывать всю оболочку.';
  @override
  String get shellTextDesktopSupportReadyIdleDetail =>
      'Используйте Диагностику или Текущую работу, когда нужна более глубокая проверка. Основной рабочий процесс остается главным.';
  @override
  String get shellTextDesktopInspector => 'Инспектор';
  @override
  String get shellTextDesktopInspectorDiagnosticsSubtitle =>
      'Диагностика и детали платформенного туннеля остаются вторичными по отношению к основному рабочему полотну.';
  @override
  String get shellTextDesktopInspectorActivitySubtitle =>
      'Текущие резолюции и сессии остаются доступными по запросу, не перехватывая всю оболочку.';
  @override
  String get shellTextDesktopTunnelDetail => 'Детали туннеля';
  @override
  String get shellTextDesktopPlatformTunnelModes =>
      'Платформенные туннельные режимы';
  @override
  String get shellTextDesktopFailClosedCompactUntilStartup =>
      'Проверки платформенного туннеля в fail-closed режиме остаются свернутыми, пока вы явно не проверите запуск.';
  @override
  String get shellTextDesktopFailClosedSectionCompactUntilStartup =>
      'Подключенный хост сообщает только о платформенных туннельных режимах в fail-closed состоянии, поэтому этот раздел остается компактным, пока вы явно не проверите запуск.';
  @override
  String get shellTextDesktopTypedHostTunnelSummary =>
      'Настольная оболочка читает типизированные возможности туннеля и этапы запуска от хоста, а не угадывает поддержку системной маршрутизации по ОС или пакету приложения.';
  @override
  String get shellTextDesktopNoPlatformTunnelModesReported =>
      'Подключенный хост не сообщил ни о каких платформенных туннельных режимах рабочего стола.';
  @override
  String get shellTextDesktopUseDiagnosticsForReportedModes =>
      'Используйте Диагностика -> Детали туннеля, чтобы просмотреть этапы запуска и fail-closed результаты для объявленных режимов.';
  @override
  String get shellTextDesktopAllModesFailClosedLatestEvidence =>
      'Все объявленные туннельные режимы все еще остаются fail-closed; откройте Диагностика -> Детали туннеля для просмотра последних данных о запуске.';
  @override
  String get shellTextDesktopAllModesFailClosedTestStartup =>
      'Все объявленные туннельные режимы сейчас находятся в fail-closed состоянии. Используйте Диагностика -> Детали туннеля, когда захотите явно проверить запуск.';
  @override
  String get shellTextDesktopHostModeAvailable =>
      'Хост сообщает, что этот режим доступен.';
  @override
  String get shellTextDesktopHostModeUnavailable =>
      'Хост сообщает, что этот режим недоступен.';
  @override
  String get shellTextDesktopNoStartupRequestYet =>
      'Запроса на запуск пока нет. Используйте типизированный контракт хоста, чтобы проверить fail-closed сценарий.';
  @override
  String get shellTextDesktopNoSessionsYet =>
      'Активных или недавних сессий пока нет.';
  @override
  String get shellTextDesktopEventStreamSubtitle =>
      'Типизированные переходы состояний и обновления проверок из /v1/events.';
  @override
  String get shellTextDesktopWorkflowAssuranceBooting =>
      'Оболочка переподключается к локальному хосту. Сохраняйте поверхность редактора стабильной, пока согласование не завершится.';
  @override
  String get shellTextDesktopWorkflowAssuranceBlocked =>
      'Локальный хост заблокирован или несовместим. Держите путь восстановления видимым из основной рабочей поверхности.';
  @override
  String get shellTextDesktopWorkflowAssuranceReadyLive =>
      'Локальный хост готов. Сохраняйте текущий рабочий процесс главным, пока детали живого рантайма остаются в одном шаге.';
  @override
  String get shellTextDesktopWorkflowAssuranceReadyIdle =>
      'Локальный хост готов. Рутинная поддержка остается компактной, чтобы активный рабочий процесс сохранял визуальный приоритет.';
  @override
  String get shellTextContinueAfterBrowserStep =>
      'Продолжить после шага в браузере';
  @override
  String get shellTextContinueInBrowser => 'Продолжить в браузере';
  @override
  String shellTextProviderFamilyLabel({required Object familyTitle}) =>
      'Семейство провайдера: ${familyTitle}';
  @override
  String get shellTextAppOwnedManagedRecord => 'Управляемая запись приложения';
  @override
  String get shellTextSelectedFamily => 'Выбранное семейство';
  @override
  String get shellTextMobileOpenBrowser => 'Открыть браузер';
  @override
  String get shellTextMobileContinueInApp => 'Продолжить в приложении';
  @override
  String shellTextChallengeContinuationCancelled({
    required Object challengeId,
  }) =>
      'Продолжение проверки ${challengeId} во встроенном браузере отменено, проверка помечена как отмененная.';
  @override
  String shellTextChallengeContinuationFailed({
    required Object challengeId,
    required Object error,
  }) =>
      'Продолжение проверки ${challengeId} во встроенном браузере завершилось ошибкой: ${error}. Проверка помечена как отмененная.';
  @override
  String get shellTextMobileEditProfile => 'Редактировать профиль';
  @override
  String get shellTextMobileSelectedForHome => 'Выбран для Главной';
  @override
  String get shellTextMobileTurnOnVpn => 'Включить VPN';
  @override
  String get shellTextMobileTurnOffVpn => 'Выключить VPN';
  @override
  String get shellTextMobileProvidersTitle => 'Провайдеры';
  @override
  String get shellTextMobileProvidersSubtitle =>
      'Выберите сохраненный переиспользуемый провайдер или добавьте новый для Профилей.';
  @override
  String get shellTextMobileAddProvider => 'Добавить провайдера';
  @override
  String get shellTextMobileBackToProviders => 'Назад к провайдерам';
  @override
  String get shellTextMobileNoProvider => 'Провайдер не выбран';
  @override
  String get shellTextMobileInputConfigured => 'ввод настроен';
  @override
  String get shellTextSupportTitle => 'Поддержка';
  @override
  String get shellTextSupportSubtitle =>
      'Активность, ошибки, логи и диагностика остаются явными, но вторичными по отношению к основному VPN-потоку.';
  @override
  String get shellTextRoutingTitle => 'Маршрутизация';
  @override
  String get shellTextRoutingSubtitle =>
      'Выберите профиль VPN и охват приложений.';
  @override
  String get shellTextRoutingProfile => 'Профиль маршрутизации';
  @override
  String get shellTextRoutingProfileStandard => 'Стандартный';
  @override
  String get shellTextRoutingProfileDevelopmentWifi => 'Development Wi-Fi';
  @override
  String get shellTextRoutingProfileStandardDescription =>
      'Использовать обычное поведение маршрутизации системного VPN Android для этого режима.';
  @override
  String get shellTextRoutingProfileDevelopmentWifiDescription =>
      'Сохранить активную локальную Wi-Fi сеть вне VPN, чтобы инструменты разработки оставались доступными, пока VPN активен.';
  @override
  String get shellTextAppScope => 'Охват приложений';
  @override
  String shellTextModeScope({required Object modeLabel}) =>
      '${modeLabel}: охват';
  @override
  String get shellTextAllApps => 'Все приложения';
  @override
  String get shellTextIncludedApps => 'Включенные приложения';
  @override
  String get shellTextExcludedApps => 'Исключенные приложения';
  @override
  String shellTextRoutingScopeSummary({
    required Object selectedCount,
    required Object totalCount,
  }) => 'Выбрано ${selectedCount} из ${totalCount} установленных приложений.';
  @override
  String get shellTextSearchApps => 'Поиск приложений';
  @override
  String shellTextRoutingVisibleAppsSummary({
    required Object visibleCount,
    required Object totalCount,
    required Object selectedCount,
  }) =>
      'На экране ${visibleCount} из ${totalCount}; выбрано ${selectedCount} видимых.';
  @override
  String get shellTextBulkActions => 'Действия';
  @override
  String get shellTextSelectVisibleApps => 'Выбрать видимые';
  @override
  String get shellTextClearVisibleApps => 'Снять видимые';
  @override
  String get shellTextAllInstalledAppsUseVpnPath =>
      'Все установленные приложения будут использовать системный VPN-путь Android для этого мобильного режима.';
  @override
  String get shellTextRetryAppScan => 'Повторить сканирование приложений';
  @override
  String get shellTextNoInstalledAppsReported =>
      'Android shell bridge не сообщил об установленных приложениях.';
  @override
  String get shellTextNoInstalledAppsMatchSearch =>
      'Для этого поиска нет совпадающих установленных приложений.';
  @override
  String get shellTextHomeNoSavedProfilesYet => 'Сохраненных профилей пока нет';
  @override
  String get shellTextHomeNoSavedProfilesMessage =>
      'Сначала создайте или импортируйте профиль, затем вернитесь сюда для быстрого переключения VPN.';
  @override
  String get shellTextCurrentProfile => 'Текущий профиль';
  @override
  String shellTextListeningOn({required Object address}) =>
      'Слушает на ${address}';
  @override
  String get shellTextCurrentMode => 'Текущий режим';
  @override
  String get shellTextNoMobileTunnelModeAdvertised =>
      'Подключенный хост пока не объявил мобильный туннельный режим.';
  @override
  String get shellTextExecutionPath => 'Путь выполнения';
  @override
  String get shellTextProviderStepTone => 'Шаг провайдера';
  @override
  String get shellTextConnectionLiveTone => 'Соединение активно';
  @override
  String get shellTextSetupNeededTone => 'Требуется настройка';
  @override
  String get shellTextMainActionTone => 'Главное действие';
  @override
  String get shellTextFinishProviderValidation =>
      'Завершите проверку провайдера';
  @override
  String get shellTextVpnIsOn => 'VPN включен';
  @override
  String get shellTextProfileRequired => 'Требуется профиль';
  @override
  String get shellTextVpnIsOff => 'VPN выключен';
  @override
  String get shellTextContinueProviderFlowInApp =>
      'Продолжите шаг провайдера во встроенном браузере, прежде чем VPN сможет запуститься.';
  @override
  String get shellTextOpenRequiredBrowserStepFromHome =>
      'Откройте обязательный шаг в браузере с Главной, затем вернитесь сюда и подтвердите завершение до запуска VPN.';
  @override
  String get shellTextDisconnectCurrentMobileVpnPath =>
      'Отсюда отключите текущий путь мобильного VPN.';
  @override
  String get shellTextChooseOrFinishProfileBeforeStartingVpn =>
      'Выберите или завершите профиль в Профилях перед запуском текущего пути мобильного VPN.';
  @override
  String get shellTextStartCurrentMobileVpnPath =>
      'Запустите текущий путь мобильного VPN отсюда.';
  @override
  String get shellTextContinueInProfiles => 'Продолжить в Профилях';
  @override
  String shellTextChallengeKind({required Object kind}) => 'Проверка: ${kind}';
  @override
  String get shellTextIveCompletedIt => 'Я завершил';
  @override
  String get shellTextCancelChallenge => 'Отменить проверку';
  @override
  String get shellTextNeedDeeperDetail => 'Нужна более глубокая детализация?';
  @override
  String shellTextResolutionsSessionsSummary({
    required Object resolutions,
    required Object sessions,
    required Object liveSummary,
  }) => 'Резолюции ${resolutions} · Сессии ${sessions} · ${liveSummary}';
  @override
  String get shellTextNoStartupRequestYetShort =>
      'Запроса на запуск пока не было.';
  @override
  String get shellTextRoutingUnavailableForMode =>
      'Маршрутизация недоступна для этого режима';
  @override
  String get shellTextRoutingUnavailableMessage =>
      'Только мобильные режимы с поддержкой маршрутизации по приложениям показывают эту поверхность. Выберите другой режим на Главной, если хост его объявляет.';
  @override
  String get shellTextNoSavedProvidersYet => 'Сохраненных провайдеров пока нет';
  @override
  String get shellTextNoSavedProvidersMessage =>
      'Добавьте провайдера, затем переиспользуйте его из Профилей.';
  @override
  String shellTextTypeLabel({required Object familyTitle}) =>
      'Тип: ${familyTitle}';
  @override
  String get shellTextUsedInProfiles => 'Используется в Профилях';
  @override
  String get shellTextCreateProvider => 'Создать провайдера';
  @override
  String get shellTextCreateProviderChooseType =>
      'Выберите тип провайдера и настройте нового сохраненного провайдера.';
  @override
  String get shellTextCreateProviderUseTemplate =>
      'Используйте шаблон для предзаполнения нового провайдера. Шаблоны - это стартовые точки, а не сохраненные провайдеры.';
  @override
  String get shellTextProviderTypes => 'Типы провайдеров';
  @override
  String get shellTextNoShippedProviderTypesYet =>
      'Эта сборка пока не объявляет никаких встроенных типов провайдеров.';
  @override
  String get shellTextSearchTemplates => 'Поиск шаблонов';
  @override
  String get shellTextMyTemplates => 'Мои шаблоны';
  @override
  String get shellTextNoSavedTemplatesYet =>
      'Сохраненных шаблонов пока нет. Сохраните провайдера как шаблон, чтобы переиспользовать его здесь.';
  @override
  String get shellTextNoSavedTemplatesMatchSearch =>
      'Нет сохраненных шаблонов, подходящих под текущий поиск.';
  @override
  String get shellTextPrefillsNewProviders => 'Предзаполняет новых провайдеров';
  @override
  String get shellTextShippedTemplates => 'Встроенные шаблоны';
  @override
  String get shellTextNoShippedTemplatesMatchSearch =>
      'Нет встроенных шаблонов, подходящих под текущий поиск.';
  @override
  String get shellTextStartingPointForNewProviders =>
      'Стартовая точка для новых провайдеров';
  @override
  String get shellTextReadOnlyShippedTemplate =>
      'Встроенный шаблон только для чтения';
  @override
  String get shellTextActivityPageSubtitle =>
      'Просматривайте резолюции провайдера и состояние сессий, не загромождая основной рабочий процесс.';
  @override
  String shellTextResolutionsCount({required Object count}) =>
      'Резолюции (${count})';
  @override
  String shellTextSessionsCount({required Object count}) => 'Сессии (${count})';
  @override
  String get shellTextDiagnosticsPageSubtitle =>
      'Подробная готовность хоста, детали платформенного туннеля и недавние типизированные события.';
  @override
  String shellTextEventsCount({required Object count}) => 'События (${count})';
  @override
  String get shellTextWaitingForMobileHostBridge =>
      'Ожидание согласования моста мобильного хоста.';
  @override
  String shellTextGuiBuildTag({required Object label}) => 'GUI ${label}';
  @override
  String shellTextHostBuildTag({required Object label}) => 'Host ${label}';
  @override
  String shellTextContractTag({required Object version}) =>
      'Контракт ${version}';
  @override
  String get shellTextReconnect => 'Переподключить';
  @override
  String get shellTextRefresh => 'Обновить';
  @override
  String get shellTextResolutionsTitle => 'Резолюции';
  @override
  String get shellTextResolutionsSubtitle =>
      'Сначала разрешите инвайт, затем используйте набор действий, ограниченный возможностями, чтобы запустить на этом устройстве, экспортировать handoff или открыть нативные цели провайдера.';
  @override
  String get shellTextNoProviderResolutionsYet =>
      'Резолюций провайдера пока нет.';
  @override
  String get shellTextSystemTunnelBannerText =>
      'Этот мобильный срез отображает типизированные возможности хоста и результаты этапов запуска для объявленных платформенных режимов. Используйте элементы управления ниже, чтобы запустить или отключить поддерживаемые пути системного туннеля.';
  @override
  String get shellTextNoPlatformTunnelModesReported =>
      'Подключенный мобильный хост не сообщил ни о каких платформенных туннельных режимах.';
  @override
  String get shellTextAvailableLowercase => 'доступно';
  @override
  String get shellTextUnavailableLowercase => 'недоступно';
  @override
  String get shellTextDisconnectVpn => 'Отключить VPN';
  @override
  String get shellTextRequestStartup => 'Запросить запуск';
  @override
  String get shellTextNoStartupRequestYet =>
      'Запроса на запуск пока нет. Используйте типизированный контракт мобильного хоста, чтобы проверить fail-closed сценарий.';
  @override
  String shellTextTurnCredentialsSummary({
    required Object address,
    required Object username,
  }) => 'TURN ${address} | ${username}';
  @override
  String shellTextFailureSummary({
    required Object stage,
    required Object message,
  }) => '${stage}: ${message}';
  @override
  String get shellTextMoreChallengeActions => 'Больше действий проверки';
  @override
  String get shellTextMoreResolutionActions => 'Больше действий резолюции';
  @override
  String get shellTextStartOnThisDevice => 'Запустить на этом устройстве';
  @override
  String get shellTextShareHandoff => 'Поделиться handoff';
  @override
  String get shellTextOpenRoom => 'Открыть комнату';
  @override
  String get shellTextOpenCamera => 'Открыть камеру';
  @override
  String get shellTextOpenArchive => 'Открыть архив';
  @override
  String get shellTextCopyHandoff => 'Копировать handoff';
  @override
  String get shellTextCancelResolution => 'Отменить резолюцию';
  @override
  String get shellTextSessionsTitle => 'Сессии';
  @override
  String get shellTextNoMobileSessionsYet =>
      'Активных или недавних мобильных сессий пока нет.';
  @override
  String shellTextSessionListenConnections({
    required Object listen,
    required Object connections,
  }) => 'слушает ${listen} | соединения ${connections}';
  @override
  String shellTextSessionUpdated({
    required Object timestamp,
    required Object sessionId,
  }) => 'Обновлено ${timestamp} | сессия ${sessionId}';
  @override
  String get shellTextMoreSessionActions => 'Больше действий сессии';
  @override
  String get shellTextStopSession => 'Остановить сессию';
  @override
  String get shellTextExportDiagnostics => 'Экспортировать диагностику';
  @override
  String get shellTextEventStream => 'Поток событий';
  @override
  String get shellTextEventStreamSubtitle =>
      'Типизированные переходы состояния и обновления проверок от моста мобильного хоста.';
  @override
  String get shellTextNoEventsYet => 'Событий пока нет.';
  @override
  String get shellTextResetNeeded => 'Требуется сброс';
  @override
  String get shellTextHostReady => 'Хост готов';
  @override
  String get shellTextHostIncompatible => 'Хост несовместим';
  @override
  String get shellTextHostBlocked => 'Хост заблокирован';
  @override
  String get shellTextConnecting => 'Подключение';
  @override
  String get shellTextMobileHostReady => 'Мобильный хост готов';
  @override
  String get shellTextMobileHostIncompatible => 'Мобильный хост несовместим';
  @override
  String get shellTextMobileHostBlocked => 'Мобильный хост заблокирован';
  @override
  String get shellTextConnectingToMobileHost =>
      'Подключение к мобильному хосту';
  @override
  String shellTextSatisfiedPrerequisites({required Object prerequisites}) =>
      'Выполненные предусловия: ${prerequisites}';
  @override
  String shellTextMissingPrerequisite({required Object prerequisite}) =>
      'Отсутствует предусловие: ${prerequisite}';
  @override
  String get shellTextMobileHostModeAvailable =>
      'Мобильный хост сообщает, что этот режим доступен.';
  @override
  String get shellTextMobileHostModeUnavailable =>
      'Мобильный хост сообщает, что этот режим недоступен.';
  @override
  String shellTextPlatformTunnelReady({required Object modeLabel}) =>
      '${modeLabel} достиг готового состояния для туннельного пути мобильного хоста.';
  @override
  String shellTextPlatformTunnelReadyWithRoutingProfile({
    required Object modeLabel,
    required Object profileLabel,
  }) => '${modeLabel} готов с профилем маршрутизации ${profileLabel}.';
  @override
  String shellTextStartupBlockedAt({required Object stageLabel}) =>
      'Запуск заблокирован на этапе ${stageLabel}.';
  @override
  String get shellTextUnknownStage => 'Неизвестный этап';
  @override
  String get shellTextNoMobileTunnelModeSelected =>
      'Сейчас не выбран ни один мобильный туннельный режим.';
  @override
  String get shellTextAndroidSystemVpnMode => 'Режим системного VPN Android';
  @override
  String get shellTextAppleNetworkExtensionMode =>
      'Режим сетевого расширения Apple';
  @override
  String get shellTextWindowsWintunMode => 'Режим Windows Wintun';
  @override
  String get shellTextLinuxTunMode => 'Режим Linux TUN';
  @override
  String get shellTextPerAppRoutingUnavailable =>
      'Маршрутизация по приложениям недоступна для этого мобильного режима.';
  @override
  String shellTextRestartVpnToApplyRoutingProfile({
    required Object modeLabel,
  }) =>
      'Перезапустите ${modeLabel}, чтобы применить выбранный профиль маршрутизации.';
  @override
  String shellTextDevelopmentWifiRoutingUnavailableForHost({
    required Object modeLabel,
  }) =>
      '${modeLabel} не объявляет профиль маршрутизации Development Wi-Fi для этого хоста.';
  @override
  String get shellTextDevelopmentWifiRoutingSavedButUnsupported =>
      'Сохраненное предпочтение Development Wi-Fi не поддерживается текущим хостом. Переключитесь обратно на стандартный профиль или переподключитесь к совместимому хосту.';
  @override
  String shellTextRoutingSummaryWithProfile({
    required Object profileLabel,
    required Object scopeSummary,
  }) => '${profileLabel}. ${scopeSummary}';
  @override
  String get shellTextScopeAllInstalledApps =>
      'Область: все установленные приложения.';
  @override
  String get shellTextScopeIncludedAppsEmpty =>
      'Область: включенные приложения, но приложения пока не выбраны.';
  @override
  String shellTextScopeOnlySelectedApps({required Object count}) =>
      'Область: только ${count} выбранных приложений.';
  @override
  String get shellTextScopeExcludedAppsEmpty =>
      'Область: исключенные приложения, но приложения пока не выбраны.';
  @override
  String shellTextScopeAllExceptSelectedApps({required Object count}) =>
      'Область: все приложения кроме ${count} выбранных приложений.';
  @override
  String get shellTextWireGuardNativeOverTurnDatagram =>
      'WireGuard native поверх TURN datagram';
  @override
  String get shellTextWireGuardNativeOverTurnDtls =>
      'WireGuard native поверх TURN DTLS overlay';
  @override
  String get shellTextWireGuardNativeOverWebRtc =>
      'WireGuard native поверх WebRTC data channel';
  @override
  String get shellTextCustomOverlayOverTurnDatagram =>
      'Custom packet overlay поверх TURN datagram';
  @override
  String get shellTextCustomOverlayOverTurnDtls =>
      'Custom packet overlay поверх TURN DTLS overlay';
  @override
  String get shellTextCustomOverlayOverWebRtc =>
      'Custom packet overlay поверх WebRTC data channel';
  @override
  String get shellTextProxyCoreOverTurnDatagram =>
      'Proxy core adapter поверх TURN datagram';
  @override
  String get shellTextProxyCoreOverTurnDtls =>
      'Proxy core adapter поверх TURN DTLS overlay';
  @override
  String get shellTextProxyCoreOverWebRtc =>
      'Proxy core adapter поверх WebRTC data channel';
  @override
  String get shellTextTrustTunnelOverTurnDatagram =>
      'TrustTunnel native поверх TURN datagram';
  @override
  String get shellTextTrustTunnelOverTurnDtls =>
      'TrustTunnel native поверх TURN DTLS overlay';
  @override
  String get shellTextTrustTunnelOverWebRtc =>
      'TrustTunnel native поверх WebRTC data channel';
  @override
  String get shellTextOwnedBrowserMissingMetadata =>
      'Эта проверка не объявляет метаданные браузера приложения, необходимые для продолжения внутри приложения.';
  @override
  String get shellTextOwnedBrowserMissingUrl =>
      'Эта проверка не предоставляет URL встроенного браузера.';
  @override
  String get shellTextOwnedBrowserNoEvidence =>
      'Сессия встроенного браузера не предоставила пригодных данных для продолжения.';
  @override
  String shellTextOwnedBrowserTitle({required Object provider}) =>
      'Проверка провайдера ${provider}';
  @override
  String get shellTextOwnedBrowserOpenInvite => 'Открыть инвайт';
  @override
  String get shellTextOwnedBrowserCollecting => 'Сбор...';
  @override
  String get shellTextOwnedBrowserContinue => 'Продолжить';
  @override
  String get shellTextOwnedBrowserFallbackPrompt =>
      'Завершите шаг в браузере в этой встроенной сессии, затем продолжите.';
  @override
  String get shellTextOwnedBrowserHideKeyboard => 'Скрыть клавиатуру';
  @override
  String shellTextPlatformTunnelBlockedBase({
    required Object modeLabel,
    required Object stageLabel,
  }) => '${modeLabel} заблокирован на этапе ${stageLabel}.';
  @override
  String shellTextPlatformTunnelBlockedMissingPrerequisite({
    required Object prerequisiteLabel,
  }) => ' Отсутствует предусловие: ${prerequisiteLabel}.';
  @override
  String get shellTextMobileNoReusableSettingsYetNamedProviderUnnamed =>
      'Переиспользуемых настроек пока нет. Сохраните это как именованный провайдер для Профилей.';
  @override
  String shellTextMobileNoReusableSettingsYetNamedProviderNamed({
    required Object providerTitle,
  }) =>
      'Переиспользуемых настроек пока нет. Сохраните ${providerTitle} как именованный провайдер для Профилей.';
  @override
  String get shellTextMobileNoReusableSettingsYetTemplateUnnamed =>
      'Переиспользуемых настроек пока нет. Сохраните этот шаблон как именованную стартовую точку.';
  @override
  String shellTextMobileNoReusableSettingsYetTemplateNamed({
    required Object providerTitle,
  }) =>
      'Переиспользуемых настроек пока нет. Сохраните ${providerTitle} как именованную стартовую точку.';
  @override
  String shellTextDesktopCompactPlatformTunnelCapabilitySummaryAvailable({
    required Object modeLabel,
  }) => '${modeLabel} доступен для подключенного хоста.';
  @override
  String shellTextDesktopCompactPlatformTunnelCapabilitySummaryUnavailable({
    required Object modeLabel,
  }) => '${modeLabel} недоступен';
  @override
  String
  shellTextDesktopCompactPlatformTunnelCapabilitySummaryMissingPrerequisite({
    required Object missingPrerequisite,
  }) => ', потому что ${missingPrerequisite} все еще отсутствует.';
  @override
  String
  get shellTextDesktopCompactPlatformTunnelCapabilitySummaryUnavailableSuffix =>
      ' для подключенного хоста.';
  @override
  String shellTextDesktopCompactPlatformTunnelStatusLabelUnavailable({
    required Object modeLabel,
  }) => '${modeLabel} недоступен';
  @override
  String shellTextDesktopCompactPlatformTunnelStatusLabelMissing({
    required Object modeLabel,
    required Object missing,
  }) => '${modeLabel}: отсутствует ${missing}';
  @override
  String shellTextDesktopPlatformTunnelResultSummaryReady({
    required Object modeLabel,
  }) =>
      '${modeLabel} достиг готового состояния для туннельного пути настольного хоста.';
  @override
  String shellTextDesktopPlatformTunnelResultSummaryBlocked({
    required Object stageLabel,
  }) => 'Запуск заблокирован на этапе ${stageLabel}.';
  @override
  String get shellTextStateStarting => 'запуск';
  @override
  String get shellTextStateChallengeRequired => 'требуется проверка';
  @override
  String get shellTextStateReady => 'готово';
  @override
  String get shellTextStateRetrying => 'повтор';
  @override
  String get shellTextStateStopping => 'остановка';
  @override
  String get shellTextStateStopped => 'остановлено';
  @override
  String get shellTextStateFailed => 'сбой';
  @override
  String get shellTextStateResolved => 'разрешено';
  @override
  String get shellTextStateCancelled => 'отменено';
  @override
  String get shellTextStateExpired => 'истекло';
  @override
  String get shellTextExecutionOwnerHost => 'хост';
  @override
  String get shellTextExecutionOwnerShellLocal => 'локальная оболочка';
  @override
  String get shellTextExecutionOwnerShellExternal => 'внешняя оболочка';
  @override
  String shellTextModeSummaryWithoutExecutionPath({
    required Object modeLabel,
    required Object routingSummary,
  }) => '${modeLabel}. ${routingSummary}';
  @override
  String shellTextModeSummaryWithExecutionPath({
    required Object modeLabel,
    required Object routingSummary,
    required Object executionPath,
  }) => '${modeLabel}. ${routingSummary} Путь выполнения: ${executionPath}.';
  @override
  String shellTextExportExpiry({required Object timestamp}) =>
      'Срок действия экспорта ${timestamp}';
  @override
  String shellTextExportExpiryWithSource({
    required Object timestamp,
    required Object source,
  }) => 'Срок действия экспорта ${timestamp} через ${source}';
}

/// The flat map containing all translations for locale <ru>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on TranslationsRu {
  dynamic _flatMapFunction(String path) {
    return switch (path) {
          'appDesktopTitle' => 'vk-turn-proxy настольная оболочка',
          'appDesktopReferencesTitle' =>
            'vk-turn-proxy примеры настольной оболочки',
          'appMobileTitle' => 'vk-turn-proxy мобильная оболочка',
          'localeMenuLabel' => 'Язык',
          'localeSwitchTooltip' => 'Сменить язык',
          'localeSystemDefault' => 'Системный',
          'localeEnglish' => 'Английский',
          'localeRussian' => 'Русский',
          'commonHome' => 'Главная',
          'commonProfiles' => 'Профили',
          'commonProviders' => 'Провайдеры',
          'commonRouting' => 'Маршрутизация',
          'commonSupport' => 'Поддержка',
          'commonDiagnostics' => 'Диагностика',
          'commonLiveWork' => 'Текущая работа',
          'commonReconnect' => 'Переподключить',
          'commonRefresh' => 'Обновить',
          'commonWorkflows' => 'Рабочие процессы',
          'commonQuickActions' => 'Быстрые действия',
          'commonSavedProfiles' => 'Сохраненные профили',
          'commonProviderRecords' => 'Записи провайдеров',
          'commonNewDraft' => 'Новый черновик',
          'commonNewFromPreset' => 'Новый из пресета',
          'commonProviderFamilies' => 'Семейства провайдеров',
          'commonOpenWorkflowsTooltip' => 'Открыть рабочие процессы',
          'mobileHomeTitle' => 'Главная',
          'mobileHomeSubtitle' =>
            'Выберите профиль, завершите шаг провайдера в браузере и отсюда включайте или выключайте текущий путь VPN на мобильном устройстве.',
          'mobileProfilesTitle' => 'Профили',
          'mobileProfilesSubtitle' =>
            'Выберите сохраненный профиль или добавьте новый для главного экрана.',
          'mobileProfilesImportInvite' => 'Импортировать инвайт',
          'mobileProfilesRouting' => 'Маршрутизация',
          'mobileProfilesActionsTooltip' => 'Действия профилей',
          'mobileProfilesAddProfile' => 'Добавить профиль',
          'mobileProfilesEmptyTitle' => 'Сохраненных профилей пока нет',
          'mobileProfilesEmptyMessage' =>
            'Создайте или импортируйте профиль, затем используйте главный экран для быстрого запуска VPN одним нажатием.',
          'desktopShellLabel' => 'Настольная оболочка управления',
          'desktopStatusConnectingTitle' => 'Подключение к локальному хосту',
          'desktopStatusReadyTitle' => 'Локальный хост готов',
          'desktopStatusBlockedTitle' => 'Локальный хост заблокирован',
          'desktopStatusStartingDetail' =>
            'Запуск локального хоста и согласование возможностей.',
          'desktopStatusConnectedDetail' => 'Подключено к локальному хосту.',
          'desktopStatusWaitingDetail' =>
            'Ожидание согласования с локальным хостом.',
          'desktopReadyWorkflowDetail' =>
            'Основным остается сфокусированный редактор; диагностика и текущая работа остаются вторичными, пока не понадобятся.',
          'desktopSectionProfilesSubtitle' => 'Редактирование профилей',
          'desktopSectionProvidersSubtitle' => 'Записи провайдеров',
          'sharedProviderAuthPostureNotApplicable' =>
            'требование к авторизации не указано',
          'sharedProviderAuthPostureGuest' => 'гостевая авторизация',
          'sharedProviderAuthPostureAccount' => 'авторизация по аккаунту',
          'sharedProviderAuthPostureGuestOrAccount' => 'гость или аккаунт',
          'sharedProviderAuthPostureStaticSecret' => 'статический секрет',
          'sharedProviderBrowserPolicyNotRequired' => 'браузер не требуется',
          'sharedProviderBrowserPolicyExternalRequired' =>
            'нужен внешний браузер',
          'sharedProviderBrowserPolicyEmbeddedAllowed' =>
            'разрешен встроенный браузер',
          'sharedArtifactFamilyGenericTurn' => 'Generic TURN',
          'sharedArtifactFamilyConferenceRoom' => 'Комната конференции',
          'sharedArtifactFamilyCameraStream' => 'Поток камеры',
          'sharedArtifactActionStartOnThisDevice' =>
            'Запустить на этом устройстве',
          'sharedArtifactActionExportHandoff' => 'Экспортировать пакет handoff',
          'sharedArtifactActionOpenRoom' => 'Открыть комнату',
          'sharedArtifactActionOpenCamera' => 'Открыть камеру',
          'sharedArtifactActionOpenArchive' => 'Открыть архив',
          'sharedPlatformTunnelModeAndroidVpnService' => 'Android VPN Service',
          'sharedPlatformTunnelModeAppleNetworkExtension' =>
            'Apple Network Extension',
          'sharedPlatformTunnelModeWindowsWintun' => 'Windows Wintun',
          'sharedPlatformTunnelModeLinuxTun' => 'Linux TUN',
          'sharedPlatformTunnelPrerequisitePermission' => 'разрешение',
          'sharedPlatformTunnelPrerequisiteEntitlement' => 'право доступа',
          'sharedPlatformTunnelPrerequisitePrivilegedExtension' =>
            'привилегированное расширение',
          'sharedPlatformTunnelPrerequisiteDriver' => 'драйвер',
          'sharedPlatformTunnelPrerequisiteRouteExclusion' =>
            'исключение маршрута',
          'sharedPlatformTunnelPrerequisiteDnsBypass' => 'обход DNS',
          'sharedPlatformTunnelPrerequisiteAppRoutingPolicy' =>
            'политика маршрутизации приложений',
          'sharedPlatformTunnelPrerequisiteHostImplementation' =>
            'реализация хоста',
          'sharedPlatformTunnelStartupStageCapabilityCheck' =>
            'Проверка возможностей',
          'sharedPlatformTunnelStartupStagePermissionAcquire' =>
            'Получение разрешения',
          'sharedPlatformTunnelStartupStageEntitlementAcquire' =>
            'Получение права доступа',
          'sharedPlatformTunnelStartupStageDriverCheck' => 'Проверка драйвера',
          'sharedPlatformTunnelStartupStageRouteValidate' =>
            'Проверка маршрута',
          'sharedPlatformTunnelStartupStageHostBringup' => 'Подъем хоста',
          'sharedPlatformTunnelStartupStageRuntimeAttach' =>
            'Подключение рантайма',
          'sharedProviderConfigAvailabilityStateAvailable' => 'Доступно',
          'sharedProviderConfigAvailabilityStateProviderUnavailable' =>
            'Провайдер недоступен',
          'sharedProviderConfigAvailabilityStateSchemaUnsupported' =>
            'Схема не поддерживается',
          'sharedProviderConfigAvailabilityStateSettingsInvalid' =>
            'Настройки невалидны',
          'sharedCatalogPresetVkDefaultTitle' => 'VK Calls',
          'sharedCatalogPresetVkDefaultDescription' =>
            'Создать управляемую запись провайдера VK для рабочего процесса с инвайтом и шагом в браузере.',
          'sharedCatalogPresetVkDefaultSuggestedProfileName' => 'VK Calls',
          'sharedCatalogPresetGenericTurnDefaultTitle' => 'Generic TURN',
          'sharedCatalogPresetGenericTurnDefaultDescription' =>
            'Создать управляемую запись Generic TURN для рабочего процесса со статической передачей TURN-параметров.',
          'sharedCatalogPresetGenericTurnDefaultSuggestedProfileName' =>
            'Generic TURN',
          'sharedCatalogSupportedProviderVkTitle' => 'VK Calls',
          'sharedCatalogSupportedProviderVkDescription' =>
            'Провайдер с инвайтом на первом шаге и продолжением через браузер, который приводит к готовым для транспорта учетным данным TURN.',
          'sharedCatalogSupportedProviderVkSuggestedManagedProviderName' =>
            'VK Calls',
          'sharedCatalogSupportedProviderGenericTurnTitle' => 'Generic TURN',
          'sharedCatalogSupportedProviderGenericTurnDescription' =>
            'Статическая передача TURN-параметров для детерминированного тестирования транспорта и запуска рантайма под управлением оператора.',
          'sharedCatalogSupportedProviderGenericTurnSuggestedManagedProviderName' =>
            'Generic TURN',
          'shellTextClose' => 'Закрыть',
          'shellTextCancel' => 'Отмена',
          'shellTextBack' => 'Назад',
          'shellTextSave' => 'Сохранить',
          'shellTextDelete' => 'Удалить',
          'shellTextNewItem' => 'Новый',
          'shellTextMissing' => 'отсутствует',
          'shellTextUnknownValue' => 'неизвестно',
          'shellTextFailureFallback' => 'сбой',
          'shellTextRetry' => 'Повторить',
          'shellTextActivity' => 'Активность',
          'shellTextDiagnostics' => 'Диагностика',
          'shellTextOverview' => 'Обзор',
          'shellTextEvents' => 'События',
          'shellTextTemplates' => 'Шаблоны',
          'shellTextAvailable' => 'Доступно',
          'shellTextUnavailable' => 'Недоступно',
          'shellTextOpenActivity' => 'Открыть активность',
          'shellTextOpenDiagnostics' => 'Открыть диагностику',
          'shellTextOpenProfiles' => 'Открыть профили',
          'shellTextResetLocalState' => 'Сбросить локальное состояние',
          'shellTextImportFromFile' => 'Импорт из файла',
          'shellTextExportSavedProfile' => 'Экспортировать сохраненный профиль',
          'shellTextPasteEnvelope' => 'Вставить конверт',
          'shellTextCopyText' => 'Копировать текст',
          'shellTextSaveFile' => 'Сохранить файл',
          'shellTextShareText' => 'Поделиться текстом',
          'shellTextShareFile' => 'Поделиться файлом',
          'shellTextPreviewImport' => 'Предпросмотр импорта',
          'shellTextImportProfile' => 'Импортировать профиль',
          'shellTextPortableProfileJson' => 'JSON переносимого профиля',
          'shellTextPortableProfileEnvelope' => 'Конверт переносимого профиля',
          'shellTextNoManagedProvidersAvailableYet' =>
            'Управляемые провайдеры пока недоступны.',
          'shellTextSelectedProviderNotAdvertisedByConnectedHost' =>
            'Выбранный провайдер не объявлен подключенным хостом.',
          'shellTextSelectedProviderNotAdvertisedByConnectedMobileHost' =>
            'Выбранный провайдер не объявлен подключенным мобильным хостом.',
          'shellTextSavedProfile' =>
            ({required Object profileLabel}) =>
                'Профиль ${profileLabel} сохранен.',
          'shellTextSavedMobileProfile' =>
            ({required Object profileLabel}) =>
                'Мобильный профиль ${profileLabel} сохранен.',
          'shellTextDeletedProfile' =>
            ({required Object profileId}) => 'Профиль ${profileId} удален.',
          'shellTextDeletedMobileProfile' =>
            ({required Object profileId}) =>
                'Мобильный профиль ${profileId} удален.',
          'shellTextSavedManagedProvider' =>
            ({required Object providerLabel}) =>
                'Управляемый провайдер ${providerLabel} сохранен.',
          'shellTextDeletedManagedProvider' =>
            ({required Object providerId}) =>
                'Управляемый провайдер ${providerId} удален.',
          'shellTextSaveOrSelectProfileBeforeExport' =>
            'Сохраните профиль или выберите уже сохраненный профиль перед экспортом.',
          'shellTextSelectedProfileDependsOnMissingManagedProviderSnapshot' =>
            'Выбранный профиль зависит от снимка управляемого провайдера, который больше недоступен локально.',
          'shellTextCopiedPortableProfile' =>
            ({required Object profileLabel}) =>
                'Переносимый профиль ${profileLabel} скопирован.',
          'shellTextCopiedSecretBearingPortableProfile' =>
            ({required Object profileLabel}) =>
                'Скопирован переносимый профиль с секретами ${profileLabel}. Относитесь к этому пакету как к учетным данным.',
          'shellTextSavedPortableProfile' =>
            ({required Object profileLabel, required Object path}) =>
                'Переносимый профиль ${profileLabel} сохранен в ${path}.',
          'shellTextSavedSecretBearingPortableProfile' =>
            ({required Object profileLabel, required Object path}) =>
                'Переносимый профиль с секретами ${profileLabel} сохранен в ${path}.',
          'shellTextSharedPortableProfileAsText' =>
            ({required Object profileLabel}) =>
                'Переносимый профиль ${profileLabel} отправлен как текст.',
          'shellTextSharedSecretBearingPortableProfileAsText' =>
            ({required Object profileLabel}) =>
                'Переносимый профиль с секретами ${profileLabel} отправлен как текст.',
          'shellTextSharedPortableProfileAsFile' =>
            ({required Object profileLabel}) =>
                'Переносимый профиль ${profileLabel} отправлен как файл.',
          'shellTextSharedSecretBearingPortableProfileAsFile' =>
            ({required Object profileLabel}) =>
                'Переносимый профиль с секретами ${profileLabel} отправлен как файл.',
          'shellTextImportedProfile' =>
            ({required Object profileLabel}) =>
                'Профиль ${profileLabel} импортирован.',
          'shellTextImportedSecretBearingProfile' =>
            ({required Object profileLabel}) =>
                'Импортирован профиль с секретами ${profileLabel}. Проверьте ввод провайдера, прежде чем делиться им дальше.',
          'shellTextStartedSession' =>
            ({required Object sessionId}) => 'Сессия ${sessionId} запущена.',
          'shellTextStartedMobileSession' =>
            ({required Object sessionId}) =>
                'Мобильная сессия ${sessionId} запущена.',
          'shellTextStoppedSession' =>
            ({required Object sessionId}) => 'Сессия ${sessionId} остановлена.',
          'shellTextManagedProviderNoLongerAvailable' =>
            ({required Object providerId}) =>
                'Управляемый провайдер ${providerId} больше недоступен.',
          'shellTextAppliedManagedProviderToActiveProfileDraft' =>
            ({required Object providerLabel}) =>
                'Управляемый провайдер ${providerLabel} применен к активному черновику профиля.',
          'shellTextAppliedManagedProviderToActiveMobileProfileDraft' =>
            ({required Object providerLabel}) =>
                'Управляемый провайдер ${providerLabel} применен к активному черновику мобильного профиля.',
          'shellTextSeededManagedProviderDraftFromPreset' =>
            ({required Object presetTitle}) =>
                'Новый черновик управляемого провайдера создан из пресета ${presetTitle}.',
          'shellTextCancelledResolution' =>
            ({required Object resolutionId}) =>
                'Разрешение ${resolutionId} отменено.',
          'shellTextCancelledMobileResolution' =>
            ({required Object resolutionId}) =>
                'Мобильное разрешение ${resolutionId} отменено.',
          'shellTextStartedSessionFromResolution' =>
            ({required Object sessionId, required Object resolutionId}) =>
                'Сессия ${sessionId} запущена из разрешения ${resolutionId}. Готовность будет показана только после успешного запуска рантайма.',
          'shellTextStartedMobileSessionFromResolution' =>
            ({required Object sessionId, required Object resolutionId}) =>
                'Мобильная сессия ${sessionId} запущена из разрешения ${resolutionId}. Готовность будет показана только после успешного запуска рантайма.',
          'shellTextCopiedHandoffLink' =>
            ({required Object resolutionId, required Object expiresAt}) =>
                'Ссылка handoff для ${resolutionId} скопирована. Истекает ${expiresAt}.',
          'shellTextSharedHandoffLink' =>
            ({required Object resolutionId, required Object expiresAt}) =>
                'Ссылка handoff для ${resolutionId} отправлена. Истекает ${expiresAt}.',
          'shellTextResolutionNoLongerAvailable' =>
            ({required Object resolutionId}) =>
                'Разрешение ${resolutionId} больше недоступно.',
          'shellTextResolutionDoesNotAdvertiseAction' =>
            ({required Object resolutionId, required Object actionLabel}) =>
                'Разрешение ${resolutionId} не объявляет действие "${actionLabel}".',
          'shellTextResolutionHasNoBrowserTarget' =>
            ({required Object resolutionId, required Object actionLabel}) =>
                'Разрешение ${resolutionId} не предоставляет браузерную цель для действия "${actionLabel}".',
          'shellTextOpenedResolutionAction' =>
            ({required Object actionLabel, required Object resolutionId}) =>
                'Открыто действие "${actionLabel}" для ${resolutionId}.',
          'shellTextFailedToOpenResolutionAction' =>
            ({required Object actionLabel, required Object resolutionId}) =>
                'Не удалось открыть действие "${actionLabel}" для ${resolutionId}.',
          'shellTextCancelledChallenge' =>
            ({required Object challengeId}) =>
                'Проверка ${challengeId} отменена.',
          'shellTextExportedDiagnostics' =>
            ({required Object path}) => 'Диагностика экспортирована в ${path}.',
          'shellTextEventStreamClosed' => 'поток событий закрыт',
          'shellTextLocalHostNotReady' => 'Локальный хост не готов.',
          'shellTextFailedToRestoreDesktopShellState' =>
            ({required Object error}) =>
                'Не удалось восстановить состояние настольной оболочки: ${error}',
          'shellTextFailedToPersistDesktopShellState' =>
            ({required Object error}) =>
                'Не удалось сохранить состояние настольной оболочки: ${error}',
          'shellTextFailedToPersistMobileShellState' =>
            ({required Object error}) =>
                'Не удалось сохранить состояние мобильной оболочки: ${error}',
          'shellTextPlatformTunnelReadyForLocalHost' =>
            ({required Object modeLabel}) =>
                '${modeLabel} готов для туннельного пути локального хоста.',
          'shellTextStartedResolutionForProvider' =>
            ({required Object resolutionId, required Object providerName}) =>
                'Разрешение ${resolutionId} для ${providerName} запущено.',
          'shellTextStartedResolutionForProviderWithExternalBrowser' =>
            ({required Object resolutionId, required Object providerName}) =>
                'Разрешение ${resolutionId} для ${providerName} запущено. Завершите обязательные шаги во внешнем браузере, прежде чем ожидать готовый артефакт.',
          'shellTextStartedResolutionForProviderWithBrowserContinuation' =>
            ({required Object resolutionId, required Object providerName}) =>
                'Разрешение ${resolutionId} для ${providerName} запущено. Завершите возможный браузерный шаг проверки, прежде чем ожидать готовый артефакт.',
          'shellTextContinuedChallenge' =>
            ({required Object challengeId}) =>
                'Проверка ${challengeId} продолжена.',
          'shellTextContinuedChallengeWithExternalBrowser' =>
            ({required Object challengeId, required Object providerName}) =>
                'Проверка ${challengeId} продолжена. Завершите внешний браузерный шаг для ${providerName}, прежде чем ожидать следующий переход состояния.',
          'shellTextContinuedChallengeForResolution' =>
            ({required Object challengeId, required Object providerName}) =>
                'Проверка ${challengeId} продолжена. Завершите поток провайдера для ${providerName}, прежде чем ожидать готовый артефакт.',
          'shellTextContinuedChallengeForSession' =>
            ({required Object challengeId, required Object providerName}) =>
                'Проверка ${challengeId} продолжена. Завершите поток провайдера для ${providerName}, прежде чем ожидать перехода сессии в состояние готовности.',
          'shellTextDesktopProviderSettingsRuntimeUnsupported' =>
            ({required Object providerName, required Object error}) =>
                'Подключенная настольная оболочка не может отрисовать настройки провайдера для ${providerName}: ${error}',
          'shellTextMobileProviderSettingsRuntimeUnsupported' =>
            ({required Object providerName, required Object error}) =>
                'Подключенная мобильная оболочка не может отрисовать настройки провайдера для ${providerName}: ${error}',
          'shellTextSelectedManagedProviderFamilyNotInSupportedCatalog' =>
            'Выбранное семейство управляемого провайдера не входит в поддерживаемый каталог приложения.',
          'shellTextSelectedManagedProviderNotInSupportedCatalog' =>
            'Выбранный управляемый провайдер не входит в поддерживаемый каталог приложения.',
          'shellTextManagedProviderNotInSupportedCatalog' =>
            'Этот управляемый провайдер не входит в поддерживаемый каталог приложения.',
          'shellTextDesktopReusableSettingsRuntimeUnsupported' =>
            ({required Object providerName, required Object error}) =>
                'Подключенная настольная оболочка не может отрисовать переиспользуемые настройки для ${providerName}: ${error}',
          'shellTextMobileReusableSettingsRuntimeUnsupported' =>
            ({required Object providerName, required Object error}) =>
                'Подключенная мобильная оболочка не может отрисовать переиспользуемые настройки для ${providerName}: ${error}',
          'shellTextConnectedHostDoesNotAdvertiseProviderFamilyYet' =>
            ({required Object providerTitle}) =>
                'Подключенный хост пока не объявляет семейство провайдера ${providerTitle}.',
          'shellTextSelectedTemplateFamilyNotInSupportedCatalog' =>
            'Выбранное семейство шаблона не входит в поддерживаемый каталог приложения.',
          'shellTextTemplateNotInSupportedCatalog' =>
            'Этот шаблон не входит в поддерживаемый каталог приложения.',
          'shellTextMobileTemplateRuntimeUnsupported' =>
            ({required Object providerName, required Object error}) =>
                'Подключенная мобильная оболочка не может отрисовать переиспользуемые настройки для ${providerName}: ${error}',
          'shellTextLocalHostShutdownRequested' =>
            'Запрошено завершение локального хоста.',
          'shellTextNoCompatibleLocalHostFound' =>
            'Совместимый локальный хост не найден, и кандидаты на запуск не настроены.',
          'shellTextLocalHostLaunchFailedWithoutReportedError' =>
            'Запуск локального хоста завершился неудачно без сообщенной ошибки.',
          'shellTextLocalHostLaunchFailed' =>
            ({required Object error}) =>
                'Не удалось запустить локальный хост: ${error}',
          'shellTextConnectedToLocalHost' =>
            ({required Object listenAddress}) =>
                'Подключено к локальному хосту ${listenAddress}',
          'shellTextLaunchedLocalHost' =>
            ({required Object description, required Object listenAddress}) =>
                'Запущен ${description} на ${listenAddress}',
          'shellTextSidecarLaunchCandidateEnvPath' => 'GUI_SHELL_CLIENTD_PATH',
          'shellTextSidecarLaunchCandidateNextToAppExecutable' =>
            'sidecar рядом с исполняемым файлом приложения',
          'shellTextSidecarLaunchCandidateBundledFrameworks' =>
            'встроенный sidecar в Frameworks',
          'shellTextSidecarLaunchCandidateFromPath' => 'clientd из PATH',
          'shellTextSidecarLaunchCandidateRepoLocalGoRun' =>
            'локальный repo fallback через go run',
          'shellTextSidecarExitedBeforeReady' =>
            ({required Object description, required Object exitCode}) =>
                '${description} завершился с кодом ${exitCode} до того, как control plane стал готов.',
          'shellTextProviderExpectsLinkEntryOnlyDesktop' =>
            ({required Object providerName, required Object inputKind}) =>
                '${providerName} ожидает ввод типа ${inputKind}. Эта настольная оболочка сейчас поддерживает только ввод ссылки.',
          'shellTextSavedTemplate' =>
            ({required Object templateLabel}) =>
                'Шаблон ${templateLabel} сохранен.',
          'shellTextDeletedTemplate' =>
            ({required Object templateId}) => 'Шаблон ${templateId} удален.',
          'shellTextTemplateNoLongerAvailable' =>
            ({required Object templateId}) =>
                'Шаблон ${templateId} больше недоступен.',
          'shellTextSeededManagedProviderDraftFromTemplate' =>
            ({required Object templateLabel}) =>
                'Новый черновик управляемого провайдера создан из шаблона ${templateLabel}.',
          'shellTextClearedLocalMobileShellState' =>
            'Локальное состояние мобильной оболочки очищено.',
          'shellTextFailedToClearLocalMobileShellState' =>
            ({required Object error}) =>
                'Не удалось очистить локальное состояние мобильной оболочки: ${error}',
          'shellTextProviderExpectsLinkEntryOnlyMobile' =>
            ({required Object providerName, required Object inputKind}) =>
                '${providerName} ожидает ввод типа ${inputKind}. Эта мобильная оболочка сейчас поддерживает только ввод ссылки.',
          'shellTextResolutionUnavailableForPlatformTunnel' =>
            ({
              required Object modeLabel,
              required Object resolutionId,
              required Object stage,
              required Object message,
            }) =>
                'Нельзя запустить ${modeLabel}, потому что разрешение ${resolutionId} завершилось на этапе ${stage}: ${message}',
          'shellTextChallengeMustCompleteBeforeStarting' =>
            ({required Object modeLabel}) =>
                'Завершите текущую проверку провайдера, прежде чем запускать ${modeLabel}.',
          'shellTextWaitForProviderResolutionBeforeStarting' =>
            ({required Object modeLabel}) =>
                'Дождитесь завершения текущего разрешения провайдера, прежде чем запускать ${modeLabel}.',
          'shellTextStartedMobileResolutionForProvider' =>
            ({required Object resolutionId, required Object providerName}) =>
                'Мобильное разрешение ${resolutionId} для ${providerName} запущено.',
          'shellTextStartedMobileResolutionForProviderWithExternalBrowser' =>
            ({required Object resolutionId, required Object providerName}) =>
                'Мобильное разрешение ${resolutionId} для ${providerName} запущено. Ожидайте шаг во внешнем браузере, если он требуется провайдеру.',
          'shellTextStartedMobileResolutionForProviderWithBrowserContinuation' =>
            ({required Object resolutionId, required Object providerName}) =>
                'Мобильное разрешение ${resolutionId} для ${providerName} запущено. Завершите возможное продолжение в браузере, прежде чем ожидать готовый артефакт.',
          'shellTextResolutionStartedThenCompleteChallengeBeforeStarting' =>
            ({required Object startedNotice, required Object modeLabel}) =>
                '${startedNotice} Завершите текущую проверку провайдера, прежде чем запускать ${modeLabel}.',
          'shellTextReceivedPortableProfileForReview' =>
            ({required Object profileLabel}) =>
                'Получен переносимый профиль ${profileLabel}. Просмотрите его перед импортом.',
          'shellTextReceivedSecretBearingPortableProfileForReview' =>
            ({required Object profileLabel}) =>
                'Получен переносимый профиль с секретами ${profileLabel}. Просмотрите его перед импортом.',
          'shellTextConnectedToMobileHostBridge' =>
            ({required Object baseUri}) =>
                'Подключено к мосту мобильного хоста ${baseUri}',
          'shellTextChallengeHasNoBrowserHandoffUrl' =>
            'Эта проверка не предоставляет URL для передачи в браузер.',
          'shellTextOpenedMobileBrowserHandoff' =>
            ({required Object challengeKind}) =>
                'Открыт переход в мобильный браузер для ${challengeKind}. Вернитесь сюда после шага в браузере.',
          'shellTextFailedToOpenMobileBrowserHandoffUrl' =>
            'Не удалось открыть URL передачи в мобильный браузер.',
          'shellTextPlatformTunnelDisconnected' =>
            ({required Object modeLabel}) => '${modeLabel} отключен.',
          'shellTextSelectAtLeastOneIncludedApp' =>
            ({required Object modeLabel}) =>
                'Выберите хотя бы одно приложение перед запуском ${modeLabel} в режиме включенных приложений.',
          'shellTextSelectAtLeastOneExcludedApp' =>
            ({required Object modeLabel}) =>
                'Выберите хотя бы одно приложение перед запуском ${modeLabel} в режиме исключенных приложений.',
          'shellTextSelectedMobileModeNotAdvertisedByConnectedHost' =>
            'Выбранный мобильный режим не объявлен подключенным хостом.',
          'shellTextModeDoesNotAdvertiseSupportedExecutionPath' =>
            ({required Object modeLabel}) =>
                '${modeLabel} пока не объявляет поддерживаемый путь выполнения.',
          'shellTextSelectExecutionPathBeforeStarting' =>
            ({required Object modeLabel}) =>
                'Выберите путь выполнения перед запуском ${modeLabel}.',
          'shellTextResetLocalMobileShellStateBeforeReconnecting' =>
            'Сбросьте локальное состояние мобильной оболочки перед переподключением.',
          'shellTextDetectedBrowserReturnAndContinuedChallenge' =>
            ({required Object signalLabel, required Object challengeId}) =>
                'Обнаружен сигнал "${signalLabel}", и проверка ${challengeId} продолжена.',
          'shellTextCompletedInAppBrowserContinuation' =>
            ({required Object challengeId}) =>
                'Продолжение во встроенном браузере для проверки ${challengeId} завершено.',
          'shellTextResetLocalMobileShellStateBeforeRuntimeControlContinue' =>
            'Сбросьте локальное состояние мобильной оболочки, прежде чем управление рантаймом сможет продолжиться.',
          'shellTextAppLinkBrowserReturn' => 'возврат из браузера по app-link',
          'shellTextUniversalLinkBrowserReturn' =>
            'возврат из браузера по universal-link',
          'shellTextBrowserReturnOnAppResume' =>
            'возврат из браузера при возобновлении приложения',
          'shellTextBrowserReturn' => 'возврат из браузера',
          'shellTextMobileHostBridgeNotReady' =>
            'Мост мобильного хоста не готов.',
          'shellTextNativeMobileHostBridgeDidNotReturnHostConfiguration' =>
            'Нативный мост мобильного хоста не вернул конфигурацию хоста.',
          'shellTextNativeMobileHostBridgeReturnedEmptyHostUrl' =>
            'Нативный мост мобильного хоста вернул пустой URL хоста.',
          'shellTextNativeMobileHostBridgeReturnedInvalidHostUrl' =>
            ({required Object baseUrl}) =>
                'Нативный мост мобильного хоста вернул некорректный URL хоста: ${baseUrl}',
          'shellTextNativeMobileHostBridgePluginUnavailable' =>
            'Плагин нативного моста мобильного хоста недоступен.',
          'shellTextFailedToResolveMobileHostBridgeFromNativePlatform' =>
            ({required Object details}) =>
                'Не удалось определить мост мобильного хоста через нативную платформу: ${details}',
          'shellTextNativeMobileHostBridgePluginUnavailableForPermissionRequests' =>
            'Плагин нативного моста мобильного хоста недоступен для запросов разрешения на платформенный туннель.',
          'shellTextFailedToRequestNativePlatformTunnelPermission' =>
            ({required Object details}) =>
                'Не удалось запросить разрешение на платформенный туннель у нативной платформы: ${details}',
          'shellTextNativeMobileHostBridgeReturnedNoWebViewSnapshot' =>
            'Нативный мост мобильного хоста не вернул снимок WebView.',
          'shellTextFailedToInspectNativeWebView' =>
            ({required Object details}) =>
                'Не удалось проинспектировать нативный WebView: ${details}',
          'shellTextVktpMobileHostUrlInvalid' =>
            'VKTP_MOBILE_HOST_URL не является корректным URI для моста мобильного хоста.',
          'shellTextNativeMobileHostBridgeDidNotProvideControlPlaneEndpoint' =>
            'Нативный мост мобильного хоста не предоставил endpoint control plane.',
          'shellTextMobileHostBridgeNotConfigured' =>
            'Мост мобильного хоста не настроен. Упакуйте совместимый loopback host или задайте VKTP_MOBILE_HOST_URL для разработки.',
          'shellTextNativeMobileHostBridgePluginUnavailableForInstalledAppInventory' =>
            'Плагин нативного моста мобильного хоста недоступен для инвентаря установленных приложений.',
          'shellTextFailedToListInstalledAppsFromNativePlatform' =>
            ({required Object details}) =>
                'Не удалось получить список установленных приложений от нативной платформы: ${details}',
          'shellTextFailedToRestoreMobileShellState' =>
            ({required Object error}) =>
                'Не удалось восстановить состояние мобильной оболочки: ${error}',
          'shellTextProviderDidNotReturnStartableArtifact' =>
            'Провайдер не вернул артефакт, пригодный для запуска.',
          'shellTextLoopbackPeerBlockReason' =>
            ({required Object modeLabel, required Object peerAddress}) =>
                '${modeLabel} все еще указывает на loopback peer ${peerAddress}. Настройте оператором управляемый удаленный peer endpoint перед запуском мобильного VPN-пути.',
          'shellTextSecureProfileSecretsUnavailable' =>
            'Защищенные секреты профилей недоступны. Восстановите secure storage или очистите сохраненное состояние мобильной оболочки.',
          'shellTextSecureProfileSecretsMissing' =>
            ({required Object profileId}) =>
                'Защищенные секреты отсутствуют для сохраненного профиля ${profileId}.',
          'shellTextSecureDraftSecretsUnavailable' =>
            'Защищенные секреты черновика недоступны. Восстановите secure storage или сбросьте черновик.',
          'shellTextResolutionStartedThenWaitForFinishBeforeStarting' =>
            ({required Object startedNotice, required Object modeLabel}) =>
                '${startedNotice} Дождитесь завершения разрешения, прежде чем запускать ${modeLabel}.',
          'shellTextNoReusableFieldsYet' => 'Переиспользуемых полей пока нет',
          'shellTextSchemaBlockedInShell' =>
            'Схема заблокирована в этой оболочке',
          'shellTextReusableFieldsReady' => 'Переиспользуемые поля готовы',
          'shellTextProviderInput' => 'Ввод провайдера',
          'shellTextProviderLink' => 'Ссылка провайдера',
          'shellTextProviderFamily' => 'Семейство провайдера',
          'shellTextProviderType' => 'Тип провайдера',
          'shellTextProfileName' => 'Имя профиля',
          'shellTextLocalUdpListen' => 'Локальный UDP-адрес',
          'shellTextPeerAddress' => 'Адрес удаленного узла',
          'shellTextConnections' => 'Соединения',
          'shellTextTurnMode' => 'Режим TURN',
          'shellTextTurnOverride' => 'Переопределение TURN',
          'shellTextTurnPort' => 'Порт TURN',
          'shellTextBindInterface' => 'Интерфейс привязки',
          'shellTextLogLevel' => 'Уровень логов',
          'shellTextDtlsEnabled' => 'DTLS включен',
          'shellTextResolveInvite' => 'Разрешить инвайт',
          'shellTextResolveProfile' => 'Разрешить профиль',
          'shellTextNotSet' => 'Не задано',
          'shellTextStartSession' => 'Запустить сессию',
          'shellTextSaveProfile' => 'Сохранить профиль',
          'shellTextDeleteProfile' => 'Удалить профиль',
          'shellTextFreshDraft' => 'Новый черновик',
          'shellTextStartSavedProfile' => 'Запустить сохраненный профиль',
          'shellTextExportPortableProfile' =>
            'Экспортировать переносимый профиль',
          'shellTextImportPortableProfile' =>
            'Импортировать переносимый профиль',
          'shellTextPastePortableProfileEnvelope' =>
            'Вставить конверт переносимого профиля',
          'shellTextPreviewOpensBeforeRecordsCreated' =>
            'Предпросмотр открывается до создания любых локальных записей.',
          'shellTextPayloadInvalidOrUnsupported' =>
            'Payload невалиден или не поддерживается.',
          'shellTextProviderAndSource' =>
            ({required Object provider, required Object source}) =>
                'Провайдер: ${provider} · Источник: ${source}',
          'shellTextProviderLabel' =>
            ({required Object provider}) => 'Провайдер: ${provider}',
          'shellTextSourceModeLabel' =>
            ({required Object mode}) => 'Режим источника: ${mode}',
          'shellTextManagedProviderSnapshot' =>
            ({required Object name}) =>
                'Снимок управляемого провайдера: ${name}',
          'shellTextPortableExportSecretWarningDesktop' =>
            'Этот пакет содержит секреты. Относитесь к скопированному тексту, сохраненным файлам и QR-экрану как к учетным данным.',
          'shellTextPortableExportSecretWarningMobile' =>
            'Этот пакет содержит секреты. Относитесь к отправляемому тексту, файлам и QR-экрану как к учетным данным.',
          'shellTextPortableExportSeparateFromRuntimeDesktop' =>
            'Экспортированный пакет остается отдельным от обычного сохранения оболочки и экспорта пакета handoff рантайма.',
          'shellTextPortableExportSeparateFromRuntimeMobile' =>
            'Передача переносимого профиля остается отдельной от обычного сохранения оболочки и экспорта пакета handoff рантайма.',
          'shellTextPortableQrCompactJson' =>
            'QR использует тот же конверт в компактной форме JSON.',
          'shellTextPortableQrUnavailableDesktop' =>
            ({required Object bytes}) =>
                'QR недоступен, потому что пакет превышает поддерживаемый размер QR (${bytes} байт). Экспорт в файл и текст остаются доступны.',
          'shellTextPortableQrUnavailableMobile' =>
            ({required Object bytes}) =>
                'QR недоступен, потому что пакет превышает поддерживаемый размер QR (${bytes} байт). Отправка текста и файла остается доступной.',
          'shellTextPortableImportSecretWarning' =>
            'Этот импортируемый пакет содержит секреты. Подтверждайте только если источник доверенный.',
          'shellTextPortableImportCreatesFreshIdsMobile' =>
            'Импорт создает новые локальные идентификаторы и не запускает рантайм автоматически.',
          'shellTextPortableImportCreatesFreshIdsDesktop' =>
            'Импорт создает новые локальные записи с новыми идентификаторами и не запускает рантайм автоматически.',
          'shellTextScanPortableProfileQr' =>
            'Сканировать QR переносимого профиля',
          'shellTextPointCameraAtPortableProfileQr' =>
            'Наведите камеру на QR-код переносимого профиля.',
          'shellTextTagInput' => ({required Object value}) => 'Ввод: ${value}',
          'shellTextTagAuth' =>
            ({required Object value}) => 'Авторизация: ${value}',
          'shellTextTagBrowser' =>
            ({required Object value}) => 'Браузер: ${value}',
          'shellTextTagFamily' =>
            ({required Object value}) => 'Семейство: ${value}',
          'shellTextBrowserNeedsExternal' =>
            'Этот провайдер требует внешний браузер, когда появляется продолжение проверки.',
          'shellTextBrowserAllowsEmbedded' =>
            'Этот провайдер разрешает встроенный браузер, но хост все равно решает, появится ли браузерная проверка.',
          'shellTextBrowserNotRequired' =>
            'Этот провайдер не сообщает о требуемом браузерном интерфейсе.',
          'shellTextBrowserContinuationMayAppear' =>
            'Для этого провайдера может появиться продолжение в браузере.',
          'shellTextBrowserContinuationNotAdvertised' =>
            'Для этого провайдера сейчас не объявлен режим браузерной проверки.',
          'shellTextDesktopProfileWorkspaceTitle' =>
            'Рабочее пространство профиля',
          'shellTextDesktopUnsavedDraft' => 'Несохраненный черновик',
          'shellTextDesktopSavedProfileWorkspace' =>
            'Рабочее пространство сохраненного профиля',
          'shellTextDesktopSaveProfileFirst' => 'Сначала сохраните профиль',
          'shellTextDesktopStartSessionFromSavedProfile' =>
            'Запустить сессию из этого сохраненного профиля',
          'shellTextDesktopProfileSettings' => 'Настройки профиля',
          'shellTextDesktopChangeSource' => 'Сменить источник',
          'shellTextDesktopChangeSourceSubtitle' =>
            'Переключайтесь между сохраненной записью провайдера и вводом, принадлежащим черновику, только когда профилю нужен другой источник.',
          'shellTextDesktopRuntimeDefaults' => 'Параметры runtime по умолчанию',
          'shellTextDesktopRuntimeDefaultsSubtitle' =>
            'Эти поля применяются, когда профиль запускается на этом устройстве.',
          'shellTextDesktopProfileMaintenance' => 'Обслуживание профиля',
          'shellTextDesktopProfileMaintenanceSubtitle' =>
            'Держите разрушительные действия вне основного потока редактирования.',
          'shellTextDesktopShowMaintenanceActions' =>
            'Показать действия обслуживания',
          'shellTextDesktopDeleteSavedProfileHint' =>
            'Удалите сохраненный профиль, не загромождая строку действий.',
          'shellTextDesktopPortableTransferSubtitle' =>
            'Экспортируйте выбранный сохраненный профиль как явный конверт переноса или просмотрите импорт до создания локальных записей.',
          'shellTextDesktopBrowserHandling' => 'Работа с браузером',
          'shellTextDesktopBrowserHandlingSubtitle' =>
            'Показывайте этот контекст только тогда, когда провайдер может передать управление в браузерную проверку.',
          'shellTextDesktopProfileProviderSettings' =>
            'Настройки провайдера профиля',
          'shellTextDesktopProviderSettingsSupportError' =>
            ({required Object providerName, required Object error}) =>
                'Эта настольная оболочка не может отрисовать схему настроек провайдера для ${providerName}: ${error}. Сохранение и разрешение остаются заблокированы, пока хост не объявит поддерживаемое подмножество схемы.',
          'shellTextDesktopProfileProviderSettingsHelp' =>
            'Сохраненные настройки профиля для выбранного провайдера. Значения только для запроса остаются только в активном черновике.',
          'shellTextDesktopNoSavedProviderRecords' =>
            'Сохраненных записей провайдеров пока нет.',
          'shellTextDirectInput' => 'Прямой ввод',
          'shellTextSavedRecord' => 'Сохраненная запись',
          'shellTextDesktopSavedRecordAttached' =>
            'К этому черновику прикреплена сохраненная запись провайдера.',
          'shellTextDesktopDraftOwnsProviderInput' =>
            'Этот черновик хранит собственный ввод провайдера.',
          'shellTextMobileProfilesTitleBar' => 'Профили',
          'shellTextMobileProviderDetails' => 'Детали провайдера',
          'shellTextMobileProviderDetailsSubtitle' =>
            'Политика браузера, семейства артефактов и подсказки по проверке',
          'shellTextMobileProviderSettingsSection' => 'Настройки провайдера',
          'shellTextMobilePortableTransfer' => 'Переносимый профиль',
          'shellTextMobileProviderSettingsUnsupportedSubtitle' =>
            'Неподдерживаемое подмножество схемы блокирует сохранение и разрешение',
          'shellTextMobileProviderSettingsRetainedSubtitle' =>
            'Обязательные и сохраняемые значения, специфичные для провайдера',
          'shellTextMobileAdvancedRuntimeControls' =>
            'Расширенные настройки рантайма',
          'shellTextMobileAdvancedRuntimeControlsSubtitle' =>
            'Переопределения транспорта, локальная привязка и логирование',
          'shellTextMobilePortableTransferSubtitle' =>
            'Экспортируйте выбранный сохраненный профиль через явный конверт или просмотрите импорт до создания локальных записей.',
          'shellTextMobileProviderSettingsSupportError' =>
            ({required Object providerName, required Object error}) =>
                'Эта мобильная оболочка не может отрисовать схему настроек провайдера для ${providerName}: ${error}. Сохранение и разрешение остаются заблокированы, пока хост не объявит поддерживаемое подмножество схемы.',
          'shellTextMobileProviderSettingsRetainedHelp' =>
            'Настройки, сохраняемые вместе с профилем, остаются в сохраненном профиле. Значения только для запроса остаются только в памяти черновика для немедленного запуска разрешения.',
          'shellTextMobileNoSavedProfilesYetBuildDraft' =>
            'Сохраненных профилей пока нет. Соберите черновик ниже и сохраните его для повторных запусков.',
          'shellTextMobileSavedProfiles' => 'Сохраненные профили',
          'shellTextMobileProviderMode' => 'Режим провайдера',
          'shellTextMobileProviderModeNoManagedProviders' =>
            'Управляемые провайдеры пока недоступны. Используйте пользовательский режим для прямого ввода провайдера или сначала создайте запись провайдера из библиотеки рабочих процессов.',
          'shellTextCustomProvider' => 'Свой провайдер',
          'shellTextManagedProvider' => 'Управляемый провайдер',
          'shellTextMobileManagedModeSummary' =>
            'Управляемый режим копирует значения из сохраненной записи провайдера, а дальнейшие изменения профиля оставляет локальными для этого черновика.',
          'shellTextMobileCustomModeSummary' =>
            'Пользовательский режим позволяет ввести исходный идентификатор провайдера и значения только для запроса без изменения каталога управляемых провайдеров.',
          'shellTextMobileManagedProviderDropdown' => 'Управляемый провайдер',
          'shellTextMobileEditProvider' => 'Редактировать провайдера',
          'shellTextMobileNewProvider' => 'Новый провайдер',
          'shellTextMobileEditSavedReusableProvider' =>
            'Редактируйте этот сохраненный переиспользуемый провайдер.',
          'shellTextMobileFinishSavedReusableProvider' =>
            'Завершите этот сохраненный переиспользуемый провайдер для дальнейшего использования в Профилях.',
          'shellTextMobileCloseProviderEditor' => 'Закрыть редактор провайдера',
          'shellTextMobileNoShippedProviderFamilies' =>
            'Эта сборка пока не объявляет ни одного встроенного семейства провайдеров.',
          'shellTextMobileProviderName' => 'Имя провайдера',
          'shellTextMobileProviderShownInProfiles' =>
            'Показывается в Профилях при выборе сохраненного переиспользуемого провайдера.',
          'shellTextMobileProviderTypeChosenWhenCreated' =>
            'Выбирается при создании этого сохраненного провайдера. Используйте эту панель, чтобы задать имя и просмотреть переиспользуемые настройки.',
          'shellTextMobileProviderConfigSupportError' =>
            ({required Object providerName, required Object error}) =>
                'Эта мобильная оболочка не может отрисовать схему настроек провайдера для ${providerName}: ${error}. Сохранение остается заблокированным, пока хост не объявит поддерживаемое подмножество схемы.',
          'shellTextMobileReusableProviderSettings' =>
            'Переиспользуемые настройки провайдера',
          'shellTextMobileReusableValuesAppliedToProfile' =>
            'Эти переиспользуемые значения применяются, когда этот провайдер используется в профиле.',
          'shellTextMobileSaveProvider' => 'Сохранить провайдера',
          'shellTextMobileSaveAsTemplate' => 'Сохранить как шаблон',
          'shellTextMobileUseInProfileDraft' =>
            'Использовать в черновике профиля',
          'shellTextMobileDeleteProvider' => 'Удалить провайдера',
          'shellTextSelectedType' => 'Выбранный тип',
          'shellTextMobileEditTemplate' => 'Редактировать шаблон',
          'shellTextMobileNewTemplate' => 'Новый шаблон',
          'shellTextMobileEditTemplateStartingValues' =>
            'Редактируйте стартовые значения для будущих провайдеров.',
          'shellTextMobileSaveTemplateStartingPoint' =>
            'Сохраните стартовую точку для будущих провайдеров.',
          'shellTextMobileCloseTemplateEditor' => 'Закрыть редактор шаблона',
          'shellTextMobileTemplateName' => 'Имя шаблона',
          'shellTextMobileTemplateShownWhenChoosing' =>
            'Показывается при выборе стартовой точки для новых провайдеров.',
          'shellTextMobileTemplateTypeChosenWhenCreated' =>
            'Выбирается при создании этого шаблона. Используйте эту панель, чтобы задать имя и просмотреть переиспользуемые стартовые значения.',
          'shellTextMobileReusableValuesPrefillProvider' =>
            'Эти значения предзаполняют нового провайдера при использовании шаблона.',
          'shellTextMobileSaveTemplate' => 'Сохранить шаблон',
          'shellTextMobileUseTemplate' => 'Использовать шаблон',
          'shellTextMobileDeleteTemplate' => 'Удалить шаблон',
          'shellTextDesktopProviderRecord' => 'Запись провайдера',
          'shellTextDesktopNewProviderRecord' => 'Новая запись провайдера',
          'shellTextDesktopEditReusableProviderRecord' =>
            'Редактируйте одну переиспользуемую запись провайдера. Прикрепленное семейство показано ниже и остается здесь только для чтения.',
          'shellTextDesktopCreateReusableProviderRecord' =>
            'Создайте одну переиспользуемую запись провайдера. Отдельно выберите семейство, затем редактируйте параметры записи ниже.',
          'shellTextDesktopRecordParameters' => 'Параметры записи',
          'shellTextDesktopParametersFor' =>
            ({required Object providerTitle}) =>
                'Параметры для ${providerTitle}',
          'shellTextDesktopChooseProviderFamilyFirst' =>
            'Сначала выберите семейство провайдера в отдельном списке. После этого здесь появятся параметры записи.',
          'shellTextDesktopEditReusableParametersFor' =>
            ({required Object providerTitle}) =>
                'Редактируйте переиспользуемые параметры, сохраненные в этой записи для ${providerTitle}. Это не меняет само семейство.',
          'shellTextDesktopUseInProfileDraft' =>
            'Использовать в черновике профиля',
          'shellTextDesktopNewRecord' => 'Новая запись',
          'shellTextDesktopRecordName' => 'Имя записи',
          'shellTextDesktopRecordNameHelp' =>
            'Сначала задайте имя этой сохраненной записи провайдера. Выбор семейства и параметры записи находятся ниже.',
          'shellTextDesktopAttachedFamily' => 'Прикрепленное семейство',
          'shellTextDesktopAttachedFamilyHelp' =>
            'Семейства выбираются в отдельном списке. Выбранное семейство прикрепляется к этой записи и описывается здесь.',
          'shellTextDesktopFamilyCharacteristics' => 'Характеристики семейства',
          'shellTextDesktopFamilyCharacteristicsHelp' =>
            'Характеристики только для чтения из выбранного семейства и текущего хост-оверлея.',
          'shellTextDesktopProviderRecordSupportError' =>
            ({required Object providerName, required Object error}) =>
                'Эта настольная оболочка не может отрисовать схему настроек провайдера для ${providerName}: ${error}. Сохранение остается заблокированным, пока хост не объявит поддерживаемое подмножество схемы.',
          'shellTextDesktopNoFamilyAttachedYet' =>
            'Семейство пока не прикреплено',
          'shellTextDesktopSelectedFamily' => 'Выбранное семейство',
          'shellTextDesktopOpenFamilyChooserFirst' =>
            'Откройте отдельный список семейств, прежде чем продолжить работу с этой записью провайдера.',
          'shellTextDesktopFamilyAttachedToRecord' =>
            ({required Object providerTitle}) =>
                '${providerTitle} прикреплено к этой записи, пока вы намеренно не измените его в списке семейств.',
          'shellTextDesktopShippedByApp' => 'Поставляется приложением',
          'shellTextDesktopHostOverlayAvailable' => 'Host overlay: доступен',
          'shellTextDesktopHostOverlayUnavailable' =>
            'Host overlay: недоступен',
          'shellTextDesktopUseActionStripToChooseFamily' =>
            'Используйте панель действий выше, чтобы выбрать семейство. Здесь семейства только для чтения.',
          'shellTextDesktopFamiliesReadonlyEditBelow' =>
            'Здесь семейства остаются только для чтения. Меняйте прикрепленное семейство через панель действий выше, а параметры этой записи редактируйте ниже.',
          'shellTextDesktopChooseFamily' => 'Выбрать семейство',
          'shellTextDesktopSaveDraft' => 'Сохранить черновик',
          'shellTextDesktopSaveRecord' => 'Сохранить запись',
          'shellTextDesktopReadOnlyFamily' => 'Семейство только для чтения',
          'shellTextDesktopAttachedFamilyCardHelp' =>
            'Эта карточка описывает прикрепленное семейство. Ниже показаны редактируемые параметры записи.',
          'shellTextDesktopNoEditableParametersYet' =>
            'Редактируемых параметров пока нет',
          'shellTextDesktopNoEditableParameters' =>
            'Редактируемых параметров нет',
          'shellTextDesktopEditableParametersReady' =>
            'Редактируемые параметры готовы',
          'shellTextDesktopNoSavedProfilesYetShort' =>
            'Сохраненных профилей пока нет.',
          'shellTextDesktopNoShippedProviderFamilies' =>
            'Эта сборка пока не объявляет ни одного встроенного семейства провайдеров.',
          'shellTextDesktopNoEditableRecordParameters' =>
            ({required Object providerTitle}) =>
                '${providerTitle} не имеет редактируемых параметров записи в этой настольной оболочке.',
          'shellTextDesktopSavedProfilesLibraryTitle' => 'Сохраненные профили',
          'shellTextDesktopSavedProfilesLibrarySubtitle' =>
            'Осознанно просматривайте сохраненные рабочие пространства оператора, а затем возвращайтесь в активный редактор, не оставляя основной путь навсегда разделенным.',
          'shellTextDesktopReturnPathExplicitTitle' =>
            'Путь возврата остается явным',
          'shellTextDesktopReturnPathExplicitMessage' =>
            'Выбор сохраненного профиля обновляет активный рабочий процесс и закрывает эту вторичную поверхность.',
          'shellTextDesktopProviderRecordsLibraryTitle' => 'Записи провайдеров',
          'shellTextDesktopProviderRecordsLibrarySubtitle' =>
            'Создайте переиспользуемую запись провайдера или откройте уже сохраненную.',
          'shellTextDesktopRecordsSeparateFromFamiliesTitle' =>
            'Записи отделены от семейств',
          'shellTextDesktopRecordsSeparateFromFamiliesMessage' =>
            'Создайте здесь запись, затем выберите ее семейство в отдельном списке семейств. Откройте существующую запись, чтобы продолжить ее редактирование.',
          'shellTextDesktopNoProviderRecordsYet' =>
            'Записей провайдеров пока нет. Создайте запись, чтобы выбрать семейство и сохранить переиспользуемые параметры.',
          'shellTextDesktopNewFromPresetSubtitle' =>
            'Начинайте с подготовленной заготовки провайдера только когда намеренно этого хотите.',
          'shellTextDesktopPresetBootstrapExplicitTitle' =>
            'Запуск из пресета остается явным',
          'shellTextDesktopPresetBootstrapExplicitMessage' =>
            'Недоступные пресеты остаются здесь видимыми и честными, но больше не занимают рабочее пространство провайдера по умолчанию.',
          'shellTextDesktopProviderFamiliesSubtitle' =>
            'Выберите здесь поставляемое семейство, затем вернитесь в редактор записи провайдера.',
          'shellTextDesktopFamiliesReadonlyHereTitle' =>
            'Здесь семейства только для чтения',
          'shellTextDesktopFamiliesReadonlyHereMessage' =>
            'Этот список принадлежит встроенной оболочке. Выберите здесь семейство, затем редактируйте выбранную запись в редакторе записи.',
          'shellTextDesktopUsePreset' => 'Использовать пресет',
          'shellTextLaunched' => 'запущен',
          'shellTextDesktopSavedProfilesRouteDetail' =>
            'Выберите сохраненный профиль или вернитесь в активный редактор профиля, не теряя текущий черновик.',
          'shellTextDesktopManagedRecordsTitle' => 'Управляемые записи',
          'shellTextDesktopManagedRecordsRouteDetail' =>
            'Выберите переиспользуемую управляемую запись для активного черновика профиля или вернитесь без изменения черновика.',
          'shellTextDesktopProviderRecordsRouteDetail' =>
            'Создайте здесь запись провайдера или заново откройте существующую для редактирования. Семейства остаются в отдельном списке выбора.',
          'shellTextDesktopPresetBootstrapTitle' => 'Запуск из пресета',
          'shellTextDesktopPresetBootstrapRouteDetail' =>
            'Запустите рабочий процесс провайдера из подготовленного пресета, затем вернитесь в маршрут редактора управляемого провайдера.',
          'shellTextDesktopProviderFamiliesRouteDetail' =>
            'Выберите здесь встроенное семейство только для чтения, затем вернитесь в редактор записи провайдера.',
          'shellTextDesktopWorkflowReadiness' => 'Готовность рабочего процесса',
          'shellTextDesktopTunnelModesReadySummary' =>
            ({required Object ready, required Object total}) =>
                '${ready}/${total} туннельных режимов готовы',
          'shellTextDesktopPlatformTunnelSummary' =>
            'Сводка платформенных туннельных режимов',
          'shellTextDesktopResolutionsSessionsCompact' =>
            ({required Object resolutions, required Object sessions}) =>
                '${resolutions} резолюций · ${sessions} сессий',
          'shellTextDesktopSupportContextPinned' =>
            'Контекст поддержки закреплен',
          'shellTextDesktopSupportAttentionRequired' =>
            'Требуется внимание поддержки',
          'shellTextDesktopSupportContextWarmingUp' =>
            'Контекст поддержки прогревается',
          'shellTextDesktopLiveWorkActive' => 'Текущая работа активна',
          'shellTextDesktopSupportNote' => 'Заметка поддержки',
          'shellTextDesktopSupportBlockedDetail' =>
            'Локальный хост заблокирован или несовместим. Держите путь восстановления видимым из основного рабочего процесса.',
          'shellTextDesktopSupportBootingDetail' =>
            'Согласование с хостом все еще идет. Диагностика остается в одном действии, не перехватывая всю оболочку.',
          'shellTextDesktopSupportReadyLiveDetail' =>
            'Используйте Текущую работу, чтобы просмотреть текущий рантайм, не позволяя поверхности поддержки перехватывать всю оболочку.',
          'shellTextDesktopSupportReadyIdleDetail' =>
            'Используйте Диагностику или Текущую работу, когда нужна более глубокая проверка. Основной рабочий процесс остается главным.',
          'shellTextDesktopInspector' => 'Инспектор',
          'shellTextDesktopInspectorDiagnosticsSubtitle' =>
            'Диагностика и детали платформенного туннеля остаются вторичными по отношению к основному рабочему полотну.',
          'shellTextDesktopInspectorActivitySubtitle' =>
            'Текущие резолюции и сессии остаются доступными по запросу, не перехватывая всю оболочку.',
          'shellTextDesktopTunnelDetail' => 'Детали туннеля',
          'shellTextDesktopPlatformTunnelModes' =>
            'Платформенные туннельные режимы',
          'shellTextDesktopFailClosedCompactUntilStartup' =>
            'Проверки платформенного туннеля в fail-closed режиме остаются свернутыми, пока вы явно не проверите запуск.',
          'shellTextDesktopFailClosedSectionCompactUntilStartup' =>
            'Подключенный хост сообщает только о платформенных туннельных режимах в fail-closed состоянии, поэтому этот раздел остается компактным, пока вы явно не проверите запуск.',
          'shellTextDesktopTypedHostTunnelSummary' =>
            'Настольная оболочка читает типизированные возможности туннеля и этапы запуска от хоста, а не угадывает поддержку системной маршрутизации по ОС или пакету приложения.',
          'shellTextDesktopNoPlatformTunnelModesReported' =>
            'Подключенный хост не сообщил ни о каких платформенных туннельных режимах рабочего стола.',
          'shellTextDesktopUseDiagnosticsForReportedModes' =>
            'Используйте Диагностика -> Детали туннеля, чтобы просмотреть этапы запуска и fail-closed результаты для объявленных режимов.',
          'shellTextDesktopAllModesFailClosedLatestEvidence' =>
            'Все объявленные туннельные режимы все еще остаются fail-closed; откройте Диагностика -> Детали туннеля для просмотра последних данных о запуске.',
          'shellTextDesktopAllModesFailClosedTestStartup' =>
            'Все объявленные туннельные режимы сейчас находятся в fail-closed состоянии. Используйте Диагностика -> Детали туннеля, когда захотите явно проверить запуск.',
          'shellTextDesktopHostModeAvailable' =>
            'Хост сообщает, что этот режим доступен.',
          'shellTextDesktopHostModeUnavailable' =>
            'Хост сообщает, что этот режим недоступен.',
          'shellTextDesktopNoStartupRequestYet' =>
            'Запроса на запуск пока нет. Используйте типизированный контракт хоста, чтобы проверить fail-closed сценарий.',
          'shellTextDesktopNoSessionsYet' =>
            'Активных или недавних сессий пока нет.',
          'shellTextDesktopEventStreamSubtitle' =>
            'Типизированные переходы состояний и обновления проверок из /v1/events.',
          'shellTextDesktopWorkflowAssuranceBooting' =>
            'Оболочка переподключается к локальному хосту. Сохраняйте поверхность редактора стабильной, пока согласование не завершится.',
          'shellTextDesktopWorkflowAssuranceBlocked' =>
            'Локальный хост заблокирован или несовместим. Держите путь восстановления видимым из основной рабочей поверхности.',
          'shellTextDesktopWorkflowAssuranceReadyLive' =>
            'Локальный хост готов. Сохраняйте текущий рабочий процесс главным, пока детали живого рантайма остаются в одном шаге.',
          'shellTextDesktopWorkflowAssuranceReadyIdle' =>
            'Локальный хост готов. Рутинная поддержка остается компактной, чтобы активный рабочий процесс сохранял визуальный приоритет.',
          'shellTextContinueAfterBrowserStep' =>
            'Продолжить после шага в браузере',
          'shellTextContinueInBrowser' => 'Продолжить в браузере',
          'shellTextProviderFamilyLabel' =>
            ({required Object familyTitle}) =>
                'Семейство провайдера: ${familyTitle}',
          'shellTextAppOwnedManagedRecord' => 'Управляемая запись приложения',
          'shellTextSelectedFamily' => 'Выбранное семейство',
          'shellTextMobileOpenBrowser' => 'Открыть браузер',
          'shellTextMobileContinueInApp' => 'Продолжить в приложении',
          'shellTextChallengeContinuationCancelled' =>
            ({required Object challengeId}) =>
                'Продолжение проверки ${challengeId} во встроенном браузере отменено, проверка помечена как отмененная.',
          'shellTextChallengeContinuationFailed' =>
            ({required Object challengeId, required Object error}) =>
                'Продолжение проверки ${challengeId} во встроенном браузере завершилось ошибкой: ${error}. Проверка помечена как отмененная.',
          'shellTextMobileEditProfile' => 'Редактировать профиль',
          'shellTextMobileSelectedForHome' => 'Выбран для Главной',
          'shellTextMobileTurnOnVpn' => 'Включить VPN',
          'shellTextMobileTurnOffVpn' => 'Выключить VPN',
          'shellTextMobileProvidersTitle' => 'Провайдеры',
          'shellTextMobileProvidersSubtitle' =>
            'Выберите сохраненный переиспользуемый провайдер или добавьте новый для Профилей.',
          'shellTextMobileAddProvider' => 'Добавить провайдера',
          'shellTextMobileBackToProviders' => 'Назад к провайдерам',
          'shellTextMobileNoProvider' => 'Провайдер не выбран',
          'shellTextMobileInputConfigured' => 'ввод настроен',
          'shellTextSupportTitle' => 'Поддержка',
          'shellTextSupportSubtitle' =>
            'Активность, ошибки, логи и диагностика остаются явными, но вторичными по отношению к основному VPN-потоку.',
          'shellTextRoutingTitle' => 'Маршрутизация',
          'shellTextRoutingSubtitle' =>
            'Выберите профиль VPN и охват приложений.',
          'shellTextRoutingProfile' => 'Профиль маршрутизации',
          'shellTextRoutingProfileStandard' => 'Стандартный',
          _ => null,
        } ??
        switch (path) {
          'shellTextRoutingProfileDevelopmentWifi' => 'Development Wi-Fi',
          'shellTextRoutingProfileStandardDescription' =>
            'Использовать обычное поведение маршрутизации системного VPN Android для этого режима.',
          'shellTextRoutingProfileDevelopmentWifiDescription' =>
            'Сохранить активную локальную Wi-Fi сеть вне VPN, чтобы инструменты разработки оставались доступными, пока VPN активен.',
          'shellTextAppScope' => 'Охват приложений',
          'shellTextModeScope' =>
            ({required Object modeLabel}) => '${modeLabel}: охват',
          'shellTextAllApps' => 'Все приложения',
          'shellTextIncludedApps' => 'Включенные приложения',
          'shellTextExcludedApps' => 'Исключенные приложения',
          'shellTextRoutingScopeSummary' =>
            ({required Object selectedCount, required Object totalCount}) =>
                'Выбрано ${selectedCount} из ${totalCount} установленных приложений.',
          'shellTextSearchApps' => 'Поиск приложений',
          'shellTextRoutingVisibleAppsSummary' =>
            ({
              required Object visibleCount,
              required Object totalCount,
              required Object selectedCount,
            }) =>
                'На экране ${visibleCount} из ${totalCount}; выбрано ${selectedCount} видимых.',
          'shellTextBulkActions' => 'Действия',
          'shellTextSelectVisibleApps' => 'Выбрать видимые',
          'shellTextClearVisibleApps' => 'Снять видимые',
          'shellTextAllInstalledAppsUseVpnPath' =>
            'Все установленные приложения будут использовать системный VPN-путь Android для этого мобильного режима.',
          'shellTextRetryAppScan' => 'Повторить сканирование приложений',
          'shellTextNoInstalledAppsReported' =>
            'Android shell bridge не сообщил об установленных приложениях.',
          'shellTextNoInstalledAppsMatchSearch' =>
            'Для этого поиска нет совпадающих установленных приложений.',
          'shellTextHomeNoSavedProfilesYet' => 'Сохраненных профилей пока нет',
          'shellTextHomeNoSavedProfilesMessage' =>
            'Сначала создайте или импортируйте профиль, затем вернитесь сюда для быстрого переключения VPN.',
          'shellTextCurrentProfile' => 'Текущий профиль',
          'shellTextListeningOn' =>
            ({required Object address}) => 'Слушает на ${address}',
          'shellTextCurrentMode' => 'Текущий режим',
          'shellTextNoMobileTunnelModeAdvertised' =>
            'Подключенный хост пока не объявил мобильный туннельный режим.',
          'shellTextExecutionPath' => 'Путь выполнения',
          'shellTextProviderStepTone' => 'Шаг провайдера',
          'shellTextConnectionLiveTone' => 'Соединение активно',
          'shellTextSetupNeededTone' => 'Требуется настройка',
          'shellTextMainActionTone' => 'Главное действие',
          'shellTextFinishProviderValidation' =>
            'Завершите проверку провайдера',
          'shellTextVpnIsOn' => 'VPN включен',
          'shellTextProfileRequired' => 'Требуется профиль',
          'shellTextVpnIsOff' => 'VPN выключен',
          'shellTextContinueProviderFlowInApp' =>
            'Продолжите шаг провайдера во встроенном браузере, прежде чем VPN сможет запуститься.',
          'shellTextOpenRequiredBrowserStepFromHome' =>
            'Откройте обязательный шаг в браузере с Главной, затем вернитесь сюда и подтвердите завершение до запуска VPN.',
          'shellTextDisconnectCurrentMobileVpnPath' =>
            'Отсюда отключите текущий путь мобильного VPN.',
          'shellTextChooseOrFinishProfileBeforeStartingVpn' =>
            'Выберите или завершите профиль в Профилях перед запуском текущего пути мобильного VPN.',
          'shellTextStartCurrentMobileVpnPath' =>
            'Запустите текущий путь мобильного VPN отсюда.',
          'shellTextContinueInProfiles' => 'Продолжить в Профилях',
          'shellTextChallengeKind' =>
            ({required Object kind}) => 'Проверка: ${kind}',
          'shellTextIveCompletedIt' => 'Я завершил',
          'shellTextCancelChallenge' => 'Отменить проверку',
          'shellTextNeedDeeperDetail' => 'Нужна более глубокая детализация?',
          'shellTextResolutionsSessionsSummary' =>
            ({
              required Object resolutions,
              required Object sessions,
              required Object liveSummary,
            }) =>
                'Резолюции ${resolutions} · Сессии ${sessions} · ${liveSummary}',
          'shellTextNoStartupRequestYetShort' =>
            'Запроса на запуск пока не было.',
          'shellTextRoutingUnavailableForMode' =>
            'Маршрутизация недоступна для этого режима',
          'shellTextRoutingUnavailableMessage' =>
            'Только мобильные режимы с поддержкой маршрутизации по приложениям показывают эту поверхность. Выберите другой режим на Главной, если хост его объявляет.',
          'shellTextNoSavedProvidersYet' => 'Сохраненных провайдеров пока нет',
          'shellTextNoSavedProvidersMessage' =>
            'Добавьте провайдера, затем переиспользуйте его из Профилей.',
          'shellTextTypeLabel' =>
            ({required Object familyTitle}) => 'Тип: ${familyTitle}',
          'shellTextUsedInProfiles' => 'Используется в Профилях',
          'shellTextCreateProvider' => 'Создать провайдера',
          'shellTextCreateProviderChooseType' =>
            'Выберите тип провайдера и настройте нового сохраненного провайдера.',
          'shellTextCreateProviderUseTemplate' =>
            'Используйте шаблон для предзаполнения нового провайдера. Шаблоны - это стартовые точки, а не сохраненные провайдеры.',
          'shellTextProviderTypes' => 'Типы провайдеров',
          'shellTextNoShippedProviderTypesYet' =>
            'Эта сборка пока не объявляет никаких встроенных типов провайдеров.',
          'shellTextSearchTemplates' => 'Поиск шаблонов',
          'shellTextMyTemplates' => 'Мои шаблоны',
          'shellTextNoSavedTemplatesYet' =>
            'Сохраненных шаблонов пока нет. Сохраните провайдера как шаблон, чтобы переиспользовать его здесь.',
          'shellTextNoSavedTemplatesMatchSearch' =>
            'Нет сохраненных шаблонов, подходящих под текущий поиск.',
          'shellTextPrefillsNewProviders' => 'Предзаполняет новых провайдеров',
          'shellTextShippedTemplates' => 'Встроенные шаблоны',
          'shellTextNoShippedTemplatesMatchSearch' =>
            'Нет встроенных шаблонов, подходящих под текущий поиск.',
          'shellTextStartingPointForNewProviders' =>
            'Стартовая точка для новых провайдеров',
          'shellTextReadOnlyShippedTemplate' =>
            'Встроенный шаблон только для чтения',
          'shellTextActivityPageSubtitle' =>
            'Просматривайте резолюции провайдера и состояние сессий, не загромождая основной рабочий процесс.',
          'shellTextResolutionsCount' =>
            ({required Object count}) => 'Резолюции (${count})',
          'shellTextSessionsCount' =>
            ({required Object count}) => 'Сессии (${count})',
          'shellTextDiagnosticsPageSubtitle' =>
            'Подробная готовность хоста, детали платформенного туннеля и недавние типизированные события.',
          'shellTextEventsCount' =>
            ({required Object count}) => 'События (${count})',
          'shellTextWaitingForMobileHostBridge' =>
            'Ожидание согласования моста мобильного хоста.',
          'shellTextGuiBuildTag' => ({required Object label}) => 'GUI ${label}',
          'shellTextHostBuildTag' =>
            ({required Object label}) => 'Host ${label}',
          'shellTextContractTag' =>
            ({required Object version}) => 'Контракт ${version}',
          'shellTextReconnect' => 'Переподключить',
          'shellTextRefresh' => 'Обновить',
          'shellTextResolutionsTitle' => 'Резолюции',
          'shellTextResolutionsSubtitle' =>
            'Сначала разрешите инвайт, затем используйте набор действий, ограниченный возможностями, чтобы запустить на этом устройстве, экспортировать handoff или открыть нативные цели провайдера.',
          'shellTextNoProviderResolutionsYet' =>
            'Резолюций провайдера пока нет.',
          'shellTextSystemTunnelBannerText' =>
            'Этот мобильный срез отображает типизированные возможности хоста и результаты этапов запуска для объявленных платформенных режимов. Используйте элементы управления ниже, чтобы запустить или отключить поддерживаемые пути системного туннеля.',
          'shellTextNoPlatformTunnelModesReported' =>
            'Подключенный мобильный хост не сообщил ни о каких платформенных туннельных режимах.',
          'shellTextAvailableLowercase' => 'доступно',
          'shellTextUnavailableLowercase' => 'недоступно',
          'shellTextDisconnectVpn' => 'Отключить VPN',
          'shellTextRequestStartup' => 'Запросить запуск',
          'shellTextNoStartupRequestYet' =>
            'Запроса на запуск пока нет. Используйте типизированный контракт мобильного хоста, чтобы проверить fail-closed сценарий.',
          'shellTextTurnCredentialsSummary' =>
            ({required Object address, required Object username}) =>
                'TURN ${address} | ${username}',
          'shellTextFailureSummary' =>
            ({required Object stage, required Object message}) =>
                '${stage}: ${message}',
          'shellTextMoreChallengeActions' => 'Больше действий проверки',
          'shellTextMoreResolutionActions' => 'Больше действий резолюции',
          'shellTextStartOnThisDevice' => 'Запустить на этом устройстве',
          'shellTextShareHandoff' => 'Поделиться handoff',
          'shellTextOpenRoom' => 'Открыть комнату',
          'shellTextOpenCamera' => 'Открыть камеру',
          'shellTextOpenArchive' => 'Открыть архив',
          'shellTextCopyHandoff' => 'Копировать handoff',
          'shellTextCancelResolution' => 'Отменить резолюцию',
          'shellTextSessionsTitle' => 'Сессии',
          'shellTextNoMobileSessionsYet' =>
            'Активных или недавних мобильных сессий пока нет.',
          'shellTextSessionListenConnections' =>
            ({required Object listen, required Object connections}) =>
                'слушает ${listen} | соединения ${connections}',
          'shellTextSessionUpdated' =>
            ({required Object timestamp, required Object sessionId}) =>
                'Обновлено ${timestamp} | сессия ${sessionId}',
          'shellTextMoreSessionActions' => 'Больше действий сессии',
          'shellTextStopSession' => 'Остановить сессию',
          'shellTextExportDiagnostics' => 'Экспортировать диагностику',
          'shellTextEventStream' => 'Поток событий',
          'shellTextEventStreamSubtitle' =>
            'Типизированные переходы состояния и обновления проверок от моста мобильного хоста.',
          'shellTextNoEventsYet' => 'Событий пока нет.',
          'shellTextResetNeeded' => 'Требуется сброс',
          'shellTextHostReady' => 'Хост готов',
          'shellTextHostIncompatible' => 'Хост несовместим',
          'shellTextHostBlocked' => 'Хост заблокирован',
          'shellTextConnecting' => 'Подключение',
          'shellTextMobileHostReady' => 'Мобильный хост готов',
          'shellTextMobileHostIncompatible' => 'Мобильный хост несовместим',
          'shellTextMobileHostBlocked' => 'Мобильный хост заблокирован',
          'shellTextConnectingToMobileHost' => 'Подключение к мобильному хосту',
          'shellTextSatisfiedPrerequisites' =>
            ({required Object prerequisites}) =>
                'Выполненные предусловия: ${prerequisites}',
          'shellTextMissingPrerequisite' =>
            ({required Object prerequisite}) =>
                'Отсутствует предусловие: ${prerequisite}',
          'shellTextMobileHostModeAvailable' =>
            'Мобильный хост сообщает, что этот режим доступен.',
          'shellTextMobileHostModeUnavailable' =>
            'Мобильный хост сообщает, что этот режим недоступен.',
          'shellTextPlatformTunnelReady' =>
            ({required Object modeLabel}) =>
                '${modeLabel} достиг готового состояния для туннельного пути мобильного хоста.',
          'shellTextPlatformTunnelReadyWithRoutingProfile' =>
            ({required Object modeLabel, required Object profileLabel}) =>
                '${modeLabel} готов с профилем маршрутизации ${profileLabel}.',
          'shellTextStartupBlockedAt' =>
            ({required Object stageLabel}) =>
                'Запуск заблокирован на этапе ${stageLabel}.',
          'shellTextUnknownStage' => 'Неизвестный этап',
          'shellTextNoMobileTunnelModeSelected' =>
            'Сейчас не выбран ни один мобильный туннельный режим.',
          'shellTextAndroidSystemVpnMode' => 'Режим системного VPN Android',
          'shellTextAppleNetworkExtensionMode' =>
            'Режим сетевого расширения Apple',
          'shellTextWindowsWintunMode' => 'Режим Windows Wintun',
          'shellTextLinuxTunMode' => 'Режим Linux TUN',
          'shellTextPerAppRoutingUnavailable' =>
            'Маршрутизация по приложениям недоступна для этого мобильного режима.',
          'shellTextRestartVpnToApplyRoutingProfile' =>
            ({required Object modeLabel}) =>
                'Перезапустите ${modeLabel}, чтобы применить выбранный профиль маршрутизации.',
          'shellTextDevelopmentWifiRoutingUnavailableForHost' =>
            ({required Object modeLabel}) =>
                '${modeLabel} не объявляет профиль маршрутизации Development Wi-Fi для этого хоста.',
          'shellTextDevelopmentWifiRoutingSavedButUnsupported' =>
            'Сохраненное предпочтение Development Wi-Fi не поддерживается текущим хостом. Переключитесь обратно на стандартный профиль или переподключитесь к совместимому хосту.',
          'shellTextRoutingSummaryWithProfile' =>
            ({required Object profileLabel, required Object scopeSummary}) =>
                '${profileLabel}. ${scopeSummary}',
          'shellTextScopeAllInstalledApps' =>
            'Область: все установленные приложения.',
          'shellTextScopeIncludedAppsEmpty' =>
            'Область: включенные приложения, но приложения пока не выбраны.',
          'shellTextScopeOnlySelectedApps' =>
            ({required Object count}) =>
                'Область: только ${count} выбранных приложений.',
          'shellTextScopeExcludedAppsEmpty' =>
            'Область: исключенные приложения, но приложения пока не выбраны.',
          'shellTextScopeAllExceptSelectedApps' =>
            ({required Object count}) =>
                'Область: все приложения кроме ${count} выбранных приложений.',
          'shellTextWireGuardNativeOverTurnDatagram' =>
            'WireGuard native поверх TURN datagram',
          'shellTextWireGuardNativeOverTurnDtls' =>
            'WireGuard native поверх TURN DTLS overlay',
          'shellTextWireGuardNativeOverWebRtc' =>
            'WireGuard native поверх WebRTC data channel',
          'shellTextCustomOverlayOverTurnDatagram' =>
            'Custom packet overlay поверх TURN datagram',
          'shellTextCustomOverlayOverTurnDtls' =>
            'Custom packet overlay поверх TURN DTLS overlay',
          'shellTextCustomOverlayOverWebRtc' =>
            'Custom packet overlay поверх WebRTC data channel',
          'shellTextProxyCoreOverTurnDatagram' =>
            'Proxy core adapter поверх TURN datagram',
          'shellTextProxyCoreOverTurnDtls' =>
            'Proxy core adapter поверх TURN DTLS overlay',
          'shellTextProxyCoreOverWebRtc' =>
            'Proxy core adapter поверх WebRTC data channel',
          'shellTextTrustTunnelOverTurnDatagram' =>
            'TrustTunnel native поверх TURN datagram',
          'shellTextTrustTunnelOverTurnDtls' =>
            'TrustTunnel native поверх TURN DTLS overlay',
          'shellTextTrustTunnelOverWebRtc' =>
            'TrustTunnel native поверх WebRTC data channel',
          'shellTextOwnedBrowserMissingMetadata' =>
            'Эта проверка не объявляет метаданные браузера приложения, необходимые для продолжения внутри приложения.',
          'shellTextOwnedBrowserMissingUrl' =>
            'Эта проверка не предоставляет URL встроенного браузера.',
          'shellTextOwnedBrowserNoEvidence' =>
            'Сессия встроенного браузера не предоставила пригодных данных для продолжения.',
          'shellTextOwnedBrowserTitle' =>
            ({required Object provider}) => 'Проверка провайдера ${provider}',
          'shellTextOwnedBrowserOpenInvite' => 'Открыть инвайт',
          'shellTextOwnedBrowserCollecting' => 'Сбор...',
          'shellTextOwnedBrowserContinue' => 'Продолжить',
          'shellTextOwnedBrowserFallbackPrompt' =>
            'Завершите шаг в браузере в этой встроенной сессии, затем продолжите.',
          'shellTextOwnedBrowserHideKeyboard' => 'Скрыть клавиатуру',
          'shellTextPlatformTunnelBlockedBase' =>
            ({required Object modeLabel, required Object stageLabel}) =>
                '${modeLabel} заблокирован на этапе ${stageLabel}.',
          'shellTextPlatformTunnelBlockedMissingPrerequisite' =>
            ({required Object prerequisiteLabel}) =>
                ' Отсутствует предусловие: ${prerequisiteLabel}.',
          'shellTextMobileNoReusableSettingsYetNamedProviderUnnamed' =>
            'Переиспользуемых настроек пока нет. Сохраните это как именованный провайдер для Профилей.',
          'shellTextMobileNoReusableSettingsYetNamedProviderNamed' =>
            ({required Object providerTitle}) =>
                'Переиспользуемых настроек пока нет. Сохраните ${providerTitle} как именованный провайдер для Профилей.',
          'shellTextMobileNoReusableSettingsYetTemplateUnnamed' =>
            'Переиспользуемых настроек пока нет. Сохраните этот шаблон как именованную стартовую точку.',
          'shellTextMobileNoReusableSettingsYetTemplateNamed' =>
            ({required Object providerTitle}) =>
                'Переиспользуемых настроек пока нет. Сохраните ${providerTitle} как именованную стартовую точку.',
          'shellTextDesktopCompactPlatformTunnelCapabilitySummaryAvailable' =>
            ({required Object modeLabel}) =>
                '${modeLabel} доступен для подключенного хоста.',
          'shellTextDesktopCompactPlatformTunnelCapabilitySummaryUnavailable' =>
            ({required Object modeLabel}) => '${modeLabel} недоступен',
          'shellTextDesktopCompactPlatformTunnelCapabilitySummaryMissingPrerequisite' =>
            ({required Object missingPrerequisite}) =>
                ', потому что ${missingPrerequisite} все еще отсутствует.',
          'shellTextDesktopCompactPlatformTunnelCapabilitySummaryUnavailableSuffix' =>
            ' для подключенного хоста.',
          'shellTextDesktopCompactPlatformTunnelStatusLabelUnavailable' =>
            ({required Object modeLabel}) => '${modeLabel} недоступен',
          'shellTextDesktopCompactPlatformTunnelStatusLabelMissing' =>
            ({required Object modeLabel, required Object missing}) =>
                '${modeLabel}: отсутствует ${missing}',
          'shellTextDesktopPlatformTunnelResultSummaryReady' =>
            ({required Object modeLabel}) =>
                '${modeLabel} достиг готового состояния для туннельного пути настольного хоста.',
          'shellTextDesktopPlatformTunnelResultSummaryBlocked' =>
            ({required Object stageLabel}) =>
                'Запуск заблокирован на этапе ${stageLabel}.',
          'shellTextStateStarting' => 'запуск',
          'shellTextStateChallengeRequired' => 'требуется проверка',
          'shellTextStateReady' => 'готово',
          'shellTextStateRetrying' => 'повтор',
          'shellTextStateStopping' => 'остановка',
          'shellTextStateStopped' => 'остановлено',
          'shellTextStateFailed' => 'сбой',
          'shellTextStateResolved' => 'разрешено',
          'shellTextStateCancelled' => 'отменено',
          'shellTextStateExpired' => 'истекло',
          'shellTextExecutionOwnerHost' => 'хост',
          'shellTextExecutionOwnerShellLocal' => 'локальная оболочка',
          'shellTextExecutionOwnerShellExternal' => 'внешняя оболочка',
          'shellTextModeSummaryWithoutExecutionPath' =>
            ({required Object modeLabel, required Object routingSummary}) =>
                '${modeLabel}. ${routingSummary}',
          'shellTextModeSummaryWithExecutionPath' =>
            ({
              required Object modeLabel,
              required Object routingSummary,
              required Object executionPath,
            }) =>
                '${modeLabel}. ${routingSummary} Путь выполнения: ${executionPath}.',
          'shellTextExportExpiry' =>
            ({required Object timestamp}) =>
                'Срок действия экспорта ${timestamp}',
          'shellTextExportExpiryWithSource' =>
            ({required Object timestamp, required Object source}) =>
                'Срок действия экспорта ${timestamp} через ${source}',
          _ => null,
        };
  }
}
