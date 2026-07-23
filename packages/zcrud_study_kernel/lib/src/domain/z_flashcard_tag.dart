/// Entité canonique `ZFlashcardTag` — tag de flashcard **first-class** (ES-2.3,
/// FR-S6, AC1/AC4/AC6/AC7/AC8 — décisions D2/D4).
///
/// origine: lex_core (module « Étude ») — `FlashcardTag` (`{id, title,
/// colorKey}`, `@JsonSerializable(fieldRename: snake)`). Remplace la liste
/// `tagIds` nue (des `String`) par une **entité à identité propre** (UUID assigné
/// par le repository — ES-8.1, jamais par l'entité, AD-14).
///
/// **DEUX rejets structurels de la source lex (D3, porté par `remapColorKey`)** :
/// lex **verrouille la palette à 8 clés en dur** (`allowedColorKeys`) et
/// **remappe par SHA-256** (`package:crypto`). zcrud **rejette les deux** : la
/// couleur est une `colorKey` `String` symbolique bornée par une palette
/// **injectée** À L'AFFICHAGE (`remapColorKey`), jamais dans l'entité.
///
/// **Généré par `@ZcrudModel` (AD-3)** : `melos run generate` émet
/// `z_flashcard_tag.g.dart` portant `_$ZFlashcardTagFromMap`, l'extension
/// `ZFlashcardTagZcrud` (`toMap`/`copyWith`), `$ZFlashcardTagFieldSpecs`,
/// `registerZFlashcardTag(ZcrudRegistry)` et le garde runtime
/// `_$zRequireExtraPreserved`.
///
/// **Patron `extra` ES-2.2b INTÉGRAL** (jumeau `ZStudySessionConfig` /
/// `ZStudyFolder`) : constructeur `const` qui **ne filtre RIEN** (`: _extra =
/// extra;`), slot brut [_extra] **lu nulle part ailleurs**, accesseur [extra]
/// **normalisant** (le SEUL point traversé par TOUTES les voies), garde partagée
/// [_sanitizeExtra] (`fromMap` **ET** `copyWith`), `toMap()` étalant l'**accesseur**
/// `...extra`, `copyWith` **à sentinelle** couvrant TOUS les champs, égalité
/// **profonde** `zJsonEquals`/`zJsonHash`.
///
/// **`colorKey` BRUT — aucun clamp dans l'entité (D4)** : suit le précédent EXACT
/// `ZStudyFolder.colorKey` (`@ZcrudField String` libre, « résolue côté UI »). Le
/// clamp exigerait la palette INJECTÉE que le domaine ne possède pas (c'est un
/// seam de présentation) : clamper ici forcerait soit une palette codée en dur
/// (viole AD-13), soit l'injection de la palette dans `fromMap` (fait fuiter la
/// présentation dans le domaine). ⇒ `colorKey` **n'a AUCUN invariant de valeur au
/// niveau entité** ; il est borné À L'AFFICHAGE par
/// `remapColorKey(palette, rawColorKey: tag.colorKey, seedTitle: tag.title)` chez
/// le consommateur (ES-8.1). La leçon H2 (garde partagée `fromMap`/`copyWith`) ne
/// s'applique donc **PAS** à `colorKey` — il n'y a rien à garder. **Ce n'est pas
/// un oubli** : c'est un choix, la borne étant palette-dépendante.
///
/// **AD-19 (D8)** : aucun `updatedAt`/`isDeleted` inline — le soft-delete du tag
/// et la fraîcheur LWW vivent **hors-entité** (`ZSyncMeta`, repository — AD-16).
/// [_reservedKeys] ⊇ `ZSyncMeta.reservedKeys` : les clés de sync (propriété du
/// STORE) ne polluent jamais [extra] et ne sont jamais réémises par [toMap].
///
/// **Éphémère (AD-14)** : `isEphemeral` provient de `ZEntity` (`id == null`),
/// non redéfini. L'entité n'attribue jamais d'`id`.
library;

import 'package:zcrud_annotations/zcrud_annotations.dart';
import 'package:zcrud_core/domain.dart';

part 'z_flashcard_tag.g.dart';

/// Reconstruit une [ZExtension] concrète depuis sa map JSON, ou `null`.
///
/// Fourni par l'app/le satellite (convention `X.fromJsonSafe`) et injecté dans
/// [ZFlashcardTag.fromMap] : le cœur ne connaît pas les sous-classes concrètes
/// (AD-4). Toute exception est absorbée en `null` par [ZExtension.guard] (AD-10).
typedef ZFlashcardTagExtensionParser = ZExtension? Function(
    Map<String, dynamic> json);

