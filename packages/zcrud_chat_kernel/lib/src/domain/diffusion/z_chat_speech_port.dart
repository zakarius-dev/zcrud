/// Diffusion **vocale** d'une réponse — port + chaîne de repli (CHAT-9 ;
/// AD-5, AD-10, AD-11, AD-57).
///
/// origine **MESURÉE sur disque** (lecture seule) :
/// * `lex_douane/packages/lex_core/lib/domain/services/on_device_tts_service.dart`
///   — le contrat neutre (`isAvailable` / `speak` / `stop`), déjà en `Either`,
///   déjà « ne lève jamais » ;
/// * `lex_douane/packages/lex_data/lib/data/services/audio_streaming_service.dart`
///   — la **chaîne de repli réelle**, dans l'ordre où elle est écrite :
///   `_tryLocalCache` (`:95-121`) → backend streaming sous **circuit breaker**
///   (`:151-176`) → `fallbackToRepository` (Cloud Storage / Functions, `:207+`)
///   → TTS sur l'appareil, servi à part parce qu'il ne produit pas
///   d'`AudioSource`.
///
/// ## 🔴 Ce qui manque à lex, et que ce fichier corrige
///
/// Chez lex, la chaîne de repli est **écrite dans le corps d'une méthode**
/// (`getAudioSource`), mêlée au circuit breaker, au préchargement et à
/// `just_audio`. Trois conséquences mesurables :
///
/// 1. l'ordre des replis n'est **pas une donnée** — on ne peut ni le réordonner
///    ni en retirer un maillon sans réécrire la méthode ;
/// 2. le dernier maillon (TTS local) est **hors chaîne** : l'appelant doit
///    savoir l'appeler lui-même (`speakOnDevice`), donc un appelant qui
///    l'oublie perd le repli le plus important — celui du hors-ligne ;
/// 3. les échecs des maillons intermédiaires sont **perdus** (`debugPrint`),
///    donc un support qui reçoit « ça ne lit pas » n'apprend rien.
///
/// ⇒ Ici la chaîne est **un objet** ([ZChatSpeechChain]) : une liste ordonnée
/// de [ZChatSpeechPort], un **site unique** de repli, et les échecs des
/// maillons **conservés** dans [ZChatSpeechDelivery.attempts]. Zéro
/// dépendance : ni `just_audio`, ni `flutter_tts`, ni HTTP n'entrent (AD-57) —
/// chaque maillon est une implémentation d'hôte.
///
/// ## 🔴 AD-10 — ce qui reste ABSENT plutôt que faux
///
/// [ZChatSpeechRequest.languageTag] est **nullable**. lex exige
/// `required String language` et son appelant passe `'fr'` en dur : un socle
/// multi-consommateurs qui ferait de même choisirait la langue de lecture à la
/// place de l'hôte. `null` signifie « laisse le moteur décider » — jamais
/// « français ».
library;

import 'package:zcrud_core/domain.dart';

import '../z_chat_message.dart';
import '../z_content_block.dart';

/// Vitesse de lecture **par défaut** — celle de lex (`double speed = 1.0`).
const double kZChatSpeechDefaultRate = 1.0;

/// Ce qu'on demande à lire.
///
/// 🔴 **Aucun second résumé de message n'est écrit ici.** [ZChatSpeechRequest.ofMessage]
/// délègue à `zChatAccessibleTextOf` — la fonction qui produit déjà le texte
/// annonçable d'une suite de blocs, `switch` exhaustif compris. En écrire un
/// deuxième rouvrirait exactement le trou que CHAT-3b avait fermé : un résumé
/// local ne connaissant que `ZTextBlock`, donc un tableau **jamais lu à voix
/// haute**. Garde **G9-D1** (grep négatif).
class ZChatSpeechRequest {
  /// Construit une demande de lecture.
  const ZChatSpeechRequest({
    required this.text,
    this.languageTag,
    this.rate = kZChatSpeechDefaultRate,
  });

  /// Demande de lecture d'un **message entier**, blocs structurés compris.
  ///
  /// [resolver] est le même seam que celui du résumé accessible : un hôte qui
  /// annonce autrement ses blocs ouverts les fait lire de la même façon, sans
  /// second point de branchement à alimenter.
  factory ZChatSpeechRequest.ofMessage(
    ZChatMessage message, {
    String? languageTag,
    double rate = kZChatSpeechDefaultRate,
    ZAccessibleTextResolver? resolver,
  }) => ZChatSpeechRequest(
    text: zChatAccessibleTextOf(message.contentBlocks, resolver: resolver),
    languageTag: languageTag,
    rate: rate,
  );

