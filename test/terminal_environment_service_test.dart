import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotus_ai/features/terminal/data/terminal_environment_service.dart';
import 'package:path/path.dart' as p;

class LocalEnvironment extends TerminalEnvironmentService {
  LocalEnvironment(this.root);
  final Directory root;

  @override
  Future<Directory> rootfsDir(String sessionId) async => root;
}

void main() {
  late Directory temp;
  late Directory root;
  late LocalEnvironment env;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('lotus-terminal-test-');
    root = Directory(p.join(temp.path, 'rootfs'));
    env = LocalEnvironment(root);
  });
  tearDown(() async => temp.delete(recursive: true));

  test('partial or legacy rootfs is not erased', () async {
    await Directory(p.join(root.path, 'bin')).create(recursive: true);
    final data = File(p.join(root.path, 'my-data'));
    await data.writeAsString('important');
    await File(p.join(root.path, 'bin', 'busybox')).writeAsString('binary');
    expect(await env.isRootfsReady('session'), isFalse);
    await expectLater(env.bootstrapAlpine('session'), throwsStateError);
    expect(await data.readAsString(), 'important');
  });

  test('requires marker and functional shell path', () async {
    await Directory(p.join(root.path, 'bin')).create(recursive: true);
    await File(p.join(root.path, 'bin', 'busybox')).writeAsString('binary');
    await File(p.join(root.path, '.lotus-rootfs-ready')).writeAsString('1');
    expect(await env.isRootfsReady('session'), isFalse);
    await File(p.join(root.path, 'bin', 'sh')).writeAsString('shell');
    expect(await env.isRootfsReady('session'), isTrue);
  });
}
