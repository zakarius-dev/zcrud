/// `ZStudyCompetencyRelation` — arête orientée entre deux compétences, et la
/// validation du graphe qu'elles forment.
///
/// **C'est un graphe, pas un arbre.** Les compétences se recoupent : une même
/// compétence est contenue par deux ensembles, requise par trois autres,
/// équivalente à une quatrième ailleurs. Les cycles sont donc **admis par
/// défaut** — `related` et `equivalent` sont symétriques, un aller-retour y est
/// la normale, pas une anomalie.
///
/// Deux natures font exception, et seulement deux : `prerequisite` et
/// `contains` (`kZStudyAcyclicCompetencyRelations`). Rien ne peut se précéder
/// ni se contenir soi-même : un cycle y est une contradiction, pas une donnée.
/// [zValidateCompetencyGraph] contrôle **chaque nature séparément** — un cycle
/// n'existe que s'il se referme sans changer de nature.
library;

import 'package:zcrud_core/domain.dart';

import 'z_study_constants.dart';
import 'z_study_graph.dart';
import 'z_study_json.dart';

/// Sentinelle de copie : distingue « argument omis » de `null` explicite.
const Object _undefined = Object();

/// Arête orientée entre deux compétences.
class ZStudyCompetencyRelation {
  /// Construit une relation entre compétences.
  const ZStudyCompetencyRelation({
    required this.fromId,
    required this.toId,
    this.kind = kZStudyCompetencyRelationRelated,
    this.metadata = const <String, dynamic>{},
  });

  /// Reconstruit défensivement depuis une map persistée (invariant AD-10) :
  /// identifiants absents ⇒ `''`, nature absente ⇒ `related`.
  factory ZStudyCompetencyRelation.fromMap(Map<String, dynamic> map) =>
      ZStudyCompetencyRelation(
        fromId: zJsonString(map['from_id']),
        toId: zJsonString(map['to_id']),
        kind: zJsonString(map['kind'], kZStudyCompetencyRelationRelated),
        metadata: zStudyAsJsonMap(map['metadata']) ?? const <String, dynamic>{},
      );

  /// Compétence d'origine, défaut `''`.
  final String fromId;

  /// Compétence d'arrivée, défaut `''`.
  final String toId;

  /// Nature du lien — chaîne opaque, défaut `related`.
  ///
  /// Voir `kZStudyCompetencyRelation…`. Une nature inconnue est conservée et
  /// n'est **jamais** contrôlée pour l'acyclicité.
  final String kind;

  /// Métadonnées libres, round-trippées telles quelles, défaut `const {}`.
  final Map<String, dynamic> metadata;

  /// `true` si la nature de ce lien interdit les cycles.
  bool get mustBeAcyclic => kZStudyAcyclicCompetencyRelations.contains(kind);

  /// Sérialise vers la map persistée ; [metadata] vide n'écrit pas de clé.
  Map<String, dynamic> toMap() => <String, dynamic>{
    'from_id': fromId,
    'to_id': toId,
    'kind': kind,
    if (metadata.isNotEmpty) 'metadata': Map<String, dynamic>.of(metadata),
  };

  /// Copie à sentinelle (un argument omis préserve la valeur).
  ZStudyCompetencyRelation copyWith({
    Object? fromId = _undefined,
    Object? toId = _undefined,
    Object? kind = _undefined,
    Object? metadata = _undefined,
  }) => ZStudyCompetencyRelation(
    fromId: identical(fromId, _undefined) ? this.fromId : fromId as String,
    toId: identical(toId, _undefined) ? this.toId : toId as String,
    kind: identical(kind, _undefined) ? this.kind : kind as String,
    metadata: identical(metadata, _undefined)
        ? this.metadata
        : metadata as Map<String, dynamic>,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZStudyCompetencyRelation &&
          fromId == other.fromId &&
          toId == other.toId &&
          kind == other.kind &&
          zJsonEquals(metadata, other.metadata);

  @override
  int get hashCode => Object.hash(fromId, toId, kind, zJsonHash(metadata));

  @override
  String toString() => 'ZStudyCompetencyRelation($fromId -[$kind]-> $toId)';
}

/// Décode une liste de relations de compétences (repli `const []`, éléments
/// illisibles ignorés).
List<ZStudyCompetencyRelation> zStudyDecodeCompetencyRelations(Object? raw) =>
    zStudyDecodeList<ZStudyCompetencyRelation>(
      raw,
      ZStudyCompetencyRelation.fromMap,
    );

/// `Right(unit)` si aucune nature à acyclicité obligatoire ne forme de cycle,
/// `Left(ZDomainFailure)` au premier cycle rencontré.
///
/// Contrat :
/// - **chaque nature est contrôlée séparément** : un chemin `a --contains--> b`
///   suivi de `b --prerequisite--> a` n'est **pas** un cycle, parce qu'aucune
///   des deux natures ne se referme sur elle-même ;
/// - les natures hors de `kZStudyAcyclicCompetencyRelations` ne sont jamais
///   contrôlées : un cycle de `related` ou d'`equivalent` est valide, y compris
///   un aller-retour direct ;
/// - une relation dont une extrémité est vide est ignorée ;
/// - le contrôle est **local à l'ensemble fourni** : il n'a pas d'avis sur les
///   relations qu'on ne lui a pas données.
///
/// [acyclicKinds] permet de choisir un autre jeu de natures contraintes ; par
/// défaut, `prerequisite` et `contains`.
ZResult<Unit> zValidateCompetencyGraph(
  Iterable<ZStudyCompetencyRelation> relations, {
  Set<String> acyclicKinds = kZStudyAcyclicCompetencyRelations,
}) {
  // Un seul passage de regroupement : une nature absente de l'entrée ne coûte
  // pas un parcours à vide.
  final parNature = <String, List<ZStudyCompetencyRelation>>{};
  for (final relation in relations) {
    if (!acyclicKinds.contains(relation.kind)) continue;
    (parNature[relation.kind] ??= <ZStudyCompetencyRelation>[]).add(relation);
  }
  for (final entry in parNature.entries) {
    final resultat = zDetectCycle<ZStudyCompetencyRelation>(
      entry.value,
      fromIdOf: (ZStudyCompetencyRelation r) => r.fromId,
      toIdOf: (ZStudyCompetencyRelation r) => r.toId,
    );
    final echec = resultat.fold<ZFailure?>(
      (ZFailure failure) => failure,
      (Unit _) => null,
    );
    if (echec != null) {
      return Left<ZFailure, Unit>(
        ZDomainFailure(
          'Cycle interdit sur les relations « ${entry.key} » : '
          '${echec.message}',
        ),
      );
    }
  }
  return const Right<ZFailure, Unit>(unit);
}
