import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/trigger_config.dart';
import 'trigger_processor.dart';

enum TriggerConnectionState {
  disconnected,
  connecting,
  connected,
  error,
}

abstract class TriggerService {
  Stream<int> get valueStream;
  Stream<TriggerConnectionState> get stateStream;
  String get statusMessage;

  Future<void> connect();
  Future<void> disconnect();
  void dispose();
}

/// BLE GATT client that connects to the ESP32 and listens for 0/1 notifications.
class BleTriggerService implements TriggerService {
  final TriggerConfig config;
  final _valueController = StreamController<int>.broadcast();
  final _stateController = StreamController<TriggerConnectionState>.broadcast();

  BluetoothDevice? _device;
  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<BluetoothConnectionState>? _connSub;
  StreamSubscription<List<int>>? _notifySub;
  String _statusMessage = 'Disconnected';

  BleTriggerService(this.config);

  @override
  Stream<int> get valueStream => _valueController.stream;

  @override
  Stream<TriggerConnectionState> get stateStream => _stateController.stream;

  @override
  String get statusMessage => _statusMessage;

  void _setState(TriggerConnectionState state, String message) {
    _statusMessage = message;
    if (!_stateController.isClosed) {
      _stateController.add(state);
    }
  }

  @override
  Future<void> connect() async {
    await disconnect();
    _setState(TriggerConnectionState.connecting,
        'Scanning for ${config.bleDeviceName}...');

    try {
      final completer = Completer<BluetoothDevice?>();

      _scanSub = FlutterBluePlus.scanResults.listen((results) {
        for (final r in results) {
          final name = r.device.platformName;
          final advName = r.advertisementData.advName;
          if (name == config.bleDeviceName || advName == config.bleDeviceName) {
            if (!completer.isCompleted) {
              completer.complete(r.device);
            }
            break;
          }
        }
      });

      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 12),
        withServices: [Guid(config.bleServiceUuid)],
      );

      final device = await completer.future.timeout(
        const Duration(seconds: 13),
        onTimeout: () => null,
      );

      await FlutterBluePlus.stopScan();
      await _scanSub?.cancel();
      _scanSub = null;

      if (device == null) {
        _setState(TriggerConnectionState.error,
            'ESP32 "${config.bleDeviceName}" not found');
        return;
      }

      _device = device;
      _setState(TriggerConnectionState.connecting, 'Connecting to ${device.platformName}...');

      await device.connect(timeout: const Duration(seconds: 10));

      _connSub = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _setState(TriggerConnectionState.disconnected, 'BLE disconnected');
        }
      });

      final services = await device.discoverServices();
      BluetoothCharacteristic? targetChar;

      for (final s in services) {
        if (s.uuid.toString().toLowerCase() ==
            config.bleServiceUuid.toLowerCase()) {
          for (final c in s.characteristics) {
            if (c.uuid.toString().toLowerCase() ==
                config.bleCharacteristicUuid.toLowerCase()) {
              targetChar = c;
              break;
            }
          }
        }
      }

      if (targetChar == null) {
        _setState(TriggerConnectionState.error,
            'Trigger characteristic not found on ESP32');
        return;
      }

      await targetChar.setNotifyValue(true);
      _notifySub = targetChar.lastValueStream.listen(_handleBytes);

      _setState(TriggerConnectionState.connected,
          'Connected to ${device.platformName}');
    } catch (e) {
      _setState(TriggerConnectionState.error, 'BLE error: $e');
    }
  }

  void _handleBytes(List<int> bytes) {
    if (bytes.isEmpty || _valueController.isClosed) return;
    // Support raw single byte (0x00 / 0x01) or ASCII ("0" / "1")
    if (bytes.length == 1 && (bytes[0] == 0 || bytes[0] == 1)) {
      _valueController.add(bytes[0]);
      return;
    }
    final text = utf8.decode(bytes, allowMalformed: true);
    final parsed = TriggerProcessor.parseValue(text);
    if (parsed != null) {
      _valueController.add(parsed);
    }
  }

  @override
  Future<void> disconnect() async {
    await _scanSub?.cancel();
    _scanSub = null;
    await _notifySub?.cancel();
    _notifySub = null;
    await _connSub?.cancel();
    _connSub = null;
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
    try {
      await _device?.disconnect();
    } catch (_) {}
    _device = null;
    _setState(TriggerConnectionState.disconnected, 'Disconnected');
  }

  @override
  void dispose() {
    disconnect();
    _valueController.close();
    _stateController.close();
  }
}

/// Wi-Fi WebSocket client that connects to the ESP32 WebSocket server.
class WebSocketTriggerService implements TriggerService {
  final TriggerConfig config;
  final _valueController = StreamController<int>.broadcast();
  final _stateController = StreamController<TriggerConnectionState>.broadcast();

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  String _statusMessage = 'Disconnected';

  WebSocketTriggerService(this.config);

  @override
  Stream<int> get valueStream => _valueController.stream;

  @override
  Stream<TriggerConnectionState> get stateStream => _stateController.stream;

  @override
  String get statusMessage => _statusMessage;

  void _setState(TriggerConnectionState state, String message) {
    _statusMessage = message;
    if (!_stateController.isClosed) {
      _stateController.add(state);
    }
  }

  @override
  Future<void> connect() async {
    await disconnect();
    _setState(
        TriggerConnectionState.connecting, 'Connecting to ${config.webSocketUrl}...');

    try {
      final uri = Uri.parse(config.webSocketUrl);
      _channel = WebSocketChannel.connect(uri);
      await _channel!.ready;

      _setState(
          TriggerConnectionState.connected, 'Connected to ${config.webSocketUrl}');

      _sub = _channel!.stream.listen(
        (data) {
          final parsed = TriggerProcessor.parseValue(data.toString());
          if (parsed != null && !_valueController.isClosed) {
            _valueController.add(parsed);
          }
        },
        onError: (err) {
          _setState(TriggerConnectionState.error, 'WebSocket error: $err');
        },
        onDone: () {
          _setState(
              TriggerConnectionState.disconnected, 'WebSocket disconnected');
        },
      );
    } catch (e) {
      _setState(TriggerConnectionState.error, 'Failed to connect: $e');
    }
  }

  @override
  Future<void> disconnect() async {
    await _sub?.cancel();
    _sub = null;
    await _channel?.sink.close();
    _channel = null;
    _setState(TriggerConnectionState.disconnected, 'Disconnected');
  }

  @override
  void dispose() {
    disconnect();
    _valueController.close();
    _stateController.close();
  }
}

/// Local simulator so the user can test sending 0 and 1 without an ESP32.
class SimulatorTriggerService implements TriggerService {
  final _valueController = StreamController<int>.broadcast();
  final _stateController = StreamController<TriggerConnectionState>.broadcast();
  String _statusMessage = 'Simulator ready';

  @override
  Stream<int> get valueStream => _valueController.stream;

  @override
  Stream<TriggerConnectionState> get stateStream => _stateController.stream;

  @override
  String get statusMessage => _statusMessage;

  @override
  Future<void> connect() async {
    _statusMessage = 'Simulator active';
    if (!_stateController.isClosed) {
      _stateController.add(TriggerConnectionState.connected);
    }
  }

  void sendSimulatedValue(int value) {
    if (!_valueController.isClosed) {
      _valueController.add(value);
    }
  }

  @override
  Future<void> disconnect() async {
    _statusMessage = 'Simulator paused';
    if (!_stateController.isClosed) {
      _stateController.add(TriggerConnectionState.disconnected);
    }
  }

  @override
  void dispose() {
    _valueController.close();
    _stateController.close();
  }
}
