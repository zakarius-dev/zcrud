/// Entité canonique `ZStudyFolder` — dossier d'organisation (Story E9-3,
/// AC2/AC3/AC4/AC5/AC6).
///
/// origine: lex_core (module « Étude ») — modèle `StudyFolder` (canonique §2.3).
/// Container **générique multi-type** : un dossier range N types hétérogènes
/// (cartes, notes, mindmaps) via un **rattachement INVERSE** — le dossier ne
/// liste **JAMAIS** ses items ; chaque item porte sa clé de rattachement
/// (`ZFlashcard.folderId`/`subFolderId`, note, mindmap…). Zéro-perte,
/// rétro-compatible (AD-10).
///
/// **Généré par `@ZcrudModel` (AD-3)** : `melos run generate` émet
/// `z_study_folder.g.dart` (`part`, gitignoré, régénéré) portant
/// `_$ZStudyFolderFromMap`, l'extension `ZStudyFolderZcrud` (`toMap`/`copyWith`),
/// `$ZStudyFolderFieldSpecs` et `registerZStudyFolder(ZcrudRegistry)`.
///
/// **Hiérarchie 2 niveaux — invariant AU REPOSITORY, jamais dans l'entité
/// (AD-14)** : `parentId == null` = racine (niveau 1) ; un enfant valide a un
/// parent racine (niveau 2). L'entité **ne s'auto-valide JAMAIS** (pas d'assert,
/// pas de throw) : la règle « 2 niveaux max » est portée par la primitive pure
/// `validatePlacement` (`z_study_folder_hierarchy.dart`), que le dépôt E9-4
/// compose dans `saveFolder` (`Left(ZDomainFailure)` si `depth >= 3`, sans
/// écrire).
///
/// **`archivedAt` = soft-archive réversible, DISTINCT du soft-delete (AC5)** :
/// archiver = poser `archivedAt` ; désarchiver = le remettre à `null`. Le
/// soft-**delete** (`is_deleted`) est une métadonnée **hors-entité**
/// (`ZSyncMeta`, E5/E9-4) : cette entité ne déclare **AUCUN** champ
/// `isDeleted`/`is_deleted`.
///
/// **`updatedAt` : MIROIR DE COMPATIBILITÉ DÉPRÉCIÉ (AD-19, ES-1.3 — OQ #3
/// TRANCHÉE)** : l'autorité de merge Last-Write-Wins est **exclusivement**
/// `ZSyncMeta.updatedAt` (**hors-entité**, `zcrud_core`), jamais ce champ. Le
/// champ interne subsiste, **déprécié**, uniquement pour les lectures **legacy**
/// (documents écrits avant AD-19, consommateurs DODLP/IFFD) : il est maintenu
/// **par l'adapter** via collision de clé `updated_at` (le store réécrit la clé
/// à chaque `put` et la relit dans `fromMap`). La divergence antérieure vs
/// `ZMindmap` (hors-entité) est donc **résolue en faveur du hors-entité**.
///
/// **Clés de sync RÉSERVÉES (AD-19)** : `updated_at` et `is_deleted`
/// (`ZSyncMeta.reservedKeys`) ne sont **jamais** capturées dans [extra] et
/// `is_deleted` n'est **jamais** réémis par [toMap] : ce sont des préoccupations
/// de **store**, pas de domaine.
///
/// **Bloc partage V2c déclaré mais INERTE (AC4)** : `isPublic`/`sharedWith`/
/// `canBeJoinedWithLink`/`coWorkersCanInviteOthers`/`shareId` portent des
/// défauts sûrs et **round-trip**, mais ne déclenchent **aucune** logique de
/// partage en E9-3 (discipline « figer tôt » du canonique — évite une migration
/// de schéma). Les métadonnées libres `relatedTopics`/`folderExplanation`
/// (génériques) et `countryCode` (douane-spécifique) **NE sont PAS** first-class :
/// elles transitent par [extra] (AC4).
///
/// **Slots d'extension AD-4** : mixe `ZExtensible` (cœur) → [extra]
/// (échappatoire non typée, round-trip des clés inconnues) + [extension] (slot
/// type additif versionné, parsé défensivement). Ces deux canaux NE sont PAS
/// gérés par le générateur : ils sont **câblés manuellement** autour du code
/// généré dans [ZStudyFolder.fromMap]/[toMap]/[copyWith] (même patron que
/// `ZFlashcard`, E9-1).
///
/// **Éphémère (AD-14)** : `isEphemeral` provient de `ZEntity` (`id == null`),
/// non redéfini. L'entité n'attribue jamais d'`id` ; la matérialisation est
/// portée par le repository (E9-4), hors périmètre ici.
library;

