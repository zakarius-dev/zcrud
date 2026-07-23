/// Référence *content-addressed* d'un podcast généré `ZStudyPodcast` (ES-2.8,
/// **FR-S11**) — **contenu personnel top-level à identité propre** (`ZEntity` +
/// `ZExtensible`, `@ZcrudModel`).
///
/// origine: lex_core (module « Étude ») — entité `StudyPodcast` (`{id, sourceKind,
/// sourceId, folderId, mode, sourceHash, resultRef, status, createdAt, updatedAt,
/// isDeleted}`, `static buildId(sourceId, mode) => '${sourceId}_${mode.name}'`).
/// Dartdoc lex : *« Content-addressed : l'identité repose sur le couple
/// (sourceId, mode) ; `sourceHash = sha256(normalizeAudio(sourceContent))` est la
/// clé d'invalidation. Seul un podcast `ready` est persisté. »*
///
/// ## 🔴 DÉCISION CENTRALE (D4) — [sourceHash] est OPAQUE, JAMAIS calculé ici
///
/// lex calcule `sourceHash` par **SHA-256**. NFR-S10/SM-S7 **INTERDISENT
/// `package:crypto`/SHA-256 dans le kernel** (précédent verrouillé
/// `ZColorPalette`/`remapColorKey`). ⇒ [sourceHash] est un `String` **OPAQUE
/// FOURNI** par l'appelant (calculé en amont par le seam de génération / le
/// binding — SHA-256 côté lex, parité backend préservée SANS que le kernel
/// n'acquière crypto). L'invalidation est une **COMPARAISON PURE** ([isStale],
/// [ZPodcastFreshness]) : le kernel **ne hashe RIEN** — ni `crypto`, ni
/// `zFnv1a32`. Le hashing du contenu source est un **seam de présentation/data**
/// (ES-9.3 `ZPodcastGenerationPort`), pas un concern du domaine (AD-4 : extension
/// par injection).
///
/// ## 🔴 AD-19 / D... — AUCUN horodatage de sync inline (DIVERGE de lex)
///
/// lex porte `updatedAt`/`isDeleted` **INLINE**. `ZStudyPodcast` les **RETIRE** :
/// la fraîcheur LWW et le soft-delete vivent **HORS-ENTITÉ** (`ZSyncMeta`,
/// AD-16/AD-19). [sourceHash] et [createdAt] sont des clés **MÉTIER** distinctes de
/// toute clé de sync. [_reservedKeys] ⊇ `ZSyncMeta.reservedKeys` : ces clés ne
/// polluent jamais [extra] et ne sont jamais réémises par [toMap].
///
/// ## Identité *content-addressed* — [id] nullable (AD-14) + helper PUR [buildId]
///
/// lex a `id` **required non-null** (`{sourceId}_{mode}`). zcrud garde
/// `id: String?` `@ZcrudId` (jamais assigné par l'entité, matérialisé au
/// repository ES-3/ES-9.3) **et** expose le static PUR [ZStudyPodcast.buildId] que
/// le repo appelle pour matérialiser l'identité déterministe.
///
/// ## Tous les champs sont codegen-ables (D5) — AUCUN canal `Map` hors-codegen
///
/// 3 `String` + `folderId` `String` + 3 enums (`select`) + 1 `DateTime?` ISO-8601 :
/// **aucun** `content`/`learning`/`section_orders`/`reminderTime`. Il n'y a donc
/// **AUCUN** `kXxxKey`, **AUCUNE** règle (g2), et le seul slot hors-codegen est
/// [extension]/[extra] (patron ES-2.2b).
///
/// ## Patron `extra` ES-2.2b INTÉGRAL (jumeau `ZExam` / `ZDocumentAnnotation`)
///
/// Constructeur `const` qui **ne filtre RIEN** (`: _extra = extra;`), slot brut
/// [_extra] **lu nulle part ailleurs**, accesseur [extra] **normalisant** (le SEUL
/// point traversé par TOUTES les voies), garde partagée [_sanitizeExtra]
/// (`fromMap` **ET** `copyWith`), [toMap] étalant l'**accesseur** `...extra`,
/// `copyWith` **à sentinelle** couvrant TOUS les champs, égalité **profonde**
/// `zJsonEquals` / `zJsonHash`.
///
/// Pur Dart — aucune dépendance Flutter/Firebase/crypto (NFR-S3/NFR-S10/SM-S5).
library;

