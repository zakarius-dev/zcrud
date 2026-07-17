/// `ZTestFiltersDialog` — le dialog de filtres test/examen (SU-6, FR-SU12 —
/// AC10/AC13/AC14/AC15).
///
/// ## Il PILOTE la fonction pure. Il ne filtre rien lui-même
///
/// Le filtrage **est** `zApplyTestFilters` (`zcrud_flashcard`, PURE, AD-33 :
/// sélection AMONT). Ce dialog **compose un `ZFlashcardTestFilters`** et le rend
/// à l'hôte via [Navigator.pop] : aucune règle métier n'est réimplémentée ici —
/// les seaux de maîtrise viennent de `ZMasteryLevel`, jamais d'une liste recopiée.
///
/// **Widget PUR** (AD-2/AD-15) : `StatefulWidget` sans gestionnaire d'état, état
/// **local au dialog** (les cases cochées), aucun moteur, aucune écriture SRS.
///
/// **A11y/RTL/l10n (AD-13)** : `Semantics(label:)` issu de `ZcrudLabels` sur
/// chaque bascule, cibles ≥ 48 dp, variantes directionnelles, aucune couleur en
/// dur. ⚠️ Ces affirmations ne valent que parce qu'un test les **énumère** :
/// le groupe « AC14 — `Semantics` sur TOUTES les tuiles du diff » de
/// `test/presentation/z_session_mode_selector_test.dart` monte **ce dialog** et
/// parcourt `ZMasteryLevel.values`, les sources et les 3 contrôles de comptage,
/// en assertant le libellé à sa **valeur EXACTE** (un `isNotEmpty` ne verrait ni
/// une fusion, ni un littéral en dur).
///
/// ## 🔴 Défaut MESURÉ (code-review su-6, D2) — la double annonce, RÉCIDIVE de su-5/D1
///
/// Mon premier jet posait `Semantics(label:, selected:)` **par-dessus** un
/// `CheckboxListTile` portant `title: Text(text)` : le lecteur d'écran annonçait
/// **« Maîtrisées, sélectionné » puis « Maîtrisées »** — libellé **doublé** sur
/// les 3 seaux ET chaque source, tandis que l'état coché ne vivait **que** sur le
/// nœud parent (l'enfant, celui qui *a l'air* d'être la case, n'exposait
/// **aucun** état : `hasCheckedState=false`).
///
/// C'est **exactement** le MAJEUR D1 de su-5 (« Cartes, 8, Cartes — valeur : 8 »),
/// re-commis dans un diff dont la story **cite** la leçon. La cause racine n'est
/// pas l'oubli : c'est que **rien ne regardait ce fichier** (0 test sur 240
/// lignes publiques).
///
/// Correctif (patron entériné par su-5 et par le cœur — `z_date_field_widget.dart`) :
/// **`excludeSemantics: true`** + **re-déclaration explicite** de tout ce que
/// l'exclusion masque — `checked:` (l'état, `checked` et non `selected` : c'est
/// une case à cocher) et `onTap:` (l'action, sinon un lecteur d'écran ne pourrait
/// plus basculer le filtre). Exclure sans re-déclarer serait **pire** que le
/// défaut.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart'
    show ZFlashcardTestFilters, ZMasteryLevel;

/// Clé l10n du libellé d'un seau de maîtrise — **dérivée de l'enum**, jamais
/// d'une table recopiée (un 4ᵉ seau ajouté demain ne peut pas être oublié).
String zMasteryLabelKey(ZMasteryLevel level) => 'zcrud.study.mastery.${level.name}';

/// Repli lisible d'un seau (utilisé si l'app ne fournit pas la clé).
String zMasteryFallback(ZMasteryLevel level) => switch (level) {
      ZMasteryLevel.bad => 'À revoir',
      ZMasteryLevel.good => 'Acquises',
      ZMasteryLevel.mastered => 'Maîtrisées',
    };

/// Dialog de composition des filtres test/examen.
///
/// Rend un [ZFlashcardTestFilters] via `Navigator.pop`, ou `null` si annulé.
class ZTestFiltersDialog extends StatefulWidget {
  /// Construit le dialog.
  ///
  /// - [initial] : filtres de départ (défaut : `questionCount: 10`, aucun seau
  ///   ⇒ tous) ;
  /// - [availableSources] : `kind` de source proposés (registre **ouvert**
  ///   AD-4) — vide ⇒ la section n'est pas affichée ;
  /// - [minQuestionCount] / [maxQuestionCount] : bornes du réglage du **nombre
  ///   de questions** — **INJECTÉES**, jamais des littéraux enfouis dans le
  ///   `build` (un hôte à gros dossiers voudra plus de 100).
  const ZTestFiltersDialog({
    this.initial = const ZFlashcardTestFilters(),
    this.availableSources = const <String>[],
    this.minQuestionCount = 1,
    this.maxQuestionCount = 100,
    super.key,
  });

