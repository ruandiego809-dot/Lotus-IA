import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import 'safe_zip_import.dart';

class ProjectEntry {
  const ProjectEntry({
    required this.entity,
    required this.name,
    required this.isDirectory,
    required this.size,
    required this.modified,
  });

  final FileSystemEntity entity;
  final String name;
  final bool isDirectory;
  final int size;
  final DateTime? modified;
}

/// Filesystem access for the local project workspace, isolated from the UI.
class ProjectRepository {
  Directory? _root;

  Future<Directory> root() async {
    final cached = _root;
    if (cached != null) return cached;
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/lotus_projects');
    if (!await dir.exists()) await dir.create(recursive: true);
    _root = dir;
    return dir;
  }

  /// Never exposes a raw path segment chosen by the user.
  static String safeName(String input) {
    final name = input.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    return name == '.' || name == '..' ? '' : name;
  }

  Future<List<ProjectEntry>> list(Directory dir) async {
    final entities = <FileSystemEntity>[];
    await for (final entity in dir.list(followLinks: false)) {
      entities.add(entity);
    }
    entities.sort((a, b) {
      final aDir = a is Directory;
      final bDir = b is Directory;
      if (aDir != bDir) return aDir ? -1 : 1;
      return _nameOf(a.path)
          .toLowerCase()
          .compareTo(_nameOf(b.path).toLowerCase());
    });
    final entries = <ProjectEntry>[];
    for (final entity in entities) {
      var size = 0;
      DateTime? modified;
      try {
        final stat = await entity.stat();
        size = stat.size;
        modified = stat.modified;
      } catch (_) {}
      entries.add(
        ProjectEntry(
          entity: entity,
          name: _nameOf(entity.path),
          isDirectory: entity is Directory,
          size: size,
          modified: modified,
        ),
      );
    }
    return entries;
  }

  static String _nameOf(String path) => path.split(Platform.pathSeparator).last;

  Future<Directory> createProject(Directory root, String rawName) async {
    final name = safeName(rawName);
    if (name.isEmpty) throw const FormatException('Nome inválido.');
    final dir = Directory('${root.path}/$name');
    if (!await dir.exists()) await dir.create(recursive: true);
    final readme = File('${dir.path}/README.md');
    if (!await readme.exists()) await readme.writeAsString('# $name\n');
    return dir;
  }

  Future<void> createFolder(Directory parent, String rawName) async {
    final name = safeName(rawName);
    if (name.isEmpty) throw const FormatException('Nome inválido.');
    final dir = Directory('${parent.path}/$name');
    if (!await dir.exists()) await dir.create(recursive: true);
  }

  Future<void> createFile(Directory parent, String rawName) async {
    final name = safeName(rawName);
    if (name.isEmpty) throw const FormatException('Nome inválido.');
    final file = File('${parent.path}/$name');
    if (!await file.exists()) await file.writeAsString('');
  }

  Future<void> rename(FileSystemEntity entity, String rawName) async {
    final name = safeName(rawName);
    if (name.isEmpty || name == _nameOf(entity.path)) return;
    final destination = '${entity.parent.path}${Platform.pathSeparator}$name';
    if (await FileSystemEntity.type(destination, followLinks: false) !=
        FileSystemEntityType.notFound) {
      throw const FileSystemException('Já existe um item com esse nome.');
    }
    await entity.rename(destination);
  }

  Future<void> delete(FileSystemEntity entity) async {
    if (entity is Directory) {
      await entity.delete(recursive: true);
    } else {
      await entity.delete();
    }
  }

  Future<String> exportZip(Directory dir) async {
    final base = await getApplicationDocumentsDirectory();
    final exports = Directory('${base.path}/lotus_exports');
    if (!await exports.exists()) await exports.create(recursive: true);
    final name = _nameOf(dir.path);
    final out =
        '${exports.path}/$name-${DateTime.now().millisecondsSinceEpoch}.zip';
    final encoder = ZipFileEncoder()..create(out);
    try {
      await encoder.addDirectory(dir, includeDirName: true);
      await encoder.close();
    } catch (_) {
      await encoder.close();
      rethrow;
    }
    return out;
  }

  Future<void> importZip(Directory target, String zipPath) async {
    final bytes = await File(zipPath).readAsBytes();
    await importProjectZip(target, bytes);
  }

  /// Downloads a public GitHub repository ZIP. Tries `main` then `master`.
  Future<String?> importGithub({
    required Directory target,
    required String owner,
    required String repo,
  }) async {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(minutes: 2),
      ),
    );
    final tmp = await getTemporaryDirectory();
    String? lastError;
    for (final branch in const ['main', 'master']) {
      final out = '${tmp.path}/lotus_${repo}_$branch.zip';
      try {
        await dio.download(
          'https://codeload.github.com/$owner/$repo/zip/refs/heads/$branch',
          out,
        );
        await importZip(target, out);
        return '$owner/$repo@$branch';
      } catch (error) {
        lastError = error.toString();
      } finally {
        try {
          await File(out).delete();
        } catch (_) {}
      }
    }
    throw Exception(lastError ?? 'Falha ao baixar o repositório.');
  }
}
