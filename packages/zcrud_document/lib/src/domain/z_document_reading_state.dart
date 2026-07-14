/// État de lecture **PERSONNEL** d'un document (ES-2.1, FR-S4).
///
/// origine: lex_core (module « Étude ») — `entities/education/document_reading_state.dart`.
///
/// ## 🔴 AD-26 — ÉTAT PERSONNEL, JAMAIS COLOCALISÉ AVEC LE CONTENU
///
/// Cet état (dernière page lue, zoom, pages maîtrisées) est **personnel** : il ne
/// vit **jamais** dans le sous-arbre **partageable** du document
/// ([ZStudyDocument]) — exactement comme `ZRepetitionInfo` (SRS) ne vit jamais
/// dans la carte. **Partager ou dupliquer un document n'emporte donc JAMAIS la
/// progression de lecture d'autrui.** La non-colocation est prouvée **par
/// machine** (aucune clé de lecture dans `$ZStudyDocumentFieldSpecs`, aucune
/// imbrication de cette entité dans le document). La **résolution de collection**
/// (le « où », p. ex. `study_document_state/{docId}`) reste du ressort de
/// `ZFirestorePathResolver` — **ES-3.2, hors périmètre de cette story**.
///
/// ## 🔴 AD-19 / D2 — `updatedAt` SUPPRIMÉ (le piège R-C, réalisé DANS LA SOURCE)
///
/// lex déclare, **dans cette entité** : `/// Clé LWW (dernière écriture).`
/// `final DateTime updatedAt;` — c'est **littéralement** la clé d'autorité du
/// merge, **logée dans le corps métier**. Le store écrivant sa méta **APRÈS** le
/// corps à chaque `put`, un tel champ est **écrasé silencieusement**. L'autorité
/// LWW et le soft-delete vivent **HORS-ENTITÉ** (`ZSyncMeta`, AD-16/AD-19) : cette
/// entité ne déclare **NI `updatedAt` NI `isDeleted`**.
///
/// ## 🔴 D8 — PAS un `ZEntity` : la clé d'identité est [docId]
///
/// Jointure **1↔1** avec le document (patron `ZRepetitionInfo`, clé par
/// `flashcardId`) : aucun `id` propre, aucune réconciliation d'identifiant.
///
/// ## 🔴 D4 — `learning` est un canal **HORS-CODEGEN** (patron `ZFlashcard.source`)
///
/// [ZDocumentLearningInfo] n'est **pas** un `@ZcrudModel` (le générateur ne
/// supporte **aucun type `Map`** — D3), or la catégorie `subModel` **exige**
/// l'annotation. `learning` **ne peut donc PAS être un `@ZcrudField`** : il est
/// décodé et réémis **à la main**, et sa clé `'learning'` est ajoutée à
/// [_reservedKeys] — sans quoi elle atterrirait dans `extra` **et** serait réémise
/// **en double** (AD-4 violé, `==` cassée entre une instance mémoire et la même
/// relue du store).
library;

import 'package:zcrud_annotations/zcrud_annotations.dart';
import 'package:zcrud_core/domain.dart';

import 'z_document_learning_info.dart';
import 'z_document_viewer_prefs.dart';

part 'z_document_reading_state.g.dart';

/// Reconstruit une [ZExtension] concrète depuis sa map JSON, ou `null` (AD-4).
typedef ZDocumentReadingStateExtensionParser = ZExtension? Function(
    Map<String, dynamic> json);

/// Clé persistée du canal **hors-codegen** `learning` (D4).
///
/// Déclarée **une seule fois**, consommée par [ZDocumentReadingState.fromMap],
/// [ZDocumentReadingState.toMap] **et** [ZDocumentReadingState._reservedKeys] :
/// aucun littéral dupliqué (précédent `ZSyncMeta` / dette DW-ES13-1).
const String kLearningKey = 'learning';

/// État de lecture personnel d'un document — clé par [docId] (**pas** un
/// `ZEntity`, D8).
@ZcrudModel(kind: 'document_reading_state')
class ZDocumentReadingState with ZExtensible {
  /// Construit un état de lecture (primitif `const`).
  const ZDocumentReadingState({
    this.docId = '',
    this.currentPage = 1,
    this.pageCount,
    this.prefs = const ZDocumentViewerPrefs(),
    this.learning = ZDocumentLearningInfo.empty,
    this.extension,
    Map<String, dynamic> extra = const <String, dynamic>{},
    // ⚠️ Le « fix » du lint (`this._extra`) est **ILLÉGAL** en Dart : un paramètre
    // NOMMÉ ne peut pas être privé (PRIVATE_OPTIONAL_PARAMETER). Or le slot brut
    // DOIT rester privé — c'est l'ACCESSEUR `extra` qui porte la garde (ES-2.2b).
    // ignore: prefer_initializing_formals
  }) : _extra = extra;

