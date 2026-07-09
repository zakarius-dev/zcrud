/// Modèle d'état de chargement de liste du domaine `zcrud_core`.
///
/// origine: lex_core (module « Étude ») — `DataState` (loading/data/empty/error)
/// dérivé côté présentation. Canonique §7 ; AD-4 (`sealed` intra-package) ;
/// AD-11 (flux nu → l'état est **dérivé**, jamais retourné par le repository).
///
/// **Décision de nommage (finding readiness #15)** : `DataState` → `ZDataState`.
library;

import '../failures/z_failure.dart';
import 'z_cursor.dart';

/// État **fermé** d'un chargement de liste, dérivé par la présentation/le
/// controller à partir du flux **nu** (`Stream<List<T>>`) et de l'`Either`
/// des opérations.
///
/// **`sealed`** (et non `abstract`) : l'ensemble des 4 états est **fermé** et
/// **intra-package** ; un `switch` exhaustif compile **sans branche `default`**
/// (atout pour l'UI). À l'inverse `ZFailure` est `abstract`/**ouvert** car
/// l'extension inter-package y est requise (AD-4). Un satellite n'ajoute jamais
/// un 5ᵉ état de chargement.
///
/// `ZDataState` **n'est jamais** un type de retour de `ZRepository` : le contrat
/// expose des flux **nus** (AD-11) ; la dérivation en état UI relève de la
/// présentation. Neutre : pur-Dart, zéro Flutter.
sealed class ZDataState<T> {
  /// Constructeur `const` de base (sous-classes immuables).
  const ZDataState();
}

/// Chargement en cours (aucune donnée encore disponible).
final class ZDataLoading<T> extends ZDataState<T> {
  /// Construit l'état de chargement.
  const ZDataLoading();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZDataLoading<T> && runtimeType == other.runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'ZDataLoading<$T>()';
}

/// Données chargées et **non vides**.
///
/// [nextCursor] (produit par l'impl) alimente `ZDataRequest.startAfter` pour la
/// page suivante ; [hasMore] indique qu'une page supplémentaire existe.
final class ZDataLoaded<T> extends ZDataState<T> {
  /// Construit l'état chargé avec ses [items] et sa pagination optionnelle.
  const ZDataLoaded({
    required this.items,
    this.nextCursor,
    this.hasMore = false,
  });

  /// Éléments chargés (non vide par convention — sinon [ZDataEmpty]).
  final List<T> items;

  /// Curseur de la page suivante, ou `null` (pas de suivante connue).
  final ZCursor? nextCursor;

  /// `true` si une page supplémentaire est disponible.
  final bool hasMore;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZDataLoaded<T> &&
          runtimeType == other.runtimeType &&
          hasMore == other.hasMore &&
          nextCursor == other.nextCursor &&
          _listEquals(items, other.items);

  @override
  int get hashCode =>
      Object.hash(runtimeType, Object.hashAll(items), nextCursor, hasMore);

  @override
  String toString() =>
      'ZDataLoaded<$T>(items: ${items.length}, hasMore: $hasMore, '
      'nextCursor: $nextCursor)';
}

/// Chargement **terminé mais vide** — distinct de [ZDataLoading].
final class ZDataEmpty<T> extends ZDataState<T> {
  /// Construit l'état vide.
  const ZDataEmpty();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZDataEmpty<T> && runtimeType == other.runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'ZDataEmpty<$T>()';
}

/// Échec de chargement, portant la [failure] domaine (AD-11).
final class ZDataError<T> extends ZDataState<T> {
  /// Construit l'état d'erreur avec sa [failure].
  const ZDataError(this.failure);

  /// Cause de l'échec (hiérarchie `ZFailure`, E2-1).
  final ZFailure failure;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZDataError<T> &&
          runtimeType == other.runtimeType &&
          failure == other.failure;

  @override
  int get hashCode => Object.hash(runtimeType, failure);

  @override
  String toString() => 'ZDataError<$T>($failure)';
}

/// Égalité **profonde** de deux listes (élément par élément), en pur-Dart.
///
/// Interne : évite `package:collection` dans le cœur (AD-1, out-degree 0).
bool _listEquals(List<Object?> a, List<Object?> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
