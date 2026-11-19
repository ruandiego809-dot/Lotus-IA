import 'package:uuid/uuid.dart';

enum TerminalDistro { alpine }

enum TerminalSessionStatus { stopped, bootstrapping, starting, running, error }

enum TerminalCommandSource { user, ai }

class TerminalSession {
  TerminalSession({
    String? id,
    required this.name,
    this.distro = TerminalDistro.alpine,
    this.status = TerminalSessionStatus.stopped,
    this.rootfsPath,
    this.lastError,
    DateTime? createdAt,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now();

  final String id;
  final String name;
  final TerminalDistro distro;
  final TerminalSessionStatus status;
  final String? rootfsPath;
  final String? lastError;
  final DateTime createdAt;

  TerminalSession copyWith({
    String? name,
    TerminalDistro? distro,
    TerminalSessionStatus? status,
    Object? rootfsPath = _s,
    Object? lastError = _s,
  }) => TerminalSession(
    id: id,
    name: name ?? this.name,
    distro: distro ?? this.distro,
    status: status ?? this.status,
    rootfsPath: identical(rootfsPath, _s)
        ? this.rootfsPath
        : rootfsPath as String?,
    lastError: identical(lastError, _s) ? this.lastError : lastError as String?,
    createdAt: createdAt,
  );

  static const _s = Object();

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'distro': distro.name,
    'status': status.name,
    'rootfsPath': rootfsPath,
    'lastError': lastError,
    'createdAt': createdAt.toIso8601String(),
  };

  factory TerminalSession.fromJson(Map<String, dynamic> j) => TerminalSession(
    id: j['id'] as String?,
    name: j['name'] as String? ?? 'Sessão',
    distro: TerminalDistro.values.byName(j['distro'] as String? ?? 'alpine'),
    status: TerminalSessionStatus.values.byName(
      j['status'] as String? ?? 'stopped',
    ),
    rootfsPath: j['rootfsPath'] as String?,
    lastError: j['lastError'] as String?,
    createdAt: DateTime.tryParse(j['createdAt'] as String? ?? ''),
  );
}

class PendingAiCommand {
  const PendingAiCommand({
    required this.sessionId,
    required this.command,
    required this.reason,
  });
  final String sessionId;
  final String command;
  final String reason;
}
