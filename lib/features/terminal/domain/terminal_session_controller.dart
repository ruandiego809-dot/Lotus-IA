import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:flutter_pty/flutter_pty.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/terminal_environment_service.dart';
import '../data/terminal_repository.dart';
import 'terminal_models.dart';

class TerminalRuntime {
  TerminalRuntime({required this.session, this.pty});
  final TerminalSession session;
  final Pty? pty;
  final StreamController<List<int>> output =
      StreamController<List<int>>.broadcast();

  void dispose() {
    try {
      pty?.kill();
    } catch (_) {}
    output.close();
  }
}

class TerminalState {
  const TerminalState({
    this.sessions = const [],
    this.activeId,
    this.bootstrapping = const {},
    this.bootstrapProgress = const {},
    this.runtimes = const {},
  });
  final List<TerminalSession> sessions;
  final String? activeId;
  final Set<String> bootstrapping;
  final Map<String, double> bootstrapProgress; // 0..1
  final Map<String, TerminalRuntime> runtimes;

  TerminalSession? get active =>
      sessions.where((s) => s.id == activeId).firstOrNull;
}

final terminalEnvironmentProvider = Provider<TerminalEnvironmentService>(
  (ref) => TerminalEnvironmentService(),
);

final terminalControllerProvider =
    StateNotifierProvider<TerminalController, TerminalState>((ref) {
      return TerminalController(ref);
    });

class TerminalController extends StateNotifier<TerminalState> {
  TerminalController(this.ref) : super(const TerminalState()) {
    _initialLoad = _load();
  }
  final Ref ref;
  late final Future<void> _initialLoad;
  final _cancelTokens = <String, CancelToken>{};

  TerminalRepository get _repo => ref.read(terminalRepositoryProvider);
  TerminalEnvironmentService get _env => ref.read(terminalEnvironmentProvider);

  Future<void> _load() async {
    final items = await _repo.load();
    if (!mounted) return;
    // Mark previously running sessions as stopped (processes don't survive app restart here).
    final normalized = [
      for (final s in items)
        s.status == TerminalSessionStatus.running ||
                s.status == TerminalSessionStatus.starting
            ? s.copyWith(status: TerminalSessionStatus.stopped)
            : s,
    ];
    state = TerminalState(
      sessions: normalized,
      activeId: normalized.isNotEmpty ? normalized.first.id : null,
    );
  }

  Future<void> _saveTail = Future<void>.value();

  Future<void> _persist() {
    final snapshot = List<TerminalSession>.of(state.sessions);
    final next = _saveTail.then((_) => _repo.save(snapshot));
    // Keep the queue usable even if this write fails; propagate to its caller.
    _saveTail = next.catchError((Object _) {});
    return next;
  }

  void select(String id) {
    state = TerminalState(
      sessions: state.sessions,
      activeId: id,
      bootstrapping: state.bootstrapping,
      bootstrapProgress: state.bootstrapProgress,
      runtimes: state.runtimes,
    );
  }

  Future<TerminalSession> createSession({String? name}) async {
    await _initialLoad;
    if (!mounted) throw StateError('O terminal já foi encerrado.');
    final n = name?.trim().isNotEmpty == true
        ? name!.trim()
        : 'Alpine ${state.sessions.length + 1}';
    final s = TerminalSession(name: n, distro: TerminalDistro.alpine);
    final sessions = [s, ...state.sessions];
    state = TerminalState(
      sessions: sessions,
      activeId: s.id,
      bootstrapping: state.bootstrapping,
      bootstrapProgress: state.bootstrapProgress,
      runtimes: state.runtimes,
    );
    await _persist();
    return s;
  }

  void _updateSession(TerminalSession s) {
    final sessions = [
      for (final x in state.sessions)
        if (x.id == s.id) s else x,
    ];
    state = TerminalState(
      sessions: sessions,
      activeId: state.activeId,
      bootstrapping: state.bootstrapping,
      bootstrapProgress: state.bootstrapProgress,
      runtimes: state.runtimes,
    );
  }

  final _bootstrapJobs = <String, Future<void>>{};
  final _deleting = <String>{};

