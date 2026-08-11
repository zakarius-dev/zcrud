/// Annotation de document partageable `ZDocumentAnnotation` — contenu
/// top-level à identité propre (`ZEntity` + `ZExtensible`).
///
/// Surlignage (sélection de texte) ou note ancrée (point sur la page),
/// persisté dans une sous-collection sous le document — sous-arbre
/// partageable, pas un état personnel.
///
/// ## Aucune clé de mise à jour ni de suppression inline
///
/// Cette entité ne déclare ni `updatedAt` ni `isDeleted` (ni sous
/// `updated_at`/`is_deleted`). Le soft-delete et l'autorité Last-Write-Wins
/// vivent hors-entité, dans `ZSyncMeta` (invariant AD-9). [createdAt] est
/// conservé : sa clé `created_at` est distincte de toute clé réservée
/// (même politique que `ZStudyFolder.archivedAt`). Les clés réservées
/// incluent celles de `ZSyncMeta` — c'est le rempart contre toute fuite.
///
/// Un portage verbatim d'un schéma legacy qui logerait `updatedAt` inline
/// dans le corps métier de l'annotation recréerait une perte de données :
/// `updatedAt` deviendrait littéralement l'autorité Last-Write-Wins de
/// l'annotation partagée, alors que les stores écrivent la métadonnée de
/// synchronisation dans le corps, après le corps métier, à chaque écriture
/// — ce qui écraserait silencieusement un tel champ.
///
/// ## Patron `extra` intégral
///
/// Constructeur `const` qui ne filtre rien, slot brut lu nulle part
/// ailleurs, accesseur [extra] normalisant (le seul point traversé par
/// toutes les voies), garde partagée entre `fromMap` et `copyWith`, [toMap]
/// étalant l'accesseur `...extra`, `copyWith` à sentinelle couvrant tous
/// les champs, égalité profonde (`zJsonEquals` / `zJsonHash` + comparaison
/// élément par élément sur [rects]).
///
/// ## Tous les champs sont codegen-ables — aucun canal `Map` hors-codegen
///
/// [bounds] (sous-modèle) et [rects] (liste de sous-modèles) sont
/// codegen-ables : `ZAnnotationBounds` est un `@ZcrudModel`. Il n'y a pas de
/// canal type `Map` ici ; les seuls slots hors-codegen sont
/// [extension]/[extra].
///
/// ## `colorKey` brute — aucun clamp entité
///
/// Même politique que `ZFlashcardTag.colorKey` / `ZStudyFolder.colorKey` :
/// la borne de palette est injectée à l'affichage (`remapColorKey`), jamais
/// dans le domaine.
///
/// Éphémère (invariant AD-14) : `isEphemeral` provient de `ZEntity` (`id ==
/// null`), jamais attribué par l'entité.
library;

import 'package:zcrud_annotations/zcrud_annotations.dart';
import 'package:zcrud_core/domain.dart';

import 'z_annotation_bounds.dart';
import 'z_document_annotation_kind.dart';

part 'z_document_annotation.g.dart';

/// Reconstruit une [ZExtension] concrète depuis sa map JSON, ou `null`.
///
/// Fourni par l'application/le satellite (convention `X.fromJsonSafe`) et
/// injecté dans [ZDocumentAnnotation.fromMap] : le cœur ne connaît pas les
/// sous-classes concrètes (invariant AD-4). Toute exception est absorbée en
/// `null` par [ZExtension.guard] (invariant AD-10).
typedef ZDocumentAnnotationExtensionParser = ZExtension? Function(
    Map<String, dynamic> json);

/// Annotation d'un document — contenu partageable à identité propre.
@ZcrudModel(kind: 'document_annotation')
class ZDocumentAnnotation extends ZEntity with ZExtensible {
  /// Construit une annotation (constructeur nominal `const` — source du
  /// `copyWith`).
  const ZDocumentAnnotation({
    this.id,
    this.docId = '',
    this.page = 1,
    this.kind = ZDocumentAnnotationKind.highlight,
    this.colorKey = '',
    this.bounds = const ZAnnotationBounds(),
    this.rects,
    this.text,
    this.createdAt,
    this.extension,
    Map<String, dynamic> extra = const <String, dynamic>{},
    // Un paramètre nommé ne peut pas être privé en Dart, mais le slot brut
    // doit rester privé — c'est l'accesseur `extra` qui porte la garde.
    // ignore: prefer_initializing_formals
  }) : _extra = extra;

