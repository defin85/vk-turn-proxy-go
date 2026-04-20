import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_shell_i18n/flutter_shell_i18n.dart';
import 'package:flutter/services.dart';
import 'package:mobile_gui_shell/src/control/control_plane_models.dart';
import 'package:mobile_gui_shell/src/control/mobile_host_bridge.dart';
import 'package:webview_cookie_manager_flutter/webview_cookie_manager.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

abstract class OwnedBrowserChallengeRunner {
  Future<ChallengeContinuationSubmission?> run(
    BuildContext context,
    ChallengeRecord challenge,
  );
}

typedef OwnedBrowserWebSessionFactory =
    OwnedBrowserWebSession Function(
      ValueChanged<String> onWebResourceError,
      ValueChanged<Uri> onPageNavigation,
    );

Future<List<BrowserObservedRequestRecord>> _collectNoObservedRequests() async {
  return const <BrowserObservedRequestRecord>[];
}

void _debugLogContinuationEvidence({
  required List<BrowserCookieRecord> cookies,
  required List<BrowserObservedRequestRecord> observedRequests,
}) {
  assert(() {
    final requestSummaries = observedRequests
        .take(8)
        .map((request) {
          final uri = Uri.tryParse(request.url);
          final target = uri == null
              ? request.url
              : '${uri.host}${uri.path.isEmpty ? '/' : uri.path}';
          final formKeys = request.formValues.keys.toList(growable: false)
            ..sort();
          final bodyKeys = request.body.keys.toList(growable: false)..sort();
          return '${request.method} $target form=$formKeys body=$bodyKeys status=${request.statusCode}';
        })
        .join(' | ');
    debugPrint(
      'OwnedBrowser continuation evidence: cookies=${cookies.length} observed=${observedRequests.length}${requestSummaries.isEmpty ? '' : ' [$requestSummaries]'}',
    );
    return true;
  }());
}

class OwnedBrowserWebSession {
  const OwnedBrowserWebSession({
    required this.viewBuilder,
    required this.load,
    required this.clearSessionState,
    required this.collectCookies,
    this.collectObservedRequests = _collectNoObservedRequests,
    this.setUserAgent,
    this.getUserAgent,
    this.syncUserAgentMetadata,
    this.setUseWideViewPort,
    this.refreshViewport,
    this.collectDebugSnapshot,
  });

  final WidgetBuilder viewBuilder;
  final Future<void> Function(Uri uri) load;
  final Future<void> Function() clearSessionState;
  final Future<List<BrowserCookieRecord>> Function(List<String> urls)
  collectCookies;
  final Future<List<BrowserObservedRequestRecord>> Function()
  collectObservedRequests;
  final Future<void> Function(String userAgent)? setUserAgent;
  final Future<String?> Function()? getUserAgent;
  final Future<bool> Function(String? userAgent)? syncUserAgentMetadata;
  final Future<void> Function(bool enabled)? setUseWideViewPort;
  final Future<void> Function()? refreshViewport;
  final Future<Map<String, Object?>> Function()? collectDebugSnapshot;
}

const String _vkDesktopChromiumFallbackUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36';
const String _ownedBrowserObservedRequestChannelName =
    'OwnedBrowserStageObserver';