  /// Le texte à lire, **déjà aplati**.
  final String text;

  /// Étiquette de langue BCP-47 (`'fr'`, `'pt-BR'`), ou **`null`** pour laisser
  /// le moteur choisir (AD-10 : jamais un défaut inventé).
  final String? languageTag;

  /// Vitesse de lecture.
  final double rate;

  /// `true` si la demande a réellement quelque chose à lire.
  ///
  /// Une chaîne blanche n'est pas « rien à lire » pour tous les moteurs : sur
  /// certains, `speak('')` **termine sans rien faire**, sur d'autres il rend
  /// une erreur. La chaîne de repli s'en sert pour **ne pas parcourir trois
  /// maillons** pour un texte vide (cf. [ZChatSpeechChain.speak]).
  bool get hasContent => text.trim().isNotEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatSpeechRequest &&
          text == other.text &&
          languageTag == other.languageTag &&
          rate == other.rate;

  @override
  int get hashCode => Object.hash(text, languageTag, rate);

  @override
  String toString() =>
      'ZChatSpeechRequest(${text.length} chars, '
      'languageTag: $languageTag, rate: $rate)';
}

/// Ce qui a **effectivement** lu, et ce qui a échoué avant.
///
/// [sourceKind] est un discriminant **OUVERT** (`String`), pas un enum : les
/// maillons de lex (`localCache`, `backendStream`, `cloudStorage`,
/// `onDeviceTts`) sont **ses** maillons ; un hôte qui en a deux, ou cinq, ou
/// d'autres, ne doit pas avoir à forker le socle (AD-4).
class ZChatSpeechDelivery {
  /// Construit un compte-rendu de lecture.
  ZChatSpeechDelivery({
    required this.sourceKind,
    List<ZFailure> attempts = const <ZFailure>[],
  }) : attempts = List<ZFailure>.unmodifiable(attempts);

  /// Le maillon qui a servi.
  final String sourceKind;

  /// 🔴 Les échecs des maillons **essayés avant**, dans l'ordre — jamais
  /// perdus. C'est le renseignement que lex jette dans un `debugPrint` et qui
  /// manque à tout diagnostic « ça ne lit pas ».
  ///
  /// Liste **vide** = le premier maillon a servi. Elle n'est jamais `null` :
  /// contrairement à `matchingMessages` d'une recherche, « aucun échec » et
  /// « on n'a pas regardé » sont ici le **même** fait — la chaîne a toujours
  /// regardé.
  final List<ZFailure> attempts;

  @override
  String toString() =>
      'ZChatSpeechDelivery($sourceKind, ${attempts.length} failed attempts)';
}

/// Un **maillon** de diffusion vocale — port d'hôte (AD-11 : aucun transport
/// ici ; AD-57 : aucune dépendance).
///
/// Porté de `OnDeviceTtsService` (lex_core), avec deux écarts :
/// * `speak` rend `ZResult<ZChatSpeechDelivery>` plutôt que `Either<_, void>` :
///   la chaîne doit pouvoir dire **quel** maillon a servi ;
/// * la langue est optionnelle (cf. l'en-tête).
abstract interface class ZChatSpeechPort {
  /// Discriminant **ouvert** de ce maillon (`'onDeviceTts'`, `'localCache'`…).
  String get sourceKind;

  /// `true` si ce maillon est utilisable **maintenant**, sur cette plateforme.
  ///
  /// Ne lève jamais (contrat de lex, conservé). Sur le web ou sans moteur, un
  /// maillon TTS rend `false` — et la chaîne passe au suivant **sans** produire
  /// d'échec, parce qu'un maillon indisponible n'est pas une panne.
  Future<bool> isAvailable();

  /// Lit [request].
  ///
  /// `Left` ⇒ la chaîne essaie le maillon suivant ; `Right` ⇒ elle s'arrête.
  Future<ZResult<ZChatSpeechDelivery>> speak(ZChatSpeechRequest request);

  /// Arrête la lecture en cours — **best-effort**, ne lève jamais.
  Future<void> stop();
}

