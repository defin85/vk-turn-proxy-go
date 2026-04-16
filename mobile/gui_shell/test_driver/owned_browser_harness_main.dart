import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_driver/driver_extension.dart';
import 'package:mobile_gui_shell/src/control/control_plane_models.dart';
import 'package:mobile_gui_shell/src/control/mobile_host_bridge.dart';
import 'package:mobile_gui_shell/src/ui/owned_browser_challenge.dart';
import 'package:webview_cookie_manager_flutter/webview_cookie_manager.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

Future<void> main() async {
  enableFlutterDriverExtension(enableTextEntryEmulation: false);
  runApp(const _OwnedBrowserHarnessApp());
}

class _OwnedBrowserHarnessApp extends StatelessWidget {
  const _OwnedBrowserHarnessApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF005F73)),
        useMaterial3: true,
      ),
      home: const _OwnedBrowserHarnessHome(),
    );
  }
}

class _OwnedBrowserHarnessHome extends StatefulWidget {
  const _OwnedBrowserHarnessHome();

  @override
  State<_OwnedBrowserHarnessHome> createState() =>
      _OwnedBrowserHarnessHomeState();
}

class _OwnedBrowserHarnessHomeState extends State<_OwnedBrowserHarnessHome> {
  static final Uri _vkLoginUri = Uri.parse('https://login.vk.ru/');
  // Flip this locally when the Android WebView IME path needs live diagnostics again.
  static const bool _showHarnessDiagnostics = false;
  static const String _vkImeBootstrapScript = r'''
    (function() {
      function normalize(text) {
        return (text || '').replace(/\s+/g, ' ').trim().toLowerCase();
      }

      function isVisible(element) {
        if (!element) return false;
        const style = window.getComputedStyle(element);
        if (style.visibility === 'hidden' || style.display === 'none') {
          return false;
        }
        const rect = element.getBoundingClientRect();
        return rect.width > 0 && rect.height > 0;
      }

      function clickManualEntry() {
        const selectors = [
          'button',
          '[role="button"]',
          'a',
          'span',
          'div',
        ];
        const phrases = [
          'ввести данные вручную',
          'войти по телефону или почте',
          'по телефону или почте',
          'другой способ',
        ];
        for (const selector of selectors) {
          const nodes = document.querySelectorAll(selector);
          for (const node of nodes) {
            if (!isVisible(node)) continue;
            const text = normalize(node.innerText || node.textContent);
            if (!text) continue;
            if (phrases.some((phrase) => text.includes(phrase))) {
              node.click();
              return true;
            }
          }
        }
        return false;
      }

      function focusBestInput() {
        const selectors = [
          'input[type="tel"]',
          'input[inputmode="numeric"]',
          'input[name*="phone" i]',
          'input[id*="phone" i]',
          'input[type="text"]',
          'input[type="email"]',
          'input:not([type="hidden"])',
          'textarea',
        ];
        for (const selector of selectors) {
          const candidate = document.querySelector(selector);
          if (!isVisible(candidate)) continue;
          candidate.focus();
          if (typeof candidate.setSelectionRange === 'function') {
            const end = candidate.value ? candidate.value.length : 0;
            candidate.setSelectionRange(end, end);
          }
          return true;
        }
        return false;
      }

      clickManualEntry();
      focusBestInput();
    })();
  ''';

  static const String _vkDomDebugScript = r'''
    (function() {
      function normalize(text) {
        return (text || '').replace(/\s+/g, ' ').trim();
      }

      function describe(element) {
        if (!element) return null;
        return {
          tag: element.tagName || null,
          type: element.type || null,
          id: element.id || null,
          name: element.name || null,
          inputMode: element.inputMode || null,
          text: normalize(element.innerText || element.textContent || ''),
        };
      }

      function visibleTexts(selector, limit) {
        const values = [];
        const nodes = document.querySelectorAll(selector);
        for (const node of nodes) {
          const style = window.getComputedStyle(node);
          if (style.visibility === 'hidden' || style.display === 'none') {
            continue;
          }
          const rect = node.getBoundingClientRect();
          if (rect.width === 0 || rect.height === 0) {
            continue;
          }
          const text = normalize(node.innerText || node.textContent || '');
          if (!text) continue;
          values.push(text);
          if (values.length >= limit) break;
        }
        return values;
      }

      return JSON.stringify({
        pageUrl: window.location.href,
        pageTitle: document.title,
        activeElement: describe(document.activeElement),
        firstInput: describe(
          document.querySelector('input:not([type="hidden"]), textarea')
        ),
        visibleCtas: visibleTexts('button, [role="button"], a', 6),
        visibleInputs: Array.from(
          document.querySelectorAll('input:not([type="hidden"]), textarea')
        ).slice(0, 4).map(describe),
      });
    })();
  ''';

