/// Modes offerts par le parcours « **Commencer à apprendre** » (CHAT-8).
///
/// Ce module ne déclare **aucun enum** : `ZReviewMode` (`zcrud_study_kernel`)
/// porte déjà les 6 valeurs. Il déclare la **sélection** — quels modes ce
/// parcours propose, et surtout **lesquels il refuse de porter, et pourquoi**.
///
/// ## Relevé sur disque chez IFFD (la référence de ce lot)
///
/// L'enum d'IFFD est `FlashcardRepetitionPageType`
/// (`folder_flashcards_repetitions_page.dart:30-37`), 6 valeurs. Le sélecteur
/// `FlashcardsLearningModeScreen` (`flashcard_widgets.dart:639`) n'expose que
/// **3 tuiles** :
///
/// | Tuile IFFD | Enum RÉELLEMENT construit | Site | Porté ici vers |
/// |---|---|---|---|
/// | « Apprendre +N flashcards » | `nFlashcardsLearningCycle` | `flashcard_widgets.dart:873` | [ZReviewMode.learn] |
/// | « Flashcards à réviser » | **`test`** | `flashcard_widgets.dart:919` | [ZReviewMode.spaced] |
/// | « Test » | **`whiteExam`** | `flashcard_widgets.dart:1002` | [ZReviewMode.whiteExam] |
///
/// 🔴 **Le libellé et l'enum sont décalés d'un cran chez IFFD** : la tuile « à
/// réviser » construit `.test`, la tuile « Test » construit `.whiteExam`. Porter
/// **par le libellé** échangerait donc deux modes — un bug qui ne se verrait
/// qu'en session. C'est le seul endroit du lot où lire le code au lieu de l'UI
/// change le résultat.
///
/// ## Ce qui n'est PAS porté — et la raison de chacun
///
/// | Mode zcrud | Statut chez IFFD | Décision |
/// |---|---|---|
/// | [ZReviewMode.cramming] | **MORT** : aucun site de construction ; la tuile « Révisez tout le dossier » est **entièrement en commentaire** (`flashcard_widgets.dart:1105-1128`, dont `// FlashcardRepetitionPageType.cramming`) ⇒ `isCramming` vaut toujours `false` | **non porté** |
/// | [ZReviewMode.list] | `listOnly` n'est **pas un mode de session** : c'est la valeur PAR DÉFAUT du paramètre de page (`folder_flashcards_repetitions_page.dart:64`), utilisée par les écrans de liste/édition | **non porté au CTA** |
/// | [ZReviewMode.test] | aucune tuile du CTA ne le construit (cf. le décalage ci-dessus : le `.test` d'IFFD, c'est la révision espacée) | **non porté au CTA** |
///
/// ⚠️ **Nuance mesurée, contre l'énoncé « 3 vifs / 2 morts »** : des 3 valeurs
/// hors CTA, **une seule est réellement morte** (`cramming`).
/// `allFlashcardsLearningCycle` est **vivant par une autre porte** — le chat
/// (`chatbot_conversation_screen.dart:857`, action `"show"` d'un message-
/// flashcards) — simplement inatteignable depuis le pied du dossier ; et
/// `listOnly` est un défaut omniprésent. « Non porté » ≠ « mort » : la
/// distinction est consignée pour qu'une story ultérieure ne « ressuscite » pas
/// par erreur ce qui n'était pas mort.
///
/// ## Aucun libellé ici (FR-26)
///
/// Ce module ne porte **aucune chaîne d'affichage** et **aucune couleur** : les
/// libellés (« Apprendre », « Réviser », « Test ») appartiennent à la l10n de
/// l'hôte. On expose des **valeurs d'enum**, pas des étiquettes.
library;

import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

/// Les **3** modes offerts par « Commencer à apprendre », dans l'ordre des
/// tuiles d'IFFD (apprendre → réviser → test).
///
/// Ordre **déterministe** : c'est l'ordre d'affichage attendu par l'hôte.
const List<ZReviewMode> kZChatStudyLaunchModes = <ZReviewMode>[
  ZReviewMode.learn,
  ZReviewMode.spaced,
  ZReviewMode.whiteExam,
];

/// Les modes **délibérément absents** du parcours (cf. le tableau de l'en-tête).
///
/// Exposé — et pas seulement commenté — pour qu'une garde de machine puisse
/// vérifier la partition (`kZChatStudyLaunchModes ⊎ kZChatStudyModesNotLaunched
/// == ZReviewMode.values`) : ajouter une valeur à `ZReviewMode` sans la classer
/// fera **rougir** le test au lieu de la laisser filer.
const Set<ZReviewMode> kZChatStudyModesNotLaunched = <ZReviewMode>{
  ZReviewMode.cramming,
  ZReviewMode.list,
  ZReviewMode.test,
};

/// `true` si [mode] est proposé par le parcours « Commencer à apprendre ».
bool zIsChatStudyLaunchMode(ZReviewMode mode) =>
    kZChatStudyLaunchModes.contains(mode);
