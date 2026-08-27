/// Mode vocal **continu** — la boucle « écouter → transcrire → soumettre →
/// énoncer → réécouter ».
///
/// ## Ce fichier est une ORCHESTRATION, pas un moteur
///
/// Rien n'est reconnu ni synthétisé ici. Les deux capacités entrent par des
/// ports d'hôte déjà existants ([ZChatDictationPort] via
/// [ZChatCaptureController], [ZChatSpeechPort] via [ZChatDiffusionService]),
/// et ce contrôleur se contente de les enchaîner. Il ne demande **aucune
/// permission** micro : un port dit s'il est utilisable, et c'est tout.
///
/// ## Elle s'appuie sur la dictée ponctuelle, elle ne la remplace pas
///
/// Un tour de boucle appelle [ZChatCaptureController.startDictation] puis
/// [ZChatCaptureController.acceptInto] — exactement les deux verbes qu'un
/// appui sur le bouton « Dicter » déclenche. Trois conséquences, toutes
/// voulues :
///
/// * il n'existe pas de second chemin d'insertion d'une transcription dans la
///   saisie, donc pas de seconde règle à tenir à jour ;
/// * la transcription reste un `ZUnreviewedText` déposé dans le tampon de
///   relecture : le mode vocal **n'ouvre pas** de voie d'envoi sans relecture.
///   Sans surface de relecture montée, `acceptInto` refuse, et le tour
///   s'arrête proprement au lieu d'envoyer en aveugle ;
/// * la dictée ponctuelle reste utilisable seule, sans ce contrôleur.
///
/// ## Les conditions d'arrêt sont le contrat
///
/// Une boucle vocale qui ne s'arrête pas laisse le micro ouvert, couvre
/// l'utilisateur de sa propre voix et vide la batterie. Quatre chemins
/// d'arrêt sont donc garantis :
///
/// | Chemin | Effet |
/// |---|---|
/// | frappe au clavier | le composer appelle [stop] : la session s'arrête |
/// | échec d'un port | [stop] est appelé, l'échec est publié dans [lastFailure], rien ne lève |
/// | destruction ([dispose], ou celle du composer) | les ports sont arrêtés, aucun abonnement ne survit |
/// | [stop] pendant une attente | la boucle **ne redémarre pas** : chaque `await` est suivi d'une relecture de [active] |
///
/// ## Invariant AD-2 — tranches granulaires
///
/// [phase] et [active] sont des `ValueListenable` séparées : un changement de
/// phase reconstruit l'indicateur de session, jamais le champ de saisie — la
/// saisie en cours et le focus survivent donc à tout un tour de boucle.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/domain.dart';

import '../diffusion/z_chat_diffusion_service.dart';
import '../z_chat_controller.dart';
import 'z_chat_capture_controller.dart';

/// Où en est un tour de la boucle vocale — tranche **grossière**,
/// volontairement séparée de la saisie (qui change à chaque frappe).
enum ZChatVoiceSessionPhase {
  /// Aucune session en cours.
  idle,

  /// Le micro écoute — état qui DOIT être annoncé, pas seulement affiché.
  listening,

  /// La transcription part dans le tour, et le tour est en vol.
  submitting,

  /// La réponse est lue à voix haute.
  speaking,
}

/// La boucle vocale continue — `ChangeNotifier` Flutter-native (invariants
/// AD-2/AD-15 : aucun gestionnaire d'état).
///
/// Sans moteur de dictée **ou** sans moteur de synthèse, la session est
/// [isAvailable] `false` : [start] rend un `Left` typé et **rien ne lève**.
class ZChatVoiceSessionController extends ChangeNotifier {
  /// Construit le contrôleur.
  ///
  /// Aucun des trois collaborateurs n'est possédé : leur cycle de vie
  /// appartient à l'hôte, et [dispose] ne les détruit pas — il se contente
  /// d'arrêter ce qu'il a démarré.
  ZChatVoiceSessionController({
    required this.chat,
    required this.capture,
    this.diffusion,
    this.localeId,
    this.languageTag,
    this.rate = kZChatSpeechDefaultRate,
  });

  /// La conversation à laquelle la session soumet.
  final ZChatController chat;

  /// La saisie assistée — c'est **elle** qui porte le moteur de dictée et le
  /// tampon de relecture.
  final ZChatCaptureController capture;

  /// La diffusion vocale, ou `null` si l'hôte n'en branche aucune.
  final ZChatDiffusionService? diffusion;

