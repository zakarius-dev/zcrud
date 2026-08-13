/// Utilitaires de **champs « chemin »** — pont entre un modèle **imbriqué**
/// (`{'vido': {'chef_equipe_poste_id': …}}`) et une édition **plate** (une
/// tranche par champ, clé pointée `'vido.chef_equipe_poste_id'`).
///
/// Un `ZFieldSpec.name` **pointé** est admis par le socle d'édition, qui le
/// traite comme une clé plate : l'aplatissement à l'ouverture
/// ([zFlattenPaths]) et le regroupement à la soumission ([zRegroupPaths]) se
/// font **à la frontière** du formulaire. La paire est **symétrique par
/// construction** : pour tout jeu de clés pointées sans collision
/// feuille/branche, `zFlattenPaths(zRegroupPaths(flat), paths: flat.keys)`
/// rend `flat` à l'identique (garde de propriété dans les tests du paquet).
///
/// **Pur-Dart, pur-données** (couche `domain`, invariant AD-1) — aucune
/// dépendance Flutter, **jamais de `throw`** sur une donnée absente ou mal
/// formée (invariant AD-10).
library;

/// Aplati les valeurs **imbriquées** de [source] sous leurs clés **pointées**.
///
/// Pour chaque chemin de [paths] (ex. `'vido.chef_equipe_poste_id'`), descend
/// dans [source] segment par segment (chaque segment intermédiaire doit être
/// une `Map`) et pose la valeur atteinte sous la clé pointée du résultat. Un
/// chemin **sans point** lit simplement la clé de premier niveau.
///
/// **Défensif (invariant AD-10)** : un segment absent, ou un segment
/// intermédiaire qui n'est pas une `Map`, produit `null` sous la clé — jamais
/// un `throw`. Chaque chemin demandé est **toujours présent** dans le résultat
/// (à `null` au pire) : le formulaire amorce ainsi toutes ses tranches.
///
/// Réciproque : [zRegroupPaths].
Map<String, Object?> zFlattenPaths(
  Map<String, dynamic> source, {
  required Iterable<String> paths,
}) {
  final result = <String, Object?>{};
  for (final path in paths) {
    Object? cursor = source;
    for (final segment in path.split('.')) {
      if (cursor is Map) {
        cursor = cursor[segment];
      } else {
        cursor = null;
        break;
      }
    }
    result[path] = cursor;
  }
  return result;
}

/// Regroupe les clés **pointées** de [flat] en une `Map` **imbriquée**.
///
/// Chaque clé pointée (`'vido.chef_equipe_poste_id': v`) reconstruit son
/// arborescence (`{'vido': {'chef_equipe_poste_id': v}}`), avec **fusion
/// profonde** : deux clés partageant un préfixe (`'vido.a'`, `'vido.b'`)
/// alimentent la **même** sous-map. Une clé **sans point** passe telle quelle
/// au premier niveau.
///
/// **Collision feuille/branche** (`'vido': 1` **et** `'vido.a': 2` dans
/// [flat]) : la **branche gagne** — la feuille est abandonnée et le résultat
/// porte `{'vido': {'a': 2}}`. La règle est **indépendante de l'ordre
/// d'itération** des clés (la feuille perd, qu'elle arrive avant ou après la
/// branche). Un tel jeu de clés est hors du domaine de la symétrie
/// [zFlattenPaths]/[zRegroupPaths] (une même clé ne peut pas être à la fois
/// une valeur et un conteneur) ; le socle le tolère sans `throw` (invariant
/// AD-10) plutôt que d'échouer une soumission.
///
/// Réciproque : [zFlattenPaths].
Map<String, dynamic> zRegroupPaths(Map<String, Object?> flat) {
  final result = <String, dynamic>{};
  for (final entry in flat.entries) {
    final segments = entry.key.split('.');
    var node = result;
    for (var i = 0; i < segments.length - 1; i++) {
      final existing = node[segments[i]];
      // Descente avec COPIE : une map déjà là (branche en cours OU map posée
      // comme valeur — potentiellement figée ou à type de valeur restreint)
      // est recopiée dans une map fraîche, extensible et `dynamic`. Jamais de
      // `throw` sur une map hôte non modifiable (invariant AD-10). Une
      // feuille non-map déjà posée là est remplacée : la BRANCHE gagne.
      final next = existing is Map
          ? <String, dynamic>{
              for (final e in existing.entries) '${e.key}': e.value,
            }
          : <String, dynamic>{};
      node[segments[i]] = next;
      node = next;
    }
    final leaf = segments.last;
    final present = node[leaf];
    final value = entry.value;
    if (present is Map<String, dynamic>) {
      // Une BRANCHE occupe déjà cette clé. Feuille non-map ⇒ abandonnée (la
      // branche gagne). Feuille-MAP ⇒ fusion récursive où la branche gagne
      // clé à clé — même résultat quel que soit l'ordre d'itération de [flat].
      if (value is Map) _mergeBranchWins(present, value);
    } else {
      node[leaf] = value;
    }
  }
  return result;
}

/// Fusionne [value] dans la branche [branch] en donnant **priorité à la
/// branche** clé à clé (récursif quand les deux côtés sont des maps). Rend
/// [zRegroupPaths] indépendant de l'ordre d'itération des clés en collision.
void _mergeBranchWins(Map<String, dynamic> branch, Map<dynamic, dynamic> value) {
  for (final e in value.entries) {
    final key = '${e.key}';
    final existing = branch[key];
    if (existing is Map<String, dynamic> && e.value is Map) {
      _mergeBranchWins(existing, e.value as Map);
    } else if (!branch.containsKey(key)) {
      branch[key] = e.value;
    }
  }
}
