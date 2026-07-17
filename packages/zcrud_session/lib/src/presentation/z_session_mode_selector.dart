/// `ZSessionModeSelector` — le sélecteur de session (SU-6, FR-SU10 —
/// AC6/AC7/AC13/AC14/AC15).
///
/// ## Il ASSEMBLE. Il ne calcule rien (AD-33 : sélection AMONT, runtime AVAL)
///
/// La catégorisation est la **fonction PURE** `zCategorize` (`zcrud_flashcard`,
/// **O(1) par carte** — mesuré par `z_session_categorization_test.dart`) ; le
/// streak est la **fonction PURE** `zAdvanceStreak` (kernel). Ce widget
/// **produit une file** via [onStart] : il ne démarre **aucun** runtime, ne
/// touche **aucun** moteur (AD-34/D7) et n'écrit **aucun** SRS (AD-33 — gardé par
/// `z_widgets_purity_test.dart`).
///
/// ## Les 3 options (FR-SU10)
///
/// | Option | Règle | Visibilité |
/// |---|---|---|
/// | « Apprendre +N » | `repetitions == 0`, lot **configurable, défaut 30** ; anneau de progression | si > 0 |
/// | « À réviser » | dues (`nextReviewDate <= at`), triées par **urgence** | **si > 0 seulement** |
/// | « Test » | ouvre le dialog de filtres | **toujours** |
///
/// **Patron AD-45** : une option à `0` est **ABSENTE**, jamais grisée.
///
/// **Widget PUR** (AD-2/AD-15) : `StatelessWidget`, aucun gestionnaire d'état,
/// controllers inexistants (rien de mutable), callbacks/thème/labels **INJECTÉS**.
/// L'instant [at] est un **PARAMÈTRE** (AD-14 : `DateTime.now()` interdit ici).
///
/// **A11y/RTL/l10n (AD-13, NFR-SU3/4/5)** : `Semantics(label:)` issu de
/// `ZcrudLabels` sur **CHAQUE** tuile (⚠️ angle mort connu : la garde de libellés
/// ne voit pas `Semantics(label:)` — un test dédié **énumère** les tuiles),
/// cibles ≥ 48 dp, variantes directionnelles, couleurs par clé injectée.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart'
    show ZFlashcard, ZRepetitionInfo, ZSessionCategories, zCategorize;
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart' show ZStudyStreak;

import 'z_streak_badge.dart';
import 'z_study_progress_rings.dart';

/// Le type d'option choisie — **enum**, jamais un `bool isTest` (AC15).
///
/// **NON persisté** (valeur runtime passée à [ZSessionModeSelector.onStart]) ⇒
/// pas de `@JsonKey(unknownEnumValue:)` — consigné.
enum ZSessionModeKind {
  /// « Apprendre +N » — cartes jamais apprises.
  learnNew,

  /// « À réviser » — cartes dues, les plus en retard d'abord.
  review,

  /// « Test » — ouvre le dialog de filtres.
  test,
}

/// Sélecteur de session : 3 options + badge flamme (FR-SU10).
class ZSessionModeSelector extends StatelessWidget {
  /// Construit le sélecteur.
  ///
  /// - [cards] / [srsById] : corpus + état SRS **indexé** (lookup O(1)) ;
  /// - [at] : instant de référence — **INJECTÉ** (AD-14) ;
  /// - [streak] : streak **INJECTÉ** (jamais calculé ici) ;
  /// - [batchSize] : lot « Apprendre +N » — **configurable, défaut 30** ;
  /// - [onStart] : reçoit `(ZSessionModeKind, List<ZFlashcard>)` — **la file
  ///   produite** ;
  /// - [onOpenFilters] : ouvre le dialog de filtres (option « Test »).
  const ZSessionModeSelector({
    required this.cards,
    required this.srsById,
    required this.at,
    required this.streak,
    required this.onStart,
    this.batchSize = 30,
    this.onOpenFilters,
    super.key,
  });

  /// Clés de widget — les tests **tapent** ces contrôles (jamais un `find.text`
  /// qui dépendrait de la langue).
  static const ValueKey<String> learnKey = ValueKey<String>('zModeLearnNew');

  /// Clé de l'option « À réviser ».
  static const ValueKey<String> reviewKey = ValueKey<String>('zModeReview');

  /// Clé de l'option « Test ».
  static const ValueKey<String> testKey = ValueKey<String>('zModeTest');

  /// Corpus de cartes.
  final Iterable<ZFlashcard> cards;

  /// État SRS **indexé** par `flashcardId` (`zIndexSrsById`) — lookup O(1).
  final Map<String, ZRepetitionInfo> srsById;

  /// Instant de référence — **INJECTÉ** (jamais `DateTime.now()` ici).
  final DateTime at;

  /// Streak affiché par le badge flamme (INJECTÉ).
  final ZStudyStreak streak;

  /// Taille du lot « Apprendre +N » (défaut **30** — FR-SU10).
  final int batchSize;

