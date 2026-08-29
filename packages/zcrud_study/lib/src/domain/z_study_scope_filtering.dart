/// Application d'un `ZStudyScopeFilter` à une liste **déjà filtrée** par un
/// écran.
///
/// Le noyau décide si UN artefact satisfait UNE portée (`zMatchesScopeFilter`) ;
/// cette fonction est le pendant côté écran : elle applique cette décision à une
/// liste, en un seul endroit, et rend la liste **inchangée** partout où la
/// portée ne dit rien.
///
/// ## Ce que l'écran doit fournir, et pourquoi
///
/// La décision de portée se prend sur un `ZStudyArtifact` — le protocole de
/// rattachement du noyau. Un item d'écran n'en est pas nécessairement un : une
/// flashcard, par exemple, ne porte aucun rattachement. L'appelant fournit donc
/// la **projection** [ZStudyArtifactOf] qui dit, pour son type d'item, où lire
/// le rattachement. Sans projection, aucune portée n'est applicable et la liste
/// est rendue telle quelle : le socle n'invente pas un rattachement que la
/// donnée ne porte pas.
///
/// ## Contrat d'inertie
///
/// [zFilterByScope] rend **l'instance reçue** (`identical`) dès que l'un des
/// trois cas se présente : filtre `null`, filtre vide, projection absente.
/// Aucune copie, aucun ordre modifié, aucune allocation.
///
/// ## Ce qu'un item sans rattachement devient
///
/// Sous un filtre non vide, un item dont la projection rend `null` est
/// **écarté** — exactement comme un artefact sans portée ni rattachement, que
/// `zMatchesScopeFilter` écarte déjà. Un item hors de toute portée ne satisfait
/// pas une portée demandée.
library;

import 'package:zcrud_study_kernel/zcrud_study_kernel.dart'
    show
        ZStudyArtifact,
        ZStudyScopeFilter,
        ZStudyStructureSnapshot,
        zMatchesScopeFilter;

/// Projection d'un item d'écran vers son rattachement, `null` si l'item n'en
/// porte aucun.
typedef ZStudyArtifactOf<T> = ZStudyArtifact? Function(T item);

/// Restreint [items] à ceux que [filter] accepte.
///
/// Rend **l'instance reçue** si [filter] est `null` ou vide, ou si [artifactOf]
/// est absente. Sinon rend une nouvelle liste, dans l'ordre d'origine.
///
/// [snapshot] sert l'extension aux descendants
/// (`ZStudyScopeFilter.includeDescendants`) : sans instantané, seule la portée
/// exacte est reconnue. [at] restreint aux rattachements valides à cet instant.
List<T> zFilterByScope<T>(
  List<T> items,
  ZStudyScopeFilter? filter, {
  ZStudyArtifactOf<T>? artifactOf,
  ZStudyStructureSnapshot snapshot = ZStudyStructureSnapshot.empty,
  DateTime? at,
}) {
  if (filter == null || filter.isEmpty || artifactOf == null) return items;
  final out = <T>[];
  for (final T item in items) {
    final ZStudyArtifact? artifact = artifactOf(item);
    if (artifact == null) continue;
    if (zMatchesScopeFilter(artifact, filter, snapshot: snapshot, at: at)) {
      out.add(item);
    }
  }
  return out;
}
