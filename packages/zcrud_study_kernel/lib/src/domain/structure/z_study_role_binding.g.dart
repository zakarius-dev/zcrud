// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'z_study_role_binding.dart';

// **************************************************************************
// ZcrudModelGenerator
// **************************************************************************

/// Sentinelle « argument non fourni » du `copyWith` généré (reset-null).
const Object? _$undefined = _ZUndefined();

/// Clé de SONDE de la garde d'extensibilité : n'est le nom persisté d'AUCUN
/// champ de schéma, ni une clé réservée (`ZSyncMeta`), ni `source`/`extension`.
const String _$zExtraProbeKey = 'zz__zcrud_extra_probe__';

/// **GARDE EXÉCUTOIRE d'extensibilité** (invariant AD-4) — émise dans le `register…`
/// de toute classe `ZExtensible`.
///
/// ## Ce qu'il fait, et pourquoi il existe
///
/// Il **OBSERVE le POUVOIR** du couple (`fromMap`, `toMap`) au lieu de faire
/// confiance à sa forme : il décode une sonde portant une clé **inconnue du
/// schéma**, puis la ré-encode, et exige que la clé **survive au round-trip
/// COMPLET** — exactement le cycle lecture → écriture d'un store câblé sur
/// `registry.decode`/`registry.encode` (`FirebaseZRepositoryImpl.fromRegistry`).
///
/// Les **DEUX** jambes sont vérifiées, parce que la destruction peut venir de
/// l'une **ou** de l'autre :
///   - **(entrée)** `fromMap` amnésique — délègue à `_$XxxFromMap` (la factory
///     du CODEGEN, qui ne connaît QUE les champs `@ZcrudField`) ou « oublie »
///     `extra:` en recopiant les champs ⇒ `extra` reste VIDE ;
///   - **(sortie)** `toMap` amnésique — n'étale pas `...extra` ⇒ ce qui avait été
///     préservé au décodage n'est **jamais réémis**. Attention : le `toMap()` **généré**
///     (extension `XxxZcrud`) n'étale PAS `extra` : une entité `ZExtensible` qui
///     ne définit pas son propre `toMap()` d'instance tombe dans ce cas.
///
/// Le contrat de **BUILD** vérifie une signature et refuse la délégation nue ; il
/// ne peut pas prouver qu'un corps ré-écrit à la main préserve `extra`. **Ce
/// garde-ci le prouve**, à l'enregistrement, une fois par kind. C'est le seul
/// filet qui suive les packages **PUBLIÉS** : un consommateur externe a le
/// générateur, mais **pas** le harnais `tool/reserved_keys_gate`.
///
/// ## Pourquoi il n'est PAS sous `assert`
///
/// Un `assert` s'évapore en release : le filet disparaîtrait précisément là où la
/// perte de données est définitive. Aucune dégradation silencieuse (R6).
void _$zRequireExtraPreserved<T>(
  String className,
  T Function(Map<String, dynamic> map) fromMap,
  Map<String, dynamic> Function(T value) toMap,
  Map<String, dynamic> Function(T value) extraOf,
) {
  final T decoded;
  try {
    decoded = fromMap(<String, dynamic>{_$zExtraProbeKey: true});
  } catch (error) {
    throw StateError(
      'zcrud/DW-ES14-1 : `$className.fromMap` a LEVÉ sur une map de sonde. '
      'Le décodage doit être DÉFENSIF (AD-10) : un champ absent ou corrompu ne '
      'fait JAMAIS échouer le parent. Erreur : $error',
    );
  }

  // Jambe (entrée) — `fromMap` peuple-t-il `extra` ?
  if (extraOf(decoded)[_$zExtraProbeKey] != true) {
    throw StateError(
      'zcrud/DW-ES14-1 (AD-4) : `$className` est `ZExtensible`, mais son '
      'décodeur de domaine `$className.fromMap` NE PEUPLE PAS `extra` — la clé '
      'hors-schéma de la sonde a été DÉTRUITE au DÉCODAGE.\n'
      'Conséquence si ce registrar était utilisé (registry.decode / '
      'FirebaseZRepositoryImpl.fromRegistry) : TOUTE clé métier inconnue du '
      'schéma serait effacée à chaque cycle lecture -> écriture. IRRÉVERSIBLE.\n'
      'CAUSE la plus fréquente : `factory $className.fromMap(map) => '
      '_\$${className}FromMap(map);` — la factory du CODEGEN ne connaît que les '
      'champs @ZcrudField.\n'
      'GESTE : recopier les champs depuis `_\$${className}FromMap(map)` PUIS '
      'passer `extra: _extraFrom(map)` (clés non réservées de la map). Patron de '
      'référence : `ZFlashcard.fromMap` / `ZStudyFolder.fromMap`.',
    );
  }

  // Jambe (sortie) — `toMap` réémet-il `extra` ?
  final Map<String, dynamic> encoded;
  try {
    encoded = toMap(decoded);
  } catch (error) {
    throw StateError(
      'zcrud/DW-ES14-1 : `$className.toMap()` a LEVÉ sur une entité décodée '
      'depuis une map de sonde. Erreur : $error',
    );
  }
  if (encoded[_$zExtraProbeKey] != true) {
    throw StateError(
      'zcrud/DW-ES14-1 (AD-4) : `$className.fromMap` préserve bien `extra`, '
      'mais `$className.toMap()` NE LE RÉÉMET PAS — la clé hors-schéma est '
      'DÉTRUITE à l\'ENCODAGE. Le round-trip d\'un store est donc amnésique '
      'malgré un décodage correct.\n'
      'CAUSE la plus fréquente : l\'entité s\'appuie sur le `toMap()` GÉNÉRÉ '
      '(extension `${className}Zcrud`), qui n\'émet QUE les champs @ZcrudField '
      'et n\'étale PAS `extra`.\n'
      'GESTE : déclarer un `toMap()` d\'INSTANCE qui étale l\'échappatoire — '
      '`Map<String, dynamic> toMap() => {...extra, ...${className}Zcrud(this).toMap()};` '
      '(patron `ZFlashcard.toMap` / `ZStudyFolder.toMap`).',
    );
  }
}