/// Tag de flashcard canonique immuable (données + `copyWith` ; identité opaque).
@ZcrudModel(kind: 'flashcard_tag', fieldRename: ZFieldRename.snake)
class ZFlashcardTag extends ZEntity with ZExtensible {
  /// Construit un tag (constructeur nominal `const` — source du `copyWith`).
  const ZFlashcardTag({
    this.id,
    this.title = '',
    this.colorKey = '',
    this.extension,
    Map<String, dynamic> extra = const <String, dynamic>{},
    // ⚠️ Le « fix » du lint (`this._extra`) est **ILLÉGAL** en Dart : un paramètre
    // NOMMÉ ne peut pas être privé (PRIVATE_OPTIONAL_PARAMETER). Or le slot brut
    // DOIT rester privé — c'est l'ACCESSEUR `extra` qui porte la garde (ES-2.2b).
    // ignore: prefer_initializing_formals
  }) : _extra = extra;

  /// Reconstruit **défensivement** depuis une map persistée (AD-10).
  ///
  /// Recopie les champs du `_$ZFlashcardTagFromMap` **généré** (défauts sûrs :
  /// `title`/`color_key` absents → `''`, `id` absent → `null`) PUIS câble les deux
  /// canaux hors-codegen : [extension] (repli `null`, `ZExtension.guard`) et
  /// [extra] = clés **non réservées** de la map (round-trip préservé).
  ///
  /// ⛔ **Ne délègue JAMAIS nuement** à `_$ZFlashcardTagFromMap` (le build
  /// passerait ROUGE via `_rejectNakedCodegenDelegation` — l'entité est
  /// `ZExtensible`) : elle **peuple `extra: _extraFrom(map)`**. Aucun cas ne fait
  /// échouer le parent (map vide, `extension` corrompue…).
  factory ZFlashcardTag.fromMap(
    Map<String, dynamic> map, {
    ZFlashcardTagExtensionParser? extensionParser,
  }) {
    final base = _$ZFlashcardTagFromMap(map);
    return ZFlashcardTag(
      id: base.id,
      title: base.title,
      colorKey: base.colorKey,
      extension: _decodeExtension(map['extension'], extensionParser),
      extra: _extraFrom(map),
    );
  }

  /// Identité opaque (nullable pour l'éphémère — AD-14 ; jamais attribuée par
  /// l'entité, matérialisée au repository ES-8.1).
  @override
  @ZcrudId()
  final String? id;

  /// Libellé affiché du tag (défaut `''` si absent — AC1).
  @ZcrudField(label: 'Tag')
  final String title;

  /// Clé de couleur symbolique **BRUTE** (persistée `color_key`, snake_case ;
  /// défaut `''`). **Stockée VERBATIM, AUCUN clamp dans l'entité (D4)** — la borne
  /// est palette-dépendante et résolue À L'AFFICHAGE par `remapColorKey` chez le
  /// consommateur. Précédent EXACT : `ZStudyFolder.colorKey`.
  @ZcrudField()
  final String colorKey;

  /// Slot type additif **versionné** (AD-4 pt.1), `null` si absent. Hors-codegen.
  @override
  final ZExtension? extension;

  /// Slot `extra` **BRUT tel que reçu par le constructeur** — jamais lu ailleurs
  /// que dans l'accesseur [extra] (**JAMAIS** dans `toMap`, `==`, `hashCode`).
  ///
  /// Il peut être **POLLUÉ** : le constructeur nominal est `const`, il ne peut
  /// appeler **aucune** fonction (et AD-10 y interdit l'`assert`). C'est
  /// l'accesseur qui porte la garde.
  final Map<String, dynamic> _extra;

  /// Échappatoire non typée (AD-4 pt.2), défaut `const {}` (jamais `null`),
  /// préservant les clés inconnues du cœur au round-trip. Hors-codegen.
  ///
  /// 🔴 **GARDE (ES-2.2b/HIGH-2)** : l'accesseur **NORMALISE** ([zNormalizeExtra])
  /// — il ne rend **JAMAIS** une clé réservée, **quelle que soit la voie
  /// d'écriture** (y compris le constructeur `const`, seule voie incapable de
  /// filtrer). C'est **le seul point que TOUTES les voies traversent** ⇒ la
  /// promesse est **INCONDITIONNELLE**, sans `assert` et sans `throw` (AD-10), et
  /// sans perdre `const`.
  @override
  Map<String, dynamic> get extra => zNormalizeExtra(_extra, _reservedKeys);

