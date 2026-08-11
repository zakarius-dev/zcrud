/// Configuration persistée d'une session d'étude `ZStudySessionConfig`.
///
/// Config de valeur (pas d'identifiant, pas de `ZEntity`) : elle décrit
/// *quelles* cartes composent une session — `mode` + filtres
/// `folderId`/`tagIds`/`types` + plafond `count`. La sélection effective est
/// portée par la primitive pure `ZStudySessionSelector`
/// (`z_study_session_selector.dart`).
///
/// Généré par `@ZcrudModel` (invariant AD-3) : `melos run generate` émet le
/// fichier compagnon (`part`, gitignoré, régénéré) portant le décodeur
/// défensif, l'extension `toMap`/`copyWith`, les spécifications de champ et
/// l'enregistrement au registre.
///
/// **`types` — clés de type neutres, découplage (invariant AD-1)** : le
/// champ conserve le nom `types` (clé JSON `types` inchangée) mais son type
/// d'élément est neutre `String` (`List<String>?`), et non un type d'enum
/// spécifique à un satellite (banni du kernel). Les valeurs persistées
/// restent les noms d'enum camelCase (ex. `"multipleChoice"`) ⇒ le wire
/// reste identique (round-trip, invariant AD-10). Le générateur zcrud
/// (dé)sérialise nativement `List<String>?` (mêmes défauts défensifs que
/// `tag_ids` : non-liste → `null`, éléments non-`String` filtrés).
/// L'ergonomie typée (mapping `String` ↔ enum, rejet défensif des inconnus)
/// est restituée côté satellite via une extension, jamais dans le kernel.
///
/// **`mode` défensif → [ZReviewMode.spaced]** via `defaultValue` : une
/// valeur inconnue/absente retombe sur `spaced`, sans `throw`.
///
/// **Slots d'extension (invariant AD-4)** : mixe `ZExtensible` (cœur) →
/// [extra] + [extension] (câblés manuellement autour du code généré, même
/// patron que les autres entités du kernel).
library;

import 'package:zcrud_annotations/zcrud_annotations.dart';
import 'package:zcrud_core/domain.dart';

import 'z_review_mode.dart';

export 'z_review_mode.dart';

part 'z_study_session_config.g.dart';

/// Reconstruit une [ZExtension] concrète depuis sa map JSON, ou `null`.
///
/// Injecté dans [ZStudySessionConfig.fromMap] (invariant AD-4) ; toute
/// exception est absorbée en `null` par [ZExtension.guard] (invariant
/// AD-10).
typedef ZSessionConfigExtensionParser = ZExtension? Function(
    Map<String, dynamic> json);

