/// État SRS canonique `ZRepetitionInfo` — SÉPARÉ de la carte (Story E9-2,
/// AC1/AC2/AC7/AC8/AC9).
///
/// origine: lex_core (module « Étude ») — `repetition_info.dart` (canonique
/// §2.1, l.62-73) : l'état de répétition espacée d'une carte, **hors carte**,
/// persisté top-level `study_repetitions/{cardId}` (E9-4) — jamais dans le
/// sous-arbre partageable. Le partage/duplication d'une carte n'emporte donc
/// jamais l'historique SRS d'autrui (AD-9).
///
/// **Généré par `@ZcrudModel` (AD-3)** : `melos run generate` émet
/// `z_repetition_info.g.dart` (`part`, gitignoré, régénéré) portant
/// `_$ZRepetitionInfoFromMap`, l'extension `ZRepetitionInfoZcrud`
/// (`toMap`/`copyWith`), `$ZRepetitionInfoFieldSpecs` et
/// `registerZRepetitionInfo(ZcrudRegistry)`.
///
/// **Contenant PUR, AUCUNE formule (AD-9)** : l'algorithme (SuperMemo-2) vit
/// **uniquement** dans `ZSrsScheduler`/`ZSm2Scheduler`. Ce modèle ne fait que
/// **transporter** l'état (`interval`/`repetitions`/`easeFactor`/…).
///
/// **VOIE D'ÉCRITURE UNIQUE (AD-9, AC7)** : cette classe n'expose **AUCUN**
/// `copyWith` public ni setter sur les champs SRS (l'extension générée
/// `ZRepetitionInfoZcrud` — qui porte un `copyWith` — est **masquée** du barrel
/// public via `hide`). L'**unique** transformation produisant un état avancé
/// est `ZSrsScheduler.apply()` ; l'**unique** création d'un état neuf est
/// `ZSrsScheduler.initial()`. Le constructeur `const` public est un **primitif
/// de reconstruction de bas niveau**, réservé à l'algorithme (`apply`/`initial`)
/// et à la désérialisation (`fromMap`) — il ne **calcule** aucune progression
/// SRS (aucune formule), donc n'est PAS une API d'avancement concurrente.
///
/// **Slots d'extension AD-4** : mixe `ZExtensible` (cœur) → `extra`
/// (échappatoire non typée, round-trip des clés inconnues) + `extension` (slot
/// type additif versionné, parsé défensivement). Ces deux canaux NE sont PAS
/// gérés par le générateur : ils sont **câblés manuellement** autour du code
/// généré dans [ZRepetitionInfo.fromMap]/[toMap] (même patron que `ZFlashcard`,
/// E9-1).
///
/// **Sans `id`/`ZEntity` (AC1)** : la clé d'identité est [flashcardId]
/// (jointure 1↔1 avec la carte) — diffère de `ZFlashcard`. L'état n'est pas
/// « éphémère » au sens carte ; il est adressé par sa carte.
///
/// **Sync « map telle quelle » (AD-9/AD-10, canonique §7)** : [fromMap]/[toMap]
/// (dé)sérialisent l'état **complet zéro-perte** SANS jamais invoquer un
/// scheduler — la synchro (E9-4) merge la map par LWW sur `updatedAt` sans
/// dériver l'état (aucun recalcul d'`interval`/`easeFactor`/échéance).
library;

import 'package:zcrud_annotations/zcrud_annotations.dart';
import 'package:zcrud_core/domain.dart';

import 'z_srs_config.dart';

part 'z_repetition_info.g.dart';

/// Reconstruit une [ZExtension] concrète depuis sa map JSON, ou `null`.
///
/// Fourni par l'app/le satellite (convention `X.fromJsonSafe`) et injecté dans
/// [ZRepetitionInfo.fromMap] : le cœur ne connaît pas les sous-classes concrètes
/// (AD-4). Toute exception est absorbée en `null` par [ZExtension.guard]
/// (AD-10), le parent survivant toujours.
typedef ZRepetitionInfoExtensionParser = ZExtension? Function(
    Map<String, dynamic> json);

