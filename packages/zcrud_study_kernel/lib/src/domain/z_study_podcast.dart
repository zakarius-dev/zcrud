/// Référence *content-addressed* d'un podcast généré `ZStudyPodcast` —
/// contenu personnel top-level à identité propre (`ZEntity` + `ZExtensible`,
/// `@ZcrudModel`).
///
/// Content-addressed : l'identité repose sur le couple (source, mode) ;
/// [sourceHash] est la clé d'invalidation. Seul un podcast prêt est persisté
/// durablement.
///
/// ## [sourceHash] est opaque, jamais calculé ici
///
/// Le kernel n'utilise aucune dépendance cryptographique. [sourceHash] est
/// donc un `String` opaque fourni par l'appelant (calculé en amont par le
/// seam de génération / le binding de l'hôte). L'invalidation est une
/// comparaison pure ([isStale], [ZPodcastFreshness]) : le kernel ne hashe
/// rien. Le hashing du contenu source est un seam de présentation/données,
/// pas un concern du domaine (invariant AD-4 : extension par injection).
///
/// ## Aucun horodatage de synchronisation inline
///
/// La fraîcheur Last-Write-Wins et le soft-delete vivent hors-entité
/// (`ZSyncMeta`, invariant AD-9). [sourceHash] et [createdAt] sont des clés
/// métier distinctes de toute clé de synchronisation. Les clés réservées
/// incluent celles de `ZSyncMeta` : elles ne polluent jamais [extra] et ne
/// sont jamais réémises par [toMap].
///
/// ## Identité content-addressed — [id] nullable + fonction pure [buildId]
///
/// `id` reste `String?` sous `@ZcrudId` (jamais assigné par l'entité,
/// matérialisé au repository — invariant AD-14) et l'entité expose la
/// fonction statique pure [ZStudyPodcast.buildId] que le repository appelle
/// pour matérialiser l'identité déterministe.
///
/// ## Tous les champs sont codegen-ables — aucun canal `Map` hors-codegen
///
/// Trois `String` + `folderId` `String` + trois enums + un `DateTime?`
/// ISO-8601 : aucun champ `Map`. Le seul slot hors-codegen est
/// [extension]/[extra] (patron commun aux entités du kernel).
///
/// ## Patron `extra` intégral
///
/// Constructeur `const` qui ne filtre rien, slot brut lu nulle part
/// ailleurs, accesseur [extra] normalisant (le seul point traversé par
/// toutes les voies), garde partagée entre `fromMap` et `copyWith`, [toMap]
/// étalant l'accesseur `...extra`, `copyWith` à sentinelle couvrant tous les
/// champs, égalité profonde (`zJsonEquals` / `zJsonHash`).
///
/// Pur Dart — aucune dépendance Flutter/Firebase/crypto.
library;

import 'package:zcrud_annotations/zcrud_annotations.dart';
import 'package:zcrud_core/domain.dart';

import 'z_podcast_mode.dart';
import 'z_podcast_source_kind.dart';
import 'z_podcast_status.dart';

part 'z_study_podcast.g.dart';

/// Reconstruit une [ZExtension] concrète depuis sa map JSON, ou `null`
/// (invariant AD-4).
///
/// Fourni par l'application/le satellite (convention `X.fromJsonSafe`) et
/// injecté dans [ZStudyPodcast.fromMap] : le domaine ne connaît pas les
/// sous-classes concrètes. Toute exception est absorbée en `null` par
/// [ZExtension.guard] (invariant AD-10).
typedef ZStudyPodcastExtensionParser = ZExtension? Function(
    Map<String, dynamic> json);

