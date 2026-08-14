/// `ZItemFilter` — **post-filtre** d'un listing, déclaré par l'écran et écrit
/// sur l'entité typée.
///
/// Un listing dérive son périmètre de sa requête : filtres permanents, portée
/// de corbeille, catégorie d'onglet. Tant que la règle du métier s'exprime en
/// clauses, cela suffit. Mais le dernier mot sur ce qui est montré appartient
/// souvent au métier, et s'exprime alors **en Dart** : un croisement de droits,
/// une fenêtre de dates calculée, une catégorie qui n'existe pas en base. Une
/// source qui ne sait pas dire cette règle laisse deux issues — élargir ce que
/// voit l'usager, ou renoncer au listing dérivé.
///
/// Ce type est la troisième : l'écran déclare un prédicat, le socle l'applique
/// **sur les entités lues**, avant qu'elles ne deviennent des lignes.
library;

import 'package:flutter/foundation.dart';

/// Prédicat **d'écran** retenant ou écartant une entité du listing, écrit sur
/// le type de l'entité.
///
/// ## L'écrire
///
/// ```dart
/// ZItemFilter.of<Dossier>((dossier) => dossier.habilitations.contains(agent))
/// // …ou, le type venant du paramètre :
/// ZItemFilter.of((Dossier dossier) => dossier.echeance.isAfter(debut))
/// ```
///
/// Le prédicat reçoit **l'entité**, jamais la ligne rendue : la règle se lit
/// dans le vocabulaire du domaine, et renommer un champ devient une erreur de
/// compilation plutôt qu'un listing qui se met silencieusement à tout montrer.
///
/// ## Ce qu'il fait, et ce qu'il ne fait jamais
///
/// * Il **restreint** : le listing montre au plus ce qu'il montrait sans lui.
///   Aucune entité que la requête n'a pas ramenée ne peut réapparaître.
/// * Il ne remplace **rien** : filtres permanents, catégorie d'onglet, portée
///   de corbeille et gouvernance par ligne continuent de s'appliquer.
/// * Il s'applique **avant la pagination** : une page pleine reste une page
///   pleine, jamais une page trouée par un filtrage appliqué après coup.
///
/// ## Ce qu'il coûte
///
/// Un prédicat Dart ne se traduit dans aucun langage de requête : le socle ne
/// peut l'appliquer que sur des entités **déjà lues**. Déclarer un post-filtre
/// impose donc au listing la **voie mémoire** — le jeu est lu en entier à
/// chaque requête, puis filtré, trié et paginé par le socle. C'est le prix de
/// l'exactitude, et il n'est raisonnable que sur un listing borné (quelques
/// milliers de lignes).
///
/// **Quand ne PAS en déclarer** : quand la règle est exprimable en clauses. Un
/// `ZFilter` permanent — ou une disjonction `ZFilterGroup` pour « cette valeur
/// ou ce champ absent » — reste servi par la source, garde la pagination
/// curseur et ne lit que la page affichée. Le post-filtre est la voie de ce qui
/// n'est **pas** requêtable, pas un raccourci d'écriture.
///
/// ## Le déclarer hors du `build`
///
/// Deux politiques d'écran sont comparées par valeur, et deux post-filtres ne
/// sont égaux que si leurs prédicats le sont. Une **fonction nommée** (méthode,
/// fonction de haut niveau) reste égale à elle-même d'une reconstruction à
/// l'autre ; une **lambda écrite dans `build`** est une nouvelle fonction à
/// chaque image, et le listing se reconstruirait à chaque fois. Déclarez le
/// prédicat une fois, à côté de l'écran.
@immutable
class ZItemFilter {
  const ZItemFilter._(this._keeps, this._parts);

  /// Déclare un post-filtre à partir d'un prédicat écrit sur l'entité [T].
  ///
  /// [T] se déduit du paramètre du prédicat (`(Dossier d) => …`) ou s'écrit
  /// explicitement (`ZItemFilter.of<Dossier>(…)`).
  static ZItemFilter of<T>(bool Function(T entity) test) => ZItemFilter._(
        (Object? entity) {
          if (entity is T) return test(entity);
          // Post-filtre déclaré sur un autre type que celui du listing : le
          // prédicat ne peut rien affirmer sur cette entité. Elle est écartée
          // — un listing vide se voit, là où un listing élargi passe pour
          // normal. L'assertion nomme la faute en développement.
          assert(
            false,
            'ZItemFilter.of<$T> reçoit une entité ${entity.runtimeType} : le '
            'post-filtre est déclaré sur un autre type que celui du listing.',
          );
          return false;
        },
        <Object>[test],
      );

  /// Post-filtre composé : une entité n'est retenue que si **tous** les
  /// [filters] la retiennent (conjonction).
  ///
  /// C'est la règle de composition des niveaux — écran, puis onglet : chaque
  /// niveau ne peut que **retirer**, jamais rendre ce qu'un autre a écarté.
  /// Sans aucun filtre, la composition est `null` (rien de déclaré).
  static ZItemFilter? every(Iterable<ZItemFilter?> filters) {
    ZItemFilter? composed;
    for (final filter in filters) {
      if (filter == null) continue;
      composed = composed == null ? filter : composed.and(filter);
    }
    return composed;
  }

  final bool Function(Object? entity) _keeps;

  /// Prédicats sources, dans l'ordre de composition — porte l'égalité.
  final List<Object> _parts;

  /// `true` si [entity] est **retenue** dans le listing.
  bool keeps(Object? entity) => _keeps(entity);

  /// Post-filtre retenant ce que celui-ci **et** [other] retiennent.
  ZItemFilter and(ZItemFilter other) => ZItemFilter._(
        (Object? entity) => _keeps(entity) && other._keeps(entity),
        <Object>[..._parts, ...other._parts],
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZItemFilter &&
          runtimeType == other.runtimeType &&
          _sameParts(_parts, other._parts);

  @override
  int get hashCode => Object.hash(runtimeType, Object.hashAll(_parts));

  @override
  String toString() => 'ZItemFilter(${_parts.length})';
}

/// Égalité des prédicats sources, un à un (identité de fonction).
bool _sameParts(List<Object> a, List<Object> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
