/// **ES-3.4 (FR-S15 / AD-20 / AD-9)** — fabrique de **câblage** de l'orchestrateur
/// de synchronisation d'étude : le **remplaçant neutre et portable** de
/// `lex_data/data/services/study_sync_manager.dart`.
///
/// **Le doublon éradiqué.** `study_sync_manager.dart` (lex) codait **en dur** 11
/// imports de `*_repository_impl.dart` (l.9-19) et une liste `_syncAll` de 11
/// lambdas (l.98-112) — *« ajouter un dépôt = éditer cette liste »*, couplée à
/// `@Riverpod`/`firebase_auth`/`connectivity_plus`. Cette fabrique supprime ce
/// couplage : la **liste des dépôts vient d'une INJECTION** (paramètre
/// [repositories]), jamais d'imports/d'une liste codés en dur. Ajouter un dépôt =
/// **passer une liste plus longue à l'appel**, jamais éditer ce fichier.
///
/// **AD-4 (compose, ne duplique pas).** Toute la mécanique du **quand** (registre,
/// débounce ~400 ms, coalescence, best-effort tolérant à l'échec partiel, gate
/// [ZSyncOrchestrator.enabled], couture [isConnected], `dispose` **non-propriétaire**)
/// est **déjà** livrée par `ZSyncOrchestrator` (E5-4, `zcrud_core`). Cette fabrique
/// **compose** : elle construit l'orchestrateur, lui injecte la liste via
/// [ZSyncOrchestrator.registerAll], et retourne l'instance. Elle **ne détient
/// AUCUN état** (ce n'est pas une classe/mini-orchestrateur concurrent).
///
/// **AD-15 (isolation gestionnaire d'état).** Aucun import Riverpod / GetX /
/// provider / `firebase_auth` / `connectivity_plus` : login/reconnexion sont
/// pilotés par **l'app** qui appelle [ZSyncOrchestrator.onLogin] /
/// [ZSyncOrchestrator.onReconnected] sur ses vraies sources ; la connectivité est
/// une **couture** [isConnected] `Future<bool> Function()?` (déjà offerte par E5-4).
///
/// **AD-5/AD-11 (signatures nues).** Aucun type backend (`cloud_firestore`/`hive`)
/// n'apparaît en signature : entrées = `Iterable<ZSyncableRepository<dynamic>>` +
/// coutures du cœur ([Duration], [ZSyncTimerFactory], `Future<bool> Function()?`,
/// [bool], [ZSyncOrchestratorLog]) ; sortie = [ZSyncOrchestrator] (type du cœur).
library;

import 'package:zcrud_core/zcrud_core.dart';

/// Assemble un [ZSyncOrchestrator] (E5-4) à partir d'une **liste injectée** de
/// dépôts synchronisables — best-effort, débouncé ~400 ms — sans coder en dur
/// aucun repo (remplaçant portable de `study_sync_manager.dart`).
///
/// - [repositories] : **LISTE INJECTÉE** par l'app (ses `ZOfflineFirstBoxRepository`
///   flat IFFD *et* nested lex, transitivement des [ZSyncableRepository]). C'est la
///   **seule** source de dépôts — aucun n'est importé/construit ici.
/// - [debounce] : fenêtre de coalescence (défaut [kZSyncDefaultDebounce] = 400 ms).
/// - [timerFactory] : couture de fabrique de timer (test → fake clock).
/// - [isConnected] : couture de connectivité de l'app (défaut `null`).
/// - [enabled] : gate d'activation (défaut `true`).
/// - [logger] : journal neutre (défaut no-op côté cœur).
///
/// L'app câble ensuite ses transitions login/réseau sur
/// [ZSyncOrchestrator.onLogin] / [ZSyncOrchestrator.onReconnected] et **possède**
/// le cycle de vie des dépôts injectés (l'orchestrateur ne les `dispose` pas).
ZSyncOrchestrator assembleZStudySyncOrchestrator({
  required Iterable<ZSyncableRepository<dynamic>> repositories,
  Duration debounce = kZSyncDefaultDebounce,
  ZSyncTimerFactory? timerFactory,
  Future<bool> Function()? isConnected,
  bool enabled = true,
  ZSyncOrchestratorLog? logger,
}) {
  final orchestrator = ZSyncOrchestrator(
    debounce: debounce,
    timerFactory: timerFactory,
    isConnected: isConnected,
    enabled: enabled,
    logger: logger,
  );
  orchestrator.registerAll(repositories);
  return orchestrator;
}
