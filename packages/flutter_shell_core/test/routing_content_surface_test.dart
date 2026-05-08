import 'package:flutter/material.dart';
import 'package:flutter_shell_core/flutter_shell_core.dart';
import 'package:flutter_shell_i18n/flutter_shell_i18n.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_i18n.dart';

void main() {
  testWidgets(
    'routing content surface renders desktop variant without profile editing',
    (WidgetTester tester) async {
      await pumpShellCoreLocalizedTestApp(
        tester,
        child: SizedBox(
          width: 1400,
          height: 860,
          child: RoutingContentSurface(
            variant: RoutingContentSurfaceVariant.desktop,
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
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('routing-content-surface-desktop')),
        findsOneWidget,
      );
      final copy = tester.element(find.byType(MaterialApp)).shellText;
      expect(find.text('Routing parameters'), findsNothing);
      expect(find.text('Profile settings'), findsNothing);
      expect(find.text(copy.saveProfile), findsNothing);
      expect(find.text(copy.openProfiles), findsNothing);
      expect(find.text(copy.startOnThisDevice), findsNothing);
      expect(find.text(copy.localUdpListen), findsNothing);
      expect(find.text(copy.peerAddress), findsNothing);
      expect(find.text(copy.connections), findsNothing);
      expect(find.text(copy.turnOverride), findsNothing);
      expect(find.byType(ExpansionTile), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('desktop-routing-mode-field')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('desktop-routing-toggle-advanced')),
        findsNothing,
      );
      expect(
        find.byKey(
          const ValueKey<String>('routing-platform-tunnel-surface-desktop'),
        ),
        findsOneWidget,
      );
      expect(find.text('windows_wintun'), findsNothing);
      expect(find.text(copy.showPlatformTunnelDetails), findsOneWidget);
      expect(find.text(copy.requestStartup), findsNothing);
      expect(find.text(copy.disconnectVpn), findsNothing);

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
      expect(find.text(copy.requestStartup), findsNothing);
      expect(find.text(copy.disconnectVpn), findsNothing);
    },
  );

  testWidgets(
    'routing content surface exposes structured editor actions and import fallback',
    (WidgetTester tester) async {
      var editCalls = 0;
      var importCalls = 0;
      var manageCalls = 0;
      var forgetCalls = 0;

      Future<void> pump({required bool configured}) async {
        await pumpShellCoreLocalizedTestApp(
          tester,
          child: SizedBox(
            width: 560,
            height: 720,
            child: RoutingContentSurface(
              variant: RoutingContentSurfaceVariant.desktop,
              busy: false,
              hostReady: true,
              platformTunnels: const <PlatformTunnelCapability>[
                PlatformTunnelCapability(
                  mode: PlatformTunnelMode.windowsWintun,
                  available: true,
                ),
              ],
              platformTunnelResultFor: (_) => null,
              transportProfileStatusSummaryForMode: (_) => configured
                  ? 'WireGuard profile configured'
                  : 'WireGuard profile required',
              platformTunnelStartBlockReasonForMode: (_) =>
                  'WireGuard profile required before startup',
              canConfigureTransportProfileForMode: (_) => true,
              canEditTransportProfileForMode: (_) => true,
              transportProfileConfiguredForMode: (_) => configured,
              onEditTransportProfile: (_) async {
                editCalls += 1;
              },
              onImportTransportProfile: (_) async {
                importCalls += 1;
              },
              onManageTransportProfiles: (_) async {
                manageCalls += 1;
              },
              onForgetTransportProfile: (_) async {
                forgetCalls += 1;
              },
            ),
          ),
        );
      }

      await pump(configured: false);
      await _tapRoutingAction(
        tester,
        'desktop-routing-create-vpn-transport-profile-windows_wintun',
      );
      await _tapRoutingAction(
        tester,
        'desktop-routing-import-vpn-transport-profile-windows_wintun',
      );
      await _tapRoutingAction(
        tester,
        'desktop-routing-open-vpn-transport-profiles-windows_wintun',
      );
      await tester.pump();

      expect(editCalls, 1);
      expect(importCalls, 1);
      expect(manageCalls, 1);

      await pump(configured: true);
      await _tapRoutingAction(
        tester,
        'desktop-routing-edit-vpn-transport-profile-windows_wintun',
      );
      await _tapRoutingAction(
        tester,
        'desktop-routing-replace-vpn-transport-profile-windows_wintun',
      );
      await tester.pumpAndSettle();
      expect(find.text('Replace VPN profile?'), findsOneWidget);
      await tester.tap(
        find.widgetWithText(FilledButton, 'Replace VPN profile'),
      );
      await tester.pumpAndSettle();
      await _tapRoutingAction(
        tester,
        'desktop-routing-open-vpn-transport-profiles-windows_wintun',
      );
      await _tapRoutingAction(
        tester,
        'desktop-routing-forget-vpn-transport-profile-windows_wintun',
      );
      await tester.pumpAndSettle();
      expect(find.text('Forget VPN profile?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Forget VPN profile'));
      await tester.pumpAndSettle();

      expect(editCalls, 2);
      expect(importCalls, 2);
      expect(manageCalls, 2);
      expect(forgetCalls, 1);
    },
  );

  testWidgets(
    'routing content surface renders mobile variant without vpn toggle actions',
    (WidgetTester tester) async {
      await pumpShellCoreLocalizedTestApp(
        tester,
        child: SingleChildScrollView(
          child: SizedBox(
            width: 460,
            child: RoutingContentSurface(
              variant: RoutingContentSurfaceVariant.mobile,
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
                    sessionId: 'session-android-1',
                    remoteIngress: RuntimeRemoteIngressDiagnostics(
                      endpointFamily: RuntimeRemoteEndpointFamily.turnServer,
                      endpointRole:
                          RuntimeRemoteEndpointRole.wireGuardRawDatagram,
                      protocol:
                          RuntimeRemoteIngressProtocol.rawWireGuardDatagram,
                      isolation: RuntimeRemoteIngressIsolation.dedicated,
                      address: '176.109.104.105:56042',
                    ),
                  ),
              platformTunnelStatusFor: (PlatformTunnelMode mode) =>
                  PlatformTunnelStatus(
                    mode: PlatformTunnelMode.androidVpnService,
                    state: PlatformTunnelLifecycleState.ready,
                    ready: true,
                    sessionId: 'session-android-1',
                    applicationRoutingPolicy:
                        PlatformTunnelApplicationRoutingPolicy.allowedPackages,
                    allowedPackages: const <String>[
                      'com.example.video',
                      'com.example.chat',
                    ],
                    underlayRoutePolicy:
                        PlatformTunnelUnderlayRoutePolicy.standard,
                    remoteIngress: const RuntimeRemoteIngressDiagnostics(
                      endpointFamily: RuntimeRemoteEndpointFamily.turnServer,
                      endpointRole:
                          RuntimeRemoteEndpointRole.wireGuardRawDatagram,
                      protocol:
                          RuntimeRemoteIngressProtocol.rawWireGuardDatagram,
                      isolation: RuntimeRemoteIngressIsolation.dedicated,
                      address: '176.109.104.105:56042',
                    ),
                    updatedAt: DateTime.utc(2026, 4, 30, 12),
                  ),
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
      expect(find.text(copy.localUdpListen), findsNothing);
      expect(find.text(copy.turnOverride), findsNothing);
      expect(find.text(copy.saveProfile), findsNothing);
      expect(find.text(copy.disconnectVpn), findsNothing);
      expect(find.text(copy.requestStartup), findsNothing);
      expect(find.textContaining('Session: session-android-1'), findsOneWidget);
      expect(
        find.textContaining(
          'Ingress: raw WireGuard at 176.109.104.105:56042 (dedicated)',
        ),
        findsWidgets,
      );
      expect(
        find.textContaining(copy.scopeOnlySelectedApps(2)),
        findsOneWidget,
      );
    },
  );
}

Future<void> _tapRoutingAction(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey<String>(key));
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
}