  /// Sérialise vers la map persistée **complète** (snake_case).
  ///
  /// Réutilise le `toMap()` **généré** (`id`/`title`/`color_key`) puis superpose
  /// les deux canaux hors-codegen : [extra] (clés inconnues préservées) et
  /// [extension].
  ///
  /// Ne produit **JAMAIS** de clé `updated_at`/`is_deleted` (garanti par
  /// construction : [_reservedKeys] ⊇ `ZSyncMeta.reservedKeys` ⇒ la clé ne peut
  /// entrer dans [extra], donc plus en ressortir — AD-16).
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      // 🔴 ES-2.2b (remédiation HIGH-1) — étale l'**ACCESSEUR** (qui NORMALISE),
      // jamais le champ brut `_extra`. C'est ce qui rend la promesse
      // INCONDITIONNELLE, y compris pour une instance née du constructeur
      // nominal (`const` : il ne peut RIEN filtrer). Un `_sanitizeExtra(extra)`
      // ICI serait DÉCORATIF — la garde vit à l'accesseur.
      ...extra,
      ...ZFlashcardTagZcrud(this).toMap(),
    };
    if (extension != null) {
      map['extension'] = extension!.toJson();
    }
    return map;
  }

  /// Copie avec sentinelle (un argument omis préserve la valeur, `null` explicite
  /// le remet à `null`). Couvre **TOUS** les champs, y compris [extension] et
  /// [extra] (que le `copyWith` **généré** ignore, faute d'annotation, et
  /// remettrait aux défauts → perte silencieuse — H3).
  ZFlashcardTag copyWith({
    Object? id = _$undefined,
    Object? title = _$undefined,
    Object? colorKey = _$undefined,
    Object? extension = _$undefined,
    Object? extra = _$undefined,
  }) =>
      ZFlashcardTag(
        id: identical(id, _$undefined) ? this.id : id as String?,
        title: identical(title, _$undefined) ? this.title : title as String,
        colorKey:
            identical(colorKey, _$undefined) ? this.colorKey : colorKey as String,
        extension: identical(extension, _$undefined)
            ? this.extension
            : extension as ZExtension?,
        // 🔴 ES-2.2b : MÊME FONCTION NOMMÉE qu'en `fromMap` — `copyWith` ne peut
        // plus ROUVRIR le filtre des clés réservées.
        extra: identical(extra, _$undefined)
            ? this.extra
            : _sanitizeExtra(extra as Map<String, dynamic>),
      );

  /// Décode défensivement l'extension via [parser] (repli `null`).
  static ZExtension? _decodeExtension(
    Object? raw,
    ZFlashcardTagExtensionParser? parser,
  ) {
    // CR-LEX-33 : le corps de cette méthode était `if (parser == null) return
    // null;` — un hôte SANS parser lisait `null`, et comme `extension` est une
    // clé CONNUE (donc exclue d'`extra`), le payload d'un AUTRE hôte était
    // DÉTRUIT au décodage, avant toute ligne de code applicatif. Le cœur
    // préserve désormais verbatim ce que personne n'a su typer.
    return zDecodeExtension(raw, parser);
  }

  /// Clés persistées **réservées** (champs générés + `extension` + **clés de sync
  /// hors-entité AD-19**) — dérivées de `$ZFlashcardTagFieldSpecs`.
  ///
  /// `...ZSyncMeta.reservedKeys` (`updated_at`, `is_deleted`) est **essentiel** :
  /// les stores écrivent ces clés **dans le corps** puis passent la map complète
  /// à [ZFlashcardTag.fromMap]. Sans cette réserve, `is_deleted` (pas un champ
  /// déclaré) atterrirait dans [extra] et serait **réémis** par [toMap] — une
  /// préoccupation de store qui fuit dans le domaine (AD-16).
  static final Set<String> _reservedKeys = <String>{
    for (final spec in $ZFlashcardTagFieldSpecs) spec.name,
    'extension',
    ...ZSyncMeta.reservedKeys,
  };

  /// Extrait `extra` = clés non réservées de [map] (round-trip préservé) —
  /// **frontière d'ENTRÉE**. C'est [_sanitizeExtra], la garde **partagée**.
  static Map<String, dynamic> _extraFrom(Map<String, dynamic> map) =>
      _sanitizeExtra(map);

  /// 🔴 **GARDE PARTAGÉE de `extra`** (ES-2.2b) — appelée par les voies CAPABLES
  /// de filtrer : [fromMap] **et** [copyWith] (jamais divergentes — leçon H2).
  /// Délègue à [zSanitizeExtra] (`zcrud_core`, implémentation UNIQUE du repo).
  static Map<String, dynamic> _sanitizeExtra(Map<String, dynamic> raw) =>
      zSanitizeExtra(raw, _reservedKeys);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZFlashcardTag &&
          id == other.id &&
          title == other.title &&
          colorKey == other.colorKey &&
          extension == other.extension &&
          zJsonEquals(extra, other.extra);

  @override
  int get hashCode => Object.hashAll(<Object?>[
        id,
        title,
        colorKey,
        extension,
        zJsonHash(extra),
      ]);
}
