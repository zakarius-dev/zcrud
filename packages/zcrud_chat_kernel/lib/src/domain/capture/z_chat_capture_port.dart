/// Saisie **assistée** — dictée vocale et OCR — en PORTS, avec la relecture
/// obligatoire rendue STRUCTURELLE (CHAT-10 ; AD-5, AD-10, AD-11, AD-13,
/// AD-57).
///
/// origine **MESURÉE sur disque** (lecture seule, `/home/zakarius/DEV/lex_douane`) :
/// * `packages/lex_core/lib/domain/services/speech_recognition_service.dart`
///   — `DictationStatus` (`listening`, `done`, `unavailable`,
///   `permissionDenied`, `error`), le DTO `DictationResult` (`text`, `isFinal`,
///   `status`) et le contrat `initialize` / `isAvailable` /
///   `listen({localeId})` / `stop()` ;
/// * `packages/lex_core/lib/domain/services/ocr_service.dart`
///   — `OcrStatus` (`recognized`, `noText`, `cancelled`, `unavailable`,
///   `permissionDenied`, `error`), le DTO `OcrResult` et le contrat
///   `isAvailable` / `scanFromCamera()` / `recognizeFromBytes(bytes)` ;
/// * `packages/lex_ui/lib/presentation/widgets/chat/chat_dictation_review_sheet.dart`
///   et `chat_ocr_review_sheet.dart` — les DEUX feuilles de **relecture** ;
/// * `packages/lex_ui/lib/presentation/widgets/chat/chat_input.dart:208-380`
///   — le câblage réel dans le composer (`_runOcr`, `_startDictation`,
///   `_insertDictation`, `_insertOcrContext`).
///
/// ## 🔴 La ligne de partage DOMAINE / ADAPTATEUR
///
/// **Domaine (ici)** : les états d'un cycle de capture, le fait qu'une capture
/// produise un texte **non relu**, le fait que ce texte n'ait **aucun** chemin
/// vers l'envoi, et les deux contrats d'hôte.
///
/// **Adaptateur (reste chez l'hôte)** : `speech_to_text`, `image_picker`,
/// `google_mlkit_text_recognition`, `path_provider`, le `kIsWeb`, la table
/// `languageCode → localeId` (`chat_input.dart:363-372`) — et surtout
/// `DictationNumberNormalizer` (`lex_ui/.../utils/dictation_number_normalizer.dart`),
/// qui convertit « huit cent cinq » en `0805` **avec padding de position SH**.
/// Ce dernier est du métier DOUANIER pur : le porter ferait entrer la
/// nomenclature tarifaire dans un socle générique. Il n'est pas porté, et la
/// couture qui permettrait à un hôte de le brancher est
/// [ZChatCaptureNormalizer].
///
/// ## 🔴 L'INVARIANT du lot : l'envoi direct est INEXPRIMABLE
///
/// Une transcription vocale et une extraction OCR sont **faillibles par
/// nature**. Chez lex, la relecture est tenue par la **discipline de
/// l'appelant** : `chat_input.dart` ouvre bien une feuille de relecture, mais
/// `DictationResult.text` est un `String` public — rien, dans le type, n'empêche
/// un second appelant de l'envoyer tel quel. C'est exactement la forme de
/// promesse que ce dépôt refuse.
///
/// Ici, le texte capturé est [ZUnreviewedText] :
/// * son contenu est un champ **privé** — la portée du privé en Dart est la
///   BIBLIOTHÈQUE, donc aucun autre fichier, aucun autre paquet, ne peut le
///   lire ;
/// * **aucun** membre public ne rend une `String` — ni getter, ni méthode, ni
///   `toString()` (qui n'expose que la longueur : un `debugPrint` puis un
///   copier-coller serait une fuite parfaitement suffisante) ;
/// * l'**unique** sortie est [ZUnreviewedText.depositInto], qui rend `void` et
///   n'accepte qu'un [ZChatReviewSink] — c'est-à-dire une surface **éditable
///   par l'utilisateur**.
///
/// Il n'existe donc, dans le socle, **aucune arête** `capture → String →
/// envoi`. Ce n'est pas « déconseillé » : ça ne compile pas.
///
/// ## 🔴 Ce qui est modélisé, et ce qui est laissé OUVERT (piège n°1)
///
/// [ZChatCaptureRejection] compte **quatre** motifs, et les quatre sont LUS
/// chez lex. Rien de plus n'est deviné : pas de `retryable`, pas de
/// « locale non supportée », pas de score de confiance de l'ASR, pas de
/// « moteur en cours de téléchargement » — aucun de ces cas n'existe dans les
/// deux services de lex, et un socle qui les modéliserait obligerait chaque
/// hôte à répondre à des questions que son moteur ne pose pas.
///
/// L'annulation par l'utilisateur (`OcrStatus.cancelled`) n'est **pas** un
/// motif de rejet : c'est une **valeur** (`Right(null)`), exactement comme
/// `ZChatAttachmentPicker.pick` de CHAT-5 traite l'annulation d'un sélecteur.
/// lex la range dans le même `enum` que `error` — ce qui force chaque appelant
/// à se souvenir qu'un de ses cas d'erreur n'en est pas un.
library;

