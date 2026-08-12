/// État de lecture personnel d'un document.
///
/// ## État personnel, jamais colocalisé avec le contenu
///
/// Cet état (dernière page lue, zoom, pages maîtrisées) est personnel : il
/// ne vit jamais dans le sous-arbre partageable du document
/// ([ZStudyDocument]) — exactement comme l'état de répétition espacée ne
/// vit jamais dans la carte. Partager ou dupliquer un document n'emporte
/// donc jamais la progression de lecture d'autrui. La non-colocation est
/// prouvée par machine (aucune clé de lecture dans les spécifications de
/// champ du document, aucune imbrication de cette entité dans le document).
/// La résolution de collection (où persister cet état) reste du ressort de
/// l'adaptateur backend, hors périmètre de ce kernel.
///
/// ## Aucune clé de mise à jour inline
///
/// L'autorité Last-Write-Wins et le soft-delete vivent hors-entité
/// (`ZSyncMeta`, invariant AD-9) : cette entité ne déclare ni `updatedAt` ni
/// `isDeleted`. Loger une telle clé dans le corps métier serait un piège :
/// le store écrivant sa métadonnée après le corps à chaque écriture, un tel
/// champ serait écrasé silencieusement.
///
/// ## Pas un `ZEntity` : la clé d'identité est [docId]
///
/// Jointure 1↔1 avec le document (même patron que l'état de répétition
/// espacée, clé par identifiant de carte) : aucun identifiant propre,
/// aucune réconciliation d'identifiant.
///
/// ## `learning` est un canal hors-codegen
///
/// [ZDocumentLearningInfo] n'est pas un `@ZcrudModel` (le générateur ne
/// supporte aucun type `Map`), or la catégorie sous-modèle exige
/// l'annotation. `learning` ne peut donc pas être un `@ZcrudField` : il est
/// décodé et réémis à la main, et sa clé `'learning'` est ajoutée aux clés
/// réservées — sans quoi elle atterrirait dans `extra` et serait réémise en
/// double (invariant AD-4 violé, égalité cassée entre une instance mémoire
/// et la même relue du store).
library;

import 'package:zcrud_annotations/zcrud_annotations.dart';
import 'package:zcrud_core/domain.dart';

import 'z_document_learning_info.dart';
import 'z_document_viewer_prefs.dart';

part 'z_document_reading_state.g.dart';

/// Reconstruit une [ZExtension] concrète depuis sa map JSON, ou `null`
/// (invariant AD-4).
typedef ZDocumentReadingStateExtensionParser = ZExtension? Function(
    Map<String, dynamic> json);

/// Clé persistée du canal hors-codegen `learning`.
///
/// Déclarée une seule fois, consommée par [ZDocumentReadingState.fromMap],
/// [ZDocumentReadingState.toMap] et [ZDocumentReadingState._reservedKeys] :
/// aucun littéral dupliqué.
const String kLearningKey = 'learning';

/// État de lecture personnel d'un document — clé par [docId] (pas un
/// `ZEntity`).
@ZcrudModel(kind: 'document_reading_state')
class ZDocumentReadingState with ZExtensible {
  /// Construit un état de lecture (constructeur `const`).
  const ZDocumentReadingState({
    this.docId = '',
    this.currentPage = 1,
    this.pageCount,
    this.prefs = const ZDocumentViewerPrefs(),
    this.learning = ZDocumentLearningInfo.empty,
    this.extension,
    Map<String, dynamic> extra = const <String, dynamic>{},
    // Un paramètre nommé ne peut pas être privé en Dart, mais le slot brut
    // doit rester privé — c'est l'accesseur `extra` qui porte la garde.
    // ignore: prefer_initializing_formals
  }) : _extra = extra;

  /// Reconstruit défensivement depuis une map persistée (invariant AD-10).
  ///
  /// Délègue au décodeur généré (défauts sûrs : `doc_id` absent → `''` ;
  /// `current_page` absent/non numérique → `1` ; `page_count` illisible →
  /// `null` ; `prefs` corrompue — `42`, une chaîne, une liste — → les
  /// défauts de [ZDocumentViewerPrefs]), puis sanitise les invariants que
  /// le codegen ignore :
  /// - [currentPage] est 1-based ⇒ `< 1` (`0`, `-3`) ⇒ `1` ;
  /// - [pageCount] `<= 0` ⇒ `null` (« inconnu », pas « zéro page »).
  ///
  /// Puis câble les canaux hors-codegen : `learning` (via
  /// [ZDocumentLearningInfo.fromJsonSafe] — non-map ⇒ `empty`, jamais de
  /// `throw`), [extension] (repli `null`) et [extra] (clés non réservées).
  ///
  /// Corps non nu obligatoire (`ZExtensible`) : une délégation nue
  /// laisserait `extra` vide, ce que le build refuse.
  ///
  /// Aucun cas ne lève — pas même `ZDocumentReadingState.fromMap(const {})`.
  factory ZDocumentReadingState.fromMap(
    Map<String, dynamic> map, {
    ZDocumentReadingStateExtensionParser? extensionParser,
  }) {
    final base = _$ZDocumentReadingStateFromMap(map);
    final rawPageCount = base.pageCount;
    return ZDocumentReadingState(
      docId: base.docId,
      // Pagination 1-based (alignée sur les contrôleurs de viewer PDF).
      // `0`, négatif ou corrompu ⇒ première page — jamais une page
      // impossible.
      currentPage: base.currentPage < 1 ? 1 : base.currentPage,
      // `<= 0` ⇒ « inconnu » (`null`), pas « zéro page ».
      pageCount:
          rawPageCount == null || rawPageCount <= 0 ? null : rawPageCount,
      prefs: base.prefs,
      // Canal hors-codegen.
      learning: ZDocumentLearningInfo.fromJsonSafe(map[kLearningKey]),
      extension: _decodeExtension(map['extension'], extensionParser),
      extra: _extraFrom(map),
    );
  }