class _ZUndefined {
  const _ZUndefined();
}

int? _$asInt(Object? v) {
  if (v is int) return v;
  if (v is String) return int.tryParse(v);
  if (v is num) return v.toInt();
  return null;
}

double? _$asDouble(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

num? _$asNum(Object? v) {
  if (v is num) return v;
  if (v is String) return num.tryParse(v);
  return null;
}

DateTime? _$asDateTime(Object? v) {
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v);
  return null;
}

/// Décode défensivement une plage `ZDateRange` (AD-10) : délègue à
/// `ZDateRange.fromJsonSafe` — `null` sur TOUTE anomalie (non-map, clé absente,
/// valeur non-`String`, date non-ISO, `start > end`), jamais de throw. Le parent
/// survit toujours (champ corrompu → `null`).
ZDateRange? _$asDateRange(Object? v) => ZDateRange.fromJsonSafe(v);

T? _$enumFromName<T extends Enum>(List<T> values, Object? name) {
  if (name is! String) return null;
  for (final value in values) {
    if (value.name == name) return value;
  }
  return null;
}

/// Coerce défensive vers `Map<String, dynamic>` (AD-10) : `null` si [v] n'est
/// pas une Map ; sinon convertit toute clé en `String` (`Map<dynamic, dynamic>`
/// forgée / Hive) SANS jamais throw — un sous-objet à clés non-`String` ne casse
/// donc JAMAIS le parent (repli `null`).
Map<String, dynamic>? _$asStringMap(Object? v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) {
    try {
      return <String, dynamic>{for (final e in v.entries) '${e.key}': e.value};
    } catch (_) {
      return null;
    }
  }
  return null;
}

/// Décode défensivement un sous-modèle (AD-10) : coerce [v] en
/// `Map<String, dynamic>` puis délègue à [fromMap]. Toute anomalie (non-map,
/// clés non-`String`, `fromMap` qui throw) retombe sur `null` — le parent
/// survit toujours (sous-objet = `null`, filtrable en liste via `whereType`).
T? _$decodeModel<T>(Object? v, T Function(Map<String, dynamic>) fromMap) {
  final m = _$asStringMap(v);
  if (m == null) return null;
  try {
    return fromMap(m);
  } catch (_) {
    return null;
  }
}

ZStudyRoleBinding _$ZStudyRoleBindingFromMap(Map<String, dynamic> map) =>
    ZStudyRoleBinding(
      id: map['id'] is String ? map['id'] as String : null,
      roleKey: map['role_key'] is String ? map['role_key'] as String : '',
      periodId: map['period_id'] is String ? map['period_id'] as String : null,
      validFrom: _$asDateTime(map['valid_from']),
      validTo: _$asDateTime(map['valid_to']),
      inheritance: map['inheritance'] is String
          ? map['inheritance'] as String
          : '',
    );

extension ZStudyRoleBindingZcrud on ZStudyRoleBinding {
  /// Sérialise vers la map persistée (snake_case, enum camelCase, ISO-8601).
  Map<String, dynamic> toMap() => <String, dynamic>{
    'id': this.id,
    'role_key': this.roleKey,
    'period_id': this.periodId,
    'valid_from': this.validFrom?.toIso8601String(),
    'valid_to': this.validTo?.toIso8601String(),
    'inheritance': this.inheritance,
  };

  /// Copie avec sentinelle : un argument omis préserve la valeur, `null` explicite la remet à `null`.
  ZStudyRoleBinding copyWith({
    Object? id = _$undefined,
    Object? roleKey = _$undefined,
    Object? periodId = _$undefined,
    Object? validFrom = _$undefined,
    Object? validTo = _$undefined,
    Object? inheritance = _$undefined,
  }) => ZStudyRoleBinding(
    id: identical(id, _$undefined) ? this.id : id as String?,
    roleKey: identical(roleKey, _$undefined) ? this.roleKey : roleKey as String,
    periodId: identical(periodId, _$undefined)
        ? this.periodId
        : periodId as String?,
    validFrom: identical(validFrom, _$undefined)
        ? this.validFrom
        : validFrom as DateTime?,
    validTo: identical(validTo, _$undefined)
        ? this.validTo
        : validTo as DateTime?,
    inheritance: identical(inheritance, _$undefined)
        ? this.inheritance
        : inheritance as String,
  );
}