  /// Langue de reconnaissance transmise **telle quelle**, `null` compris :
  /// `null` signifie « laisse le moteur décider », jamais une langue en dur.
  final String? localeId;

  /// Langue de synthèse, même règle que [localeId].
  final String? languageTag;

  /// Débit de lecture transmis au port de synthèse.
  final double rate;

  final ValueNotifier<ZChatVoiceSessionPhase> _phase =
      ValueNotifier<ZChatVoiceSessionPhase>(ZChatVoiceSessionPhase.idle);
  final ValueNotifier<bool> _active = ValueNotifier<bool>(false);
  final ValueNotifier<ZFailure?> _lastFailure = ValueNotifier<ZFailure?>(null);

  bool _disposed = false;

  /// Où en est la boucle — la tranche que l'indicateur écoute.
  ValueListenable<ZChatVoiceSessionPhase> get phase => _phase;

  /// `true` tant qu'une session tourne. Séparée de [phase] : une affordance
  /// « arrêter » n'a pas à se reconstruire à chaque tour de boucle.
  ValueListenable<bool> get active => _active;

  /// Dernier échec **typé**, ou `null`. Jamais une exception (invariant
  /// AD-10).
  ValueListenable<ZFailure?> get lastFailure => _lastFailure;

  /// `true` si les deux capacités sont branchées.
  ///
  /// La boucle énonce la réponse : sans moteur de synthèse elle serait
  /// muette, donc ce n'est pas la même fonctionnalité rendue en dégradé —
  /// c'est une autre. Le socle préfère la déclarer indisponible plutôt que
  /// de promettre un geste qui ne viendra pas.
  bool get isAvailable => capture.dictation != null && diffusion?.speech != null;

  /// Démarre la boucle et rend la main **quand elle s'arrête**.
  ///
  /// Le futur se complète à l'arrêt de la session, quelle qu'en soit la
  /// cause. Un appelant d'interface l'abandonne (`unawaited`) ; un test
  /// l'attend.
  ///
  /// * `Left(ZUnsupportedOperationFailure)` — une capacité manque : la
  ///   session est indisponible, et rien n'a été démarré ;
  /// * `Left(ZFailure)` — un port a échoué en cours de boucle ; la session
  ///   est arrêtée et le micro fermé ;
  /// * `Right(unit)` — la session s'est arrêtée sans échec.
  Future<ZResult<Unit>> start() async {
    if (!isAvailable) {
      const ZFailure failure = ZUnsupportedOperationFailure(
        'no dictation or speech port wired',
        operation: 'voiceSession',
      );
      _publishFailure(failure);
      return const Left<ZFailure, Unit>(failure);
    }
    // Idempotent : un second appui sur l'affordance ne lance pas une seconde
    // boucle sur le même micro.
    if (_active.value) return const Right<ZFailure, Unit>(unit);
    _set(_lastFailure, null);
    _set(_active, true);
    return _loop();
  }

  /// Arrête la session — best-effort, ne lève **jamais**.
  ///
  /// C'est le site unique d'arrêt : la frappe au clavier, l'échec d'un port et
  /// la destruction passent tous par ici. [active] retombe à `false`
  /// **immédiatement**, avant même que les ports aient répondu : la boucle
  /// relit cette tranche après chacune de ses attentes, donc un arrêt demandé
  /// pendant une attente ne peut pas être suivi d'un tour de plus.
  Future<void> stop() async {
    if (!_active.value) return;
    _set(_active, false);
    await capture.stopDictation();
    await diffusion?.stopNarration();
    _set(_phase, ZChatVoiceSessionPhase.idle);
  }

