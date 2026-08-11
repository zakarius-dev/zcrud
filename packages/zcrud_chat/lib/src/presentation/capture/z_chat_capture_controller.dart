/// Saisie assistée — l'état réactif de la dictée et de la reconnaissance de
/// texte.
///
/// ## Ce que ce contrôleur garantit
///
/// L'insertion d'une capture concatène toujours : elle ne remplace jamais ce
/// que l'utilisateur avait déjà tapé. C'est la propriété la plus importante
/// de ce fichier après la relecture elle-même : [acceptInto] préserve,
/// [cancelReview] ne touche à rien d'autre que le brouillon de capture.
///
/// * l'état d'écoute est une tranche granulaire ([activity]), et rien
///   d'autre ne s'y abonne (invariant AD-2) — un cycle de dictée ne
///   reconstruit jamais le composer entier ;
/// * l'écoute est annoncée, pas seulement visible : un utilisateur
///   non-voyant doit savoir que le micro écoute. Le rendu ([ZChatCaptureBar])
///   porte une région live (invariant AD-13) ;
/// * la transcription n'est jamais un `String` nu accessible à l'appelant :
///   elle est un [ZUnreviewedText] (cf. l'en-tête de
///   `z_chat_capture_port.dart`) — l'envoi direct sans relecture n'est pas
///   seulement déconseillé, il est inexprimable dans ce contrat.
///
/// Aucune dépendance tierce : ni moteur de reconnaissance vocale, ni moteur
/// d'OCR, ni sélecteur de fichier. Les moteurs entrent par
/// [ZChatDictationPort] / [ZChatOcrPort], que l'hôte implémente.
library;

import 'package:flutter/foundation.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/domain.dart';

import '../z_chat_controller.dart';

/// Ce que la capture est en train de faire — tranche grossière, volontairement
/// séparée du texte relu (qui, lui, change à chaque frappe).
enum ZChatCaptureActivity {
  /// Rien en cours.
  idle,

  /// Le micro écoute — état qui DOIT être annoncé, pas seulement affiché.
  listening,

  /// Une image est en cours d'analyse.
  recognizing,
}

/// La surface de relecture : le seul puits d'un [ZUnreviewedText], et la
/// seule chose de ce contrôleur qui expose un texte lisible.
///
/// C'est assumé et c'est le point : une relecture qu'on ne peut pas afficher
/// n'est pas une relecture. Ce qui est structurel, c'est que le texte capturé
/// n'entre nulle part ailleurs, et que ce qui en ressort vers le composer est
/// la valeur **courante et mutable** de ce tampon — donc ce que l'utilisateur a
/// sous les yeux et peut corriger, pas la sortie du moteur.
class ZChatCaptureReviewBuffer extends ValueNotifier<String>
    implements ZChatReviewSink {
  /// Construit un tampon vide.
  ZChatCaptureReviewBuffer() : super('');

  /// Appelé à chaque mutation — hors mécanisme de `ChangeNotifier`.
  ///
  /// Le contrôleur propriétaire ne s'abonne pas à ce tampon. S'il le faisait,
  /// [isObserved] serait vrai en permanence et la garantie de
  /// [ZChatCaptureController.acceptInto] deviendrait vide de sens — une
  /// vérification toujours vraie, c'est-à-dire pire que pas de vérification.
  void Function()? onMutated;

  /// Dépose une capture — remplace le brouillon de relecture.
  ///
  /// Le composer, lui, n'est jamais remplacé ([ZChatCaptureController.acceptInto]).
  @override
  void seed(String seed) {
    value = seed;
    onMutated?.call();
  }

  /// Enregistre une **correction de l'utilisateur**.
  void edit(String text) {
    value = text;
    onMutated?.call();
  }

  /// Vide le brouillon (annulation, ou consommation).
  void clear() {
    value = '';
    onMutated?.call();
  }

  /// `true` si quelque chose affiche ce tampon.
  ///
  /// Proxy mesurable de « une surface de relecture est montée » : un
  /// `ValueListenableBuilder` qui rend le champ s'y abonne, un appelant qui
  /// lit `value` en douce ne s'y abonne pas. Ce n'est pas une preuve qu'un
  /// humain a lu — aucune API ne peut le prouver — mais c'en est le plus
  /// proche substitut vérifiable, et il fait échouer le raccourci le plus
  /// probable : « dicter puis insérer sans jamais rien montrer ».
  bool get isObserved => hasListeners;
}