/// État de répétition espacée d'une carte (contenant pur ; invariants au
/// scheduler/repo).
@ZcrudModel(kind: 'repetition_info')
class ZRepetitionInfo with ZExtensible {
  /// Primitif de reconstruction de bas niveau (`const`) — **réservé** à
  /// `ZSrsScheduler.apply`/`initial` et à la désérialisation [fromMap].
  ///
  /// N'exécute **aucune** formule SRS : il assemble un état déjà calculé. Ce
  /// n'est **pas** une voie d'avancement (cf. AD-9/AC7 : la progression passe
  /// exclusivement par `ZSrsScheduler.apply`).
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
    // ⚠️ Le « fix » du lint (`this._extra`) est **ILLÉGAL** en Dart : un paramètre
    // NOMMÉ ne peut pas être privé (PRIVATE_OPTIONAL_PARAMETER). Or le slot brut
    // DOIT rester privé — c'est l'ACCESSEUR `extra` qui porte la garde (ES-2.2b).
    // ignore: prefer_initializing_formals
  }) : _extra = extra;

  /// Reconstruit **défensivement** depuis une map persistée (AD-10, AC8/AC9).
  ///
  /// Délègue au `_$ZRepetitionInfoFromMap` **généré** (défauts sûrs :
  /// `flashcard_id`/`folder_id` absents → `''`, `interval`/`repetitions`
  /// non-int → `0`, `ease_factor` non-numérique → `defaultEaseFactor`, dates
  /// illisibles → `null`), **sans jamais invoquer un scheduler** (aucun
  /// recalcul — l'état persisté est reconstruit TEL QUEL, y compris des valeurs
  /// « impossibles »), puis :
  /// - **sanitise** `interval`/`repetitions` négatifs → `0` (défaut sûr, AC9) ;
  /// - câble [extension] via [extensionParser] (repli `null`,
  ///   `ZExtension.guard`) ;
  /// - câble [extra] = clés **non réservées** de la map (round-trip préservé).
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
      // retombe sur `0` (AC9) — sans jamais throw.
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

  /// Clé de jointure 1↔1 avec la carte (identité de l'état SRS ; requis, AC1).
  @ZcrudField()
  final String flashcardId;

  /// Dossier dénormalisé (requêtes de session sans jointure ; requis, AC1).
  @ZcrudField()
  final String folderId;

  /// Intervalle courant en **jours** avant la prochaine révision (défaut `0`).
  @ZcrudField()
  final int interval;

  /// Nombre de révisions **réussies consécutives** (défaut `0` ; remis à `0`
  /// sur lapse par l'algorithme).
  @ZcrudField()
  final int repetitions;

  /// Facteur de facilité SuperMemo-2, borné `[minEaseFactor;maxEaseFactor]` par
  /// l'algorithme (défaut [ZSrsConfig.defaultEaseFactor], càd `2.5`).
  @ZcrudField(defaultValue: ZSrsConfig.kDefaultEaseFactor)
  final double easeFactor;

  /// Date de la prochaine révision due (`now + interval jours`), ou `null` si
  /// jamais révisée.
  @ZcrudField()
  final DateTime? nextReviewDate;

  /// Date de la **première** réussite (`quality >= passThreshold`), **jamais**
  /// remise à `null` sur lapse ultérieur (AC4). `null` tant qu'aucune réussite.
  @ZcrudField()
  final DateTime? learnedAt;

  /// Dernière qualité de réponse appliquée (`0..5`), ou `null` si jamais
  /// révisée.
  @ZcrudField()
  final int? lastQuality;

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

  /// Copie **folder-only** (M1 d'E9-4, tranchée E9-5) : relocalise le seul
  /// [folderId] dénormalisé (routage de session) en **préservant à l'identique**
  /// TOUS les champs d'ordonnancement SRS (`interval`/`repetitions`/`easeFactor`/
  /// `nextReviewDate`/`learnedAt`/`lastQuality`) ainsi que les canaux
  /// hors-codegen ([extension]/[extra]).
  ///
  /// **AD-9 (voie d'avancement UNIQUE)** : cette copie **ne peut pas** faire
  /// progresser l'état — elle n'expose **aucun** paramètre d'ordonnancement et
  /// n'invoque **aucun** scheduler. Ce n'est donc **pas** une voie d'avancement
  /// concurrente de `ZSrsScheduler.apply` : c'est une pure **relocalisation de
  /// routage** (déplacement d'une carte entre dossiers, cf.
  /// `ZFlashcardRepository.moveCard`). Additif minimal au modèle E9-2, il
  /// **ne réintroduit AUCUN** `copyWith` SRS d'avancement.
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

  /// Sérialise vers la map persistée **complète** (snake_case), zéro-perte.
  ///
  /// Réutilise le `toMap()` **généré** (champs scalaires/dates) puis superpose
  /// les deux canaux hors-codegen : [extra] (clés inconnues préservées) et
  /// [extension]. **Jamais** de recalcul SRS (AC8) : sérialise l'état tel quel.
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      // 🔴 DW-ES22-3 (ES-2.2b) — **C'EST ICI, ET NULLE PART AILLEURS, QUE LA
      // PROMESSE TIENT SUR CETTE ENTITÉ.**
      //
      // `ZRepetitionInfo` n'a **AUCUN `copyWith`** (voie SRS unique, AC8) : la
      // seule voie d'écriture publique de `extra` est le **CONSTRUCTEUR
      // NOMINAL** — qui est **`const`** et ne peut donc appeler **aucune**
      // fonction de filtrage. Et **AD-10 INTERDIT** d'y mettre un `assert` : le
      // décodeur généré l'appelle avec des valeurs **BRUTES**, un `assert` ferait
      // **throw la désérialisation d'une donnée corrompue**.
      //
      // ⇒ `toMap()`, **frontière de SORTIE**, est la seule frontière que la voie
      // constructeur traverse. **MESURÉ** avant correctif :
      // `ZRepetitionInfo(…, extra: {updated_at: …, is_deleted: true}).toMap()`
      // réémettait les DEUX clés ⇒ collision frontale avec l'autorité de sync
      // (le store écrit `ZSyncMeta` APRÈS le corps — AD-9/AD-16/AD-19).
      // 🔴 ES-2.2b (remédiation HIGH-1) — étale l'**ACCESSEUR** (qui NORMALISE),
      // jamais le champ brut `_extra`. Un `_sanitizeExtra(extra)` ICI serait
      // **DÉCORATIF** — MESURÉ (INJ-A/INJ-B) : le retirer laissait le gate VERT
      // sur 8 entités sur 9. La garde vit à l'accesseur ; l'en retirer rend
      // (i.1a)/(i.1b)/(i.1c) ROUGES.
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
    if (parser == null) return null;
    final map = _asStringMap(raw);
    if (map == null) return null;
    return ZExtension.guard<ZExtension?>(() => parser(map));
  }

  /// Clés persistées **réservées** (champs générés + `extension` + **clés de
  /// sync `ZSyncMeta`**) — dérivées de `$ZRepetitionInfoFieldSpecs` pour rester
  /// synchrones avec le codegen.
  ///
  /// **AD-19 (ES-1.3)** — le spread `...ZSyncMeta.reservedKeys` (`updated_at`,
  /// `is_deleted`) est **essentiel** : `ZRepetitionInfo` est persistée top-level
  /// (`study_repetitions/{cardId}`) et le store écrit ses métadonnées de sync
  /// **dans le corps du document** (`hive_z_local_store.dart` `_encode` ;
  /// `firebase_z_repository_impl.dart` `_encode`) puis passe la map **complète**
  /// à [fromMap]. Sans ce spread, ces clés — qui appartiennent au **store**, pas
  /// au domaine — atterriraient dans [extra] (AD-4 violé : `extra` = clés
  /// *inconnues du domaine*) et seraient **réémises** par [toMap] (AD-16 violé :
  /// le soft-delete doit rester hors-entité), cassant au passage `==` entre un
  /// état SRS construit en mémoire et le même relu du store.
  ///
  /// `ZRepetitionInfo` ne déclarant **aucun** champ `updatedAt`/`isDeleted`,
  /// c'est bien `ZSyncMeta.reservedKeys` — et lui seul — qui protège les **deux**
  /// clés. C'est l'**exemplaire de référence** d'AD-19.1 : aucune clé LWW
  /// in-entité, aucune capture des clés de sync.
  static final Set<String> _reservedKeys = <String>{
    for (final spec in $ZRepetitionInfoFieldSpecs) spec.name,
    'extension',
    ...ZSyncMeta.reservedKeys,
  };

  /// Extrait `extra` = clés non réservées de [map] (round-trip préservé) —
  /// **frontière d'ENTRÉE**. C'est [_sanitizeExtra], la garde **partagée**.
  static Map<String, dynamic> _extraFrom(Map<String, dynamic> map) =>
      _sanitizeExtra(map);

  /// 🔴 **LA GARDE PARTAGÉE DE `extra`** (DW-ES22-3, ES-2.2b) — appelée par
  /// [fromMap] **et** [toMap].
  ///
  /// ⚠️ **DEUX sites seulement, et ce n'est PAS un oubli** : cette entité n'offre
  /// **aucun `copyWith`** (voie SRS unique). La voie d'écriture publique de
  /// `extra` y est le **constructeur nominal**, `const`, qui ne peut rien
  /// filtrer — c'est [toMap] qui porte la promesse (cf. sa dartdoc).
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
