import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/trigger_config.dart';
import '../services/storage_service.dart';
import '../services/trigger_processor.dart';
import '../services/trigger_service.dart';
import 'folders_screen.dart';
import 'settings_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final StorageService _storage = StorageService();
  late TriggerProcessor _processor;
  TriggerConfig _config = const TriggerConfig();

  CameraController? _cameraController;
  bool _cameraReady = false;
  String? _cameraError;

  TriggerService? _triggerService;
  StreamSubscription<int>? _valueSub;
  StreamSubscription<TriggerConnectionState>? _stateSub;
  TriggerConnectionState _connState = TriggerConnectionState.disconnected;
  String _connMessage = 'Disconnected';

  int? _lastReceivedValue;
  bool _isCapturing = false;
  bool _flashCapture = false;
  String? _lastSavedPath;

  @override
  void initState() {
    super.initState();
    _processor = TriggerProcessor();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    _config = await TriggerConfig.load();
    _processor = TriggerProcessor(
      risingEdgeOnly: _config.risingEdgeOnly,
      cooldown: Duration(milliseconds: _config.cooldownMs),
    );

    await _requestPermissions();
    await _storage.startNewSession();
    await _initCamera();
    await _initTriggerService();
    if (mounted) setState(() {});
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.camera,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _cameraError = 'No cameras found on this device.');
        return;
      }

      final backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _cameraController = controller;
        _cameraReady = true;
        _cameraError = null;
      });
    } catch (e) {
      setState(() => _cameraError = 'Camera init failed: $e');
    }
  }

  Future<void> _initTriggerService() async {
    await _valueSub?.cancel();
    await _stateSub?.cancel();
    _triggerService?.dispose();

    switch (_config.mode) {
      case TriggerMode.ble:
        _triggerService = BleTriggerService(_config);
        break;
      case TriggerMode.webSocket:
        _triggerService = WebSocketTriggerService(_config);
        break;
      case TriggerMode.simulator:
        _triggerService = SimulatorTriggerService();
        break;
    }

    _stateSub = _triggerService!.stateStream.listen((state) {
      if (!mounted) return;
      setState(() {
        _connState = state;
        _connMessage = _triggerService!.statusMessage;
      });
    });

    _valueSub = _triggerService!.valueStream.listen(_onTriggerValueReceived);
    await _triggerService!.connect();
  }

  void _onTriggerValueReceived(int value) {
    if (!mounted) return;
    setState(() => _lastReceivedValue = value);

    final shouldCapture = _processor.process(value);
    if (shouldCapture) {
      _captureShot();
    }
  }

  Future<void> _captureShot() async {
    if (!_cameraReady || _cameraController == null || _isCapturing) return;
    if (_cameraController!.value.isTakingPicture) return;

    setState(() {
      _isCapturing = true;
      _flashCapture = true;
    });

    try {
      final xFile = await _cameraController!.takePicture();
      final savedFile = await _storage.saveShot(
        sourcePath: xFile.path,
        folderMode: _config.folderMode,
      );

      if (mounted) {
        setState(() {
          _lastSavedPath = savedFile.path;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Capture failed: $e')),
        );
      }
    } finally {
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) setState(() => _flashCapture = false);
      });
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  Future<void> _startNewTimestampFolder() async {
    await _storage.startNewSession();
    _processor.reset();
    if (mounted) {
      setState(() {});
      final name =
          _storage.currentSessionDir?.path.split(Platform.pathSeparator).last ??
              '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('New timestamp folder: $name')),
      );
    }
  }

  Future<void> _openSettings() async {
    final updated = await Navigator.of(context).push<TriggerConfig>(
      MaterialPageRoute(builder: (_) => SettingsScreen(config: _config)),
    );
    if (updated != null) {
      _config = updated;
      _processor.risingEdgeOnly = _config.risingEdgeOnly;
      _processor.cooldown = Duration(milliseconds: _config.cooldownMs);
      await _initTriggerService();
      if (mounted) setState(() {});
    }
  }

  Color _statusColor() {
    switch (_connState) {
      case TriggerConnectionState.connected:
        return Colors.green;
      case TriggerConnectionState.connecting:
        return Colors.amber;
      case TriggerConnectionState.error:
        return Colors.red;
      case TriggerConnectionState.disconnected:
        return Colors.grey;
    }
  }

  @override
  void dispose() {
    _valueSub?.cancel();
    _stateSub?.cancel();
    _triggerService?.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessionFolderName =
        _storage.currentSessionDir?.path.split(Platform.pathSeparator).last ??
            'Creating...';

    return Scaffold(
      appBar: AppBar(
        title: const Text('BambuLab Timelapse'),
        actions: [
          IconButton(
            tooltip: 'View Timestamp Folders',
            icon: const Icon(Icons.photo_library),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => FoldersScreen(storage: _storage),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: Column(
        children: [
          // Connection & Signal Status Bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: Colors.black54,
            child: Row(
              children: [
                Icon(Icons.circle, size: 12, color: _statusColor()),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _connMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _lastReceivedValue == 1
                        ? Colors.green.shade700
                        : Colors.grey.shade800,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'RX: ${_lastReceivedValue ?? '-'}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Reconnect ESP32',
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: () => _triggerService?.connect(),
                ),
              ],
            ),
          ),

          // Camera Preview
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_cameraReady && _cameraController != null)
                  CameraPreview(_cameraController!)
                else if (_cameraError != null)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _cameraError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  )
                else
                  const Center(child: CircularProgressIndicator()),
                if (_flashCapture)
                  Container(color: Colors.white.withValues(alpha: 0.45)),
              ],
            ),
          ),

          // Bottom Control Panel
          Container(
            padding: const EdgeInsets.all(14),
            color: Colors.black87,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Folder: $sessionFolderName',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Shots: ${_storage.shotCount}'
                            '${_lastSavedPath != null ? ' • Saved!' : ''}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _startNewTimestampFolder,
                      icon: const Icon(Icons.create_new_folder, size: 18),
                      label: const Text('New Folder'),
                    ),
                  ],
                ),
                if (_triggerService is SimulatorTriggerService) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () =>
                              (_triggerService as SimulatorTriggerService)
                                  .sendSimulatedValue(0),
                          child: const Text('Send 0'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () =>
                              (_triggerService as SimulatorTriggerService)
                                  .sendSimulatedValue(1),
                          child: const Text('Send 1 (Take Shot)'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
