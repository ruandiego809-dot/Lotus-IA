// ignore_for_file: deprecated_member_use
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/chat_models.dart';
import '../../../core/models/provider_models.dart';
import '../../../design/design.dart';
import '../../providers/data/provider_repository.dart';

final groupChatProvider =
    StateNotifierProvider<GroupChatController, GroupChatState>((ref) {
  return GroupChatController(ref);
});

class GroupChatState {
  const GroupChatState({
    this.selectedProviderIds = const [],
    this.availableProviders = const [],
    this.turns = const [],
    this.isLoading = false,
    this.error,
  });

  final List<String> selectedProviderIds;
  final List<ProviderConfig> availableProviders;
  final List<GroupTurn> turns;
  final bool isLoading;
  final String? error;

  static const Object _unset = Object();

  GroupChatState copyWith({
    List<String>? selectedProviderIds,
    List<ProviderConfig>? availableProviders,
    List<GroupTurn>? turns,
    bool? isLoading,
    Object? error = _unset,
  }) {
    return GroupChatState(
      selectedProviderIds: selectedProviderIds ?? this.selectedProviderIds,
      availableProviders: availableProviders ?? this.availableProviders,
      turns: turns ?? this.turns,
      isLoading: isLoading ?? this.isLoading,
      error: identical(error, _unset) ? this.error : error as String?,
    );
  }
}

class GroupTurn {
  const GroupTurn({
    required this.id,
    required this.prompt,
    required this.responses,
  });

  final String id;
  final String prompt;
  final List<GroupResponse> responses;

  GroupTurn copyWith({List<GroupResponse>? responses}) => GroupTurn(
    id: id,
    prompt: prompt,
    responses: responses ?? this.responses,
  );
}

class GroupResponse {
  const GroupResponse({
    required this.providerId,
    required this.providerName,
    required this.modelId,
    this.content = '',
    this.error,
    this.isStreaming = true,
  });

  final String providerId;
  final String providerName;
  final String modelId;
  final String content;

  /// Machine-readable error code resolved by the UI. Values: `no_model`,
  /// `cancelled`, `provider`.
  final String? error;
  final bool isStreaming;

  static const Object _unset = Object();

  GroupResponse copyWith({
    String? content,
    bool? isStreaming,
    Object? error = _unset,
  }) {
    return GroupResponse(
      providerId: providerId,
      providerName: providerName,
      modelId: modelId,
      content: content ?? this.content,
      error: identical(error, _unset) ? this.error : error as String?,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }
}

class GroupChatController extends StateNotifier<GroupChatState> {
  GroupChatController(this.ref) : super(const GroupChatState()) {
    _syncProviders(ref.read(providerControllerProvider).value?.configs);
    ref.listen(providerControllerProvider, (_, next) {
      _syncProviders(next.value?.configs);
    });
  }

  final Ref ref;
  final Map<String, CancelToken> _tokens = {};
  bool _disposed = false;

  void _syncProviders(List<ProviderConfig>? configs) {
    if (_disposed || configs == null) return;
    final enabled = configs.where((c) => c.enabled).toList();
    final ids = enabled.map((c) => c.id).toSet();
    state = state.copyWith(
      availableProviders: enabled,
      selectedProviderIds: state.selectedProviderIds
          .where(ids.contains)
          .toList(growable: false),
    );
  }

  void toggleProvider(String providerId) {
    if (state.isLoading) return;
    final selected = List<String>.from(state.selectedProviderIds);
    if (selected.contains(providerId)) {
      selected.remove(providerId);
    } else {
      selected.add(providerId);
    }
    state = state.copyWith(selectedProviderIds: selected);
  }

  bool isSelected(String providerId) =>
      state.selectedProviderIds.contains(providerId);

