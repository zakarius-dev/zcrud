/// État SRS canonique `ZRepetitionInfo` — séparé de la carte.
///
/// L'état de répétition espacée d'une carte vit hors de la carte, persisté
/// dans un canal séparé — jamais dans le sous-arbre partageable de la carte.
/// Le partage ou la duplication d'une carte n'emporte donc jamais
/// l'historique SRS avec le corps de la carte (invariant AD-9).
///
/// Cette séparation joue vis-à-vis du **corps de la carte**, pas entre
/// utilisateurs : `ZRepetitionInfo` ne porte volontairement aucun champ
/// d'appartenance — le périmètre par propriétaire est porté par le chemin de
/// persistance de l'adaptateur, une instance de `ZRepetitionStore` étant liée
/// à exactement un propriétaire. Voir le contrat détaillé sur
/// `ZRepetitionStore`.
///
/// Généré par `@ZcrudModel` (invariant AD-3) : le codegen émet le décodeur,
/// l'extension `ZRepetitionInfoZcrud` (`toMap`/`copyWith`), les
/// spécifications de champs et l'enregistrement au registre.
///
/// ## Contenant pur, aucune formule
///
/// L'algorithme (SuperMemo-2 par défaut) vit uniquement dans
/// `ZSrsScheduler`/`ZSm2Scheduler`. Ce modèle ne fait que transporter l'état
/// (intervalle, nombre de répétitions, facteur de facilité…).
///
/// ## Voie d'écriture unique
///
/// Cette classe n'expose aucun `copyWith` public ni setter sur les champs
/// SRS (l'extension générée, qui porte un `copyWith`, est masquée du barrel
/// public). L'unique transformation produisant un état avancé est
/// `ZSrsScheduler.apply()` ; l'unique création d'un état neuf est
/// `ZSrsScheduler.initial()` (invariant AD-9). Le constructeur `const`
/// public est un primitif de reconstruction de bas niveau, réservé à
/// l'algorithme et à la désérialisation — il ne calcule aucune progression
/// SRS, donc n'est pas une voie d'avancement concurrente.
///
/// ## Slots d'extension
///
/// Mixe `ZExtensible` (invariant AD-4) : `extra` (échappatoire non typée,
/// round-trip des clés inconnues) et `extension` (emplacement typé et
/// versionné, décodé défensivement). Ces deux canaux ne sont pas gérés par le
/// codegen : ils sont câblés explicitement autour du code généré dans
/// [ZRepetitionInfo.fromMap]/[toMap] (même patron que `ZFlashcard`).
///
/// ## Sans `id`
///
/// La clé d'identité est [flashcardId] (jointure un-à-un avec la carte) —
/// diffère de `ZFlashcard`. L'état n'est pas « éphémère » au sens carte ; il
/// est adressé par sa carte.
///
/// ## Synchronisation « map telle quelle »
///
/// [fromMap]/[toMap] (dé)sérialisent l'état complet sans perte, sans jamais
/// invoquer un scheduler — la synchronisation fusionne la map par
/// Last-Write-Wins sur `updatedAt` sans dériver l'état (aucun recalcul
/// d'intervalle, de facteur de facilité ou d'échéance ; invariants AD-9 et
/// AD-10).
library;

import 'package:zcrud_annotations/zcrud_annotations.dart';
import 'package:zcrud_core/domain.dart';

import 'z_srs_config.dart';

part 'z_repetition_info.g.dart';

/// Reconstruit une [ZExtension] concrète depuis sa map JSON, ou rend `null`.
///
/// Fourni par l'application ou le satellite appelant, et injecté dans
/// [ZRepetitionInfo.fromMap] : le domaine ne connaît pas les sous-classes
/// concrètes (invariant AD-4). Toute exception levée par le parseur est
/// absorbée en `null` par [ZExtension.guard] (invariant AD-10), le parent
/// survivant toujours.
typedef ZRepetitionInfoExtensionParser = ZExtension? Function(
    Map<String, dynamic> json);

/// État de répétition espacée d'une carte (contenant pur ; les invariants
/// vivent au scheduler et au repository).
@ZcrudModel(kind: 'repetition_info')
class ZRepetitionInfo with ZExtensible {
  /// Primitif de reconstruction de bas niveau (`const`) — réservé à
  /// `ZSrsScheduler.apply`/`initial` et à la désérialisation [fromMap].
  ///
  /// N'exécute aucune formule SRS : il assemble un état déjà calculé. Ce
  /// n'est pas une voie d'avancement (la progression passe exclusivement par
  /// `ZSrsScheduler.apply`, invariant AD-9).
  const ZRepetitionInfo({
    required this.flashcardId,
    required this.folderId,
    this.interval = 0,
    this.repetitions = 0,
    this.easeFactor = ZSrsConfig.kDefaultEaseFactor,
    this.nextReviewDate,
    this.learnedAt,
    this.lastQuality,
    this.extension,
    Map<String, dynamic> extra = const <String, dynamic>{},
    // Un paramètre nommé ne peut pas être privé en Dart
    // (PRIVATE_OPTIONAL_PARAMETER) — le slot brut doit pourtant rester privé,
    // c'est l'accesseur `extra` qui porte la garde.
    // ignore: prefer_initializing_formals
  }) : _extra = extra;

