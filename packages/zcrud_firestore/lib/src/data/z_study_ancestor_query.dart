/// Requête de **portée** sur la chaîne d'ancêtres d'une entité de structure.
///
/// Les entités hiérarchiques du noyau d'étude persistent, à côté de leur
/// parent immédiat, la **chaîne complète de leurs ancêtres** — la projection
/// qui rend une portée interrogeable en une seule requête, à profondeur
/// quelconque, sans lecture récursive.
///
/// Le prédicat est exprimé en termes **neutres** ([ZFilter]) et non en termes
/// Firestore : l'adaptateur le traduit en appartenance d'un élément au champ
/// collection (`arrayContains`). Aucun type backend n'entre donc dans une
/// signature publique, et le même filtre vaut devant un dépôt mémoire.
library;

import 'package:zcrud_core/zcrud_core.dart';

/// Nom persisté de la chaîne d'ancêtres.
///
/// C'est la clé écrite par la sérialisation du noyau, et donc celle que la
/// requête doit viser. Elle est publique pour qu'un hôte puisse l'employer
/// dans ses règles de sécurité et ses index composites, qui vivent hors du
/// code Dart.
const String kZStudyAncestorIdsKey = 'ancestor_ids';

/// Filtre « descendants de [ancestorId], à toute profondeur ».
///
/// Retient les enregistrements dont la chaîne d'ancêtres **contient**
/// [ancestorId] — donc les descendants directs comme indirects, mais **pas**
/// l'ancêtre lui-même : un enregistrement n'est jamais son propre ancêtre.
///
/// N'a de sens que sur une entité qui persiste sa chaîne d'ancêtres ; sur une
/// entité qui ne la porte pas, la clause ne retient rien.
///
/// ⚠️ La clause part dans la requête **et** est ré-appliquée aux lignes
/// projetées ; côté Firestore elle exige un index sur la clé de chaîne
/// d'ancêtres dès qu'elle est combinée à un tri.
ZFilter zStudyAncestorFilter(String ancestorId) =>
    ZFilter(kZStudyAncestorIdsKey, ZFilterOp.contains, ancestorId);

/// Requête complète « descendants de [ancestorId] », prête pour un
/// `ZRepository.getAll`/`watch`.
///
/// [extraFilters] sont ajoutés **après** le filtre de portée (conjonction).
/// [sorts], [limit], [startAfter] et [deletedScope] sont transmis tels quels ;
/// le défaut de [deletedScope] exclut les enregistrements supprimés.
ZDataRequest zStudyAncestorRequest(
  String ancestorId, {
  List<ZFilter> extraFilters = const <ZFilter>[],
  List<ZSort> sorts = const <ZSort>[],
  int? limit,
  ZCursor? startAfter,
  ZDeletedScope deletedScope = ZDeletedScope.aliveOnly,
}) =>
    ZDataRequest(
      filters: <ZFilter>[zStudyAncestorFilter(ancestorId), ...extraFilters],
      sorts: sorts,
      limit: limit,
      startAfter: startAfter,
      deletedScope: deletedScope,
    );
