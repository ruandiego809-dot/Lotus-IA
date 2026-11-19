// ignore_for_file: deprecated_member_use
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_localizations_pt.dart' as pt;
import 'app_localizations_en.dart' as en;

/// Lookup de strings traduzidas. Instância por BuildContext via [of].
class AppLocalizations {
  AppLocalizations(this.localeName);

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  // Todas as chaves disponíveis
  static final Map<String, Map<String, String>> _localizedValues = {
    'en': en.values,
    'pt': pt.values,
  };

  String _resolve(String key) {
    return _localizedValues[localeName]?[key] ??
        _localizedValues['en']?[key] ??
        key;
  }

  // ---- Chat ----
  String get welcomeTitle => _resolve('welcomeTitle');
  String get welcomeSubtitle => _resolve('welcomeSubtitle');
  String get newConversation => _resolve('newConversation');
  String get history => _resolve('history');
  String get rename => _resolve('rename');
  String get systemPrompt => _resolve('systemPrompt');
  String get export => _resolve('export');
  String get clearMessages => _resolve('clearMessages');
  String get messagesCount => _resolve('messagesCount');
  String get intelligenceCenter => _resolve('intelligenceCenter');
  String get adjustProviders => _resolve('adjustProviders');
  String get hintWrite => _resolve('hintWrite');
  String get hintGenerate => _resolve('hintGenerate');
  String get attach => _resolve('attach');
  String get sendMessage => _resolve('sendMessage');
  String get stopGeneration => _resolve('stopGeneration');
  String get thinking => _resolve('thinking');
  String get noContent => _resolve('noContent');
  String get copied => _resolve('copied');
  String get errorProvider => _resolve('errorProvider');
  String get conversationHistory => _resolve('conversationHistory');
  String get conversationsSaved => _resolve('conversationsSaved');
  String get searchHistory => _resolve('searchHistory');
  String get noResults => _resolve('noResults');
  String get noConversations => _resolve('noConversations');
  String get today => _resolve('today');
  String get yesterday => _resolve('yesterday');
  String get deleteConversation => _resolve('deleteConversation');
  String get deleteConversationMsg => _resolve('deleteConversationMsg');
  String get delete => _resolve('delete');
  String get cancel => _resolve('cancel');
  String get confirm => _resolve('confirm');
  String get provider => _resolve('provider');
  String get model => _resolve('model');
  String get chooseProvider => _resolve('chooseProvider');
  String get noProvider => _resolve('noProvider');
  String get noModels => _resolve('noModels');
  String get manageProviders => _resolve('manageProviders');
  String get tokensMonitor => _resolve('tokensMonitor');
  String get tokensEstimated => _resolve('tokensEstimated');
  String get tokensReal => _resolve('tokensReal');
  String get tokensLimit => _resolve('tokensLimit');
  String get tokensUsage => _resolve('tokensUsage');
  String get tokensRemaining => _resolve('tokensRemaining');
  String get tokensNoLimit => _resolve('tokensNoLimit');
  String get tokensContextWarning => _resolve('tokensContextWarning');
  String get tokensContextWarningHigh => _resolve('tokensContextWarningHigh');
  String get tokensCreditsNote => _resolve('tokensCreditsNote');
  String get saved => _resolve('saved');
  String get notSaved => _resolve('notSaved');
  String get lines => _resolve('lines');
  String get characters => _resolve('characters');
  String get archive => _resolve('archive');
  String get unarchive => _resolve('unarchive');
  String get archiveConversation => _resolve('archiveConversation');
  String get exportConversation => _resolve('exportConversation');
  String get importConversation => _resolve('importConversation');

  // ---- Ajustes ----
  String get settingsTitle => _resolve('settingsTitle');
  String get settingsSubtitle => _resolve('settingsSubtitle');
  String get appearance => _resolve('appearance');
  String get data => _resolve('data');
  String get providers => _resolve('providers');
  String get modulesStatus => _resolve('modulesStatus');
  String get exportSettings => _resolve('exportSettings');
  String get exportSettingsSub => _resolve('exportSettingsSub');
  String get importSettings => _resolve('importSettings');
  String get importSettingsSub => _resolve('importSettingsSub');
  String get activeProviders => _resolve('activeProviders');
  String get providerNotConfigured => _resolve('providerNotConfigured');
  String get saveProvider => _resolve('saveProvider');
  String get testConnection => _resolve('testConnection');
  String get apiKey => _resolve('apiKey');
  String get apiKeyHelper => _resolve('apiKeyHelper');
  String get endpoint => _resolve('endpoint');
  String get modelId => _resolve('modelId');
  String get contextLimit => _resolve('contextLimit');
  String get contextLimitHelper => _resolve('contextLimitHelper');
  String get enableProvider => _resolve('enableProvider');
  String get enableProviderSub => _resolve('enableProviderSub');
  String get defaultProvider => _resolve('defaultProvider');
  String get defaultProviderSub => _resolve('defaultProviderSub');
  String get availableModels => _resolve('availableModels');
  String get searchingModels => _resolve('searchingModels');
  String get huggingfaceNote => _resolve('huggingfaceNote');