  /// Clé du bouton « Valider » — les tests le **tapent** (jamais un `find.text`).
  static const ValueKey<String> confirmKey = ValueKey<String>('zFiltersConfirm');

  /// Clé du bouton « Annuler ».
  static const ValueKey<String> cancelKey = ValueKey<String>('zFiltersCancel');

  /// Clé de l'affichage du nombre de questions (porte `Semantics(value:)`).
  static const ValueKey<String> questionCountKey =
      ValueKey<String>('zFiltersCount');

  /// Clé du bouton « une question de moins ».
  static const ValueKey<String> questionCountDecrementKey =
      ValueKey<String>('zFiltersCountDecrement');

  /// Clé du bouton « une question de plus ».
  static const ValueKey<String> questionCountIncrementKey =
      ValueKey<String>('zFiltersCountIncrement');

  /// Clé de la bascule d'un seau de maîtrise.
  static ValueKey<String> masteryKey(ZMasteryLevel level) =>
      ValueKey<String>('zFiltersMastery_${level.name}');

  /// Clé de la bascule d'un `kind` de source.
  static ValueKey<String> sourceKey(String kind) =>
      ValueKey<String>('zFiltersSource_$kind');

  /// Filtres initiaux.
  final ZFlashcardTestFilters initial;

  /// `kind` de source proposés.
  final List<String> availableSources;

  /// Borne basse du nombre de questions (défaut **1** — `<= 0` ⇒ tirage vide).
  final int minQuestionCount;

  /// Borne haute du nombre de questions (défaut **100**).
  final int maxQuestionCount;

  @override
  State<ZTestFiltersDialog> createState() => _ZTestFiltersDialogState();
}

class _ZTestFiltersDialogState extends State<ZTestFiltersDialog> {
  late Set<ZMasteryLevel> _levels;
  late Set<String> _sources;
  late int _questionCount;

  @override
  void initState() {
    super.initState();
    // État local INITIALISÉ une fois (jamais réinjecté au rebuild — AD-2).
    _levels = <ZMasteryLevel>{...widget.initial.masteryLevels};
    _sources = <String>{...widget.initial.sources};
    // Borné dès l'entrée : un `initial` hors bornes (0, 10 000 — hôte, données
    // corrompues) ne doit ni throw ni piéger le stepper (AD-10).
    _questionCount = _clampCount(widget.initial.questionCount);
  }

  /// Borne un comptage aux bornes INJECTÉES (jamais un littéral ici).
  int _clampCount(int value) {
    final lo = widget.minQuestionCount;
    final hi = widget.maxQuestionCount;
    // Bornes incohérentes (`hi < lo`) ⇒ on ne throw pas : `lo` fait foi (AD-10).
    if (hi < lo) return lo;
    return value < lo ? lo : (value > hi ? hi : value);
  }

  void _setCount(int value) => setState(() => _questionCount = _clampCount(value));

