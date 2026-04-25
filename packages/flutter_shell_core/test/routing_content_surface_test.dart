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
          height: 860,
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
      final copy = tester.element(find.byType(MaterialApp)).shellText;
      expect(find.text('Routing parameters'), findsOneWidget);
      expect(find.text('Profile settings'), findsNothing);
      expect(find.text(copy.saveProfile), findsOneWidget);
      expect(find.text(copy.openProfiles), findsNothing);
      expect(find.text(copy.startOnThisDevice), findsNothing);
      final listenAddressField = tester.widget<TextField>(
        find.byKey(
          const ValueKey<String>('desktop-routing-listen-address-field'),
        ),
      );
      expect(listenAddressField.decoration?.labelText, isNull);
      expect(find.text(copy.localUdpListen), findsOneWidget);
      expect(find.byType(ExpansionTile), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('desktop-routing-mode-field')),
        findsNothing,
      );
      final advancedToggle = find.byKey(
        const ValueKey<String>('desktop-routing-toggle-advanced'),
      );
      final desktopRoutingScrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        advancedToggle,
        120,
        scrollable: desktopRoutingScrollable,
      );
      await tester.pumpAndSettle();
      expect(find.text(copy.mobileAdvancedRuntimeControls), findsOneWidget);
      expect(find.text(copy.showAdvancedRuntimeControls), findsOneWidget);

      tester.widget<TextButton>(advancedToggle).onPressed!.call();
      await tester.pumpAndSettle();

      final modeField = tester.widget<DropdownButtonFormField<TransportMode>>(
        find.byKey(const ValueKey<String>('desktop-routing-mode-field')),
      );
      expect(modeField.decoration.labelText, isNull);
      expect(
        find.byKey(const ValueKey<String>('desktop-routing-mode-field')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>('routing-platform-tunnel-surface-desktop'),
        ),
        findsOneWidget,
      );
      expect(find.text('windows_wintun'), findsNothing);
      expect(find.text(copy.showPlatformTunnelDetails), findsOneWidget);
      expect(find.text(copy.requestStartup), findsOneWidget);

      tester
          .widget<TextButton>(
            find.byKey(
              const ValueKey<String>('routing-platform-tunnel-toggle-desktop'),
            ),
          )
          .onPressed!
          .call();
      await tester.pumpAndSettle();

      expect(find.text('windows_wintun'), findsOneWidget);
      expect(find.text(copy.requestStartup), findsOneWidget);

      await tester.scrollUntilVisible(
        find.byKey(
          const ValueKey<String>('desktop-routing-listen-address-field'),
        ),
        -120,
        scrollable: desktopRoutingScrollable,
      );
      await tester.pumpAndSettle();
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
