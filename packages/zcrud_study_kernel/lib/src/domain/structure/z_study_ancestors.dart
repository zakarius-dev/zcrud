/// Projection des chaînes d'ancêtres à partir du seul `parentId`.
///
/// **`parentId` est la vérité ; `ancestorIds` est une projection.** Elle est
/// persistée pour rendre les requêtes de sous-arbre possibles sur un store
/// sans jointure, jamais pour faire autorité. Ces primitives la reconstruisent
/// à partir des seuls liens de parenté, pour n'importe quel type de nœud.
library;

import 'package:zcrud_core/domain.dart';

/// Recalcule la chaîne d'ancêtres de chaque nœud, racine d'abord.
///
/// [idOf] et [parentIdOf] projettent l'identité et la parenté du type porteur :
/// une organisation, une unité, un groupe, un programme et une période se
/// recalculent avec la même primitive.
///
/// Contrat :
/// - rend `Right` d'une map `id → ancestorIds` (racine d'abord, le nœud
///   lui-même exclu) ; un nœud racine a une chaîne vide ;
/// - un nœud d'identité `null` ou vide est **ignoré** (éphémère : il n'a pas
///   encore d'identité à laquelle rattacher une chaîne) ;
/// - un parent qui ne figure pas dans [nodes] termine la chaîne : le nœud est
///   traité comme une racine locale, sans échec — une vue partielle de l'arbre
///   reste exploitable ;
/// - un nœud son propre parent, ou tout **cycle**, rend
///   `Left(ZDomainFailure)`. La remontée est bornée par le nombre de nœuds :
///   elle se termine toujours, y compris sur une entrée cyclique.
ZResult<Map<String, List<String>>> zRecomputeAncestorIds<T>(
  Iterable<T> nodes, {
  required String? Function(T node) idOf,
  required String? Function(T node) parentIdOf,
}) {
  final parents = <String, String?>{};
  for (final node in nodes) {
    final id = idOf(node);
    if (id == null || id.isEmpty) continue;
    final parent = parentIdOf(node);
    parents[id] = (parent == null || parent.isEmpty) ? null : parent;
  }

  final out = <String, List<String>>{};
  final limit = parents.length;
  for (final id in parents.keys) {
    final chain = <String>[];
    final seen = <String>{id};
    var current = parents[id];
    var steps = 0;
    while (current != null) {
      if (!seen.add(current)) {
        return Left<ZFailure, Map<String, List<String>>>(
          ZDomainFailure(
            'Cycle de parenté détecté en remontant depuis « $id » '
            '(« $current » revu).',
          ),
        );
      }
      chain.add(current);
      if (!parents.containsKey(current)) break;
      current = parents[current];
      // Borne dure : même si `seen` était contourné, la remontée s'arrête.
      if (++steps > limit) {
        return Left<ZFailure, Map<String, List<String>>>(
          ZDomainFailure(
            'Remontée de parenté non terminante depuis « $id ».',
          ),
        );
      }
    }
    out[id] = List<String>.unmodifiable(chain.reversed);
  }
  return Right<ZFailure, Map<String, List<String>>>(
    Map<String, List<String>>.unmodifiable(out),
  );
}

/// Profondeur d'un nœud à partir de sa chaîne d'ancêtres (racine = `0`).
///
/// Définition unique de la profondeur dans le noyau : c'est celle que
/// rendent les accesseurs `depth` des entités de structure.
int zDepthOf(List<String> ancestorIds) => ancestorIds.length;