  /// Reconstruit **défensivement** depuis une map persistée (AD-10, AC6/AC11).
  ///
  /// Délègue au `_$ZDocumentReadingStateFromMap` **généré** (défauts sûrs :
  /// `doc_id` absent → `''` ; `current_page` absent/non numérique → `1` ;
  /// `page_count` illisible → `null` ; `prefs` **corrompue** — `42`, une chaîne,
  /// une liste — → `ZDocumentViewerPrefs.fromMap(const {})`, càd les défauts),
  /// **puis SANITISE** les invariants que le codegen ignore (R-H) :
  /// - [currentPage] est **1-based** ⇒ `< 1` (`0`, `-3`) ⇒ **`1`** ;
  /// - [pageCount] `<= 0` ⇒ **`null`** (« inconnu », pas « zéro page »).
  ///
  /// Puis câble les canaux **hors-codegen** : `learning` (**D4**, via
  /// [ZDocumentLearningInfo.fromJsonSafe] — non-map ⇒ `empty`, **jamais de
  /// throw**), [extension] (repli `null`) et [extra] (clés **non réservées**).
  ///
  /// ⚠️ Corps **NON NU** obligatoire (`ZExtensible`) : une délégation nue laisserait
  /// `extra` VIDE ⇒ **build ROUGE** + garde runtime à l'enregistrement.
  ///
  /// **Aucun cas ne throw** — pas même `ZDocumentReadingState.fromMap(const {})`.
  factory ZDocumentReadingState.fromMap(
    Map<String, dynamic> map, {
    ZDocumentReadingStateExtensionParser? extensionParser,
  }) {
    final base = _$ZDocumentReadingStateFromMap(map);
    final rawPageCount = base.pageCount;
    return ZDocumentReadingState(
      docId: base.docId,
      // R-H : pagination **1-based** (alignée `PdfViewerController`). `0`,
      // négatif ou corrompu ⇒ première page — jamais une page impossible.
      currentPage: base.currentPage < 1 ? 1 : base.currentPage,
      // R-H : `<= 0` ⇒ « inconnu » (`null`), pas « zéro page ».
      pageCount:
          rawPageCount == null || rawPageCount <= 0 ? null : rawPageCount,
      prefs: base.prefs,
      // 🔴 CANAL HORS-CODEGEN (D4) — patron `ZFlashcard.source`.
      learning: ZDocumentLearningInfo.fromJsonSafe(map[kLearningKey]),
      extension: _decodeExtension(map['extension'], extensionParser),
      extra: _extraFrom(map),
    );
  }

  /// Identité : le document dont c'est l'état de lecture (jointure **1↔1**).
  /// Défaut `''`. **Pas d'`id` propre** (D8).
  @ZcrudField()
  final String docId;

  /// Dernière page lue — **1-based** (défaut `1`, première ouverture ;
  /// **jamais `< 1`** — R-H).
  @ZcrudField(defaultValue: 1)
  final int currentPage;

  /// Nombre total de pages — **AUTORITÉ** de la méta « lues / total ».
  ///
  /// Consolidé au **chargement réel du PDF** (viewer), il comble le
  /// `ZStudyDocument.pageCount` best-effort d'ingestion. `null` tant qu'inconnu ;
  /// **jamais `<= 0`** (R-H). Le doublon avec [ZStudyDocument.pageCount] est
  /// **VOLONTAIRE** (design lex conservé) : deux sources de confiance distinctes —
  /// **ne pas « factoriser »**.
  @ZcrudField()
  final int? pageCount;

  /// Préférences de lecture (zoom, sens, disposition) — sous-modèle `@ZcrudModel`
  /// décodé **défensivement** (map corrompue ⇒ défauts, jamais de throw).
  @ZcrudField()
  final ZDocumentViewerPrefs prefs;

  /// État d'apprentissage **par page** — **CANAL HORS-CODEGEN** (D4, patron
  /// `ZFlashcard.source`) : sa clé [kLearningKey] est **réservée**, il est décodé
  /// et réémis **à la main**. Défaut [ZDocumentLearningInfo.empty].
  final ZDocumentLearningInfo learning;

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