/// Référence *content-addressed* d'un podcast généré — contenu personnel
/// top-level à identité propre (invariant AD-14).
@ZcrudModel(kind: 'study_podcast')
class ZStudyPodcast extends ZEntity with ZExtensible {
  /// Construit une référence de podcast (constructeur `const`).
  ///
  /// Aucun `assert` ici, volontairement (invariant AD-10) : le décodeur
  /// généré appelle ce constructeur avec les valeurs brutes de la map
  /// persistée. Un `assert` y ferait échouer la désérialisation d'une
  /// donnée corrompue. Les gardes vivent exclusivement aux frontières
  /// [fromMap] / [copyWith], et la garde `extra` y est la même fonction
  /// nommée ([_sanitizeExtra]).
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
    // Un paramètre nommé ne peut pas être privé en Dart, mais le slot brut
    // doit rester privé — c'est l'accesseur `extra` qui porte la garde.
    // ignore: prefer_initializing_formals
  }) : _extra = extra;

  /// Reconstruit défensivement depuis une map persistée (invariant AD-10) —
  /// aucun cas ne lève, pas même sur une map vide.
  ///
  /// Délègue au décodeur généré pour les champs de schéma (défauts sûrs :
  /// `source_id`/`folder_id`/`source_hash`/`result_ref` absents → `''` ;
  /// `source_kind`/`mode`/`status` inconnus/`null`/non-`String` → première
  /// constante déclarée ; `created_at` illisible → `null`), puis câble les
  /// canaux hors-codegen : [extension] (via [extensionParser], repli
  /// `null`, protégé par [ZExtension.guard]) et [extra] (clés non réservées
  /// de la map — round-trip).
  ///
  /// Le corps ne délègue jamais nuement au décodeur généré (l'entité est
  /// `ZExtensible`) : une délégation nue laisserait [extra] vide, ce que le
  /// build refuse et qu'une garde runtime lèverait à l'enregistrement.
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

  /// Identité opaque (`null` pour l'éphémère — invariant AD-14 ; jamais
  /// attribuée par l'entité, matérialisée au repository via [buildId]).
  @override
  @ZcrudId()
  final String? id;

  /// Nature de la source (note / dossier / document).
  ///
  /// Défaut défensif [ZPodcastSourceKind.note] — première constante de
  /// l'enum (le repli généré d'un enum non-nullable est la première
  /// constante déclarée).
  @ZcrudField()
  final ZPodcastSourceKind sourceKind;

  /// Identifiant de la source d'étude — clé neutre `String` (défaut `''`).
  ///
  /// Aucun symbole d'un satellite n'est importé : c'est un `String` opaque.
  /// Compose l'identité content-addressed via [buildId].
  @ZcrudField()
  final String sourceId;

  /// Dossier d'appartenance — clé neutre `String` (défaut `''`, aucun
  /// import d'un type de dossier concret).
  @ZcrudField()
  final String folderId;

  /// Mode de synthèse (voix unique / dialogue).
  ///
  /// Défaut défensif [ZPodcastMode.simple] — première constante déclarée.
  /// Compose le suffixe de l'identité content-addressed via [buildId].
  @ZcrudField()
  final ZPodcastMode mode;

  /// Empreinte opaque de la source ayant produit ce podcast (persistée
  /// `source_hash`, défaut `''`) — clé d'invalidation.
  ///
  /// Jamais calculée par le kernel : elle est fournie par l'appelant. Le
  /// kernel la compare ([isStale]), il ne la hashe pas. Clé métier,
  /// distincte de toute clé de synchronisation.
  @ZcrudField()
  final String sourceHash;

  /// Référence opaque du résultat audio (chemin de stockage / URL) —
  /// persistée `result_ref`, défaut `''`. La résolution `resultRef → blob
  /// audio` est un seam d'application, hors périmètre du kernel.
  @ZcrudField()
  final String resultRef;

  /// État du cycle de vie du podcast.
  ///
  /// Défaut défensif [ZPodcastStatus.ready] — première constante déclarée
  /// (seul un podcast prêt est persisté durablement).
  @ZcrudField()
  final ZPodcastStatus status;

  /// Date de création — clé persistée `created_at`, ISO-8601, nullable
  /// (défaut `null`).
  ///
  /// Nullable car un `DateTime` n'a aucun constructeur `const`. `created_at`
  /// illisible → `null`, jamais un `throw`. Distincte de toute clé de
  /// synchronisation (hors-entité, invariant AD-9).
  @ZcrudField()
  final DateTime? createdAt;

  /// Slot type additif versionné (invariant AD-4), `null` si absent.
  /// Hors-codegen.
  @override
  final ZExtension? extension;

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

  /// Échappatoire non typée (invariant AD-4), défaut `const {}` (jamais
  /// `null`), préservant les clés inconnues du cœur au round-trip.
  /// Hors-codegen.
  ///
  /// Garde : l'accesseur normalise ([zNormalizeExtra]) — il ne rend jamais
  /// une clé réservée, quelle que soit la voie d'écriture (y compris le
  /// constructeur `const`, seule voie incapable de filtrer). Promesse
  /// inconditionnelle, sans `assert` et sans `throw` (invariant AD-10).
  @override
  Map<String, dynamic> get extra => zNormalizeExtra(_extra, _reservedKeys);

  /// Identité déterministe content-addressed — pure, totale, déterministe.
  /// `id` n'est jamais assigné par l'entité (invariant AD-14) : le
  /// repository matérialise l'identité en appelant cette fonction.
  ///
  /// `(s1, simple)` ≠ `(s1, dialogue)` ≠ `(s2, simple)` ⇒ trois identités
  /// distinctes.
  static String buildId(String sourceId, ZPodcastMode mode) =>
      '${sourceId}_${mode.name}';

  /// Invalidation content-addressed — comparaison pure, totale,
  /// déterministe : `true` ssi [sourceHash] diffère de [currentSourceHash].
  /// Aucun calcul de hash, aucune horloge.
  ///
  /// La sortie dépend réellement des deux empreintes (varier l'une ou
  /// l'autre change le résultat).
  bool isStale(String currentSourceHash) => sourceHash != currentSourceHash;

  /// Sérialise vers la map persistée complète (snake_case, enums camelCase
  /// `name`, ISO-8601), zéro-perte.
  ///
  /// Réutilise le `toMap()` généré (champs du schéma) puis superpose les
  /// canaux hors-codegen : [extra] (l'accesseur qui normalise, jamais le
  /// champ brut) et [extension].
  ///
  /// Ne réémet ni clé de mise à jour ni clé de suppression logique
  /// (garanti par construction : ces clés ne peuvent pas entrer dans
  /// [extra], donc ne peuvent pas en ressortir — invariant AD-9).
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      // Étale l'accesseur (qui normalise), jamais le champ brut `_extra`.
      // `toMap()` est la frontière de sortie.
      ...extra,
      ...ZStudyPodcastZcrud(this).toMap(),
    };
    if (extension != null) {
      map['extension'] = extension!.toJson();
    }
    return map;
  }

  /// Copie à sentinelle (un argument omis préserve la valeur, `null`
  /// explicite le remet à `null`) — couvre tous les champs, [extension] et
  /// [extra] compris (que le `copyWith` généré remettrait à leurs défauts,
  /// faute d'annotation : perte silencieuse évitée ici).
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
      // La garde de `extra` est la même fonction nommée qu'en `fromMap` —
      // `copyWith` ne peut pas rouvrir le filtre des clés réservées.
      extra: identical(extra, _$undefined)
          ? this.extra
          : _sanitizeExtra(extra as Map<String, dynamic>),
    );
  }

  /// Décode défensivement l'extension via [parser] (repli `null`,
  /// invariants AD-4/AD-10).
  static ZExtension? _decodeExtension(
    Object? raw,
    ZStudyPodcastExtensionParser? parser,
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
  /// Le spread des clés de synchronisation est essentiel : le store écrit
  /// ses métadonnées dans le corps avant de passer la map à [fromMap]. Sans
  /// ce spread, ces clés — propriété du store — atterriraient dans [extra]
  /// et seraient réémises par [toMap]. `ZStudyPodcast` ne déclarant aucun
  /// champ de synchronisation, c'est ce spread — et lui seul — qui
  /// l'empêche.
  static final Set<String> _reservedKeys = <String>{
    for (final spec in $ZStudyPodcastFieldSpecs) spec.name,
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
          // Égalité profonde : `extra` porte du JSON arbitraire (donc
          // imbriqué) — une égalité superficielle casserait
          // `fromMap(m) == fromMap(m)` dès qu'une clé legacy porte une
          // `Map`/`List`.
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
