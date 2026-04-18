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
      'sharedProviderBrowserPolicyExternalRequired' => 'нужен внешний браузер',
      'sharedProviderBrowserPolicyEmbeddedAllowed' =>
        'разрешен встроенный браузер',
      'sharedArtifactFamilyGenericTurn' => 'Generic TURN',
      'sharedArtifactFamilyConferenceRoom' => 'Комната конференции',
      'sharedArtifactFamilyCameraStream' => 'Поток камеры',
      'sharedArtifactActionStartOnThisDevice' => 'Запустить на этом устройстве',
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
      'sharedPlatformTunnelPrerequisiteRouteExclusion' => 'исключение маршрута',
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
      'sharedPlatformTunnelStartupStageRouteValidate' => 'Проверка маршрута',
      'sharedPlatformTunnelStartupStageHostBringup' => 'Подъем хоста',
      'sharedPlatformTunnelStartupStageRuntimeAttach' => 'Подключение рантайма',
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
      _ => null,
    };
  }
}