/// Filtres persistés d'une session d'étude (config de valeur immuable).
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
    // Un paramètre nommé ne peut pas être privé en Dart, mais le slot brut
    // doit rester privé — c'est l'accesseur `extra` qui porte la garde.
    // ignore: prefer_initializing_formals
  }) : _extra = extra;

  /// Reconstruit défensivement depuis une map persistée (invariant AD-10).
  ///
  /// Délègue au décodeur généré (`mode` inconnu → `spaced` ; `tag_ids`/
  /// `types` non-liste → `null` ; élément de `types` inconnu → ignoré ;
  /// `count` non-int → `null`), puis câble les deux canaux hors-codegen :
  /// [extension] (repli `null`) et [extra] (clés non réservées).
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

  /// Mode de session (défaut/repli défensif `spaced`).
  @ZcrudField(defaultValue: ZReviewMode.spaced)
  final ZReviewMode mode;

  /// Dossier cible (`null` = toutes les cartes éligibles, pas de filtre).
  /// Couvre le dossier ET ses sous-dossiers (voir le sélecteur).
  @ZcrudField()
  final String? folderId;

  /// Étiquettes filtrantes (`null` ou vide = pas de filtre ; sinon
  /// intersection non vide).
  @ZcrudField()
  final List<String>? tagIds;

  /// Types filtrants neutres (`null` ou vide = pas de filtre ; sinon
  /// appartenance sur la clé opaque `ZSessionCandidate.typeKey`). Clés
  /// camelCase (ex. `"multipleChoice"`) ; l'ergonomie typée est restituée
  /// côté satellite.
  @ZcrudField()
  final List<String>? types;

  /// Plafond du nombre de cartes (`null` = illimité ; `<= 0` = sélection
  /// vide).
  @ZcrudField()
  final int? count;

  /// Slot type additif versionné (invariant AD-4), `null` si absent.
  /// Hors-codegen.
  @override
  final ZExtension? extension;

  /// Échappatoire non typée (invariant AD-4), défaut `const {}` (jamais
  /// `null`). Hors-codegen.
  @override
  Map<String, dynamic> get extra => zNormalizeExtra(_extra, _reservedKeys);

  /// Slot `extra` brut tel que reçu par le constructeur — lu nulle part
  /// ailleurs que dans l'accesseur [extra] (ni `toMap`, ni `==`, ni
  /// `hashCode`).
  ///
  /// Il peut être pollué : le constructeur nominal est `const`, il ne peut
  /// appeler aucune fonction dans son initializer, et l'invariant AD-10
  /// interdit d'y mettre un `assert`. C'est l'accesseur [extra] qui porte
  /// la garde (`zNormalizeExtra`) — le seul point que toutes les voies
  /// traversent.
  final Map<String, dynamic> _extra;

  /// Sérialise vers la map persistée complète (snake_case).
  ///
  /// Réutilise le `toMap()` généré (mode camelCase, `types` en `name`) puis
  /// superpose [extra] et [extension].
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      // `toMap()` est la frontière de sortie : la seule que toutes les
      // voies d'écriture traversent ⇒ la promesse est inconditionnelle, y
      // compris pour une instance née du constructeur nominal (qui ne peut
      // rien filtrer). Étale l'accesseur (qui normalise), jamais le champ
      // brut `_extra`.
      ...extra,
      ...ZStudySessionConfigZcrud(this).toMap(),
    };
    if (extension != null) {
      map['extension'] = extension!.toJson();
    }
    return map;
  }

  /// Copie avec sentinelle (un argument omis préserve la valeur, `null`
  /// explicite le remet à `null`). Couvre [extension]/[extra] (ignorés du
  /// `copyWith` généré).
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
        // Même fonction nommée qu'en `fromMap` — `copyWith` ne peut pas
        // rouvrir le filtre des clés réservées.
        extra: identical(extra, _$undefined)
            ? this.extra
            : _sanitizeExtra(extra as Map<String, dynamic>),
      );

  /// Décode défensivement l'extension via [parser] (repli `null`).
  static ZExtension? _decodeExtension(
    Object? raw,
    ZSessionConfigExtensionParser? parser,
  ) {
    // Un hôte sans parser doit préserver verbatim ce qu'il n'a pas su
    // typer plutôt que le détruire au décodage : `extension` étant une clé
    // connue (donc exclue d'`extra`), un `null` inconditionnel effacerait
    // le payload d'un autre hôte avant toute ligne de code applicatif.
    return zDecodeExtension(raw, parser);
  }

  /// Clés persistées réservées (champs générés + `extension` + clés de
  /// synchronisation) — dérivées des spécifications de champ générées.
  ///
  /// Le spread des clés de synchronisation (`updated_at`, `is_deleted`) est
  /// obligatoire pour toute entité annotée : l'entité est enregistrée au
  /// registre (nature `'study_session_config'`) donc persistable comme
  /// document autonome, et les stores écrivent leurs métadonnées de
  /// synchronisation dans le corps avant de passer la map complète à
  /// [fromMap]. Sans ce spread, ces clés — propriété du store, pas du
  /// domaine — atterriraient dans [extra] et seraient réémises par [toMap]
  /// (invariant AD-9 : soft-delete hors-entité).
  ///
  /// C'est le patron canonique du kernel : toute entité annotée le
  /// reproduit à l'identique.
  static final Set<String> _reservedKeys = <String>{
    for (final spec in $ZStudySessionConfigFieldSpecs) spec.name,
    'extension',
    ...ZSyncMeta.reservedKeys,
  };

  /// Extrait `extra` = clés non réservées de [map] (round-trip préservé) —
  /// frontière d'entrée. C'est [_sanitizeExtra], la garde partagée.
  static Map<String, dynamic> _extraFrom(Map<String, dynamic> map) =>
      _sanitizeExtra(map);

  /// La garde partagée de `extra` — appelée par les trois voies :
  /// [fromMap], [copyWith] et [toMap]. Délègue à [zSanitizeExtra]
  /// (`zcrud_core`, implémentation unique du dépôt).
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

bool _listEquals<T>(List<T>? a, List<T>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null) return false;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
