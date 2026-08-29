/// `ZStudyRelation` — arête datée et typée entre deux éléments de structure.
///
/// Là où `ZStudyBinding` rattache une source à une **portée** (et propage),
/// une relation exprime un lien **latéral** entre deux éléments de même rang :
/// équivalence entre deux cours de deux organisations, prérequis entre deux
/// programmes, succession entre deux périodes.
///
/// [kind] est une chaîne opaque : le noyau ne l'interprète pas, ne l'oriente
/// pas et n'en dérive aucune fermeture transitive. [metadata] est une carte
/// libre round-trippée telle quelle.
library;

import 'package:zcrud_core/domain.dart';

import 'z_study_json.dart';
import 'z_study_ref.dart';

/// Sentinelle de copie : distingue « argument omis » de `null` explicite.
const Object _undefined = Object();

/// Arête datée et typée entre deux éléments de structure.
class ZStudyRelation {
  /// Construit une relation.
  const ZStudyRelation({
    required this.fromRef,
    required this.toRef,
    this.kind = '',
    this.validFrom,
    this.validTo,
    this.metadata = const <String, dynamic>{},
  });

  /// Reconstruit défensivement depuis une map persistée (invariant AD-10).
  factory ZStudyRelation.fromMap(Map<String, dynamic> map) => ZStudyRelation(
    fromRef: _refOf(map['from_ref']),
    toRef: _refOf(map['to_ref']),
    kind: zJsonString(map['kind']),
    validFrom: zJsonDate(map['valid_from']),
    validTo: zJsonDate(map['valid_to']),
    metadata: zStudyAsJsonMap(map['metadata']) ?? const <String, dynamic>{},
  );

  /// Origine de l'arête.
  final ZStudyRef fromRef;

  /// Extrémité de l'arête.
  final ZStudyRef toRef;

  /// Nature du lien — chaîne opaque, défaut `''`.
  final String kind;

  /// Début de validité inclus, `null` si non borné.
  final DateTime? validFrom;

  /// Fin de validité exclue, `null` si non bornée.
  final DateTime? validTo;

  /// Métadonnées libres, round-trippées telles quelles, défaut `const {}`.
  final Map<String, dynamic> metadata;

  /// `true` si la relation est valide à [instant] (intervalle semi-ouvert).
  bool isActiveAt(DateTime instant) {
    if (validFrom != null && instant.isBefore(validFrom!)) return false;
    if (validTo != null && !instant.isBefore(validTo!)) return false;
    return true;
  }

  /// Sérialise vers la map persistée ; aucune valeur absente n'écrit de clé,
  /// et [metadata] vide n'écrit pas de clé.
  Map<String, dynamic> toMap() => <String, dynamic>{
    'from_ref': fromRef.toMap(),
    'to_ref': toRef.toMap(),
    'kind': kind,
    if (validFrom != null) 'valid_from': validFrom!.toIso8601String(),
    if (validTo != null) 'valid_to': validTo!.toIso8601String(),
    if (metadata.isNotEmpty) 'metadata': Map<String, dynamic>.of(metadata),
  };

  /// Copie à sentinelle (un argument omis préserve la valeur, `null` explicite
  /// remet à `null`).
  ZStudyRelation copyWith({
    Object? fromRef = _undefined,
    Object? toRef = _undefined,
    Object? kind = _undefined,
    Object? validFrom = _undefined,
    Object? validTo = _undefined,
    Object? metadata = _undefined,
  }) => ZStudyRelation(
    fromRef: identical(fromRef, _undefined)
        ? this.fromRef
        : fromRef as ZStudyRef,
    toRef: identical(toRef, _undefined) ? this.toRef : toRef as ZStudyRef,
    kind: identical(kind, _undefined) ? this.kind : kind as String,
    validFrom: identical(validFrom, _undefined)
        ? this.validFrom
        : validFrom as DateTime?,
    validTo: identical(validTo, _undefined)
        ? this.validTo
        : validTo as DateTime?,
    metadata: identical(metadata, _undefined)
        ? this.metadata
        : metadata as Map<String, dynamic>,
  );

  static ZStudyRef _refOf(Object? raw) {
    final map = zStudyAsJsonMap(raw);
    return map == null
        ? const ZStudyRef(type: '', id: '')
        : ZStudyRef.fromMap(map);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZStudyRelation &&
          fromRef == other.fromRef &&
          toRef == other.toRef &&
          kind == other.kind &&
          validFrom == other.validFrom &&
          validTo == other.validTo &&
          zJsonEquals(metadata, other.metadata);

  @override
  int get hashCode => Object.hash(
    fromRef,
    toRef,
    kind,
    validFrom,
    validTo,
    zJsonHash(metadata),
  );
}

/// Décode une liste de relations (repli `const []`, éléments illisibles
/// ignorés).
List<ZStudyRelation> zStudyDecodeRelations(Object? raw) =>
    zStudyDecodeList<ZStudyRelation>(raw, ZStudyRelation.fromMap);
