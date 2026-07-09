/// Curseur de pagination **opaque et neutre** du domaine `zcrud_core`.
///
/// origine: lex_core (module « Étude ») — pagination `startAfter` des repositories
/// (`data_request` / `streamByContainer`). Canonique §7 ; AD-16 (curseur neutre,
/// résout OQ-9) ; AD-5 (backend-agnostique).
library;

/// Curseur de pagination **opaque** : ancre de reprise d'une page.
///
/// `ZCursor` est **neutre** — il ne porte **aucun** type backend
/// (`DocumentSnapshot`/`Timestamp`/…). Il capture seulement :
/// - [values] : les valeurs des **clés d'ordre** (`ZDataRequest.sorts`) de
///   l'élément d'ancrage (dernier élément de la page précédente), alignées
///   positionnellement sur les `sorts` de la requête ;
/// - [id] : l'identité stable de l'élément d'ancrage, utilisée comme clé de
///   **départage** (deux éléments de mêmes clés d'ordre) et comme ancre du
///   repli in-memory.
///
/// **Double mapping** (implémenté en E5, jamais ici) :
/// - **Firestore** → `query.orderBy(...).startAfter(cursor.values).limit(n)` :
///   l'adaptateur reconstitue `startAfter` depuis [values] ; aucun
///   `DocumentSnapshot` ne traverse le port.
/// - **Repli in-memory** (AD-16, « repli in-memory documenté ») → filtrer, trier
///   selon `sorts`, **sauter** toutes les lignes situées avant l'ancre dans
///   l'ordre courant — comparaison positionnelle par [values] (valeurs des clés
///   d'ordre), [id] servant **uniquement** de départage à valeurs d'ordre
///   égales — puis prendre `limit`. Le saut ne dépend **pas** de la présence de
///   [id] (`id: null` légitime : pagination pilotée par [values] seules) ; un
///   curseur invalide (ancre inexistante) ne plante jamais (page vide au-delà de
///   la fin, départ complet avant le début). Un backend sans curseur natif reste
///   paginable sans crash.
///
/// Le consommateur (liste E4-3) obtient le prochain curseur via
/// `ZDataLoaded.nextCursor` et le repasse dans `ZDataRequest.startAfter` — boucle
/// fermée **sans** jamais construire ni relire un type backend.
class ZCursor {
  /// Construit un curseur opaque à partir des [values] de clés d'ordre et de
  /// l'[id] d'ancrage optionnel.
  const ZCursor({required this.values, this.id});

  /// Valeurs des clés d'ordre de l'élément d'ancrage, alignées sur
  /// `ZDataRequest.sorts`. Opaques : aucun type backend.
  final List<Object?> values;

  /// Identité stable de l'ancre (départage / repli in-memory), ou `null`.
  final String? id;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZCursor &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          _listEquals(values, other.values);

  @override
  int get hashCode => Object.hash(runtimeType, id, Object.hashAll(values));

  @override
  String toString() => 'ZCursor(values: $values, id: $id)';
}

/// Égalité **profonde** de deux listes (élément par élément), en pur-Dart.
///
/// Interne : évite de tirer `package:collection` dans le cœur (AD-1, out-degree 0).
bool _listEquals(List<Object?> a, List<Object?> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
