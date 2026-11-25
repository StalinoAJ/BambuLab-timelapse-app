import 'dart:io';
import 'package:flutter/material.dart';
import '../services/storage_service.dart';

class FoldersScreen extends StatefulWidget {
  final StorageService storage;

  const FoldersScreen({super.key, required this.storage});

  @override
  State<FoldersScreen> createState() => _FoldersScreenState();
}

class _FoldersScreenState extends State<FoldersScreen> {
  List<Directory> _folders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFolders();
  }

  Future<void> _loadFolders() async {
    setState(() => _loading = true);
    final dirs = await widget.storage.listFolders();
    if (mounted) {
      setState(() {
        _folders = dirs;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Timestamped Folders')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _folders.isEmpty
              ? const Center(
                  child: Text('No timelapse folders yet.'),
                )
              : RefreshIndicator(
                  onRefresh: _loadFolders,
                  child: ListView.builder(
                    itemCount: _folders.length,
                    itemBuilder: (context, index) {
                      final dir = _folders[index];
                      final name = dir.path.split(Platform.pathSeparator).last;
                      return FutureBuilder<List<File>>(
                        future: widget.storage.listShotsInFolder(dir),
                        builder: (context, snapshot) {
                          final count = snapshot.data?.length ?? 0;
                          return ListTile(
                            leading: const Icon(Icons.folder),
                            title: Text(name),
                            subtitle: Text('$count shot(s) • ${dir.path}'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => _FolderDetailScreen(
                                    folderName: name,
                                    files: snapshot.data ?? const [],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
    );
  }
}

class _FolderDetailScreen extends StatelessWidget {
  final String folderName;
  final List<File> files;

  const _FolderDetailScreen({
    required this.folderName,
    required this.files,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(folderName)),
      body: files.isEmpty
          ? const Center(child: Text('No images in this folder.'))
          : GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
              ),
              itemCount: files.length,
              itemBuilder: (context, index) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.file(files[index], fit: BoxFit.cover),
                );
              },
            ),
    );
  }
}