  Future<void> sendMessage(String text) async {
    final prompt = text.trim();
    if (prompt.isEmpty || state.selectedProviderIds.isEmpty || state.isLoading) {
      return;
    }
    final configs = state.availableProviders
        .where((c) => state.selectedProviderIds.contains(c.id))
        .toList(growable: false);
    if (configs.isEmpty) return;

    final turn = GroupTurn(
      id: 'turn-${DateTime.now().microsecondsSinceEpoch}',
      prompt: prompt,
      responses: [
        for (final c in configs)
          GroupResponse(
            providerId: c.id,
            providerName: c.name,
            modelId: c.selectedModel ?? '',
          ),
      ],
    );
    state = state.copyWith(
      turns: [...state.turns, turn],
      isLoading: true,
      error: null,
    );

    try {
      await Future.wait(configs.map((config) => _runProvider(turn, config)));
    } finally {
      if (!_disposed) state = state.copyWith(isLoading: false);
    }
  }

  Future<void> _runProvider(GroupTurn turn, ProviderConfig config) async {
    final model = config.selectedModel?.trim();
    if (model == null || model.isEmpty) {
      _updateResponse(turn.id, config.id, error: 'no_model', isStreaming: false);
      return;
    }

    final adapter = ref
        .read(providerControllerProvider.notifier)
        .adapterFor(config.type);
    final token = CancelToken();
    _tokens[config.id] = token;
    final buffer = StringBuffer();
    final clock = Stopwatch()..start();
    var lastPublish = -1000;

    try {
      final apiKey = await ref.read(secureStoreProvider).readApiKey(config.id);
      final messages = <ChatMessage>[
        ..._historyFor(config.id, turn.id),
        ChatMessage(role: MessageRole.user, content: turn.prompt),
      ];
      await for (final ev in adapter.streamChat(
        config: config,
        apiKey: apiKey,
        model: model,
        messages: messages,
        cancelToken: token,
      )) {
        if (token.isCancelled) break;
        if (ev.delta != null) buffer.write(ev.delta);
        final now = clock.elapsedMilliseconds;
        if (ev.usage == null && now - lastPublish < 50) continue;
        lastPublish = now;
        _updateResponse(
          turn.id,
          config.id,
          content: buffer.toString(),
          isStreaming: true,
        );
      }
      _updateResponse(
        turn.id,
        config.id,
        content: buffer.toString(),
        isStreaming: false,
        error: token.isCancelled ? 'cancelled' : null,
      );
    } catch (e) {
      _updateResponse(
        turn.id,
        config.id,
        content: buffer.toString(),
        isStreaming: false,
        error: token.isCancelled ? 'cancelled' : 'provider',
      );
    } finally {
      _tokens.remove(config.id);
    }
  }

  /// Builds the per-provider conversation history from previous completed
  /// turns, so each model keeps its own thread across rounds.
  List<ChatMessage> _historyFor(String providerId, String currentTurnId) {
    final history = <ChatMessage>[];
    for (final turn in state.turns) {
      if (turn.id == currentTurnId) break;
      GroupResponse? response;
      for (final candidate in turn.responses) {
        if (candidate.providerId == providerId) {
          response = candidate;
          break;
        }
      }
      if (response == null ||
          response.error != null ||
          response.content.trim().isEmpty) {
        continue;
      }
      history
        ..add(ChatMessage(role: MessageRole.user, content: turn.prompt))
        ..add(
          ChatMessage(role: MessageRole.assistant, content: response.content),
        );
    }
    return history;
  }

  void _updateResponse(
    String turnId,
    String providerId, {
    String? content,
    bool? isStreaming,
    Object? error = GroupResponse._unset,
  }) {
    if (_disposed) return;
    final turns = [
      for (final turn in state.turns)
        if (turn.id == turnId)
          turn.copyWith(
            responses: [
              for (final response in turn.responses)
                if (response.providerId == providerId)
                  response.copyWith(
                    content: content,
                    isStreaming: isStreaming,
                    error: error,
                  )
                else
                  response,
            ],
          )
        else
          turn,
    ];
    state = state.copyWith(turns: turns);
  }

  void cancelGeneration() {
    for (final token in _tokens.values) {
      token.cancel('group-chat-cancelled');
    }
    _tokens.clear();
  }

