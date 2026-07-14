/// Document d'étude `ZStudyDocument` (ES-2.1, FR-S4) — **contenu PARTAGEABLE**.
///
/// origine: lex_core (module « Étude ») — `entities/education/study_document.dart`
/// (canonique retenu, D1 : IFFD importe `cloud_firestore` **et**
/// `package:flutter/material.dart` — `Color` — dans son modèle de domaine, ce que
/// NFR-S3/SM-S5 interdisent).
///
/// **AD-26 — contenu PARTAGEABLE** : cette entité est le **contenu** du document
/// (nom de fichier, chemin de stockage, statut d'ingestion). Elle est destinée au
/// sous-arbre partageable d'un dossier. L'**état de lecture PERSONNEL**
/// (page courante, zoom, pages maîtrisées) vit **ailleurs**, dans
/// `ZDocumentReadingState` — **jamais colocalisé ici** : partager un document
/// n'emporte donc **jamais** la progression de lecture d'autrui.
///
/// ## 🔴 AD-19 / D2 — `updatedAt` et `isDeleted` sont SUPPRIMÉS (le piège R-C est
/// RÉALISÉ DANS LA SOURCE)
///
/// lex porte, **inline dans l'entité** : `final DateTime updatedAt;` **et**
/// `@JsonKey(defaultValue: false) final bool isDeleted;`. Un **portage verbatim
/// recréerait exactement** la perte de données soldée en ES-1.3 : les stores
/// (`hive_z_local_store` `_encode`, `firebase_z_repository_impl` `_encode`)
/// écrivent la méta de sync **DANS LE CORPS**, **APRÈS** le corps métier, à chaque
/// `put` ⇒ un champ métier logé sous une **clé réservée** est **écrasé
/// silencieusement**, sans erreur ni test rouge.
///
/// ⇒ L'autorité Last-Write-Wins et le soft-delete vivent **HORS-ENTITÉ**, dans
/// `ZSyncMeta` (AD-16/AD-19). [createdAt] est **conservé** : sa clé `created_at`
/// est **DISTINCTE** de toute clé réservée (précédent sur disque :
/// `ZStudyFolder.archivedAt` → `archived_at`).
///
/// **Slots d'extension AD-4** : `extension` (typé, versionné, parsé
/// défensivement) + `extra` (échappatoire non typée, round-trip des clés
/// inconnues). Ces deux canaux sont **hors-codegen** : câblés à la main autour du
/// code généré (patron `ZFlashcard`/`ZRepetitionInfo`). Les champs IFFD sans
/// équivalent canonique (`type`, `content`, `contentLength`, `cloudUrl`,
/// `assistantFileId`, `subjectId`, `creatorId`…) passent par **là**, jamais par le
/// schéma partagé.
library;

import 'package:zcrud_annotations/zcrud_annotations.dart';
import 'package:zcrud_core/domain.dart';

import 'z_document_status.dart';

part 'z_study_document.g.dart';

/// Reconstruit une [ZExtension] concrète depuis sa map JSON, ou `null`.
///
/// Fourni par l'app/le satellite (convention `X.fromJsonSafe`) et injecté dans
/// [ZStudyDocument.fromMap] : le cœur ne connaît pas les sous-classes concrètes
/// (AD-4). Toute exception est absorbée en `null` par [ZExtension.guard] (AD-10).
typedef ZStudyDocumentExtensionParser = ZExtension? Function(
    Map<String, dynamic> json);

/// Document d'étude rattaché à un dossier — **contenu partageable** (AD-26).
@ZcrudModel(kind: 'study_document')
class ZStudyDocument extends ZEntity with ZExtensible {
  /// Construit un document (primitif `const`).
  const ZStudyDocument({
    this.id,
    this.folderId = '',
    this.fileName = '',
    this.status = ZDocumentStatus.uploading,
    this.storagePath = '',
    this.pageCount,
    this.sizeBytes = 0,
    this.createdAt,
    this.extension,
    Map<String, dynamic> extra = const <String, dynamic>{},
    // ⚠️ Le « fix » du lint (`this._extra`) est **ILLÉGAL** en Dart : un paramètre
    // NOMMÉ ne peut pas être privé (PRIVATE_OPTIONAL_PARAMETER). Or le slot brut
    // DOIT rester privé — c'est l'ACCESSEUR `extra` qui porte la garde (ES-2.2b).
    // ignore: prefer_initializing_formals
  }) : _extra = extra;

