/// Configuration persistée d'une session d'étude `ZStudySessionConfig`
/// (Story E9-3, AC1/AC3/AC7).
///
/// origine: lex_core (module « Étude ») — filtres de session (canonique §2.3,
/// FR-18). **Config de valeur** (pas d'`id`, pas de `ZEntity`) : elle décrit
/// *quelles* cartes composent une session — `mode` + filtres `folderId`/`tagIds`/
/// `types` + plafond `count`. La **sélection effective** est portée par la
/// primitive pure `ZStudySessionSelector` (`z_study_session_selector.dart`).
///
/// **Généré par `@ZcrudModel` (AD-3)** : `melos run generate` émet
/// `z_study_session_config.g.dart` (`part`, gitignoré, régénéré) portant
/// `_$ZStudySessionConfigFromMap`, l'extension `ZStudySessionConfigZcrud`
/// (`toMap`/`copyWith`), `$ZStudySessionConfigFieldSpecs` et
/// `registerZStudySessionConfig(ZcrudRegistry)`.
///
/// **`types` (liste de clés de type NEUTRES) — découplage AD-1/AD-17 (ES-1.1,
/// AC6)** : le champ conserve le **nom `types`** (clé JSON `types` inchangée)
/// mais son type d'élément est **neutre `String`** (`List<String>?`) — et non
/// plus `List<ZFlashcardType>` (concept flashcard-spécifique, banni du noyau par
/// AD-17). Les valeurs persistées restent les **noms d'enum camelCase**
/// (ex. `"multipleChoice"`) ⇒ le wire est **byte-identique** à E9 (round-trip
/// AD-10, gate `verify:serialization` préservé). Le générateur zcrud
/// (dé)sérialise nativement `List<String>?` (mêmes défauts défensifs que
/// `tag_ids` : non-liste → `null`, éléments non-`String` filtrés). L'ergonomie
/// typée `ZFlashcardType` (mapping String↔enum, drop défensif des inconnus) est
/// restituée **côté `zcrud_flashcard`** via une extension (`flashcardTypes` /
/// `withFlashcardTypes`), jamais dans le noyau.
///
/// **`mode` défensif → [ZReviewMode.spaced] (AC1)** via `defaultValue` : une
/// valeur inconnue/absente retombe sur `spaced`, sans throw.
///
/// **Slots d'extension AD-4** : mixe `ZExtensible` (cœur) → [extra] + [extension]
/// (câblés manuellement autour du code généré, même patron que `ZFlashcard`).
library;

import 'package:zcrud_annotations/zcrud_annotations.dart';
import 'package:zcrud_core/domain.dart';

import 'z_review_mode.dart';

export 'z_review_mode.dart';

part 'z_study_session_config.g.dart';

/// Reconstruit une [ZExtension] concrète depuis sa map JSON, ou `null`.
///
/// Injecté dans [ZStudySessionConfig.fromMap] (AD-4) ; toute exception est
/// absorbée en `null` par [ZExtension.guard] (AD-10).
typedef ZSessionConfigExtensionParser = ZExtension? Function(
    Map<String, dynamic> json);

/// Filtres persistés d'une session d'étude (config de valeur immuable — AC7).
@ZcrudModel(kind: 'study_session_config', fieldRename: ZFieldRename.snake)
class ZStudySessionConfig with ZExtensible {
  /// Construit une config (constructeur nommé — source du `copyWith`).
  const ZStudySessionConfig({
    this.mode = ZReviewMode.spaced,
    this.folderId,
    this.tagIds,
    this.types,
    this.count,
    this.extension,
    Map<String, dynamic> extra = const <String, dynamic>{},
    // ⚠️ Le « fix » du lint (`this._extra`) est **ILLÉGAL** en Dart : un paramètre
    // NOMMÉ ne peut pas être privé (PRIVATE_OPTIONAL_PARAMETER). Or le slot brut
    // DOIT rester privé — c'est l'ACCESSEUR `extra` qui porte la garde (ES-2.2b).
    // ignore: prefer_initializing_formals
  }) : _extra = extra;

