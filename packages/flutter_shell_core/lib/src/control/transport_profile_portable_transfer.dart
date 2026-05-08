import 'package:flutter_shell_core/control_plane_models.dart';

const String kPortableTransportProfileEnvelopeType =
    'portable_transport_profile';
const int kPortableTransportProfileEnvelopeVersion = 1;

class PortableTransportProfileEnvelopeCarriage {
  const PortableTransportProfileEnvelopeCarriage({
    required this.envelope,
    required this.profileKind,
    this.displayName = '',
    this.encodedBytes = 0,
  });

  factory PortableTransportProfileEnvelopeCarriage.fromExportResult(
    TransportProfilePortableExportResult result,
  ) {
    return PortableTransportProfileEnvelopeCarriage(
      envelope: result.envelope,
      profileKind: result.profileKind,
      displayName: result.displayName,
      encodedBytes: result.encodedBytes,
    );
  }

  final String envelope;
  final TransportProfileKind profileKind;
  final String displayName;
  final int encodedBytes;

  bool fitsQrBounds(TransportProfilePortableTransferCapability capability) {
    final qrMaxPayloadBytes = capability.qrMaxPayloadBytes;
    return capability.exportPaths.contains(
          TransportProfilePortableTransferPath.qrPayload,
        ) &&
        capability.qrMode ==
            TransportProfilePortableTransferQrMode.singlePayload &&
        qrMaxPayloadBytes > 0 &&
        encodedBytes <= qrMaxPayloadBytes;
  }

  void requireSupportedQrBounds(
    TransportProfilePortableTransferCapability capability,
  ) {
    if (fitsQrBounds(capability)) {
      return;
    }
    final qrMaxPayloadBytes = capability.qrMaxPayloadBytes;
    throw FormatException(
      'portable transport-profile envelope exceeds supported QR bounds '
      '($encodedBytes > $qrMaxPayloadBytes bytes)',
    );
  }

  TransportProfilePortableImportRequest importRequest({
    required String passphrase,
  }) {
    return TransportProfilePortableImportRequest(
      envelope: envelope,
      passphrase: passphrase,
    );
  }
}