/// 🔴 La chaîne de repli, **en tant que donnée** — site UNIQUE du repli.
///
/// Reproduit la sémantique mesurée d'`AudioStreamingService` (essayer chaque
/// source dans l'ordre, retomber sur la suivante à l'échec), en corrigeant ses
/// trois défauts : l'ordre est une liste, le dernier maillon est **dans** la
/// chaîne, et les échecs sont conservés.
///
/// Implémente elle-même [ZChatSpeechPort] : une chaîne est un maillon. Un hôte
/// peut donc en imbriquer une (« cache local, puis \[réseau : A ou B\], puis
/// TTS ») sans que ce fichier ait à connaître la notion de sous-chaîne.
class ZChatSpeechChain implements ZChatSpeechPort {
  /// Construit une chaîne à partir de maillons **ordonnés**.
  ZChatSpeechChain(
    List<ZChatSpeechPort> links, {
    this.sourceKind = 'chain',
  }) : links = List<ZChatSpeechPort>.unmodifiable(links);

  /// Les maillons, dans l'ordre d'essai.
  final List<ZChatSpeechPort> links;

  @override
  final String sourceKind;

  /// `true` dès qu'**un** maillon est disponible.
  ///
  /// AD-10 : un maillon dont l'`isAvailable` **lève** — cas réel, un plugin qui
  /// n'est pas enregistré sur la plateforme lève au premier appel — est traité
  /// comme indisponible, jamais propagé.
  @override
  Future<bool> isAvailable() async {
    for (final ZChatSpeechPort link in links) {
      if (await _availabilityOf(link)) return true;
    }
    return false;
  }

  /// Essaie chaque maillon **disponible**, dans l'ordre, et rend le premier
  /// succès.
  ///
  /// * texte vide ⇒ `Left(ZDomainFailure)` **sans toucher aucun maillon** : lire
  ///   le silence n'est pas un service rendu, et trois appels plateforme pour
  ///   rien coûtent au démarrage ;
  /// * aucun maillon disponible ⇒ `Left(ZUnsupportedOperationFailure)` — type
  ///   **EXISTANT** du cœur, pas une nouvelle famille ;
  /// * tous les maillons ont échoué ⇒ le **dernier** échec, enrichi de rien :
  ///   c'est celui du repli ultime, le plus proche de la cause réelle.
  @override
  Future<ZResult<ZChatSpeechDelivery>> speak(ZChatSpeechRequest request) async {
    if (!request.hasContent) {
      return const Left<ZFailure, ZChatSpeechDelivery>(
        ZDomainFailure('nothing to speak'),
      );
    }
    final List<ZFailure> attempts = <ZFailure>[];
    bool any = false;
    for (final ZChatSpeechPort link in links) {
      if (!await _availabilityOf(link)) continue;
      any = true;
      final ZResult<ZChatSpeechDelivery> result = await _speakOn(link, request);
      final ZChatSpeechDelivery? delivered = result.fold(
        (ZFailure f) {
          attempts.add(f);
          return null;
        },
        (ZChatSpeechDelivery d) => d,
      );
      if (delivered != null) {
        return Right<ZFailure, ZChatSpeechDelivery>(
          ZChatSpeechDelivery(
            sourceKind: delivered.sourceKind,
            attempts: attempts,
          ),
        );
      }
    }
    if (!any) {
      return const Left<ZFailure, ZChatSpeechDelivery>(
        ZUnsupportedOperationFailure(
          'no speech link available',
          operation: 'speak',
        ),
      );
    }
    return Left<ZFailure, ZChatSpeechDelivery>(attempts.last);
  }

  /// Arrête **tous** les maillons — un seul a parlé, mais on ne suppose pas
  /// lequel : la chaîne peut avoir changé d'avis entre deux lectures, et un
  /// maillon oublié continuerait à parler par-dessus.
  @override
  Future<void> stop() async {
    for (final ZChatSpeechPort link in links) {
      try {
        await link.stop();
      } catch (_) {
        // AD-10 : `stop` est best-effort — un maillon qui lève n'empêche PAS
        // les suivants de s'arrêter. C'est la raison d'être du `try` par tour.
      }
    }
  }

  Future<bool> _availabilityOf(ZChatSpeechPort link) async {
    try {
      return await link.isAvailable();
    } catch (_) {
      return false;
    }
  }

  Future<ZResult<ZChatSpeechDelivery>> _speakOn(
    ZChatSpeechPort link,
    ZChatSpeechRequest request,
  ) async {
    try {
      return await link.speak(request);
    } catch (error) {
      // AD-10 : un maillon d'hôte qui lève ne casse PAS la chaîne — il devient
      // un échec ordinaire, et le maillon suivant est essayé.
      return Left<ZFailure, ZChatSpeechDelivery>(ZDomainFailure('$error'));
    }
  }
}