  void clearMessages() {
    if (state.isLoading) return;
    state = state.copyWith(turns: const [], error: null);
  }

  @override
  void dispose() {
    _disposed = true;
    cancelGeneration();
    super.dispose();
  }
}

class GroupChatPage extends ConsumerWidget {
  const GroupChatPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(groupChatProvider);
    final l10n = context.l10n;

    return LotusScaffold(
      appBar: LotusAppBar(
        showBrand: true,
        title: l10n.groupChat,
        subtitle: l10n.groupChatSubtitle,
        actions: [
          IconButton(
            tooltip: l10n.groupClear,
            onPressed: state.turns.isEmpty || state.isLoading
                ? null
                : () => ref.read(groupChatProvider.notifier).clearMessages(),
            icon: const Icon(Icons.delete_sweep_rounded, size: 21),
          ),
          IconButton(
            tooltip: l10n.goBack,
            onPressed: () => context.canPop() ? context.pop() : context.go('/chat'),
            icon: const Icon(Icons.close_rounded, size: 21),
          ),
        ],
      ),
      body: Column(
        children: [
          _ProviderSelectionBar(state: state),
          const Divider(height: 1),
          Expanded(
            child: state.turns.isEmpty
                ? _EmptyGroup(hasProviders: state.availableProviders.isNotEmpty)
                : _GroupMessages(turns: state.turns),
          ),
          _GroupComposer(state: state),
        ],
      ),
    );
  }
}

class _ProviderSelectionBar extends ConsumerWidget {
  const _ProviderSelectionBar({required this.state});

