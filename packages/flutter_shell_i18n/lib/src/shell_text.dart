import 'package:flutter/material.dart';

import 'i18n/strings.g.dart';

class ShellText {
  ShellText(this.context);

  final BuildContext context;

  bool get _ru => LocaleSettings.currentLocale == AppLocale.ru;

  String _pick(String en, String ru) => _ru ? ru : en;

  String get close => _pick('Close', 'Закрыть');
  String get cancel => _pick('Cancel', 'Отмена');
  String get back => _pick('Back', 'Назад');
  String get save => _pick('Save', 'Сохранить');
  String get delete => _pick('Delete', 'Удалить');
  String get newItem => _pick('New', 'Новый');
  String get missing => _pick('missing', 'отсутствует');
  String get unknownValue => _pick('unknown', 'неизвестно');
  String get failureFallback => _pick('failure', 'сбой');
  String get retry => _pick('Retry', 'Повторить');
  String get activity => _pick('Activity', 'Активность');
  String get diagnostics => _pick('Diagnostics', 'Диагностика');
  String get overview => _pick('Overview', 'Обзор');
  String get events => _pick('Events', 'События');
  String get templates => _pick('Templates', 'Шаблоны');
  String get available => _pick('Available', 'Доступно');
  String get unavailable => _pick('Unavailable', 'Недоступно');
  String get openActivity => _pick('Open activity', 'Открыть активность');
  String get openDiagnostics => _pick('Open diagnostics', 'Открыть диагностику');
  String get openProfiles => _pick('Open profiles', 'Открыть профили');
  String get resetLocalState => _pick(
    'Reset local state',
    'Сбросить локальное состояние',
  );
  String get importFromFile => _pick('Import from file', 'Импорт из файла');
  String get exportSavedProfile => _pick(
    'Export saved profile',
    'Экспортировать сохраненный профиль',
  );
  String get pasteEnvelope => _pick('Paste envelope', 'Вставить конверт');
  String get copyText => _pick('Copy text', 'Копировать текст');
  String get saveFile => _pick('Save file', 'Сохранить файл');
  String get shareText => _pick('Share text', 'Поделиться текстом');
  String get shareFile => _pick('Share file', 'Поделиться файлом');
  String get previewImport => _pick('Preview import', 'Предпросмотр импорта');
  String get importProfile => _pick('Import profile', 'Импортировать профиль');
  String get portableProfileJson => _pick(
    'Portable profile JSON',
    'JSON переносимого профиля',
  );
  String get noReusableFieldsYet => _pick(
    'No reusable fields yet',
    'Переиспользуемых полей пока нет',
  );
  String get schemaBlockedInShell => _pick(
    'Schema blocked in this shell',
    'Схема заблокирована в этой оболочке',
  );
  String get reusableFieldsReady => _pick(
    'Reusable fields ready',
    'Переиспользуемые поля готовы',
  );
  String get providerInput => _pick('Provider input', 'Ввод провайдера');
  String get providerLink => _pick('Provider link', 'Ссылка провайдера');
  String get providerFamily => _pick('Provider family', 'Семейство провайдера');
  String get providerType => _pick('Provider type', 'Тип провайдера');
  String get profileName => _pick('Profile name', 'Имя профиля');
  String get localUdpListen => _pick(
    'Local UDP listen',
    'Локальный UDP-адрес',
  );
  String get peerAddress => _pick('Peer address', 'Адрес удаленного узла');
  String get connections => _pick('Connections', 'Соединения');
  String get turnMode => _pick('TURN mode', 'Режим TURN');
  String get turnOverride => _pick('TURN override', 'Переопределение TURN');
  String get turnPort => _pick('TURN port', 'Порт TURN');
  String get bindInterface => _pick('Bind interface', 'Интерфейс привязки');
  String get logLevel => _pick('Log level', 'Уровень логов');
  String get dtlsEnabled => _pick('DTLS enabled', 'DTLS включен');
  String get resolveInvite => _pick('Resolve invite', 'Разрешить инвайт');
  String get resolveProfile => _pick('Resolve profile', 'Разрешить профиль');
  String get notSet => _pick('Not set', 'Не задано');
  String get startSession => _pick('Start session', 'Запустить сессию');
  String get saveProfile => _pick('Save profile', 'Сохранить профиль');
  String get deleteProfile => _pick('Delete profile', 'Удалить профиль');
  String get freshDraft => _pick('Fresh draft', 'Новый черновик');
  String get startSavedProfile => _pick(
    'Start saved profile',
    'Запустить сохраненный профиль',
  );
  String get exportPortableProfile => _pick(
    'Export portable profile',
    'Экспортировать переносимый профиль',
  );
  String get importPortableProfile => _pick(
    'Import portable profile',
    'Импортировать переносимый профиль',
  );
  String get pastePortableProfileEnvelope => _pick(
    'Paste portable profile envelope',
    'Вставить конверт переносимого профиля',
  );
  String get previewOpensBeforeRecordsCreated => _pick(
    'Preview opens before any local records are created.',
    'Предпросмотр открывается до создания любых локальных записей.',
  );
  String get payloadInvalidOrUnsupported => _pick(
    'Payload is invalid or unsupported.',
    'Payload невалиден или не поддерживается.',
  );
  String providerAndSource({
    required String provider,
    required String source,
  }) => _pick(
    'Provider: $provider · Source: $source',
    'Провайдер: $provider · Источник: $source',
  );
  String providerLabel(String provider) =>
      _pick('Provider: $provider', 'Провайдер: $provider');
  String sourceModeLabel(String mode) =>
      _pick('Source mode: $mode', 'Режим источника: $mode');
  String managedProviderSnapshot(String name) => _pick(
    'Managed provider snapshot: $name',
    'Снимок управляемого провайдера: $name',
  );
  String get portableExportSecretWarningDesktop => _pick(
    'This payload is secret-bearing. Treat copied text, saved files, and QR screens like credentials.',
    'Этот пакет содержит секреты. Относитесь к скопированному тексту, сохраненным файлам и QR-экрану как к учетным данным.',
  );
  String get portableExportSecretWarningMobile => _pick(
    'This payload is secret-bearing. Treat shared text, files, and QR screens like credentials.',
    'Этот пакет содержит секреты. Относитесь к отправляемому тексту, файлам и QR-экрану как к учетным данным.',
  );
  String get portableExportSeparateFromRuntimeDesktop => _pick(
    'Exported payload stays separate from ordinary shell persistence and runtime handoff export.',
    'Экспортированный пакет остается отдельным от обычного сохранения оболочки и экспорта пакета handoff рантайма.',
  );
  String get portableExportSeparateFromRuntimeMobile => _pick(
    'Portable transfer stays separate from ordinary shell persistence and runtime handoff export.',
    'Передача переносимого профиля остается отдельной от обычного сохранения оболочки и экспорта пакета handoff рантайма.',
  );
  String get portableQrCompactJson => _pick(
    'QR uses the same envelope in compact JSON form.',
    'QR использует тот же конверт в компактной форме JSON.',
  );
  String portableQrUnavailableDesktop(int bytes) => _pick(
    'QR is unavailable because this payload exceeds supported QR bounds ($bytes bytes). File and text export stay available.',
    'QR недоступен, потому что пакет превышает поддерживаемый размер QR ($bytes байт). Экспорт в файл и текст остаются доступны.',
  );
  String portableQrUnavailableMobile(int bytes) => _pick(
    'QR is unavailable because this payload exceeds supported QR bounds ($bytes bytes). Text and file sharing stay available.',
    'QR недоступен, потому что пакет превышает поддерживаемый размер QR ($bytes байт). Отправка текста и файла остается доступной.',
  );
  String get portableImportSecretWarning => _pick(
    'This import payload is secret-bearing. Confirm only if the source is trusted.',
    'Этот импортируемый пакет содержит секреты. Подтверждайте только если источник доверенный.',
  );
  String get portableImportCreatesFreshIdsMobile => _pick(
    'Import creates fresh local ids and does not auto-start runtime.',
    'Импорт создает новые локальные идентификаторы и не запускает рантайм автоматически.',
  );
  String get portableImportCreatesFreshIdsDesktop => _pick(
    'Import creates new local records with fresh ids and does not auto-start runtime.',
    'Импорт создает новые локальные записи с новыми идентификаторами и не запускает рантайм автоматически.',
  );
  String get scanPortableProfileQr => _pick(
    'Scan portable profile QR',
    'Сканировать QR переносимого профиля',
  );
  String get pointCameraAtPortableProfileQr => _pick(
    'Point the camera at a portable profile QR code.',
    'Наведите камеру на QR-код переносимого профиля.',
  );
  String tagInput(String value) => _pick('Input: $value', 'Ввод: $value');
  String tagAuth(String value) => _pick('Auth: $value', 'Авторизация: $value');
  String tagBrowser(String value) =>
      _pick('Browser: $value', 'Браузер: $value');
  String tagFamily(String value) =>
      _pick('Family: $value', 'Семейство: $value');
  String get browserNeedsExternal => _pick(
    'This provider requires an external browser when challenge continuation appears.',
    'Этот провайдер требует внешний браузер, когда появляется продолжение проверки.',
  );
  String get browserAllowsEmbedded => _pick(
    'This provider allows an embedded browser surface, but the host still controls whether a browser challenge appears.',
    'Этот провайдер разрешает встроенный браузер, но хост все равно решает, появится ли браузерная проверка.',
  );
  String get browserNotRequired => _pick(
    'This provider does not report a required browser surface.',
    'Этот провайдер не сообщает о требуемом браузерном интерфейсе.',
  );
  String get browserContinuationMayAppear => _pick(
    'Browser continuation may appear for this provider.',
    'Для этого провайдера может появиться продолжение в браузере.',
  );
  String get browserContinuationNotAdvertised => _pick(
    'No browser challenge mode is currently advertised for this provider.',
    'Для этого провайдера сейчас не объявлен режим браузерной проверки.',
  );

