/// `ZFlashcardGenerationController` — orchestration du flux de génération IA
/// (SU-9/AC5..AC8/AC13 — AD-2/AD-15/AD-10/AD-37/AD-43).
///
/// ## Réactivité Flutter-native PURE (AD-2/AD-15)
///
/// `ChangeNotifier` **pur-Flutter** : AUCUN gestionnaire d'état (ni Riverpod, ni
/// GetX, ni provider) — la garde `z_widgets_purity_test.dart` le verrouille. Le
/// statut est une **enum** ([ZFlashcardGenerationStatus]), jamais une grappe de
/// booléens qui pourrait exprimer un état impossible.
///
/// ## Rien n'est persisté (AD-37/AD-43 — SU-9/AC5/AC6)
///
/// Le contrôleur **n'importe AUCUN** store/repository — aucune LIGNE DE CODE
/// (commentaires exclus) ne matche `Repository|LocalStore|RemoteStore|save|persist`
/// (grep code-only ⇒ RC=1 ; la garde `z_widgets_purity_test.dart` le verrouille
/// par mutation) : la « frontière de commit » d'AD-43 est le **handoff**
/// [onGenerated] à l'appelant, pas une
/// écriture base. Les cartes remises sont **éphémères** (`id == null` sur
/// chacune, [_ephemeral]) et leur `source` n'est estampillée QUE depuis
/// `request.provenance` (jamais une source backend). L'app tuée en cours ⇒ rien,
/// puisqu'aucune voie d'écriture n'existe.
///
/// ## Port ASYNCHRONE et FAILLIBLE (AD-10/AD-35 — SU-9/AC7/AC8)
///
/// Le port peut **lever**, **timeouter**, renvoyer `Left(ZFailure)`, `Right([])`
/// (0 carte) ou répondre **tard** (feuille déjà fermée). Un **jeton de fraîcheur
/// monotone** ([_generation]), capturé avant l'`await` et comparé après, **écarte**
/// toute réponse périmée : jamais un lot obsolète appliqué, jamais un
/// `notifyListeners` après `dispose`, jamais une persistance. L'anti-double-tap
/// ignore toute soumission pendant `status == generating`.
library;

import 'package:flutter/foundation.dart';
import 'package:zcrud_core/domain.dart' show ZResult;
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart' show ZFlashcardTag;

import '../domain/z_flashcard_generation_port.dart';

/// Statut du flux de génération (AD-2 : enum, jamais des booléens — AC6).
enum ZFlashcardGenerationStatus {
  /// Aucune génération en cours (état initial et après abandon/handoff).
  idle,

  /// Requête en vol (`await` du port) — l'anti-double-tap est actif.
  generating,

  /// Le port a répondu un lot NON vide : aperçu proposé à l'utilisateur.
  preview,

  /// L'utilisateur revoit/édite les tags suggérés avant confirmation.
  confirmingTags,

  /// Le port a échoué (Left / throw / 0 carte) : message affiché, saisie préservée.
  failed,
}

/// Libellés INJECTÉS des messages d'échec NON portés par un `ZFailure` (i18n —
/// AC7/AC12). Aucun libellé en dur dans le contrôleur (FR-26/AD-13).
@immutable
class ZFlashcardGenerationMessages {
  /// Construit les messages injectés.
  const ZFlashcardGenerationMessages({
    required this.unexpectedError,
    required this.emptyResult,
  });

  /// Affiché quand le port **lève** (exception capturée, convertie en `failed`).
  final String unexpectedError;

  /// Affiché quand le port répond `Right([])` (0 carte générée).
  final String emptyResult;
}

/// Callback de **handoff** : remet le lot éphémère + les tags confirmés à
/// l'appelant (typiquement le multi-éditeur FR-SU20). C'est l'UNIQUE canal de
/// sortie du résultat — non persistant (AC5/AC6).
typedef ZFlashcardGeneratedCallback = void Function(
  List<ZFlashcard> cards,
  List<ZFlashcardTag> confirmedTags,
);

/// Contrôleur du flux de génération (aucun store — AD-37/AD-43).
class ZFlashcardGenerationController extends ChangeNotifier {
  /// Construit le contrôleur autour d'un [port] advisory/faillible (AD-35).
  ZFlashcardGenerationController({
    required ZFlashcardGenerationPort port,
    required this.messages,
    this.onGenerated,
    List<ZFlashcardType>? generableTypes,
  })  : _port = port,
        generableTypes =
            generableTypes ?? List<ZFlashcardType>.unmodifiable(ZFlashcardType.values);

  final ZFlashcardGenerationPort _port;

  /// Messages d'échec injectés (i18n).
  final ZFlashcardGenerationMessages messages;

  /// Handoff du lot éphémère (AC5). `null` ⇒ le résultat n'est remis nulle part.
  final ZFlashcardGeneratedCallback? onGenerated;

  /// Types proposés à la répartition (défaut : les 6 `ZFlashcardType`).
  final List<ZFlashcardType> generableTypes;

  ZFlashcardGenerationStatus _status = ZFlashcardGenerationStatus.idle;

  /// Statut courant (AD-2).
  ZFlashcardGenerationStatus get status => _status;

  List<ZFlashcard> _cards = const <ZFlashcard>[];

