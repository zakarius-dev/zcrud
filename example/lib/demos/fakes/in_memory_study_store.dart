import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_session/zcrud_session.dart';

/// **Store d'étude EN MÉMOIRE** (adaptateur fake app-side, AD-15/AC3).
///
/// ## Migration
///
/// L'app réelle (IFFD / lex_douane) branche ICI son `ZFlashcardRepository`
/// offline-first (Hive + Firestore, E5/E9-4) : le corpus de cartes vient de
/// `ZStudyRepository.watchAll` et l'état SRS de `ZRepetitionStore`. La **voie
/// d'écriture SRS UNIQUE** (`reviewCard`) est remplacée par
/// `ZFlashcardRepository.reviewCard`. Ici, tout est déterministe et en mémoire :
/// aucune I/O, aucune horloge non injectée (AD-14), aucun secret.
///
/// - [cardsById] : corpus indexé par `flashcardId` — c'est la **carte du couple
///   « deux listes parallèles »** (l'autre étant la `List<ZSessionItem>` de la
///   file, su-7). L'hôte résout **toujours par `flashcardId`**, jamais par index.
/// - [srsById] : état SRS indexé par `flashcardId` (`Map<String,
///   ZRepetitionInfo>`) — SÉPARÉ de la carte (invariant SRS top-level).
/// - [review] : le **seam d'écriture SRS** (`ZSessionReviewer`), signature
///   **exacte** de `ZFlashcardRepository.reviewCard`. C'est la SEULE mutation de
///   l'état SRS de ce store.
class InMemoryStudyStore {
  /// Construit un store à partir d'un corpus déjà indexé + état SRS initial.
  InMemoryStudyStore({
    required Map<String, ZFlashcard> cardsById,
    Map<String, ZRepetitionInfo>? srsById,
    ZSrsConfig config = const ZSrsConfig(),
    this.reviewFailure,
  })  : cardsById = Map<String, ZFlashcard>.of(cardsById),
        srsById = Map<String, ZRepetitionInfo>.of(
          srsById ?? const <String, ZRepetitionInfo>{},
        ),
        _scheduler = ZSm2Scheduler(config: config);

  /// Corpus indexé par `flashcardId` (source de résolution identité — su-7).
  final Map<String, ZFlashcard> cardsById;

  /// État SRS indexé par `flashcardId` (SÉPARÉ de la carte, voie d'écriture
  /// unique [review]).
  final Map<String, ZRepetitionInfo> srsById;

  /// Si non nul, [review] échoue (`Left`) de façon déterministe — pour prouver
  /// que la saisie n'est **pas perdue** et que l'échec est **typé** (AD-10).
  final ZFailure? reviewFailure;

  final ZSm2Scheduler _scheduler;

  /// Nombre d'écritures SRS **réussies** (témoin positif pour les tests — un
  /// « 0 écriture » resterait vert sans ce compteur).
  int srsWrites = 0;

  /// Corpus sous forme de liste (ordre d'insertion — déterministe).
  List<ZFlashcard> get cards => cardsById.values.toList(growable: false);

  /// État SRS **indexé** attendu par `ZSessionModeSelector` (lookup O(1)).
  Map<String, ZRepetitionInfo> get srsIndex =>
      Map<String, ZRepetitionInfo>.unmodifiable(srsById);

  /// **Seam d'écriture SRS** ([ZSessionReviewer]) — signature **exacte** de
  /// `ZFlashcardRepository.reviewCard` (voie d'écriture UNIQUE, AD-9). Calcule
  /// l'état SRS suivant via `ZSm2Scheduler.apply` (formule SM-2 réelle,
  /// déterministe : `now` INJECTÉ, AD-14) et le persiste en mémoire.
  ///
  /// Échec **typé** si [reviewFailure] est configuré (`Left`) — jamais une
  /// exception (AD-10) : l'hôte conserve la saisie et signale l'échec.
  Future<ZResult<ZRepetitionInfo>> review({
    required String flashcardId,
    required String folderId,
    required int quality,
    DateTime? now,
  }) async {
    final failure = reviewFailure;
    if (failure != null) {
      return Left<ZFailure, ZRepetitionInfo>(failure);
    }
    final current = srsById[flashcardId] ??
        _scheduler.initial(flashcardId: flashcardId, folderId: folderId);
    final next = _scheduler.apply(current, quality, now: now);
    srsById[flashcardId] = next;
    srsWrites += 1;
    return Right<ZFailure, ZRepetitionInfo>(next);
  }

  /// Jeu de démonstration : **6 cartes**, un mélange de TOUS les types, dont au
  /// moins une carte à **contenu markdown/formule** — pour exercer le CHEMIN
  /// RÉEL (leçon su-2 : 9 taps verts sur une fonctionnalité MORTE sous markdown).
  factory InMemoryStudyStore.demo({
    ZSrsConfig config = const ZSrsConfig(),
    ZFailure? reviewFailure,
  }) {
    const folder = 'demoStudyFolder';
    final cards = <ZFlashcard>[
      // Rédigée (openQuestion) à contenu MARKDOWN + FORMULE (chemin réel su-2).
      const ZFlashcard(
        id: 'f_written_md',
        folderId: folder,
        type: ZFlashcardType.openQuestion,
        question: '**Droits de douane** — donnez la formule de la valeur en '
            r'douane : $V = P + F + A$ (prix + fret + assurance).',
        answer: 'V = P + F + A',
        explanation: 'La valeur transactionnelle est le prix effectivement '
            'payé, ajusté du fret et de l\'assurance (Accord de l\'OMC).',
        hint: 'Trois termes additifs.',
      ),
      // QCM (évalué LOCALEMENT — le port d'évaluation n'est JAMAIS appelé, AD-35).
      const ZFlashcard(
        id: 'f_mcq',
        folderId: folder,
        type: ZFlashcardType.multipleChoice,
        question: 'Quel régime suspend les droits à l\'importation ?',
        choices: <ZChoice>[
          ZChoice(content: 'Mise à la consommation', isCorrect: false),
          ZChoice(content: 'Transit', isCorrect: true),
          ZChoice(content: 'Réexportation directe', isCorrect: false),
        ],
      ),
      // Vrai/Faux (évalué LOCALEMENT, AD-35).
      const ZFlashcard(
        id: 'f_tf',
        folderId: folder,
        type: ZFlashcardType.trueOrFalse,
        question: 'Le BESC est exigé à l\'exportation depuis le Togo.',
        isTrue: false,
      ),
      // Rédigée simple (voie du port d'évaluation advisory).
      const ZFlashcard(
        id: 'f_written_plain',
        folderId: folder,
        type: ZFlashcardType.openQuestion,
        question: 'Que signifie l\'acronyme SH (nomenclature) ?',
        answer: 'Système Harmonisé',
        hint: 'Système…',
      ),
      // Texte à trous.
      const ZFlashcard(
        id: 'f_blank',
        folderId: folder,
        type: ZFlashcardType.fillBlank,
        question: 'La ___ tarifaire détermine le taux de droit applicable.',
        answer: 'position',
      ),
      // Réponse courte à contenu markdown (2ᵉ carte markdown).
      const ZFlashcard(
        id: 'f_short_md',
        folderId: folder,
        type: ZFlashcardType.shortAnswer,
        question: 'Citez _un_ instrument de l\'**évaluation** en douane.',
        answer: 'Valeur transactionnelle',
      ),
    ];
    return InMemoryStudyStore(
      cardsById: <String, ZFlashcard>{
        for (final c in cards) c.id!: c,
      },
      config: config,
      reviewFailure: reviewFailure,
    );
  }
}