/// `toMap()`/`copyWith()` de `ZStudyRoleBinding` en MEMBRES D'INSTANCE.
///
/// À appliquer (`class ZStudyRoleBinding … with _$ZStudyRoleBindingZcrud`) quand un membre
/// d'extension ne suffit pas : un membre d'extension ne satisfait jamais un
/// membre abstrait hérité et reste invisible à un appel fait à travers un type
/// de base. Corps identiques à ceux de l'extension `ZStudyRoleBindingZcrud` : la map
/// produite ne change pas. Les champs déclarés par la classe deviennent alors
/// des `@override` des getters ci-dessous.
mixin _$ZStudyRoleBindingZcrud {
  String? get id;
  String get roleKey;
  String? get periodId;
  DateTime? get validFrom;
  DateTime? get validTo;
  String get inheritance;

  /// Sérialise vers la map persistée (snake_case, enum camelCase, ISO-8601).
  Map<String, dynamic> toMap() => <String, dynamic>{
    'id': this.id,
    'role_key': this.roleKey,
    'period_id': this.periodId,
    'valid_from': this.validFrom?.toIso8601String(),
    'valid_to': this.validTo?.toIso8601String(),
    'inheritance': this.inheritance,
  };

  /// Copie avec sentinelle : un argument omis préserve la valeur, `null` explicite la remet à `null`.
  ZStudyRoleBinding copyWith({
    Object? id = _$undefined,
    Object? roleKey = _$undefined,
    Object? periodId = _$undefined,
    Object? validFrom = _$undefined,
    Object? validTo = _$undefined,
    Object? inheritance = _$undefined,
  }) => ZStudyRoleBinding(
    id: identical(id, _$undefined) ? this.id : id as String?,
    roleKey: identical(roleKey, _$undefined) ? this.roleKey : roleKey as String,
    periodId: identical(periodId, _$undefined)
        ? this.periodId
        : periodId as String?,
    validFrom: identical(validFrom, _$undefined)
        ? this.validFrom
        : validFrom as DateTime?,
    validTo: identical(validTo, _$undefined)
        ? this.validTo
        : validTo as DateTime?,
    inheritance: identical(inheritance, _$undefined)
        ? this.inheritance
        : inheritance as String,
  );
}

/// Schéma déclaratif projeté depuis @ZcrudField.
const List<ZFieldSpec> $ZStudyRoleBindingFieldSpecs = <ZFieldSpec>[
  ZFieldSpec(name: 'id', type: EditionFieldType.text, isId: true),
  ZFieldSpec(name: 'role_key', type: EditionFieldType.text),
  ZFieldSpec(name: 'period_id', type: EditionFieldType.text),
  ZFieldSpec(name: 'valid_from', type: EditionFieldType.dateTime),
  ZFieldSpec(name: 'valid_to', type: EditionFieldType.dateTime),
  ZFieldSpec(name: 'inheritance', type: EditionFieldType.text),
];

/// Clés que `ZStudyRoleBinding.toMap()` PEUT produire — surensemble
/// stable, champs nuls compris. Source unique pour une garde d'exhaustivité
/// côté hôte : un champ ajouté par un tag futur apparaît ici sans action.
const Set<String> $ZStudyRoleBindingPersistedKeys = <String>{
  'id',
  'role_key',
  'period_id',
  'valid_from',
  'valid_to',
  'inheritance',
};

/// Enregistre `ZStudyRoleBinding` (kind "study_role_binding") sur [registry] : (dé)sérialisation + schéma.
void registerZStudyRoleBinding(ZcrudRegistry registry) {
  // DW-ES14-1 (AD-4) : POUVOIR observé, pas seulement signature vérifiée.
  _$zRequireExtraPreserved<ZStudyRoleBinding>(
    'ZStudyRoleBinding',
    ZStudyRoleBinding.fromMap,
    (value) => value.toMap(),
    (value) => value.extra,
  );
  registry.register<ZStudyRoleBinding>(
    'study_role_binding',
    fromMap: ZStudyRoleBinding.fromMap,
    toMap: (value) => value.toMap(),
    fieldSpecs: $ZStudyRoleBindingFieldSpecs,
    fromMapWithContext: (map, context) => ZStudyRoleBinding.fromMap(
      map,
      extensionParser: context?.extensionParser == null
          ? null
          : (json) => context!.extensionParser!('study_role_binding', json),
    ),
  );
}

/// Clés persistées à encoder en `Timestamp` Firestore natif (gap B14, AD-5).
///
/// Métadonnée NEUTRE (littéraux `String`) : à passer au param `timestampFields`
/// de `FirebaseZRepositoryImpl` — `Timestamp` reste confiné à `zcrud_firestore`.
const Set<String> $ZStudyRoleBindingTimestampFields = <String>{};
