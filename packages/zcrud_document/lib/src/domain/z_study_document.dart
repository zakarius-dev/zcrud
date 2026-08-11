/// Document d'étude `ZStudyDocument` — contenu partageable.
///
/// Cette entité est le contenu du document (nom de fichier, chemin de
/// stockage, statut d'ingestion). Elle est destinée au sous-arbre
/// partageable d'un dossier. L'état de lecture personnel (page courante,
/// zoom, pages maîtrisées) vit ailleurs, dans `ZDocumentReadingState` —
/// jamais colocalisé ici : partager un document n'emporte donc jamais la
/// progression de lecture d'autrui.
///
/// ## Aucune clé de mise à jour ni de suppression inline
///
/// Un portage verbatim d'un schéma legacy qui logerait `updatedAt` et
/// `isDeleted` inline dans l'entité recréerait une perte de données : les
/// stores écrivent la métadonnée de synchronisation dans le corps, après le
/// corps métier, à chaque écriture ⇒ un champ métier logé sous une clé
/// réservée serait écrasé silencieusement, sans erreur ni test rouge.
///
/// L'autorité Last-Write-Wins et le soft-delete vivent donc hors-entité,
/// dans `ZSyncMeta` (invariant AD-9). [createdAt] est conservé : sa clé
/// `created_at` est distincte de toute clé réservée (même politique que
/// `ZStudyFolder.archivedAt`).
///
/// **Slots d'extension (invariant AD-4)** : `extension` (typé, versionné,
/// parsé défensivement) + `extra` (échappatoire non typée, round-trip des
/// clés inconnues). Ces deux canaux sont hors-codegen : câblés à la main
/// autour du code généré. Les champs propres à une application sans
/// équivalent canonique passent par là, jamais par le schéma partagé.
///
/// ## `implements ZStudyDocumentRef` — strictement additif
///
/// L'entité implémente le port neutre `ZStudyDocumentRef`
/// (`zcrud_study_kernel`) pour que le socle de présentation puisse la
/// nommer sans arête directe vers ce paquet (invariant AD-1). Trois points,
/// tous vérifiables :
///
/// 1. Aucune arête nouvelle : `zcrud_document → zcrud_study_kernel` est
///    déjà déclarée, et déjà importée par `lib/src/presentation/`. Le
///    kernel est pur-Dart (son `pubspec` n'a aucun `flutter:`), donc
///    l'importer ici ne casse pas la pureté du domaine.
/// 2. Aucun champ ajouté. [title] et [formatKey] sont des getters dérivés
///    de [fileName]. Le schéma `@ZcrudField` est inchangé ⇒ `toMap`,
///    `fromMap`, `copyWith`, `==`/`hashCode` et les clés réservées sont
///    identiques au bit près. Rien n'entre ni ne sort de la persistance.
/// 3. Aucune signature modifiée : rien n'est renommé, rien ne change de
///    type, rien ne devient requis.
///
/// Le membre du port s'appelle `formatKey`, jamais `extension` — et ce
/// n'est pas une préférence de style : [extension] existe déjà ici et vaut
/// `ZExtension?` (slot d'extensibilité, invariant AD-4). Un `String? get
/// extension` entrerait en collision de type avec le champ hérité et ferait
/// de ce `implements` une erreur de compilation.
library;

import 'package:zcrud_annotations/zcrud_annotations.dart';
import 'package:zcrud_core/domain.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart'
    show ZStudyDocumentRef;

import 'z_document_status.dart';

part 'z_study_document.g.dart';

/// Reconstruit une [ZExtension] concrète depuis sa map JSON, ou `null`.
///
/// Fourni par l'application/le satellite (convention `X.fromJsonSafe`) et
/// injecté dans [ZStudyDocument.fromMap] : le cœur ne connaît pas les
/// sous-classes concrètes (invariant AD-4). Toute exception est absorbée en
/// `null` par [ZExtension.guard] (invariant AD-10).
typedef ZStudyDocumentExtensionParser = ZExtension? Function(
    Map<String, dynamic> json);

