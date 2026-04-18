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
  String get appDesktopTitle => 'vk-turn-proxy desktop shell';
  @override
  String get appDesktopReferencesTitle =>
      'vk-turn-proxy desktop shell references';
  @override
  String get appMobileTitle => 'vk-turn-proxy mobile shell';
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
  String get commonWorkflows => 'Workflow';
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
  String get commonOpenWorkflowsTooltip => 'Открыть workflow';
  @override
  String get mobileHomeTitle => 'Главная';
  @override
  String get mobileHomeSubtitle =>
      'Выберите профиль, завершите шаг провайдера в браузере и отсюда включайте или выключайте текущий mobile VPN path.';
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
      'Создайте или импортируйте профиль, затем используйте главный экран для one-tap VPN workflow.';
  @override
  String get desktopShellLabel => 'Desktop control shell';
  @override
  String get desktopStatusConnectingTitle => 'Подключение к локальному host';
  @override
  String get desktopStatusReadyTitle => 'Локальный host готов';
  @override
  String get desktopStatusBlockedTitle => 'Локальный host заблокирован';
  @override
  String get desktopStatusStartingDetail =>
      'Запуск локального host и negotiation capabilities.';
  @override
  String get desktopStatusConnectedDetail => 'Подключено к локальному host.';
  @override
  String get desktopStatusWaitingDetail =>
      'Ожидание negotiation локального host.';
  @override
  String get desktopReadyWorkflowDetail =>
      'Основным остается focused editor; диагностика и live work остаются вторичными, пока они не нужны.';
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
  String get sharedArtifactActionExportHandoff => 'Экспортировать handoff';
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
  String get sharedPlatformTunnelPrerequisiteEntitlement => 'entitlement';
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
      'реализация host';
  @override
  String get sharedPlatformTunnelStartupStageCapabilityCheck =>
      'Проверка capability';
  @override
  String get sharedPlatformTunnelStartupStagePermissionAcquire =>
      'Получение разрешения';
  @override
  String get sharedPlatformTunnelStartupStageEntitlementAcquire =>
      'Получение entitlement';
  @override
  String get sharedPlatformTunnelStartupStageDriverCheck => 'Проверка драйвера';
  @override
  String get sharedPlatformTunnelStartupStageRouteValidate =>
      'Проверка маршрута';
  @override
  String get sharedPlatformTunnelStartupStageHostBringup => 'Подъем host';
  @override
  String get sharedPlatformTunnelStartupStageRuntimeAttach =>
      'Подключение runtime';
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
      'Создать управляемую запись провайдера VK для workflow с инвайтом и шагом в браузере.';
  @override
  String get sharedCatalogPresetVkDefaultSuggestedProfileName => 'VK Calls';
  @override
  String get sharedCatalogPresetGenericTurnDefaultTitle => 'Generic TURN';
  @override
  String get sharedCatalogPresetGenericTurnDefaultDescription =>
      'Создать управляемую запись Generic TURN для статического TURN handoff workflow.';
  @override
  String get sharedCatalogPresetGenericTurnDefaultSuggestedProfileName =>
      'Generic TURN';
  @override
  String get sharedCatalogSupportedProviderVkTitle => 'VK Calls';
  @override
  String get sharedCatalogSupportedProviderVkDescription =>
      'Провайдер с invite-first flow и браузерным продолжением, который приводит к transport-ready TURN credentials.';
  @override
  String get sharedCatalogSupportedProviderVkSuggestedManagedProviderName =>
      'VK Calls';
  @override
  String get sharedCatalogSupportedProviderGenericTurnTitle => 'Generic TURN';
  @override
  String get sharedCatalogSupportedProviderGenericTurnDescription =>
      'Статический TURN handoff для детерминированного transport testing и operator-driven runtime startup.';
  @override
  String
  get sharedCatalogSupportedProviderGenericTurnSuggestedManagedProviderName =>
      'Generic TURN';
}