  /// Sérialise vers la map persistée **complète** (snake_case), zéro-perte.
  ///
  /// Réutilise le `toMap()` **généré** (champs du schéma, dont `prefs` imbriquée)
  /// puis superpose les **trois** canaux hors-codegen : [extra], `learning`
  /// (**toujours** émis, même vide — round-trip **idempotent**) et [extension].
  ///
  /// ⛔ **Ne réémet NI `updated_at` NI `is_deleted`** : ces clés appartiennent au
  /// store (`ZSyncMeta`), pas au domaine (AD-16/AD-19).
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      // 🔴 DW-ES22-3 (ES-2.2b) — MÊME garde nommée qu'en `fromMap`/`copyWith`.
      // `toMap()` est la **frontière de SORTIE** : la seule que TOUTES les voies
      // d'écriture traversent ⇒ la promesse ci-dessus (« ne réémet NI `updated_at`
      // NI `is_deleted` ») est enfin **INCONDITIONNELLE**, et non plus
      // contredite par `copyWith(extra:)` (MESURÉ : les DEUX clés réémises).
      // 🔴 ES-2.2b (remédiation HIGH-1) — étale l'**ACCESSEUR** (qui NORMALISE),
      // jamais le champ brut `_extra`. Un `_sanitizeExtra(extra)` ICI serait
      // **DÉCORATIF** — MESURÉ (INJ-A/INJ-B) : le retirer laissait le gate VERT
      // sur 8 entités sur 9. La garde vit à l'accesseur ; l'en retirer rend
      // (i.1a)/(i.1b)/(i.1c) ROUGES.
      ...extra,
      ...ZDocumentReadingStateZcrud(this).toMap(),
      kLearningKey: learning.toJson(),
    };
    if (extension != null) {
      map['extension'] = extension!.toJson();
    }
    return map;
  }

  /// Copie **à sentinelle** — couvre **tous** les champs, y compris `learning`,
  /// [extension] et [extra] (que le `copyWith` **généré** ignore ou remettrait à
  /// leurs défauts : perte silencieuse). Masque le `copyWith` de l'extension.
  ///
  /// [currentPage] et [pageCount] sont **sanitisés** comme au décodage (une
  /// mutation applicative ne doit pas rouvrir l'invariant que `fromMap` ferme).
  ZDocumentReadingState copyWith({
    Object? docId = _$undefined,
    Object? currentPage = _$undefined,
    Object? pageCount = _$undefined,
    Object? prefs = _$undefined,
    Object? learning = _$undefined,
    Object? extension = _$undefined,
    Object? extra = _$undefined,
  }) {
    final nextPage = identical(currentPage, _$undefined)
        ? this.currentPage
        : currentPage as int;
    final nextCount = identical(pageCount, _$undefined)
        ? this.pageCount
        : pageCount as int?;
    return ZDocumentReadingState(
      docId: identical(docId, _$undefined) ? this.docId : docId as String,
      currentPage: nextPage < 1 ? 1 : nextPage,
      pageCount: nextCount == null || nextCount <= 0 ? null : nextCount,
      prefs: identical(prefs, _$undefined)
          ? this.prefs
          : prefs as ZDocumentViewerPrefs,
      learning: identical(learning, _$undefined)
          ? this.learning
          : learning as ZDocumentLearningInfo,
      extension: identical(extension, _$undefined)
          ? this.extension
          : extension as ZExtension?,
      // 🔴 DW-ES22-3 (ES-2.2b) : MÊME FONCTION NOMMÉE qu'en `fromMap` —
      // `copyWith` ne peut plus ROUVRIR le filtre des clés réservées.
      extra: identical(extra, _$undefined)
          ? this.extra
          : _sanitizeExtra(extra as Map<String, dynamic>),
    );
  }

  /// Décode défensivement l'extension via [parser] (repli `null`).
  static ZExtension? _decodeExtension(
    Object? raw,
    ZDocumentReadingStateExtensionParser? parser,
  ) {
    if (parser == null) return null;
    final map = _asStringMap(raw);
    if (map == null) return null;
    return ZExtension.guard<ZExtension?>(() => parser(map));
  }

  /// Clés persistées **RÉSERVÉES** (champs générés + `extension` + **`learning`**
  /// + **clés de sync `ZSyncMeta`**) — dérivées de
  /// `$ZDocumentReadingStateFieldSpecs` pour rester synchrones avec le codegen.
  ///
  /// 🔴 **`...ZSyncMeta.reservedKeys` est ESSENTIEL** (AD-19.1) : cette entité est
  /// persistée **top-level** et le store écrit `updated_at`/`is_deleted` **dans le
  /// corps** du document avant de passer la map **complète** à [fromMap]. Sans ce
  /// spread, ces clés — qui appartiennent au **store** — atterriraient dans [extra]
  /// et seraient **réémises** par [toMap]. L'oubli s'est produit **2 fois sur 4**
  /// en ES-1.3, **sous 1193 tests verts** : il est ici prouvé **comportementalement**
  /// (test AD-19 par entité + volet (A) du gate `reserved-keys`).
  ///
  /// 🔴 **[kLearningKey] est ESSENTIEL** (D4) : le canal hors-codegen étant réémis
  /// **à la main** par [toMap], sa clé DOIT être réservée — sinon elle atterrirait
  /// **aussi** dans [extra] et serait émise **deux fois** (une par `...extra`, une
  /// par le câblage manuel), cassant l'idempotence du round-trip.
  static final Set<String> _reservedKeys = <String>{
    for (final spec in $ZDocumentReadingStateFieldSpecs) spec.name,
    'extension',
    kLearningKey,
    ...ZSyncMeta.reservedKeys,
  };

  /// Extrait `extra` = clés **non réservées** de [map] (round-trip préservé).
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
      other is ZDocumentReadingState &&
          docId == other.docId &&
          currentPage == other.currentPage &&
          pageCount == other.pageCount &&
          prefs == other.prefs &&
          learning == other.learning &&
          extension == other.extension &&
          zJsonEquals(extra, other.extra);

  @override
  int get hashCode => Object.hashAll(<Object?>[
        docId,
        currentPage,
        pageCount,
        prefs,
        learning,
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