const List<String> _ownedBrowserObservedRequestAllowedOriginRules = <String>[
  'https://vk.com',
  'https://*.vk.com',
  'https://login.vk.com',
  'https://login.vk.ru',
  'https://*.vk.ru',
  'https://id.vk.ru',
  'https://api.vk.com',
];
const String _ownedBrowserObservedRequestBootstrap = r'''
(function() {
  if (window.__ownedBrowserStageObserverInstalled) {
    return;
  }
  window.__ownedBrowserStageObserverInstalled = true;
  function overrideReadonlyProperty(target, name, getter) {
    if (!target || typeof getter !== 'function') {
      return;
    }
    try {
      Object.defineProperty(target, name, {
        configurable: true,
        enumerable: true,
        get: getter
      });
    } catch (_) {}
  }
  function createMediaQueryList(query, matches) {
    return {
      matches: matches,
      media: query,
      onchange: null,
      addListener: function() {},
      removeListener: function() {},
      addEventListener: function() {},
      removeEventListener: function() {},
      dispatchEvent: function() { return true; }
    };
  }
  function installDesktopBrowserShims() {
    var ua = navigator.userAgent || '';
    if (ua.indexOf('Windows NT') === -1) {
      return;
    }
    var navigatorPrototype = Object.getPrototypeOf(navigator);
    overrideReadonlyProperty(navigatorPrototype, 'platform', function() {
      return 'Win32';
    });
    overrideReadonlyProperty(navigatorPrototype, 'maxTouchPoints', function() {
      return 0;
    });
    overrideReadonlyProperty(navigatorPrototype, 'vendor', function() {
      return 'Google Inc.';
    });
    overrideReadonlyProperty(window, 'orientation', function() {
      return undefined;
    });
    if (typeof window.matchMedia === 'function' &&
        !window.__ownedBrowserDesktopMatchMediaInstalled) {
      var originalMatchMedia = window.matchMedia.bind(window);
      window.matchMedia = function(query) {
        var normalized = String(query || '').toLowerCase().replace(/\s+/g, '');
        if (normalized === '(pointer:coarse)' ||
            normalized === '(any-pointer:coarse)' ||
            normalized === '(hover:none)' ||
            normalized === '(any-hover:none)') {
          return createMediaQueryList(query, false);
        }
        if (normalized === '(pointer:fine)' ||
            normalized === '(any-pointer:fine)' ||
            normalized === '(hover:hover)' ||
            normalized === '(any-hover:hover)') {
          return createMediaQueryList(query, true);
        }
        return originalMatchMedia(query);
      };
      window.__ownedBrowserDesktopMatchMediaInstalled = true;
    }
  }
  installDesktopBrowserShims();
  var channel = window.OwnedBrowserStageObserver;
  if (!channel || typeof channel.postMessage !== 'function') {
    return;
  }
  function parseJsonObject(raw) {
    if (!raw || typeof raw !== 'string') {
      return null;
    }
    try {
      var parsed = JSON.parse(raw);
      if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
        return null;
      }
      return parsed;
    } catch (_) {
      return null;
    }
  }
  function assignFormValue(target, key, value) {
    if (!key || typeof key !== 'string' || value === undefined || value === null) {
      return;
    }
    target[key] = typeof value === 'string' ? value : String(value);
  }
  function parseFormValues(body) {
    if (!body) {
      return null;
    }
    var values = {};
    if (typeof body === 'string') {
      new URLSearchParams(body).forEach(function(value, key) {
        assignFormValue(values, key, value);
      });
    } else if (typeof URLSearchParams !== 'undefined' && body instanceof URLSearchParams) {
      body.forEach(function(value, key) {
        assignFormValue(values, key, value);
      });
    } else if (typeof FormData !== 'undefined' && body instanceof FormData) {
      body.forEach(function(value, key) {
        assignFormValue(values, key, value);
      });
    } else {
      return null;
    }
    return Object.keys(values).length === 0 ? null : values;
  }
  function postObservedRequest(payload) {
    try {
      channel.postMessage(JSON.stringify(payload));
    } catch (_) {}
  }
  function parseXHRPayload(xhr) {
    if (!xhr) {
      return null;
    }
    var responseType = xhr.responseType || '';
    if (responseType === '' || responseType === 'text') {
      return parseJsonObject(xhr.responseText);
    }
    if (responseType === 'json') {
      var response = xhr.response;
      if (!response || typeof response !== 'object' || Array.isArray(response)) {
        return null;
      }
      return response;
    }
    if (typeof xhr.response === 'string') {
      return parseJsonObject(xhr.response);
    }
    return null;
  }
  var originalFetch = window.fetch;
  if (typeof originalFetch === 'function') {
    window.fetch = function(input, init) {
      var request = input instanceof Request ? input : null;
      var method = (init && init.method) || (request && request.method) || 'GET';
      var rawUrl = (typeof input === 'string' || input instanceof URL)
        ? String(input)
        : ((request && request.url) || '');
      var url = rawUrl ? String(new URL(rawUrl, window.location.href)) : '';
      var bodySource = init && Object.prototype.hasOwnProperty.call(init, 'body')
        ? init.body
        : null;
      var formValues = parseFormValues(bodySource);
      return originalFetch.apply(this, arguments).then(function(response) {
        if (String(method).toUpperCase() !== 'POST' || !response || typeof response.clone !== 'function') {
          return response;
        }
        return response.clone().text().then(function(text) {
          var payload = parseJsonObject(text);
          if (payload) {
            postObservedRequest({
              method: String(method).toUpperCase(),
              url: url,
              form_values: formValues || {},
              status_code: response.status || 0,
              body: payload
            });
          }
          return response;
        }).catch(function() {
          return response;
        });
      });
    };
  }
  var originalOpen = XMLHttpRequest.prototype.open;
  var originalSend = XMLHttpRequest.prototype.send;
  XMLHttpRequest.prototype.open = function(method, url) {
    this.__ownedBrowserObservedMethod = method;
    this.__ownedBrowserObservedUrl = url;
    return originalOpen.apply(this, arguments);
  };
  XMLHttpRequest.prototype.send = function(body) {
    var method = this.__ownedBrowserObservedMethod || 'GET';
    var rawUrl = this.__ownedBrowserObservedUrl || '';
    var url = rawUrl ? String(new URL(rawUrl, window.location.href)) : '';
    var formValues = parseFormValues(body);
    this.addEventListener('load', function() {
      if (String(method).toUpperCase() !== 'POST') {
        return;
      }
      var payload = parseXHRPayload(this);
      if (!payload) {
        return;
      }
      postObservedRequest({
        method: String(method).toUpperCase(),
        url: url,
        form_values: formValues || {},
        status_code: this.status || 0,
        body: payload
      });
    }, { once: true });
    return originalSend.apply(this, arguments);
  };
})();
''';