  /// Identité : le document dont c'est l'état de lecture (jointure 1↔1).
  /// Défaut `''`. Pas d'identifiant propre.
  @ZcrudField()
  final String docId;

  /// Dernière page lue — 1-based (défaut `1`, première ouverture ; jamais
  /// `< 1`).
  @ZcrudField(defaultValue: 1)
  final int currentPage;

  /// Nombre total de pages — autorité de la méta « lues / total ».
  ///
  /// Consolidé au chargement réel du document (viewer), il comble le
  /// `ZStudyDocument.pageCount` best-effort d'ingestion. `null` tant
  /// qu'inconnu ; jamais `<= 0`. Le doublon avec `ZStudyDocument.pageCount`
  /// est volontaire : deux sources de confiance distinctes — ne pas
  /// « factoriser ».
  @ZcrudField()
  final int? pageCount;

  /// Préférences de lecture (zoom, sens, disposition) — sous-modèle
  /// `@ZcrudModel` décodé défensivement (map corrompue ⇒ défauts, jamais de
  /// `throw`).
  @ZcrudField()
  final ZDocumentViewerPrefs prefs;

  /// État d'apprentissage par page — canal hors-codegen : sa clé
  /// [kLearningKey] est réservée, il est décodé et réémis à la main. Défaut
  /// [ZDocumentLearningInfo.empty].
  @ZcrudIgnore()
  final ZDocumentLearningInfo learning;

  /// Slot type additif versionné (invariant AD-4), `null` si absent.
  /// Hors-codegen.
  @override
  final ZExtension? extension;

  /// Échappatoire non typée (invariant AD-4), défaut `const {}` (jamais
  /// `null`). Hors-codegen.
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
  /// Réutilise le `toMap()` généré (champs du schéma, dont `prefs`
  /// imbriquée) puis superpose les trois canaux hors-codegen : [extra],
  /// `learning` (toujours émis, même vide — round-trip idempotent) et
  /// [extension].
  ///
  /// Ne réémet ni clé de mise à jour ni clé de suppression logique : ces
  /// clés appartiennent au store (`ZSyncMeta`), pas au domaine (invariant
  /// AD-9).
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      // `toMap()` est la frontière de sortie : la seule que toutes les
      // voies d'écriture traversent ⇒ la promesse ci-dessus est
      // inconditionnelle. Étale l'accesseur (qui normalise), jamais le
      // champ brut `_extra`.
      ...extra,
      ...ZDocumentReadingStateZcrud(this).toMap(),
      kLearningKey: learning.toJson(),
    };
    if (extension != null) {
      map['extension'] = extension!.toJson();
    }
    return map;
  }

  /// Copie à sentinelle — couvre tous les champs, y compris `learning`,
  /// [extension] et [extra] (que le `copyWith` généré ignore ou remettrait
  /// à leurs défauts : perte silencieuse évitée ici). Masque le `copyWith`
  /// de l'extension.
  ///
  /// [currentPage] et [pageCount] sont sanitisés comme au décodage (une
  /// mutation applicative ne doit pas rouvrir l'invariant que `fromMap`
  /// ferme).
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
    ZDocumentReadingStateExtensionParser? parser,
  ) {
    // Un hôte sans parser doit préserver verbatim ce qu'il n'a pas su
    // typer plutôt que le détruire au décodage : `extension` étant une clé
    // connue (donc exclue d'`extra`), un `null` inconditionnel effacerait
    // le payload d'un autre hôte avant toute ligne de code applicatif.
    return zDecodeExtension(raw, parser);
  }

  /// Clés persistées réservées (champs générés + `extension` + `learning`
  /// + clés de synchronisation) — dérivées des spécifications de champ
  /// générées pour rester synchrones avec le codegen.
  ///
  /// Le spread des clés de synchronisation est essentiel : cette entité
  /// est persistée top-level et le store écrit ses métadonnées dans le
  /// corps du document avant de passer la map complète à [fromMap]. Sans ce
  /// spread, ces clés — propriété du store — atterriraient dans [extra] et
  /// seraient réémises par [toMap].
  ///
  /// [kLearningKey] est tout aussi essentiel : le canal hors-codegen étant
  /// réémis à la main par [toMap], sa clé doit être réservée — sinon elle
  /// atterrirait aussi dans [extra] et serait émise deux fois (une par
  /// `...extra`, une par le câblage manuel), cassant l'idempotence du
  /// round-trip.
  static final Set<String> _reservedKeys = <String>{
    for (final spec in $ZDocumentReadingStateFieldSpecs) spec.name,
    'extension',
    kLearningKey,
    ...ZSyncMeta.reservedKeys,
  };

  /// Extrait `extra` = clés non réservées de [map] (round-trip préservé).
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
