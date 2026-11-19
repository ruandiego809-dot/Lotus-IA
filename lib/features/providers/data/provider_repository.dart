import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';

import '../../../core/models/provider_models.dart';
import '../../../core/storage/local_store.dart';
import '../../../core/storage/secure_store.dart';
import '../domain/provider_adapter.dart';
import 'provider_registry.dart';

final localStoreProvider = Provider((ref) => LocalStore());
final secureStoreProvider = Provider((ref) => SecureStore());
final providerRegistryProvider = Provider((ref) => ProviderRegistry());

class ProviderState {
  const ProviderState({required this.configs, this.loading = false});
  final List<ProviderConfig> configs;
  final bool loading;

  ProviderConfig? get defaultConfig =>
      configs.where((c) => c.isDefault && c.enabled).firstOrNull ??
      configs.where((c) => c.enabled).firstOrNull;

  ProviderConfig? byIdOrNull(String id) =>
      configs.where((c) => c.id == id).firstOrNull;

  ProviderConfig byId(String id) =>
      byIdOrNull(id) ??
      ProviderConfig.defaults(ProviderType.customOpenAiCompatible).copyWith();
}

class ProviderController extends StateNotifier<AsyncValue<ProviderState>> {
  ProviderController(this.ref) : super(const AsyncValue.loading()) {
    load();
  }
  final Ref ref;

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final configs = await ref.read(localStoreProvider).loadProviders();
      state = AsyncValue.data(ProviderState(configs: configs));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> save(List<ProviderConfig> configs) async {
    await ref.read(localStoreProvider).saveProviders(configs);
    state = AsyncValue.data(ProviderState(configs: configs));
  }

  Future<void> updateConfig(ProviderConfig config) async {
    final cur = state.value?.configs ?? [];
    final list = [
      for (final c in cur)
        if (c.id == config.id) config else c,
    ];
    await save(list);
  }

  Future<void> setDefault(String id) async {
    final cur = state.value?.configs ?? [];
    final list = [for (final c in cur) c.copyWith(isDefault: c.id == id)];
    await save(list);
  }

  ProviderAdapter adapterFor(ProviderType type) =>
      ref.read(providerRegistryProvider).forType(type);
}

final providerControllerProvider =
    StateNotifierProvider<ProviderController, AsyncValue<ProviderState>>(
      (ref) => ProviderController(ref),
    );

final apiKeyProvider = FutureProvider.family<String?, String>((
  ref,
  providerId,
) {
  return ref.read(secureStoreProvider).readApiKey(providerId);
});
