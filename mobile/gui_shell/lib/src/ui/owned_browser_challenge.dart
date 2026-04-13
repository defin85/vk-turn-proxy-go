import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_gui_shell/src/control/control_plane_models.dart';
import 'package:webview_cookie_manager_flutter/webview_cookie_manager.dart';
import 'package:webview_flutter/webview_flutter.dart';

abstract class OwnedBrowserChallengeRunner {
  Future<ChallengeContinuationSubmission?> run(
    BuildContext context,
    ChallengeRecord challenge,
  );
}

class WebViewOwnedBrowserChallengeRunner
    implements OwnedBrowserChallengeRunner {
  const WebViewOwnedBrowserChallengeRunner();

  @override
  Future<ChallengeContinuationSubmission?> run(
    BuildContext context,
    ChallengeRecord challenge,
  ) async {
    final ownedBrowser = challenge.ownedBrowser;
    final openUrl = challenge.openUrl?.trim() ?? '';
    if (ownedBrowser == null || ownedBrowser.cookieUrls.isEmpty) {
      throw StateError(
        'This challenge does not advertise the app-owned browser metadata required for in-app continuation.',
      );
    }
    if (openUrl.isEmpty) {
      throw StateError('This challenge does not expose an in-app browser URL.');
    }
    return Navigator.of(context).push<ChallengeContinuationSubmission>(
      MaterialPageRoute<ChallengeContinuationSubmission>(
        builder: (BuildContext context) =>
            _OwnedBrowserChallengePage(challenge: challenge),
      ),
    );
  }
}

class _OwnedBrowserChallengePage extends StatefulWidget {
  const _OwnedBrowserChallengePage({required this.challenge});

  final ChallengeRecord challenge;

  @override
  State<_OwnedBrowserChallengePage> createState() =>
      _OwnedBrowserChallengePageState();
}

class _OwnedBrowserChallengePageState
    extends State<_OwnedBrowserChallengePage> {
  late final WebViewController _controller;
  final WebviewCookieManager _cookieManager = WebviewCookieManager();
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onWebResourceError: (WebResourceError error) {
            if (!mounted) {
              return;
            }
            setState(() {
              _error = error.description;
            });
          },
        ),
      );
    final openUri = Uri.parse(widget.challenge.openUrl!.trim());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _start(openUri);
    });
  }

  Future<void> _start(Uri uri) async {
    await _cookieManager.clearCookies();
    await _controller.loadRequest(uri);
  }

  Future<void> _complete() async {
    if (_submitting) {
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final cookies = <BrowserCookieRecord>[];
      final seen = <String>{};
      for (final rawUrl
          in widget.challenge.ownedBrowser?.cookieUrls ?? const <String>[]) {
        final urlCookies = await _cookieManager.getCookies(rawUrl);
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
      if (cookies.isEmpty) {
        throw StateError(
          'The embedded browser session did not expose any cookies for the documented continuation domains.',
        );
      }
      if (!mounted) {
        return;
      }
      Navigator.of(
        context,
      ).pop(ChallengeContinuationSubmission(cookies: cookies));
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

  @override
  void dispose() {
    unawaited(_cookieManager.clearCookies());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final challenge = widget.challenge;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('${challenge.provider} challenge')),
      body: Column(
        children: <Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: theme.colorScheme.surfaceContainerHighest,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  challenge.prompt?.trim().isNotEmpty == true
                      ? challenge.prompt!
                      : 'Complete the browser step in this in-app session, then continue.',
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
              ],
            ),
          ),
          Expanded(child: WebViewWidget(controller: _controller)),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: _submitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _submitting ? null : _complete,
                      child: Text(
                        _submitting ? 'Collecting session...' : 'Continue',
                      ),
                    ),
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
