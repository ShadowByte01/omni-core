import 'package:equatable/equatable.dart';

/// Transport channel used to discover / connect a peer in OmniBeam.
enum BeamTransport { webrtc, bluetooth, wifiDirect }

extension BeamTransportX on BeamTransport {
  String get label {
    switch (this) {
      case BeamTransport.webrtc:
        return 'WebRTC';
      case BeamTransport.bluetooth:
        return 'Bluetooth';
      case BeamTransport.wifiDirect:
        return 'Wi-Fi Direct';
    }
  }
}

/// Connection lifecycle for a nearby device.
enum BeamDeviceState { discovered, connecting, connected, beaming, done, failed }

/// A nearby device discovered by the OmniBeam radar.
class NearbyDevice extends Equatable {
  const NearbyDevice({
    required this.id,
    required this.name,
    required this.transport,
    required this.state,
    required this.signalStrength,
    this.rssi = -60,
  });

  final String id;
  final String name;
  final BeamTransport transport;
  final BeamDeviceState state;
  /// 0.0 - 1.0 normalised proximity (derived from RSSI).
  final double signalStrength;
  final int rssi;

  NearbyDevice copyWith({
    BeamDeviceState? state,
    double? signalStrength,
    int? rssi,
  }) {
    return NearbyDevice(
      id: id,
      name: name,
      transport: transport,
      state: state ?? this.state,
      signalStrength: signalStrength ?? this.signalStrength,
      rssi: rssi ?? this.rssi,
    );
  }

  @override
  List<Object?> get props => [id, name, transport, state, signalStrength];
}

/// A live OmniBeam transfer (queued or in-flight).
class BeamTransfer extends Equatable {
  const BeamTransfer({
    required this.id,
    required this.deviceId,
    required this.deviceName,
    required this.fileName,
    required this.sizeBytes,
    required this.startedAt,
    required this.transport,
    this.sentBytes = 0,
    this.status = BeamTransferStatus.queued,
  });

  final String id;
  final String deviceId;
  final String deviceName;
  final String fileName;
  final int sizeBytes;
  final DateTime startedAt;
  final BeamTransport transport;
  final int sentBytes;
  final BeamTransferStatus status;

  double get progress => sizeBytes == 0 ? 0 : (sentBytes / sizeBytes).clamp(0.0, 1.0);

  BeamTransfer copyWith({
    int? sentBytes,
    BeamTransferStatus? status,
  }) {
    return BeamTransfer(
      id: id,
      deviceId: deviceId,
      deviceName: deviceName,
      fileName: fileName,
      sizeBytes: sizeBytes,
      startedAt: startedAt,
      transport: transport,
      sentBytes: sentBytes ?? this.sentBytes,
      status: status ?? this.status,
    );
  }

  @override
  List<Object?> get props =>
      [id, deviceId, fileName, sentBytes, status, transport];
}

enum BeamTransferStatus { queued, beaming, done, failed, cancelled }
