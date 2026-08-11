/// `ZSessionModeSelector` — le sélecteur de session.
///
/// ## Il assemble. Il ne calcule rien
///
/// La catégorisation est la fonction pure `zCategorize` (`zcrud_flashcard`,
/// coût constant par carte) ; le streak est la fonction pure
/// `zAdvanceStreak` (kernel). Ce widget produit une file via [onStart] : il
/// ne démarre aucun runtime, ne touche aucun moteur et n'écrit aucun SRS.
///
/// ## Les quatre options
///
/// | Option | Règle | Visibilité |
/// |---|---|---|
/// | « Apprendre +N » | `repetitions == 0`, lot configurable, défaut 30 ; anneau de progression | si > 0 |
/// | « À réviser » | dues (`nextReviewDate <= at`), triées par urgence | si > 0 seulement |
/// | « Test » | ouvre le dialog de filtres | toujours |
/// | « Bachotage » | tout le corpus, ordre d'entrée, aucune lecture SRS | si le corpus > 0 |
///
/// Une option à `0` est absente, jamais grisée.
///
/// ## Le point d'entrée « bachotage » (`ZSessionModeKind.cramming`)
///
/// Ce mode s'appuie sur `zSessionRuntimeForMode`, qui envoie déjà `list` ou
/// `cramming` sur `ZLinearSessionState` (runtime sans aucun seam SRS). Ce
/// widget en est le point d'entrée dans le sélecteur ; il ne change rien au
/// runtime ni au régime d'écriture.
///
/// Aucune lecture SRS pour cette option : le bachotage porte sur le corpus
/// entier, pas sur une catégorie SRS. La file est donc `cards` dans son
/// ordre d'entrée, sans consulter [srsById] — cohérent avec un runtime qui
/// n'écrit aucun SRS.
///
/// Aucun mélange n'est appliqué ici. Ce widget est pur et déterministe : un
/// `Random` dans un `build()` rendrait la file différente à chaque
/// rebuild — donc un ordre qui change sous les doigts de l'apprenant, et un
/// widget intestable. Le mélange, s'il est voulu, est la responsabilité de
/// l'hôte, dans son `onStart` (là où il compose la file avant de démarrer
/// le runtime).
///
/// Widget pur (invariants AD-2/AD-15) : `StatelessWidget`, aucun
/// gestionnaire d'état, aucun controller mutable, callbacks/thème/labels
/// injectés. L'instant [at] est un paramètre (invariant AD-14 :
/// `DateTime.now()` interdit ici).
///
/// A11y/RTL/l10n (invariant AD-13) : `Semantics(label:)` issu de
/// `ZcrudLabels` sur chaque tuile, cibles ≥ 48 dp, variantes
/// directionnelles, couleurs par clé injectée.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart'
    show ZFlashcard, ZRepetitionInfo, ZSessionCategories, zCategorize;
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart' show ZStudyStreak;

import 'z_streak_badge.dart';
import 'z_study_progress_rings.dart';

/// Le type d'option choisie — un enum, jamais un `bool isTest`.
///
/// Non persisté (valeur runtime passée à [ZSessionModeSelector.onStart]) :
/// pas de `@JsonKey(unknownEnumValue:)` requis.
enum ZSessionModeKind {
  /// « Apprendre +N » — cartes jamais apprises.
  learnNew,

  /// « À réviser » — cartes dues, les plus en retard d'abord.
  review,

  /// « Test » — ouvre le dialog de filtres.
  test,

  /// « Bachotage » — parcours du corpus entier avec re-boucle des ratés,
  /// sans aucune écriture SRS (`ZReviewMode.cramming` → `ZLinearSessionState`).
  ///
  /// Ajouté en queue de l'enum, après [test], pour préserver l'ordre des
  /// valeurs existantes : l'ordre d'un enum est un contrat implicite qu'on
  /// ne rompt pas sans raison.
  ///
  /// Ce membre casse volontairement la compilation de tout `switch`
  /// exhaustif sur ce type — c'est délibéré, sur le même principe que
  /// `zSessionRuntimeForMode` : une valeur de plus doit casser la
  /// compilation plutôt que de retomber silencieusement dans le régime du
  /// voisin, potentiellement un régime qui écrit du SRS.
  cramming,
}