import 'dart:typed_data';

import 'package:zcrud_core/domain.dart';

/// Longueur maximale d'un texte capturé retenue **sans** troncature.
///
/// 🔴 Ce n'est PAS une limite de sécurité et ça ne prétend pas l'être (même
/// partition que `ZChatAttachmentFailure`). C'est une borne d'ergonomie : une
/// OCR de page dense produit couramment plusieurs dizaines de milliers de
/// caractères, et les déverser dans un composer rend la relecture impossible —
/// donc rend l'invariant du lot inopérant en pratique.
///
/// 🔴 Au-delà du seuil, la capture est **acceptée ENTIÈRE** : le socle ne
/// tronque RIEN, il se contente de l'annoncer ([ZUnreviewedText.isLarge]) pour
/// que l'hôte avertisse. Tronquer à la place de l'utilisateur détruirait de la
/// saisie — exactement le défaut que ce lot existe pour ne pas rejouer.
const int kZChatCaptureLargeTextThreshold = 20000;

/// Motif d'échec d'un cycle de capture — famille **fermée** (elle ne traverse
/// aucune frontière de sérialisation : AD-4 ne s'y applique pas).
///
/// Correspondance **exacte** avec ce qui est lu chez lex :
///
/// | ici | lex `DictationStatus` | lex `OcrStatus` |
/// |---|---|---|
/// | [unavailable]      | `unavailable`      | `unavailable`      |
/// | [permissionDenied] | `permissionDenied` | `permissionDenied` |
/// | [nothingCaptured]  | (transcription vide) | `noText`         |
/// | [engineError]      | `error`            | `error`            |
///
/// `listening` / `done` ne sont pas des échecs : ce sont les phases d'un cycle
/// de dictée ([ZChatDictationPhase]). `cancelled` n'en est pas un non plus :
/// c'est `Right(null)`.
enum ZChatCaptureRejection {
  /// Aucun moteur sur cette plateforme (web, plugin absent, moteur non
  /// installé). L'hôte masque l'affordance — il ne la grise pas en promettant
  /// une action qui ne viendra jamais.
  unavailable,

  /// L'utilisateur a refusé la permission (micro, caméra). Le clavier reste
  /// utilisable : c'est **le** point où lex insiste, et il a raison.
  permissionDenied,

  /// Le cycle a réussi mais n'a **rien** produit : silence, image floue, page
  /// vide. Distinct de [engineError] — rien n'est cassé, il n'y a simplement
  /// rien à relire, et surtout **rien à écraser dans le composer**.
  nothingCaptured,

  /// Panne du moteur (réseau ASR, délai dépassé, décodage impossible).
  engineError,
}

/// Échec **typé** d'un cycle de capture (AD-5).
///
/// Porte [reason] et, quand le refus vient d'ailleurs, la [cause] d'origine —
/// **transportée**, jamais réinterprétée (même règle que
/// `ZChatAttachmentFailure.cause`).
class ZChatCaptureFailure extends ZFailure {
  /// Construit un échec de capture.
  const ZChatCaptureFailure(
    super.message, {
    required this.reason,
    this.cause,
  });

  /// Le motif du rejet.
  final ZChatCaptureRejection reason;

  /// L'échec d'origine relayé verbatim, ou `null`.
  final ZFailure? cause;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatCaptureFailure &&
          runtimeType == other.runtimeType &&
          message == other.message &&
          reason == other.reason &&
          cause == other.cause;

  @override
  int get hashCode => Object.hash(runtimeType, message, reason, cause);

  @override
  String toString() => 'ZChatCaptureFailure($reason, message: $message)';
}