  /// Reconstruit défensivement depuis une map persistée (invariant AD-10).
  ///
  /// Délègue au décodeur généré (défauts sûrs : `doc_id`/`color_key`
  /// absents → `''` ; `page` absent/non numérique → `1` ; `kind`
  /// inconnu/`null`/non-`String` → [ZDocumentAnnotationKind.highlight], la
  /// première constante déclarée ; `bounds` corrompu — non-map, scalaire —
  /// → `ZAnnotationBounds(0,0,0,0)` (chemin sous-modèle défensif) ; chaque
  /// élément de `rects` décodé par élément — un élément corrompu est ignoré,
  /// chaque survivant auto-clampé `[0,1]` via `ZAnnotationBounds.fromMap` ;
  /// date illisible → `null`), puis sanitise [page] via [sanitizePage] — le
  /// codegen ne borne pas.
  ///
  /// Puis câble les deux canaux hors-codegen : [extension] (via
  /// [extensionParser], repli `null`) et [extra] (clés non réservées de la
  /// map — round-trip préservé).
  ///
  /// Corps non nu obligatoire (`ZExtensible`) : une délégation nue au
  /// décodeur généré laisserait [extra] vide, ce que le build refuse.
  ///
  /// Aucun cas ne lève — pas même `ZDocumentAnnotation.fromMap(const {})`.
  factory ZDocumentAnnotation.fromMap(
    Map<String, dynamic> map, {
    ZDocumentAnnotationExtensionParser? extensionParser,
  }) {
    final base = _$ZDocumentAnnotationFromMap(map);
    return ZDocumentAnnotation(
      id: base.id,
      docId: base.docId,
      // `page` est 1-based ⇒ `< 1` (corruption) ⇒ `1`. Même fonction
      // nommée qu'en `copyWith` (l'invariant tient aux deux frontières,
      // désérialisation ET mutation applicative).
      page: sanitizePage(base.page),
      kind: base.kind,
      // Brute — aucun clamp (même politique que `ZFlashcardTag.colorKey`).
      colorKey: base.colorKey,
      // Sous-modèle déjà décodé/clampé par le codegen via ZAnnotationBounds.fromMap.
      bounds: base.bounds,
      // Liste de sous-modèles : éléments corrompus déjà ignorés, survivants
      // auto-clampés `[0,1]`.
      rects: base.rects,
      text: base.text,
      createdAt: base.createdAt,
      extension: _decodeExtension(map['extension'], extensionParser),
      extra: _extraFrom(map),
    );
  }

  /// Identité opaque (`null` pour l'éphémère — invariant AD-14 ; jamais
  /// attribuée par l'entité).
  @override
  @ZcrudId()
  final String? id;

  /// Document d'appartenance (`== ZStudyDocument.id`) — persisté `doc_id`,
  /// défaut `''`.
  @ZcrudField()
  final String docId;

  /// Numéro de page 1-based (aligné sur les conventions habituelles de
  /// viewer PDF) — défaut `1` ; jamais `< 1` (voir [sanitizePage]).
  @ZcrudField(defaultValue: 1)
  final int page;

  /// Nature de l'annotation (surlignage / note ancrée).
  ///
  /// Défaut défensif [ZDocumentAnnotationKind.highlight] — première
  /// constante de l'enum (le repli généré d'un enum non-nullable est la
  /// première constante déclarée).
  @ZcrudField()
  final ZDocumentAnnotationKind kind;

  /// Clé de couleur symbolique brute (persistée `color_key`, snake_case ;
  /// défaut `''`). Stockée verbatim, aucun clamp dans l'entité — la borne
  /// est palette-dépendante, résolue à l'affichage par `remapColorKey`.
  @ZcrudField()
  final String colorKey;

  /// Rectangle d'ancrage (enveloppe pour un surlignage, point pour une
  /// note), fractions `[0,1]` — sous-modèle `@ZcrudModel` décodé
  /// défensivement (map corrompue ⇒ `(0,0,0,0)`, jamais de `throw` du
  /// parent). Défaut `const ZAnnotationBounds()`.
  @ZcrudField()
  final ZAnnotationBounds bounds;

