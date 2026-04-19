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
  final Future<void> Function()? refreshViewport;
  final Future<Map<String, Object?>> Function()? collectDebugSnapshot;
}

const String _vkDesktopLikeUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:144.0) Gecko/20100101 Firefox/144.0';
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
    if (WebViewPlatform.instance is AndroidWebViewPlatform) {
      widgetCreationParams =
          AndroidWebViewWidgetCreationParams.fromPlatformWebViewWidgetCreationParams(
            widgetCreationParams,
            displayWithHybridComposition: true,
          );
      final androidController = controller.platform as AndroidWebViewController;
      const scriptInstaller =
          PlatformMobileWebViewDocumentStartScriptInstaller();
      unawaited(
        scriptInstaller.install(
          webViewIdentifier: androidController.webViewIdentifier,
          javaScript: _ownedBrowserObservedRequestBootstrap,
          allowedOriginRules: _ownedBrowserObservedRequestAllowedOriginRules,
        ),
      );
      const inspector = PlatformMobileWebViewDebugInspector();
      collectDebugSnapshot = () => inspector.snapshot(
        webViewIdentifier: androidController.webViewIdentifier,
      );
    }

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
      collectDebugSnapshot: collectDebugSnapshot,
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
  Timer? _viewportRefreshTimer;
  double _keyboardInsetBottom = 0;
  bool _submitting = false;
  String? _error;
  String? _debugSnapshot;
  bool _keyboardVisible = false;
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
    final openUri = _normalizeChallengeOpenUri(widget.challenge, challengeUri);
    _openUri = openUri;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(widget.softInputModeController.enableOwnedBrowserMode());
      _start(openUri);
    });
    _startDebugPolling();
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
      final preferredUserAgent = _preferredUserAgentForChallenge(
        widget.challenge,
      );
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

String? _preferredUserAgentForChallenge(ChallengeRecord challenge) {
  if (!_isVkOwnedBrowserLikeChallenge(challenge)) {
    return null;
  }
  return _vkDesktopLikeUserAgent;
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
  return lines.join('\n');
}

Future<void> _installOwnedBrowserObserver(WebViewController controller) async {
  try {
    await controller.runJavaScript(_ownedBrowserObservedRequestBootstrap);
  } catch (_) {}
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

class _OwnedBrowserDebugPanel extends StatelessWidget {
  const _OwnedBrowserDebugPanel({required this.snapshot});

  final String snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Card(
        key: const ValueKey<String>('owned-browser-debug-panel'),
        color: theme.colorScheme.surface.withValues(alpha: 0.94),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            snapshot,
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
              height: 1.3,
            ),
          ),
        ),
      ),
    );
  }
}
