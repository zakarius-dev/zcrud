/// Diffusion **vocale** d'une réponse — port + chaîne de repli (invariants
/// AD-5, AD-10, AD-11).
///
/// ## Le défaut qu'une chaîne de repli écrite en dur produit
///
/// Une chaîne de repli (cache local, puis streaming distant, puis stockage
/// de secours, puis synthèse vocale sur l'appareil) **écrite dans le corps
/// d'une méthode**, mêlée au circuit breaker et au préchargement audio, porte
/// trois défauts mesurables :
///
/// 1. l'ordre des replis n'est **pas une donnée** — on ne peut ni le réordonner
///    ni en retirer un maillon sans réécrire la méthode ;
/// 2. le dernier maillon (synthèse locale) peut se retrouver **hors chaîne** :
///    l'appelant doit savoir l'invoquer lui-même, donc un appelant qui
///    l'oublie perd le repli le plus important — celui du hors-ligne ;
/// 3. les échecs des maillons intermédiaires sont **perdus** dans un simple
///    journal, donc un support qui reçoit « ça ne lit pas » n'apprend rien.
///
/// ⇒ Ici la chaîne est **un objet** ([ZChatSpeechChain]) : une liste ordonnée
/// de [ZChatSpeechPort], un **site unique** de repli, et les échecs des
/// maillons **conservés** dans [ZChatSpeechDelivery.attempts]. Zéro
/// dépendance : ni bibliothèque audio, ni bibliothèque de synthèse vocale, ni
/// HTTP n'entrent ici — chaque maillon est une implémentation d'hôte.
///
/// ## Ce qui reste absent plutôt que faux (invariant AD-10)
///
/// [ZChatSpeechRequest.languageTag] est **nullable**. Un appelant qui passe
/// une langue codée en dur dans un socle multi-consommateurs choisirait la
/// langue de lecture à la place de l'hôte. `null` signifie « laisse le moteur
/// décider » — jamais une langue par défaut devinée.
library;

import 'package:zcrud_core/domain.dart';

import '../z_chat_message.dart';
import '../z_content_block.dart';

/// Vitesse de lecture **par défaut**.
const double kZChatSpeechDefaultRate = 1.0;

/// Ce qu'on demande à lire.
///
/// **Aucun second résumé de message n'est écrit ici.** [ZChatSpeechRequest.ofMessage]
/// délègue à `zChatAccessibleTextOf` — la fonction qui produit déjà le texte
/// annonçable d'une suite de blocs, `switch` exhaustif compris. En écrire un
/// second rouvrirait un trou classique : un résumé local ne connaissant que
/// `ZTextBlock`, donc un tableau **jamais lu à voix haute**.
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
  /// le moteur choisir (invariant AD-10 : jamais un défaut inventé).
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
/// [sourceKind] est un discriminant **ouvert** (`String`), pas un enum : un
/// hôte a ses propres maillons (cache local, flux distant, stockage de
/// secours, synthèse sur l'appareil…) ; qu'il en ait deux, cinq, ou d'autres,
/// il ne doit pas avoir à forker le socle (invariant AD-4).
class ZChatSpeechDelivery {
  /// Construit un compte-rendu de lecture.
  ZChatSpeechDelivery({
    required this.sourceKind,
    List<ZFailure> attempts = const <ZFailure>[],
  }) : attempts = List<ZFailure>.unmodifiable(attempts);

  /// Le maillon qui a servi.
  final String sourceKind;

  /// Les échecs des maillons **essayés avant**, dans l'ordre — jamais
  /// perdus. C'est le renseignement qu'une chaîne écrite en dur jette dans un
  /// simple journal, et qui manque à tout diagnostic « ça ne lit pas ».
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

/// Un **maillon** de diffusion vocale — port d'hôte (invariant AD-11 : aucun
/// transport ici ; aucune dépendance tierce).
///
/// `speak` rend `ZResult<ZChatSpeechDelivery>` plutôt qu'un simple
/// `Either<_, void>` : la chaîne doit pouvoir dire **quel** maillon a servi.
/// La langue est optionnelle (cf. l'en-tête).
abstract interface class ZChatSpeechPort {
  /// Discriminant **ouvert** de ce maillon (`'onDeviceTts'`, `'localCache'`…).
  String get sourceKind;

  /// `true` si ce maillon est utilisable **maintenant**, sur cette plateforme.
  ///
  /// Ne lève jamais. Sur le web ou sans moteur, un maillon de synthèse rend
  /// `false` — et la chaîne passe au suivant **sans** produire d'échec, parce
  /// qu'un maillon indisponible n'est pas une panne.
  Future<bool> isAvailable();

  /// Lit [request].
  ///
  /// `Left` ⇒ la chaîne essaie le maillon suivant ; `Right` ⇒ elle s'arrête.
  Future<ZResult<ZChatSpeechDelivery>> speak(ZChatSpeechRequest request);

  /// Arrête la lecture en cours — **best-effort**, ne lève jamais.
  Future<void> stop();
}

/// La chaîne de repli, **en tant que donnée** — site unique du repli.
///
/// Reproduit la sémantique habituelle d'un service de streaming audio
/// (essayer chaque source dans l'ordre, retomber sur la suivante à l'échec),
/// en corrigeant ses trois défauts habituels : l'ordre est une liste, le
/// dernier maillon est **dans** la chaîne, et les échecs sont conservés.
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
  /// Invariant AD-10 : un maillon dont l'`isAvailable` **lève** — cas réel, un plugin qui
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
  ///   **existant** du cœur, pas une nouvelle famille ;
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
        // Invariant AD-10 : `stop` est best-effort — un maillon qui lève n'empêche PAS
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
      // Invariant AD-10 : un maillon d'hôte qui lève ne casse PAS la chaîne — il devient
      // un échec ordinaire, et le maillon suivant est essayé.
      return Left<ZFailure, ZChatSpeechDelivery>(ZDomainFailure('$error'));
    }
  }
}