  /// Reconstruit défensivement un état SRS depuis une map persistée
  /// (invariant AD-10).
  ///
  /// Délègue au décodeur généré (défauts sûrs : `flashcard_id`/`folder_id`
  /// absents → `''`, `interval`/`repetitions` non-int → `0`, `ease_factor`
  /// non numérique → la valeur par défaut, dates illisibles → `null`), sans
  /// jamais invoquer un scheduler (aucun recalcul — l'état persisté est
  /// reconstruit tel quel, y compris des valeurs incohérentes), puis :
  /// - sanitise `interval`/`repetitions` négatifs → `0` (défaut sûr) ;
  /// - câble [extension] via [extensionParser] (repli `null`,
  ///   [ZExtension.guard]) ;
  /// - câble [extra] = les clés non réservées de la map (round-trip
  ///   préservé).
  ///
  /// Aucun cas ne fait échouer le parent (map vide, `ease_factor` corrompu,
  /// `extension` corrompue…).
  factory ZRepetitionInfo.fromMap(
    Map<String, dynamic> map, {
    ZRepetitionInfoExtensionParser? extensionParser,
  }) {
    final base = _$ZRepetitionInfoFromMap(map);
    return ZRepetitionInfo(
      flashcardId: base.flashcardId,
      folderId: base.folderId,
      // Sanitisation défensive : un compteur négatif persisté (corruption)
      // retombe sur `0`, sans jamais lever d'exception.
      interval: base.interval < 0 ? 0 : base.interval,
      repetitions: base.repetitions < 0 ? 0 : base.repetitions,
      easeFactor: base.easeFactor,
      nextReviewDate: base.nextReviewDate,
      learnedAt: base.learnedAt,
      lastQuality: base.lastQuality,
      extension: _decodeExtension(map['extension'], extensionParser),
      extra: _extraFrom(map),
    );
  }

  /// Clé de jointure un-à-un avec la carte (identité de l'état SRS ;
  /// requis).
  @ZcrudField()
  final String flashcardId;

  /// Dossier dénormalisé (pour les requêtes de session sans jointure ;
  /// requis).
  @ZcrudField()
  final String folderId;

  /// Intervalle courant en jours avant la prochaine révision (défaut `0`).
  @ZcrudField()
  final int interval;

  /// Nombre de révisions réussies consécutives (défaut `0` ; remis à `0` sur
  /// lapse par l'algorithme).
  @ZcrudField()
  final int repetitions;

  /// Facteur de facilité SuperMemo-2, borné par l'algorithme selon les bornes
  /// min/max de la configuration (défaut [ZSrsConfig.defaultEaseFactor],
  /// c'est-à-dire `2.5`).
  @ZcrudField(defaultValue: ZSrsConfig.kDefaultEaseFactor)
  final double easeFactor;

  /// Date de la prochaine révision due (`maintenant + interval jours`), ou
  /// `null` si jamais révisée.
  @ZcrudField()
  final DateTime? nextReviewDate;

  /// Date de la première réussite (qualité au moins égale au seuil de
  /// passage), jamais remise à `null` sur un lapse ultérieur. `null` tant
  /// qu'aucune réussite.
  @ZcrudField()
  final DateTime? learnedAt;

  /// Dernière qualité de réponse appliquée (`0..5`), ou `null` si jamais
  /// révisée.
  @ZcrudField()
  final int? lastQuality;

  /// Emplacement d'extension typée et versionnée (invariant AD-4), `null` si
  /// absente. Hors schéma généré.
  @override
  final ZExtension? extension;

  /// Échappatoire non typée (invariant AD-4), défaut `const {}` (jamais
  /// `null`), qui préserve au round-trip les clés inconnues du domaine. Hors
  /// schéma généré.
  @override
  Map<String, dynamic> get extra => zNormalizeExtra(_extra, _reservedKeys);

  /// Emplacement `extra` brut tel que reçu par le constructeur — lu nulle
  /// part ailleurs que dans l'accesseur [extra] (ni `toMap`, ni `==`, ni
  /// `hashCode`).
  ///
  /// Il peut être pollué : le constructeur nominal est `const`, il ne peut
  /// appeler aucune fonction dans son initialiseur, et l'invariant AD-10
  /// interdit d'y placer un `assert`. C'est l'accesseur [extra] qui porte la
  /// garde — le seul point que toutes les voies traversent.
  final Map<String, dynamic> _extra;