class WebViewOwnedBrowserChallengeRunner
    implements OwnedBrowserChallengeRunner {
  const WebViewOwnedBrowserChallengeRunner({
    OwnedBrowserWebSessionFactory? sessionFactory,
    MobileSoftKeyboardHider? keyboardHider,
    MobileWindowSoftInputModeController? softInputModeController,
    MobileOwnedBrowserSessionStateResetter? sessionStateResetter,
    this.showDebugDiagnostics = false,
  }) : _sessionFactory = sessionFactory,
       _keyboardHider =
           keyboardHider ?? const PlatformMobileSoftKeyboardHider(),
       _softInputModeController =
           softInputModeController ??
           const PlatformMobileWindowSoftInputModeController(),
       _sessionStateResetter =
           sessionStateResetter ??
           const PlatformMobileOwnedBrowserSessionStateResetter();

  final OwnedBrowserWebSessionFactory? _sessionFactory;
  final MobileSoftKeyboardHider _keyboardHider;
  final MobileWindowSoftInputModeController _softInputModeController;
  final MobileOwnedBrowserSessionStateResetter _sessionStateResetter;
  final bool showDebugDiagnostics;

  @override
  Future<ChallengeContinuationSubmission?> run(
    BuildContext context,
    ChallengeRecord challenge,
  ) async {
    final ownedBrowser = challenge.ownedBrowser;
    final openUrl = challenge.openUrl?.trim() ?? '';
    if (ownedBrowser == null || ownedBrowser.cookieUrls.isEmpty) {
      throw StateError(context.shellText.ownedBrowserMissingMetadata);
    }
    if (openUrl.isEmpty) {
      throw StateError(context.shellText.ownedBrowserMissingUrl);
    }
    return Navigator.of(context).push<ChallengeContinuationSubmission>(
      MaterialPageRoute<ChallengeContinuationSubmission>(
        builder: (BuildContext context) => _OwnedBrowserChallengePage(
          challenge: challenge,
          sessionFactory:
              _sessionFactory ??
              (
                ValueChanged<String> onWebResourceError,
                ValueChanged<Uri> onPageNavigation,
              ) => _createDefaultSession(
                onWebResourceError,
                onPageNavigation,
                _sessionStateResetter,
              ),
          keyboardHider: _keyboardHider,
          softInputModeController: _softInputModeController,
          showDebugDiagnostics: showDebugDiagnostics,
        ),
      ),
    );
  }

  static OwnedBrowserWebSession _createDefaultSession(
    ValueChanged<String> onWebResourceError,
    ValueChanged<Uri> onPageNavigation,
    MobileOwnedBrowserSessionStateResetter sessionStateResetter,
  ) {
    final cookieManager = WebviewCookieManager();
    final observedRequests = <BrowserObservedRequestRecord>[];
    final consoleMessages = <String>[];
    final controllerCreationParams =
        WebViewPlatform.instance is AndroidWebViewPlatform
        ? AndroidWebViewControllerCreationParams.fromPlatformWebViewControllerCreationParams(
            const PlatformWebViewControllerCreationParams(),
          )
        : const PlatformWebViewControllerCreationParams();
    final controller = WebViewController.fromPlatformCreationParams(
      controllerCreationParams,
    );
    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setOnConsoleMessage((JavaScriptConsoleMessage message) {
        final level = message.level.name.trim();
        final text = message.message.trim();
        if (text.isEmpty) {
          return;
        }
        final summary = level.isEmpty ? text : '$level: $text';
        consoleMessages.add(summary);
        if (consoleMessages.length > 8) {
          consoleMessages.removeRange(0, consoleMessages.length - 8);
        }
      })
      ..addJavaScriptChannel(
        _ownedBrowserObservedRequestChannelName,
        onMessageReceived: (JavaScriptMessage message) {
          final parsed = _parseObservedBrowserRequestMessage(message.message);
          if (parsed != null) {
            observedRequests.add(parsed);
          }
        },
      );
    controller.setNavigationDelegate(
      NavigationDelegate(
        onPageStarted: (String url) {
          unawaited(_installOwnedBrowserObserver(controller));
        },
        onPageFinished: (String url) {
          final parsed = Uri.tryParse(url);
          if (parsed != null) {
            onPageNavigation(parsed);
          }
          unawaited(_installOwnedBrowserObserver(controller));
        },
        onWebResourceError: (WebResourceError error) {
          onWebResourceError(error.description);
        },
      ),
    );
    PlatformWebViewWidgetCreationParams widgetCreationParams =
        PlatformWebViewWidgetCreationParams(controller: controller.platform);
    Future<Map<String, Object?>> Function()? collectDebugSnapshot;
    PlatformMobileWebViewUserAgentMetadataController?
    userAgentMetadataController;
    int? androidWebViewIdentifier;
    if (WebViewPlatform.instance is AndroidWebViewPlatform) {
      widgetCreationParams =
          AndroidWebViewWidgetCreationParams.fromPlatformWebViewWidgetCreationParams(
            widgetCreationParams,
            displayWithHybridComposition: true,
          );
      final androidController = controller.platform as AndroidWebViewController;
      const scriptInstaller =
          PlatformMobileWebViewDocumentStartScriptInstaller();
      userAgentMetadataController =
          const PlatformMobileWebViewUserAgentMetadataController();
      androidWebViewIdentifier = androidController.webViewIdentifier;
      unawaited(
        scriptInstaller.install(
          webViewIdentifier: androidWebViewIdentifier,
          javaScript: _ownedBrowserObservedRequestBootstrap,
          allowedOriginRules: _ownedBrowserObservedRequestAllowedOriginRules,
        ),
      );
      const inspector = PlatformMobileWebViewDebugInspector();
      collectDebugSnapshot = () =>
          inspector.snapshot(webViewIdentifier: androidWebViewIdentifier!);
    }

    final debugSnapshotCollector = collectDebugSnapshot;

    return OwnedBrowserWebSession(
      viewBuilder: (BuildContext context) =>
          WebViewWidget.fromPlatformCreationParams(
            params: widgetCreationParams,
          ),
      load: (Uri uri) async {
        observedRequests.clear();
        await controller.loadRequest(uri);
      },
      clearSessionState: sessionStateResetter.clearSessionState,
      setUserAgent: (String userAgent) => controller.setUserAgent(userAgent),
      getUserAgent: () async {
        if (controller.platform case final AndroidWebViewController android) {
          return android.getUserAgent();
        }
        return null;
      },
      syncUserAgentMetadata: (String? userAgent) async {
        if (userAgentMetadataController == null ||
            androidWebViewIdentifier == null) {
          return true;
        }
        return userAgentMetadataController.sync(
          webViewIdentifier: androidWebViewIdentifier,
          userAgent: userAgent,
        );
      },
      setUseWideViewPort: (bool enabled) async {
        if (controller.platform case final AndroidWebViewController android) {
          await android.setUseWideViewPort(enabled);
        }
      },
      collectCookies: (List<String> urls) async {
        final cookies = <BrowserCookieRecord>[];
        final seen = <String>{};
        for (final rawUrl in urls) {
          final urlCookies = await cookieManager.getCookies(rawUrl);
          for (final cookie in urlCookies) {
            final key = [
              cookie.name,
              cookie.domain,
              cookie.path,
              cookie.secure,
              cookie.httpOnly,
            ].join('|');
            if (!seen.add(key)) {
              continue;
            }
            cookies.add(
              BrowserCookieRecord(
                name: cookie.name,
                value: cookie.value,
                domain: cookie.domain,
                path: cookie.path,
                expires: cookie.expires?.toUtc(),
                secure: cookie.secure,
                httpOnly: cookie.httpOnly,
              ),
            );
          }
        }
        return cookies;
      },
      collectObservedRequests: () async =>
          List<BrowserObservedRequestRecord>.unmodifiable(observedRequests),
      refreshViewport: () => nudgeOwnedBrowserViewport(controller),
      collectDebugSnapshot: debugSnapshotCollector == null
          ? null
          : () async {
              final snapshot = await debugSnapshotCollector();
              final currentUrl = await controller.currentUrl();
              if (currentUrl != null && currentUrl.trim().isNotEmpty) {
                snapshot['page_url'] = currentUrl.trim();
              }
              final pageTitle = await controller.getTitle();
              if (pageTitle != null && pageTitle.trim().isNotEmpty) {
                snapshot['page_title'] = pageTitle.trim();
              }
              if (consoleMessages.isNotEmpty) {
                snapshot['page_console_messages'] = List<String>.unmodifiable(
                  consoleMessages,
                );
              }
              final pageState = await _collectOwnedBrowserPageState(controller);
              if (pageState != null) {
                snapshot.addAll(pageState);
              }
              return snapshot;
            },
    );
  }
}