import 'package:zcrud_annotations/zcrud_annotations.dart';
import 'package:zcrud_core/domain.dart';

import 'z_podcast_mode.dart';
import 'z_podcast_source_kind.dart';
import 'z_podcast_status.dart';

part 'z_study_podcast.g.dart';

/// Reconstruit une [ZExtension] concrète depuis sa map JSON, ou `null` (AD-4).
///
/// Fourni par l'app/le satellite (convention `X.fromJsonSafe`) et injecté dans
/// [ZStudyPodcast.fromMap] : le domaine ne connaît pas les sous-classes concrètes.
/// Toute exception est absorbée en `null` par [ZExtension.guard] (AD-10).
typedef ZStudyPodcastExtensionParser = ZExtension? Function(
    Map<String, dynamic> json);

/// Référence *content-addressed* d'un podcast généré — **contenu personnel
/// top-level à identité propre** (AD-14).
@ZcrudModel(kind: 'study_podcast')
class ZStudyPodcast extends ZEntity with ZExtensible {
  /// Construit une référence de podcast (primitif `const`).
  ///
  /// ⛔ **AUCUN `assert` ici, volontairement** (AD-10) : le décodeur **généré**
  /// (`_$ZStudyPodcastFromMap`) appelle ce constructeur avec les valeurs **BRUTES**
  /// de la map persistée. Un `assert` y ferait **échouer la désérialisation d'une
  /// donnée corrompue** — violation frontale d'AD-10. Les gardes vivent
  /// **exclusivement aux frontières** [fromMap] / [copyWith], et la garde `extra`
  /// y est **la MÊME fonction nommée** ([_sanitizeExtra]) — leçon H2.
  const ZStudyPodcast({
    this.id,
    this.sourceKind = ZPodcastSourceKind.note,
    this.sourceId = '',
    this.folderId = '',
    this.mode = ZPodcastMode.simple,
    this.sourceHash = '',
    this.resultRef = '',
    this.status = ZPodcastStatus.ready,
    this.createdAt,
    this.extension,
    Map<String, dynamic> extra = const <String, dynamic>{},
    // ⚠️ Le « fix » du lint (`this._extra`) est ILLÉGAL en Dart : un paramètre
    // NOMMÉ ne peut pas être privé (PRIVATE_OPTIONAL_PARAMETER). Or le slot brut
    // DOIT rester privé — c'est l'ACCESSEUR `extra` qui porte la garde (ES-2.2b).
    // ignore: prefer_initializing_formals
  }) : _extra = extra;

  /// Reconstruit **défensivement** depuis une map persistée (AD-10, D9) — **aucun
  /// cas ne throw**, pas même `ZStudyPodcast.fromMap(const <String, dynamic>{})`.
  ///
  /// Délègue au `_$ZStudyPodcastFromMap` **généré** pour les champs de schéma
  /// (défauts sûrs : `source_id`/`folder_id`/`source_hash`/`result_ref` absents →
  /// `''` ; `source_kind`/`mode`/`status` inconnus/`null`/non-`String` → 1ʳᵉ
  /// constante D3 (`note`/`simple`/`ready`) ; `created_at` illisible → `null`),
  /// **puis câble les canaux hors-codegen** : [extension] (via [extensionParser],
  /// repli `null`, `ZExtension.guard`) et [extra] (clés **non réservées** de la
  /// map — round-trip AD-4).
  ///
  /// ⚠️ Corps **NON NU** obligatoire (`ZExtensible`) : une délégation nue à
  /// `_$ZStudyPodcastFromMap` laisserait [extra] **VIDE** — le **build la REFUSE**
  /// (`_rejectNakedCodegenDelegation`) et le garde runtime `_$zRequireExtraPreserved`
  /// **lèverait à l'enregistrement**.
  factory ZStudyPodcast.fromMap(
    Map<String, dynamic> map, {
    ZStudyPodcastExtensionParser? extensionParser,
  }) {
    final base = _$ZStudyPodcastFromMap(map);
    return ZStudyPodcast(
      id: base.id,
      sourceKind: base.sourceKind,
      sourceId: base.sourceId,
      folderId: base.folderId,
      mode: base.mode,
      sourceHash: base.sourceHash,
      resultRef: base.resultRef,
      status: base.status,
      createdAt: base.createdAt,
      extension: _decodeExtension(map['extension'], extensionParser),
      extra: _extraFrom(map),
    );
  }