  /// Copie relocalisant uniquement le [folderId] dénormalisé (routage de
  /// session) en préservant à l'identique tous les champs d'ordonnancement
  /// SRS (intervalle, répétitions, facteur de facilité, prochaine échéance,
  /// date d'apprentissage, dernière qualité) ainsi que les canaux hors
  /// schéma (extension/extra).
  ///
  /// Cette copie ne peut pas faire progresser l'état — elle n'expose aucun
  /// paramètre d'ordonnancement et n'invoque aucun scheduler. Ce n'est donc
  /// pas une voie d'avancement concurrente de `ZSrsScheduler.apply`
  /// (invariant AD-9) : c'est une pure relocalisation de routage (par
  /// exemple le déplacement d'une carte entre dossiers, voir
  /// `ZFlashcardRepository.moveCard`). Additif minimal au modèle SRS, elle
  /// ne réintroduit aucun `copyWith` d'avancement.
  ZRepetitionInfo withFolder(String folderId) => ZRepetitionInfo(
        flashcardId: flashcardId,
        folderId: folderId,
        interval: interval,
        repetitions: repetitions,
        easeFactor: easeFactor,
        nextReviewDate: nextReviewDate,
        learnedAt: learnedAt,
        lastQuality: lastQuality,
        extension: extension,
        extra: extra,
      );

  /// Sérialise vers la map persistée complète (snake_case), sans perte.
  ///
  /// Réutilise le `toMap()` généré (champs scalaires/dates) puis superpose
  /// les deux canaux hors schéma : [extra] (clés inconnues préservées) et
  /// [extension]. Jamais de recalcul SRS : sérialise l'état tel quel.
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      // Cette entité n'a aucun `copyWith` (voie SRS unique) : la seule voie
      // d'écriture publique de `extra` est le constructeur nominal, `const`,
      // qui ne peut appeler aucune fonction de filtrage. `toMap()`, frontière
      // de sortie, est donc la seule frontière que cette voie traverse —
      // étale l'accesseur (qui normalise), jamais le champ brut `_extra`.
      ...extra,
      ...ZRepetitionInfoZcrud(this).toMap(),
    };
    if (extension != null) {
      map['extension'] = extension!.toJson();
    }
    return map;
  }

  /// Décode défensivement l'extension via [parser] (repli `null`).
  static ZExtension? _decodeExtension(
    Object? raw,
    ZRepetitionInfoExtensionParser? parser,
  ) {
    // Un hôte sans parseur ne détruit pas le payload : comme `extension` est
    // une clé connue (donc exclue d'`extra`), le contenu d'un autre hôte est
    // préservé verbatim, quel que soit le résultat du parseur.
    return zDecodeExtension(raw, parser);
  }

  /// Clés persistées réservées (champs générés, `extension` et les clés de
  /// synchronisation) — dérivées des spécifications de champs générées pour
  /// rester synchrones avec le codegen.
  ///
  /// `ZRepetitionInfo` est persistée dans un canal séparé, top-level, et le
  /// store écrit ses métadonnées de synchronisation dans le corps du document
  /// avant de passer la map complète à [fromMap]. Sans les clés réservées de
  /// `ZSyncMeta`, ces clés — qui appartiennent au store, pas au domaine —
  /// atterriraient dans [extra] (violant l'invariant AD-4 : `extra` désigne
  /// les clés inconnues du domaine) et seraient réémises par [toMap]
  /// (violant l'invariant AD-9 : le soft-delete doit rester hors entité),
  /// cassant au passage l'égalité entre un état SRS construit en mémoire et
  /// le même relu du store.
  ///
  /// `ZRepetitionInfo` ne déclarant aucun champ `updatedAt`/`isDeleted`,
  /// c'est bien la réserve de `ZSyncMeta` — et elle seule — qui protège ces
  /// deux clés.
  static final Set<String> _reservedKeys = <String>{
    for (final spec in $ZRepetitionInfoFieldSpecs) spec.name,
    'extension',
    ...ZSyncMeta.reservedKeys,
  };

  /// Extrait `extra` = les clés non réservées de [map] (round-trip préservé)
  /// — frontière d'entrée. Délègue à [_sanitizeExtra], la garde partagée.
  static Map<String, dynamic> _extraFrom(Map<String, dynamic> map) =>
      _sanitizeExtra(map);

  /// La garde partagée de `extra`, appelée par [fromMap] et [toMap].
  ///
  /// Deux sites seulement, et ce n'est pas un oubli : cette entité n'offre
  /// aucun `copyWith` (voie SRS unique). La voie d'écriture publique de
  /// `extra` y est le constructeur nominal, `const`, qui ne peut rien
  /// filtrer — c'est [toMap] qui porte la promesse (voir sa dartdoc).
  static Map<String, dynamic> _sanitizeExtra(Map<String, dynamic> raw) =>
      zSanitizeExtra(raw, _reservedKeys);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZRepetitionInfo &&
          flashcardId == other.flashcardId &&
          folderId == other.folderId &&
          interval == other.interval &&
          repetitions == other.repetitions &&
          easeFactor == other.easeFactor &&
          nextReviewDate == other.nextReviewDate &&
          learnedAt == other.learnedAt &&
          lastQuality == other.lastQuality &&
          extension == other.extension &&
          zJsonEquals(extra, other.extra);

  @override
  int get hashCode => Object.hashAll(<Object?>[
        flashcardId,
        folderId,
        interval,
        repetitions,
        easeFactor,
        nextReviewDate,
        learnedAt,
        lastQuality,
        extension,
        zJsonHash(extra),
      ]);
}
