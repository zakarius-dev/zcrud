/// Annotation de document PARTAGEABLE `ZDocumentAnnotation` (ES-2.5, FR-S8) —
/// **contenu top-level à identité propre** (`ZEntity` + `ZExtensible`).
///
/// origine: lex_core (module « Étude ») —
/// `entities/education/document_annotation.dart` (`DocumentAnnotation`) :
/// surlignage (sélection de texte) ou sticky note (point ancré), persisté dans la
/// sous-collection `.../documents/{docId}/annotations/{id}` — **sous-arbre
/// partageable** (AD-26), pas un état personnel.
///
/// ## 🔴 AD-19 / D5 — `updatedAt` ET `isDeleted` inline lex SONT REJETÉS (cœur FR)
///
/// lex porte, **inline dans l'entité** : `final DateTime updatedAt;` (annotée
/// « Dernière mise à jour (LWW) » — **littéralement la clé d'autorité du merge**)
/// **et** `@JsonKey(defaultValue: false) final bool isDeleted;`. C'est **exactement**
/// le piège AD-19 **réalisé dans la source** — le contraste ES-2.1
/// (`ZStudyDocument`/`ZDocumentReadingState` ont retiré `updatedAt`/`isDeleted`
/// inline) reproduit ici, en **plus aigu** : `updatedAt` **EST** l'autorité LWW de
/// l'annotation partagée. Un portage verbatim recréerait la perte de données
/// soldée en ES-1.3 (les stores écrivent la méta de sync **dans le corps, APRÈS**
/// le corps métier, à chaque `put` ⇒ écrasement silencieux).
///
/// ⇒ Cette entité **ne déclare NI `updatedAt`, NI `isDeleted`** (ni sous
/// `updated_at`/`is_deleted`). Le soft-delete et l'autorité Last-Write-Wins vivent
/// **HORS-ENTITÉ**, dans `ZSyncMeta` (AD-16/AD-9). [createdAt] est **conservé** : sa
/// clé `created_at` est **DISTINCTE** de toute clé réservée (précédent
/// `ZStudyFolder.archivedAt`). [_reservedKeys] ⊇ `ZSyncMeta.reservedKeys` est **le**
/// rempart.
///
/// ## Patron `extra` ES-2.2b INTÉGRAL (jumeau `ZStudyDocument` / `ZFlashcardTag`)
///
/// Constructeur `const` qui **ne filtre RIEN** (`: _extra = extra;`), slot brut
/// [_extra] **lu nulle part ailleurs**, accesseur [extra] **normalisant** (le SEUL
/// point traversé par TOUTES les voies), garde partagée [_sanitizeExtra] (`fromMap`
/// **ET** `copyWith`), [toMap] étalant l'**accesseur** `...extra`, `copyWith` **à
/// sentinelle** couvrant TOUS les champs, égalité **profonde** `zJsonEquals` /
/// `zJsonHash` (+ [_listEquals] sur [rects]).
///
/// ## Tous les champs sont codegen-ables (D2) — AUCUN canal `Map` hors-codegen
///
/// [bounds] = sous-modèle (`subModel`) et [rects] = liste de sous-modèles
/// (`listModel`, précédent `ZFlashcard.choices`) sont **codegen-ables** :
/// `ZAnnotationBounds` est un `@ZcrudModel`. Il n'y a **PAS** de canal type
/// `learning`/`content`/`section_orders` ici ; les seuls slots hors-codegen sont
/// [extension]/[extra] (patron ES-2.2b).
///
/// ## `colorKey` BRUT — aucun clamp entité (D6)
///
/// Précédent EXACT `ZFlashcardTag.colorKey` / `ZStudyFolder.colorKey` : la borne de
/// palette est **injectée À L'AFFICHAGE** (`remapColorKey`, ES-8.x), jamais dans le
/// domaine. La leçon H2 (garde partagée) ne s'applique **PAS** à [colorKey] : il n'y
/// a rien à garder.
///
/// **Éphémère (AD-14)** : `isEphemeral` provient de `ZEntity` (`id == null`),
/// jamais attribué par l'entité.
library;

import 'package:zcrud_annotations/zcrud_annotations.dart';
import 'package:zcrud_core/domain.dart';

import 'z_annotation_bounds.dart';
import 'z_document_annotation_kind.dart';

part 'z_document_annotation.g.dart';