  Future<ZResult<Unit>> _loop() async {
    ZFailure? failure;
    while (_active.value) {
      // 1 — écouter et transcrire. La transcription atterrit dans le tampon
      // de relecture de la capture, pas ici.
      _set(_phase, ZChatVoiceSessionPhase.listening);
      final ZResult<Unit> heard = await capture.startDictation(
        localeId: localeId,
      );
      if (!_active.value) break;
      failure = _failureOf(heard);
      if (failure != null) break;

      // 2 — insérer le texte relu dans la saisie. `acceptInto` refuse si rien
      // n'a été relu ou si aucune surface ne montre le tampon : dans les deux
      // cas la boucle s'arrête au lieu d'envoyer quelque chose que personne
      // n'a vu.
      failure = _failureOf(capture.acceptInto(chat));
      if (failure != null) break;

      // 3 — soumettre, et ATTENDRE le tour : `send()` ne rend la main qu'une
      // fois le flux consommé, réponse écrite dans le fil. Il n'y a donc pas
      // de seconde attente à écrire ici — en écrire une donnerait un
      // mécanisme que rien n'exerce, et une garde que rien ne peut faire
      // rougir.
      //
      // Aucune requête n'est fabriquée ici : c'est le `send()` existant du
      // contrôleur, avec ses refus.
      //
      // La POSITION de la dernière réponse est relevée AVANT le tour : c'est
      // elle qui distingue « la réponse de ce tour » de « la réponse du tour
      // précédent, encore en queue de fil ». Sans ce repère, un tour qui ne
      // produit rien — annulé, refusé, interrompu — ferait relire à voix haute
      // une réponse déjà entendue.
      //
      // La position, et non l'identité : un événement terminal qui n'annonce
      // aucune identité laisse la réponse avec un identifiant VIDE (mesuré),
      // et deux réponses successives compareraient alors égales — la seconde
      // ne serait jamais lue.
      final int previousReplyIndex = _latestReplyIndex();
      _set(_phase, ZChatVoiceSessionPhase.submitting);
      final ZResult<ZChatRequestToken> sent = await chat.send();
      if (!_active.value) break;
      failure = _failureOf(sent);
      if (failure != null) break;

      // 4 — énoncer la réponse. Aucun rendu n'est écrit ici : le texte lu est
      // celui que le résolveur d'annonce du kernel produit déjà, via
      // `narrateMessage`.
      final int replyIndex = _latestReplyIndex();
      if (replyIndex > previousReplyIndex) {
        final ZChatMessage reply = chat.messages.value[replyIndex];
        _set(_phase, ZChatVoiceSessionPhase.speaking);
        final ZResult<ZChatSpeechDelivery> spoken = await diffusion!
            .narrateMessage(reply, languageTag: languageTag, rate: rate);
        // Pas de relecture de [active] ici : la condition de boucle, deux
        // lignes plus bas, la porte déjà — plus rien ne se produit entre les
        // deux. Une clause de plus serait une clause qu'aucune injection ne
        // pourrait faire rougir.
        failure = _failureOf(spoken);
        if (failure != null) break;
      }
      // 5 — réécouter : le tour suivant recommence par l'écoute.
    }
    final ZFailure? cause = failure;
    if (cause != null) _publishFailure(cause);
    // Un échec ferme le micro comme un arrêt demandé : la session ne reste
    // jamais « en écoute » derrière une panne.
    await stop();
    return cause == null
        ? const Right<ZFailure, Unit>(unit)
        : Left<ZFailure, Unit>(cause);
  }

  /// Position de la dernière réponse **établie** du fil, ou `-1`.
  ///
  /// La lecture porte sur le rôle, pas sur une identité reconstruite : un tour
  /// interrompu ne nomme pas sa réponse de la même façon qu'un tour complet, et
  /// deviner ce nom ferait lire le mauvais message une fois sur deux.
  int _latestReplyIndex() {
    final List<ZChatMessage> thread = chat.messages.value;
    for (int i = thread.length - 1; i >= 0; i--) {
      if (thread[i].role == ZChatRole.assistant) return i;
    }
    return -1;
  }

  ZFailure? _failureOf(ZResult<Object?> result) =>
      result.fold((ZFailure f) => f, (Object? _) => null);

  void _publishFailure(ZFailure failure) => _set(_lastFailure, failure);

  /// Écrit une tranche **seulement si** le contrôleur vit encore.
  ///
  /// La boucle est asynchrone : un `await` peut se dénouer après la
  /// destruction. Sans ce garde-fou, la reprise écrirait dans un
  /// `ValueNotifier` disposé et ferait tomber l'application sur un chemin
  /// parfaitement nominal (invariant AD-10).
  void _set<T>(ValueNotifier<T> slice, T value) {
    if (_disposed) return;
    slice.value = value;
  }

  @override
  void dispose() {
    _disposed = true;
    _active.value = false;
    // Aucun abonnement ne survit : le flux d'écoute est fermé par le `stop()`
    // du port, et la boucle relit [active] après chacune de ses attentes.
    unawaited(capture.stopDictation());
    unawaited(diffusion?.stopNarration() ?? Future<void>.value());
    _phase.dispose();
    _active.dispose();
    _lastFailure.dispose();
    super.dispose();
  }
}