  Future<void> bootstrap(String sessionId) async {
    if (_deleting.contains(sessionId)) return;
    final existing = _bootstrapJobs[sessionId];
    if (existing != null) return existing;
    final job = _bootstrap(sessionId);
    _bootstrapJobs[sessionId] = job;
    try {
      await job;
    } finally {
      _bootstrapJobs.remove(sessionId);
    }
  }

  Future<void> _bootstrap(String sessionId) async {
    final s = state.sessions.firstWhereOrNull((e) => e.id == sessionId);
    if (s == null) return;
    if (await _env.isRootfsReady(sessionId)) {
      final path = (await _env.rootfsDir(sessionId)).path;
      if (!mounted || _deleting.contains(sessionId)) return;
      _updateSession(
        s.copyWith(
          status: TerminalSessionStatus.stopped,
          rootfsPath: path,
          lastError: null,
        ),
      );
      await _persist();
      return;
    }
    if (!mounted || _deleting.contains(sessionId)) return;
    final token = CancelToken();
    _cancelTokens[sessionId] = token;
    state = TerminalState(
      sessions: state.sessions,
      activeId: state.activeId,
      bootstrapping: {...state.bootstrapping, sessionId},
      bootstrapProgress: {...state.bootstrapProgress, sessionId: 0},
      runtimes: state.runtimes,
    );
    _updateSession(
      s.copyWith(status: TerminalSessionStatus.bootstrapping, lastError: null),
    );
    try {
      final path = await _env.bootstrapAlpine(
        sessionId,
        cancelToken: token,
        onProgress: (r, t) {
          if (mounted && t != null && t > 0) {
            state = TerminalState(
              sessions: state.sessions,
              activeId: state.activeId,
              bootstrapping: state.bootstrapping,
              bootstrapProgress: {...state.bootstrapProgress, sessionId: r / t},
              runtimes: state.runtimes,
            );
          }
        },
      );
      if (!mounted) return;
      final cur = state.sessions.firstWhereOrNull((e) => e.id == sessionId);
      if (cur != null) {
        _updateSession(
          cur.copyWith(
            status: TerminalSessionStatus.stopped,
            rootfsPath: path,
            lastError: null,
          ),
        );
        await _persist();
      }
    } catch (e) {
      if (!mounted) return;
      final cur = state.sessions.firstWhereOrNull((e) => e.id == sessionId);
      if (cur != null) {
        _updateSession(
          cur.copyWith(status: TerminalSessionStatus.error, lastError: '$e'),
        );
        await _persist();
      }
    } finally {
      _cancelTokens.remove(sessionId);
      if (mounted) {
        final bs = {...state.bootstrapping}..remove(sessionId);
        final bp = {...state.bootstrapProgress}..remove(sessionId);
        state = TerminalState(
          sessions: state.sessions,
          activeId: state.activeId,
          bootstrapping: bs,
          bootstrapProgress: bp,
          runtimes: state.runtimes,
        );
      }
    }
  }

  final _starting = <String>{};

  Future<void> start(String sessionId) async {
    if (!_starting.add(sessionId)) return;
    try {
      await _start(sessionId);
    } finally {
      _starting.remove(sessionId);
    }
  }