  /// Lot d'aperçu courant (éphémère, `id == null`). Vue non modifiable.
  List<ZFlashcard> get cards => List<ZFlashcard>.unmodifiable(_cards);

  String? _errorMessage;

  /// Message d'échec lisible (issu de `.fold` ou des libellés injectés), ou `null`.
  String? get errorMessage => _errorMessage;

  ZFlashcardGenerationRequest? _lastRequest;

  /// Dernière requête soumise — **préservée** après un échec (l'utilisateur
  /// relance sans re-saisir, AC7).
  ZFlashcardGenerationRequest? get lastRequest => _lastRequest;

  /// Jeton de fraîcheur MONOTONE (AC8). Capturé avant l'`await`, comparé après :
  /// toute réponse dont le jeton ne correspond plus au courant est **écartée**.
  int _generation = 0;

  bool _disposed = false;

  /// Lance une génération (AC7/AC8). Anti-double-tap : ignoré si déjà `generating`.
  Future<void> generate(ZFlashcardGenerationRequest request) async {
    if (_status == ZFlashcardGenerationStatus.generating) {
      return; // anti-double-tap : une seule requête en vol à la fois.
    }
    final token = ++_generation;
    _lastRequest = request; // saisie préservée (AC7).
    _errorMessage = null;
    _setStatus(ZFlashcardGenerationStatus.generating);

    ZResult<List<ZFlashcard>> result;
    try {
      result = await _port.generateFlashcards(request);
    } catch (_) {
      // Le port a LEVÉ (AC7-b) : capté ici, converti en `failed`, aucune
      // exception ne remonte. Réponse périmée ⇒ silencieusement ignorée.
      if (_isStale(token)) return;
      _fail(messages.unexpectedError);
      return;
    }

    if (_isStale(token)) return; // réponse tardive/annulée (AC6/AC8) ⇒ droppée.

    result.fold(
      (failure) => _fail(failure.message), // Left typé rendu lisible (AC7-a).
      (cards) {
        if (cards.isEmpty) {
          _fail(messages.emptyResult); // Right([]) 0 carte (AC7-c).
          return;
        }
        _cards = <ZFlashcard>[
          for (final c in cards) _ephemeral(c, request.provenance),
        ];
        _setStatus(ZFlashcardGenerationStatus.preview);
      },
    );
  }

  /// Passe de l'aperçu à la confirmation de tags (AC9). No-op hors `preview`.
  void proceedToTagConfirmation() {
    if (_status != ZFlashcardGenerationStatus.preview) return;
    _setStatus(ZFlashcardGenerationStatus.confirmingTags);
  }

  /// Retour de la confirmation de tags vers l'aperçu (annulation NON destructive)
  /// — conserve le lot, ne persiste rien (AC9). No-op hors `confirmingTags`.
  void backToPreview() {
    if (_status != ZFlashcardGenerationStatus.confirmingTags) return;
    _setStatus(ZFlashcardGenerationStatus.preview);
  }

  /// Confirme les tags retenus et **remet** le lot éphémère à l'appelant (AC9).
  ///
  /// Applique les `id` des tags confirmés (NON `null`) aux cartes via
  /// `copyWith(tagIds:)` — l'`id` de CHAQUE carte **reste `null`** (AC6). Les tags
  /// créés sans `id` (matérialisés par le repository app-side) voyagent dans
  /// [confirmedTags] du handoff. **Aucune persistance** ici.
  void confirmTags(List<ZFlashcardTag> confirmedTags) {
    if (_status != ZFlashcardGenerationStatus.confirmingTags) return;
    final tagIds = <String>[
      for (final t in confirmedTags)
        if (t.id != null) t.id!,
    ];
    final handed = <ZFlashcard>[
      for (final c in _cards) c.copyWith(tagIds: tagIds), // id reste null.
    ];
    onGenerated?.call(handed, List<ZFlashcardTag>.unmodifiable(confirmedTags));
    // Le handoff EST la frontière de commit AD-43 : aucune écriture base ici.
    _reset();
  }

  /// Annule/abandonne le flux (fermeture de la feuille) : retour à `idle`, sans
  /// throw, sans persistance (AC6/AC8). Bump du jeton ⇒ toute réponse en vol
  /// devient périmée et sera écartée.
  void abandon() {
    _generation++; // invalide toute réponse en vol (AC6 réponse tardive).
    _reset();
  }

  void _reset() {
    _cards = const <ZFlashcard>[];
    _errorMessage = null;
    _setStatus(ZFlashcardGenerationStatus.idle);
  }

  /// Rend une carte **éphémère** : `id == null` FORCÉ et `source` estampillée
  /// **uniquement** depuis [provenance] de la requête (jamais une source backend).
  static ZFlashcard _ephemeral(ZFlashcard card, ZFlashcardSource? provenance) =>
      card.copyWith(id: null, source: provenance);

  void _fail(String message) {
    _errorMessage = message;
    _setStatus(ZFlashcardGenerationStatus.failed);
  }

  bool _isStale(int token) => _disposed || token != _generation;

  void _setStatus(ZFlashcardGenerationStatus status) {
    _status = status;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++; // toute réponse en vol devient périmée (pas de notify post-dispose).
    super.dispose();
  }
}
