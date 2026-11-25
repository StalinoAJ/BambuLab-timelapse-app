import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../models/trigger_config.dart';

class StorageService {
  static final DateFormat _folderFormat = DateFormat('yyyy-MM-dd_HH-mm-ss');
  static final DateFormat _fileFormat = DateFormat('HH-mm-ss_SSS');

  Directory? _currentSessionDir;
  int _shotCount = 0;

  Directory? get currentSessionDir => _currentSessionDir;
  int get shotCount => _shotCount;

  /// Returns the root directory where all timelapse folders are stored.
  Future<Directory> getRootDirectory() async {
    Directory baseDir;
    if (Platform.isAndroid) {
      baseDir = (await getExternalStorageDirectory()) ??
          await getApplicationDocumentsDirectory();
    } else {
      baseDir = await getApplicationDocumentsDirectory();
    }

    final root = Directory('${baseDir.path}/timelapses');
    if (!await root.exists()) {
      await root.create(recursive: true);
    }
    return root;
  }

  /// Creates a new session folder named with the current timestamp.
  Future<Directory> startNewSession({DateTime? timestamp}) async {
    final root = await getRootDirectory();
    final folderName = _folderFormat.format(timestamp ?? DateTime.now());
    final sessionDir = Directory('${root.path}/$folderName');
    if (!await sessionDir.exists()) {
      await sessionDir.create(recursive: true);
    }
    _currentSessionDir = sessionDir;
    _shotCount = 0;
    return sessionDir;
  }

  /// Saves a captured image file into the timestamp-named folder.
  Future<File> saveShot({
    required String sourcePath,
    required FolderNamingMode folderMode,
    DateTime? timestamp,
  }) async {
    final now = timestamp ?? DateTime.now();
    Directory targetDir;

    if (folderMode == FolderNamingMode.perShot) {
      final root = await getRootDirectory();
      final shotFolderName = '${_folderFormat.format(now)}_${now.millisecond.toString().padLeft(3, '0')}';
      targetDir = Directory('${root.path}/$shotFolderName');
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }
      _currentSessionDir = targetDir;
    } else {
      targetDir = _currentSessionDir ?? await startNewSession(timestamp: now);
    }

    _shotCount += 1;
    final indexStr = _shotCount.toString().padLeft(4, '0');
    final timeStr = _fileFormat.format(now);
    final destPath = '${targetDir.path}/shot_${indexStr}_$timeStr.jpg';

    final sourceFile = File(sourcePath);
    final savedFile = await sourceFile.copy(destPath);
    if (await sourceFile.exists()) {
      await sourceFile.delete();
    }
    return savedFile;
  }

  /// Lists all timestamped folders sorted newest first.
  Future<List<Directory>> listFolders() async {
    final root = await getRootDirectory();
    final entities = await root.list().toList();
    final dirs = entities.whereType<Directory>().toList();
    dirs.sort((a, b) => b.path.compareTo(a.path));
    return dirs;
  }

  /// Lists all JPG files inside a given folder sorted oldest first.
  Future<List<File>> listShotsInFolder(Directory folder) async {
    if (!await folder.exists()) return [];
    final entities = await folder.list().toList();
    final files = entities
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.jpg'))
        .toList();
    files.sort((a, b) => a.path.compareTo(b.path));
    return files;
  }
}