/// Sélecteur de session : quatre options et badge flamme.
class ZSessionModeSelector extends StatelessWidget {
  /// Construit le sélecteur.
  ///
  /// - [cards] / [srsById] : corpus + état SRS indexé (lookup en temps constant) ;
  /// - [at] : instant de référence — injecté (invariant AD-14) ;
  /// - [streak] : streak injecté (jamais calculé ici) ;
  /// - [batchSize] : lot « Apprendre +N » — configurable, défaut 30 ;
  /// - [onStart] : reçoit `(ZSessionModeKind, List<ZFlashcard>)`, la file
  ///   produite ;
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

  /// Clés de widget — un test tape ces contrôles (jamais un `find.text` qui
  /// dépendrait de la langue).
  static const ValueKey<String> learnKey = ValueKey<String>('zModeLearnNew');

  /// Clé de l'option « À réviser ».
  static const ValueKey<String> reviewKey = ValueKey<String>('zModeReview');

  /// Clé de l'option « Test ».
  static const ValueKey<String> testKey = ValueKey<String>('zModeTest');

  /// Clé de l'option « Bachotage ».
  static const ValueKey<String> crammingKey =
      ValueKey<String>('zModeCramming');

  /// Corpus de cartes.
  final Iterable<ZFlashcard> cards;

  /// État SRS indexé par `flashcardId` (`zIndexSrsById`) — lookup en temps
  /// constant.
  final Map<String, ZRepetitionInfo> srsById;

  /// Instant de référence — injecté (jamais `DateTime.now()` ici).
  final DateTime at;

  /// Streak affiché par le badge flamme (injecté).
  final ZStudyStreak streak;

  /// Taille du lot « Apprendre +N » (défaut 30).
  final int batchSize;

  /// Callback de démarrage : reçoit le type et la file produite.
  final void Function(ZSessionModeKind kind, List<ZFlashcard> queue) onStart;

  /// Ouvre le dialog de filtres (option « Test »).
  final VoidCallback? onOpenFilters;

  @override
  Widget build(BuildContext context) {
    final theme = ZcrudTheme.of(context);

    // Catégorisation déléguée à la fonction pure du domaine — jamais
    // réimplémentée ici.
    final ZSessionCategories categories =
        zCategorize(cards, srsById: srsById, at: at);

    // Lot « Apprendre +N » : borné par `batchSize` (défaut 30). `batchSize <= 0`
    // donne une file vide, donc l'option disparaît.
    final learnBatch = _batch(categories.neverLearned, batchSize);

    // Bachotage : le corpus entier, ordre d'entrée, sans consulter le SRS
    // (le runtime linéaire n'en écrit aucun). Matérialisé une seule fois :
    // `cards` est une `Iterable`, et la ré-itérer à chaque tap rendrait la
    // file dépendante du moment du geste.
    final List<ZFlashcard> crammingQueue = cards.toList(growable: false);

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

        // « Apprendre +N » — absente si aucune carte à apprendre, jamais
        // grisée.
        if (learnBatch.isNotEmpty) ...<Widget>[
          _ModeTile(
            tileKey: learnKey,
            labelKey: 'zcrud.study.mode.learnNew',
            labelFallback: 'Apprendre',
            countValue: learnBatch.length,
            colorKeyName: 'primary',
            // L'anneau de progression réutilise `ZStudyProgressRings` —
            // jamais un anneau redéclaré. Il est statique (`CustomPaint`) :
            // rien à désactiver sous Reduce Motion, aucune animation factice.
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

        // « À réviser » — visible seulement si > 0, jamais grisée.
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

        // « Test » — toujours présente, même sur un corpus vide. Un tap
        // ouvre le dialog de filtres et invoque `onStart(test, [])` dans le
        // même geste : elle ne produit aucune file (la file naît des
        // filtres que l'hôte composera), mais elle invoque bien `onStart`.
        // Un hôte qui câble `onStart` sur une navigation doit donc s'attendre
        // à recevoir, pour cette option, à la fois l'ouverture du dialog et
        // l'événement de démarrage.
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

        // « Bachotage » — absente sur un corpus vide, jamais grisée. Le gap
        // est porté ici, en tête du bloc conditionnel : « Test » reste la
        // tuile terminale quand le corpus est vide.
        if (crammingQueue.isNotEmpty) ...<Widget>[
          SizedBox(height: theme.gapS),
          _ModeTile(
            tileKey: crammingKey,
            labelKey: 'zcrud.study.mode.cramming',
            labelFallback: 'Bachotage',
            countValue: crammingQueue.length,
            // Rôle neutre : le bachotage n'est ni une échéance (secondary)
            // ni un engagement noté (tertiary) — il ne consomme aucune
            // dette SRS. Les rôles disponibles sont bornés par `ZColorSlot`
            // (primary/secondary/tertiary/error/neutral) ; `error` serait
            // un contresens.
            colorKeyName: 'neutral',
            onTap: () => onStart(ZSessionModeKind.cramming, crammingQueue),
          ),
        ],
      ],
    );
  }