  /// Reconstruit **défensivement** depuis une map persistée (AD-10, AC2/AC11).
  ///
  /// Délègue au `_$ZStudyDocumentFromMap` **généré** (défauts sûrs : clés absentes
  /// → `''`/`0`/`null` ; `status` inconnu → [ZDocumentStatus.uploading], la 1ʳᵉ
  /// constante — D5 ; date illisible → `null`), **puis SANITISE** les invariants
  /// de valeur que le codegen ignore (R-H) :
  /// - [pageCount] **`<= 0`** ⇒ `null` (un document a au moins 1 page, ou on ne
  ///   sait pas) ;
  /// - [sizeBytes] **`< 0`** ⇒ `0`.
  ///
  /// Puis câble les deux canaux **hors-codegen** : [extension] (via
  /// [extensionParser], repli `null`) et [extra] (clés **non réservées** de la
  /// map — round-trip AD-4 préservé).
  ///
  /// ⚠️ Corps **NON NU** obligatoire : `ZStudyDocument` étant `ZExtensible`, une
  /// délégation nue à `_$ZStudyDocumentFromMap` laisserait `extra` **VIDE** — le
  /// build la **REFUSE** (`_rejectNakedCodegenDelegation`) et le garde runtime
  /// `_$zRequireExtraPreserved` émis dans le `.g.dart` lèverait à l'enregistrement.
  ///
  /// Aucun cas ne fait échouer le parent (map vide, `status` corrompu,
  /// `extension` illisible…).
  factory ZStudyDocument.fromMap(
    Map<String, dynamic> map, {
    ZStudyDocumentExtensionParser? extensionParser,
  }) {
    final base = _$ZStudyDocumentFromMap(map);
    return ZStudyDocument(
      id: base.id,
      folderId: base.folderId,
      fileName: base.fileName,
      status: base.status,
      storagePath: base.storagePath,
      // R-H : un `page_count` nul/négatif persisté (corruption) n'est PAS une
      // page count — c'est « inconnu » (`null`), pas « zéro page ».
      //
      // ⚠️ La garde est la MÊME FONCTION NOMMÉE qu'en `copyWith` (H2, ES-2.1) :
      // un invariant de valeur doit tenir aux DEUX frontières (désérialisation
      // ET mutation applicative), et deux implémentations jumelles finiraient
      // par diverger.
      pageCount: sanitizePageCount(base.pageCount),
      // R-H : une taille négative est impossible ⇒ défaut sûr `0`.
      sizeBytes: sanitizeSizeBytes(base.sizeBytes),
      createdAt: base.createdAt,
      extension: _decodeExtension(map['extension'], extensionParser),
      extra: _extraFrom(map),
    );
  }

  /// Identité opaque (`null` pour l'éphémère — jamais attribuée par l'entité).
  /// Vaut le `documentId` d'ingestion (aucune réconciliation, cf. lex).
  @override
  @ZcrudId()
  final String? id;

  /// Dossier d'appartenance (clé de partitionnement ; défaut `''`).
  @ZcrudField()
  final String folderId;

  /// Nom de fichier affiché (titre de la carte ; défaut `''`).
  @ZcrudField(label: 'Nom du fichier')
  final String fileName;

  /// État du cycle de vie (upload → validation → prêt).
  ///
  /// Défaut défensif [ZDocumentStatus.uploading] — **1ʳᵉ constante de l'enum**
  /// (D5 : le repli généré d'un enum non-nullable est `T.values.first`).
  @ZcrudField()
  final ZDocumentStatus status;

  /// Chemin de stockage renvoyé par le backend — **jamais construit côté client**
  /// (défaut `''`).
  @ZcrudField()
  final String storagePath;

  /// Nombre de pages **best-effort à l'ingestion** — `null` tant qu'inconnu.
  ///
  /// ⚠️ **Doublon VOLONTAIRE** avec `ZDocumentReadingState.pageCount` (design lex,
  /// conservé) : celui-ci est la valeur **d'ingestion** (OCR backend, best-effort,
  /// souvent absente) ; celui de l'état de lecture est l'**AUTORITÉ**, consolidée
  /// au **chargement réel du PDF** côté viewer. Ce ne sont **pas** deux copies de
  /// la même donnée : ce sont deux sources de confiance différentes, et
  /// **supprimer l'une ne serait pas une simplification**.
  @ZcrudField()
  final int? pageCount;