/// Reconstruit une [ZExtension] concrète depuis sa map JSON, ou `null`.
///
/// Fourni par l'app/le satellite (convention `X.fromJsonSafe`) et injecté dans
/// [ZDocumentAnnotation.fromMap] : le cœur ne connaît pas les sous-classes
/// concrètes (AD-4). Toute exception est absorbée en `null` par [ZExtension.guard]
/// (AD-10).
typedef ZDocumentAnnotationExtensionParser = ZExtension? Function(
    Map<String, dynamic> json);

/// Annotation d'un document — **contenu partageable** à identité propre (AD-26).
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
    // ⚠️ Le « fix » du lint (`this._extra`) est **ILLÉGAL** en Dart : un paramètre
    // NOMMÉ ne peut pas être privé (PRIVATE_OPTIONAL_PARAMETER). Or le slot brut
    // DOIT rester privé — c'est l'ACCESSEUR `extra` qui porte la garde (ES-2.2b).
    // ignore: prefer_initializing_formals
  }) : _extra = extra;

  /// Reconstruit **défensivement** depuis une map persistée (AD-10, AC8).
  ///
  /// Délègue au `_$ZDocumentAnnotationFromMap` **généré** (défauts sûrs :
  /// `doc_id`/`color_key` absents → `''` ; `page` absent/non numérique → `1` ;
  /// `kind` inconnu/`null`/non-`String` → [ZDocumentAnnotationKind.highlight], la
  /// 1ʳᵉ constante — D5 ; `bounds` **corrompu** — non-map, scalaire — →
  /// `ZAnnotationBounds(0,0,0,0)` (chemin `subModel` défensif) ; chaque élément de
  /// `rects` décodé **par élément** — un élément corrompu est **ignoré**
  /// (`whereType`, chemin `listModel`), chaque survivant **auto-clampé** `[0,1]`
  /// via `ZAnnotationBounds.fromMap` ; date illisible → `null`), **puis SANITISE**
  /// [page] via [sanitizePage] — le codegen ne borne pas.
  ///
  /// Puis câble les deux canaux **hors-codegen** : [extension] (via
  /// [extensionParser], repli `null`) et [extra] (clés **non réservées** de la map
  /// — round-trip AD-4 préservé).
  ///
  /// ⚠️ Corps **NON NU** obligatoire (`ZExtensible`) : une délégation nue à
  /// `_$ZDocumentAnnotationFromMap` laisserait [extra] **VIDE** — le build la
  /// **REFUSE** (`_rejectNakedCodegenDelegation`) et le garde runtime
  /// `_$zRequireExtraPreserved` lèverait à l'enregistrement.
  ///
  /// **Aucun cas ne throw** — pas même `ZDocumentAnnotation.fromMap(const {})`.
  factory ZDocumentAnnotation.fromMap(
    Map<String, dynamic> map, {
    ZDocumentAnnotationExtensionParser? extensionParser,
  }) {
    final base = _$ZDocumentAnnotationFromMap(map);
    return ZDocumentAnnotation(
      id: base.id,
      docId: base.docId,
      // R-H (D8) : `page` est **1-based** ⇒ `< 1` (corruption) ⇒ `1`. MÊME
      // FONCTION NOMMÉE qu'en `copyWith` (leçon H2 : l'invariant tient aux DEUX
      // frontières, désérialisation ET mutation applicative).
      page: sanitizePage(base.page),
      kind: base.kind,
      // BRUT — aucun clamp (D6, précédent `ZFlashcardTag.colorKey`).
      colorKey: base.colorKey,
      // Sous-modèle déjà décodé/clampé par le codegen via `ZAnnotationBounds.fromMap`.
      bounds: base.bounds,
      // Liste de sous-modèles : éléments corrompus déjà ignorés, survivants
      // auto-clampés `[0,1]` (AC8, chemin `listModel`).
      rects: base.rects,
      text: base.text,
      createdAt: base.createdAt,
      extension: _decodeExtension(map['extension'], extensionParser),
      extra: _extraFrom(map),
    );
  }

  /// Identité opaque (`null` pour l'éphémère — AD-14 ; jamais attribuée par
  /// l'entité).
  @override
  @ZcrudId()
  final String? id;

  /// Document d'appartenance (`== ZStudyDocument.id`) — persisté `doc_id`,
  /// défaut `''`.
  @ZcrudField()
  final String docId;

  /// Numéro de page **1-based** (aligné convention Syncfusion) — défaut `1` ;
  /// **jamais `< 1`** (R-H/D8, cf. [sanitizePage]).
  @ZcrudField(defaultValue: 1)
  final int page;

  /// Nature de l'annotation (surlignage / sticky note).
  ///
  /// Défaut défensif [ZDocumentAnnotationKind.highlight] — **1ʳᵉ constante de
  /// l'enum** (D5 : le repli généré d'un enum non-nullable est `T.values.first`).
  @ZcrudField()
  final ZDocumentAnnotationKind kind;

  /// Clé de couleur symbolique **BRUTE** (persistée `color_key`, snake_case ;
  /// défaut `''`). **Stockée VERBATIM, AUCUN clamp dans l'entité (D6)** — la borne
  /// est palette-dépendante, résolue À L'AFFICHAGE par `remapColorKey`.
  @ZcrudField()
  final String colorKey;

  /// Rectangle d'ancrage (enveloppe pour un surlignage, point pour une note),
  /// fractions `[0,1]` — sous-modèle `@ZcrudModel` décodé **défensivement**
  /// (map corrompue ⇒ `(0,0,0,0)`, jamais de throw du parent). Défaut
  /// `const ZAnnotationBounds()`.
  @ZcrudField()
  final ZAnnotationBounds bounds;

  /// Rects des lignes d'un surlignage multi-lignes (fractions `[0,1]`), `null` ou
  /// vide pour une sticky note / un surlignage mono-ligne.
  ///
  /// 🔴 **DW-ES24-1** : l'immuabilité de cette `List` n'est **profonde** que via
  /// [fromMap]/[copyWith] (chaque élément re-décodé/clampé) — **PAS** via le
  /// constructeur `const`, qui reçoit la référence telle quelle. Ne pas
  /// surpromettre « immuabilité profonde » sans qualifier la voie.
  @ZcrudField()
  final List<ZAnnotationBounds>? rects;

  /// Texte : contenu d'une sticky note, ou extrait surligné (pour le panneau).
  @ZcrudField()
  final String? text;

  /// Date de création — clé persistée `created_at`, **DISTINCTE** de toute clé
  /// réservée `ZSyncMeta` (précédent `ZStudyFolder.archivedAt`). `null` si
  /// absente/illisible.
  ///
  /// ⛔ Il n'y a **volontairement AUCUN** `updatedAt` ici : la clé LWW est
  /// **hors-entité** (`ZSyncMeta.updatedAt`) — cf. la dartdoc de bibliothèque
  /// (AD-19 / D5).
  @ZcrudField()
  final DateTime? createdAt;

  /// Slot type additif **versionné** (AD-4 pt.1), `null` si absent. Hors-codegen.
  @override
  final ZExtension? extension;

  /// Échappatoire non typée (AD-4 pt.2), défaut `const {}` (jamais `null`),
  /// préservant les clés inconnues du cœur au round-trip. Hors-codegen.
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

  /// Ramène un numéro de page dans son domaine `1-based` — **jamais de throw**.
  ///
  /// `raw < 1` ⇒ `1` (une annotation a au moins une page d'ancrage ; un `<= 0`
  /// n'est pas une page — D8). Déclarée **publique et NOMMÉE** : la garde est ainsi
  /// **la même fonction** aux deux frontières ([fromMap] et [copyWith]).
  ///
  /// Nuance vs `ZStudyDocument.sanitizePageCount` (nullable « inconnu »,
  /// `<= 0 ⇒ null`) : ici [page] est **non-null et requis** ⇒ repli déterministe
  /// `1`.
  static int sanitizePage(int raw) => raw < 1 ? 1 : raw;

  /// Sérialise vers la map persistée **complète** (snake_case), zéro-perte.
  ///
  /// Réutilise le `toMap()` **généré** (champs du schéma, dont [bounds]/[rects]
  /// imbriqués) puis superpose les canaux hors-codegen : [extra] (clés inconnues
  /// préservées) et [extension].
  ///
  /// ⛔ **Ne réémet NI `updated_at` NI `is_deleted`** (garanti par construction :
  /// [_reservedKeys] ⊇ `ZSyncMeta.reservedKeys` ⇒ ces clés ne peuvent entrer dans
  /// [extra], donc plus en ressortir — AD-16/AD-19).
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      // 🔴 ES-2.2b (remédiation HIGH-1) — étale l'**ACCESSEUR** (qui NORMALISE),
      // jamais le champ brut `_extra`. `toMap()` est la **frontière de SORTIE** :
      // la seule que TOUTES les voies d'écriture traversent ⇒ promesse
      // INCONDITIONNELLE (constructeur nominal `const` compris). Un
      // `_sanitizeExtra(extra)` ICI serait DÉCORATIF — la garde vit à l'accesseur.
      ...extra,
      ...ZDocumentAnnotationZcrud(this).toMap(),
    };
    if (extension != null) {
      map['extension'] = extension!.toJson();
    }
    return map;
  }

  /// Copie **à sentinelle** (un argument omis préserve la valeur, `null` explicite
  /// le remet à `null`) — couvre **TOUS** les champs, [extension] et [extra]
  /// compris (que le `copyWith` **généré** remettrait à leurs défauts, faute
  /// d'annotation : perte silencieuse). Masque le `copyWith` de l'extension.
  ///
  /// 🔴 **[page] est SANITISÉ** — exactement comme dans [fromMap] (H2 : un
  /// invariant de valeur a DEUX frontières ; ne fermer que la désérialisation
  /// laisserait la garde ROUVRABLE par mutation applicative). [colorKey] reste
  /// **BRUT** (D6). [bounds]/[rects] restent tels que fournis (leur clamp est la
  /// responsabilité de `ZAnnotationBounds` — DW-ES24-1).
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
      // R-H (D8) : MÊME FONCTION NOMMÉE qu'en `fromMap`.
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
      // 🔴 ES-2.2b : MÊME FONCTION NOMMÉE qu'en `fromMap` — `copyWith` ne peut plus
      // ROUVRIR le filtre des clés réservées.
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
    // CR-LEX-33 : le corps de cette méthode était `if (parser == null) return
    // null;` — un hôte SANS parser lisait `null`, et comme `extension` est une
    // clé CONNUE (donc exclue d'`extra`), le payload d'un AUTRE hôte était
    // DÉTRUIT au décodage, avant toute ligne de code applicatif. Le cœur
    // préserve désormais verbatim ce que personne n'a su typer.
    return zDecodeExtension(raw, parser);
  }

  /// Clés persistées **RÉSERVÉES** (champs générés + `extension` + **clés de sync
  /// `ZSyncMeta`**) — dérivées de `$ZDocumentAnnotationFieldSpecs` pour rester
  /// synchrones avec le codegen.
  ///
  /// 🔴 **`...ZSyncMeta.reservedKeys` est ESSENTIEL** (AD-19.1) : cette entité est
  /// **partageable** et le store écrit `updated_at`/`is_deleted` **dans le corps**
  /// avant de passer la map **complète** à [fromMap]. Sans ce spread, ces clés —
  /// qui appartiennent au **store** — atterriraient dans [extra] (AD-4 violé :
  /// `extra` = clés *inconnues du domaine*) puis seraient **réémises** par [toMap]
  /// (AD-16 violé), cassant l'`==` entre une annotation en mémoire et la même relue
  /// du store. L'oubli s'est produit **2 fois sur 4** en ES-1.3, **sous 1193 tests
  /// verts**. `ZDocumentAnnotation` ne déclarant **aucun** champ
  /// `updatedAt`/`isDeleted` (D5), c'est **ce spread — et lui seul —** qui l'empêche.
  static final Set<String> _reservedKeys = <String>{
    for (final spec in $ZDocumentAnnotationFieldSpecs) spec.name,
    'extension',
    ...ZSyncMeta.reservedKeys,
  };

  /// Extrait `extra` = clés **non réservées** de [map] (round-trip préservé) —
  /// **frontière d'ENTRÉE**. C'est [_sanitizeExtra], la garde **partagée**.
  static Map<String, dynamic> _extraFrom(Map<String, dynamic> map) =>
      _sanitizeExtra(map);

  /// 🔴 **LA GARDE PARTAGÉE DE `extra`** (ES-2.2b) — appelée par [fromMap] **ET**
  /// [copyWith] (jamais divergentes — leçon H2). Délègue à [zSanitizeExtra]
  /// (`zcrud_core`, implémentation UNIQUE du repo).
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

/// Égalité élément par élément (précédent `ZFlashcard.choices`).
bool _listEquals<T>(List<T>? a, List<T>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null) return false;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