  bool _opened = false;

  OwnedBrowserChallengeRunner get _runner => WebViewOwnedBrowserChallengeRunner(
    sessionFactory: _buildSession,
    showDebugDiagnostics: _showHarnessDiagnostics,
  );

  static OwnedBrowserWebSession _buildSession(
    ValueChanged<String> onWebResourceError,
  ) {
    final controllerCreationParams = WebViewPlatform.instance
            is AndroidWebViewPlatform
        ? AndroidWebViewControllerCreationParams
            .fromPlatformWebViewControllerCreationParams(
            const PlatformWebViewControllerCreationParams(),
          )
        : const PlatformWebViewControllerCreationParams();
    final controller = WebViewController.fromPlatformCreationParams(
      controllerCreationParams,
    );
    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            for (final delay in <Duration>[
              Duration.zero,
              const Duration(milliseconds: 300),
              const Duration(milliseconds: 900),
              const Duration(milliseconds: 1800),
            ]) {
              unawaited(
                Future<void>.delayed(delay).then((_) {
                  return controller.runJavaScript(_vkImeBootstrapScript);
                }),
              );
            }
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
      widgetCreationParams = AndroidWebViewWidgetCreationParams
          .fromPlatformWebViewWidgetCreationParams(
            widgetCreationParams,
            displayWithHybridComposition: true,
          );
      if (_showHarnessDiagnostics) {
        final androidController =
            controller.platform as AndroidWebViewController;
        const inspector = PlatformMobileWebViewDebugInspector();
        collectDebugSnapshot = () async {
          final nativeSnapshot = await inspector.snapshot(
            webViewIdentifier: androidController.webViewIdentifier,
          );
          final pageSnapshot = await _collectDomSnapshot(controller);
          return <String, Object?>{
            ...nativeSnapshot,
            ...pageSnapshot,
          };
        };
      }
    }
    final cookieManager = WebviewCookieManager();
    return OwnedBrowserWebSession(
      viewBuilder: (BuildContext context) =>
          WebViewWidget.fromPlatformCreationParams(
            params: widgetCreationParams,
          ),
      load: (_) => controller.loadRequest(_vkLoginUri),
      clearCookies: () => cookieManager.clearCookies(),
      collectCookies: (_) async => const <BrowserCookieRecord>[],
      refreshViewport: () => nudgeOwnedBrowserViewport(controller),
      collectDebugSnapshot: collectDebugSnapshot,
    );
  }

  static Future<Map<String, Object?>> _collectDomSnapshot(
    WebViewController controller,
  ) async {
    try {
      final raw = await controller.runJavaScriptReturningResult(
        _vkDomDebugScript,
      );
      final payload = switch (raw) {
        String value => value,
        _ => raw?.toString() ?? '',
      };
      if (payload.isEmpty) {
        return const <String, Object?>{};
      }
      final decoded = jsonDecode(payload);
      if (decoded is! Map) {
        return const <String, Object?>{};
      }
      return <String, Object?>{
        'page_url': decoded['pageUrl'],
        'page_title': decoded['pageTitle'],
        'page_active_element': decoded['activeElement'],
        'page_first_input': decoded['firstInput'],
        'page_visible_ctas': decoded['visibleCtas'],
        'page_visible_inputs': decoded['visibleInputs'],
      };
    } catch (error) {
      return <String, Object?>{
        'page_debug_error': '$error',
      };
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_opened) {
      return;
    }
    _opened = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_runner.run(context, _challenge));
    });
  }

  ChallengeRecord get _challenge {
    final now = DateTime.utc(2026, 4, 16, 15, 0);
    return ChallengeRecord(
      id: 'owned-browser-ime-harness',
      sessionId: 'owned-browser-ime-harness',
      provider: 'vk',
      stage: 'provider_resolve',
      kind: 'browser',
      prompt:
          'Owned-browser IME harness on the live VK auth page. The WebView must stay visible while the keyboard is open.',
      openUrl: _vkLoginUri.toString(),
      status: ChallengeStatus.pending,
      completionMode: ChallengeCompletionMode.ownedBrowserObserved,
      ownedBrowser: const ChallengeOwnedBrowserMetadata(
        cookieUrls: <String>['https://example.test/'],
      ),
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Owned Browser Harness')),
      body: Center(
        child: FilledButton(
          onPressed: () => unawaited(_runner.run(context, _challenge)),
          child: const Text('Open owned-browser harness'),
        ),
      ),
    );
  }
}