/// L'état réactif de la saisie assistée — `ChangeNotifier` Flutter-native
/// (invariants AD-2/AD-15 : aucun gestionnaire d'état).
///
/// Les deux ports sont optionnels : sans eux, le chat fonctionne — on ne
/// peut simplement pas dicter ni scanner (même sémantique que
/// `ZChatRenderer`).
class ZChatCaptureController extends ChangeNotifier {
  /// Construit le contrôleur.
  ///
  /// [normalizer] est la couture où un hôte branche sa normalisation métier
  /// (par exemple convertir un nombre énoncé en toutes lettres vers sa forme
  /// chiffrée dans un domaine particulier) — une logique propre à l'hôte, qui
  /// reste chez lui.
  ZChatCaptureController({this.dictation, this.ocr, this.normalizer}) {
    review.onMutated = _syncPending;
  }

  /// Le moteur de dictée de l'hôte, ou `null`.
  final ZChatDictationPort? dictation;

  /// Le moteur d'OCR de l'hôte, ou `null`.
  final ZChatOcrPort? ocr;

  /// Normalisation d'hôte appliquée **avant** relecture, ou `null` (verbatim).
  final ZChatCaptureNormalizer? normalizer;

  /// Le brouillon de relecture.
  final ZChatCaptureReviewBuffer review = ZChatCaptureReviewBuffer();

  final ValueNotifier<ZChatCaptureActivity> _activity =
      ValueNotifier<ZChatCaptureActivity>(ZChatCaptureActivity.idle);
  final ValueNotifier<ZFailure?> _lastFailure = ValueNotifier<ZFailure?>(null);
  final ValueNotifier<bool> _pending = ValueNotifier<bool>(false);

  /// Ce que la capture fait **maintenant** — la tranche que la barre écoute.
  ValueListenable<ZChatCaptureActivity> get activity => _activity;

  /// Le dernier échec typé, ou `null`. Jamais une exception (invariant AD-10).
  ValueListenable<ZFailure?> get lastFailure => _lastFailure;

  /// `true` s'il y a quelque chose à relire.
  ValueListenable<bool> get hasPendingReview => _pending;

  void _syncPending() => _pending.value = review.value.trim().isNotEmpty;

  /// Lance un cycle de dictée et **dépose** la transcription dans [review].
  ///
  /// [localeId] est transmis tel quel, `null` compris : le socle ne choisit
  /// jamais la langue à la place de l'hôte (invariant AD-10).
  ///
  /// * `Right(unit)` — le cycle s'est terminé ; il y a peut-être quelque chose
  ///   à relire ([hasPendingReview]) ;
  /// * `Left(ZChatCaptureFailure)` — aucun moteur, permission refusée, panne.
  ///   **La saisie déjà tapée n'est jamais touchée** : ce contrôleur n'écrit
  ///   dans le composer que depuis [acceptInto].
  Future<ZResult<Unit>> startDictation({String? localeId}) async {
    final ZChatDictationPort? port = dictation;
    if (port == null) return _fail(ZChatCaptureRejection.unavailable, 'no dictation port');
    _lastFailure.value = null;
    _activity.value = ZChatCaptureActivity.listening;
    try {
      await for (final ZResult<ZChatDictationEvent> event
          in port.listen(localeId: localeId)) {
        final ZFailure? failure = event.fold(
          (ZFailure f) => f,
          (ZChatDictationEvent e) {
            // Chaque événement remplace le brouillon : le moteur émet des
            // transcriptions cumulatives, chacune plus complète que la
            // précédente.
            e.text.depositInto(review);
            return null;
          },
        );
        if (failure != null) {
          _activity.value = ZChatCaptureActivity.idle;
          _lastFailure.value = failure;
          return Left<ZFailure, Unit>(failure);
        }
      }
    } catch (error) {
      // Invariant AD-10 : un port d'hôte qui lève ne fait pas tomber la
      // conversation, et ne coûte pas la frappe de l'utilisateur.
      _activity.value = ZChatCaptureActivity.idle;
      return _fail(ZChatCaptureRejection.engineError, '$error');
    }
    _activity.value = ZChatCaptureActivity.idle;
    return const Right<ZFailure, Unit>(unit);
  }