  /// Callback de démarrage : reçoit le **type** et la **file** produite.
  final void Function(ZSessionModeKind kind, List<ZFlashcard> queue) onStart;

  /// Ouvre le dialog de filtres (option « Test »).
  final VoidCallback? onOpenFilters;

  @override
  Widget build(BuildContext context) {
    final theme = ZcrudTheme.of(context);

    // 🔴 Catégorisation DÉLÉGUÉE à la fonction PURE du domaine (O(1)/carte) —
    // jamais réimplémentée ici.
    final ZSessionCategories categories =
        zCategorize(cards, srsById: srsById, at: at);

    // Lot « Apprendre +N » : borné par `batchSize` (défaut 30). `batchSize <= 0`
    // ⇒ file vide (l'option disparaît) — cohérent avec `count <= 0 ⇒ vide`.
    final learnBatch = _batch(categories.neverLearned, batchSize);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Align(
          // Directionnel (RTL) — jamais `Alignment.centerRight`.
          alignment: AlignmentDirectional.centerEnd,
          child: ZStreakBadge(streak: streak),
        ),
        SizedBox(height: theme.gapM),

        // « Apprendre +N » — ABSENTE si aucune carte à apprendre (AD-45 : jamais
        // grisée).
        if (learnBatch.isNotEmpty) ...<Widget>[
          _ModeTile(
            tileKey: learnKey,
            labelKey: 'zcrud.study.mode.learnNew',
            labelFallback: 'Apprendre',
            countValue: learnBatch.length,
            colorKeyName: 'primary',
            // L'anneau de progression RÉUTILISE le seam existant
            // (`ZStudyProgressRings`, ES-4.5) — jamais un anneau redéclaré.
            // Il est STATIQUE (CustomPaint) : rien à désactiver sous Reduce
            // Motion, et aucune animation factice ajoutée (leçon su-3).
            leading: ZStudyProgressRings(
              data: ZProgressRingsData(
                total: categories.neverLearned.length,
                correct: learnBatch.length,
                ratio: categories.neverLearned.isEmpty
                    ? 0
                    : (learnBatch.length / categories.neverLearned.length)
                        .clamp(0.0, 1.0)
                        .toDouble(),
              ),
              diameter: 48,
              strokeWidth: 5,
            ),
            onTap: () => onStart(ZSessionModeKind.learnNew, learnBatch),
          ),
          SizedBox(height: theme.gapS),
        ],

        // « À réviser » — VISIBLE SEULEMENT si > 0 (AC7/AC13 : jamais grisée).
        if (categories.due.isNotEmpty) ...<Widget>[
          _ModeTile(
            tileKey: reviewKey,
            labelKey: 'zcrud.study.mode.review',
            labelFallback: 'À réviser',
            countValue: categories.due.length,
            colorKeyName: 'secondary',
            onTap: () => onStart(ZSessionModeKind.review, categories.due),
          ),
          SizedBox(height: theme.gapS),
        ],

        // « Test » — TOUJOURS présente, même sur un dossier vide (patron AD-45).
        //
        // ⚠️ Ce commentaire disait « elle ne démarre rien » DEUX LIGNES au-dessus
        // d'un `onStart(...)` (code-review su-6, LOW-4). Le comportement est
        // correct et verrouillé par test — c'est la PROSE qui était ambiguë : un
        // hôte qui câble `onStart` sur « naviguer vers l'écran de session »
        // recevrait, à chaque tap, une ouverture de dialog **ET** un événement de
        // démarrage. Formulation exacte : elle ne produit **AUCUNE FILE** —
        // l'hôte reçoit `onStart(test, [])` (la file naît des filtres qu'il
        // composera) **et** l'ouverture du dialog.
        _ModeTile(
          tileKey: testKey,
          labelKey: 'zcrud.study.mode.test',
          labelFallback: 'Test',
          colorKeyName: 'tertiary',
          onTap: () {
            onOpenFilters?.call();
            onStart(ZSessionModeKind.test, const <ZFlashcard>[]);
          },
        ),
      ],
    );
  }

  /// Borne [source] à [size] éléments (`size <= 0` ⇒ vide).
  static List<ZFlashcard> _batch(List<ZFlashcard> source, int size) {
    if (size <= 0) return const <ZFlashcard>[];
    if (source.length <= size) return source;
    return source.sublist(0, size);
  }
}

