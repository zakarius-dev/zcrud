/// Fabrique de **câblage** de l'orchestrateur de synchronisation d'étude
/// (invariant AD-9) : un remplaçant neutre et portable d'une
/// implémentation applicative qui coderait ses dépôts en dur.
///
/// **Le doublon éradiqué.** Une implémentation applicative code souvent en
/// dur un import par dépôt et une liste de lambdas de synchronisation —
/// *« ajouter un dépôt = éditer cette liste »*, couplée à un gestionnaire
/// d'état et des dépendances de plateforme. Cette fabrique supprime ce
/// couplage : la **liste des dépôts vient d'une INJECTION** (paramètre
/// [repositories]), jamais d'imports/d'une liste codés en dur. Ajouter un dépôt =
/// **passer une liste plus longue à l'appel**, jamais éditer ce fichier.
///
/// **Composer, ne pas dupliquer (invariant AD-4).** Toute la mécanique du
/// **quand** (registre, débounce ~400 ms, coalescence, best-effort tolérant
/// à l'échec partiel, gate [ZSyncOrchestrator.enabled], couture
/// [isConnected], `dispose` **non-propriétaire**) est **déjà** livrée par
/// `ZSyncOrchestrator` (`zcrud_core`). Cette fabrique **compose** : elle
/// construit l'orchestrateur, lui injecte la liste via
/// [ZSyncOrchestrator.registerAll], et retourne l'instance. Elle **ne détient
/// AUCUN état** (ce n'est pas une classe/mini-orchestrateur concurrent).
///
/// **Isolation gestionnaire d'état (invariant AD-15).** Aucun import
/// Riverpod / GetX / provider / dépendance d'authentification ou de
/// connectivité : login/reconnexion sont pilotés par **l'application** qui
/// appelle [ZSyncOrchestrator.onLogin] / [ZSyncOrchestrator.onReconnected]
/// sur ses vraies sources ; la connectivité est une **couture** [isConnected]
/// `Future<bool> Function()?`.
///
/// **Signatures nues (invariants AD-5/AD-11).** Aucun type backend
/// (`cloud_firestore`/`hive`) n'apparaît en signature : entrées =
/// `Iterable<ZSyncableRepository<dynamic>>` + coutures du cœur ([Duration],
/// [ZSyncTimerFactory], `Future<bool> Function()?`, [bool],
/// [ZSyncOrchestratorLog]) ; sortie = [ZSyncOrchestrator] (type du cœur).
library;

import 'package:zcrud_core/zcrud_core.dart';

/// Assemble un [ZSyncOrchestrator] à partir d'une **liste injectée** de
/// dépôts synchronisables — best-effort, débouncé ~400 ms — sans coder en dur
/// aucun repo.
///
/// - [repositories] : **LISTE INJECTÉE** par l'app (ses `ZOfflineFirstBoxRepository`
///   flat *et* nested, transitivement des [ZSyncableRepository]). C'est la
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