  /// Arrête l'écoute — best-effort, ne lève jamais.
  Future<void> stopDictation() async {
    final ZChatDictationPort? port = dictation;
    if (port == null) return;
    try {
      await port.stop();
    } catch (_) {
      // Invariant AD-10 : `stop` est best-effort. Un moteur qui lève à
      // l'arrêt ne doit pas laisser l'interface bloquée sur « à l'écoute ».
    }
    _activity.value = ZChatCaptureActivity.idle;
  }

  /// Lance un cycle d'OCR et **dépose** le texte reconnu dans [review].
  ///
  /// * `Right(unit)` — texte reconnu, ou **annulation** de l'utilisateur (issue
  ///   nominale : rien n'a changé, et surtout rien n'a été perdu) ;
  /// * `Left(ZChatCaptureFailure)` — aucun moteur, permission refusée, aucun
  ///   texte détecté, panne.
  Future<ZResult<Unit>> scan(ZChatOcrRequest request) async {
    final ZChatOcrPort? port = ocr;
    if (port == null) return _fail(ZChatCaptureRejection.unavailable, 'no ocr port');
    _lastFailure.value = null;
    _activity.value = ZChatCaptureActivity.recognizing;
    final ZResult<ZUnreviewedText?> result;
    try {
      result = await port.recognize(request);
    } catch (error) {
      _activity.value = ZChatCaptureActivity.idle;
      return _fail(ZChatCaptureRejection.engineError, '$error');
    }
    _activity.value = ZChatCaptureActivity.idle;
    return result.fold(
      (ZFailure f) {
        _lastFailure.value = f;
        return Left<ZFailure, Unit>(f);
      },
      (ZUnreviewedText? text) {
        // `null` = annulation. Le brouillon N'EST PAS vidé : une OCR annulée ne
        // doit pas effacer une relecture en cours, pas plus qu'elle n'efface le
        // composer.
        text?.depositInto(review);
        return const Right<ZFailure, Unit>(unit);
      },
    );
  }

  /// Abandonne la relecture en cours.
  ///
  /// Ceci ne touche que le brouillon de capture : le composer n'est même pas
  /// atteignable depuis cette méthode, donc la saisie déjà tapée par
  /// l'utilisateur n'est jamais détruite par une annulation de capture.
  void cancelReview() {
    review.clear();
    _lastFailure.value = null;
    _activity.value = ZChatCaptureActivity.idle;
  }

  /// L'unique sortie de la capture — insère le texte relu dans le composer de
  /// [chat].
  ///
  /// Rend `ZResult<Unit>` : aucune `String` ne s'échappe. Le seul chemin
  /// possible pour un texte capturé est donc « tampon éditable → composer »,
  /// et depuis le composer c'est l'utilisateur qui décide d'envoyer.
  ///
  /// * la saisie existante est préservée : le texte relu lui est ajouté,
  ///   jamais substitué ;
  /// * `Left(ZDomainFailure)` si rien n'a été relu, ou si rien n'affiche le
  ///   tampon ([ZChatCaptureReviewBuffer.isObserved]) — le raccourci « dicter
  ///   puis insérer sans jamais rien montrer » échoue au lieu de réussir en
  ///   silence. C'est un type d'échec existant du cœur, pas un motif de
  ///   capture propre à ce contrôleur : il n'entre donc pas dans
  ///   [ZChatCaptureRejection].
  ZResult<Unit> acceptInto(ZChatController chat) {
    final String reviewed = review.value.trim();
    if (reviewed.isEmpty) {
      return const Left<ZFailure, Unit>(
        ZDomainFailure('nothing has been reviewed'),
      );
    }
    if (!review.isObserved) {
      return const Left<ZFailure, Unit>(
        ZDomainFailure('no review surface is observing the capture buffer'),
      );
    }
    final String existing = chat.composer.text;
    final String merged =
        existing.trim().isEmpty ? reviewed : '$existing\n\n$reviewed';
    chat.composer.text = merged;
    chat.composer.selection = chat.composer.selection.copyWith(
      baseOffset: merged.length,
      extentOffset: merged.length,
    );
    review.clear();
    _lastFailure.value = null;
    return const Right<ZFailure, Unit>(unit);
  }

  ZResult<Unit> _fail(ZChatCaptureRejection reason, String message) {
    final ZChatCaptureFailure failure =
        ZChatCaptureFailure(message, reason: reason);
    _lastFailure.value = failure;
    return Left<ZFailure, Unit>(failure);
  }

  @override
  void dispose() {
    review.onMutated = null;
    review.dispose();
    _activity.dispose();
    _lastFailure.dispose();
    _pending.dispose();
    super.dispose();
  }
}