  /// Identité opaque (`null` pour l'éphémère — AD-14 ; **jamais attribuée par
  /// l'entité**, matérialisée au repository via [buildId]).
  @override
  @ZcrudId()
  final String? id;

  /// Nature de la source (note / dossier / document).
  ///
  /// Défaut défensif [ZPodcastSourceKind.note] — **1ʳᵉ constante de l'enum** (D3 :
  /// le repli généré d'un enum non-nullable est `T.values.first`).
  @ZcrudField()
  final ZPodcastSourceKind sourceKind;

  /// Identifiant de la source d'étude — **clé NEUTRE `String`** (défaut `''`).
  ///
  /// ⚠️ **Aucun symbole de `zcrud_study_kernel`/satellite n'est importé** : c'est
  /// un `String` opaque (comme `ZExam.folderId`). Compose l'identité *content-
  /// addressed* via [buildId].
  @ZcrudField()
  final String sourceId;

  /// Dossier d'appartenance — **clé NEUTRE `String`** (défaut `''`, aucun import
  /// de `ZStudyFolder`).
  @ZcrudField()
  final String folderId;

  /// Mode de synthèse (voix unique / dialogue).
  ///
  /// Défaut défensif [ZPodcastMode.simple] — **1ʳᵉ constante** (D3). Compose le
  /// suffixe de l'identité *content-addressed* via [buildId].
  @ZcrudField()
  final ZPodcastMode mode;

  /// 🔴 Empreinte **OPAQUE** de la source ayant produit ce podcast (persistée
  /// `source_hash`, défaut `''`) — **clé d'invalidation** (D4).
  ///
  /// **JAMAIS calculée par le kernel** : elle est FOURNIE par l'appelant (SHA-256
  /// côté lex, hors-domaine). Le kernel la **COMPARE** ([isStale]), il ne la hashe
  /// pas. Clé **MÉTIER**, DISTINCTE de toute clé de sync (`updated_at`).
  @ZcrudField()
  final String sourceHash;

  /// Référence opaque du résultat audio (chemin de storage / URL) — persistée
  /// `result_ref`, défaut `''`. La résolution `resultRef → blob audio` est un seam
  /// d'app (ES-9.3), hors périmètre.
  @ZcrudField()
  final String resultRef;

  /// État du cycle de vie du podcast.
  ///
  /// Défaut défensif [ZPodcastStatus.ready] — **1ʳᵉ constante** (D3 ; parité
  /// sémantique lex `fromJson → ready` : seul un podcast `ready` est persisté).
  @ZcrudField()
  final ZPodcastStatus status;

  /// Date de création — clé persistée `created_at`, **ISO-8601**, **nullable**
  /// (défaut `null`).
  ///
  /// Nullable car un `DateTime` n'a **aucun constructeur `const`**. `created_at`
  /// illisible → `null`, jamais un throw. ⛔ **DISTINCTE de toute clé de sync**
  /// (`updated_at`/`is_deleted`, hors-entité AD-19).
  @ZcrudField()
  final DateTime? createdAt;

  /// Slot type additif **versionné** (AD-4 pt.1), `null` si absent. Hors-codegen.
  @override
  final ZExtension? extension;

  /// Slot `extra` **BRUT tel que reçu par le constructeur** — lu **NULLE PART**
  /// ailleurs que dans l'accesseur [extra] (ni `toMap`, ni `==`, ni `hashCode`).
  ///
  /// Il peut être **POLLUÉ** : le constructeur nominal est `const`, il ne peut
  /// appeler **aucune** fonction dans son initializer, et **AD-10 INTERDIT** d'y
  /// mettre un `assert`. C'est l'**ACCESSEUR** [extra] qui porte la garde
  /// (`zNormalizeExtra`) — **le seul point que TOUTES les voies traversent**.
  final Map<String, dynamic> _extra;