import 'package:zcrud_annotations/zcrud_annotations.dart';
import 'package:zcrud_core/domain.dart';

part 'z_study_folder.g.dart';

/// Reconstruit une [ZExtension] concrète depuis sa map JSON, ou `null`.
///
/// Fourni par l'app/le satellite (convention `X.fromJsonSafe`) et injecté dans
/// [ZStudyFolder.fromMap] : le cœur ne connaît pas les sous-classes concrètes
/// (AD-4). Toute exception est absorbée en `null` par [ZExtension.guard]
/// (AD-10), le parent survivant toujours.
typedef ZFolderExtensionParser = ZExtension? Function(Map<String, dynamic> json);

/// Dossier d'organisation canonique immuable (données + `copyWith` ; invariants
/// au repo).
@ZcrudModel(kind: 'study_folder', fieldRename: ZFieldRename.snake)
class ZStudyFolder extends ZEntity with ZExtensible {
  /// Construit un dossier (constructeur nommé — source du `copyWith`).
  const ZStudyFolder({
    this.id,
    required this.title,
    this.colorKey = '',
    this.parentId,
    this.ownerId = '',
    this.archivedAt,
    this.createdAt,
    this.updatedAt,
    this.isPublic = false,
    this.sharedWith = const <String>[],
    this.canBeJoinedWithLink = false,
    this.coWorkersCanInviteOthers = false,
    this.shareId,
    this.extension,
    Map<String, dynamic> extra = const <String, dynamic>{},
    // ⚠️ Le « fix » du lint (`this._extra`) est **ILLÉGAL** en Dart : un paramètre
    // NOMMÉ ne peut pas être privé (PRIVATE_OPTIONAL_PARAMETER). Or le slot brut
    // DOIT rester privé — c'est l'ACCESSEUR `extra` qui porte la garde (ES-2.2b).
    // ignore: prefer_initializing_formals
  }) : _extra = extra;

  /// Reconstruit **défensivement** depuis une map persistée (AD-10).
  ///
  /// Délègue au `_$ZStudyFolderFromMap` **généré** (défauts sûrs : `title`
  /// absent → `''`, `owner_id`/`color_key` absents → `''`, booléens V2c → `false`,
  /// `shared_with` non-liste → `const []`, dates illisibles → `null`), puis
  /// **câble manuellement** les deux canaux hors-codegen :
  /// - [extension] via [extensionParser] (repli `null`, `ZExtension.guard`) ;
  /// - [extra] = clés **non réservées** de la map (round-trip préservé — c'est
  ///   la voie de `relatedTopics`/`folderExplanation`/`countryCode`).
  ///
  /// Aucun cas ne fait échouer le parent (map vide, `extension` corrompue…).
  factory ZStudyFolder.fromMap(
    Map<String, dynamic> map, {
    ZFolderExtensionParser? extensionParser,
  }) {
    final base = _$ZStudyFolderFromMap(map);
    return ZStudyFolder(
      id: base.id,
      title: base.title,
      colorKey: base.colorKey,
      parentId: base.parentId,
      ownerId: base.ownerId,
      archivedAt: base.archivedAt,
      createdAt: base.createdAt,
      updatedAt: base.updatedAt,
      isPublic: base.isPublic,
      sharedWith: base.sharedWith,
      canBeJoinedWithLink: base.canBeJoinedWithLink,
      coWorkersCanInviteOthers: base.coWorkersCanInviteOthers,
      shareId: base.shareId,
      extension: _decodeExtension(map['extension'], extensionParser),
      extra: _extraFrom(map),
    );
  }

  /// Identité opaque (nullable pour l'éphémère — AC2 ; jamais attribuée par
  /// l'entité).
  @override
  @ZcrudId()
  final String? id;

  /// Titre du dossier (**requis** ; validateur éditeur — AC2).
  @ZcrudField(
    label: 'Titre',
    validators: <ZValidatorSpec>[ZValidatorSpec.required()],
  )
  final String title;