/// 🔴 Une surface **éditable par l'utilisateur**, et le SEUL puits d'un
/// [ZUnreviewedText].
///
/// Le contrat tient en une ligne parce que c'est tout ce qu'il doit garantir :
/// on **dépose** un texte dans quelque chose que l'utilisateur peut corriger.
/// Rien n'en ressort ici — la sortie appartient à l'implémentation, qui est,
/// par construction, la surface de relecture elle-même.
abstract interface class ZChatReviewSink {
  /// Dépose [seed] dans la surface éditable, en **remplaçant** ce qu'elle
  /// contenait (c'est un brouillon de relecture, pas le composer : le composer,
  /// lui, n'est jamais écrasé — cf. `ZChatCaptureController.acceptInto`).
  void seed(String seed);
}

/// Transforme un texte capturé **avant** relecture — couture d'hôte, optionnelle.
///
/// C'est ici que se branche `DictationNumberNormalizer` de lex (« huit cent
/// cinq » → `0805`), qui reste CHEZ LUI : il connaît la nomenclature SH, ce
/// socle non. `null` ⇒ le texte est déposé **verbatim**, ce qui est la seule
/// valeur par défaut honnête (AD-10 : jamais un défaut inventé).
typedef ZChatCaptureNormalizer = String Function(String raw);

/// 🔴 Un texte capturé **qui n'a pas été relu** — le type qui rend l'envoi
/// direct inexprimable.
///
/// Il n'expose **aucune** `String`. Son unique sortie est [depositInto], qui
/// rend `void`. Un hôte peut bien sûr écrire une implémentation de
/// [ZChatReviewSink] qui capte le texte et l'envoie : ce serait *son* défaut,
/// écrit à la main, visible à la revue — pas une pente offerte par le socle.
/// C'est la frontière atteignable, et elle est nommée plutôt que promise.
final class ZUnreviewedText {
  /// Construit un texte non relu à partir de ce qu'a produit un moteur.
  ///
  /// [normalizer] est appliqué **une fois**, à la construction : la surface de
  /// relecture reçoit le texte déjà normalisé, comme chez lex (la feuille
  /// normalise `initState`), et l'utilisateur corrige la normalisation elle-même
  /// s'il le faut.
  ZUnreviewedText(String raw, {ZChatCaptureNormalizer? normalizer})
    : _raw = normalizer == null ? raw : normalizer(raw);

  /// 🔴 Le contenu — **privé à la bibliothèque**. Aucun autre fichier ne peut
  /// le lire, et aucun membre public ne le rend.
  final String _raw;

  /// Nombre de caractères capturés — métadonnée, pas contenu.
  int get length => _raw.length;

  /// `true` si la capture n'a rien produit d'exploitable.
  ///
  /// C'est ce que l'appelant teste pour ne PAS ouvrir une relecture vide, et
  /// pour ne rien écrire dans un composer déjà rempli.
  bool get isBlank => _raw.trim().isEmpty;

  /// `true` si la capture est assez volumineuse pour que l'hôte veuille
  /// prévenir avant d'ouvrir la relecture ([kZChatCaptureLargeTextThreshold]).
  bool get isLarge => _raw.length > kZChatCaptureLargeTextThreshold;

  /// 🔴 **L'UNIQUE sortie.** Dépose le texte dans une surface éditable.
  ///
  /// Rend `void` : rien ne s'échappe vers l'appelant. Ne fait rien si la
  /// capture est vide — déposer du blanc dans une relecture ferait croire à
  /// l'utilisateur que le moteur a compris quelque chose.
  void depositInto(ZChatReviewSink sink) {
    if (isBlank) return;
    sink.seed(_raw);
  }

  /// 🔴 N'expose **PAS** le contenu.
  ///
  /// Un `toString()` qui rendrait le texte suffirait à contourner tout ce
  /// fichier : `debugPrint('$unreviewed')`, puis copier-coller. C'est une fuite
  /// mesurée ailleurs dans ce dépôt (les `debugPrint` de la chaîne audio de
  /// lex), et elle est fermée ici plutôt que documentée.
  @override
  String toString() => 'ZUnreviewedText(${_raw.length} chars, unreviewed)';
}

/// Phase d'un cycle de dictée — port **exact** de `DictationStatus.listening` /
/// `.done` de lex. Les trois autres valeurs de son `enum` sont des ÉCHECS et
/// vivent dans [ZChatCaptureRejection] : les mélanger, comme lex le fait, force
/// chaque `switch` d'appelant à trier lui-même l'état et la panne.
enum ZChatDictationPhase {
  /// Le moteur écoute — l'hôte DOIT l'annoncer (région live, AD-13), pas
  /// seulement l'afficher.
  listening,

  /// Le cycle s'est terminé normalement (silence, arrêt manuel).
  done,
}