  Future<void> _start(String sessionId) async {
    var s = state.sessions.firstWhereOrNull((e) => e.id == sessionId);
    if (s == null || _deleting.contains(sessionId)) return;
    if (state.runtimes[sessionId]?.pty != null) return;
    final ready = await _env.isRootfsReady(sessionId);
    if (!mounted || _deleting.contains(sessionId)) return;
    if (!ready) {
      await bootstrap(sessionId);
      if (!mounted || _deleting.contains(sessionId)) return;
      s = state.sessions.firstWhereOrNull((e) => e.id == sessionId);
      if (s == null || !await _env.isRootfsReady(sessionId)) return;
    }
    if (!mounted || _deleting.contains(sessionId)) return;
    _updateSession(
      s.copyWith(status: TerminalSessionStatus.starting, lastError: null),
    );
    try {
      final rootfs = (await _env.rootfsDir(sessionId)).path;
      final cmd = await _env.buildShellCommand(rootfsPath: rootfs);
      if (!mounted ||
          _deleting.contains(sessionId) ||
          !state.sessions.any((item) => item.id == sessionId)) {
        return;
      }
      final pty = Pty.start(
        cmd.executable,
        arguments: cmd.args,
        environment: cmd.env,
        workingDirectory: rootfs,
        columns: 80,
        rows: 24,
      );
      final rt = TerminalRuntime(session: s, pty: pty);
      pty.output.listen((data) {
        if (!rt.output.isClosed) rt.output.add(data);
      });
      pty.exitCode.then((code) {
        if (!mounted || state.runtimes[sessionId] != rt) return;
        final cur = state.sessions.firstWhereOrNull((e) => e.id == sessionId);
        if (cur != null) {
          _updateSession(
            cur.copyWith(
              status: TerminalSessionStatus.stopped,
              lastError: code == 0 ? null : 'Processo encerrou (código $code).',
            ),
          );
          _persist();
        }
        final runtimes = {...state.runtimes}..remove(sessionId);
        state = TerminalState(
          sessions: state.sessions,
          activeId: state.activeId,
          bootstrapping: state.bootstrapping,
          bootstrapProgress: state.bootstrapProgress,
          runtimes: runtimes,
        );
        rt.output.close();
      });
      final runtimes = {...state.runtimes, sessionId: rt};
      state = TerminalState(
        sessions: state.sessions,
        activeId: state.activeId,
        bootstrapping: state.bootstrapping,
        bootstrapProgress: state.bootstrapProgress,
        runtimes: runtimes,
      );
      _updateSession(
        s.copyWith(
          status: TerminalSessionStatus.running,
          rootfsPath: rootfs,
          lastError: null,
        ),
      );
      await _persist();
    } catch (e) {
      if (!mounted || _deleting.contains(sessionId)) return;
      final current = state.sessions.firstWhereOrNull(
        (item) => item.id == sessionId,
      );
      if (current == null) return;
      _updateSession(
        current.copyWith(
          status: TerminalSessionStatus.error,
          lastError: 'Falha ao iniciar PTY/shell: $e',
        ),
      );
      await _persist();
    }
  }

  void write(String sessionId, String data) {
    final pty = state.runtimes[sessionId]?.pty;
    if (pty == null) return;
    pty.write(const Utf8Encoder().convert(data));
  }

  void resize(String sessionId, int cols, int rows) {
    state.runtimes[sessionId]?.pty?.resize(rows, cols);
  }

  Future<void> stop(String sessionId) async {
    try {
      state.runtimes[sessionId]?.pty?.kill();
    } catch (_) {}
    final s = state.sessions.firstWhereOrNull((e) => e.id == sessionId);
    if (s != null) {
      _updateSession(s.copyWith(status: TerminalSessionStatus.stopped));
      await _persist();
    }
  }

  Future<void> deleteSession(String sessionId) async {
    if (!_deleting.add(sessionId)) return;
    try {
      // The job may still be checking readiness before it creates its token.
      _cancelTokens[sessionId]?.cancel('deleted');
      final job = _bootstrapJobs[sessionId];
      if (job != null) {
        await job;
      }
      await _deleteSession(sessionId);
    } finally {
      _deleting.remove(sessionId);
    }
  }

  Future<void> _deleteSession(String sessionId) async {
    await stop(sessionId);
    try {
      await _env.deleteSessionEnv(sessionId);
    } catch (_) {}
    final sessions = state.sessions.where((s) => s.id != sessionId).toList();
    final activeId = state.activeId == sessionId
        ? (sessions.isNotEmpty ? sessions.first.id : null)
        : state.activeId;
    final runtime = state.runtimes[sessionId];
    final runtimes = {...state.runtimes}..remove(sessionId);
    state = TerminalState(
      sessions: sessions,
      activeId: activeId,
      bootstrapping: {...state.bootstrapping}..remove(sessionId),
      bootstrapProgress: {...state.bootstrapProgress}..remove(sessionId),
      runtimes: runtimes,
    );
    runtime?.dispose();
    await _persist();
  }

  @override
  void dispose() {
    for (final token in _cancelTokens.values) {
      token.cancel('controller disposed');
    }
    for (final rt in state.runtimes.values) {
      rt.dispose();
    }
    super.dispose();
  }
}
