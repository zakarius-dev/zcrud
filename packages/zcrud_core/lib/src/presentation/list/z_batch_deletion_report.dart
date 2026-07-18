/// Rapport **au grain de la racine** d'une opération de lot (me-1, AD-39/AD-10).
///
/// origine: leçon E-STUDY-UI « lot silencieusement partiel = perte de données
/// non anticipée » (su-3/su-7). AD-39 exige que toute suppression persistée soit
/// **`await`ée** et que l'appelant reçoive **toujours** la liste des racines
/// échouées — jamais un succès global masquant un échec par racine.
///
/// **Value object immuable** (couche présentation ; imports limités à
/// `package:flutter/foundation.dart` — `setEquals`/`mapEquals` — + types
/// `zcrud_core`). Égalité de **valeur** par contenu (utile aux tests porteurs qui
/// assèrent QUELLES racines ont réussi/échoué, pas seulement « rien n'a levé »).
///
/// **Générique par contrat** (T3/T4/T5) : ce même contour (racines réussies +
/// `Map<rootId, ZFailure>` échouées) est réutilisé par la suppression
/// (`batchDelete`), le déplacement (`batchMove`) et l'édition de champ commun
/// (`applyCommonField`) — une seule forme de rapport. Le type est nommé
/// [ZBatchReport] ; l'alias historique [ZBatchDeletionReport] (nom demandé par la
/// story me-1) le désigne à l'identique.
///
/// **CORE OUT=0 (AD-1)** : aucune dépendance zcrud/tierce. La **cascade** (AD-21,
/// borne ≤ 450) et le chemin d'écriture physique sont des propriétés de
/// l'**implémentation injectée** (`zcrud_study_kernel`/`zcrud_firestore`), jamais
/// de ce rapport ni du cœur.
library;

import 'package:flutter/foundation.dart';

import '../../domain/failures/z_failure.dart';

/// Rapport au grain de la racine d'une opération de lot (AD-39).
///
/// - [succeededRootIds] : `id` racines dont l'opération a réussi (`Right`) ;
/// - [failures] : `id` racine → [ZFailure] pour chaque racine échouée (`Left` ou
///   `throw` capté, AD-10). Une racine est **soit** dans [succeededRootIds]
///   **soit** dans [failures], jamais les deux.
///
/// Les collections exposées sont **non modifiables**.
@immutable
class ZBatchReport {
  /// Construit un rapport à partir de racines réussies et échouées. Les
  /// collections sont copiées en versions **non modifiables**.
  ZBatchReport({
    required Set<String> succeededRootIds,
    required Map<String, ZFailure> failures,
  })  : succeededRootIds = Set<String>.unmodifiable(succeededRootIds),
        failures = Map<String, ZFailure>.unmodifiable(failures);

  /// Rapport vide (aucune racine traitée — ex. sélection vide, `dispose`).
  ZBatchReport.empty()
      : succeededRootIds = const <String>{},
        failures = const <String, ZFailure>{};

  /// `id` racines dont l'opération a réussi (non modifiable).
  final Set<String> succeededRootIds;

  /// `id` racine → cause d'échec [ZFailure] (non modifiable).
  final Map<String, ZFailure> failures;

  /// `true` s'il existe **au moins une** racine échouée (AD-39 : l'appelant ne
  /// doit jamais présumer un succès global).
  bool get hasFailures => failures.isNotEmpty;

  /// Nombre de racines réussies.
  int get succeededCount => succeededRootIds.length;

  /// Nombre de racines échouées.
  int get failedCount => failures.length;

  /// `id` racines échouées (clés de [failures]), non modifiable.
  Set<String> get failedRootIds => Set<String>.unmodifiable(failures.keys);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZBatchReport &&
          runtimeType == other.runtimeType &&
          setEquals(succeededRootIds, other.succeededRootIds) &&
          mapEquals(failures, other.failures);

  @override
  int get hashCode => Object.hash(
        runtimeType,
        Object.hashAllUnordered(succeededRootIds),
        Object.hashAllUnordered(
          failures.entries.map((e) => Object.hash(e.key, e.value)),
        ),
      );

  @override
  String toString() =>
      'ZBatchReport(succeeded: $succeededRootIds, failures: $failures)';
}

/// Alias historique du rapport de lot pour la **suppression** (nom demandé par
/// la story me-1, T3). Désigne [ZBatchReport] à l'identique — le contour du
/// rapport (racines réussies + `Map<rootId, ZFailure>`) est **générique** et
/// réutilisé aussi par `batchMove`/`applyCommonField` (T4/T5).
typedef ZBatchDeletionReport = ZBatchReport;
