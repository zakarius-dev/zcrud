// Fake `ZAppFileResolver` — résolution de RÉFÉRENCES opaques de fichiers,
// pilotable par test (succès / référence introuvable / `Exception` / `Error` /
// `Future` qui ne se termine JAMAIS), sans aucune dépendance lourde.
import 'dart:async';

import 'package:zcrud_core/zcrud_core.dart';

/// Comportement d'échec simulé par [FakeAppFileResolver].
enum FakeResolveFailure {
  /// Aucun échec : renvoie [FakeAppFileResolver.files].
  none,

  /// Lève une `Exception` — l'échec **NORMAL** d'une E/S (un `on Error` seul la
  /// laisserait remonter : c'est l'incident mesuré que la garde doit couvrir).
  exception,

  /// Lève une `Error` (bug de programmation).
  error,

  /// Lève **synchroniquement**, avant même de rendre un `Future`.
  syncThrow,

  /// Rend un `Future` qui ne se termine **JAMAIS** (seul le délai de garde
  /// peut débloquer le champ).
  never,

  /// Rend un `Future` complété **à la demande du test**
  /// ([FakeAppFileResolver.completeDeferred]) — permet d'observer l'arbre
  /// AVANT et APRÈS l'arrivée de la réponse (preuve SM-1).
  deferred,
}

/// Fake déterministe du port de résolution de références.
class FakeAppFileResolver implements ZAppFileResolver {
  FakeAppFileResolver({
    this.files = const <AppFile>[],
    this.failure = FakeResolveFailure.none,
    this.timeout = const Duration(seconds: 5),
  });

  /// Fichiers renvoyés (appariés par `AppFile.id` == référence demandée).
  List<AppFile> files;

  /// Échec simulé.
  FakeResolveFailure failure;

  /// Délai de garde exposé au consommateur.
  @override
  Duration timeout;

  /// Références demandées, appel par appel (oracle de non-redemande).
  final List<List<String>> calls = <List<String>>[];

  /// Nombre d'appels à [resolve].
  int get callCount => calls.length;

  final List<Completer<List<AppFile>>> _deferred =
      <Completer<List<AppFile>>>[];

  /// Complète les résolutions en attente (mode [FakeResolveFailure.deferred]).
  void completeDeferred() {
    for (final c in _deferred) {
      if (!c.isCompleted) c.complete(files);
    }
    _deferred.clear();
  }

  @override
  Future<List<AppFile>> resolve(List<String> refs) {
    calls.add(List<String>.unmodifiable(refs));
    switch (failure) {
      case FakeResolveFailure.syncThrow:
        throw StateError('résolveur défaillant (throw synchrone)');
      case FakeResolveFailure.exception:
        return Future<List<AppFile>>.error(
          const FormatException('échec réseau simulé'),
        );
      case FakeResolveFailure.error:
        return Future<List<AppFile>>.error(StateError('bug simulé'));
      case FakeResolveFailure.never:
        return Completer<List<AppFile>>().future;
      case FakeResolveFailure.deferred:
        final c = Completer<List<AppFile>>();
        _deferred.add(c);
        return c.future;
      case FakeResolveFailure.none:
        return Future<List<AppFile>>.value(files);
    }
  }
}

/// Fabrique un `AppFile` **distant** (déjà uploadé) d'id [id].
AppFile fakeResolvedFile({
  required String id,
  String name = 'doc.pdf',
  String mime = 'application/pdf',
}) =>
    AppFile(
      id: id,
      name: name,
      mimeType: mime,
      remoteUrl: 'memory://$id',
      uploadState: ZAppFileUploadState.uploaded,
    );