/// Un événement de dictée — port de `DictationResult`, avec [text] devenu
/// **non lisible** ([ZUnreviewedText]).
class ZChatDictationEvent {
  /// Construit un événement de dictée.
  const ZChatDictationEvent({
    required this.text,
    required this.isFinal,
    required this.phase,
  });

  /// Le texte transcrit **verbatim**, non relu.
  final ZUnreviewedText text;

  /// `true` quand le moteur a figé la transcription.
  final bool isFinal;

  /// Phase courante du cycle.
  final ZChatDictationPhase phase;

  @override
  String toString() =>
      'ZChatDictationEvent($phase, isFinal: $isFinal, ${text.length} chars)';
}

/// Couture de **dictée** (speech-to-text) — l'hôte fournit le moteur (AD-57).
///
/// 🔴 Aucun moteur ici, et aucune dépendance : `speech_to_text` reste chez
/// l'hôte, avec ses permissions de manifeste. Sans implémentation, le chat
/// fonctionne — on ne peut simplement pas dicter (sémantique de
/// `ZChatRenderer` : `null` est une réponse valide).
abstract interface class ZChatDictationPort {
  /// `true` si un moteur est utilisable **maintenant**. Ne lève jamais.
  Future<bool> isAvailable();

  /// Écoute et émet les transcriptions partielles puis finale.
  ///
  /// [localeId] est **nullable** : `null` = « laisse le moteur décider »,
  /// jamais « français ». lex passe `'fr_FR'` en repli codé en dur
  /// (`chat_input.dart:371`) — acceptable dans une app francophone, jamais dans
  /// un socle multi-consommateurs (même écart que `ZChatSpeechRequest.languageTag`).
  ///
  /// Chaque élément est un `ZResult` : `Left(ZChatCaptureFailure)` pour un refus
  /// de permission, une indisponibilité ou une panne — **jamais** une exception
  /// (AD-10).
  Stream<ZResult<ZChatDictationEvent>> listen({String? localeId});

  /// Arrête l'écoute — best-effort, ne lève jamais.
  Future<void> stop();
}

/// D'où vient l'image soumise à l'OCR.
///
/// Les deux flux **vivants** de lex : `scanFromCamera()` (capture) et
/// `recognizeFromBytes()` (une image déjà en mémoire, typiquement une pièce
/// jointe de CHAT-5). Une valeur de plus ne se justifierait que si un flux de
/// plus existait réellement.
enum ZChatOcrSource {
  /// L'hôte ouvre la caméra ou un sélecteur : l'utilisateur peut **annuler**.
  capture,

  /// Des octets déjà en mémoire : ni permission, ni annulation possibles.
  bytes,
}

/// Ce qu'on demande à l'OCR.
class ZChatOcrRequest {
  /// Demande une **capture** (caméra / sélecteur d'image).
  const ZChatOcrRequest.capture()
    : source = ZChatOcrSource.capture,
      bytes = null;

  /// Demande la reconnaissance d'une image **déjà en mémoire**.
  const ZChatOcrRequest.bytes(Uint8List this.bytes)
    : source = ZChatOcrSource.bytes;

  /// D'où vient l'image.
  final ZChatOcrSource source;

  /// Les octets, pour [ZChatOcrSource.bytes] ; `null` pour une capture.
  final Uint8List? bytes;

  @override
  String toString() =>
      'ZChatOcrRequest($source, ${bytes?.length ?? 0} bytes)';
}

/// Couture d'**OCR** — l'hôte fournit le moteur (AD-57).
///
/// 🔴 Ni `google_mlkit_text_recognition`, ni `image_picker`, ni
/// `path_provider` n'entrent ici. La reconnaissance est **on-device** ou non
/// selon l'hôte : ce socle ne le sait pas et n'a pas à le savoir.
abstract interface class ZChatOcrPort {
  /// `true` si un moteur est utilisable **maintenant**. Ne lève jamais.
  Future<bool> isAvailable();

  /// Extrait le texte de l'image décrite par [request].
  ///
  /// * `Right(ZUnreviewedText)` — du texte a été reconnu ;
  /// * `Right(null)` — l'utilisateur a **annulé** (issue nominale : le
  ///   `cancelled` de lex, sorti de l'`enum` d'erreurs) ;
  /// * `Left(ZChatCaptureFailure)` — permission refusée, indisponible, aucun
  ///   texte, panne. **Jamais** d'exception (AD-10).
  Future<ZResult<ZUnreviewedText?>> recognize(ZChatOcrRequest request);
}