  /// Reconstruit **défensivement** depuis une map persistée (AD-10).
  ///
  /// Délègue au `_$ZStudySessionConfigFromMap` **généré** (`mode` inconnu →
  /// `spaced` ; `tag_ids`/`types` non-liste → `null` ; élément de `types`
  /// inconnu → ignoré ; `count` non-int → `null`), puis câble les deux canaux
  /// hors-codegen : [extension] (repli `null`) et [extra] (clés non réservées).
  ///
  /// Aucun cas ne fait échouer le parent.
  factory ZStudySessionConfig.fromMap(
    Map<String, dynamic> map, {
    ZSessionConfigExtensionParser? extensionParser,
  }) {
    final base = _$ZStudySessionConfigFromMap(map);
    return ZStudySessionConfig(
      mode: base.mode,
      folderId: base.folderId,
      tagIds: base.tagIds,
      types: base.types,
      count: base.count,
      extension: _decodeExtension(map['extension'], extensionParser),
      extra: _extraFrom(map),
    );
  }

  /// Mode de session (défaut/repli défensif `spaced` — AC1).
  @ZcrudField(defaultValue: ZReviewMode.spaced)
  final ZReviewMode mode;

  /// Dossier cible (`null` = **toutes** les cartes éligibles, pas de filtre —
  /// AC7/AC8). Couvre le dossier ET ses sous-dossiers (cf. sélecteur).
  @ZcrudField()
  final String? folderId;

  /// Étiquettes filtrantes (`null` ou vide = pas de filtre ; sinon intersection
  /// non vide — AC8).
  @ZcrudField()
  final List<String>? tagIds;

  /// Types filtrants **neutres** (`null` ou vide = pas de filtre ; sinon
  /// appartenance sur la clé opaque `ZSessionCandidate.typeKey` — AC6). Clés
  /// camelCase (ex. `"multipleChoice"`) ; l'ergonomie typée `ZFlashcardType` est
  /// restituée côté `zcrud_flashcard`.
  @ZcrudField()
  final List<String>? types;

  /// Plafond du nombre de cartes (`null` = illimité ; `<= 0` = sélection vide —
  /// AC8).
  @ZcrudField()
  final int? count;

  /// Slot type additif **versionné** (AD-4 pt.1), `null` si absent. Hors-codegen.
  @override
  final ZExtension? extension;

  /// Échappatoire non typée (AD-4 pt.2), défaut `const {}` (jamais `null`).
  /// Hors-codegen.
  @override
  Map<String, dynamic> get extra => zNormalizeExtra(_extra, _reservedKeys);

  /// Slot `extra` **BRUT tel que reçu par le constructeur** — lu **NULLE PART**
  /// ailleurs que dans l'accesseur [extra] (ni `toMap`, ni `==`, ni `hashCode`).
  ///
  /// Il peut être **POLLUÉ** : le constructeur nominal est `const`, il ne peut
  /// appeler **aucune** fonction dans son initializer, et **AD-10 INTERDIT** d'y
  /// mettre un `assert`. C'est l'**ACCESSEUR** [extra] qui porte la garde
  /// (`zNormalizeExtra`) — **le seul point que TOUTES les voies traversent**.
  final Map<String, dynamic> _extra;