class _OwnedBrowserChallengePage extends StatefulWidget {
  const _OwnedBrowserChallengePage({
    required this.challenge,
    required this.sessionFactory,
    required this.keyboardHider,
    required this.softInputModeController,
    required this.showDebugDiagnostics,
  });

  final ChallengeRecord challenge;
  final OwnedBrowserWebSessionFactory sessionFactory;
  final MobileSoftKeyboardHider keyboardHider;
  final MobileWindowSoftInputModeController softInputModeController;
  final bool showDebugDiagnostics;

  @override
  State<_OwnedBrowserChallengePage> createState() =>
      _OwnedBrowserChallengePageState();
}

class _OwnedBrowserChallengePageState extends State<_OwnedBrowserChallengePage>
    with WidgetsBindingObserver {
  late final OwnedBrowserWebSession _session;
  ui.FlutterView? _flutterView;
  Timer? _debugPollTimer;
  Timer? _transportReadyAutoCompleteTimer;
  Timer? _viewportRefreshTimer;
  double _keyboardInsetBottom = 0;
  bool _submitting = false;
  bool _transportReadyAutoCompleteTriggered = false;
  String? _error;
  String? _debugSnapshot;
  bool _keyboardVisible = false;
  bool _transportReadyAutoCompleteEnabled = false;
  Uri? _openUri;
  Uri? _harnessInviteUri;
  bool _harnessInviteLoaded = false;
  bool _restoredInviteAfterFeed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _session = widget.sessionFactory(
      (String description) {
        if (!mounted) {
          return;
        }
        setState(() {
          _error = description;
        });
      },
      (Uri uri) {
        _handlePageNavigation(uri);
      },
    );
    final challengeUri = Uri.parse(widget.challenge.openUrl!.trim());
    _harnessInviteUri = _extractHarnessInviteUri(
      widget.challenge,
      challengeUri,
    );
    _transportReadyAutoCompleteEnabled =
        widget.challenge.ownedBrowser?.autoContinueOnTransportReady == true ||
        _extractHarnessAutoCompleteEnabled(widget.challenge, challengeUri);
    final openUri = _normalizeChallengeOpenUri(widget.challenge, challengeUri);
    _openUri = openUri;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(widget.softInputModeController.enableOwnedBrowserMode());
      _start(openUri);
    });
    _startDebugPolling();
    _startTransportReadyAutoCompletePolling();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _flutterView = View.maybeOf(context);
    _syncKeyboardInset(notify: false);
  }

  @override
  void didChangeMetrics() {
    _syncKeyboardInset();
  }

  Future<void> _start(Uri uri) async {
    try {
      final copy = context.shellText;
      final preferredUserAgent = _preferredUserAgentForChallenge(
        widget.challenge,
        currentUserAgent: await _session.getUserAgent?.call(),
      );
      final metadataSynced = await _session.syncUserAgentMetadata?.call(
        preferredUserAgent,
      );
      if (preferredUserAgent != null && metadataSynced == false) {
        throw StateError(copy.ownedBrowserDesktopFingerprintUnavailable);
      }
      await _session.setUseWideViewPort?.call(preferredUserAgent != null);
      if (preferredUserAgent != null) {
        await _session.setUserAgent?.call(preferredUserAgent);
      }
      if (_shouldResetBrowserStateForChallenge(widget.challenge)) {
        await _session.clearSessionState();
      }
      await _session.load(uri);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = '$error';
      });
    }
  }

  Future<void> _loadHarnessInvite() async {
    final inviteUri = _harnessInviteUri;
    if (inviteUri == null) {
      return;
    }
    setState(() {
      _harnessInviteLoaded = true;
    });
    await _session.load(inviteUri);
  }

  void _handlePageNavigation(Uri uri) {
    if (widget.showDebugDiagnostics) {
      debugPrint('OWNED_BROWSER_NAVIGATED $uri');
    }
    if (!mounted || !_shouldReturnInviteFromFeed(uri)) {
      return;
    }
    _restoredInviteAfterFeed = true;
    unawaited(_session.load(_openUri!));
  }

  bool _shouldReturnInviteFromFeed(Uri currentUri) {
    if (_restoredInviteAfterFeed) {
      return false;
    }
    final openUri = _openUri;
    if (openUri == null || !_isVkInviteUri(openUri)) {
      return false;
    }
    return _isVkFeedUri(currentUri);
  }

  void _startDebugPolling() {
    if (!widget.showDebugDiagnostics || _session.collectDebugSnapshot == null) {
      return;
    }
    unawaited(_refreshDebugSnapshot());
    _debugPollTimer = Timer.periodic(const Duration(milliseconds: 700), (_) {
      unawaited(_refreshDebugSnapshot());
    });
  }

  void _startTransportReadyAutoCompletePolling() {
    if (!_transportReadyAutoCompleteEnabled) {
      return;
    }
    unawaited(_maybeCompleteOnTransportReady());
    _transportReadyAutoCompleteTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) {
        unawaited(_maybeCompleteOnTransportReady());
      },
    );
  }

  Future<void> _maybeCompleteOnTransportReady() async {
    if (!_transportReadyAutoCompleteEnabled ||
        _submitting ||
        _transportReadyAutoCompleteTriggered ||
        !mounted) {
      return;
    }
    final observedRequests = await _session.collectObservedRequests();
    if (!_containsTransportReadyObservation(observedRequests)) {
      return;
    }
    _transportReadyAutoCompleteTriggered = true;
    await _complete();
    if (mounted && !_submitting) {
      _transportReadyAutoCompleteTriggered = false;
    }
  }

  Future<void> _refreshDebugSnapshot() async {
    final collector = _session.collectDebugSnapshot;
    if (collector == null || !mounted) {
      return;
    }
    final snapshot = await collector();
    if (!mounted) {
      return;
    }
    final formatted = _formatDebugSnapshot(snapshot);
    if (_debugSnapshot == formatted) {
      return;
    }
    if (widget.showDebugDiagnostics) {
      debugPrint('OWNED_BROWSER_DEBUG\n$formatted');
    }
    setState(() {
      _debugSnapshot = formatted;
    });
  }

  void _syncKeyboardInset({bool notify = true}) {
    final view = _flutterView ?? View.maybeOf(context);
    if (view == null) {
      return;
    }
    final devicePixelRatio = view.devicePixelRatio;
    final logicalBottom = devicePixelRatio == 0
        ? view.viewInsets.bottom
        : view.viewInsets.bottom / devicePixelRatio;
    final keyboardVisible = logicalBottom > 0.5;
    if (_keyboardVisible != keyboardVisible) {
      _keyboardVisible = keyboardVisible;
      _updateViewportRefreshLoop();
      _nudgeViewportForImeTransition();
    }
    if ((_keyboardInsetBottom - logicalBottom).abs() < 0.5) {
      return;
    }
    if (!notify || !mounted) {
      _keyboardInsetBottom = logicalBottom;
      return;
    }
    setState(() {
      _keyboardInsetBottom = logicalBottom;
    });
  }

  void _nudgeViewportForImeTransition() {
    if (_session.refreshViewport == null) {
      return;
    }
    for (final delay in <Duration>[
      Duration.zero,
      const Duration(milliseconds: 120),
      const Duration(milliseconds: 320),
    ]) {
      unawaited(
        Future<void>.delayed(delay).then((_) async {
          if (!mounted) {
            return;
          }
          await _refreshViewportSilently();
        }),
      );
    }
  }

  void _updateViewportRefreshLoop() {
    _viewportRefreshTimer?.cancel();
    if (!_keyboardVisible || _session.refreshViewport == null) {
      return;
    }
    _viewportRefreshTimer = Timer.periodic(const Duration(milliseconds: 700), (
      _,
    ) {
      unawaited(_refreshViewportSilently());
    });
  }

  Future<void> _refreshViewportSilently() async {
    final refreshViewport = _session.refreshViewport;
    if (refreshViewport == null || !mounted) {
      return;
    }
    try {
      await refreshViewport();
    } catch (_) {}
  }

  Future<void> _complete() async {
    if (_submitting) {
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final noEvidenceMessage = context.shellText.ownedBrowserNoEvidence;
    try {
      final cookies = await _session.collectCookies(
        widget.challenge.ownedBrowser?.cookieUrls ?? const <String>[],
      );
      final observedRequests = await _session.collectObservedRequests();
      if (cookies.isEmpty && observedRequests.isEmpty) {
        throw StateError(noEvidenceMessage);
      }
      _debugLogContinuationEvidence(
        cookies: cookies,
        observedRequests: observedRequests,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(
        ChallengeContinuationSubmission(
          cookies: cookies,
          observedRequests: observedRequests,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _submitting = false;
        _error = '$error';
      });
    }
  }

  Future<void> _hideKeyboard() async {
    FocusManager.instance.primaryFocus?.unfocus();
    try {
      await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    } catch (_) {}
    await widget.keyboardHider.hide();
  }

  @override
  void dispose() {
    _debugPollTimer?.cancel();
    _transportReadyAutoCompleteTimer?.cancel();
    _viewportRefreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(widget.softInputModeController.restoreDefaultMode());
    if (_shouldResetBrowserStateForChallenge(widget.challenge)) {
      unawaited(_session.clearSessionState());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final challenge = widget.challenge;
    final theme = Theme.of(context);
    final copy = context.shellText;
    final keyboardInsetBottom = math.max(
      MediaQuery.viewInsetsOf(context).bottom,
      _keyboardInsetBottom,
    );
    final keyboardVisible = keyboardInsetBottom > 0;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text(copy.ownedBrowserTitle(challenge.provider)),
        actions: <Widget>[
          if (_harnessInviteUri != null && !_harnessInviteLoaded)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Center(
                child: TextButton(
                  onPressed: _submitting
                      ? null
                      : () => unawaited(_loadHarnessInvite()),
                  child: Text(copy.ownedBrowserOpenInvite),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: TextButton(
                onPressed: _submitting ? null : _complete,
                child: Text(
                  _submitting
                      ? copy.ownedBrowserCollecting
                      : copy.ownedBrowserContinue,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // Keep the platform view under stable constraints while IME appears.
          Positioned.fill(child: _session.viewBuilder(context)),
          if (!keyboardVisible)
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: SafeArea(
                bottom: false,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        challenge.prompt?.trim().isNotEmpty == true
                            ? challenge.prompt!
                            : copy.ownedBrowserFallbackPrompt,
                        style: theme.textTheme.bodyMedium,
                      ),
                      if (_error != null) ...<Widget>[
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ],
                      if (_debugSnapshot != null) ...<Widget>[
                        const SizedBox(height: 12),
                        _OwnedBrowserDebugPanel(snapshot: _debugSnapshot!),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          if (keyboardVisible)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (_debugSnapshot != null)
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: _OwnedBrowserDebugPanel(
                            snapshot: _debugSnapshot!,
                          ),
                        ),
                      )
                    else
                      const Spacer(),
                    if (_debugSnapshot != null) const SizedBox(width: 12),
                    FilledButton.tonalIcon(
                      onPressed: _submitting ? null : _hideKeyboard,
                      icon: const Icon(Icons.keyboard_hide_rounded),
                      label: Text(copy.ownedBrowserHideKeyboard),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

bool _isVkInviteUri(Uri uri) {
  if (!_isVkHost(uri.host)) {
    return false;
  }
  return uri.path.startsWith('/call/join/');
}

bool _isVkFeedUri(Uri uri) {
  if (!_isVkHost(uri.host)) {
    return false;
  }
  final normalizedPath = uri.path.replaceFirst(RegExp(r'/+$'), '');
  return normalizedPath == '/feed';
}

bool _isVkHost(String host) {
  final normalized = host.trim().toLowerCase();
  return normalized == 'vk.com' ||
      normalized == 'www.vk.com' ||
      normalized == 'm.vk.com';
}

String? _preferredUserAgentForChallenge(
  ChallengeRecord challenge, {
  String? currentUserAgent,
}) {
  if (!_isVkOwnedBrowserLikeChallenge(challenge)) {
    return null;
  }
  return _desktopChromiumUserAgentFrom(currentUserAgent);
}

String _desktopChromiumUserAgentFrom(String? currentUserAgent) {
  final raw = currentUserAgent?.trim() ?? '';
  if (raw.isEmpty) {
    return _vkDesktopChromiumFallbackUserAgent;
  }
  final chromeMatch = RegExp(r'Chrome/([0-9.]+)').firstMatch(raw);
  final chromeVersion = chromeMatch?.group(1)?.trim();
  if (chromeVersion == null || chromeVersion.isEmpty) {
    return _vkDesktopChromiumFallbackUserAgent;
  }
  return 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/$chromeVersion Safari/537.36';
}

bool _shouldResetBrowserStateForChallenge(ChallengeRecord challenge) {
  if (challenge.id == 'owned-browser-ime-harness') {
    return true;
  }
  return challenge.ownedBrowser?.rememberSignIn != true;
}

bool _isVkOwnedBrowserLikeChallenge(ChallengeRecord challenge) {
  if (challenge.provider.trim().toLowerCase() == 'vk') {
    return true;
  }
  return challenge.id == 'owned-browser-ime-harness';
}

Uri _normalizeChallengeOpenUri(ChallengeRecord challenge, Uri openUri) {
  if (challenge.id != 'owned-browser-ime-harness') {
    return openUri;
  }
  if (!openUri.hasFragment) {
    return openUri;
  }
  return openUri.replace(fragment: '');
}

Uri? _extractHarnessInviteUri(ChallengeRecord challenge, Uri openUri) {
  if (challenge.id != 'owned-browser-ime-harness') {
    return null;
  }
  final fragment = openUri.fragment.trim();
  if (!fragment.startsWith('codex-invite=')) {
    return null;
  }
  final encoded = fragment.substring('codex-invite='.length).trim();
  if (encoded.isEmpty) {
    return null;
  }
  return Uri.tryParse(Uri.decodeComponent(encoded));
}

bool _extractHarnessAutoCompleteEnabled(
  ChallengeRecord challenge,
  Uri openUri,
) {
  if (challenge.id != 'owned-browser-ime-harness') {
    return false;
  }
  final fragment = openUri.fragment.trim();
  if (fragment.isEmpty) {
    return false;
  }
  final parameters = Uri.splitQueryString(fragment);
  final rawValue =
      parameters['codex-auto-complete']?.trim().toLowerCase() ?? '';
  return rawValue == '1' || rawValue == 'true' || rawValue == 'yes';
}

Future<void> nudgeOwnedBrowserViewport(WebViewController controller) async {
  await controller.runJavaScript('''
    (function() {
      window.dispatchEvent(new Event('resize'));
      const active = document.activeElement;
      if (active && typeof active.scrollIntoView === 'function') {
        active.scrollIntoView({block: 'center', inline: 'nearest'});
      }
    })();
  ''');
}

String _formatDebugSnapshot(Map<String, Object?> snapshot) {
  if (snapshot.isEmpty) {
    return 'native: no snapshot';
  }
  final error = snapshot['error'];
  if (error is String && error.isNotEmpty) {
    return 'native error: $error';
  }
  final lines = <String>[
    'ime visible=${snapshot['ime_visible'] ?? '?'} bottom=${snapshot['ime_inset_bottom'] ?? '?'} accepting=${snapshot['ime_accepting_text'] ?? '?'} active=${snapshot['ime_active_for_web_view'] ?? '?'}',
    'softInput=${snapshot['window_soft_input_mode_hex'] ?? snapshot['window_soft_input_mode'] ?? '?'}',
    'focus activity=${snapshot['activity_focus_class'] ?? '-'}',
    'focus decor=${snapshot['decor_focus_class'] ?? '-'}',
    'focus web=${snapshot['web_view_find_focus_class'] ?? '-'}',
    'webView ${snapshot['web_view_width'] ?? '?'}x${snapshot['web_view_height'] ?? '?'} @ ${snapshot['web_view_screen_x'] ?? '?'},${snapshot['web_view_screen_y'] ?? '?'}',
    'inputCalls=${snapshot['input_connection_calls'] ?? '?'} ime=${snapshot['last_ime_options_hex'] ?? snapshot['last_ime_options'] ?? '?'} noFullscreen=${snapshot['last_no_fullscreen_flag'] ?? '?'} noExtract=${snapshot['last_no_extract_ui_flag'] ?? '?'}',
    'inputType=${snapshot['last_input_type_hex'] ?? snapshot['last_input_type'] ?? '?'} sel=${snapshot['last_initial_selection_start'] ?? '?'}..${snapshot['last_initial_selection_end'] ?? '?'}',
  ];
  final pageUrl = snapshot['page_url'];
  if (pageUrl is String && pageUrl.isNotEmpty) {
    lines.add('page url=$pageUrl');
  }
  final pageTitle = snapshot['page_title'];
  if (pageTitle is String && pageTitle.isNotEmpty) {
    lines.add('page title=$pageTitle');
  }
  final pageReadyState = snapshot['page_ready_state'];
  if (pageReadyState is String && pageReadyState.isNotEmpty) {
    lines.add('page ready=$pageReadyState');
  }
  final pageNavigatorPlatform = snapshot['page_navigator_platform'];
  if (pageNavigatorPlatform is String && pageNavigatorPlatform.isNotEmpty) {
    lines.add('page platform=$pageNavigatorPlatform');
  }
  final pageNavigatorUa = snapshot['page_navigator_user_agent'];
  if (pageNavigatorUa is String && pageNavigatorUa.isNotEmpty) {
    lines.add('page ua=$pageNavigatorUa');
  }
  final pageNavigatorUaData = snapshot['page_navigator_user_agent_data'];
  if (pageNavigatorUaData is String && pageNavigatorUaData.isNotEmpty) {
    lines.add('page uaData=$pageNavigatorUaData');
  }
  final pageNavigatorTouchPoints = snapshot['page_navigator_max_touch_points'];
  final pagePointerCoarse = snapshot['page_pointer_coarse'];
  final pageHoverNone = snapshot['page_hover_none'];
  if (pageNavigatorTouchPoints != null ||
      pagePointerCoarse != null ||
      pageHoverNone != null) {
    lines.add(
      'page input touchPoints=${pageNavigatorTouchPoints ?? '-'} coarse=${pagePointerCoarse ?? '-'} hoverNone=${pageHoverNone ?? '-'}',
    );
  }
  final pageActive = snapshot['page_active_element'];
  if (pageActive is Map<Object?, Object?>) {
    lines.add(
      'page active=${pageActive['tag'] ?? '-'} type=${pageActive['type'] ?? '-'} id=${pageActive['id'] ?? '-'} name=${pageActive['name'] ?? '-'} mode=${pageActive['inputMode'] ?? '-'} text=${pageActive['text'] ?? '-'}',
    );
  }
  final firstInput = snapshot['page_first_input'];
  if (firstInput is Map<Object?, Object?>) {
    lines.add(
      'page firstInput=${firstInput['tag'] ?? '-'} type=${firstInput['type'] ?? '-'} id=${firstInput['id'] ?? '-'} name=${firstInput['name'] ?? '-'} mode=${firstInput['inputMode'] ?? '-'}',
    );
  }
  final ctas = snapshot['page_visible_ctas'];
  if (ctas is List && ctas.isNotEmpty) {
    lines.add('page ctas=${ctas.take(4).join(' | ')}');
  }
  final pageDebugError = snapshot['page_debug_error'];
  if (pageDebugError is String && pageDebugError.isNotEmpty) {
    lines.add('page debug error=$pageDebugError');
  }
  final consoleMessages = snapshot['page_console_messages'];
  if (consoleMessages is List && consoleMessages.isNotEmpty) {
    lines.add('page console=${consoleMessages.take(4).join(' | ')}');
  }
  return lines.join('\n');
}

Future<Map<String, Object?>?> _collectOwnedBrowserPageState(
  WebViewController controller,
) async {
  try {
    final raw = await controller.runJavaScriptReturningResult('''
      (function() {
        function describeElement(element) {
          if (!element) {
            return null;
          }
          return {
            tag: element.tagName || null,
            type: element.type || null,
            id: element.id || null,
            name: element.name || null,
            inputMode: element.inputMode || null,
            text: (element.innerText || element.textContent || '').trim().slice(0, 120) || null
          };
        }
        function collectVisibleCtas() {
          var nodes = Array.from(
            document.querySelectorAll(
              'button, a, [role="button"], input[type="submit"], input[type="button"]'
            )
          );
          return nodes
            .filter(function(node) {
              var rect = node.getBoundingClientRect();
              if (rect.width <= 0 || rect.height <= 0) {
                return false;
              }
              var style = window.getComputedStyle(node);
              return style && style.display !== 'none' && style.visibility !== 'hidden';
            })
            .map(function(node) {
              return (node.innerText || node.textContent || node.value || node.getAttribute('aria-label') || '')
                .replace(/\\s+/g, ' ')
                .trim();
            })
            .filter(function(text) { return text.length > 0; })
            .slice(0, 8);
        }
        return JSON.stringify({
          page_ready_state: document.readyState || null,
          page_location_href: window.location.href || null,
          page_navigator_platform: navigator.platform || null,
          page_navigator_user_agent: navigator.userAgent || null,
          page_navigator_max_touch_points:
            typeof navigator.maxTouchPoints === 'number' ? navigator.maxTouchPoints : null,
          page_navigator_user_agent_data:
            typeof navigator.userAgentData === 'object' &&
                navigator.userAgentData &&
                typeof navigator.userAgentData.toJSON === 'function'
            ? JSON.stringify(navigator.userAgentData.toJSON())
            : null,
          page_pointer_coarse:
            typeof window.matchMedia === 'function'
            ? window.matchMedia('(pointer: coarse)').matches
            : null,
          page_hover_none:
            typeof window.matchMedia === 'function'
            ? window.matchMedia('(hover: none)').matches
            : null,
          page_active_element: describeElement(document.activeElement),
          page_first_input: describeElement(
            document.querySelector('input, textarea, [contenteditable="true"]')
          ),
          page_visible_ctas: collectVisibleCtas()
        });
      })();
    ''');
    final normalized = _normalizeOwnedBrowserJavaScriptResult(raw);
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    final decoded = jsonDecode(normalized);
    if (decoded is! Map) {
      return null;
    }
    return decoded.map<String, Object?>(
      (dynamic key, dynamic value) => MapEntry('$key', value),
    );
  } catch (error) {
    return <String, Object?>{'page_debug_error': '$error'};
  }
}

String? _normalizeOwnedBrowserJavaScriptResult(Object? raw) {
  if (raw == null) {
    return null;
  }
  if (raw is String) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty || trimmed == 'null' || trimmed == 'undefined') {
      return null;
    }
    if (trimmed.startsWith('"') && trimmed.endsWith('"')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is String) {
          return decoded;
        }
      } catch (_) {}
    }
    return trimmed;
  }
  return '$raw';
}

Future<void> _installOwnedBrowserObserver(WebViewController controller) async {
  try {
    await controller.runJavaScript(_ownedBrowserObservedRequestBootstrap);
  } catch (_) {}
}

bool _containsTransportReadyObservation(
  List<BrowserObservedRequestRecord> observedRequests,
) {
  return observedRequests.any(_isTransportReadyObservation);
}

bool _isTransportReadyObservation(BrowserObservedRequestRecord request) {
  if (request.method.toUpperCase() != 'POST' || request.statusCode != 200) {
    return false;
  }
  final uri = Uri.tryParse(request.url);
  if (uri == null || uri.host != 'calls.okcdn.ru' || uri.path != '/fb.do') {
    return false;
  }
  if (request.formValues['method'] != 'vchat.startConversation' ||
      request.formValues['createJoinLink'] != 'true') {
    return false;
  }
  final body = request.body;
  final turnServer = body['turn_server'];
  if (turnServer is! Map<String, dynamic>) {
    return false;
  }
  final urls = turnServer['urls'];
  return _hasNonEmptyString(body['endpoint']) &&
      _hasNonEmptyString(body['wt_endpoint']) &&
      _hasNonEmptyString(body['token']) &&
      _hasNonEmptyString(turnServer['username']) &&
      _hasNonEmptyString(turnServer['credential']) &&
      urls is List &&
      urls.isNotEmpty;
}

bool _hasNonEmptyString(dynamic value) {
  return value is String && value.trim().isNotEmpty;
}

BrowserObservedRequestRecord? _parseObservedBrowserRequestMessage(
  String message,
) {
  final trimmed = message.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  final decoded = jsonDecode(trimmed);
  if (decoded is! Map<String, dynamic>) {
    return null;
  }
  final method = (decoded['method'] as String? ?? '').trim();
  final url = (decoded['url'] as String? ?? '').trim();
  final statusCode = decoded['status_code'] as int? ?? 0;
  final body = decoded['body'];
  if (method.isEmpty ||
      url.isEmpty ||
      statusCode == 0 ||
      body is! Map<String, dynamic>) {
    return null;
  }
  final rawFormValues =
      decoded['form_values'] as Map<String, dynamic>? ??
      const <String, dynamic>{};
  final formValues = <String, String>{};
  rawFormValues.forEach((String key, dynamic value) {
    final trimmedKey = key.trim();
    if (trimmedKey.isEmpty || value == null) {
      return;
    }
    formValues[trimmedKey] = value.toString();
  });
  return BrowserObservedRequestRecord(
    method: method,
    url: url,
    formValues: Map<String, String>.unmodifiable(formValues),
    statusCode: statusCode,
    body: Map<String, dynamic>.unmodifiable(body),
  );
}

class _OwnedBrowserDebugPanel extends StatefulWidget {
  const _OwnedBrowserDebugPanel({required this.snapshot});

  final String snapshot;

  @override
  State<_OwnedBrowserDebugPanel> createState() =>
      _OwnedBrowserDebugPanelState();
}

class _OwnedBrowserDebugPanelState extends State<_OwnedBrowserDebugPanel> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = _debugSummary(widget.snapshot);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: Card(
        key: const ValueKey<String>('owned-browser-debug-panel'),
        color: theme.colorScheme.surface.withValues(alpha: 0.94),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            setState(() {
              _expanded = !_expanded;
            });
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.bug_report_outlined,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        summary,
                        maxLines: _expanded ? 3 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _expanded ? 'Hide' : 'Debug',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (_expanded) ...<Widget>[
                  const SizedBox(height: 10),
                  Text(
                    widget.snapshot,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _debugSummary(String snapshot) {
  String? extract(String prefix) {
    for (final line in snapshot.split('\n')) {
      if (line.startsWith(prefix)) {
        return line.substring(prefix.length).trim();
      }
    }
    return null;
  }

  final ready = extract('page ready=');
  final title = extract('page title=');
  final url = extract('page url=');
  final uaData = extract('page uaData=');
  final host = url == null ? null : Uri.tryParse(url)?.host;
  final fingerprint = uaData != null && uaData.contains('"platform":"Windows"')
      ? 'desktop hints'
      : 'mixed hints';
  final parts = <String>[
    if (ready != null && ready.isNotEmpty) 'ready=$ready',
    fingerprint,
    if (host != null && host.isNotEmpty) host,
    if (title != null && title.isNotEmpty) title,
  ];
  return parts.join(' · ');
}