  /// Rects des lignes d'un surlignage multi-lignes (fractions `[0,1]`),
  /// `null` ou vide pour une note ancrée / un surlignage mono-ligne.
  ///
  /// L'immuabilité de cette `List` n'est profonde que via [fromMap]/
  /// [copyWith] (chaque élément re-décodé/clampé) — pas via le constructeur
  /// `const`, qui reçoit la référence telle quelle.
  @ZcrudField()
  final List<ZAnnotationBounds>? rects;

  /// Texte : contenu d'une note ancrée, ou extrait surligné (pour un
  /// panneau de navigation).
  @ZcrudField()
  final String? text;

  /// Date de création — clé persistée `created_at`, distincte de toute clé
  /// réservée de `ZSyncMeta`. `null` si absente/illisible.
  ///
  /// Il n'y a volontairement aucun `updatedAt` ici : la clé
  /// Last-Write-Wins est hors-entité (`ZSyncMeta.updatedAt`) — voir la
  /// dartdoc de bibliothèque.
  @ZcrudField()
  final DateTime? createdAt;

  /// Slot type additif versionné (invariant AD-4), `null` si absent.
  /// Hors-codegen.
  @override
  final ZExtension? extension;

  /// Échappatoire non typée (invariant AD-4), défaut `const {}` (jamais
  /// `null`), préservant les clés inconnues du cœur au round-trip.
  /// Hors-codegen.
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

  /// Ramène un numéro de page dans son domaine 1-based — ne lève jamais.
  ///
  /// `raw < 1` ⇒ `1` (une annotation a au moins une page d'ancrage ; un
  /// `<= 0` n'est pas une page). Déclarée publique et nommée : la garde est
  /// ainsi la même fonction aux deux frontières ([fromMap] et [copyWith]).
  ///
  /// Nuance vs le sanitizer de nombre de pages de `ZStudyDocument`
  /// (nullable « inconnu », `<= 0 ⇒ null`) : ici [page] est non-null et
  /// requis ⇒ repli déterministe `1`.
  static int sanitizePage(int raw) => raw < 1 ? 1 : raw;