  @override
  Widget build(BuildContext context) {
    final theme = ZcrudTheme.of(context);

    return AlertDialog(
      title: Text(
        label(context, 'zcrud.study.filters.title', fallback: 'Filtres du test'),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // 🔴 Le NOMBRE DE QUESTIONS est RÉGLABLE (FR-SU12 : « nombre de
            // questions (défaut 10, tirage aléatoire si excédent) … + dialog de
            // configuration »).
            //
            // Mon premier jet portait `late int _questionCount` initialisé dans
            // `initState` et relu au `pop` — **jamais réassigné**, sans aucun
            // contrôle de saisie : un champ mutable dont l'unique rôle était le
            // pass-through **donnait l'apparence** de la configurabilité. Le
            // « dialog de configuration » de FR-SU12 ne configurait donc pas ce
            // que FR-SU12 nomme en premier : l'apprenant voulant 20 questions ne
            // pouvait pas les demander, alors que `zDrawQuestions` sait les
            // tirer (prouvé). Le seul chemin d'accès utilisateur manquait —
            // et le fichier n'ayant AUCUN test, rien ne pouvait le voir (D2/D3).
            _QuestionCountStepper(
              value: _questionCount,
              canDecrement: _questionCount > widget.minQuestionCount,
              canIncrement: _questionCount < widget.maxQuestionCount,
              onDecrement: () => _setCount(_questionCount - 1),
              onIncrement: () => _setCount(_questionCount + 1),
            ),
            SizedBox(height: theme.gapM),

            // 🔴 Les seaux ÉNUMÈRENT `ZMasteryLevel.values` — jamais une liste
            // recopiée : un 4ᵉ seau apparaîtrait ici sans toucher ce fichier.
            for (final level in ZMasteryLevel.values)
              _FilterToggle(
                tileKey: ZTestFiltersDialog.masteryKey(level),
                text: label(
                  context,
                  zMasteryLabelKey(level),
                  fallback: zMasteryFallback(level),
                ),
                selected: _levels.contains(level),
                onChanged: (value) => setState(() {
                  // `setState` LOCAL au dialog (quelques cases) — ce n'est PAS
                  // un formulaire d'édition : aucun `TextEditingController`,
                  // aucun champ à focus. AD-2 vise le rebuild global d'un
                  // FORMULAIRE, pas une case à cocher de dialog.
                  if (value) {
                    _levels.add(level);
                  } else {
                    _levels.remove(level);
                  }
                }),
              ),
            if (widget.availableSources.isNotEmpty) ...<Widget>[
              SizedBox(height: theme.gapM),
              for (final source in widget.availableSources)
                _FilterToggle(
                  tileKey: ZTestFiltersDialog.sourceKey(source),
                  // La clé l10n DÉRIVE du `kind` (registre ouvert AD-4) : aucune
                  // enum fermée, aucun libellé en dur. Le repli est le `kind`
                  // lui-même (opaque, non traduisible).
                  text: label(
                    context,
                    'zcrud.study.source.$source',
                    fallback: source,
                  ),
                  selected: _sources.contains(source),
                  onChanged: (value) => setState(() {
                    if (value) {
                      _sources.add(source);
                    } else {
                      _sources.remove(source);
                    }
                  }),
                ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          key: ZTestFiltersDialog.cancelKey,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            // 🔴 Clé NUE `'cancel'` — jamais un namespace `zcrud.action.*`
            // inventé ici (code-review su-6, D6). `_enLabels` porte DÉJÀ
            // `'cancel'`/`'confirm'`, et le patron du dépôt est la clé nue
            // (`z_color_field_widget.dart:478`). Avec `zcrud.action.cancel`, une
            // app anglaise ratait `_enLabels` et retombait sur le fallback
            // FRANÇAIS : « Annuler » au milieu d'une UI en « Cancel ».
            label(context, 'cancel', fallback: 'Annuler'),
          ),
        ),
        TextButton(
          key: ZTestFiltersDialog.confirmKey,
          onPressed: () => Navigator.of(context).pop(
            ZFlashcardTestFilters(
              questionCount: _questionCount,
              masteryLevels: _levels,
              sources: _sources,
            ),
          ),
          child: Text(
            label(context, 'confirm', fallback: 'Valider'),
          ),
        ),
      ],
    );
  }
}

/// Réglage du **nombre de questions** (FR-SU12) — stepper borné.
///
/// **A11y (AD-13)** : la valeur passe par `Semantics(value:)` — jamais seulement
/// par le texte ; les deux boutons portent un libellé **d'action** distinct du
/// libellé du champ (« une question de plus » ≠ « Nombre de questions »), et des
/// cibles ≥ 48 dp. Un bouton **désactivé aux bornes** est annoncé comme tel
/// (`enabled:`), jamais silencieusement inerte.
class _QuestionCountStepper extends StatelessWidget {
  const _QuestionCountStepper({
    required this.value,
    required this.canDecrement,
    required this.canIncrement,
    required this.onDecrement,
    required this.onIncrement,
  });

