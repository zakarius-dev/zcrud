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
/// compose dans `saveFolder` (`Left(DomainFailure)` si `depth >= 3`, sans
/// écrire).
///
/// **`archivedAt` = soft-archive réversible, DISTINCT du soft-delete (AC5)** :
/// archiver = poser `archivedAt` ; désarchiver = le remettre à `null`. Le
/// soft-**delete** (`is_deleted`) est une métadonnée **hors-entité**
/// (`ZSyncMeta`, E5/E9-4) : cette entité ne déclare **AUCUN** champ
/// `isDeleted`/`is_deleted`.
///
/// **`updatedAt` DANS l'entité (AC6)** : champ de première classe = clé de merge
/// LWW (E9-4). Divergence **assumée** vs `ZMindmap` (qui le porte hors-entité
/// `ZSyncMeta`) — open question canonique #3 non tranchée ici, E9-3 reste fidèle
/// à `StudyFolder`.
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
    this.extra = const <String, dynamic>{},
  });

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

  /// Date de mise à jour (ISO-8601 ; **clé de merge LWW**, DANS l'entité — AC6).
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

  /// Échappatoire non typée (AD-4 pt.2), défaut `const {}` (jamais `null`),
  /// préservant les clés inconnues du cœur au round-trip (dont `relatedTopics`/
  /// `countryCode`). Hors-codegen.
  @override
  final Map<String, dynamic> extra;

  /// `true` si le dossier est archivé (soft-archive réversible — AC5).
  bool get isArchived => archivedAt != null;

  /// Sérialise vers la map persistée **complète** (snake_case).
  ///
  /// Réutilise le `toMap()` **généré** (champs scalaires/dates/listes) puis
  /// superpose les deux canaux hors-codegen : [extra] (clés inconnues
  /// préservées) et [extension]. Ne produit **aucune** clé `is_deleted` (AC5).
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
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
        extra: identical(extra, _$undefined)
            ? this.extra
            : extra as Map<String, dynamic>,
      );

  /// Décode défensivement l'extension via [parser] (repli `null`).
  static ZExtension? _decodeExtension(
    Object? raw,
    ZFolderExtensionParser? parser,
  ) {
    if (parser == null) return null;
    final map = _asStringMap(raw);
    if (map == null) return null;
    return ZExtension.guard<ZExtension?>(() => parser(map));
  }

  /// Clés persistées **réservées** (champs générés + `extension`) — dérivées de
  /// `$ZStudyFolderFieldSpecs` pour rester synchrones avec le codegen.
  static final Set<String> _reservedKeys = <String>{
    for (final spec in $ZStudyFolderFieldSpecs) spec.name,
    'extension',
  };

  /// Extrait `extra` = clés non réservées de [map] (round-trip préservé).
  /// Rendu **non-modifiable** (cohérence `ZExtensible`).
  static Map<String, dynamic> _extraFrom(Map<String, dynamic> map) =>
      Map<String, dynamic>.unmodifiable(<String, dynamic>{
        for (final e in map.entries)
          if (!_reservedKeys.contains(e.key)) e.key: e.value,
      });

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
          _mapEquals(extra, other.extra);

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
        _mapHash(extra),
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

bool _listEquals<T>(List<T>? a, List<T>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null) return false;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _mapEquals(Map<String, dynamic> a, Map<String, dynamic> b) {
  if (a.length != b.length) return false;
  for (final e in a.entries) {
    if (!b.containsKey(e.key) || b[e.key] != e.value) return false;
  }
  return true;
}

int _mapHash(Map<String, dynamic> m) {
  var h = 0;
  for (final e in m.entries) {
    h ^= Object.hash(e.key, e.value);
  }
  return h;
}