  /// Sérialise vers la map persistée complète (snake_case), zéro-perte.
  ///
  /// Réutilise le `toMap()` généré (champs du schéma, dont [bounds]/[rects]
  /// imbriqués) puis superpose les canaux hors-codegen : [extra] (clés
  /// inconnues préservées) et [extension].
  ///
  /// Ne réémet ni clé de mise à jour ni clé de suppression logique
  /// (garanti par construction : ces clés ne peuvent pas entrer dans
  /// [extra], donc ne peuvent pas en ressortir — invariant AD-9).
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      // Étale l'accesseur (qui normalise), jamais le champ brut `_extra`.
      // `toMap()` est la frontière de sortie : la seule que toutes les
      // voies d'écriture traversent ⇒ promesse inconditionnelle
      // (constructeur nominal `const` compris).
      ...extra,
      ...ZDocumentAnnotationZcrud(this).toMap(),
    };
    if (extension != null) {
      map['extension'] = extension!.toJson();
    }
    return map;
  }

  /// Copie à sentinelle (un argument omis préserve la valeur, `null`
  /// explicite le remet à `null`) — couvre tous les champs, [extension] et
  /// [extra] compris (que le `copyWith` généré remettrait à leurs défauts,
  /// faute d'annotation : perte silencieuse évitée ici). Masque le
  /// `copyWith` de l'extension.
  ///
  /// [page] est sanitisé — exactement comme dans [fromMap] (un invariant
  /// de valeur a deux frontières ; ne fermer que la désérialisation
  /// laisserait la garde rouvrable par mutation applicative). [colorKey]
  /// reste brute. [bounds]/[rects] restent tels que fournis (leur clamp
  /// est la responsabilité de `ZAnnotationBounds`).
  ZDocumentAnnotation copyWith({
    Object? id = _$undefined,
    Object? docId = _$undefined,
    Object? page = _$undefined,
    Object? kind = _$undefined,
    Object? colorKey = _$undefined,
    Object? bounds = _$undefined,
    Object? rects = _$undefined,
    Object? text = _$undefined,
    Object? createdAt = _$undefined,
    Object? extension = _$undefined,
    Object? extra = _$undefined,
  }) {
    final nextPage = identical(page, _$undefined) ? this.page : page as int;
    return ZDocumentAnnotation(
      id: identical(id, _$undefined) ? this.id : id as String?,
      docId: identical(docId, _$undefined) ? this.docId : docId as String,
      // Même fonction nommée qu'en `fromMap`.
      page: sanitizePage(nextPage),
      kind: identical(kind, _$undefined)
          ? this.kind
          : kind as ZDocumentAnnotationKind,
      colorKey:
          identical(colorKey, _$undefined) ? this.colorKey : colorKey as String,
      bounds: identical(bounds, _$undefined)
          ? this.bounds
          : bounds as ZAnnotationBounds,
      rects: identical(rects, _$undefined)
          ? this.rects
          : rects as List<ZAnnotationBounds>?,
      text: identical(text, _$undefined) ? this.text : text as String?,
      createdAt: identical(createdAt, _$undefined)
          ? this.createdAt
          : createdAt as DateTime?,
      extension: identical(extension, _$undefined)
          ? this.extension
          : extension as ZExtension?,
      // Même fonction nommée qu'en `fromMap` — `copyWith` ne peut pas
      // rouvrir le filtre des clés réservées.
      extra: identical(extra, _$undefined)
          ? this.extra
          : _sanitizeExtra(extra as Map<String, dynamic>),
    );
  }

  /// Décode défensivement l'extension via [parser] (repli `null`).
  static ZExtension? _decodeExtension(
    Object? raw,
    ZDocumentAnnotationExtensionParser? parser,
  ) {
    // Un hôte sans parser doit préserver verbatim ce qu'il n'a pas su
    // typer plutôt que le détruire au décodage : `extension` étant une clé
    // connue (donc exclue d'`extra`), un `null` inconditionnel effacerait
    // le payload d'un autre hôte avant toute ligne de code applicatif.
    return zDecodeExtension(raw, parser);
  }

  /// Clés persistées réservées (champs générés + `extension` + clés de
  /// synchronisation) — dérivées des spécifications de champ générées pour
  /// rester synchrones avec le codegen.
  ///
  /// Le spread des clés de synchronisation est essentiel : cette entité
  /// est partageable et le store écrit ses métadonnées dans le corps avant
  /// de passer la map complète à [fromMap]. Sans ce spread, ces clés —
  /// propriété du store — atterriraient dans [extra] (invariant AD-4
  /// violé : `extra` = clés inconnues du domaine) puis seraient réémises
  /// par [toMap] (invariant AD-9 violé), cassant l'égalité entre une
  /// annotation en mémoire et la même relue du store. `ZDocumentAnnotation`
  /// ne déclarant aucun champ de synchronisation, c'est ce spread — et lui
  /// seul — qui l'empêche.
  static final Set<String> _reservedKeys = <String>{
    for (final spec in $ZDocumentAnnotationFieldSpecs) spec.name,
    'extension',
    ...ZSyncMeta.reservedKeys,
  };

  /// Extrait `extra` = clés non réservées de [map] (round-trip préservé) —
  /// frontière d'entrée. C'est [_sanitizeExtra], la garde partagée.
  static Map<String, dynamic> _extraFrom(Map<String, dynamic> map) =>
      _sanitizeExtra(map);

  /// La garde partagée de `extra` — appelée par [fromMap] et [copyWith]
  /// (jamais divergentes). Délègue à [zSanitizeExtra] (`zcrud_core`,
  /// implémentation unique du dépôt).
  static Map<String, dynamic> _sanitizeExtra(Map<String, dynamic> raw) =>
      zSanitizeExtra(raw, _reservedKeys);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZDocumentAnnotation &&
          id == other.id &&
          docId == other.docId &&
          page == other.page &&
          kind == other.kind &&
          colorKey == other.colorKey &&
          bounds == other.bounds &&
          _listEquals(rects, other.rects) &&
          text == other.text &&
          createdAt == other.createdAt &&
          extension == other.extension &&
          zJsonEquals(extra, other.extra);

  @override
  int get hashCode => Object.hashAll(<Object?>[
        id,
        docId,
        page,
        kind,
        colorKey,
        bounds,
        if (rects != null) Object.hashAll(rects!),
        text,
        createdAt,
        extension,
        zJsonHash(extra),
      ]);
}

/// Égalité élément par élément (même patron qu'ailleurs pour les listes de
/// sous-modèles).
bool _listEquals<T>(List<T>? a, List<T>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null) return false;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