  String get desktopProfileWorkspaceTitle => _pick(
    'Profile workspace',
    'Рабочее пространство профиля',
  );
  String get desktopUnsavedDraft => _pick('Unsaved draft', 'Несохраненный черновик');
  String get desktopSavedProfileWorkspace => _pick(
    'Saved profile workspace',
    'Рабочее пространство сохраненного профиля',
  );
  String get desktopSaveProfileFirst => _pick(
    'Save profile first',
    'Сначала сохраните профиль',
  );
  String get desktopStartSessionFromSavedProfile => _pick(
    'Start a session from this saved profile',
    'Запустить сессию из этого сохраненного профиля',
  );
  String get desktopProfileSettings => _pick(
    'Profile settings',
    'Настройки профиля',
  );
  String get desktopChangeSource => _pick('Change source', 'Сменить источник');
  String get desktopChangeSourceSubtitle => _pick(
    'Switch between a saved provider record and draft-owned input only when the profile needs a different source.',
    'Переключайтесь между сохраненной записью провайдера и вводом, принадлежащим черновику, только когда профилю нужен другой источник.',
  );
  String get desktopRuntimeDefaults => _pick(
    'Runtime defaults',
    'Параметры runtime по умолчанию',
  );
  String get desktopRuntimeDefaultsSubtitle => _pick(
    'These fields apply when the profile starts on this device.',
    'Эти поля применяются, когда профиль запускается на этом устройстве.',
  );
  String get desktopProfileMaintenance => _pick(
    'Profile maintenance',
    'Обслуживание профиля',
  );
  String get desktopProfileMaintenanceSubtitle => _pick(
    'Keep destructive actions out of the main edit flow.',
    'Держите разрушительные действия вне основного потока редактирования.',
  );
  String get desktopShowMaintenanceActions => _pick(
    'Show maintenance actions',
    'Показать действия обслуживания',
  );
  String get desktopDeleteSavedProfileHint => _pick(
    'Delete the saved profile without crowding the action row.',
    'Удалите сохраненный профиль, не загромождая строку действий.',
  );
  String get desktopPortableTransferSubtitle => _pick(
    'Export the selected saved profile as an explicit transfer envelope, or preview an import before creating local records.',
    'Экспортируйте выбранный сохраненный профиль как явный конверт переноса или просмотрите импорт до создания локальных записей.',
  );
  String get desktopBrowserHandling => _pick(
    'Browser handling',
    'Работа с браузером',
  );
  String get desktopBrowserHandlingSubtitle => _pick(
    'Show this context only when the provider can hand off into a browser challenge.',
    'Показывайте этот контекст только тогда, когда провайдер может передать управление в браузерную проверку.',
  );
  String get desktopProfileProviderSettings => _pick(
    'Profile provider settings',
    'Настройки провайдера профиля',
  );
  String desktopProviderSettingsSupportError({
    required String providerName,
    required String error,
  }) => _pick(
    'This desktop shell cannot render the provider settings schema for $providerName: $error. Save and resolve stay blocked until the host advertises a supported schema subset.',
    'Эта настольная оболочка не может отрисовать схему настроек провайдера для $providerName: $error. Сохранение и разрешение остаются заблокированы, пока хост не объявит поддерживаемое подмножество схемы.',
  );
  String get desktopProfileProviderSettingsHelp => _pick(
    'Saved profile settings for the selected provider. Prompt-only values stay only in the active draft.',
    'Сохраненные настройки профиля для выбранного провайдера. Значения только для запроса остаются только в активном черновике.',
  );
  String get desktopNoSavedProviderRecords => _pick(
    'No saved provider records are available yet.',
    'Сохраненных записей провайдеров пока нет.',
  );
  String get directInput => _pick('Direct input', 'Прямой ввод');
  String get savedRecord => _pick('Saved record', 'Сохраненная запись');
  String get desktopSavedRecordAttached => _pick(
    'A saved provider record is attached to this draft.',
    'К этому черновику прикреплена сохраненная запись провайдера.',
  );
  String get desktopDraftOwnsProviderInput => _pick(
    'This draft keeps its own provider input.',
    'Этот черновик хранит собственный ввод провайдера.',
  );