  /// Échappatoire non typée (AD-4 pt.2), défaut `const {}` (jamais `null`),
  /// préservant les clés inconnues du cœur au round-trip. Hors-codegen.
  ///
  /// 🔴 **GARDE (ES-2.2b)** : l'accesseur **NORMALISE** ([zNormalizeExtra]) — il ne
  /// rend **JAMAIS** une clé réservée, **quelle que soit la voie d'écriture** (y
  /// compris le constructeur `const`, seule voie incapable de filtrer). Promesse
  /// **INCONDITIONNELLE**, sans `assert` et sans `throw` (AD-10).
  @override
  Map<String, dynamic> get extra => zNormalizeExtra(_extra, _reservedKeys);

  /// Identité déterministe *content-addressed* — **PURE, TOTALE, DÉTERMINISTE**
  /// (D2, parité lex `buildId`). `id` n'est **jamais** assigné par l'entité
  /// (AD-14) : le repository matérialise l'identité en appelant ce helper.
  ///
  /// `(s1, simple)` ≠ `(s1, dialogue)` ≠ `(s2, simple)` ⇒ trois ids distincts
  /// (pouvoir discriminant observé, R2).
  static String buildId(String sourceId, ZPodcastMode mode) =>
      '${sourceId}_${mode.name}';

  /// 🔴 Invalidation *content-addressed* — **COMPARAISON PURE, TOTALE,
  /// DÉTERMINISTE** (D4) : `true` **ssi** [sourceHash] diffère de
  /// [currentSourceHash]. **Aucun calcul de hash, aucune horloge.**
  ///
  /// La sortie dépend **RÉELLEMENT des DEUX empreintes** (leçon ES-2.3 : varier
  /// l'une OU l'autre change le résultat — prouvé bidirectionnellement).
  bool isStale(String currentSourceHash) => sourceHash != currentSourceHash;