/// Document d'étude rattaché à un dossier — contenu partageable.
@ZcrudModel(kind: 'study_document')
class ZStudyDocument extends ZEntity
    with ZExtensible
    implements ZStudyDocumentRef {
  /// Construit un document (constructeur `const`).
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
    // Un paramètre nommé ne peut pas être privé en Dart, mais le slot brut
    // doit rester privé — c'est l'accesseur `extra` qui porte la garde.
    // ignore: prefer_initializing_formals
  }) : _extra = extra;

  /// Reconstruit défensivement depuis une map persistée (invariant AD-10).
  ///
  /// Délègue au décodeur généré (défauts sûrs : clés absentes → `''`/`0`/
  /// `null` ; `status` inconnu → [ZDocumentStatus.uploading], la première
  /// constante déclarée ; date illisible → `null`), puis sanitise les
  /// invariants de valeur que le codegen ignore :
  /// - [pageCount] `<= 0` ⇒ `null` (un document a au moins 1 page, ou on ne
  ///   sait pas) ;
  /// - [sizeBytes] `< 0` ⇒ `0`.
  ///
  /// Puis câble les deux canaux hors-codegen : [extension] (via
  /// [extensionParser], repli `null`) et [extra] (clés non réservées de la
  /// map — round-trip préservé).
  ///
  /// Corps non nu obligatoire : `ZStudyDocument` étant `ZExtensible`, une
  /// délégation nue au décodeur généré laisserait `extra` vide, ce que le
  /// build refuse.
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
      // Un `page_count` nul/négatif persisté (corruption) n'est pas un
      // nombre de pages — c'est « inconnu » (`null`), pas « zéro page ».
      //
      // La garde est la même fonction nommée qu'en `copyWith` : un
      // invariant de valeur doit tenir aux deux frontières
      // (désérialisation ET mutation applicative), sans quoi deux
      // implémentations jumelles finiraient par diverger.
      pageCount: sanitizePageCount(base.pageCount),
      // Une taille négative est impossible ⇒ défaut sûr `0`.
      sizeBytes: sanitizeSizeBytes(base.sizeBytes),
      createdAt: base.createdAt,
      extension: _decodeExtension(map['extension'], extensionParser),
      extra: _extraFrom(map),
    );
  }

  /// Identité opaque (`null` pour l'éphémère — jamais attribuée par
  /// l'entité). Vaut l'identifiant d'ingestion (aucune réconciliation).
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
  /// Défaut défensif [ZDocumentStatus.uploading] — première constante de
  /// l'enum (le repli généré d'un enum non-nullable est la première
  /// constante déclarée).
  @ZcrudField()
  final ZDocumentStatus status;

  /// Chemin de stockage renvoyé par le backend — jamais construit côté
  /// client (défaut `''`).
  @ZcrudField()
  final String storagePath;

  /// Nombre de pages best-effort à l'ingestion — `null` tant qu'inconnu.
  ///
  /// Doublon volontaire avec `ZDocumentReadingState.pageCount` : celui-ci
  /// est la valeur d'ingestion (OCR backend, best-effort, souvent absente) ;
  /// celui de l'état de lecture est l'autorité, consolidée au chargement
  /// réel du document côté viewer. Ce ne sont pas deux copies de la même
  /// donnée : ce sont deux sources de confiance différentes, et supprimer
  /// l'une ne serait pas une simplification.
  @ZcrudField()
  final int? pageCount;

  /// Taille du fichier en octets (défaut `0` ; jamais négative).
  @ZcrudField()
  final int sizeBytes;

  /// Date de création — clé persistée `created_at`, distincte de toute clé
  /// réservée de `ZSyncMeta`. `null` si absente/illisible.
  ///
  /// Il n'y a volontairement aucun `updatedAt` ici : la clé
  /// Last-Write-Wins est hors-entité (`ZSyncMeta.updatedAt`) — voir la
  /// dartdoc de bibliothèque.
  @ZcrudField()
  final DateTime? createdAt;

  /// Libellé principal affiché — `ZStudyDocumentRef.title`, alias dérivé de
  /// [fileName].
  ///
  /// Ce n'est pas un champ : c'est la même donnée sous le nom que le port
  /// (et les cartes du socle de présentation) emploie.
  ///
  /// Jamais `null` : [fileName] a pour défaut `''`. Le repli visible («
  /// sans titre ») est un libellé localisé, donc l'affaire de l'hôte —
  /// jamais du domaine.
  @override
  String get title => fileName;

  /// Clé de format opaque — `ZStudyDocumentRef.formatKey`, dérivée de
  /// [fileName] par [deriveFormatKey]. `null` si le nom ne porte aucun
  /// suffixe exploitable.
  ///
  /// Ce getter produit une clé, il ne la normalise pas. La normalisation de
  /// consommation (minuscules, point retiré, éclatement d'un type MIME en
  /// sous-type/famille) vit dans la présentation d'un satellite dont
  /// `zcrud_document` ne dépend pas — en dépendre serait une arête
  /// nouvelle, interdite (invariant AD-1). Ce n'est donc pas une
  /// duplication : les deux fonctions font des travaux différents
  /// (produire vs. résoudre), aux deux bouts de la même clé opaque. Sa
  /// sortie est déjà en minuscules et sans point, soit un point fixe de la
  /// normalisation aval.
  @override
  String? get formatKey => deriveFormatKey(fileName);

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

  /// Sérialise vers la map persistée complète (snake_case), zéro-perte.
  ///
  /// Réutilise le `toMap()` généré (champs du schéma) puis superpose les
  /// canaux hors-codegen : [extra] (clés inconnues préservées) et
  /// [extension].
  ///
  /// Indispensable : le `toMap()` généré (extension `ZStudyDocumentZcrud`)
  /// n'étale pas `extra` — sans ce `toMap()` d'instance, ce que `fromMap` a
  /// préservé ne serait jamais réémis.
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      // `toMap()` est la frontière de sortie : la seule que toutes les
      // voies d'écriture traversent ⇒ promesse inconditionnelle
      // (constructeur nominal compris). Étale l'accesseur (qui normalise),
      // jamais le champ brut `_extra`.
      ...extra,
      ...ZStudyDocumentZcrud(this).toMap(),
    };
    if (extension != null) {
      map['extension'] = extension!.toJson();
    }
    return map;
  }

  /// Copie à sentinelle (un argument omis préserve la valeur, `null`
  /// explicite la remet à `null`) — couvre tous les champs, [extension] et
  /// [extra] compris (que le `copyWith` généré remettrait à leurs défauts,
  /// faute d'annotation : perte silencieuse évitée ici). Masque le
  /// `copyWith` de l'extension.
  ///
  /// [pageCount] et [sizeBytes] sont sanitisés — exactement comme dans
  /// [fromMap].
  ///
  /// Un invariant de valeur a deux frontières : la désérialisation (une
  /// valeur corrompue qui entre) et la mutation applicative (une valeur
  /// hors-domaine qu'on écrit). Ne fermer que la première laisse la garde
  /// rouvrable : un `copyWith(sizeBytes: -1, pageCount: 0)` sans sanitation
  /// persisterait des valeurs hors du domaine de définition, que la
  /// relecture modifierait ensuite silencieusement ⇒ round-trip non
  /// idempotent, égalité cassée entre l'instance en mémoire et la même
  /// relue du store.
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
      // `<= 0` ⇒ « inconnu » (`null`), pas « zéro page » — voir `fromMap`.
      pageCount: sanitizePageCount(nextPageCount),
      // Une taille négative est impossible ⇒ défaut sûr `0`.
      sizeBytes: sanitizeSizeBytes(nextSizeBytes),
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

  /// Ramène un nombre de pages dans son domaine de définition — jamais de
  /// `throw`.
  ///
  /// `null` ou `<= 0` ⇒ `null` (« inconnu », pas « zéro page »). Déclarée
  /// publique et nommée : la garde est ainsi la même fonction aux deux
  /// frontières ([fromMap] et [copyWith]) — impossible qu'une des deux
  /// dérive.
  static int? sanitizePageCount(int? raw) =>
      raw == null || raw <= 0 ? null : raw;

  /// Ramène une taille de fichier dans son domaine de définition — jamais
  /// négative (repli `0`). Voir [sanitizePageCount].
  static int sanitizeSizeBytes(int raw) => raw < 0 ? 0 : raw;

  /// Dérive la clé de format opaque d'un nom de fichier — jamais de
  /// `throw` (invariant AD-10), jamais un enum (invariant AD-4). `null`
  /// quand aucun suffixe exploitable.
  ///
  /// Le nom est `deriveFormatKey`, pas `extension` : `ZStudyDocument` a
  /// déjà un membre `extension` de type `ZExtension?` (slot d'extensibilité).
  /// Publique et nommée — même discipline que [sanitizePageCount]/
  /// [sanitizeSizeBytes] : une règle testable directement, plutôt
  /// qu'enfouie dans un getter.
  ///
  /// ## Règles exactes (dans cet ordre)
  ///
  /// | Entrée | Sortie | Pourquoi |
  /// |---|---|---|
  /// | `'cours.PDF'` | `'pdf'` | minuscules — point fixe de la normalisation aval |
  /// | `'cours.pdf '` | `'pdf'` | le nom est trimé d'abord |
  /// | `'archive.tar.gz'` | `'gz'` | dernier point, jamais le premier |
  /// | `'notes/2026.v2/README'` | `null` | le point est dans un segment de chemin, pas dans le nom |
  /// | `'.gitignore'` | `null` | un point en tête nomme un fichier caché — ce n'est pas un suffixe |
  /// | `'README'` | `null` | aucun point |
  /// | `'cours.'` | `null` | suffixe vide |
  /// | `'Dr. Smith notes'` | `null` | un suffixe contenant une espace n'en est pas un |
  /// | `''` | `null` | rien à dériver |
  ///
  /// La règle « espace ⇒ pas un suffixe » n'est pas cosmétique : sans elle,
  /// `'Dr. Smith notes'` produirait la clé `'smith notes'`, c'est-à-dire une
  /// clé fausse (et non pas simplement absente). Une clé fausse résout un
  /// glyphe et une couleur de format arbitraires côté carte ; une clé
  /// absente retombe proprement sur le repli total (invariant AD-10).
  static String? deriveFormatKey(String fileName) {
    final String trimmed = fileName.trim();
    if (trimmed.isEmpty) return null;

    // Le nom seul : ce qui suit le dernier séparateur de chemin. Sans cela,
    // `'2026.v2/README'` rendrait `'v2/readme'` — une clé fausse.
    final int slash = trimmed.lastIndexOf('/');
    final int backslash = trimmed.lastIndexOf(r'\');
    final int sep = slash > backslash ? slash : backslash;
    final String base = sep < 0 ? trimmed : trimmed.substring(sep + 1);

    // `> 0` : un point en tête nomme un fichier caché (`.gitignore`), il
    // n'introduit aucun suffixe.
    final int dot = base.lastIndexOf('.');
    if (dot <= 0 || dot == base.length - 1) return null;

    final String suffix = base.substring(dot + 1);
    if (suffix.contains(RegExp(r'\s'))) return null;
    return suffix.toLowerCase();
  }

  /// Décode défensivement l'extension via [parser] (repli `null`).
  static ZExtension? _decodeExtension(
    Object? raw,
    ZStudyDocumentExtensionParser? parser,
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
  /// Le spread des clés de synchronisation est essentiel : `ZStudyDocument`
  /// ne déclarant aucun champ de synchronisation, c'est ce spread — et lui
  /// seul — qui empêche ces clés, que le store écrit dans le corps du
  /// document, d'atterrir dans [extra] (invariant AD-4 violé : `extra` =
  /// clés inconnues du domaine, pas clés du store) puis d'être réémises par
  /// [toMap] (invariant AD-9 violé : le soft-delete reste hors-entité) —
  /// cassant au passage l'égalité entre un document en mémoire et le même
  /// relu du store.
  static final Set<String> _reservedKeys = <String>{
    for (final spec in $ZStudyDocumentFieldSpecs) spec.name,
    'extension',
    ...ZSyncMeta.reservedKeys,
  };

  /// Extrait `extra` = clés non réservées de [map] (round-trip préservé).
  /// Rendu non modifiable (cohérence `ZExtensible`).
  static Map<String, dynamic> _extraFrom(Map<String, dynamic> map) =>
      _sanitizeExtra(map);

  /// La garde partagée de `extra` — appelée par les trois voies :
  /// [fromMap], [copyWith] et [toMap]. Délègue à [zSanitizeExtra]
  /// (`zcrud_core`, implémentation unique du dépôt).
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