/// Tuile d'option — **le SEUL patron de tuile** du sélecteur.
///
/// 🔴 **Un défaut est un MOTIF** (leçon su-5 : `Semantics`+`Text` corrigé sur une
/// tuile, **3 autres laissées cassées**). Les 3 options traversent donc **CE**
/// widget : il n'existe **aucune** tuile écrite à part qui pourrait diverger.
/// Le test A11y **énumère** les 3 tuiles — jamais une seule.
class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.tileKey,
    required this.labelKey,
    required this.labelFallback,
    required this.colorKeyName,
    required this.onTap,
    this.countValue,
    this.leading,
  });

  final ValueKey<String> tileKey;
  final String labelKey;
  final String labelFallback;
  final String colorKeyName;
  final VoidCallback onTap;
  final int? countValue;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    final pair = zResolveColorKeyOrSlot(context, colorKeyName, slotIndex: 0);

    // 🔴 Libellé issu de `ZcrudLabels` — jamais un littéral (NFR-SU4).
    final text = label(context, labelKey, fallback: labelFallback);
    final count = countValue;

    return Semantics(
      key: tileKey,
      // 🔴 `Semantics(label:)` issu de `ZcrudLabels` — l'angle mort de la garde
      // de libellés, tenu par l'énumération AC14 de
      // `z_session_mode_selector_test.dart` (à la valeur EXACTE : `isNotEmpty`
      // ne voyait ni un littéral en dur, ni une fusion).
      label: text,
      // Le NOMBRE passe par `value` : jamais concaténé dans le label (le lecteur
      // d'écran annonce « Apprendre, 30 »).
      value: count == null ? null : '$count',
      button: true,
      // 🔴 Défaut MESURÉ (code-review su-6, D2 — balayage du MOTIF).
      //
      // Sans exclusion, les `Text` descendants **fusionnaient** dans ce nœud.
      // Arbre sémantique RÉEL, sondé :
      //   zModeReview -> label = « L10N_REVIEW⏎L10N_REVIEW⏎1 »
      //   zModeTest   -> label = « L10N_TEST⏎L10N_TEST »
      // ⇒ TalkBack annonçait « À réviser, À réviser, 12 — valeur : 12 » : le
      // libellé DOUBLÉ **et le compte CONCATÉNÉ AU LABEL** — c'est-à-dire
      // exactement ce que le commentaire ci-dessus déclarait impossible. Une
      // prose qui dit le contraire du code, sur le puits que la garde ne voit
      // pas. C'est le MAJEUR su-5/D1, re-commis.
      //
      // ⚠️ La tuile « Apprendre » (la seule à porter un `leading`) avait, elle,
      // un nœud PARENT propre — la duplication s'était déplacée dans son nœud
      // ENFANT (« progression, 1/1, L10N_LEARN, 1 »). Une sonde qui ne lit que
      // le parent de CETTE tuile conclut « le sélecteur est sain ». Il ne
      // l'était pas.
      //
      // Ce que l'exclusion MASQUE, et pourquoi c'est assumé : le nœud propre de
      // l'anneau (« progression, 30/60 »). L'anneau est une **redite décorative**
      // des nombres que la tuile annonce déjà (`correct` = la file = ce `value`) ;
      // seul le TOTAL du backlog disparaît du canal a11y — il n'est pas dans le
      // contrat d'AC7 (« Apprendre +N » annonce N), il reste visible à l'œil, et
      // le bilan de session le porte. En contrepartie, le nœud cesse d'être le
      // charabia mesuré ci-dessus.
      excludeSemantics: true,
      // 🔴 `excludeSemantics` masque aussi le `onTap` de l'`InkWell` : on le
      // RE-DÉCLARE, sinon la tuile deviendrait inactionnable au lecteur d'écran
      // (une correction a11y qui casse l'a11y serait pire que le défaut).
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          // Cible ≥ 48 dp (AD-13/NFR-SU3).
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            // Directionnel (RTL).
            padding: EdgeInsetsDirectional.all(theme.gapM),
            child: Row(
              children: <Widget>[
                if (leading != null) ...<Widget>[
                  leading!,
                  SizedBox(width: theme.gapM),
                ],
                Expanded(
                  child: Text(
                    text,
                    // Directionnel — jamais `TextAlign.left`.
                    textAlign: TextAlign.start,
                    style: TextStyle(color: pair.onColor),
                  ),
                ),
                if (count != null)
                  Text(
                    // Interpolation PURE (un nombre) : rien à traduire.
                    '$count',
                    // 🔴 Contraste MESURÉ (code-review su-6, ÉCART-2 — le MÊME
                    // défaut que `ZStreakBadge`, ici aussi).
                    //
                    // Ce compte portait `pair.color` — le rôle de **FOND** de la
                    // paire — en PREMIER PLAN, sur une tuile qui ne peint AUCUN
                    // fond : `primaryContainer` sur `surface`, ratio RÉEL
                    // **1,23:1** contre les **4,5:1** de WCAG AA. Le « +N » de la
                    // tuile « Apprendre » — le nombre même qu'AC7 exige
                    // d'afficher — était donc illisible, à deux lignes d'un
                    // libellé qui, lui, utilisait déjà `pair.onColor` (8,87:1)
                    // dans le MÊME `Row`. Un défaut est un MOTIF : corriger le
                    // badge et laisser CETTE tuile à 1,23:1, c'est exactement la
                    // leçon su-5 (« une tuile corrigée, 3 laissées cassées »)
                    // re-commise. Aligné sur son propre libellé — aucun
                    // changement de mise en page.
                    style: TextStyle(color: pair.onColor),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
