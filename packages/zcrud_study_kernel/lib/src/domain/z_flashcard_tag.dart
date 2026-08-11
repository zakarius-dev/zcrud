/// Entité canonique `ZFlashcardTag` — tag de flashcard first-class.
///
/// Un tag est une entité à identité propre (identifiant assigné par le
/// repository, jamais par l'entité — invariant AD-14), plutôt qu'une simple
/// `String` dans une liste `tagIds`.
///
/// La couleur d'un tag est une `colorKey` `String` symbolique, bornée par
/// une palette **injectée à l'affichage** (`remapColorKey`), jamais figée en
/// dur ni hachée cryptographiquement dans l'entité.
///
/// Généré par `@ZcrudModel` (invariant AD-3) : `melos run generate` émet le
/// fichier compagnon portant le décodeur défensif, l'extension `toMap`/
/// `copyWith`, les spécifications de champ, l'enregistrement au registre et
/// une garde runtime de préservation d'`extra`.
///
/// **Patron `extra` intégral** (jumeau `ZStudySessionConfig` /
/// `ZStudyFolder`) : constructeur `const` qui ne filtre rien, slot brut lu
/// nulle part ailleurs, accesseur `extra` normalisant (le seul point
/// traversé par toutes les voies), garde partagée entre `fromMap` et
/// `copyWith`, `toMap()` étalant l'accesseur `...extra`, `copyWith` à
/// sentinelle couvrant tous les champs, égalité profonde.
///
/// `colorKey` est stockée brute — aucun clamp dans l'entité : le clamp
/// exigerait la palette injectée, que le domaine ne possède pas (c'est un
/// seam de présentation). Clamper ici forcerait soit une palette codée en
/// dur (viole l'invariant AD-13), soit l'injection de la palette dans
/// `fromMap` (fait fuiter la présentation dans le domaine). `colorKey` n'a
/// donc aucun invariant de valeur au niveau entité ; elle est bornée à
/// l'affichage par `remapColorKey(palette, rawColorKey: tag.colorKey,
/// seedTitle: tag.title)` chez le consommateur.
///
/// Aucune clé de synchronisation (mise à jour, suppression) inline — le
/// soft-delete du tag et la fraîcheur Last-Write-Wins vivent hors-entité
/// (`ZSyncMeta`, côté repository — invariant AD-9). Les clés de
/// synchronisation ne polluent jamais `extra` et ne sont jamais réémises par
/// `toMap`.
///
/// Éphémère (invariant AD-14) : `isEphemeral` provient de `ZEntity` (`id ==
/// null`), non redéfini. L'entité n'attribue jamais d'identifiant.
library;

import 'package:zcrud_annotations/zcrud_annotations.dart';
import 'package:zcrud_core/domain.dart';

part 'z_flashcard_tag.g.dart';

/// Reconstruit une [ZExtension] concrète depuis sa map JSON, ou `null`.
///
/// Fourni par l'application/le satellite (convention `X.fromJsonSafe`) et
/// injecté dans [ZFlashcardTag.fromMap] : le cœur ne connaît pas les
/// sous-classes concrètes (invariant AD-4). Toute exception est absorbée en
/// `null` par [ZExtension.guard] (invariant AD-10).
typedef ZFlashcardTagExtensionParser = ZExtension? Function(
    Map<String, dynamic> json);

/// Tag de flashcard canonique immuable (données + `copyWith` ; identité
/// opaque).
@ZcrudModel(kind: 'flashcard_tag', fieldRename: ZFieldRename.snake)
class ZFlashcardTag extends ZEntity with ZExtensible {
  /// Construit un tag (constructeur nominal `const` — source du
  /// `copyWith`).
  const ZFlashcardTag({
    this.id,
    this.title = '',
    this.colorKey = '',
    this.extension,
    Map<String, dynamic> extra = const <String, dynamic>{},
    // Un paramètre nommé ne peut pas être privé en Dart, mais le slot brut
    // doit rester privé — c'est l'accesseur `extra` qui porte la garde.
    // ignore: prefer_initializing_formals
  }) : _extra = extra;

  /// Reconstruit défensivement depuis une map persistée (invariant AD-10).
  ///
  /// Recopie les champs du décodeur généré (défauts sûrs : `title`/
  /// `color_key` absents → `''`, `id` absent → `null`) puis câble les deux
  /// canaux hors-codegen : [extension] (repli `null`, protégé par
  /// [ZExtension.guard]) et [extra] (clés non réservées de la map,
  /// round-trip préservé).
  ///
  /// Ne délègue jamais nuement au décodeur généré (l'entité est
  /// `ZExtensible`) : elle peuple `extra` explicitement. Aucun cas ne fait
  /// échouer le parent (map vide, extension corrompue…).
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

  /// Identité opaque (nullable pour l'éphémère — invariant AD-14 ; jamais
  /// attribuée par l'entité, matérialisée au repository).
  @override
  @ZcrudId()
  final String? id;

  /// Libellé affiché du tag (défaut `''` si absent).
  @ZcrudField(label: 'Tag')
  final String title;

