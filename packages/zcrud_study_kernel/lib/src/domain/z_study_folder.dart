/// Entité canonique `ZStudyFolder` — dossier d'organisation.
///
/// Container générique multi-type : un dossier range N types hétérogènes
/// (cartes, notes, mindmaps) via un rattachement inverse — le dossier ne
/// liste jamais ses items ; chaque item porte sa clé de rattachement
/// (`folderId`/`subFolderId`). Zéro-perte, rétro-compatible (invariant
/// AD-10).
///
/// Généré par `@ZcrudModel` (invariant AD-3) : `melos run generate` émet le
/// fichier compagnon (`part`, gitignoré, régénéré) portant le décodeur
/// défensif, l'extension `toMap`/`copyWith`, les spécifications de champ et
/// l'enregistrement au registre.
///
/// **Hiérarchie 2 niveaux — invariant au repository, jamais dans l'entité
/// (invariant AD-14)** : `parentId == null` = racine (niveau 1) ; un enfant
/// valide a un parent racine (niveau 2). L'entité ne s'auto-valide jamais
/// (pas d'assert, pas de `throw`) : la règle « 2 niveaux max » est portée
/// par la primitive pure `validatePlacement` (`z_study_folder_hierarchy.dart`),
/// que le dépôt compose dans sa méthode de sauvegarde (`Left(ZDomainFailure)`
/// si la profondeur dépasse 2, sans écrire).
///
/// **`archivedAt` = soft-archive réversible, distinct du soft-delete** :
/// archiver = poser `archivedAt` ; désarchiver = le remettre à `null`. Le
/// soft-delete (`is_deleted`) est une métadonnée hors-entité (`ZSyncMeta`) :
/// cette entité ne déclare aucun champ `isDeleted`/`is_deleted`.
///
/// **`updatedAt` : miroir de compatibilité déprécié (invariant AD-9)** :
/// l'autorité de merge Last-Write-Wins est exclusivement `ZSyncMeta.
/// updatedAt` (hors-entité, `zcrud_core`), jamais ce champ. Le champ interne
/// subsiste, déprécié, uniquement pour les lectures legacy (documents
/// écrits avant l'introduction de `ZSyncMeta`, consommateurs existants) : il
/// est maintenu par l'adaptateur via collision de clé `updated_at` (le
/// store réécrit la clé à chaque écriture et la relit dans `fromMap`).
///
/// **Clés de synchronisation réservées (invariant AD-9)** : `updated_at` et
/// `is_deleted` (`ZSyncMeta.reservedKeys`) ne sont jamais capturées dans
/// [extra] et `is_deleted` n'est jamais réémis par [toMap] : ce sont des
/// préoccupations de store, pas de domaine.
///
/// **Bloc de partage déclaré mais inerte** : `isPublic`/`sharedWith`/
/// `canBeJoinedWithLink`/`coWorkersCanInviteOthers`/`shareId` portent des
/// défauts sûrs et sont round-trip, mais ne déclenchent aucune logique de
/// partage dans ce kernel (discipline « figer tôt » du schéma canonique —
/// évite une migration ultérieure). Les métadonnées libres (sujets
/// associés, explication du dossier, code pays…) ne sont pas first-class :
/// elles transitent par [extra].
///
/// **Slots d'extension (invariant AD-4)** : mixe `ZExtensible` (cœur) →
/// [extra] (échappatoire non typée, round-trip des clés inconnues) +
/// [extension] (slot type additif versionné, parsé défensivement). Ces deux
/// canaux ne sont pas gérés par le générateur : ils sont câblés
/// manuellement autour du code généré dans [ZStudyFolder.fromMap]/[toMap]/
/// [copyWith].
///
/// **Éphémère (invariant AD-14)** : `isEphemeral` provient de `ZEntity`
/// (`id == null`), non redéfini. L'entité n'attribue jamais d'identifiant ;
/// la matérialisation est portée par le repository, hors périmètre ici.
library;

import 'package:zcrud_annotations/zcrud_annotations.dart';
import 'package:zcrud_core/domain.dart';

part 'z_study_folder.g.dart';