  final int value;
  final bool canDecrement;
  final bool canIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) {
    final text = label(
      context,
      'zcrud.study.filters.questionCount',
      fallback: 'Nombre de questions',
    );

    return Row(
      children: <Widget>[
        Expanded(
          child: Semantics(
            key: ZTestFiltersDialog.questionCountKey,
            label: text,
            // La VALEUR est le nombre (jamais concaténée au label) — le lecteur
            // d'écran annonce « Nombre de questions, 10 ».
            value: '$value',
            // Le `Text` ci-dessous rend le MÊME contenu : sans exclusion, il
            // serait annoncé une seconde fois (motif su-5/D1).
            excludeSemantics: true,
            child: Text(
              // Interpolation PURE pour le nombre : le SENS est porté par `text`
              // (issu de `ZcrudLabels`), la VALEUR par le nombre.
              '$text : $value',
              textAlign: TextAlign.start,
            ),
          ),
        ),
        _CountAction(
          buttonKey: ZTestFiltersDialog.questionCountDecrementKey,
          icon: Icons.remove,
          labelKey: 'zcrud.study.filters.questionCount.decrement',
          labelFallback: 'Une question de moins',
          onPressed: canDecrement ? onDecrement : null,
        ),
        _CountAction(
          buttonKey: ZTestFiltersDialog.questionCountIncrementKey,
          icon: Icons.add,
          labelKey: 'zcrud.study.filters.questionCount.increment',
          labelFallback: 'Une question de plus',
          onPressed: canIncrement ? onIncrement : null,
        ),
      ],
    );
  }
}

/// Bouton d'incrément/décrément — **le seul patron** (un défaut est un MOTIF).
class _CountAction extends StatelessWidget {
  const _CountAction({
    required this.buttonKey,
    required this.icon,
    required this.labelKey,
    required this.labelFallback,
    required this.onPressed,
  });

  final ValueKey<String> buttonKey;
  final IconData icon;
  final String labelKey;
  final String labelFallback;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: buttonKey,
      label: label(context, labelKey, fallback: labelFallback),
      button: true,
      enabled: onPressed != null,
      // 🔴 `excludeSemantics` MASQUE l'action du bouton Material : on la
      // RE-DÉCLARE ici, sinon le filtre deviendrait inactionnable au lecteur
      // d'écran (une correction a11y qui casse l'a11y serait pire que le défaut).
      excludeSemantics: true,
      onTap: onPressed,
      child: ConstrainedBox(
        // Cible ≥ 48 dp (AD-13/NFR-SU3).
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        child: IconButton(
          onPressed: onPressed,
          // Icône DÉCORATIVE : le `Semantics` parent porte déjà le sens.
          icon: Icon(icon, semanticLabel: null),
        ),
      ),
    );
  }
}

/// Bascule d'un filtre — **LE seul patron** (seaux de maîtrise ET sources).
///
/// 🔴 **Un défaut est un MOTIF** : mon premier jet portait DEUX classes de
/// bascule quasi identiques (`_MasteryToggle`/`_SourceToggle`). Deux copies, ce
/// sont deux endroits où corriger — et su-5 a démontré qu'on n'en corrige qu'un.
/// Les seaux et les sources traversent donc **ce** widget : aucune bascule ne
/// peut diverger de l'autre.
class _FilterToggle extends StatelessWidget {
  const _FilterToggle({
    required this.tileKey,
    required this.text,
    required this.selected,
    required this.onChanged,
  });

  final ValueKey<String> tileKey;

  /// Libellé **déjà résolu** via `ZcrudLabels` par l'appelant.
  final String text;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: tileKey,
      // 🔴 Libellé A11y issu de `ZcrudLabels` (angle mort DÉCLARÉ de la garde de
      // libellés — tenu par l'énumération AC14, qui l'assert à sa valeur EXACTE).
      label: text,
      // 🔴 `checked:`, pas `selected:` — c'est une CASE À COCHER : le lecteur
      // d'écran doit annoncer « cochée / non cochée », jamais la couleur seule
      // (AD-13). C'est aussi l'information que `excludeSemantics` retire au
      // `CheckboxListTile` : elle est donc RE-DÉCLARÉE ici, jamais perdue.
      checked: selected,
      // 🔴 L'ACTION est re-déclarée pour la même raison : sans elle, la bascule
      // serait annoncée mais inactionnable au lecteur d'écran.
      onTap: () => onChanged(!selected),
      // 🔴 Le `title: Text(text)` de la tuile rend le MÊME libellé que ce
      // `Semantics(label:)` : sans exclusion, TalkBack annonce « Maîtrisées,
      // cochée » PUIS « Maîtrisées » (su-5/D1, mesuré à nouveau ici).
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: CheckboxListTile(
          value: selected,
          onChanged: (v) => onChanged(v ?? false),
          title: Text(text, textAlign: TextAlign.start),
          // Directionnel : `ListTileControlAffinity.leading` est RTL-safe
          // (Flutter le résout selon la direction du texte).
          controlAffinity: ListTileControlAffinity.leading,
        ),
      ),
    );
  }
}