/// The flat map containing all translations for locale <ru>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on TranslationsRu {
  dynamic _flatMapFunction(String path) {
    return switch (path) {
      'appDesktopTitle' => 'vk-turn-proxy desktop shell',
      'appDesktopReferencesTitle' => 'vk-turn-proxy desktop shell references',
      'appMobileTitle' => 'vk-turn-proxy mobile shell',
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
      'commonWorkflows' => 'Workflow',
      'commonQuickActions' => 'Быстрые действия',
      'commonSavedProfiles' => 'Сохраненные профили',
      'commonProviderRecords' => 'Записи провайдеров',
      'commonNewDraft' => 'Новый черновик',
      'commonNewFromPreset' => 'Новый из пресета',
      'commonProviderFamilies' => 'Семейства провайдеров',
      'commonOpenWorkflowsTooltip' => 'Открыть workflow',
      'mobileHomeTitle' => 'Главная',
      'mobileHomeSubtitle' =>
        'Выберите профиль, завершите шаг провайдера в браузере и отсюда включайте или выключайте текущий mobile VPN path.',
      'mobileProfilesTitle' => 'Профили',
      'mobileProfilesSubtitle' =>
        'Выберите сохраненный профиль или добавьте новый для главного экрана.',
      'mobileProfilesImportInvite' => 'Импортировать инвайт',
      'mobileProfilesRouting' => 'Маршрутизация',
      'mobileProfilesActionsTooltip' => 'Действия профилей',
      'mobileProfilesAddProfile' => 'Добавить профиль',
      'mobileProfilesEmptyTitle' => 'Сохраненных профилей пока нет',
      'mobileProfilesEmptyMessage' =>
        'Создайте или импортируйте профиль, затем используйте главный экран для one-tap VPN workflow.',
      'desktopShellLabel' => 'Desktop control shell',
      'desktopStatusConnectingTitle' => 'Подключение к локальному host',
      'desktopStatusReadyTitle' => 'Локальный host готов',
      'desktopStatusBlockedTitle' => 'Локальный host заблокирован',
      'desktopStatusStartingDetail' =>
        'Запуск локального host и negotiation capabilities.',
      'desktopStatusConnectedDetail' => 'Подключено к локальному host.',
      'desktopStatusWaitingDetail' => 'Ожидание negotiation локального host.',
      'desktopReadyWorkflowDetail' =>
        'Основным остается focused editor; диагностика и live work остаются вторичными, пока они не нужны.',
      'desktopSectionProfilesSubtitle' => 'Редактирование профилей',
      'desktopSectionProvidersSubtitle' => 'Записи провайдеров',
      'sharedProviderAuthPostureNotApplicable' =>
        'требование к авторизации не указано',
      'sharedProviderAuthPostureGuest' => 'гостевая авторизация',
      'sharedProviderAuthPostureAccount' => 'авторизация по аккаунту',
      'sharedProviderAuthPostureGuestOrAccount' => 'гость или аккаунт',
      'sharedProviderAuthPostureStaticSecret' => 'статический секрет',
      'sharedProviderBrowserPolicyNotRequired' => 'браузер не требуется',
      'sharedProviderBrowserPolicyExternalRequired' => 'нужен внешний браузер',
      'sharedProviderBrowserPolicyEmbeddedAllowed' =>
        'разрешен встроенный браузер',
      'sharedArtifactFamilyGenericTurn' => 'Generic TURN',
      'sharedArtifactFamilyConferenceRoom' => 'Комната конференции',
      'sharedArtifactFamilyCameraStream' => 'Поток камеры',
      'sharedArtifactActionStartOnThisDevice' => 'Запустить на этом устройстве',
      'sharedArtifactActionExportHandoff' => 'Экспортировать handoff',
      'sharedArtifactActionOpenRoom' => 'Открыть комнату',
      'sharedArtifactActionOpenCamera' => 'Открыть камеру',
      'sharedArtifactActionOpenArchive' => 'Открыть архив',
      'sharedPlatformTunnelModeAndroidVpnService' => 'Android VPN Service',
      'sharedPlatformTunnelModeAppleNetworkExtension' =>
        'Apple Network Extension',
      'sharedPlatformTunnelModeWindowsWintun' => 'Windows Wintun',
      'sharedPlatformTunnelModeLinuxTun' => 'Linux TUN',
      'sharedPlatformTunnelPrerequisitePermission' => 'разрешение',
      'sharedPlatformTunnelPrerequisiteEntitlement' => 'entitlement',
      'sharedPlatformTunnelPrerequisitePrivilegedExtension' =>
        'привилегированное расширение',
      'sharedPlatformTunnelPrerequisiteDriver' => 'драйвер',
      'sharedPlatformTunnelPrerequisiteRouteExclusion' => 'исключение маршрута',
      'sharedPlatformTunnelPrerequisiteDnsBypass' => 'обход DNS',
      'sharedPlatformTunnelPrerequisiteAppRoutingPolicy' =>
        'политика маршрутизации приложений',
      'sharedPlatformTunnelPrerequisiteHostImplementation' => 'реализация host',
      'sharedPlatformTunnelStartupStageCapabilityCheck' =>
        'Проверка capability',
      'sharedPlatformTunnelStartupStagePermissionAcquire' =>
        'Получение разрешения',
      'sharedPlatformTunnelStartupStageEntitlementAcquire' =>
        'Получение entitlement',
      'sharedPlatformTunnelStartupStageDriverCheck' => 'Проверка драйвера',
      'sharedPlatformTunnelStartupStageRouteValidate' => 'Проверка маршрута',
      'sharedPlatformTunnelStartupStageHostBringup' => 'Подъем host',
      'sharedPlatformTunnelStartupStageRuntimeAttach' => 'Подключение runtime',
      'sharedProviderConfigAvailabilityStateAvailable' => 'Доступно',
      'sharedProviderConfigAvailabilityStateProviderUnavailable' =>
        'Провайдер недоступен',
      'sharedProviderConfigAvailabilityStateSchemaUnsupported' =>
        'Схема не поддерживается',
      'sharedProviderConfigAvailabilityStateSettingsInvalid' =>
        'Настройки невалидны',
      'sharedCatalogPresetVkDefaultTitle' => 'VK Calls',
      'sharedCatalogPresetVkDefaultDescription' =>
        'Создать управляемую запись провайдера VK для workflow с инвайтом и шагом в браузере.',
      'sharedCatalogPresetVkDefaultSuggestedProfileName' => 'VK Calls',
      'sharedCatalogPresetGenericTurnDefaultTitle' => 'Generic TURN',
      'sharedCatalogPresetGenericTurnDefaultDescription' =>
        'Создать управляемую запись Generic TURN для статического TURN handoff workflow.',
      'sharedCatalogPresetGenericTurnDefaultSuggestedProfileName' =>
        'Generic TURN',
      'sharedCatalogSupportedProviderVkTitle' => 'VK Calls',
      'sharedCatalogSupportedProviderVkDescription' =>
        'Провайдер с invite-first flow и браузерным продолжением, который приводит к transport-ready TURN credentials.',
      'sharedCatalogSupportedProviderVkSuggestedManagedProviderName' =>
        'VK Calls',
      'sharedCatalogSupportedProviderGenericTurnTitle' => 'Generic TURN',
      'sharedCatalogSupportedProviderGenericTurnDescription' =>
        'Статический TURN handoff для детерминированного transport testing и operator-driven runtime startup.',
      'sharedCatalogSupportedProviderGenericTurnSuggestedManagedProviderName' =>
        'Generic TURN',
      _ => null,
    };
  }
}