  /// Sérialise vers la map persistée **complète** (snake_case).
  ///
  /// Réutilise le `toMap()` **généré** (mode camelCase, `types` en `name`) puis
  /// superpose [extra] et [extension].
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      // 🔴 DW-ES22-3 (ES-2.2b) — MÊME garde nommée qu'en `fromMap`/`copyWith`.
      // `toMap()` est la **frontière de SORTIE** : la seule que TOUTES les voies
      // d'écriture traversent ⇒ la promesse est INCONDITIONNELLE, y compris pour
      // une instance née du constructeur nominal (qui ne peut RIEN filtrer).
      // 🔴 ES-2.2b (remédiation HIGH-1) — étale l'**ACCESSEUR** (qui NORMALISE),
      // jamais le champ brut `_extra`. Un `_sanitizeExtra(extra)` ICI serait
      // **DÉCORATIF** — MESURÉ (INJ-A/INJ-B) : le retirer laissait le gate VERT
      // sur 8 entités sur 9. La garde vit à l'accesseur ; l'en retirer rend
      // (i.1a)/(i.1b)/(i.1c) ROUGES.
      ...extra,
      ...ZStudySessionConfigZcrud(this).toMap(),
    };
    if (extension != null) {
      map['extension'] = extension!.toJson();
    }
    return map;
  }

  /// Copie avec sentinelle (un argument omis préserve la valeur, `null` explicite
  /// le remet à `null`). Couvre [extension]/[extra] (ignorés du `copyWith`
  /// généré).
  ZStudySessionConfig copyWith({
    Object? mode = _$undefined,
    Object? folderId = _$undefined,
    Object? tagIds = _$undefined,
    Object? types = _$undefined,
    Object? count = _$undefined,
    Object? extension = _$undefined,
    Object? extra = _$undefined,
  }) =>
      ZStudySessionConfig(
        mode: identical(mode, _$undefined) ? this.mode : mode as ZReviewMode,
        folderId:
            identical(folderId, _$undefined) ? this.folderId : folderId as String?,
        tagIds: identical(tagIds, _$undefined)
            ? this.tagIds
            : tagIds as List<String>?,
        types: identical(types, _$undefined)
            ? this.types
            : types as List<String>?,
        count: identical(count, _$undefined) ? this.count : count as int?,
        extension: identical(extension, _$undefined)
            ? this.extension
            : extension as ZExtension?,
        // 🔴 DW-ES22-3 (ES-2.2b) : MÊME FONCTION NOMMÉE qu'en `fromMap` —
        // `copyWith` ne peut plus ROUVRIR le filtre des clés réservées.
        extra: identical(extra, _$undefined)
            ? this.extra
            : _sanitizeExtra(extra as Map<String, dynamic>),
      );

  /// Décode défensivement l'extension via [parser] (repli `null`).
  static ZExtension? _decodeExtension(
    Object? raw,
    ZSessionConfigExtensionParser? parser,
  ) {
    if (parser == null) return null;
    final map = _asStringMap(raw);
    if (map == null) return null;
    return ZExtension.guard<ZExtension?>(() => parser(map));
  }

  /// Clés persistées **réservées** (champs générés + `extension` + **clés de
  /// sync `ZSyncMeta`**) — dérivées de `$ZStudySessionConfigFieldSpecs`.
  ///
  /// **AD-19 (ES-1.3)** — le spread `...ZSyncMeta.reservedKeys` (`updated_at`,
  /// `is_deleted`) est **obligatoire pour toute entité annotée** : l'entité est
  /// enregistrée au `ZcrudRegistry` (`kind: 'study_session_config'`) donc
  /// persistable comme document autonome, et les stores écrivent leurs
  /// métadonnées de sync **dans le corps** avant de passer la map **complète** à
  /// [fromMap]. Sans ce spread, `updated_at`/`is_deleted` — propriété du
  /// **store**, pas du domaine — atterriraient dans [extra] (AD-4) et seraient
  /// **réémises** par [toMap] (AD-16 : soft-delete hors-entité).
  ///
  /// C'est le **patron canonique du noyau** : toute entité d'ES-2
  /// (`ZStudyDocument`, `ZSmartNote`, `ZExam`, …) le reproduit à l'identique.
  static final Set<String> _reservedKeys = <String>{
    for (final spec in $ZStudySessionConfigFieldSpecs) spec.name,
    'extension',
    ...ZSyncMeta.reservedKeys,
  };

  /// Extrait `extra` = clés non réservées de [map] (round-trip préservé) —
  /// **frontière d'ENTRÉE**. C'est [_sanitizeExtra], la garde **partagée**.
  static Map<String, dynamic> _extraFrom(Map<String, dynamic> map) =>
      _sanitizeExtra(map);

  /// 🔴 **LA GARDE PARTAGÉE DE `extra`** (DW-ES22-3, ES-2.2b) — appelée par les
  /// **TROIS** voies : [fromMap], [copyWith] **et** [toMap]. Délègue à
  /// [zSanitizeExtra] (`zcrud_core`, implémentation UNIQUE du repo).
  static Map<String, dynamic> _sanitizeExtra(Map<String, dynamic> raw) =>
      zSanitizeExtra(raw, _reservedKeys);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZStudySessionConfig &&
          mode == other.mode &&
          folderId == other.folderId &&
          _listEquals(tagIds, other.tagIds) &&
          _listEquals(types, other.types) &&
          count == other.count &&
          extension == other.extension &&
          zJsonEquals(extra, other.extra);

  @override
  int get hashCode => Object.hashAll(<Object?>[
        mode,
        folderId,
        if (tagIds != null) Object.hashAll(tagIds!),
        if (types != null) Object.hashAll(types!),
        count,
        extension,
        zJsonHash(extra),
      ]);
}

/// Coerce défensive vers `Map<String, dynamic>` (repli `null`).
Map<String, dynamic>? _asStringMap(Object? v) {
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

bool _listEquals<T>(List<T>? a, List<T>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null) return false;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