  final GroupChatState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    if (state.availableProviders.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(LotusSpace.md),
        child: Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 18,
              color: context.palette.muted,
            ),
            const SizedBox(width: LotusSpace.sm),
            Expanded(
              child: Text(
                l10n.groupNoProviders,
                style: context.text.labelSmall,
              ),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        LotusSpace.md,
        LotusSpace.sm,
        LotusSpace.md,
        LotusSpace.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(l10n.groupSelectModels, style: context.text.labelSmall),
              const Spacer(),
              if (state.selectedProviderIds.isNotEmpty)
                Text(
                  l10n.groupSelectedCount(state.selectedProviderIds.length),
                  style: context.text.labelSmall?.copyWith(
                    color: context.scheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: LotusSpace.xs),
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: state.availableProviders.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(width: LotusSpace.sm),
              itemBuilder: (context, index) {
                final config = state.availableProviders[index];
                final selected = state.selectedProviderIds.contains(config.id);
                return FilterChip(
                  selected: selected,
                  showCheckmark: false,
                  avatar: selected
                      ? Icon(
                          Icons.check_rounded,
                          size: 15,
                          color: context.scheme.primary,
                        )
                      : null,
                  label: Text(
                    config.selectedModel == null
                        ? config.name
                        : '${config.name} • ${config.selectedModel}',
                    style: context.text.labelSmall?.copyWith(
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                  onSelected: state.isLoading
                      ? null
                      : (_) => ref
                            .read(groupChatProvider.notifier)
                            .toggleProvider(config.id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyGroup extends StatelessWidget {
  const _EmptyGroup({required this.hasProviders});

  final bool hasProviders;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(LotusSpace.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const LotusBrandMark(size: 64, radius: 24),
              const SizedBox(height: LotusSpace.lg),
              Text(
                l10n.groupChat,
                style: context.text.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: LotusSpace.sm),
              Text(
                hasProviders ? l10n.groupEmptyMsg : l10n.groupNoProviders,
                textAlign: TextAlign.center,
                style: context.text.bodySmall?.copyWith(height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupMessages extends StatefulWidget {
  const _GroupMessages({required this.turns});

  final List<GroupTurn> turns;

  @override
  State<_GroupMessages> createState() => _GroupMessagesState();
}

class _GroupMessagesState extends State<_GroupMessages> {
  final _controller = ScrollController();

  @override
  void didUpdateWidget(covariant _GroupMessages oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nearBottom =
        !_controller.hasClients ||
        _controller.position.maxScrollExtent - _controller.offset < 180;
    if (nearBottom) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_controller.hasClients) return;
        _controller.animateTo(
          _controller.position.maxScrollExtent,
          duration: LotusMotion.fast,
          curve: LotusMotion.curve,
        );
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: _controller,
      padding: const EdgeInsets.symmetric(vertical: LotusSpace.md),
      itemCount: widget.turns.length,
      itemBuilder: (context, index) => _MessageTurn(
        turnNumber: index + 1,
        turn: widget.turns[index],
      ),
    );
  }
}

class _MessageTurn extends StatelessWidget {
  const _MessageTurn({required this.turnNumber, required this.turn});

  final int turnNumber;
  final GroupTurn turn;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: LotusBreakpoints.chatMaxWidth,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            LotusSpace.md,
            0,
            LotusSpace.md,
            LotusSpace.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 560),
                  margin: const EdgeInsets.only(bottom: LotusSpace.md),
                  padding: const EdgeInsets.symmetric(
                    horizontal: LotusSpace.lg,
                    vertical: LotusSpace.md,
                  ),
                  decoration: BoxDecoration(
                    gradient: context.palette.brandGradient,
                    borderRadius: BorderRadius.circular(LotusRadius.lg),
                  ),
                  child: Text(
                    turn.prompt,
                    style: context.text.bodyMedium?.copyWith(
                      color: Colors.white,
                      height: 1.45,
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: context.scheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(LotusRadius.pill),
                    ),
                    child: Center(
                      child: Text(
                        '$turnNumber',
                        style: context.text.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: context.scheme.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: LotusSpace.sm),
                  Text(
                    l10n.groupResponses,
                    style: context.text.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: LotusSpace.sm),
              LayoutBuilder(
                builder: (context, constraints) {
                  final sideBySide =
                      constraints.maxWidth >= 860 && turn.responses.length > 1;
                  if (!sideBySide) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final response in turn.responses)
                          _SingleMessage(response: response),
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < turn.responses.length; i++) ...[
                        if (i > 0) const SizedBox(width: LotusSpace.md),
                        Expanded(
                          child: _SingleMessage(
                            response: turn.responses[i],
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SingleMessage extends StatelessWidget {
  const _SingleMessage({required this.response});

  final GroupResponse response;

  String _errorText(BuildContext context) => switch (response.error) {
    'no_model' => context.l10n.groupNoModel,
    'cancelled' => context.l10n.groupStopped,
    _ => context.l10n.groupError,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final error = response.error != null;
    return LotusCard(
      padding: const EdgeInsets.all(LotusSpace.md),
      margin: const EdgeInsets.only(bottom: LotusSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const LotusBrandMark(size: 24, radius: 8),
              const SizedBox(width: LotusSpace.sm),
              Expanded(
                child: Text(
                  response.providerName,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (!response.isStreaming && response.content.isNotEmpty)
                IconButton(
                  tooltip: l10n.groupCopy,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 30,
                    minHeight: 30,
                  ),
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: response.content),
                    );
                    if (!context.mounted) return;
                    LotusFeedback.show(
                      context,
                      l10n.groupCopied,
                      tone: LotusSnackTone.success,
                    );
                  },
                  icon: Icon(
                    Icons.copy_rounded,
                    size: 15,
                    color: context.palette.muted,
                  ),
                ),
            ],
          ),
          if (response.modelId.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: LotusSpace.xs),
              child: Text(
                response.modelId,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelSmall?.copyWith(
                  color: context.palette.muted,
                ),
              ),
            ),
          const SizedBox(height: LotusSpace.xs),
          if (error)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(LotusSpace.md),
              decoration: BoxDecoration(
                color: context.scheme.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(LotusRadius.sm),
                border: Border.all(
                  color: context.scheme.error.withValues(alpha: 0.25),
                ),
              ),
              child: Text(
                _errorText(context),
                style: context.text.bodySmall?.copyWith(
                  color: context.scheme.error,
                ),
              ),
            )
          else if (response.content.isEmpty && response.isStreaming)
            const _TypingDots()
          else
            SelectableText(
              response.content.isEmpty ? l10n.noContent : response.content,
              style: context.text.bodyMedium?.copyWith(height: 1.5),
            ),
        ],
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = context.scheme.primary;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          children: [
            for (var i = 0; i < 3; i++)
              Padding(
                padding: const EdgeInsets.only(right: 5),
                child: Opacity(
                  opacity:
                      0.25 +
                      0.75 *
                          (1 -
                                  ((_controller.value + i * 0.18) % 1.0) * 2)
                              .abs()
                              .clamp(0.0, 1.0),
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            const SizedBox(width: 4),
            Text(
              context.l10n.groupThinking,
              style: context.text.labelSmall?.copyWith(color: color),
            ),
          ],
        );
      },
    );
  }
}

class _GroupComposer extends ConsumerStatefulWidget {
  const _GroupComposer({required this.state});

  final GroupChatState state;

  @override
  ConsumerState<_GroupComposer> createState() => _GroupComposerState();
}

class _GroupComposerState extends ConsumerState<_GroupComposer> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    setState(() {});
    await ref.read(groupChatProvider.notifier).sendMessage(text);
    if (!mounted) return;
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final l10n = context.l10n;
    final canSend = !state.isLoading &&
        state.selectedProviderIds.isNotEmpty &&
        _controller.text.trim().isNotEmpty;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(
        LotusSpace.md,
        0,
        LotusSpace.md,
        LotusSpace.sm,
      ),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: LotusBreakpoints.chatMaxWidth,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(
              LotusSpace.md,
              LotusSpace.md,
              LotusSpace.sm,
              LotusSpace.sm,
            ),
            decoration: BoxDecoration(
              color: context.palette.elevated,
              borderRadius: BorderRadius.circular(LotusRadius.lg),
              border: Border.all(color: context.palette.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: context.isDark ? 0.32 : 0.05,
                  ),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focus,
                    minLines: 1,
                    maxLines: 6,
                    textInputAction: TextInputAction.newline,
                    keyboardType: TextInputType.multiline,
                    enabled: !state.isLoading &&
                        state.selectedProviderIds.isNotEmpty,
                    onChanged: (_) => setState(() {}),
                    style: context.text.bodyMedium?.copyWith(
                      fontSize: 15,
                      height: 1.45,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: LotusSpace.xs,
                        vertical: LotusSpace.xs,
                      ),
                      hintText: state.selectedProviderIds.isEmpty
                          ? l10n.groupSelectFirst
                          : l10n.groupHint,
                    ),
                  ),
                ),
                const SizedBox(width: LotusSpace.sm),
                _SendButton(
                  generating: state.isLoading,
                  enabled: canSend,
                  onSend: state.isLoading
                      ? () => ref
                          .read(groupChatProvider.notifier)
                          .cancelGeneration()
                      : _send,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.generating,
    required this.enabled,
    required this.onSend,
  });

  final bool generating;
  final bool enabled;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: generating || enabled ? onSend : null,
      child: AnimatedContainer(
        duration: LotusMotion.fast,
        curve: LotusMotion.curve,
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          gradient: generating || !enabled ? null : context.palette.brandGradient,
          color: generating
              ? context.scheme.errorContainer
              : (enabled ? null : context.scheme.surfaceContainerHighest),
          borderRadius: BorderRadius.circular(LotusRadius.sm),
        ),
        child: AnimatedSwitcher(
          duration: LotusMotion.fast,
          child: Icon(
            generating ? Icons.stop_rounded : Icons.arrow_upward_rounded,
            key: ValueKey(generating),
            size: 22,
            color: generating
                ? context.scheme.onErrorContainer
                : enabled
                    ? Colors.white
                    : context.palette.muted,
          ),
        ),
      ),
    );
  }
}
