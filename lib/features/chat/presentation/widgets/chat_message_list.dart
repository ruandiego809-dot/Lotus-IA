// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../../../../core/models/chat_models.dart';
import '../../../../core/utils/date_labels.dart';
import '../../../../design/design.dart';
import 'chat_message_bubble.dart';

class ChatMessageList extends StatefulWidget {
  const ChatMessageList({
    super.key,
    required this.conversation,
    required this.generating,
    required this.controller,
    required this.onEdit,
    required this.onRegenerate,
    required this.onReply,
  });

  final Conversation conversation;
  final bool generating;
  final ScrollController controller;
  final ValueChanged<ChatMessage> onEdit;
  final VoidCallback onRegenerate;
  final ValueChanged<ChatMessage> onReply;

  @override
  State<ChatMessageList> createState() => _ChatMessageListState();
}

class _ChatMessageListState extends State<ChatMessageList> {
  final Map<String, _CachedBubble> _cache = {};
  String? _conversationId;
  int _lastCount = 0;
  int _lastLength = 0;
  bool _stickToBottom = true;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleScroll);
    _conversationId = widget.conversation.id;
    _lastCount = widget.conversation.messages.length;
    _lastLength = _lastMessageLength;
    _scheduleScroll(animate: false);
  }

  @override
  void didUpdateWidget(covariant ChatMessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    final messages = widget.conversation.messages;
    final switched = widget.conversation.id != _conversationId;
    if (switched) {
      _conversationId = widget.conversation.id;
      _cache.clear();
      _stickToBottom = true;
    }
    final added = messages.length != _lastCount;
    final grew = messages.isNotEmpty && _lastMessageLength != _lastLength;
    _lastCount = messages.length;
    _lastLength = _lastMessageLength;
    if (switched || added || grew) {
      _scheduleScroll(animate: added || switched);
    }
    if (_cache.length > 120) {
      final alive = {for (final m in messages) m.id};
      _cache.removeWhere((key, _) => !alive.contains(key));
    }
  }

  int get _lastMessageLength {
    final messages = widget.conversation.messages;
    return messages.isEmpty ? 0 : messages.last.content.length;
  }

  void _handleScroll() {
    if (!widget.controller.hasClients) return;
    _stickToBottom = widget.controller.position.extentAfter < 180;
  }

  void _scheduleScroll({required bool animate}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = widget.controller;
      if (!controller.hasClients) return;
      if (!_stickToBottom) return;
      final position = controller.position;
      final target = position.maxScrollExtent;
      if ((position.pixels - target).abs() < 4) return;
      final distance = (target - position.pixels).abs();
      if (animate && distance < 1200) {
        controller.animateTo(
          target,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      } else {
        controller.jumpTo(target);
      }
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleScroll);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messages = widget.conversation.messages;
    return ListView.builder(
      scrollCacheExtent: const ScrollCacheExtent.pixels(640), controller: widget.controller,
      padding: const EdgeInsets.fromLTRB(
        LotusSpace.lg,
        LotusSpace.sm,
        LotusSpace.lg,
        LotusSpace.md,
      ),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: messages.length,
      addAutomaticKeepAlives: false,
      addRepaintBoundaries: false,
      itemBuilder: (context, index) {
        final message = messages[index];
        final day = formatDayLabel(message.createdAt);
        final showHeader =
            index == 0 || formatDayLabel(messages[index - 1].createdAt) != day;
        final isLastAssistant =
            index == messages.length - 1 &&
            message.role == MessageRole.assistant &&
            !message.isStreaming &&
            !widget.generating;
        final canEdit = message.role == MessageRole.user && !widget.generating;
        final bubble = _bubbleFor(
          message: message,
          canEdit: canEdit,
          canRegenerate: isLastAssistant,
          showRetry: isLastAssistant && message.error != null,
          onReply: () => widget.onReply(message),
        );
        return RepaintBoundary(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showHeader) _DayDivider(label: day),
              bubble,
            ],
          ),
        );
      },
    );
  }

  /// Reuses the previously built widget while its message instance and
  /// interaction flags are unchanged. Completed Markdown bubbles are therefore
  /// not rebuilt (or re-parsed) for every streamed token.
  Widget _bubbleFor({
    required ChatMessage message,
    required bool canEdit,
    required bool canRegenerate,
    required bool showRetry,
    required VoidCallback onReply,
  }) {
    final cached = _cache[message.id];
    if (cached != null &&
        identical(cached.message, message) &&
        cached.canEdit == canEdit &&
        cached.canRegenerate == canRegenerate &&
        cached.showRetry == showRetry) {
      return cached.widget;
    }
    final bubble = ChatMessageBubble(
      message: message,
      canEdit: canEdit,
      canRegenerate: canRegenerate,
      onEdit: () => widget.onEdit(message),
      onRegenerate: widget.onRegenerate,
      onRetry: showRetry
          ? () {
              widget.onRegenerate();
            }
          : null,
      onReply: onReply,
    );
    _cache[message.id] = _CachedBubble(
      message: message,
      canEdit: canEdit,
      canRegenerate: canRegenerate,
      showRetry: showRetry,
      widget: bubble,
    );
    return bubble;
  }
}

class _CachedBubble {
  const _CachedBubble({
    required this.message,
    required this.canEdit,
    required this.canRegenerate,
    required this.showRetry,
    required this.widget,
  });

  final ChatMessage message;
  final bool canEdit;
  final bool canRegenerate;
  final bool showRetry;
  final Widget widget;
}

class _DayDivider extends StatelessWidget {
  const _DayDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: LotusSpace.md),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: LotusSpace.md),
            child: Text(
              label,
              style: context.text.labelSmall?.copyWith(letterSpacing: 0.3),
            ),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}