  String get mobileProfilesTitleBar => _pick('Profiles', 'Профили');
  String get mobileProviderDetails => _pick(
    'Provider details',
    'Детали провайдера',
  );
  String get mobileProviderDetailsSubtitle => _pick(
    'Browser policy, artifact families, and challenge guidance',
    'Политика браузера, семейства артефактов и подсказки по проверке',
  );
  String get mobileProviderSettingsSection => _pick(
    'Provider settings',
    'Настройки провайдера',
  );
  String get mobilePortableTransfer => _pick(
    'Portable transfer',
    'Переносимый профиль',
  );
  String get mobileProviderSettingsUnsupportedSubtitle => _pick(
    'Unsupported schema subset blocks save and resolve',
    'Неподдерживаемое подмножество схемы блокирует сохранение и разрешение',
  );
  String get mobileProviderSettingsRetainedSubtitle => _pick(
    'Required and retained provider-specific values',
    'Обязательные и сохраняемые значения, специфичные для провайдера',
  );
  String get mobileAdvancedRuntimeControls => _pick(
    'Advanced runtime controls',
    'Расширенные настройки рантайма',
  );
  String get mobileAdvancedRuntimeControlsSubtitle => _pick(
    'Transport overrides, local bind, and logging',
    'Переопределения транспорта, локальная привязка и логирование',
  );
  String get mobilePortableTransferSubtitle => _pick(
    'Export the selected saved profile through an explicit envelope, or preview an import before creating local records.',
    'Экспортируйте выбранный сохраненный профиль через явный конверт или просмотрите импорт до создания локальных записей.',
  );
  String mobileProviderSettingsSupportError({
    required String providerName,
    required String error,
  }) => _pick(
    'This mobile shell cannot render the provider settings schema for $providerName: $error. Save and resolve stay blocked until the host advertises a supported schema subset.',
    'Эта мобильная оболочка не может отрисовать схему настроек провайдера для $providerName: $error. Сохранение и разрешение остаются заблокированы, пока хост не объявит поддерживаемое подмножество схемы.',
  );
  String get mobileProviderSettingsRetainedHelp => _pick(
    'Profile-retained settings stay with the saved profile. Prompt-only values remain only in the in-memory draft used for immediate resolution starts.',
    'Настройки, сохраняемые вместе с профилем, остаются в сохраненном профиле. Значения только для запроса остаются только в памяти черновика для немедленного запуска разрешения.',
  );
  String get mobileNoSavedProfilesYetBuildDraft => _pick(
    'No saved profiles yet. Build the draft below, then save it for repeat starts.',
    'Сохраненных профилей пока нет. Соберите черновик ниже и сохраните его для повторных запусков.',
  );
  String get mobileSavedProfiles => _pick('Saved profiles', 'Сохраненные профили');
  String get mobileProviderMode => _pick('Provider mode', 'Режим провайдера');
  String get mobileProviderModeNoManagedProviders => _pick(
    'No managed providers are available yet. Use custom mode for direct provider entry or create a provider record from the workflow library first.',
    'Управляемые провайдеры пока недоступны. Используйте пользовательский режим для прямого ввода провайдера или сначала создайте запись провайдера из библиотеки рабочих процессов.',
  );
  String get customProvider => _pick('Custom provider', 'Свой провайдер');
  String get managedProvider => _pick(
    'Managed provider',
    'Управляемый провайдер',
  );
  String get mobileManagedModeSummary => _pick(
    'Managed mode snapshots values from a saved provider record, then keeps further profile edits local to this draft.',
    'Управляемый режим копирует значения из сохраненной записи провайдера, а дальнейшие изменения профиля оставляет локальными для этого черновика.',
  );
  String get mobileCustomModeSummary => _pick(
    'Custom mode lets you type a raw provider id and prompt-only inputs without mutating the managed provider catalog.',
    'Пользовательский режим позволяет ввести исходный идентификатор провайдера и значения только для запроса без изменения каталога управляемых провайдеров.',
  );
  String get mobileManagedProviderDropdown => _pick(
    'Managed provider',
    'Управляемый провайдер',
  );

  String get mobileEditProvider => _pick('Edit provider', 'Редактировать провайдера');
  String get mobileNewProvider => _pick('New provider', 'Новый провайдер');
  String get mobileEditSavedReusableProvider => _pick(
    'Edit this saved reusable provider.',
    'Редактируйте этот сохраненный переиспользуемый провайдер.',
  );
  String get mobileFinishSavedReusableProvider => _pick(
    'Finish this saved reusable provider for later use in Profiles.',
    'Завершите этот сохраненный переиспользуемый провайдер для дальнейшего использования в Профилях.',
  );
  String get mobileCloseProviderEditor => _pick(
    'Close provider editor',
    'Закрыть редактор провайдера',
  );
  String get mobileNoShippedProviderFamilies => _pick(
    'This build does not advertise any shipped provider families yet.',
    'Эта сборка пока не объявляет ни одного встроенного семейства провайдеров.',
  );
  String get mobileProviderName => _pick('Provider name', 'Имя провайдера');
  String get mobileProviderShownInProfiles => _pick(
    'Shown in Profiles when choosing a saved reusable provider.',
    'Показывается в Профилях при выборе сохраненного переиспользуемого провайдера.',
  );
  String get mobileProviderTypeChosenWhenCreated => _pick(
    'Chosen when this saved provider was created. Use this pane to name it and review reusable settings.',
    'Выбирается при создании этого сохраненного провайдера. Используйте эту панель, чтобы задать имя и просмотреть переиспользуемые настройки.',
  );
  String mobileNoReusableSettingsYetNamedProvider(String providerTitle) =>
      providerTitle.isEmpty
          ? _pick(
              'No reusable settings yet. Save this as a named provider for Profiles.',
              'Переиспользуемых настроек пока нет. Сохраните это как именованный провайдер для Профилей.',
            )
          : _pick(
              'No reusable settings yet. Save $providerTitle as a named provider for Profiles.',
              'Переиспользуемых настроек пока нет. Сохраните $providerTitle как именованный провайдер для Профилей.',
            );
  String mobileProviderConfigSupportError({
    required String providerName,
    required String error,
  }) => _pick(
    'This mobile shell cannot render the provider settings schema for $providerName: $error. Save stays blocked until the host advertises a supported schema subset.',
    'Эта мобильная оболочка не может отрисовать схему настроек провайдера для $providerName: $error. Сохранение остается заблокированным, пока хост не объявит поддерживаемое подмножество схемы.',
  );
  String get mobileReusableProviderSettings => _pick(
    'Reusable provider settings',
    'Переиспользуемые настройки провайдера',
  );
  String get mobileReusableValuesAppliedToProfile => _pick(
    'These reusable values are applied when this provider is used in a profile.',
    'Эти переиспользуемые значения применяются, когда этот провайдер используется в профиле.',
  );
  String get mobileSaveProvider => _pick('Save provider', 'Сохранить провайдера');
  String get mobileSaveAsTemplate => _pick(
    'Save as template',
    'Сохранить как шаблон',
  );
  String get mobileUseInProfileDraft => _pick(
    'Use in profile draft',
    'Использовать в черновике профиля',
  );
  String get mobileDeleteProvider => _pick(
    'Delete provider',
    'Удалить провайдера',
  );
  String get selectedType => _pick('Selected type', 'Выбранный тип');
  String get mobileEditTemplate => _pick('Edit template', 'Редактировать шаблон');
  String get mobileNewTemplate => _pick('New template', 'Новый шаблон');
  String get mobileEditTemplateStartingValues => _pick(
    'Edit starting values for future providers.',
    'Редактируйте стартовые значения для будущих провайдеров.',
  );
  String get mobileSaveTemplateStartingPoint => _pick(
    'Save a starting point for future providers.',
    'Сохраните стартовую точку для будущих провайдеров.',
  );
  String get mobileCloseTemplateEditor => _pick(
    'Close template editor',
    'Закрыть редактор шаблона',
  );
  String get mobileTemplateName => _pick('Template name', 'Имя шаблона');
  String get mobileTemplateShownWhenChoosing => _pick(
    'Shown when choosing a starting point for new providers.',
    'Показывается при выборе стартовой точки для новых провайдеров.',
  );
  String get mobileTemplateTypeChosenWhenCreated => _pick(
    'Chosen when this template was created. Use this pane to name it and review reusable starting values.',
    'Выбирается при создании этого шаблона. Используйте эту панель, чтобы задать имя и просмотреть переиспользуемые стартовые значения.',
  );
  String mobileNoReusableSettingsYetTemplate(String providerTitle) =>
      providerTitle.isEmpty
          ? _pick(
              'No reusable settings yet. Save this template as a named starting point.',
              'Переиспользуемых настроек пока нет. Сохраните этот шаблон как именованную стартовую точку.',
            )
          : _pick(
              'No reusable settings yet. Save $providerTitle as a named starting point.',
              'Переиспользуемых настроек пока нет. Сохраните $providerTitle как именованную стартовую точку.',
            );
  String get mobileReusableValuesPrefillProvider => _pick(
    'These values prefill a new provider when this template is used.',
    'Эти значения предзаполняют нового провайдера при использовании шаблона.',
  );
  String get mobileSaveTemplate => _pick('Save template', 'Сохранить шаблон');
  String get mobileUseTemplate => _pick('Use template', 'Использовать шаблон');
  String get mobileDeleteTemplate => _pick(
    'Delete template',
    'Удалить шаблон',
  );