  /// Borne [source] à [size] éléments (`size <= 0` donne une liste vide).
  static List<ZFlashcard> _batch(List<ZFlashcard> source, int size) {
    if (size <= 0) return const <ZFlashcard>[];
    if (source.length <= size) return source;
    return source.sublist(0, size);
  }
}

/// Tuile d'option — le seul patron de tuile du sélecteur.
///
/// Les quatre options traversent ce même widget : il n'existe aucune tuile
/// écrite à part qui pourrait diverger. C'est ce qui rend l'ajout d'une
/// nouvelle option gratuit en a11y/contraste/RTL : la tuile neuve hérite du
/// patron, elle ne le re-décrit pas.
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

    // Libellé issu de `ZcrudLabels` — jamais un littéral.
    final text = label(context, labelKey, fallback: labelFallback);
    final count = countValue;

    return Semantics(
      key: tileKey,
      label: text,
      // Le nombre passe par `value` : jamais concaténé dans le label (le
      // lecteur d'écran annonce « Apprendre, 30 »).
      value: count == null ? null : '$count',
      button: true,
      // Sans exclusion, les `Text` descendants fusionneraient dans ce nœud,
      // faisant annoncer le libellé deux fois et le compte concaténé au
      // label plutôt que porté par `value` seul.
      //
      // Ce que l'exclusion masque, et pourquoi c'est assumé pour la tuile
      // « Apprendre » (la seule à porter un `leading`) : le nœud propre de
      // l'anneau de progression (« progression, 30/60 »). L'anneau est une
      // redite décorative des nombres que la tuile annonce déjà (`correct`
      // = la file = ce `value`) ; seul le total du backlog disparaît du
      // canal a11y — il reste visible à l'œil, et le bilan de session le
      // porte.
      excludeSemantics: true,
      // `excludeSemantics` masque aussi le `onTap` de l'`InkWell` : on le
      // re-déclare, sinon la tuile deviendrait inactionnable au lecteur
      // d'écran.
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          // Cible ≥ 48 dp (invariant AD-13).
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
                    // Interpolation pure (un nombre) : rien à traduire.
                    '$count',
                    // `pair.onColor`, le rôle premier plan lisible sur
                    // `pair.color` — jamais `pair.color` lui-même en premier
                    // plan, qui produirait un contraste insuffisant sur une
                    // tuile qui ne peint aucun fond dédié. Aligné sur le
                    // libellé du même `Row`, qui utilise déjà `pair.onColor`.
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
