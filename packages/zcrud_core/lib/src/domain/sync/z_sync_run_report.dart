/// Rapport agrégé **neutre** d'un cycle de synchronisation orchestré (E5-4).
///
/// origine: canonique §7 — `ZSyncOrchestrator` best-effort (« un échec n'arrête
/// pas les autres »). Ce value object rend l'**échec partiel** d'un cycle
/// **visible et testable** : plutôt qu'un `Left` global (best-effort intégral,
/// AD-9), un cycle renvoie `Right(ZSyncRunReport)` où les échecs sont **comptés**
/// (`failed`) et **collectés** (`failures`) — jamais noyés silencieusement (AD-11).
///
/// **Backend-agnostique (AD-5)** : aucun champ n'expose de type `hive`/
/// `cloud_firestore`/gestionnaire d'état ; seuls des primitifs et des [ZFailure]
/// **neutres** du domaine.
library;

import '../failures/z_failure.dart';

/// Résultat **immuable** d'un cycle de synchronisation best-effort exécuté par
/// `ZSyncOrchestrator`.
///
/// Invariant : `attempted == succeeded + failed`. Un cycle **sauté** (gate
/// désactivé, hors-ligne, registre vide) est représenté par [ZSyncRunReport.empty]
/// (`attempted == 0`).
///
/// **Pur-Dart** (AD-5) : aucune dépendance Flutter/backend — l'égalité de liste
/// est implémentée localement ([_listEquals]) pour ne pas importer `foundation`.
class ZSyncRunReport {
  /// Construit un rapport ; l'invariant `attempted == succeeded + failed` est
  /// vérifié par assertion (mode debug).
  const ZSyncRunReport({
    required this.attempted,
    required this.succeeded,
    required this.failed,
    this.failures = const <ZFailure>[],
  }) : assert(
          attempted == succeeded + failed,
          'attempted doit égaler succeeded + failed',
        );

  /// Rapport d'un cycle **sans aucune tentative** (cycle sauté : gate off,
  /// hors-ligne, ou registre vide). `attempted == succeeded == failed == 0`.
  const ZSyncRunReport.empty()
      : attempted = 0,
        succeeded = 0,
        failed = 0,
        failures = const <ZFailure>[];

  /// Nombre de dépôts pour lesquels `sync()` a été **tenté** dans ce cycle.
  final int attempted;

  /// Nombre de `sync()` ayant **réussi** (`Right`).
  final int succeeded;

  /// Nombre de `sync()` ayant **échoué** (`Left(ZFailure)` **ou** exception).
  final int failed;

  /// Failures **collectées** durant le cycle (neutres). Les exceptions brutes
  /// (non-`ZFailure`) sont comptées dans [failed] et loggées, mais ne figurent
  /// pas dans cette liste (seuls des [ZFailure] typés y sont agrégés).
  final List<ZFailure> failures;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZSyncRunReport &&
          runtimeType == other.runtimeType &&
          attempted == other.attempted &&
          succeeded == other.succeeded &&
          failed == other.failed &&
          _listEquals(failures, other.failures);

  @override
  int get hashCode =>
      Object.hash(runtimeType, attempted, succeeded, failed,
          Object.hashAll(failures));

  @override
  String toString() =>
      'ZSyncRunReport(attempted: $attempted, succeeded: $succeeded, '
      'failed: $failed, failures: $failures)';
}

/// Égalité ordonnée de deux listes de [ZFailure] (évite d'importer `foundation`).
bool _listEquals(List<ZFailure> a, List<ZFailure> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