  String get desktopProviderRecord => _pick(
    'Provider record',
    'Запись провайдера',
  );
  String get desktopNewProviderRecord => _pick(
    'New provider record',
    'Новая запись провайдера',
  );
  String get desktopEditReusableProviderRecord => _pick(
    'Edit one reusable provider record. The attached family is shown below and stays read-only here.',
    'Редактируйте одну переиспользуемую запись провайдера. Прикрепленное семейство показано ниже и остается здесь только для чтения.',
  );
  String get desktopCreateReusableProviderRecord => _pick(
    'Create one reusable provider record. Choose its family separately, then edit the record parameters below.',
    'Создайте одну переиспользуемую запись провайдера. Отдельно выберите семейство, затем редактируйте параметры записи ниже.',
  );
  String get desktopRecordParameters => _pick(
    'Record parameters',
    'Параметры записи',
  );
  String desktopParametersFor(String providerTitle) => _pick(
    'Parameters for $providerTitle',
    'Параметры для $providerTitle',
  );
  String get desktopChooseProviderFamilyFirst => _pick(
    'Choose a provider family from the separate family list first. Record parameters will appear here afterwards.',
    'Сначала выберите семейство провайдера в отдельном списке. После этого здесь появятся параметры записи.',
  );
  String desktopEditReusableParametersFor(String providerTitle) => _pick(
    'Edit reusable parameters stored in this record for $providerTitle. This does not change the family itself.',
    'Редактируйте переиспользуемые параметры, сохраненные в этой записи для $providerTitle. Это не меняет само семейство.',
  );
  String get desktopUseInProfileDraft => _pick(
    'Use in profile draft',
    'Использовать в черновике профиля',
  );
  String get desktopNewRecord => _pick('New record', 'Новая запись');
  String get desktopRecordName => _pick('Record name', 'Имя записи');
  String get desktopRecordNameHelp => _pick(
    'Name this saved provider record first. Family choice and record parameters stay below.',
    'Сначала задайте имя этой сохраненной записи провайдера. Выбор семейства и параметры записи находятся ниже.',
  );
  String get desktopAttachedFamily => _pick(
    'Attached family',
    'Прикрепленное семейство',
  );
  String get desktopAttachedFamilyHelp => _pick(
    'Families live in a separate chooser. The selected family is attached to this record and described here.',
    'Семейства выбираются в отдельном списке. Выбранное семейство прикрепляется к этой записи и описывается здесь.',
  );
  String get desktopFamilyCharacteristics => _pick(
    'Family characteristics',
    'Характеристики семейства',
  );
  String get desktopFamilyCharacteristicsHelp => _pick(
    'Read-only characteristics from the selected family and current host overlay.',
    'Характеристики только для чтения из выбранного семейства и текущего хост-оверлея.',
  );
  String desktopProviderRecordSupportError({
    required String providerName,
    required String error,
  }) => _pick(
    'This desktop shell cannot render the provider settings schema for $providerName: $error. Save stays blocked until the host advertises a supported schema subset.',
    'Эта настольная оболочка не может отрисовать схему настроек провайдера для $providerName: $error. Сохранение остается заблокированным, пока хост не объявит поддерживаемое подмножество схемы.',
  );
  String get desktopNoFamilyAttachedYet => _pick(
    'No family attached yet',
    'Семейство пока не прикреплено',
  );
  String get desktopSelectedFamily => _pick(
    'Selected family',
    'Выбранное семейство',
  );
  String get desktopOpenFamilyChooserFirst => _pick(
    'Open the separate family chooser before you continue with this provider record.',
    'Откройте отдельный список семейств, прежде чем продолжить работу с этой записью провайдера.',
  );
  String desktopFamilyAttachedToRecord(String providerTitle) => _pick(
    '$providerTitle is attached to this record until you intentionally change it in the family chooser.',
    '$providerTitle прикреплено к этой записи, пока вы намеренно не измените его в списке семейств.',
  );
  String get desktopShippedByApp => _pick('Shipped by app', 'Поставляется приложением');
  String get desktopHostOverlayAvailable => _pick(
    'Host overlay: available',
    'Host overlay: доступен',
  );
  String get desktopHostOverlayUnavailable => _pick(
    'Host overlay: unavailable',
    'Host overlay: недоступен',
  );
  String get desktopUseActionStripToChooseFamily => _pick(
    'Use the action strip above to choose a family. Families are read-only here.',
    'Используйте панель действий выше, чтобы выбрать семейство. Здесь семейства только для чтения.',
  );
  String get desktopFamiliesReadonlyEditBelow => _pick(
    'Families stay read-only here. Change the attached family from the action strip above; edit this record\'s parameters below.',
    'Здесь семейства остаются только для чтения. Меняйте прикрепленное семейство через панель действий выше, а параметры этой записи редактируйте ниже.',
  );
  String get desktopChooseFamily => _pick('Choose family', 'Выбрать семейство');
  String get desktopSaveDraft => _pick('Save draft', 'Сохранить черновик');
  String get desktopSaveRecord => _pick('Save record', 'Сохранить запись');
  String get desktopReadOnlyFamily => _pick(
    'Read-only family',
    'Семейство только для чтения',
  );
  String get desktopAttachedFamilyCardHelp => _pick(
    'This card describes the attached family. Editable record parameters are shown below.',
    'Эта карточка описывает прикрепленное семейство. Ниже показаны редактируемые параметры записи.',
  );
  String get desktopNoEditableParametersYet => _pick(
    'No editable parameters yet',
    'Редактируемых параметров пока нет',
  );
  String get desktopNoEditableParameters => _pick(
    'No editable parameters',
    'Редактируемых параметров нет',
  );
  String get desktopEditableParametersReady => _pick(
    'Editable parameters ready',
    'Редактируемые параметры готовы',
  );
  String get desktopNoSavedProfilesYetShort => _pick(
    'No saved profiles yet.',
    'Сохраненных профилей пока нет.',
  );
  String get desktopNoShippedProviderFamilies => _pick(
    'This build does not advertise any shipped provider families yet.',
    'Эта сборка пока не объявляет ни одного встроенного семейства провайдеров.',
  );
  String desktopNoEditableRecordParameters(String providerTitle) => _pick(
    '$providerTitle has no editable record parameters in this desktop shell.',
    '$providerTitle не имеет редактируемых параметров записи в этой настольной оболочке.',
  );
  String get desktopSavedProfilesLibraryTitle => _pick(
    'Saved profiles',
    'Сохраненные профили',
  );
  String get desktopSavedProfilesLibrarySubtitle => _pick(
    'Browse saved operator workspaces intentionally, then return to the active editor without leaving the main path permanently split.',
    'Осознанно просматривайте сохраненные рабочие пространства оператора, а затем возвращайтесь в активный редактор, не оставляя основной путь навсегда разделенным.',
  );
  String get desktopReturnPathExplicitTitle => _pick(
    'Return path stays explicit',
    'Путь возврата остается явным',
  );
  String get desktopReturnPathExplicitMessage => _pick(
    'Selecting a saved profile updates the active workflow and closes this secondary surface.',
    'Выбор сохраненного профиля обновляет активный рабочий процесс и закрывает эту вторичную поверхность.',
  );
  String get desktopProviderRecordsLibraryTitle => _pick(
    'Provider records',
    'Записи провайдеров',
  );
  String get desktopProviderRecordsLibrarySubtitle => _pick(
    'Create a reusable provider record or reopen one you already saved.',
    'Создайте переиспользуемую запись провайдера или откройте уже сохраненную.',
  );
  String get desktopRecordsSeparateFromFamiliesTitle => _pick(
    'Records are separate from families',
    'Записи отделены от семейств',
  );
  String get desktopRecordsSeparateFromFamiliesMessage => _pick(
    'Create a record here, then choose its family in the separate family chooser. Open an existing record to continue editing it.',
    'Создайте здесь запись, затем выберите ее семейство в отдельном списке семейств. Откройте существующую запись, чтобы продолжить ее редактирование.',
  );
  String get desktopNoProviderRecordsYet => _pick(
    'No provider records yet. Create one to choose a family and store reusable parameters.',
    'Записей провайдеров пока нет. Создайте запись, чтобы выбрать семейство и сохранить переиспользуемые параметры.',
  );
  String get desktopNewFromPresetSubtitle => _pick(
    'Start from a curated provider seed only when you intentionally ask for it.',
    'Начинайте с подготовленной заготовки провайдера только когда намеренно этого хотите.',
  );
  String get desktopPresetBootstrapExplicitTitle => _pick(
    'Preset bootstrap stays explicit',
    'Запуск из пресета остается явным',
  );
  String get desktopPresetBootstrapExplicitMessage => _pick(
    'Unavailable presets remain visible and honest here, but they no longer occupy the default provider workspace.',
    'Недоступные пресеты остаются здесь видимыми и честными, но больше не занимают рабочее пространство провайдера по умолчанию.',
  );
  String get desktopProviderFamiliesSubtitle => _pick(
    'Choose the shipped family here, then return to the provider record editor.',
    'Выберите здесь поставляемое семейство, затем вернитесь в редактор записи провайдера.',
  );
  String get desktopFamiliesReadonlyHereTitle => _pick(
    'Families are read-only here',
    'Здесь семейства только для чтения',
  );
  String get desktopFamiliesReadonlyHereMessage => _pick(
    'This list belongs to the shipped shell. Choose a family here, then edit the selected record back in the record editor.',
    'Этот список принадлежит встроенной оболочке. Выберите здесь семейство, затем редактируйте выбранную запись в редакторе записи.',
  );
  String get desktopUsePreset => _pick('Use preset', 'Использовать пресет');
  String providerFamilyLabel(String familyTitle) => _pick(
    'Provider family: $familyTitle',
    'Семейство провайдера: $familyTitle',
  );
  String get appOwnedManagedRecord => _pick(
    'App-owned managed record',
    'Управляемая запись приложения',
  );
  String get selectedFamily => _pick('Selected family', 'Выбранное семейство');

