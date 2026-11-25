import 'package:flutter/material.dart';
import '../models/trigger_config.dart';

class SettingsScreen extends StatefulWidget {
  final TriggerConfig config;

  const SettingsScreen({super.key, required this.config});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TriggerMode _mode;
  late FolderNamingMode _folderMode;
  late bool _risingEdgeOnly;
  late TextEditingController _cooldownCtrl;
  late TextEditingController _wsUrlCtrl;
  late TextEditingController _bleNameCtrl;
  late TextEditingController _bleServiceCtrl;
  late TextEditingController _bleCharCtrl;

  @override
  void initState() {
    super.initState();
    _mode = widget.config.mode;
    _folderMode = widget.config.folderMode;
    _risingEdgeOnly = widget.config.risingEdgeOnly;
    _cooldownCtrl =
        TextEditingController(text: widget.config.cooldownMs.toString());
    _wsUrlCtrl = TextEditingController(text: widget.config.webSocketUrl);
    _bleNameCtrl = TextEditingController(text: widget.config.bleDeviceName);
    _bleServiceCtrl =
        TextEditingController(text: widget.config.bleServiceUuid);
    _bleCharCtrl =
        TextEditingController(text: widget.config.bleCharacteristicUuid);
  }

  @override
  void dispose() {
    _cooldownCtrl.dispose();
    _wsUrlCtrl.dispose();
    _bleNameCtrl.dispose();
    _bleServiceCtrl.dispose();
    _bleCharCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveAndClose() async {
    final cooldown = int.tryParse(_cooldownCtrl.text.trim()) ?? 500;
    final updated = widget.config.copyWith(
      mode: _mode,
      folderMode: _folderMode,
      risingEdgeOnly: _risingEdgeOnly,
      cooldownMs: cooldown.clamp(0, 60000),
      webSocketUrl: _wsUrlCtrl.text.trim(),
      bleDeviceName: _bleNameCtrl.text.trim(),
      bleServiceUuid: _bleServiceCtrl.text.trim(),
      bleCharacteristicUuid: _bleCharCtrl.text.trim(),
    );
    await updated.save();
    if (mounted) {
      Navigator.of(context).pop(updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ESP32 & Capture Settings'),
        actions: [
          FilledButton.icon(
            onPressed: _saveAndClose,
            icon: const Icon(Icons.check),
            label: const Text('Save'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'ESP32 Connection Mode',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          SegmentedButton<TriggerMode>(
            segments: const [
              ButtonSegment(
                value: TriggerMode.ble,
                label: Text('BLE'),
                icon: Icon(Icons.bluetooth),
              ),
              ButtonSegment(
                value: TriggerMode.webSocket,
                label: Text('Wi-Fi WS'),
                icon: Icon(Icons.wifi),
              ),
              ButtonSegment(
                value: TriggerMode.simulator,
                label: Text('Simulator'),
                icon: Icon(Icons.bug_report),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (set) => setState(() => _mode = set.first),
          ),
          const SizedBox(height: 20),
          if (_mode == TriggerMode.ble) ...[
            TextField(
              controller: _bleNameCtrl,
              decoration: const InputDecoration(
                labelText: 'BLE Device Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bleServiceCtrl,
              decoration: const InputDecoration(
                labelText: 'BLE Service UUID',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bleCharCtrl,
              decoration: const InputDecoration(
                labelText: 'BLE Notify Characteristic UUID',
                border: OutlineInputBorder(),
              ),
            ),
          ],
          if (_mode == TriggerMode.webSocket) ...[
            TextField(
              controller: _wsUrlCtrl,
              decoration: const InputDecoration(
                labelText: 'ESP32 WebSocket URL',
                hintText: 'ws://192.168.4.1:81',
                border: OutlineInputBorder(),
              ),
            ),
          ],
          const Divider(height: 32),
          const Text(
            'Trigger & Folder Behavior',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Rising-Edge Only (0 → 1)'),
            subtitle: const Text(
              'Only take one shot when value transitions from 0 to 1',
            ),
            value: _risingEdgeOnly,
            onChanged: (v) => setState(() => _risingEdgeOnly = v),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _cooldownCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Cooldown / Debounce (ms)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Timestamp Folder Mode',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          RadioListTile<FolderNamingMode>(
            contentPadding: EdgeInsets.zero,
            title: const Text('Folder per session (timestamp)'),
            subtitle: const Text(
              'All shots in one timelapse saved in timelapses/<session_timestamp>/',
            ),
            value: FolderNamingMode.perSession,
            groupValue: _folderMode,
            onChanged: (v) => setState(() => _folderMode = v!),
          ),
          RadioListTile<FolderNamingMode>(
            contentPadding: EdgeInsets.zero,
            title: const Text('Folder per shot (timestamp)'),
            subtitle: const Text(
              'Each shot saved in its own timelapses/<shot_timestamp>/ folder',
            ),
            value: FolderNamingMode.perShot,
            groupValue: _folderMode,
            onChanged: (v) => setState(() => _folderMode = v!),
          ),
        ],
      ),
    );
  }
}
