import 'package:shared_preferences/shared_preferences.dart';

enum TriggerMode {
  ble,
  webSocket,
  simulator,
}

enum FolderNamingMode {
  perSession,
  perShot,
}

class TriggerConfig {
  final TriggerMode mode;
  final FolderNamingMode folderMode;
  final bool risingEdgeOnly;
  final int cooldownMs;
  final String webSocketUrl;
  final String bleDeviceName;
  final String bleServiceUuid;
  final String bleCharacteristicUuid;

  const TriggerConfig({
    this.mode = TriggerMode.ble,
    this.folderMode = FolderNamingMode.perSession,
    this.risingEdgeOnly = true,
    this.cooldownMs = 500,
    this.webSocketUrl = 'ws://192.168.4.1:81',
    this.bleDeviceName = 'BambuTimelapse-ESP32',
    this.bleServiceUuid = '4fafc201-1fb5-459e-8fcc-c5c9c331914b',
    this.bleCharacteristicUuid = 'beb5483e-36e1-4688-b7f5-ea07361b26a8',
  });

  TriggerConfig copyWith({
    TriggerMode? mode,
    FolderNamingMode? folderMode,
    bool? risingEdgeOnly,
    int? cooldownMs,
    String? webSocketUrl,
    String? bleDeviceName,
    String? bleServiceUuid,
    String? bleCharacteristicUuid,
  }) {
    return TriggerConfig(
      mode: mode ?? this.mode,
      folderMode: folderMode ?? this.folderMode,
      risingEdgeOnly: risingEdgeOnly ?? this.risingEdgeOnly,
      cooldownMs: cooldownMs ?? this.cooldownMs,
      webSocketUrl: webSocketUrl ?? this.webSocketUrl,
      bleDeviceName: bleDeviceName ?? this.bleDeviceName,
      bleServiceUuid: bleServiceUuid ?? this.bleServiceUuid,
      bleCharacteristicUuid:
          bleCharacteristicUuid ?? this.bleCharacteristicUuid,
    );
  }

  static Future<TriggerConfig> load() async {
    final prefs = await SharedPreferences.getInstance();
    final modeIdx = prefs.getInt('trigger_mode') ?? 0;
    final folderIdx = prefs.getInt('folder_mode') ?? 0;

    return TriggerConfig(
      mode: TriggerMode.values[modeIdx.clamp(0, TriggerMode.values.length - 1)],
      folderMode: FolderNamingMode
          .values[folderIdx.clamp(0, FolderNamingMode.values.length - 1)],
      risingEdgeOnly: prefs.getBool('rising_edge_only') ?? true,
      cooldownMs: prefs.getInt('cooldown_ms') ?? 500,
      webSocketUrl: prefs.getString('ws_url') ?? 'ws://192.168.4.1:81',
      bleDeviceName:
          prefs.getString('ble_device_name') ?? 'BambuTimelapse-ESP32',
      bleServiceUuid: prefs.getString('ble_service_uuid') ??
          '4fafc201-1fb5-459e-8fcc-c5c9c331914b',
      bleCharacteristicUuid: prefs.getString('ble_char_uuid') ??
          'beb5483e-36e1-4688-b7f5-ea07361b26a8',
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('trigger_mode', mode.index);
    await prefs.setInt('folder_mode', folderMode.index);
    await prefs.setBool('rising_edge_only', risingEdgeOnly);
    await prefs.setInt('cooldown_ms', cooldownMs);
    await prefs.setString('ws_url', webSocketUrl);
    await prefs.setString('ble_device_name', bleDeviceName);
    await prefs.setString('ble_service_uuid', bleServiceUuid);
    await prefs.setString('ble_char_uuid', bleCharacteristicUuid);
  }
}
