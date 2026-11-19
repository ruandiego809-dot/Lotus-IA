import 'dart:io';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class TerminalEnvironmentService {
  TerminalEnvironmentService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  // Alpine Linux minirootfs (aarch64/x86_64) - real upstream artifact.
  // Version pinned for reproducibility; update as needed.
  static const _alpineVersion = '3.20.3';
  Future<Directory> baseDir() async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory(p.join(support.path, 'terminal'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<Directory> rootfsDir(String sessionId) async {
    final dir = Directory(p.join((await baseDir()).path, 'rootfs', sessionId));
    return dir;
  }

  Future<Directory> binDir() async {
    final dir = Directory(p.join((await baseDir()).path, 'bin'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  String _hostArch() {
    // Dart reports ABI-like arch in some contexts; normalize.
    final v = Platform.version.toLowerCase();
    if (v.contains('aarch64') || v.contains('arm64')) return 'aarch64';
    if (v.contains('x64') || v.contains('x86_64')) return 'x86_64';
    // Fallback: assume common Android device arch.
    return 'aarch64';
  }

  String alpineMinirootfsUrl({String? arch}) {
    final a = arch ?? _hostArch();
    return 'https://dl-cdn.alpinelinux.org/alpine/v${_alpineVersion.split('.').take(2).join('.')}/releases/$a/alpine-minirootfs-$_alpineVersion-$a.tar.gz';
  }

  Future<bool> isRootfsReady(String sessionId) async {
    final dir = await rootfsDir(sessionId);
    final marker = File(p.join(dir.path, '.lotus-rootfs-ready'));
    final busybox = File(p.join(dir.path, 'bin', 'busybox'));
    final sh = File(p.join(dir.path, 'bin', 'sh'));
    return await marker.exists() && await busybox.exists() && await sh.exists();
  }

  /// Downloads and extracts Alpine minirootfs for [sessionId]. Real network + filesystem ops.
  /// Progress callback receives (received, total) bytes when known.
  Future<String> bootstrapAlpine(
    String sessionId, {
    void Function(int received, int? total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final dir = await rootfsDir(sessionId);
    if (await isRootfsReady(sessionId)) return dir.path;
    // An older or interrupted rootfs may contain user data; never erase it.
    if (await dir.exists()) {
      throw StateError(
        'O ambiente existente não está validado. Crie outra sessão para preservar seus arquivos.',
      );
    }
    await dir.create(recursive: true);

    final url = alpineMinirootfsUrl();
    final tmp = File(
      p.join((await baseDir()).path, 'alpine-$sessionId.tar.gz'),
    );
    try {
      await _dio.download(
        url,
        tmp.path,
        cancelToken: cancelToken,
        onReceiveProgress: (r, t) => onProgress?.call(r, t > 0 ? t : null),
        options: Options(
          receiveTimeout: const Duration(minutes: 5),
          sendTimeout: const Duration(minutes: 1),
          headers: const {'User-Agent': 'LotusAI/1.0'},
        ),
      );
      final bytes = await tmp.readAsBytes();
      final gz = const GZipDecoder().decodeBytes(bytes);
      final archive = TarDecoder().decodeBytes(gz);
      final links = <({String path, String target})>[];
      for (final file in archive) {
        if (cancelToken?.isCancelled == true) {
          throw StateError('Instalação cancelada.');
        }
        final outPath = p.normalize(p.join(dir.path, file.name));
        if (!p.isWithin(dir.path, outPath) && outPath != dir.path) {
          continue; // path traversal protection
        }
        if (file.isSymbolicLink) {
          final target = file.symbolicLink!;
          // Resolve absolute archive links inside the rootfs, never on the host.
          final resolved = p.normalize(
            p.isAbsolute(target)
                ? p.join(dir.path, target.substring(1))
                : p.join(p.dirname(outPath), target),
          );
          if (!p.isWithin(dir.path, resolved) && resolved != dir.path) {
            throw const FormatException('Link do Alpine fora do rootfs.');
          }
          links.add((
            path: outPath,
            target: p.relative(resolved, from: p.dirname(outPath)),
          ));
          continue;
        }
        if (file.isFile) {
          final outFile = File(outPath);
          await outFile.parent.create(recursive: true);
          await outFile.writeAsBytes(file.content as List<int>, flush: true);
          final mode = file.mode;
          if (mode & 0x49 != 0) {
            // best-effort executable bit on unix-like fs
            try {
              await Process.run('chmod', ['+x', outPath]);
            } catch (_) {}
          }
        } else {
          await Directory(outPath).create(recursive: true);
        }
      }
      // Ensure basic dirs exist
      for (final d in ['tmp', 'root', 'home', 'proc', 'sys', 'dev', 'etc']) {
        await Directory(p.join(dir.path, d)).create(recursive: true);
      }
      final resolv = File(p.join(dir.path, 'etc', 'resolv.conf'));
      if (!await resolv.exists()) {
        await resolv.writeAsString('nameserver 8.8.8.8\nnameserver 1.1.1.1\n');
      }
      // Create links last so archive entries can never write through them.
      for (final link in links) {
        if (cancelToken?.isCancelled == true) {
          throw StateError('Instalação cancelada.');
        }
        var parent = p.dirname(link.path);
        while (parent != dir.path) {
          if (await FileSystemEntity.type(parent, followLinks: false) !=
              FileSystemEntityType.directory) {
            throw const FormatException('Pasta de link do Alpine inválida.');
          }
          parent = p.dirname(parent);
        }
        if (await FileSystemEntity.type(link.path, followLinks: false) !=
            FileSystemEntityType.notFound) {
          throw const FormatException(
            'Link do Alpine conflita com arquivo existente.',
          );
        }
        await Link(link.path).create(link.target);
      }
      if (!await File(p.join(dir.path, 'bin', 'busybox')).exists() ||
          !await File(p.join(dir.path, 'bin', 'sh')).exists()) {
        throw const FormatException('Rootfs Alpine incompleto: shell ausente.');
      }
      if (cancelToken?.isCancelled == true) {
        throw StateError('Instalação cancelada.');
      }
      await File(p.join(dir.path, '.lotus-rootfs-ready')).writeAsString('1');
      return dir.path;
    } catch (_) {
      // A partially extracted tree must never be mistaken for a ready rootfs.
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
      rethrow;
    } finally {
      if (await tmp.exists()) {
        try {
          await tmp.delete();
        } catch (_) {}
      }
    }
  }

  Future<String?> findProotBinary() async {
    // 1) bundled/downloaded in app bin dir
    final dir = await binDir();
    for (final name in ['proot', 'proot-aarch64', 'proot-x86_64']) {
      final f = File(p.join(dir.path, name));
      if (await f.exists()) return f.path;
    }
    // 2) system paths (e.g. Termux-like environments) - only if present
    for (final pth in [
      '/usr/bin/proot',
      '/system/bin/proot',
      '/data/data/com.termux/files/usr/bin/proot',
    ]) {
      if (await File(pth).exists()) return pth;
    }
    return null;
  }

  Future<({String executable, List<String> args, Map<String, String> env})>
  buildShellCommand({
    required String rootfsPath,
    String shell = '/bin/sh',
    bool login = true,
  }) async {
    final proot = await findProotBinary();
    final env = <String, String>{
      'PATH': '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin',
      'HOME': '/root',
      'USER': 'root',
      'TERM': 'xterm-256color',
      'LANG': 'C.UTF-8',
      'TMPDIR': '/tmp',
    };
    if (proot != null) {
      final args = <String>[
        '-r',
        rootfsPath,
        '-0',
        '-w',
        '/root',
        '-b',
        '/dev',
        '-b',
        '/proc',
        '-b',
        '/sys',
        '--kill-on-exit',
        shell,
      ];
      if (login) args.add('-l');
      return (executable: proot, args: args, env: env);
    }
    // Running an Alpine executable directly does not enter its root filesystem.
    // Do not silently start a host shell or misrepresent it as Alpine.
    throw StateError(
      'PRoot compatível não encontrado. A sessão Alpine precisa de PRoot acessível ao app.',
    );
  }

  Future<void> deleteSessionEnv(String sessionId) async {
    final dir = await rootfsDir(sessionId);
    if (await dir.exists()) await dir.delete(recursive: true);
  }
}
