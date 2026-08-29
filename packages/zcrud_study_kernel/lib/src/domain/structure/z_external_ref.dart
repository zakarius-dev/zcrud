/// `ZExternalRef` — identifiant d'un enregistrement dans un système tiers.
///
/// Porté par toute entité principale de structure sous forme de liste
/// (`externalRefs`) : c'est la voie par laquelle une application relie ses
/// enregistrements à un annuaire, un ENT, un SIS ou un export, **sans** que le
/// noyau connaisse ce système ni impose un format d'identifiant.
///
/// [system], [type] et [value] sont des chaînes opaques. Aucune unicité n'est
/// imposée : plusieurs références vers le même système coexistent (par
/// exemple un identifiant technique et un code d'export).
library;

import 'package:zcrud_core/domain.dart';

import 'z_study_json.dart';

/// Sentinelle de copie : distingue « argument omis » de `null` explicite.
const Object _undefined = Object();

/// Référence vers un enregistrement d'un système tiers.
class ZExternalRef {
  /// Construit une référence externe.
  const ZExternalRef({required this.system, required this.value, this.type});

  /// Reconstruit défensivement depuis une map persistée (invariant AD-10) :
  /// [system] et [value] absents retombent sur `''`, [type] sur `null`.
  factory ZExternalRef.fromMap(Map<String, dynamic> map) => ZExternalRef(
    system: zJsonString(map['system']),
    value: zJsonString(map['value']),
    type: zJsonStringOrNull(map['type']),
  );

  /// Système d'origine — chaîne opaque, défaut `''`.
  final String system;

  /// Nature de l'identifiant dans ce système — chaîne opaque, `null` si non
  /// qualifiée (le système n'en distingue qu'une).
  final String? type;

  /// Valeur de l'identifiant tel que le système tiers l'écrit, défaut `''`.
  final String value;

  /// Sérialise vers la map persistée ; [type] absent n'écrit aucune clé.
  Map<String, dynamic> toMap() => <String, dynamic>{
    'system': system,
    'value': value,
    if (type != null) 'type': type,
  };

  /// Copie à sentinelle (un argument omis préserve la valeur, `null` explicite
  /// remet à `null`).
  ZExternalRef copyWith({
    Object? system = _undefined,
    Object? type = _undefined,
    Object? value = _undefined,
  }) => ZExternalRef(
    system: identical(system, _undefined) ? this.system : system as String,
    type: identical(type, _undefined) ? this.type : type as String?,
    value: identical(value, _undefined) ? this.value : value as String,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZExternalRef &&
          system == other.system &&
          type == other.type &&
          value == other.value;

  @override
  int get hashCode => Object.hash(system, type, value);

  @override
  String toString() => 'ZExternalRef($system/${type ?? '-'}:$value)';
}

/// Décode une liste de références externes (repli `const []`, éléments
/// illisibles ignorés).
List<ZExternalRef> zStudyDecodeExternalRefs(Object? raw) =>
    zStudyDecodeList<ZExternalRef>(raw, ZExternalRef.fromMap);