  // ---- Projetos ----
  String get projects => _resolve('projects');
  String get workspace => _resolve('workspace');
  String get items => _resolve('items');
  String get newProject => _resolve('newProject');
  String get newProjectMsg => _resolve('newProjectMsg');
  String get newFolder => _resolve('newFolder');
  String get newFile => _resolve('newFile');
  String get folder => _resolve('folder');
  String get file => _resolve('file');
  String get goBack => _resolve('goBack');
  String get refresh => _resolve('refresh');
  String get importZip => _resolve('importZip');
  String get exportZip => _resolve('exportZip');
  String get importGithub => _resolve('importGithub');
  String get scopeWorkspace => _resolve('scopeWorkspace');
  String get emptyFolder => _resolve('emptyFolder');
  String get emptyFolderMsg => _resolve('emptyFolderMsg');
  String get createProject => _resolve('createProject');
  String get errorReadingFolder => _resolve('errorReadingFolder');
  String get tryAgain => _resolve('tryAgain');
  String get createProjectTitle => _resolve('createProjectTitle');
  String get createProjectMsg => _resolve('createProjectMsg');
  String get renameItem => _resolve('renameItem');
  String get newName => _resolve('newName');
  String get deleteItem => _resolve('deleteItem');
  String get deleteItemMsg => _resolve('deleteItemMsg');
  String get deleteFolderMsg => _resolve('deleteFolderMsg');
  String get binaryFile => _resolve('binaryFile');
  String get binaryFileMsg => _resolve('binaryFileMsg');
  String get zipExported => _resolve('zipExported');
  String get zipExportedCaption => _resolve('zipExportedCaption');
  String get zipImported => _resolve('zipImported');
  String get importFailed => _resolve('importFailed');
  String get importGithubTitle => _resolve('importGithubTitle');
  String get importGithubMsg => _resolve('importGithubMsg');
  String get importGithubHint => _resolve('importGithubHint');
  String get importGithubConfirm => _resolve('importGithubConfirm');
  String get importGithubOk => _resolve('importGithubOk');
  String get invalidFormat => _resolve('invalidFormat');
  String get importFailedGeneric => _resolve('importFailedGeneric');
  String get scopeTitle => _resolve('scopeTitle');
  String get scopeBody => _resolve('scopeBody');

  // ---- Agentes ----
  String get agents => _resolve('agents');
  String get agentsSubtitle => _resolve('agentsSubtitle');
  String get collaborativeWork => _resolve('collaborativeWork');
  String get collaborativeWorkBody => _resolve('collaborativeWorkBody');
  String get realProvider => _resolve('realProvider');
  String get noSimulation => _resolve('noSimulation');

  // ---- Terminal ----
  String get terminal => _resolve('terminal');
  String get terminalSubtitle => _resolve('terminalSubtitle');
  String get sessions => _resolve('sessions');
  String get alpineSessions => _resolve('alpineSessions');
  String get newSession => _resolve('newSession');
  String get aiAuthorization => _resolve('aiAuthorization');
  String get terminalReal => _resolve('terminalReal');
  String get terminalRealMsg => _resolve('terminalRealMsg');
  String get newAlpineSession => _resolve('newAlpineSession');
  String get noSessions => _resolve('noSessions');
  String get noSessionsMsg => _resolve('noSessionsMsg');
  String get installing => _resolve('installing');
  String get starting => _resolve('starting');
  String get running => _resolve('running');
  String get errorLabel => _resolve('errorLabel');
  String get stoppedReady => _resolve('stoppedReady');
  String get stoppedNotReady => _resolve('stoppedNotReady');
  String get installAndStart => _resolve('installAndStart');
  String get start => _resolve('start');
  String get stop => _resolve('stop');
  String get preparingAlpine => _resolve('preparingAlpine');
  String get alpineNotInstalled => _resolve('alpineNotInstalled');
  String get installRootfsMsg => _resolve('installRootfsMsg');
  String get startSessionMsg => _resolve('startSessionMsg');
  String get sessionsCount => _resolve('sessionsCount');
  String get deleteSession => _resolve('deleteSession');
  String get deleteSessionMsg => _resolve('deleteSessionMsg');
  String get aiTerminalTitle => _resolve('aiTerminalTitle');
  String get aiTerminalBody => _resolve('aiTerminalBody');
  String get aiAllowed => _resolve('aiAllowed');
  String get aiBlocked => _resolve('aiBlocked');
  String get blockAi => _resolve('blockAi');
  String get allowAiWithConfirm => _resolve('allowAiWithConfirm');

  // ---- Erros / carregamento ----
  String get loadFailed => _resolve('loadFailed');
  String get loadFailedMsg => _resolve('loadFailedMsg');
  String get retry => _resolve('retry');
  String get appVersion => _resolve('appVersion');
  String get flutterLabel => _resolve('flutterLabel');

  String get suggestionsTitle => _resolve('suggestionsTitle');
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'pt'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return SynchronousFuture<AppLocalizations>(
      AppLocalizations(locale.languageCode),
    );
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
