// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'z_choice.dart';

// **************************************************************************
// ZcrudModelGenerator
// **************************************************************************

/// Sentinelle « argument non fourni » du `copyWith` généré (reset-null).
const Object? _$undefined = _ZUndefined();

/// Clé de SONDE du garde DW-ES14-1 : n'est le nom persisté d'AUCUN champ de
/// schéma, ni une clé réservée (`ZSyncMeta`), ni `source`/`extension`.
const String _$zExtraProbeKey = 'zz__zcrud_extra_probe__';

/// 🔴 **GARDE EXÉCUTOIRE DW-ES14-1 / AD-4** — émis dans le `register…` de toute
/// classe `ZExtensible` (H1, code-review ES-2.0).
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
///     préservé au décodage n'est **jamais réémis**. ⚠️ Le `toMap()` **généré**
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

ZChoice _$ZChoiceFromMap(Map<String, dynamic> map) => ZChoice(
  content: map['content'] is String ? map['content'] as String : '',
  isCorrect: map['is_correct'] is bool ? map['is_correct'] as bool : false,
);

extension ZChoiceZcrud on ZChoice {
  /// Sérialise vers la map persistée (snake_case, enum camelCase, ISO-8601).
  Map<String, dynamic> toMap() => <String, dynamic>{
    'content': this.content,
    'is_correct': this.isCorrect,
  };

  /// Copie avec sentinelle : un argument omis préserve la valeur, `null` explicite la remet à `null`.
  ZChoice copyWith({
    Object? content = _$undefined,
    Object? isCorrect = _$undefined,
  }) => ZChoice(
    content: identical(content, _$undefined) ? this.content : content as String,
    isCorrect: identical(isCorrect, _$undefined)
        ? this.isCorrect
        : isCorrect as bool,
  );
}

/// Schéma déclaratif projeté depuis @ZcrudField (E2-5).
const List<ZFieldSpec> $ZChoiceFieldSpecs = <ZFieldSpec>[
  ZFieldSpec(name: 'content', type: EditionFieldType.text, label: 'Choix'),
  ZFieldSpec(name: 'is_correct', type: EditionFieldType.boolean),
];

/// Enregistre `ZChoice` (kind "flashcard_choice") sur [registry] : (dé)sérialisation + schéma.
void registerZChoice(ZcrudRegistry registry) => registry.register<ZChoice>(
  'flashcard_choice',
  fromMap: ZChoice.fromMap,
  toMap: (value) => value.toMap(),
  fieldSpecs: $ZChoiceFieldSpecs,
);

/// Clés persistées à encoder en `Timestamp` Firestore natif (gap B14, AD-5).
///
/// Métadonnée NEUTRE (littéraux `String`) : à passer au param `timestampFields`
/// de `FirebaseZRepositoryImpl` — `Timestamp` reste confiné à `zcrud_firestore`.
const Set<String> $ZChoiceTimestampFields = <String>{};