/// Reconstruit une [ZExtension] concrète depuis sa map JSON, ou `null`.
///
/// Fourni par l'application/le satellite (convention `X.fromJsonSafe`) et
/// injecté dans [ZStudyFolder.fromMap] : le cœur ne connaît pas les
/// sous-classes concrètes (invariant AD-4). Toute exception est absorbée en
/// `null` par [ZExtension.guard] (invariant AD-10), le parent survivant
/// toujours.
typedef ZFolderExtensionParser = ZExtension? Function(Map<String, dynamic> json);

/// Dossier d'organisation canonique immuable (données + `copyWith` ;
/// invariants au repository).
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
    // Un paramètre nommé ne peut pas être privé en Dart, mais le slot brut
    // doit rester privé — c'est l'accesseur `extra` qui porte la garde.
    // ignore: prefer_initializing_formals
  }) : _extra = extra;

  /// Reconstruit défensivement depuis une map persistée (invariant AD-10).
  ///
  /// Délègue au décodeur généré (défauts sûrs : `title` absent → `''`,
  /// `owner_id`/`color_key` absents → `''`, booléens de partage → `false`,
  /// `shared_with` non-liste → `const []`, dates illisibles → `null`), puis
  /// câble manuellement les deux canaux hors-codegen :
  /// - [extension] via [extensionParser] (repli `null`, protégé par
  ///   [ZExtension.guard]) ;
  /// - [extra] = clés non réservées de la map (round-trip préservé — c'est
  ///   la voie des métadonnées libres non first-class).
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

  /// Identité opaque (nullable pour l'éphémère ; jamais attribuée par
  /// l'entité).
  @override
  @ZcrudId()
  final String? id;

  /// Titre du dossier (requis ; validateur éditeur).
  @ZcrudField(
    label: 'Titre',
    validators: <ZValidatorSpec>[ZValidatorSpec.required()],
  )
  final String title;

  /// Clé de thème libre (résolue côté UI), défaut `''`.
  @ZcrudField()
  final String colorKey;

  /// Parent (`null` = racine ; profondeur validée au repository).
  @ZcrudField()
  final String? parentId;

  /// Propriétaire (identifiant utilisateur, ou une valeur conventionnelle
  /// hors-ligne ; attribué par l'application, jamais par l'entité), défaut
  /// `''`.
  @ZcrudField()
  final String ownerId;

  /// Soft-archive réversible (`null` = actif) — distinct du soft-delete.
  @ZcrudField()
  final DateTime? archivedAt;

  /// Date de création (ISO-8601 ; `null` si éphémère).
  @ZcrudField()
  final DateTime? createdAt;

  /// Miroir de compatibilité — déprécié (invariant AD-9).
  ///
  /// L'autorité de merge Last-Write-Wins est exclusivement `ZSyncMeta.
  /// updatedAt` (hors-entité). Ce champ est maintenu par l'adaptateur
  /// (collision de clé `updated_at` : le store réécrit la clé à chaque
  /// écriture et la relit dans [ZStudyFolder.fromMap]), uniquement pour que
  /// les lectures legacy — documents écrits avant l'introduction de
  /// `ZSyncMeta` et consommateurs existants — restent valides (évolution
  /// additive, invariant AD-10). Ne jamais l'utiliser pour décider d'un
  /// merge, d'un tri de synchronisation ou d'une résolution de conflit.
  @Deprecated(
    'Miroir de compat (AD-19). Autorité de merge = ZSyncMeta.updatedAt '
    '(hors-entité). Ne jamais lire ce champ pour un merge/tri de sync.',
  )
  @ZcrudField()
  final DateTime? updatedAt;

  /// Partage inerte : dossier public, défaut `false`.
  @ZcrudField()
  final bool isPublic;

  /// Partage inerte : identifiants partagés, défaut `const []`.
  @ZcrudField()
  final List<String> sharedWith;

  /// Partage inerte : rejoignable par lien, défaut `false`.
  @ZcrudField()
  final bool canBeJoinedWithLink;

  /// Partage inerte : les collaborateurs peuvent inviter, défaut `false`.
  @ZcrudField()
  final bool coWorkersCanInviteOthers;

  /// Partage inerte : identifiant de partage, défaut `null`.
  @ZcrudField()
  final String? shareId;

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
  ///
  /// Lecture sans copie sur le chemin chaud (`fromMap`/`copyWith`
  /// normalisent déjà en amont) : le slot stocké est alors rendu tel quel.
  @override
  Map<String, dynamic> get extra => zNormalizeExtra(_extra, _reservedKeys);

  /// `true` si le dossier est archivé (soft-archive réversible).
  bool get isArchived => archivedAt != null;

  /// Sérialise vers la map persistée complète (snake_case).
  ///
  /// Réutilise le `toMap()` généré (champs scalaires/dates/listes) puis
  /// superpose les deux canaux hors-codegen : [extra] (clés inconnues
  /// préservées) et [extension].
  ///
  /// Ne produit jamais de clé de suppression logique — garanti par
  /// construction (la clé ne peut pas entrer dans [extra], donc ne peut pas
  /// en ressortir). La clé `updated_at` est émise (miroir de compatibilité
  /// déprécié) mais sans autorité : l'adaptateur l'écrase inconditionnellement
  /// par l'estampille `ZSyncMeta` à chaque écriture.
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      // Étale l'accesseur, qui normalise ([extra] ⇒ `zNormalizeExtra`), et
      // jamais le champ brut `_extra`. C'est ce qui rend la promesse
      // ci-dessus inconditionnelle, y compris pour une instance née du
      // constructeur nominal (`const` : il ne peut rien filtrer).
      ...extra,
      ...ZStudyFolderZcrud(this).toMap(),
    };
    if (extension != null) {
      map['extension'] = extension!.toJson();
    }
    return map;
  }

  /// Copie avec sentinelle (un argument omis préserve la valeur, `null`
  /// explicite le remet à `null` — c'est la voie de désarchivage
  /// `archivedAt: null`). Couvre tous les champs, y compris [extension] et
  /// [extra] (que le `copyWith` généré ignore, faute d'annotation) — évite
  /// toute perte silencieuse.
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
        // La garde est la même fonction nommée qu'en `fromMap` —
        // `copyWith` ne peut pas rouvrir le filtre des clés réservées.
        extra: identical(extra, _$undefined)
            ? this.extra
            : _sanitizeExtra(extra as Map<String, dynamic>),
      );

  /// Décode défensivement l'extension via [parser] (repli `null`).
  static ZExtension? _decodeExtension(
    Object? raw,
    ZFolderExtensionParser? parser,
  ) {
    // Un hôte sans parser doit préserver verbatim ce qu'il n'a pas su
    // typer plutôt que le détruire au décodage : `extension` étant une clé
    // connue (donc exclue d'`extra`), un `null` inconditionnel effacerait
    // le payload d'un autre hôte avant toute ligne de code applicatif.
    return zDecodeExtension(raw, parser);
  }

  /// Clés persistées réservées (champs générés + `extension` + clés de
  /// synchronisation hors-entité) — dérivées des spécifications de champ
  /// générées pour rester synchrones avec le codegen.
  ///
  /// Le spread des clés de synchronisation est essentiel : les stores
  /// écrivent ces clés dans le corps du document puis passent la map
  /// complète à [ZStudyFolder.fromMap]. Sans cette réserve, une clé de
  /// suppression logique (qui n'est pas un champ déclaré) atterrirait dans
  /// [extra] et serait réémise par [toMap] — une préoccupation de store qui
  /// fuit dans le domaine, cassant au passage l'égalité entre une entité en
  /// mémoire et la même relue du store.
  static final Set<String> _reservedKeys = <String>{
    for (final spec in $ZStudyFolderFieldSpecs) spec.name,
    'extension',
    ...ZSyncMeta.reservedKeys,
  };

  /// Extrait `extra` = clés non réservées de [map] (round-trip préservé) —
  /// frontière d'entrée. C'est [_sanitizeExtra], la garde partagée.
  static Map<String, dynamic> _extraFrom(Map<String, dynamic> map) =>
      _sanitizeExtra(map);

  /// Normalisation en amont de `extra` — appelée par les voies capables de
  /// filtrer : [fromMap] et [copyWith].
  ///
  /// Ce n'est pas le porteur de l'invariant (le constructeur `const` ne
  /// peut pas l'appeler) : c'est l'accesseur [extra] qui l'est. Ici, elle
  /// garantit que le slot stocké est déjà propre ⇒ la lecture est sans
  /// copie.
  ///
  /// Délègue à [zSanitizeExtra] (`zcrud_core`) : implémentation unique du
  /// dépôt. Une fonction nommée unique rend le contournement
  /// structurellement impossible — deux implémentations jumelles, elles,
  /// divergent.
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
