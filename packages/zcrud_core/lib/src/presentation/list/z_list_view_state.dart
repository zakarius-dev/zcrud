/// État de **vue** de `DynamicList` (E4-2, AD-11/AD-13).
///
/// origine: E4-2. Pendant **présentation** de `ZDataState` (domaine, AD-11) :
/// `ZListViewState` porte des `ZListRow` déjà **projetées** (pas de générécité
/// `T`) et ajoute l'état `noResults` (« aucun résultat **après filtre** ») que
/// `ZDataState` n'a pas — c'est une distinction **UI**, pas domaine (on ne
/// pollue donc pas `ZDataState`). Le mapping `ZDataState → ZListViewState` (dont
/// le choix `empty` vs `noResults` selon qu'un filtre est actif) est câblé par le
/// controller d'**E4-3** ; E4-2 fournit seulement les états distincts + leur
/// rendu accessible.
///
/// **Neutre, pur-données** : imports limités à `ZFailure` + `ZListRow` (contrat
/// neutre). AUCUN widget, AUCUN `package:syncfusion`.
library;

import '../../domain/failures/z_failure.dart';
import 'z_list_render_request.dart';

/// État **fermé** de la vue de liste (E4-2). `sealed` : le `switch` de rendu de
/// `DynamicList` est exhaustif sans branche `default`.
sealed class ZListViewState {
  /// Constructeur `const` de base.
  const ZListViewState();
}

/// Chargement en cours (aucune donnée encore disponible). Rendu : indicateur de
/// progression + `Semantics(liveRegion: true)`.
final class ZListLoading extends ZListViewState {
  /// Construit l'état de chargement.
  const ZListLoading();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZListLoading && runtimeType == other.runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'ZListLoading()';
}

/// Chargement terminé, **aucune donnée** (jeu vide, hors filtre). **Distinct** de
/// [ZListNoResults].
final class ZListEmpty extends ZListViewState {
  /// Construit l'état vide.
  const ZListEmpty();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZListEmpty && runtimeType == other.runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'ZListEmpty()';
}

/// **Aucun résultat après filtre/recherche** — **distinct** d'[ZListEmpty]
/// (message différent). E4-2 rend cet état ; E4-3 le **décide** (mapping selon
/// qu'un filtre est actif).
final class ZListNoResults extends ZListViewState {
  /// Construit l'état « aucun résultat après filtre ».
  const ZListNoResults();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZListNoResults && runtimeType == other.runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'ZListNoResults()';
}

/// Échec de chargement, portant la [failure] domaine (AD-11). Rendu : message
/// dérivé de la `ZFailure` + `Semantics(liveRegion: true)` (erreur **annoncée**).
final class ZListError extends ZListViewState {
  /// Construit l'état d'erreur avec sa [failure].
  const ZListError(this.failure);

  /// Cause de l'échec (hiérarchie `ZFailure`).
  final ZFailure failure;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZListError &&
          runtimeType == other.runtimeType &&
          failure == other.failure;

  @override
  int get hashCode => Object.hash(runtimeType, failure);

  @override
  String toString() => 'ZListError($failure)';
}

/// Données prêtes à afficher : porte les [rows] projetées. `DynamicList` dérive
/// alors les colonnes (`fromSchema`) et dispatche sur le `ZListLayout`.
final class ZListReady extends ZListViewState {
  /// Construit l'état prêt avec ses [rows].
  const ZListReady(this.rows);

  /// Lignes neutres à afficher (identité opaque + cellules brutes).
  final List<ZListRow> rows;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZListReady &&
          runtimeType == other.runtimeType &&
          _listEquals(rows, other.rows);

  @override
  int get hashCode => Object.hash(runtimeType, Object.hashAll(rows));

  @override
  String toString() => 'ZListReady(rows: ${rows.length})';
}

/// Égalité **profonde** de deux listes (élément par élément), pur-Dart (évite
/// `package:collection` — AD-1 out-degree 0).
bool _listEquals(List<Object?> a, List<Object?> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