  /// Clé de thème libre (résolue côté UI), défaut `''` (AC2).
  @ZcrudField()
  final String colorKey;

  /// Parent (`null` = racine ; profondeur validée AU REPOSITORY — AC2/AC9).
  @ZcrudField()
  final String? parentId;

  /// Propriétaire (uid Firebase ou `'local'` hors-ligne ; attribué par l'app,
  /// jamais par l'entité), défaut `''` (AC2).
  @ZcrudField()
  final String ownerId;

  /// Soft-archive réversible (`null` = actif) — DISTINCT du soft-delete (AC5).
  @ZcrudField()
  final DateTime? archivedAt;

  /// Date de création (ISO-8601 ; `null` si éphémère).
  @ZcrudField()
  final DateTime? createdAt;

  /// **MIROIR DE COMPATIBILITÉ — DÉPRÉCIÉ (AD-19).**
  ///
  /// L'autorité de merge Last-Write-Wins est **exclusivement**
  /// `ZSyncMeta.updatedAt` (**hors-entité**). Ce champ est **maintenu par
  /// l'adapter** (collision de clé `updated_at` : le store réécrit la clé à
  /// chaque `put` et la relit dans [ZStudyFolder.fromMap]), UNIQUEMENT pour que
  /// les lectures **legacy** — documents écrits avant AD-19 et consommateurs
  /// existants (DODLP/IFFD) — restent valides (AD-10, évolution additive).
  /// **NE JAMAIS** l'utiliser pour décider d'un merge, d'un tri de sync ou
  /// d'une résolution de conflit.
  @Deprecated(
    'Miroir de compat (AD-19). Autorité de merge = ZSyncMeta.updatedAt '
    '(hors-entité). Ne jamais lire ce champ pour un merge/tri de sync.',
  )
  @ZcrudField()
  final DateTime? updatedAt;

  /// Partage V2c **inerte** : dossier public, défaut `false` (AC4).
  @ZcrudField()
  final bool isPublic;

  /// Partage V2c **inerte** : uids partagés, défaut `const []` (AC4).
  @ZcrudField()
  final List<String> sharedWith;

  /// Partage V2c **inerte** : rejoignable par lien, défaut `false` (AC4).
  @ZcrudField()
  final bool canBeJoinedWithLink;

  /// Partage V2c **inerte** : co-workers peuvent inviter, défaut `false` (AC4).
  @ZcrudField()
  final bool coWorkersCanInviteOthers;

  /// Partage V2c **inerte** : identifiant de partage, défaut `null` (AC4).
  @ZcrudField()
  final String? shareId;

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
  /// préservant les clés inconnues du cœur au round-trip (dont `relatedTopics`/
  /// `countryCode`). Hors-codegen.
  ///
  /// 🔴 **GARDE (DW-ES22-3/DW-ES22-4, remédiation ES-2.2b/HIGH-2)** : l'accesseur
  /// **NORMALISE** ([zNormalizeExtra]) — il ne rend **JAMAIS** une clé réservée,
  /// **quelle que soit la voie d'écriture** (y compris le constructeur `const`,
  /// seule voie incapable de filtrer). C'est **le seul point que TOUTES les voies
  /// traversent** ⇒ la promesse est **INCONDITIONNELLE**, sans `assert` et sans
  /// `throw` (AD-10), et **sans perdre `const`**.
  ///
  /// **Lecture SANS COPIE** sur le chemin chaud (`fromMap`/`copyWith` normalisent
  /// déjà **EAGER**) : le slot stocké est alors rendu **tel quel**.
  @override
  Map<String, dynamic> get extra => zNormalizeExtra(_extra, _reservedKeys);

  /// `true` si le dossier est archivé (soft-archive réversible — AC5).
  bool get isArchived => archivedAt != null;

