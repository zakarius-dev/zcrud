/// `ZStudyTopicCompetency` — ce qu'un thème fait travailler.
///
/// La liaison est **plusieurs-à-plusieurs** : un thème travaille plusieurs
/// compétences, une compétence est travaillée par plusieurs thèmes, souvent de
/// curriculums différents. Aucune des deux extrémités ne liste l'autre.
///
/// [weight] est un poids relatif libre, `null` si la liaison n'est pas
/// pondérée. Le noyau ne lui impose **aucune échelle** et ne garantit **aucune
/// somme** : normaliser des poids est une décision d'affichage ou de calcul,
/// pas une propriété de la donnée.
library;

import 'package:zcrud_core/domain.dart';

import 'z_study_json.dart';

/// Sentinelle de copie : distingue « argument omis » de `null` explicite.
const Object _undefined = Object();

/// Liaison pondérée entre un thème et une compétence.
class ZStudyTopicCompetency {
  /// Construit une liaison thème ↔ compétence.
  const ZStudyTopicCompetency({
    required this.topicId,
    required this.competencyId,
    this.weight,
  });

  /// Reconstruit défensivement depuis une map persistée (invariant AD-10) :
  /// identifiants absents ⇒ `''`, poids illisible ⇒ `null`.
  factory ZStudyTopicCompetency.fromMap(Map<String, dynamic> map) =>
      ZStudyTopicCompetency(
        topicId: zJsonString(map['topic_id']),
        competencyId: zJsonString(map['competency_id']),
        weight: zJsonDoubleOrNull(map['weight']),
      );

  /// Thème d'origine, défaut `''`.
  final String topicId;

  /// Compétence travaillée, défaut `''`.
  final String competencyId;

  /// Poids relatif libre, `null` si non pondérée.
  final double? weight;

  /// Sérialise vers la map persistée ; un poids absent n'écrit pas de clé.
  Map<String, dynamic> toMap() => <String, dynamic>{
    'topic_id': topicId,
    'competency_id': competencyId,
    if (weight != null) 'weight': weight,
  };

  /// Copie à sentinelle (un argument omis préserve la valeur, `null` explicite
  /// remet à `null`).
  ZStudyTopicCompetency copyWith({
    Object? topicId = _undefined,
    Object? competencyId = _undefined,
    Object? weight = _undefined,
  }) => ZStudyTopicCompetency(
    topicId: identical(topicId, _undefined) ? this.topicId : topicId as String,
    competencyId: identical(competencyId, _undefined)
        ? this.competencyId
        : competencyId as String,
    weight: identical(weight, _undefined) ? this.weight : weight as double?,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZStudyTopicCompetency &&
          topicId == other.topicId &&
          competencyId == other.competencyId &&
          weight == other.weight;

  @override
  int get hashCode => Object.hash(topicId, competencyId, weight);

  @override
  String toString() => 'ZStudyTopicCompetency($topicId ↔ $competencyId)';
}

/// Décode une liste de liaisons thème ↔ compétence (repli `const []`, éléments
/// illisibles ignorés).
List<ZStudyTopicCompetency> zStudyDecodeTopicCompetencies(Object? raw) =>
    zStudyDecodeList<ZStudyTopicCompetency>(
      raw,
      ZStudyTopicCompetency.fromMap,
    );
