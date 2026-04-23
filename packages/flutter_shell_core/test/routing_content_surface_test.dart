import 'package:flutter/material.dart';
import 'package:flutter_shell_core/flutter_shell_core.dart';
import 'package:flutter_shell_i18n/flutter_shell_i18n.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_i18n.dart';

void main() {
  testWidgets(
    'routing content surface renders desktop variant and updates spec fields',
    (WidgetTester tester) async {
      var latestSpec = ProfileDraft.defaults().spec;
      final initialSpec = latestSpec;

      await pumpShellCoreLocalizedTestApp(
        tester,
        child: SizedBox(
          width: 1400,
          height: 760,
          child: RoutingContentSurface(
            variant: RoutingContentSurfaceVariant.desktop,
            spec: initialSpec,
            selectedProfileName: 'vk live',
            selectedProfileProvider: 'vk',
            busy: false,
            hostReady: true,
            platformTunnels: const <PlatformTunnelCapability>[
              PlatformTunnelCapability(
                mode: PlatformTunnelMode.windowsWintun,
                available: true,
                satisfiedPrerequisites: <PlatformTunnelPrerequisite>[
                  PlatformTunnelPrerequisite.driver,
                ],
              ),
            ],
            platformTunnelResultFor: (_) => null,
            onSpecChanged: (ProfileSpec next) {
              latestSpec = next;
            },
            onSave: () async {},
            onOpenProfiles: () {},
            onStartProfile: () async {},
            onStartPlatformTunnel: (_) async {},
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('routing-content-surface-desktop')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>('routing-platform-tunnel-surface-desktop'),
        ),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(
          const ValueKey<String>('desktop-routing-listen-address-field'),
        ),
        '127.0.0.1:7001',
      );
      await tester.pump();

      expect(latestSpec.listenAddress, '127.0.0.1:7001');
    },
  );

  testWidgets(
    'routing content surface renders mobile variant and exposes stop action for ready tunnel',
    (WidgetTester tester) async {
      var stopCalls = 0;

      await pumpShellCoreLocalizedTestApp(
        tester,
        child: SingleChildScrollView(
          child: SizedBox(
            width: 460,
            child: RoutingContentSurface(
              variant: RoutingContentSurfaceVariant.mobile,
              spec: ProfileDraft.defaults().spec,
              selectedProfileName: 'vk mobile',
              selectedProfileProvider: 'vk',
              busy: false,
              hostReady: true,
              platformTunnels: const <PlatformTunnelCapability>[
                PlatformTunnelCapability(
                  mode: PlatformTunnelMode.androidVpnService,
                  available: true,
                  satisfiedPrerequisites: <PlatformTunnelPrerequisite>[
                    PlatformTunnelPrerequisite.permission,
                    PlatformTunnelPrerequisite.hostImplementation,
                  ],
                ),
              ],
              platformTunnelResultFor: (PlatformTunnelMode mode) =>
                  const PlatformTunnelStartResult(
                    mode: PlatformTunnelMode.androidVpnService,
                    ready: true,
                  ),
              onSpecChanged: (_) {},
              onSave: () async {},
              onOpenProfiles: () {},
              onStartProfile: () async {},
              onStartPlatformTunnel: (_) async {},
              onStopPlatformTunnel: (_) async {
                stopCalls += 1;
              },
            ),
          ),
        ),
      );

      final copy = tester.element(find.byType(MaterialApp)).shellText;

      expect(
        find.byKey(const ValueKey<String>('routing-content-surface-mobile')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>('routing-platform-tunnel-surface-mobile'),
        ),
        findsOneWidget,
      );
      expect(find.text(copy.disconnectVpn), findsOneWidget);

      await tester.ensureVisible(find.text(copy.disconnectVpn));
      await tester.pumpAndSettle();
      await tester.tap(find.text(copy.disconnectVpn));
      await tester.pump();

      expect(stopCalls, 1);
    },
  );
}