  /// Sérialise vers la map persistée **complète** (snake_case).
  ///
  /// Réutilise le `toMap()` **généré** (champs scalaires/dates/listes) puis
  /// superpose les deux canaux hors-codegen : [extra] (clés inconnues
  /// préservées) et [extension].
  ///
  /// Ne produit **JAMAIS** de clé `is_deleted` — désormais **garanti par
  /// construction** (`_reservedKeys` ⊇ `ZSyncMeta.reservedKeys` : la clé ne peut
  /// plus entrer dans [extra], donc plus en ressortir), et non plus « par
  /// chance ». La clé `updated_at` **est** émise (miroir de compat déprécié)
  /// mais **sans autorité** : l'adapter l'écrase inconditionnellement par
  /// l'estampille `ZSyncMeta` à chaque `put`.
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      // 🔴 DW-ES22-3 (ES-2.2b, remédiation HIGH-1) — étale **l'ACCESSEUR**, qui
      // NORMALISE ([extra] ⇒ `zNormalizeExtra`), et **JAMAIS** le champ brut
      // `_extra`. C'est ce qui rend la promesse ci-dessus INCONDITIONNELLE, y
      // compris pour une instance née du **constructeur nominal** (`const` : il
      // ne peut RIEN filtrer).
      //
      // ⚠️ Un `_sanitizeExtra(extra)` ICI serait **DÉCORATIF** — MESURÉ
      // (code-review ES-2.2b, INJ-A) : le retirer laissait le gate **VERT** sur
      // 8 entités sur 9. Une garde qu'aucune machine n'exige est un vœu (R1).
      // La garde vit à l'ACCESSEUR ; la retirer de là rend (i.1a)/(i.1b)/(i.1c)
      // **ROUGES**.
      ...extra,
      ...ZStudyFolderZcrud(this).toMap(),
    };
    if (extension != null) {
      map['extension'] = extension!.toJson();
    }
    return map;
  }

  /// Copie avec sentinelle (un argument omis préserve la valeur, `null` explicite
  /// le remet à `null` — c'est la voie de **désarchivage** `archivedAt: null`).
  /// Couvre **tous** les champs, y compris [extension] et [extra] (que le
  /// `copyWith` généré ignore, faute d'annotation) — évite toute perte
  /// silencieuse.
  ZStudyFolder copyWith({
    Object? id = _$undefined,
    Object? title = _$undefined,
    Object? colorKey = _$undefined,
    Object? parentId = _$undefined,
    Object? ownerId = _$undefined,
    Object? archivedAt = _$undefined,
    Object? createdAt = _$undefined,
    Object? updatedAt = _$undefined,
    Object? isPublic = _$undefined,
    Object? sharedWith = _$undefined,
    Object? canBeJoinedWithLink = _$undefined,
    Object? coWorkersCanInviteOthers = _$undefined,
    Object? shareId = _$undefined,
    Object? extension = _$undefined,
    Object? extra = _$undefined,
  }) =>
      ZStudyFolder(
        id: identical(id, _$undefined) ? this.id : id as String?,
        title: identical(title, _$undefined) ? this.title : title as String,
        colorKey:
            identical(colorKey, _$undefined) ? this.colorKey : colorKey as String,
        parentId:
            identical(parentId, _$undefined) ? this.parentId : parentId as String?,
        ownerId:
            identical(ownerId, _$undefined) ? this.ownerId : ownerId as String,
        archivedAt: identical(archivedAt, _$undefined)
            ? this.archivedAt
            : archivedAt as DateTime?,
        createdAt: identical(createdAt, _$undefined)
            ? this.createdAt
            : createdAt as DateTime?,
        updatedAt: identical(updatedAt, _$undefined)
            ? this.updatedAt
            : updatedAt as DateTime?,
        isPublic:
            identical(isPublic, _$undefined) ? this.isPublic : isPublic as bool,
        sharedWith: identical(sharedWith, _$undefined)
            ? this.sharedWith
            : sharedWith as List<String>,
        canBeJoinedWithLink: identical(canBeJoinedWithLink, _$undefined)
            ? this.canBeJoinedWithLink
            : canBeJoinedWithLink as bool,
        coWorkersCanInviteOthers: identical(coWorkersCanInviteOthers, _$undefined)
            ? this.coWorkersCanInviteOthers
            : coWorkersCanInviteOthers as bool,
        shareId:
            identical(shareId, _$undefined) ? this.shareId : shareId as String?,
        extension: identical(extension, _$undefined)
            ? this.extension
            : extension as ZExtension?,
        // 🔴 DW-ES22-3 (ES-2.2b) : la garde est la MÊME FONCTION NOMMÉE qu'en
        // `fromMap` — `copyWith` ne peut plus ROUVRIR le filtre des clés
        // réservées. **MESURÉ** avant correctif :
        // `folder.copyWith(extra: {is_deleted: true}).toMap()` réémettait
        // `is_deleted: true` ⇒ collision avec l'autorité de sync (AD-9/AD-16).
        extra: identical(extra, _$undefined)
            ? this.extra
            : _sanitizeExtra(extra as Map<String, dynamic>),
      );

  /// Décode défensivement l'extension via [parser] (repli `null`).
  static ZExtension? _decodeExtension(
    Object? raw,
    ZFolderExtensionParser? parser,
  ) {
    // CR-LEX-33 : le corps de cette méthode était `if (parser == null) return
    // null;` — un hôte SANS parser lisait `null`, et comme `extension` est une
    // clé CONNUE (donc exclue d'`extra`), le payload d'un AUTRE hôte était
    // DÉTRUIT au décodage, avant toute ligne de code applicatif. Le cœur
    // préserve désormais verbatim ce que personne n'a su typer.
    return zDecodeExtension(raw, parser);
  }

  /// Clés persistées **réservées** (champs générés + `extension` + **clés de
  /// sync hors-entité AD-19**) — dérivées de `$ZStudyFolderFieldSpecs` pour
  /// rester synchrones avec le codegen.
  ///
  /// `...ZSyncMeta.reservedKeys` (`updated_at`, `is_deleted`) est **essentiel** :
  /// les stores écrivent ces clés **dans le corps** du document puis passent la
  /// map **complète** à [ZStudyFolder.fromMap]. Sans cette réserve, `is_deleted`
  /// (qui n'est **pas** un champ déclaré) atterrirait dans [extra] et serait
  /// **réémis** par [toMap] — une préoccupation de store qui fuit dans le
  /// domaine (AD-16), cassant au passage l'`==` entre une entité en mémoire et
  /// la même relue du store.
  static final Set<String> _reservedKeys = <String>{
    for (final spec in $ZStudyFolderFieldSpecs) spec.name,
    'extension',
    ...ZSyncMeta.reservedKeys,
  };

  /// Extrait `extra` = clés non réservées de [map] (round-trip préservé) —
  /// **frontière d'ENTRÉE**. C'est [_sanitizeExtra], la garde **partagée**.
  static Map<String, dynamic> _extraFrom(Map<String, dynamic> map) =>
      _sanitizeExtra(map);

  /// 🔴 **NORMALISATION EAGER de `extra`** (DW-ES22-3, ES-2.2b) — appelée par les
  /// voies **CAPABLES** de filtrer : [fromMap] et [copyWith].
  ///
  /// ⚠️ Ce n'est **PAS** le porteur de l'invariant (le constructeur `const` ne
  /// peut pas l'appeler) : c'est l'**ACCESSEUR** [extra] qui l'est. Ici, elle
  /// garantit que le slot STOCKÉ est **déjà propre** ⇒ la lecture est **SANS
  /// COPIE**. Cette propriété est **EXIGÉE PAR LE HARNAIS** (assertion (i.3),
  /// `identical(e.extra, e.extra)`) : la retirer d'ici rend le gate **ROUGE**.
  ///
  /// Délègue à [zSanitizeExtra] (`zcrud_core`) : implémentation **UNIQUE** du
  /// repo. Une fonction nommée unique rend le contournement **structurellement
  /// impossible** — deux implémentations jumelles, elles, divergent.
  static Map<String, dynamic> _sanitizeExtra(Map<String, dynamic> raw) =>
      zSanitizeExtra(raw, _reservedKeys);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZStudyFolder &&
          id == other.id &&
          title == other.title &&
          colorKey == other.colorKey &&
          parentId == other.parentId &&
          ownerId == other.ownerId &&
          archivedAt == other.archivedAt &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt &&
          isPublic == other.isPublic &&
          _listEquals(sharedWith, other.sharedWith) &&
          canBeJoinedWithLink == other.canBeJoinedWithLink &&
          coWorkersCanInviteOthers == other.coWorkersCanInviteOthers &&
          shareId == other.shareId &&
          extension == other.extension &&
          zJsonEquals(extra, other.extra);

  @override
  int get hashCode => Object.hashAll(<Object?>[
        id,
        title,
        colorKey,
        parentId,
        ownerId,
        archivedAt,
        createdAt,
        updatedAt,
        isPublic,
        Object.hashAll(sharedWith),
        canBeJoinedWithLink,
        coWorkersCanInviteOthers,
        shareId,
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
