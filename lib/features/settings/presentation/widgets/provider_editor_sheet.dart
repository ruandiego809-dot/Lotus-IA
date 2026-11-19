// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/provider_models.dart';
import '../../../../design/design.dart';
import '../../../providers/data/provider_repository.dart';

/// Provider configuration sheet. Owns every controller it creates and only
/// persists on an explicit save, avoiding the previous leaks and partial states.
class ProviderEditorSheet extends ConsumerStatefulWidget {
  const ProviderEditorSheet({
    super.key,
    required this.config,
    required this.storedKey,
  });

  final ProviderConfig config;
  final String? storedKey;

  @override
  ConsumerState<ProviderEditorSheet> createState() =>
      _ProviderEditorSheetState();
}

class _ProviderEditorSheetState extends ConsumerState<ProviderEditorSheet> {
  late final TextEditingController _key = TextEditingController(
    text: widget.storedKey ?? '',
  );
  late final TextEditingController _endpoint = TextEditingController(
    text: widget.config.endpoint ?? widget.config.type.defaultEndpoint ?? '',
  );
  late final TextEditingController _model = TextEditingController(
    text: widget.config.selectedModel ?? '',
  );
  final _modelSearch = TextEditingController();
  final _contextLimit = TextEditingController();

  late bool _enabled = widget.config.enabled;
  late bool _isDefault = widget.config.isDefault;
  late List<String> _models = List.of(widget.config.availableModels);
  late Map<String, int> _limits = Map.of(widget.config.modelContextLimits);
  bool _testing = false;
  bool _saving = false;
  bool _obscureKey = true;
  String? _testMessage;
  bool _testOk = false;

  @override
  void initState() {
    super.initState();
    _syncLimitField();
  }

  @override
  void dispose() {
    _key.dispose();
    _endpoint.dispose();
    _model.dispose();
    _modelSearch.dispose();
    _contextLimit.dispose();
    super.dispose();
  }

  void _syncLimitField() {
    final model = _model.text.trim();
    _contextLimit.text = model.isEmpty
        ? ''
        : (_limits[model]?.toString() ?? '');
  }

  ProviderConfig _draft() => widget.config.copyWith(
    enabled: _enabled,
    endpoint: _endpoint.text.trim().isEmpty ? null : _endpoint.text.trim(),
    selectedModel: _model.text.trim().isEmpty ? null : _model.text.trim(),
    availableModels: List<String>.of(_models),
    isDefault: _isDefault,
  );