  /// Taille du fichier en octets (défaut `0` ; **jamais négative** — R-H).
  @ZcrudField()
  final int sizeBytes;

  /// Date de création — clé persistée `created_at`, **DISTINCTE** de toute clé
  /// réservée `ZSyncMeta` (précédent : `ZStudyFolder.archivedAt`). `null` si
  /// absente/illisible.
  ///
  /// ⛔ Il n'y a **volontairement AUCUN** `updatedAt` ici : la clé LWW est
  /// **hors-entité** (`ZSyncMeta.updatedAt`) — cf. la dartdoc de bibliothèque
  /// (AD-19 / D2).
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

  /// Sérialise vers la map persistée **complète** (snake_case), zéro-perte.
  ///
  /// Réutilise le `toMap()` **généré** (champs du schéma) puis superpose les
  /// canaux hors-codegen : [extra] (clés inconnues préservées) et [extension].
  ///
  /// ⚠️ **Indispensable** : le `toMap()` GÉNÉRÉ (extension `ZStudyDocumentZcrud`)
  /// **n'étale PAS `extra`** — sans ce `toMap()` d'instance, ce que `fromMap` a
  /// préservé ne serait **jamais réémis** (jambe « sortie » de DW-ES14-1, observée
  /// par le garde runtime émis dans le `.g.dart`).
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      // 🔴 DW-ES22-3 (ES-2.2b) — MÊME garde nommée qu'en `fromMap`/`copyWith`.
      // `toMap()` est la **frontière de SORTIE** : la seule que TOUTES les voies
      // d'écriture traversent ⇒ promesse INCONDITIONNELLE (constructeur nominal
      // compris). H2 (ES-2.1) avait fermé les DEUX frontières pour les invariants
      // de VALEUR (`pageCount`/`sizeBytes`) et **oublié `extra`** : `copyWith`
      // rouvrait le filtre des clés réservées (MESURÉ).
      // 🔴 ES-2.2b (remédiation HIGH-1) — étale l'**ACCESSEUR** (qui NORMALISE),
      // jamais le champ brut `_extra`. Un `_sanitizeExtra(extra)` ICI serait
      // **DÉCORATIF** — MESURÉ (INJ-A/INJ-B) : le retirer laissait le gate VERT
      // sur 8 entités sur 9. La garde vit à l'accesseur ; l'en retirer rend
      // (i.1a)/(i.1b)/(i.1c) ROUGES.
      ...extra,
      ...ZStudyDocumentZcrud(this).toMap(),
    };
    if (extension != null) {
      map['extension'] = extension!.toJson();
    }
    return map;
  }

  /// Copie **à sentinelle** (un argument omis préserve la valeur, `null` explicite
  /// la remet à `null`) — couvre **tous** les champs, [extension] et [extra]
  /// compris (que le `copyWith` **généré** remettrait à leurs défauts, faute
  /// d'annotation : perte silencieuse). Masque le `copyWith` de l'extension.
  ///
  /// 🔴 **[pageCount] et [sizeBytes] sont SANITISÉS** — exactement comme dans
  /// [fromMap] (H2, code-review ES-2.1).
  ///
  /// Un invariant de valeur a **DEUX** frontières : la **désérialisation** (une
  /// valeur corrompue qui ENTRE) **et** la **mutation applicative** (une valeur
  /// hors-domaine qu'on ÉCRIT). Ne fermer que la première laisse la garde
  /// **ROUVRABLE** : `doc.copyWith(sizeBytes: -1, pageCount: 0).toMap()`
  /// persistait `{'size_bytes': -1, 'page_count': 0}` — **hors du domaine de
  /// définition** — et la relecture les **modifiait silencieusement** (`0` /
  /// `null`) ⇒ **round-trip NON idempotent**, `==` cassée entre l'instance en
  /// mémoire et la même relue du store. La dartdoc de [sizeBytes] PROMETTAIT
  /// « jamais négative » : **une promesse en prose qu'aucune machine ne tenait**.
  /// (Ses deux sœurs de la même story, `ZDocumentViewerPrefs` et
  /// `ZDocumentReadingState`, sanitisaient déjà.)
  ZStudyDocument copyWith({
    Object? id = _$undefined,
    Object? folderId = _$undefined,
    Object? fileName = _$undefined,
    Object? status = _$undefined,
    Object? storagePath = _$undefined,
    Object? pageCount = _$undefined,
    Object? sizeBytes = _$undefined,
    Object? createdAt = _$undefined,
    Object? extension = _$undefined,
    Object? extra = _$undefined,
  }) {
    final nextPageCount = identical(pageCount, _$undefined)
        ? this.pageCount
        : pageCount as int?;
    final nextSizeBytes =
        identical(sizeBytes, _$undefined) ? this.sizeBytes : sizeBytes as int;
    return ZStudyDocument(
      id: identical(id, _$undefined) ? this.id : id as String?,
      folderId:
          identical(folderId, _$undefined) ? this.folderId : folderId as String,
      fileName:
          identical(fileName, _$undefined) ? this.fileName : fileName as String,
      status: identical(status, _$undefined)
          ? this.status
          : status as ZDocumentStatus,
      storagePath: identical(storagePath, _$undefined)
          ? this.storagePath
          : storagePath as String,
      // R-H : `<= 0` ⇒ « inconnu » (`null`), pas « zéro page » — cf. `fromMap`.
      pageCount: sanitizePageCount(nextPageCount),
      // R-H : une taille négative est impossible ⇒ défaut sûr `0`.
      sizeBytes: sanitizeSizeBytes(nextSizeBytes),
      createdAt: identical(createdAt, _$undefined)
          ? this.createdAt
          : createdAt as DateTime?,
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

  /// Ramène un nombre de pages dans son domaine de définition — **jamais de throw**.
  ///
  /// `null` ou **`<= 0`** ⇒ `null` (« inconnu », **pas** « zéro page »). Déclarée
  /// **publique et NOMMÉE** : la garde est ainsi **la même fonction** aux deux
  /// frontières ([fromMap] et [copyWith]) — impossible qu'une des deux dérive.
  static int? sanitizePageCount(int? raw) =>
      raw == null || raw <= 0 ? null : raw;

  /// Ramène une taille de fichier dans son domaine de définition — **jamais
  /// négative** (repli `0`). Cf. [sanitizePageCount].
  static int sanitizeSizeBytes(int raw) => raw < 0 ? 0 : raw;

  /// Décode défensivement l'extension via [parser] (repli `null`).
  static ZExtension? _decodeExtension(
    Object? raw,
    ZStudyDocumentExtensionParser? parser,
  ) {
    if (parser == null) return null;
    final map = _asStringMap(raw);
    if (map == null) return null;
    return ZExtension.guard<ZExtension?>(() => parser(map));
  }

  /// Clés persistées **RÉSERVÉES** (champs générés + `extension` + **clés de sync
  /// `ZSyncMeta`**) — dérivées de `$ZStudyDocumentFieldSpecs` pour rester
  /// synchrones avec le codegen.
  ///
  /// 🔴 **`...ZSyncMeta.reservedKeys` est ESSENTIEL** (AD-19.1) — l'oubli s'est
  /// produit **2 fois sur 4** en ES-1.3, **sous 1193 tests verts**. `ZStudyDocument`
  /// ne déclarant **aucun** champ `updatedAt`/`isDeleted` (D2), c'est **ce spread —
  /// et lui seul —** qui empêche `updated_at`/`is_deleted`, que le store écrit
  /// **dans le corps** du document, d'atterrir dans [extra] (AD-4 violé : `extra`
  /// = clés *inconnues du domaine*, pas clés du store) puis d'être **réémis** par
  /// [toMap] (AD-16 violé : le soft-delete reste hors-entité) — cassant au passage
  /// l'`==` entre un document en mémoire et le même relu du store.
  static final Set<String> _reservedKeys = <String>{
    for (final spec in $ZStudyDocumentFieldSpecs) spec.name,
    'extension',
    ...ZSyncMeta.reservedKeys,
  };

  /// Extrait `extra` = clés **non réservées** de [map] (round-trip préservé).
  /// Rendu **non-modifiable** (cohérence `ZExtensible`).
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
      other is ZStudyDocument &&
          id == other.id &&
          folderId == other.folderId &&
          fileName == other.fileName &&
          status == other.status &&
          storagePath == other.storagePath &&
          pageCount == other.pageCount &&
          sizeBytes == other.sizeBytes &&
          createdAt == other.createdAt &&
          extension == other.extension &&
          zJsonEquals(extra, other.extra);

  @override
  int get hashCode => Object.hashAll(<Object?>[
        id,
        folderId,
        fileName,
        status,
        storagePath,
        pageCount,
        sizeBytes,
        createdAt,
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