  /// Sérialise vers la map persistée **complète** (snake_case, enums camelCase
  /// `name`, ISO-8601), **zéro-perte**.
  ///
  /// Réutilise le `toMap()` **généré** (champs du schéma) puis superpose les canaux
  /// hors-codegen : [extra] (l'**ACCESSEUR** qui NORMALISE, jamais `_extra` brut)
  /// et [extension].
  ///
  /// ⛔ **Ne réémet NI `updated_at` NI `is_deleted`** (garanti par construction :
  /// [_reservedKeys] ⊇ `ZSyncMeta.reservedKeys` ⇒ ces clés ne peuvent entrer dans
  /// [extra], donc plus en ressortir — AD-16/AD-19).
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      // 🔴 ES-2.2b — étale l'ACCESSEUR (qui NORMALISE), jamais le champ brut
      // `_extra`. `toMap()` est la frontière de SORTIE : un `_sanitizeExtra(extra)`
      // ICI serait DÉCORATIF — la garde vit à l'accesseur.
      ...extra,
      ...ZStudyPodcastZcrud(this).toMap(),
    };
    if (extension != null) {
      map['extension'] = extension!.toJson();
    }
    return map;
  }

  /// Copie **à sentinelle** (un argument omis préserve la valeur, `null` explicite
  /// le remet à `null`) — couvre **TOUS** les champs, [extension] et [extra]
  /// compris (que le `copyWith` **généré** remettrait à leurs défauts, faute
  /// d'annotation : perte silencieuse H3). Masque le `copyWith` de l'extension.
  ZStudyPodcast copyWith({
    Object? id = _$undefined,
    Object? sourceKind = _$undefined,
    Object? sourceId = _$undefined,
    Object? folderId = _$undefined,
    Object? mode = _$undefined,
    Object? sourceHash = _$undefined,
    Object? resultRef = _$undefined,
    Object? status = _$undefined,
    Object? createdAt = _$undefined,
    Object? extension = _$undefined,
    Object? extra = _$undefined,
  }) {
    return ZStudyPodcast(
      id: identical(id, _$undefined) ? this.id : id as String?,
      sourceKind: identical(sourceKind, _$undefined)
          ? this.sourceKind
          : sourceKind as ZPodcastSourceKind,
      sourceId:
          identical(sourceId, _$undefined) ? this.sourceId : sourceId as String,
      folderId:
          identical(folderId, _$undefined) ? this.folderId : folderId as String,
      mode: identical(mode, _$undefined) ? this.mode : mode as ZPodcastMode,
      sourceHash: identical(sourceHash, _$undefined)
          ? this.sourceHash
          : sourceHash as String,
      resultRef: identical(resultRef, _$undefined)
          ? this.resultRef
          : resultRef as String,
      status:
          identical(status, _$undefined) ? this.status : status as ZPodcastStatus,
      createdAt: identical(createdAt, _$undefined)
          ? this.createdAt
          : createdAt as DateTime?,
      extension: identical(extension, _$undefined)
          ? this.extension
          : extension as ZExtension?,
      // 🔴 ES-2.2b : la garde de `extra` est la MÊME FONCTION NOMMÉE qu'en
      // `fromMap` — `copyWith` ne peut plus ROUVRIR le filtre des clés réservées.
      extra: identical(extra, _$undefined)
          ? this.extra
          : _sanitizeExtra(extra as Map<String, dynamic>),
    );
  }

  /// Décode défensivement l'extension via [parser] (repli `null`, AD-4/AD-10).
  static ZExtension? _decodeExtension(
    Object? raw,
    ZStudyPodcastExtensionParser? parser,
  ) {
    // CR-LEX-33 : le corps de cette méthode était `if (parser == null) return
    // null;` — un hôte SANS parser lisait `null`, et comme `extension` est une
    // clé CONNUE (donc exclue d'`extra`), le payload d'un AUTRE hôte était
    // DÉTRUIT au décodage, avant toute ligne de code applicatif. Le cœur
    // préserve désormais verbatim ce que personne n'a su typer.
    return zDecodeExtension(raw, parser);
  }

  /// Clés persistées **RÉSERVÉES** (champs générés + `extension` + **clés de sync
  /// `ZSyncMeta`**) — dérivées de `$ZStudyPodcastFieldSpecs` pour rester synchrones
  /// avec le codegen.
  ///
  /// 🔴 **`...ZSyncMeta.reservedKeys` est ESSENTIEL** (AD-19.1) : le store écrit
  /// `updated_at`/`is_deleted` **dans le corps** avant de passer la map à [fromMap].
  /// Sans ce spread, ces clés — propriété du store — atterriraient dans [extra]
  /// (AD-4 violé) et seraient réémises par [toMap] (AD-16 violé). `ZStudyPodcast`
  /// ne déclarant **aucun** champ `updatedAt`/`isDeleted` (AD-19), c'est **ce
  /// spread — et lui seul —** qui l'empêche.
  static final Set<String> _reservedKeys = <String>{
    for (final spec in $ZStudyPodcastFieldSpecs) spec.name,
    'extension',
    ...ZSyncMeta.reservedKeys,
  };

  /// Extrait `extra` = clés **non réservées** de [map] (round-trip préservé) —
  /// **frontière d'ENTRÉE**. C'est [_sanitizeExtra], la garde **partagée**.
  static Map<String, dynamic> _extraFrom(Map<String, dynamic> map) =>
      _sanitizeExtra(map);

  /// 🔴 **LA GARDE PARTAGÉE de `extra`** (ES-2.2b) — appelée par [fromMap] **ET**
  /// [copyWith] (jamais divergentes — leçon H2). Délègue à [zSanitizeExtra]
  /// (`zcrud_core`, implémentation UNIQUE du repo).
  static Map<String, dynamic> _sanitizeExtra(Map<String, dynamic> raw) =>
      zSanitizeExtra(raw, _reservedKeys);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZStudyPodcast &&
          id == other.id &&
          sourceKind == other.sourceKind &&
          sourceId == other.sourceId &&
          folderId == other.folderId &&
          mode == other.mode &&
          sourceHash == other.sourceHash &&
          resultRef == other.resultRef &&
          status == other.status &&
          createdAt == other.createdAt &&
          extension == other.extension &&
          // Égalité PROFONDE : `extra` porte du JSON ARBITRAIRE (donc IMBRIQUÉ) —
          // une égalité superficielle casserait `fromMap(m) == fromMap(m)` dès
          // qu'une clé legacy porte une `Map`/`List` (DW-ES22-4).
          zJsonEquals(extra, other.extra);

  @override
  int get hashCode => Object.hashAll(<Object?>[
        id,
        sourceKind,
        sourceId,
        folderId,
        mode,
        sourceHash,
        resultRef,
        status,
        createdAt,
        extension,
        zJsonHash(extra),
      ]);
}