  Future<void> _runTest() async {
    setState(() {
      _testing = true;
      _testMessage = null;
    });
    final controller = ref.read(providerControllerProvider.notifier);
    final adapter = controller.adapterFor(widget.config.type);
    final result = await adapter.testConnection(
      config: _draft(),
      apiKey: _key.text.trim().isEmpty ? null : _key.text.trim(),
    );
    if (!mounted) return;
    setState(() {
      _testing = false;
      _testOk = result.ok;
      _testMessage = result.message;
      final models = result.models;
      if (models != null) {
        _models = models.map((m) => m.id).toSet().toList();
        final nextLimits = Map<String, int>.of(_limits);
        for (final model in models) {
          if (model.contextLimit != null && !nextLimits.containsKey(model.id)) {
            nextLimits[model.id] = model.contextLimit!;
          }
        }
        _limits = nextLimits;
        if (_model.text.trim().isEmpty && _models.isNotEmpty) {
          _model.text = _models.first;
        }
        _syncLimitField();
      }
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final selected = _model.text.trim();
      final key = _key.text.trim();
      final limit = int.tryParse(_contextLimit.text.trim());
      final limits = Map<String, int>.of(_limits);
      if (selected.isNotEmpty) {
        if (limit != null && limit > 0) {
          limits[selected] = limit;
        } else {
          limits.remove(selected);
        }
      }
      final updated = widget.config.copyWith(
        enabled: _enabled,
        endpoint: _endpoint.text.trim().isEmpty ? null : _endpoint.text.trim(),
        selectedModel: selected.isEmpty ? null : selected,
        availableModels: List<String>.of(_models),
        modelContextLimits: limits,
        isDefault: _isDefault,
      );
      final store = ref.read(secureStoreProvider);
      if (key.isEmpty) {
        await store.deleteApiKey(widget.config.id);
      } else {
        await store.saveApiKey(widget.config.id, key);
      }
      ref.invalidate(apiKeyProvider(widget.config.id));
      final state = ref.read(providerControllerProvider).value;
      if (state == null || state.byIdOrNull(widget.config.id) == null) {
        throw StateError('Configurações de provedores indisponíveis.');
      }
      var list = [
        for (final config in state.configs)
          if (config.id == updated.id) updated else config,
      ];
      if (updated.isDefault) {
        list = [
          for (final config in list)
            config.copyWith(isDefault: config.id == updated.id),
        ];
      }
      await ref.read(providerControllerProvider.notifier).save(list);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        LotusFeedback.show(
          context,
          'Falha ao salvar. A chave pode já ter sido atualizada; tente novamente.',
          tone: LotusSnackTone.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.config.type;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          LotusSpace.xl,
          LotusSpace.xs,
          LotusSpace.xl,
          LotusSpace.xxl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const LotusIconBadge(
                  icon: Icons.hub_outlined,
                  size: 42,
                  gradient: true,
                ),
                const SizedBox(width: LotusSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(type.label, style: context.text.titleMedium),
                      Text(
                        type.defaultEndpoint ?? 'Endpoint personalizado',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.labelSmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: LotusSpace.lg),
            LotusCard(
              padding: const EdgeInsets.symmetric(
                horizontal: LotusSpace.md,
                vertical: LotusSpace.xs,
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Habilitar provedor'),
                    subtitle: const Text('Aparece no seletor do chat'),
                    value: _enabled,
                    onChanged: (value) => setState(() => _enabled = value),
                  ),
                  const Divider(),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Definir como padrão'),
                    subtitle: const Text('Usado em novas conversas'),
                    value: _isDefault,
                    onChanged: (value) => setState(() => _isDefault = value),
                  ),
                ],
              ),
            ),
            const SizedBox(height: LotusSpace.lg),
            TextField(
              controller: _key,
              obscureText: _obscureKey,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: 'API key',
                helperText: 'Guardada no armazenamento seguro do dispositivo. Nunca é exportada.',
                suffixIcon: IconButton(
                  tooltip: _obscureKey ? 'Mostrar' : 'Ocultar',
                  icon: Icon(
                    _obscureKey
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 19,
                  ),
                  onPressed: () => setState(() => _obscureKey = !_obscureKey),
                ),
              ),
            ),
            if (type.supportsCustomEndpoint) ...[
              const SizedBox(height: LotusSpace.md),
              TextField(
                controller: _endpoint,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: 'Endpoint',
                  hintText: type.defaultEndpoint ?? 'https://...',
                ),
              ),
            ],
            const SizedBox(height: LotusSpace.md),
            TextField(
              controller: _model,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Modelo (ID)',
                hintText: 'ex: gpt-5.1',
              ),
              onChanged: (_) => setState(_syncLimitField),
            ),
            if (_models.isNotEmpty) ...[
              const SizedBox(height: LotusSpace.md),
              TextField(
                controller: _modelSearch,
                decoration: InputDecoration(
                  labelText: 'Buscar modelo',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  helperText: '${_models.length} modelos listados',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: LotusSpace.sm),
              _ModelDropdown(
                models: _models,
                query: _modelSearch.text,
                current: _model.text.trim(),
                onSelected: (value) {
                  setState(() {
                    _model.text = value;
                    _syncLimitField();
                  });
                },
              ),
            ],
            const SizedBox(height: LotusSpace.md),
            TextField(
              controller: _contextLimit,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Limite de contexto (tokens, opcional)',
                helperText:
                    'Usado pelo monitor quando a API não informa o limite.',
              ),
              onChanged: (value) {
                final model = _model.text.trim();
                if (model.isEmpty) return;
                final parsed = int.tryParse(value.trim());
                if (value.trim().isEmpty || parsed == null || parsed <= 0) {
                  _limits.remove(model);
                } else {
                  _limits[model] = parsed;
                }
              },
            ),
            const SizedBox(height: LotusSpace.lg),
            FilledButton.tonalIcon(
              onPressed: _testing || _saving ? null : _runTest,
              icon: _testing
                  ? const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.wifi_tethering_rounded, size: 18),
              label: Text(
                _testing ? 'Testando…' : 'Testar conexão e listar modelos',
              ),
            ),
            if (_testMessage != null) ...[
              const SizedBox(height: LotusSpace.md),
              Container(
                padding: const EdgeInsets.all(LotusSpace.md),
                decoration: BoxDecoration(
                  color:
                      (_testOk ? context.palette.success : context.scheme.error)
                          .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(LotusRadius.xs),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _testOk
                          ? Icons.check_circle_outline_rounded
                          : Icons.error_outline_rounded,
                      size: 17,
                      color: _testOk
                          ? context.palette.success
                          : context.scheme.error,
                    ),
                    const SizedBox(width: LotusSpace.sm),
                    Expanded(
                      child: Text(
                        _testMessage!,
                        style: context.text.bodySmall?.copyWith(
                          color: context.scheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: LotusSpace.xl),
            FilledButton.icon(
              onPressed: _testing || _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_rounded, size: 19),
              label: Text(_saving ? 'Salvando…' : 'Salvar provedor'),
            ),
            const SizedBox(height: LotusSpace.lg),
            Text(
              'Hugging Face usa um endpoint OpenAI-compatible configurável. Cohere tem adaptador dedicado (v2, streaming). Erros, limites e modelos são os retornados pela API.',
              style: context.text.labelSmall?.copyWith(height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModelDropdown extends StatelessWidget {
  const _ModelDropdown({
    required this.models,
    required this.query,
    required this.current,
    required this.onSelected,
  });

  final List<String> models;
  final String query;
  final String current;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final search = query.trim().toLowerCase();
    final filtered = search.isEmpty
        ? models
        : models.where((m) => m.toLowerCase().contains(search)).toList();
    final visible = filtered.take(120).toList();
    final value = visible.contains(current)
        ? current
        : (models.contains(current) ? current : null);
    final items = <String>{...visible, if (value != null) value}.toList();
    return DropdownButtonFormField<String>(
      key: ValueKey('$value|${items.length}'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Modelos disponíveis (${filtered.length}/${models.length})',
      ),
      items: [
        for (final model in items)
          DropdownMenuItem(
            value: model,
            child: Text(model, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (value) {
        if (value != null) onSelected(value);
      },
    );
  }
}