  /// Clé de couleur symbolique brute (persistée `color_key`, snake_case ;
  /// défaut `''`). Stockée verbatim, aucun clamp dans l'entité — la borne
  /// est palette-dépendante et résolue à l'affichage par `remapColorKey`
  /// chez le consommateur. Même politique que `ZStudyFolder.colorKey`.
  @ZcrudField()
  final String colorKey;

  /// Slot type additif versionné (invariant AD-4), `null` si absent.
  /// Hors-codegen.
  @override
  final ZExtension? extension;

  /// Slot `extra` brut tel que reçu par le constructeur — jamais lu
  /// ailleurs que dans l'accesseur [extra] (jamais dans `toMap`, `==`,
  /// `hashCode`).
  ///
  /// Il peut être pollué : le constructeur nominal est `const`, il ne peut
  /// appeler aucune fonction (et l'invariant AD-10 y interdit l'`assert`).
  /// C'est l'accesseur qui porte la garde.
  final Map<String, dynamic> _extra;

  /// Échappatoire non typée (invariant AD-4), défaut `const {}` (jamais
  /// `null`), préservant les clés inconnues du cœur au round-trip.
  /// Hors-codegen.
  ///
  /// Garde : l'accesseur normalise ([zNormalizeExtra]) — il ne rend jamais
  /// une clé réservée, quelle que soit la voie d'écriture (y compris le
  /// constructeur `const`, seule voie incapable de filtrer). C'est le seul
  /// point que toutes les voies traversent ⇒ la promesse est
  /// inconditionnelle, sans `assert` et sans `throw` (invariant AD-10), et
  /// sans perdre `const`.
  @override
  Map<String, dynamic> get extra => zNormalizeExtra(_extra, _reservedKeys);

  /// Sérialise vers la map persistée complète (snake_case).
  ///
  /// Réutilise le `toMap()` généré (`id`/`title`/`color_key`) puis
  /// superpose les deux canaux hors-codegen : [extra] (clés inconnues
  /// préservées) et [extension].
  ///
  /// Ne produit jamais de clé de synchronisation (mise à jour, suppression)
  /// : garanti par construction, ces clés ne peuvent pas entrer dans
  /// [extra], donc ne peuvent pas en ressortir (invariant AD-9).
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      // Étale l'accesseur (qui normalise), jamais le champ brut `_extra`.
      // C'est ce qui rend la promesse inconditionnelle, y compris pour une
      // instance née du constructeur nominal (`const` : il ne peut rien
      // filtrer).
      ...extra,
      ...ZFlashcardTagZcrud(this).toMap(),
    };
    if (extension != null) {
      map['extension'] = extension!.toJson();
    }
    return map;
  }

  /// Copie avec sentinelle (un argument omis préserve la valeur, `null`
  /// explicite le remet à `null`). Couvre tous les champs, y compris
  /// [extension] et [extra] (que le `copyWith` généré ignore, faute
  /// d'annotation, et remettrait aux défauts — perte silencieuse évitée
  /// ici).
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
        // Même fonction nommée qu'en `fromMap` — `copyWith` ne peut pas
        // rouvrir le filtre des clés réservées.
        extra: identical(extra, _$undefined)
            ? this.extra
            : _sanitizeExtra(extra as Map<String, dynamic>),
      );

  /// Décode défensivement l'extension via [parser] (repli `null`).
  static ZExtension? _decodeExtension(
    Object? raw,
    ZFlashcardTagExtensionParser? parser,
  ) {
    // Un hôte sans parser doit préserver verbatim ce qu'il n'a pas su
    // typer plutôt que le détruire au décodage : `extension` étant une clé
    // connue (donc exclue d'`extra`), un `null` inconditionnel effacerait
    // le payload d'un autre hôte avant toute ligne de code applicatif.
    return zDecodeExtension(raw, parser);
  }

  /// Clés persistées réservées (champs générés + `extension` + clés de
  /// synchronisation hors-entité) — dérivées des spécifications de champ
  /// générées.
  ///
  /// Inclure les clés de synchronisation (mise à jour, suppression) est
  /// essentiel : les stores écrivent ces clés dans le corps puis passent la
  /// map complète à [ZFlashcardTag.fromMap]. Sans cette réserve, une clé de
  /// suppression logique (pas un champ déclaré) atterrirait dans [extra] et
  /// serait réémise par [toMap] — une préoccupation de store qui fuit dans
  /// le domaine (invariant AD-9).
  static final Set<String> _reservedKeys = <String>{
    for (final spec in $ZFlashcardTagFieldSpecs) spec.name,
    'extension',
    ...ZSyncMeta.reservedKeys,
  };

  /// Extrait `extra` = clés non réservées de [map] (round-trip préservé) —
  /// frontière d'entrée. C'est [_sanitizeExtra], la garde partagée.
  static Map<String, dynamic> _extraFrom(Map<String, dynamic> map) =>
      _sanitizeExtra(map);

  /// Garde partagée de `extra` — appelée par les voies capables de filtrer :
  /// [fromMap] et [copyWith] (jamais divergentes). Délègue à
  /// [zSanitizeExtra] (`zcrud_core`, implémentation unique du dépôt).
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
