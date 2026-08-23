/// Référence de modèle — `ZChatModelRef` (invariants AD-4, AD-10, AD-12).
///
/// Partout où un routeur nomme un modèle (modèle de référence, modèle d'une
/// route, replis), c'est ce value object qui est porté : un **fournisseur**
/// optionnel et un **identifiant de modèle**, tous deux **opaques** — le socle
/// les transporte verbatim et ne les interprète jamais (aucun catalogue, aucun
/// fournisseur par défaut, aucun `switch`).
///
/// ## Trois formes lues, une forme écrite
///
/// La lecture est tolérante (AD-10) :
/// - une map `{provider_id, model_id}` ;
/// - un jeton `"fournisseur:modèle"` — coupé sur le **premier** `:` ;
/// - un identifiant nu — le fournisseur est alors `null`.
///
/// [toJson] écrit toujours la map — c'est la forme des listes de replis d'une
/// route et d'un routeur, celle que produit le sous-formulaire décrit par
/// [$ZChatModelRefFieldSpecs]. [toCompactJson] reste disponible pour un hôte
/// qui transporte une référence isolée en jeton.
library;

import 'package:zcrud_core/domain.dart';

/// Référence **opaque** à un modèle, avec son fournisseur optionnel.
class ZChatModelRef {
  /// Construit une référence. [modelId] est transporté tel quel.
  const ZChatModelRef({this.providerId, required this.modelId});

  /// Lecture **défensive** d'une map, d'un jeton `"fournisseur:modèle"` ou
  /// d'un identifiant nu — `null` si aucun identifiant de modèle n'est
  /// lisible (jamais d'exception).
  ///
  /// Un jeton est coupé sur le **premier** `:` : `"a:b:c"` donne le
  /// fournisseur `a` et le modèle `b:c`. Un fournisseur vide (`":x"`) vaut
  /// `null`.
  static ZChatModelRef? fromJson(Object? raw) {
    if (raw is ZChatModelRef) return raw;
    if (raw is String) return _fromToken(raw);
    final Map<String, dynamic>? map = zJsonMap(raw);
    if (map == null) return null;
    final String modelId = zJsonString(map['model_id']).trim();
    if (modelId.isEmpty) return null;
    return ZChatModelRef(
      providerId: _blankToNull(zJsonStringOrNull(map['provider_id'])),
      modelId: modelId,
    );
  }

  /// Lit la référence **embarquée** dans la map d'un porteur (route, routeur).
  ///
  /// Deux dispositions sont acceptées : la clé `model` (map ou jeton), sinon
  /// les clés à plat `model_provider_id` / `model_id` — la forme que
  /// [ZChatModelRef.writeEmbedded] écrit et qu'un formulaire édite.
  static ZChatModelRef? readEmbedded(Map<String, dynamic> map) {
    if (map.containsKey('model')) {
      final ZChatModelRef? nested = fromJson(map['model']);
      if (nested != null) return nested;
    }
    final String modelId = zJsonString(map['model_id']).trim();
    if (modelId.isEmpty) return null;
    return ZChatModelRef(
      providerId: _blankToNull(zJsonStringOrNull(map['model_provider_id'])),
      modelId: modelId,
    );
  }

  /// Écrit [ref] **à plat** dans [out] (`model_provider_id`, `model_id`) —
  /// rien n'est écrit si [ref] est `null`.
  static void writeEmbedded(Map<String, dynamic> out, ZChatModelRef? ref) {
    if (ref == null) return;
    if (ref.providerId != null) out['model_provider_id'] = ref.providerId;
    out['model_id'] = ref.modelId;
  }

  /// Fournisseur **opaque**, ou `null` (l'exécuteur de l'hôte décide).
  final String? providerId;

  /// Identifiant de modèle **opaque**, jamais vide après [fromJson].
  final String modelId;

  /// `true` si le jeton [token] relit exactement cette référence.
  ///
  /// Faux dans un seul cas : fournisseur `null` et identifiant contenant un
  /// `:` — le jeton serait alors relu comme `fournisseur:modèle`.
  bool get isTokenReversible => providerId != null || !modelId.contains(':');

  /// Jeton `"fournisseur:modèle"`, ou l'identifiant nu sans fournisseur.
  String get token => providerId == null ? modelId : '$providerId:$modelId';

  /// Forme persistée canonique : `{provider_id?, model_id}`.
  Map<String, dynamic> toJson() => <String, dynamic>{
    if (providerId != null) 'provider_id': providerId,
    'model_id': modelId,
  };

  /// Forme **compacte** : le [token] quand il est réversible, la map de
  /// [toJson] sinon. Toujours relue par [fromJson] ; ce n'est **pas** la
  /// forme persistée des replis (voir [toJson]).
  Object toCompactJson() => isTokenReversible ? token : toJson();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatModelRef &&
          providerId == other.providerId &&
          modelId == other.modelId;

  @override
  int get hashCode => Object.hash(providerId, modelId);

  @override
  String toString() => 'ZChatModelRef($token)';
}

/// Sous-schéma d'édition d'une référence de modèle — items des sous-listes
/// `fallbacks` d'une route et d'un routeur. Aucun libellé : les textes
/// viennent de l'hôte, par clé.
///
/// Un item édité est la map `{provider_id?, model_id}` que [ZChatModelRef.toJson]
/// écrit et que [ZChatModelRef.fromJson] relit ; `model_id` est requis, un
/// item sans identifiant lisible est sauté à la lecture.
const List<ZFieldSpec> $ZChatModelRefFieldSpecs = <ZFieldSpec>[
  ZFieldSpec(name: 'provider_id', type: EditionFieldType.text),
  ZFieldSpec(
    name: 'model_id',
    type: EditionFieldType.text,
    validators: <ZValidatorSpec>[ZValidatorSpec.required()],
  ),
];

ZChatModelRef? _fromToken(String raw) {
  final String trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  final int i = trimmed.indexOf(':');
  if (i < 0) return ZChatModelRef(modelId: trimmed);
  final String provider = trimmed.substring(0, i).trim();
  final String model = trimmed.substring(i + 1).trim();
  if (model.isEmpty) return null;
  return ZChatModelRef(
    providerId: provider.isEmpty ? null : provider,
    modelId: model,
  );
}

String? _blankToNull(String? value) {
  if (value == null) return null;
  final String trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
