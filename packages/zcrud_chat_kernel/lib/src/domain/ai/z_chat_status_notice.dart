/// Avis d'avancement d'un tour, sans agent obligatoire.
///
/// Un flux peut annoncer où il en est (`phase`, `detail`) avant le premier
/// bloc de réponse. Cet avis n'est pas une étape de réflexion attribuée à
/// un agent : les deux champs sont du texte, et l'absence de l'un des deux
/// laisse l'autre lisible.
library;

import 'package:zcrud_core/domain.dart';

/// Un avis d'avancement reçu pendant un tour.
class ZChatStatusNotice {
  /// Construit un avis. Les deux textes peuvent être vides : l'avis reste
  /// alors une marque d'arrivée, jamais une erreur.
  const ZChatStatusNotice({this.phase = '', this.detail = ''});

  /// Phase courte (`search`, `read`…), ou `''`.
  final String phase;

  /// Précision lisible, ou `''`.
  final String detail;

  /// `true` quand l'avis ne porte aucun texte.
  bool get isEmpty => phase.isEmpty && detail.isEmpty;

  /// Reconstruit un avis. Une donnée illisible devient un avis vide, jamais
  /// une exception (invariant AD-10).
  factory ZChatStatusNotice.fromJson(Object? raw) {
    final Map<String, dynamic>? map = zJsonMap(raw);
    if (map == null) return const ZChatStatusNotice();
    return ZChatStatusNotice(
      phase: zJsonString(map['phase']),
      detail: zJsonString(map['detail']),
    );
  }

  /// Forme persistée, sans les textes vides.
  Map<String, dynamic> toJson() => <String, dynamic>{
    if (phase.isNotEmpty) 'phase': phase,
    if (detail.isNotEmpty) 'detail': detail,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatStatusNotice &&
          phase == other.phase &&
          detail == other.detail;

  @override
  int get hashCode => Object.hash(phase, detail);

  @override
  String toString() => 'ZChatStatusNotice($phase, $detail)';
}
