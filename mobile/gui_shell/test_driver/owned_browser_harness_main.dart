import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_driver/driver_extension.dart';
import 'package:mobile_gui_shell/src/control/control_plane_models.dart';
import 'package:mobile_gui_shell/src/ui/owned_browser_challenge.dart';

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
  static final Uri _vkInviteUri = Uri.parse(
    'https://vk.com/call/join/nZQ-WqsQ8Fy3AOPEyc-pF_JWXzNLSqgvF3ypfP1DWJc',
  );
  static final Uri _vkLoginUri = Uri.parse(
    'https://calls.vk.com/#codex-invite=${Uri.encodeComponent(_vkInviteUri.toString())}',
  );
  // Flip this locally when the Android WebView IME path needs live diagnostics again.
  static const bool _showHarnessDiagnostics = false;

  bool _opened = false;
  String? _lastContinuationSummary;

  OwnedBrowserChallengeRunner get _runner =>
      const WebViewOwnedBrowserChallengeRunner(
        showDebugDiagnostics: _showHarnessDiagnostics,
      );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_opened) {
      return;
    }
    _opened = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_openHarness());
    });
  }

  Future<void> _openHarness() async {
    final result = await _runner.run(context, _challenge);
    if (!mounted) {
      return;
    }
    final observedTargets =
        result?.observedRequests
            .map(_formatObservedTargetSummary)
            .toList(growable: false) ??
        const <String>[];
    final interestingOkBodies =
        result?.observedRequests
            .where(_isInterestingOKCallRequest)
            .map(_formatInterestingOKCallBody)
            .toList(growable: false) ??
        const <String>[];
    final cookieDomains =
        result?.cookies
            .map((BrowserCookieRecord cookie) {
              final domain = (cookie.domain?.isNotEmpty ?? false)
                  ? cookie.domain!
                  : '<host-only>';
              return '$domain/${cookie.name}';
            })
            .toList(growable: false) ??
        const <String>[];
    final summary =
        'cookies=${result?.cookies.length ?? 0} observed_requests=${result?.observedRequests.length ?? 0} result=${result == null ? 'cancelled' : 'collected'}';
    debugPrint('OWNED_BROWSER_HARNESS_RESULT $summary');
    if (observedTargets.isNotEmpty) {
      debugPrint(
        'OWNED_BROWSER_HARNESS_OBSERVED\n${observedTargets.join('\n')}',
      );
    }
    for (final bodySummary in interestingOkBodies) {
      debugPrint('OWNED_BROWSER_HARNESS_OK_BODY\n$bodySummary');
    }
    if (cookieDomains.isNotEmpty) {
      debugPrint('OWNED_BROWSER_HARNESS_COOKIES\n${cookieDomains.join('\n')}');
    }
    setState(() {
      _lastContinuationSummary = summary;
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
        cookieUrls: <String>[
          'https://calls.vk.com/',
          'https://vk.com/',
          'https://login.vk.com/',
          'https://login.vk.ru/',
        ],
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            FilledButton(
              onPressed: () => unawaited(_openHarness()),
              child: const Text('Open owned-browser harness'),
            ),
            if (_lastContinuationSummary != null) ...<Widget>[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  _lastContinuationSummary!,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _formatObservedTargetSummary(BrowserObservedRequestRecord request) {
  final uri = Uri.tryParse(request.url);
  final target = uri == null
      ? request.url
      : '${uri.host}${uri.path.isEmpty ? '/' : uri.path}';
  final formKeys = request.formValues.keys.toList(growable: false)..sort();
  return '${request.method} $target form=$formKeys status=${request.statusCode}';
}

bool _isInterestingOKCallRequest(BrowserObservedRequestRecord request) {
  final uri = Uri.tryParse(request.url);
  if (uri == null || uri.host != 'calls.okcdn.ru' || uri.path != '/fb.do') {
    return false;
  }
  return request.formValues['method'] == 'auth.anonymLogin' ||
      request.formValues.containsKey('createJoinLink');
}

String _formatInterestingOKCallBody(BrowserObservedRequestRecord request) {
  final formValues = Map<String, String>.from(request.formValues);
  final okMethod = formValues['method'] ?? '<missing>';
  final createJoinLink = formValues['createJoinLink'];
  final descriptor = <String>[
    _formatObservedTargetSummary(request),
    'ok_method=$okMethod',
    if (createJoinLink != null) 'createJoinLink=$createJoinLink',
  ].join(' ');
  final bodyLines = _collectObservedBodyLines(request.body);
  return '$descriptor\n${bodyLines.join('\n')}';
}

List<String> _collectObservedBodyLines(
  dynamic value, {
  String prefix = 'body',
  int depth = 0,
  int budget = 80,
}) {
  if (budget <= 0) {
    return const <String>[];
  }
  if (depth >= 6) {
    return <String>['$prefix=<depth-limit>'];
  }
  if (value is Map) {
    if (value.isEmpty) {
      return <String>['$prefix={}'];
    }
    final keys = value.keys.map((key) => '$key').toList(growable: false)
      ..sort();
    final lines = <String>[];
    for (final key in keys) {
      final childBudget = budget - lines.length;
      if (childBudget <= 0) {
        break;
      }
      final childPrefix = '$prefix.$key';
      lines.addAll(
        _collectObservedBodyLines(
          value[key],
          prefix: childPrefix,
          depth: depth + 1,
          budget: childBudget,
        ),
      );
    }
    if (lines.length >= budget) {
      return <String>[...lines.take(budget - 1), '$prefix...=<truncated>'];
    }
    return lines;
  }
  if (value is List) {
    if (value.isEmpty) {
      return <String>['$prefix=[]'];
    }
    final limit = value.length > 5 ? 5 : value.length;
    final lines = <String>[];
    for (var index = 0; index < limit; index++) {
      final childBudget = budget - lines.length;
      if (childBudget <= 0) {
        break;
      }
      lines.addAll(
        _collectObservedBodyLines(
          value[index],
          prefix: '$prefix[$index]',
          depth: depth + 1,
          budget: childBudget,
        ),
      );
    }
    if (value.length > limit) {
      lines.add('$prefix[...]=<${value.length - limit} more>');
    }
    if (lines.length >= budget) {
      return <String>[...lines.take(budget - 1), '$prefix...=<truncated>'];
    }
    return lines;
  }
  return <String>['$prefix=${_formatObservedLeafValue(prefix, value)}'];
}

String _formatObservedLeafValue(String path, dynamic value) {
  final key = path.split('.').last.split('[').first.toLowerCase();
  if (_isSensitiveObservedField(key)) {
    return '<redacted>';
  }
  if (value == null) {
    return 'null';
  }
  if (value is String) {
    final singleLine = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (singleLine.isEmpty) {
      return '""';
    }
    if (singleLine.length > 160) {
      return '${singleLine.substring(0, 157)}...';
    }
    return singleLine;
  }
  return '$value';
}

bool _isSensitiveObservedField(String key) {
  switch (key) {
    case 'access_token':
    case 'anonymous_token':
    case 'anonymtoken':
    case 'anonym_token':
    case 'auth_token':
    case 'client_secret':
    case 'code':
    case 'credential':
    case 'httoken':
    case 'joinlink':
    case 'link_with_password':
    case 'oauth_force_hash':
    case 'oauth_state':
    case 'password':
    case 'session_data':
    case 'session_key':
    case 'sid':
    case 'short_link':
    case 'sua':
    case 'sui':
    case 'username':
    case 'verification_hash':
    case 'vkid_oauth_hash':
      return true;
  }
  return key.endsWith('_token') ||
      key.contains('password') ||
      key.contains('secret') ||
      key.contains('session') ||
      key.contains('token');
}