  String get mobileOpenBrowser => _pick('Open browser', 'Открыть браузер');
  String get mobileContinueInApp => _pick('Continue in app', 'Продолжить в приложении');
  String challengeContinuationCancelled(String challengeId) => _pick(
    'Cancelled the in-app browser continuation for challenge $challengeId and marked the challenge cancelled.',
    'Продолжение проверки $challengeId во встроенном браузере отменено, проверка помечена как отмененная.',
  );
  String challengeContinuationFailed({
    required String challengeId,
    required Object error,
  }) => _pick(
    'In-app browser continuation failed: $error. Marked challenge $challengeId as cancelled.',
    'Продолжение проверки $challengeId во встроенном браузере завершилось ошибкой: $error. Проверка помечена как отмененная.',
  );
  String get mobileEditProfile => _pick('Edit profile', 'Редактировать профиль');
  String get mobileSelectedForHome => _pick(
    'Selected for Home',
    'Выбран для Главной',
  );
  String get mobileTurnOnVpn => _pick('Turn on VPN', 'Включить VPN');
  String get mobileTurnOffVpn => _pick('Turn off VPN', 'Выключить VPN');
  String get mobileProvidersTitle => _pick('Providers', 'Провайдеры');
  String get mobileProvidersSubtitle => _pick(
    'Choose a saved reusable provider or add a new one for Profiles.',
    'Выберите сохраненный переиспользуемый провайдер или добавьте новый для Профилей.',
  );
  String get mobileAddProvider => _pick('Add provider', 'Добавить провайдера');
  String get mobileBackToProviders => _pick(
    'Back to providers',
    'Назад к провайдерам',
  );
  String get mobileNoProvider => _pick('No provider', 'Провайдер не выбран');
  String get mobileInputConfigured => _pick(
    'input configured',
    'ввод настроен',
  );
  String get supportTitle => _pick('Support', 'Поддержка');
  String get supportSubtitle => _pick(
    'Activity, failures, logs, and diagnostics stay explicit but secondary to the main VPN workflow.',
    'Активность, ошибки, логи и диагностика остаются явными, но вторичными по отношению к основному VPN-потоку.',
  );
  String get routingTitle => _pick('Routing', 'Маршрутизация');
  String get routingSubtitle => _pick(
    'Choose whether Android system VPN covers all apps, only selected apps, or every app except the selected list.',
    'Выберите, охватывает ли системный VPN Android все приложения, только выбранные приложения или все приложения кроме выбранного списка.',
  );
  String modeScope(String modeLabel) =>
      _pick('$modeLabel scope', '$modeLabel: охват');
  String get allApps => _pick('All apps', 'Все приложения');
  String get includedApps => _pick('Included apps', 'Включенные приложения');
  String get excludedApps => _pick('Excluded apps', 'Исключенные приложения');
  String get searchApps => _pick('Search apps', 'Поиск приложений');
  String get allInstalledAppsUseVpnPath => _pick(
    'All installed apps will use the Android system VPN path for this mobile mode.',
    'Все установленные приложения будут использовать системный VPN-путь Android для этого мобильного режима.',
  );
  String get retryAppScan => _pick('Retry app scan', 'Повторить сканирование приложений');
  String get noInstalledAppsReported => _pick(
    'No installed apps were reported by the Android shell bridge.',
    'Android shell bridge не сообщил об установленных приложениях.',
  );
  String get noInstalledAppsMatchSearch => _pick(
    'No installed apps match this search.',
    'Для этого поиска нет совпадающих установленных приложений.',
  );
  String get homeNoSavedProfilesYet => _pick(
    'No saved profiles yet',
    'Сохраненных профилей пока нет',
  );
  String get homeNoSavedProfilesMessage => _pick(
    'Create or import a profile first, then come back here for the fast VPN toggle.',
    'Сначала создайте или импортируйте профиль, затем вернитесь сюда для быстрого переключения VPN.',
  );
  String get currentProfile => _pick('Current profile', 'Текущий профиль');
  String listeningOn(String address) =>
      _pick('Listening on $address', 'Слушает на $address');
  String get currentMode => _pick('Current mode', 'Текущий режим');
  String get noMobileTunnelModeAdvertised => _pick(
    'The connected host has not advertised a mobile tunnel mode yet.',
    'Подключенный хост пока не объявил мобильный туннельный режим.',
  );
  String get executionPath => _pick('Execution path', 'Путь выполнения');
  String get providerStepTone => _pick('Provider step', 'Шаг провайдера');
  String get connectionLiveTone => _pick('Connection live', 'Соединение активно');
  String get setupNeededTone => _pick('Setup needed', 'Требуется настройка');
  String get mainActionTone => _pick('Main action', 'Главное действие');
  String get finishProviderValidation => _pick(
    'Finish provider validation',
    'Завершите проверку провайдера',
  );
  String get vpnIsOn => _pick('VPN is on', 'VPN включен');
  String get profileRequired => _pick('Profile required', 'Требуется профиль');
  String get vpnIsOff => _pick('VPN is off', 'VPN выключен');
  String get continueProviderFlowInApp => _pick(
    'Continue the provider flow in the in-app browser before VPN can start.',
    'Продолжите шаг провайдера во встроенном браузере, прежде чем VPN сможет запуститься.',
  );
  String get openRequiredBrowserStepFromHome => _pick(
    'Open the required browser step from Home, then return here and confirm completion before VPN can start.',
    'Откройте обязательный шаг в браузере с Главной, затем вернитесь сюда и подтвердите завершение до запуска VPN.',
  );
  String get disconnectCurrentMobileVpnPath => _pick(
    'Disconnect the current mobile VPN path from here.',
    'Отсюда отключите текущий путь мобильного VPN.',
  );
  String get chooseOrFinishProfileBeforeStartingVpn => _pick(
    'Choose or finish a profile in Profiles before starting the current mobile VPN path.',
    'Выберите или завершите профиль в Профилях перед запуском текущего пути мобильного VPN.',
  );
  String get startCurrentMobileVpnPath => _pick(
    'Start the current mobile VPN path from here.',
    'Запустите текущий путь мобильного VPN отсюда.',
  );
  String get continueInProfiles => _pick(
    'Continue in Profiles',
    'Продолжить в Профилях',
  );
  String challengeKind(String kind) => _pick(
    'Challenge: $kind',
    'Проверка: $kind',
  );
  String get iveCompletedIt => _pick("I've completed it", 'Я завершил');
  String get cancelChallenge => _pick(
    'Cancel challenge',
    'Отменить проверку',
  );
  String get needDeeperDetail => _pick(
    'Need deeper detail?',
    'Нужна более глубокая детализация?',
  );
  String resolutionsSessionsSummary({
    required int resolutions,
    required int sessions,
    required String liveSummary,
  }) => _pick(
    'Resolutions $resolutions · Sessions $sessions · $liveSummary',
    'Резолюции $resolutions · Сессии $sessions · $liveSummary',
  );
  String get noStartupRequestYetShort => _pick(
    'No startup request yet.',
    'Запроса на запуск пока не было.',
  );
  String get routingUnavailableForMode => _pick(
    'Routing is unavailable for this mode',
    'Маршрутизация недоступна для этого режима',
  );
  String get routingUnavailableMessage => _pick(
    'Only mobile modes that support per-app scope expose this surface. Pick another mode from home if the host advertises one.',
    'Только мобильные режимы с поддержкой маршрутизации по приложениям показывают эту поверхность. Выберите другой режим на Главной, если хост его объявляет.',
  );
  String get noSavedProvidersYet => _pick(
    'No saved providers yet',
    'Сохраненных провайдеров пока нет',
  );
  String get noSavedProvidersMessage => _pick(
    'Add a provider, then reuse it from Profiles.',
    'Добавьте провайдера, затем переиспользуйте его из Профилей.',
  );
  String typeLabel(String familyTitle) =>
      _pick('Type: $familyTitle', 'Тип: $familyTitle');
  String get usedInProfiles => _pick('Used in Profiles', 'Используется в Профилях');
  String get createProvider => _pick('Create provider', 'Создать провайдера');
  String get createProviderChooseType => _pick(
    'Choose a provider type and configure a new saved provider.',
    'Выберите тип провайдера и настройте нового сохраненного провайдера.',
  );
  String get createProviderUseTemplate => _pick(
    'Use a template to prefill a new provider. Templates are starting points, not saved providers.',
    'Используйте шаблон для предзаполнения нового провайдера. Шаблоны - это стартовые точки, а не сохраненные провайдеры.',
  );
  String get providerTypes => _pick('Provider types', 'Типы провайдеров');
  String get noShippedProviderTypesYet => _pick(
    'This build does not advertise any shipped provider types yet.',
    'Эта сборка пока не объявляет никаких встроенных типов провайдеров.',
  );
  String get searchTemplates => _pick('Search templates', 'Поиск шаблонов');
  String get myTemplates => _pick('My templates', 'Мои шаблоны');
  String get noSavedTemplatesYet => _pick(
    'No saved templates yet. Save a provider as a template to reuse it here.',
    'Сохраненных шаблонов пока нет. Сохраните провайдера как шаблон, чтобы переиспользовать его здесь.',
  );
  String get noSavedTemplatesMatchSearch => _pick(
    'No saved templates match the current search.',
    'Нет сохраненных шаблонов, подходящих под текущий поиск.',
  );
  String get prefillsNewProviders => _pick(
    'Prefills new providers',
    'Предзаполняет новых провайдеров',
  );
  String get shippedTemplates => _pick('Shipped templates', 'Встроенные шаблоны');
  String get noShippedTemplatesMatchSearch => _pick(
    'No shipped templates match the current search.',
    'Нет встроенных шаблонов, подходящих под текущий поиск.',
  );
  String get startingPointForNewProviders => _pick(
    'Starting point for new providers',
    'Стартовая точка для новых провайдеров',
  );
  String get readOnlyShippedTemplate => _pick(
    'Read-only shipped template',
    'Встроенный шаблон только для чтения',
  );
  String get activityPageSubtitle => _pick(
    'Inspect provider resolutions and session state without crowding the main workflow.',
    'Просматривайте резолюции провайдера и состояние сессий, не загромождая основной рабочий процесс.',
  );
  String resolutionsCount(int count) =>
      _pick('Resolutions ($count)', 'Резолюции ($count)');
  String sessionsCount(int count) =>
      _pick('Sessions ($count)', 'Сессии ($count)');
  String get diagnosticsPageSubtitle => _pick(
    'Detailed host readiness, platform tunnel detail, and recent typed events.',
    'Подробная готовность хоста, детали платформенного туннеля и недавние типизированные события.',
  );
  String eventsCount(int count) => _pick('Events ($count)', 'События ($count)');
  String get waitingForMobileHostBridge => _pick(
    'Waiting for mobile host bridge negotiation.',
    'Ожидание согласования моста мобильного хоста.',
  );
  String guiBuildTag(String label) => _pick('GUI $label', 'GUI $label');
  String hostBuildTag(String label) => _pick('Host $label', 'Host $label');
  String contractTag(String version) =>
      _pick('Contract $version', 'Контракт $version');
  String get reconnect => _pick('Reconnect', 'Переподключить');
  String get refresh => _pick('Refresh', 'Обновить');
  String get resolutionsTitle => _pick('Resolutions', 'Резолюции');
  String get resolutionsSubtitle => _pick(
    'Resolve the invite first, then use the capability-gated action set to start on this device, export a handoff, or open provider-native targets.',
    'Сначала разрешите инвайт, затем используйте набор действий, ограниченный возможностями, чтобы запустить на этом устройстве, экспортировать handoff или открыть нативные цели провайдера.',
  );
  String get noProviderResolutionsYet => _pick(
    'No provider resolutions yet.',
    'Резолюций провайдера пока нет.',
  );
  String get systemTunnelBannerText => _pick(
    'This mobile slice renders typed host capability and startup-stage results for the reported platform modes. Use the controls below to start or disconnect supported system-tunnel paths.',
    'Этот мобильный срез отображает типизированные возможности хоста и результаты этапов запуска для объявленных платформенных режимов. Используйте элементы управления ниже, чтобы запустить или отключить поддерживаемые пути системного туннеля.',
  );
  String get noPlatformTunnelModesReported => _pick(
    'The connected mobile host did not report any platform tunnel modes.',
    'Подключенный мобильный хост не сообщил ни о каких платформенных туннельных режимах.',
  );
  String get availableLowercase => _pick('available', 'доступно');
  String get unavailableLowercase => _pick('unavailable', 'недоступно');
  String get disconnectVpn => _pick('Disconnect VPN', 'Отключить VPN');
  String get requestStartup => _pick('Request startup', 'Запросить запуск');
  String get noStartupRequestYet => _pick(
    'No startup request yet. Use the typed mobile host contract to verify the fail-closed path.',
    'Запроса на запуск пока нет. Используйте типизированный контракт мобильного хоста, чтобы проверить fail-closed сценарий.',
  );
  String turnCredentialsSummary({
    required String address,
    required String username,
  }) => _pick('TURN $address | $username', 'TURN $address | $username');
  String exportExpiry({
    required String timestamp,
    String? source,
  }) => _pick(
    'Export expiry $timestamp${source == null ? '' : ' via $source'}',
    'Срок действия экспорта $timestamp${source == null ? '' : ' через $source'}',
  );
  String failureSummary({
    required String stage,
    required String message,
  }) => _pick('$stage: $message', '$stage: $message');
  String sessionStateLabel(String value) => switch (value) {
    'starting' => _pick('starting', 'запуск'),
    'challenge_required' => _pick('challenge required', 'требуется проверка'),
    'ready' => _pick('ready', 'готово'),
    'retrying' => _pick('retrying', 'повтор'),
    'stopping' => _pick('stopping', 'остановка'),
    'stopped' => _pick('stopped', 'остановлено'),
    'failed' => _pick('failed', 'сбой'),
    _ => value,
  };
  String resolutionStateLabel(String value) => switch (value) {
    'starting' => _pick('starting', 'запуск'),
    'challenge_required' => _pick('challenge required', 'требуется проверка'),
    'resolved' => _pick('resolved', 'разрешено'),
    'failed' => _pick('failed', 'сбой'),
    'cancelled' => _pick('cancelled', 'отменено'),
    'expired' => _pick('expired', 'истекло'),
    _ => value,
  };
  String actionExecutionOwnerLabel(String value) => switch (value) {
    'host' => _pick('host', 'хост'),
    'shell_local' => _pick('shell local', 'локальная оболочка'),
    'shell_external' => _pick('shell external', 'внешняя оболочка'),
    _ => value,
  };
  String get moreChallengeActions => _pick(
    'More challenge actions',
    'Больше действий проверки',
  );
  String get moreResolutionActions => _pick(
    'More resolution actions',
    'Больше действий резолюции',
  );
  String get startOnThisDevice => _pick(
    'Start on this device',
    'Запустить на этом устройстве',
  );
  String get shareHandoff => _pick('Share handoff', 'Поделиться handoff');
  String get openRoom => _pick('Open room', 'Открыть комнату');
  String get openCamera => _pick('Open camera', 'Открыть камеру');
  String get openArchive => _pick('Open archive', 'Открыть архив');
  String get copyHandoff => _pick('Copy handoff', 'Копировать handoff');
  String get cancelResolution => _pick(
    'Cancel resolution',
    'Отменить резолюцию',
  );
  String get sessionsTitle => _pick('Sessions', 'Сессии');
  String get noMobileSessionsYet => _pick(
    'No active or recent mobile sessions yet.',
    'Активных или недавних мобильных сессий пока нет.',
  );
  String sessionListenConnections({
    required String listen,
    required int connections,
  }) => _pick(
    'listen $listen | connections $connections',
    'слушает $listen | соединения $connections',
  );
  String sessionUpdated({
    required String timestamp,
    required String sessionId,
  }) => _pick(
    'Updated $timestamp | session $sessionId',
    'Обновлено $timestamp | сессия $sessionId',
  );
  String get moreSessionActions => _pick(
    'More session actions',
    'Больше действий сессии',
  );
  String get stopSession => _pick('Stop session', 'Остановить сессию');
  String get exportDiagnostics => _pick(
    'Export diagnostics',
    'Экспортировать диагностику',
  );
  String get eventStream => _pick('Event stream', 'Поток событий');
  String get eventStreamSubtitle => _pick(
    'Typed state transitions and challenge updates from the mobile host bridge.',
    'Типизированные переходы состояния и обновления проверок от моста мобильного хоста.',
  );
  String get noEventsYet => _pick('No events yet.', 'Событий пока нет.');
  String get resetNeeded => _pick('Reset needed', 'Требуется сброс');
  String get hostReady => _pick('Host ready', 'Хост готов');
  String get hostIncompatible => _pick(
    'Host incompatible',
    'Хост несовместим',
  );
  String get hostBlocked => _pick('Host blocked', 'Хост заблокирован');
  String get connecting => _pick('Connecting', 'Подключение');
  String get mobileHostReady => _pick(
    'Mobile host ready',
    'Мобильный хост готов',
  );
  String get mobileHostIncompatible => _pick(
    'Mobile host incompatible',
    'Мобильный хост несовместим',
  );
  String get mobileHostBlocked => _pick(
    'Mobile host blocked',
    'Мобильный хост заблокирован',
  );
  String get connectingToMobileHost => _pick(
    'Connecting to mobile host',
    'Подключение к мобильному хосту',
  );
  String satisfiedPrerequisites(String prerequisites) => _pick(
    'Satisfied prerequisites: $prerequisites',
    'Выполненные предусловия: $prerequisites',
  );
  String missingPrerequisite(String prerequisite) => _pick(
    'Missing prerequisite: $prerequisite',
    'Отсутствует предусловие: $prerequisite',
  );
  String get mobileHostModeAvailable => _pick(
    'The mobile host reports that this mode is available.',
    'Мобильный хост сообщает, что этот режим доступен.',
  );
  String get mobileHostModeUnavailable => _pick(
    'The mobile host reports that this mode is unavailable.',
    'Мобильный хост сообщает, что этот режим недоступен.',
  );
  String platformTunnelReady(String modeLabel) => _pick(
    '$modeLabel reached ready state for the mobile host tunnel path.',
    '$modeLabel достиг готового состояния для туннельного пути мобильного хоста.',
  );
  String startupBlockedAt(String stageLabel) => _pick(
    'Startup blocked at $stageLabel.',
    'Запуск заблокирован на этапе $stageLabel.',
  );
  String get unknownStage => _pick('Unknown stage', 'Неизвестный этап');
  String get noMobileTunnelModeSelected => _pick(
    'No mobile tunnel mode is currently selected.',
    'Сейчас не выбран ни один мобильный туннельный режим.',
  );
  String get androidSystemVpnMode => _pick(
    'Android system VPN mode',
    'Режим системного VPN Android',
  );
  String get appleNetworkExtensionMode => _pick(
    'Apple network extension mode',
    'Режим сетевого расширения Apple',
  );
  String get windowsWintunMode => _pick(
    'Windows Wintun mode',
    'Режим Windows Wintun',
  );
  String get linuxTunMode => _pick('Linux TUN mode', 'Режим Linux TUN');
  String modeSummary({
    required String modeLabel,
    required String routingSummary,
    String? executionPath,
  }) => executionPath == null
      ? _pick('$modeLabel. $routingSummary', '$modeLabel. $routingSummary')
      : _pick(
          '$modeLabel. $routingSummary Execution path: $executionPath.',
          '$modeLabel. $routingSummary Путь выполнения: $executionPath.',
        );
  String get perAppRoutingUnavailable => _pick(
    'Per-app routing is unavailable for this mobile mode.',
    'Маршрутизация по приложениям недоступна для этого мобильного режима.',
  );
  String get scopeAllInstalledApps => _pick(
    'Scope: all installed apps.',
    'Область: все установленные приложения.',
  );
  String get scopeIncludedAppsEmpty => _pick(
    'Scope: included apps, but no apps are selected yet.',
    'Область: включенные приложения, но приложения пока не выбраны.',
  );
  String scopeOnlySelectedApps(int count) => _pick(
    'Scope: only $count selected apps.',
    'Область: только $count выбранных приложений.',
  );
  String get scopeExcludedAppsEmpty => _pick(
    'Scope: excluded apps, but no apps are selected yet.',
    'Область: исключенные приложения, но приложения пока не выбраны.',
  );
  String scopeAllExceptSelectedApps(int count) => _pick(
    'Scope: all apps except $count selected apps.',
    'Область: все приложения кроме $count выбранных приложений.',
  );
  String get wireGuardNativeOverTurnDatagram => _pick(
    'WireGuard native over TURN datagram',
    'WireGuard native поверх TURN datagram',
  );
  String get wireGuardNativeOverTurnDtls => _pick(
    'WireGuard native over TURN DTLS overlay',
    'WireGuard native поверх TURN DTLS overlay',
  );
  String get wireGuardNativeOverWebRtc => _pick(
    'WireGuard native over WebRTC data channel',
    'WireGuard native поверх WebRTC data channel',
  );
  String get customOverlayOverTurnDatagram => _pick(
    'Custom packet overlay over TURN datagram',
    'Custom packet overlay поверх TURN datagram',
  );
  String get customOverlayOverTurnDtls => _pick(
    'Custom packet overlay over TURN DTLS overlay',
    'Custom packet overlay поверх TURN DTLS overlay',
  );
  String get customOverlayOverWebRtc => _pick(
    'Custom packet overlay over WebRTC data channel',
    'Custom packet overlay поверх WebRTC data channel',
  );
  String get proxyCoreOverTurnDatagram => _pick(
    'Proxy core adapter over TURN datagram',
    'Proxy core adapter поверх TURN datagram',
  );
  String get proxyCoreOverTurnDtls => _pick(
    'Proxy core adapter over TURN DTLS overlay',
    'Proxy core adapter поверх TURN DTLS overlay',
  );
  String get proxyCoreOverWebRtc => _pick(
    'Proxy core adapter over WebRTC data channel',
    'Proxy core adapter поверх WebRTC data channel',
  );
  String get trustTunnelOverTurnDatagram => _pick(
    'TrustTunnel native over TURN datagram',
    'TrustTunnel native поверх TURN datagram',
  );
  String get trustTunnelOverTurnDtls => _pick(
    'TrustTunnel native over TURN DTLS overlay',
    'TrustTunnel native поверх TURN DTLS overlay',
  );
  String get trustTunnelOverWebRtc => _pick(
    'TrustTunnel native over WebRTC data channel',
    'TrustTunnel native поверх WebRTC data channel',
  );
  String get ownedBrowserMissingMetadata => _pick(
    'This challenge does not advertise the app-owned browser metadata required for in-app continuation.',
    'Эта проверка не объявляет метаданные браузера приложения, необходимые для продолжения внутри приложения.',
  );
  String get ownedBrowserMissingUrl => _pick(
    'This challenge does not expose an in-app browser URL.',
    'Эта проверка не предоставляет URL встроенного браузера.',
  );
  String get ownedBrowserNoEvidence => _pick(
    'The embedded browser session did not expose any usable continuation evidence.',
    'Сессия встроенного браузера не предоставила пригодных данных для продолжения.',
  );
  String ownedBrowserTitle(String provider) =>
      _pick('$provider challenge', 'Проверка провайдера $provider');
  String get ownedBrowserOpenInvite => _pick('Open invite', 'Открыть инвайт');
  String get ownedBrowserCollecting => _pick('Collecting...', 'Сбор...');
  String get ownedBrowserContinue => _pick('Continue', 'Продолжить');
  String get ownedBrowserFallbackPrompt => _pick(
    'Complete the browser step in this in-app session, then continue.',
    'Завершите шаг в браузере в этой встроенной сессии, затем продолжите.',
  );
  String get ownedBrowserHideKeyboard => _pick(
    'Hide keyboard',
    'Скрыть клавиатуру',
  );
}

extension BuildContextShellTextX on BuildContext {
  ShellText get shellText => ShellText(this);
}
