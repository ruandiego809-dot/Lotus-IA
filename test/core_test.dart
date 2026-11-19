import 'package:flutter_test/flutter_test.dart';
import 'package:lotus_ai/core/models/chat_models.dart';
import 'package:lotus_ai/core/models/provider_models.dart';
import 'package:lotus_ai/core/utils/token_estimator.dart';

void main() {
  test('TokenEstimator estimates roughly 4 chars per token', () {
    expect(TokenEstimator.estimate(''), 0);
    expect(TokenEstimator.estimate('abcd'), 1);
    expect(TokenEstimator.estimate('abcdefgh'), 2);
  });

  test('ChatMessage/Conversation JSON roundtrip', () {
    final msg = ChatMessage(
      role: MessageRole.user,
      content: 'hello',
      usage: const ChatUsage(totalTokens: 5),
    );
    final conv = Conversation(
      title: 't',
      messages: [msg],
      providerId: 'openai',
      modelId: 'gpt',
      systemPrompt: 'sys',
    );
    final j = conv.toJson();
    final conv2 = Conversation.fromJson(j);
    expect(conv2.title, 't');
    expect(conv2.messages.length, 1);
    expect(conv2.messages.first.content, 'hello');
    expect(conv2.messages.first.usage?.totalTokens, 5);
    expect(conv2.systemPrompt, 'sys');
  });

  test('ProviderConfig context limit roundtrip', () {
    final c = ProviderConfig.defaults(ProviderType.openai)
        .copyWith(modelContextLimits: const {'gpt-4': 8192});
    final j = c.toJson();
    final c2 = ProviderConfig.fromJson(j);
    expect(c2.contextLimitFor('gpt-4'), 8192);
  });
}
