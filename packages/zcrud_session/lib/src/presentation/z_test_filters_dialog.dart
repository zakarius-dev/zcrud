/// `ZTestFiltersDialog` — le dialog de filtres test/examen.
///
/// ## Il pilote la fonction pure. Il ne filtre rien lui-même
///
/// Le filtrage est `zApplyTestFilters` (`zcrud_flashcard`, fonction pure,
/// sélection en amont). Ce dialog compose un `ZFlashcardTestFilters` et le
/// rend à l'hôte via [Navigator.pop] : aucune règle métier n'est
/// réimplémentée ici — les seaux de maîtrise viennent de `ZMasteryLevel`,
/// jamais d'une liste recopiée.
///
/// ## Les critères rendus, et ceux qui n'y sont pas
///
/// Ce dialog compose les quatre critères que porte `ZFlashcardTestFilters` :
/// nombre de questions, seaux de maîtrise, `kind` de provenance
/// (`availableSources`) et provenance par identifiant
/// (`availableSourceIds`). Les deux dernières sections ne sont rendues que
/// si l'hôte propose des candidats — sans candidats, l'arbre ne porte que le
/// stepper et les seaux.
///
/// Dossier, **tags** et **types de question** n'y figurent pas, et c'est
/// délibéré : ils appartiennent à `ZStudySessionConfig`, appliqué par
/// `ZStudySessionSelector` en amont du tirage. Les porter aussi ici créerait
/// deux sources du même filtre, avec une question sans réponse (« lequel
/// gagne ? »). Un hôte qui veut les faire régler à l'utilisateur compose sa
/// propre surface pour la config de session, en frère de ce dialog.
///
/// Un critère absent des sections rendues n'est pas pour autant perdu : ce
/// dialog restitue [ZTestFiltersDialog.initial] verbatim pour tout ce qu'il
/// ne fait pas régler.
///
/// Widget pur (invariants AD-2/AD-15) : `StatefulWidget` sans gestionnaire
/// d'état, état local au dialog (les cases cochées), aucun moteur, aucune
/// écriture SRS.
///
/// A11y/RTL/l10n (invariant AD-13) : `Semantics(label:)` issu de
/// `ZcrudLabels` sur chaque bascule, cibles ≥ 48 dp, variantes
/// directionnelles, aucune couleur en dur.
///
/// ## Chaque case cochée re-déclare son état et son action
///
/// Chaque bascule pose `Semantics(label:, checked:)` par-dessus un
/// `CheckboxListTile` qui porte le même libellé en `title: Text(text)`.
/// Sans `excludeSemantics: true`, le libellé serait annoncé deux fois par le
/// lecteur d'écran (une fois par le nœud `Semantics` parent, une fois par le
/// `Text` enfant), tandis que l'état coché ne serait exposé que sur le nœud
/// parent. Le correctif (même patron que le cœur, `z_date_field_widget.dart`) :
/// `excludeSemantics: true`, puis re-déclaration explicite de tout ce que
/// l'exclusion masque — `checked:` (et non `selected:` : c'est une case à
/// cocher) et `onTap:` (l'action, sinon un lecteur d'écran ne pourrait plus
/// basculer le filtre). Exclure sans re-déclarer serait pire que ne pas
/// exclure du tout.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart'
    show ZFlashcardTestFilters, ZMasteryLevel;

/// Clé l10n du libellé d'un seau de maîtrise — dérivée de l'enum, jamais
/// d'une table recopiée (un quatrième seau ajouté demain ne peut pas être
/// oublié).
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
  /// - [initial] : filtres de départ (défaut : `questionCount: 10`, aucun
  ///   seau, donc tous) ;
  /// - [availableSources] : `kind` de source proposés (registre ouvert,
  ///   invariant AD-4) — vide, la section n'est pas affichée ;
  /// - [availableSourceIds] : identifiants de provenance proposés (`noteId`,
  ///   `documentId`, `messageId`…) — vide, la section n'est pas affichée ;
  /// - [minQuestionCount] / [maxQuestionCount] : bornes du réglage du nombre
  ///   de questions — injectées, jamais des littéraux enfouis dans le
  ///   `build` (un hôte à gros dossiers voudra plus de 100).
  const ZTestFiltersDialog({
    this.initial = const ZFlashcardTestFilters(),
    this.availableSources = const <String>[],
    this.availableSourceIds = const <String>[],
    this.minQuestionCount = 1,
    this.maxQuestionCount = 100,
    super.key,
  });

  /// Clé du bouton « Valider » — un test le cible ainsi, jamais par son texte.
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

  /// Clé de la bascule d'un identifiant de provenance.
  static ValueKey<String> sourceIdKey(String id) =>
      ValueKey<String>('zFiltersSourceId_$id');

  /// Filtres initiaux.
  final ZFlashcardTestFilters initial;

  /// `kind` de source proposés.
  final List<String> availableSources;

  /// Identifiants de provenance proposés — vide, aucune section n'est rendue.
  ///
  /// Ce sont les identifiants canoniques du contenu d'origine (`noteId` pour
  /// une note, `documentId` pour un document, `messageId` pour une
  /// conversation), tels que `ZFlashcardTestFilters.sourceIds` les attend.
  /// Ils se composent en ET avec [availableSources] : cocher le `kind`
  /// « note » **et** deux identifiants ne retient que ces deux notes.
  ///
  /// Le libellé rendu est résolu par
  /// `label(context, 'zcrud.study.sourceId.' + id)`, avec l'identifiant
  /// lui-même en repli. Un
  /// identifiant opaque n'étant pas lisible, un hôte qui veut des titres les
  /// fournit par `ZcrudScope(labels:)` — ce dialog n'invente aucun libellé.
  final List<String> availableSourceIds;

  /// Borne basse du nombre de questions (défaut 1 — `<= 0` donnerait un
  /// tirage vide).
  final int minQuestionCount;

  /// Borne haute du nombre de questions (défaut 100).
  final int maxQuestionCount;

  @override
  State<ZTestFiltersDialog> createState() => _ZTestFiltersDialogState();
}

class _ZTestFiltersDialogState extends State<ZTestFiltersDialog> {
  late Set<ZMasteryLevel> _levels;
  late Set<String> _sources;
  late Set<String> _sourceIds;
  late int _questionCount;

  @override
  void initState() {
    super.initState();
    // État local initialisé une fois (jamais réinjecté au rebuild, invariant
    // AD-2).
    _levels = <ZMasteryLevel>{...widget.initial.masteryLevels};
    _sources = <String>{...widget.initial.sources};
    // Repris de `initial`, comme les autres critères : sans cette reprise ET
    // sans la restitution au `pop`, un `initial.sourceIds` non vide serait
    // silencieusement effacé par un simple aller-retour dans le dialog.
    _sourceIds = <String>{...widget.initial.sourceIds};
    // Borné dès l'entrée : un `initial` hors bornes (données d'hôte
    // corrompues) ne doit ni lever, ni piéger le stepper (invariant AD-10).
    _questionCount = _clampCount(widget.initial.questionCount);
  }

  /// Borne un comptage aux bornes injectées (jamais un littéral ici).
  int _clampCount(int value) {
    final lo = widget.minQuestionCount;
    final hi = widget.maxQuestionCount;
    // Bornes incohérentes (`hi < lo`) : on ne lève pas, `lo` fait foi.
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
            // Le nombre de questions est réglable dans ce dialog (défaut 10,
            // tirage aléatoire si excédent).
            _QuestionCountStepper(
              value: _questionCount,
              canDecrement: _questionCount > widget.minQuestionCount,
              canIncrement: _questionCount < widget.maxQuestionCount,
              onDecrement: () => _setCount(_questionCount - 1),
              onIncrement: () => _setCount(_questionCount + 1),
            ),
            SizedBox(height: theme.gapM),

            // Les seaux énumèrent `ZMasteryLevel.values` — jamais une liste
            // recopiée : un quatrième seau apparaîtrait ici sans toucher ce
            // fichier.
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
                  // `setState` local au dialog (quelques cases) — ce n'est pas
                  // un formulaire d'édition : aucun `TextEditingController`,
                  // aucun champ à focus. L'invariant AD-2 vise le rebuild
                  // global d'un formulaire, pas une case à cocher de dialog.
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
                  // La clé l10n dérive du `kind` (registre ouvert, invariant
                  // AD-4) : aucune enum fermée, aucun libellé en dur. Le
                  // repli est le `kind` lui-même (opaque, non traduisible).
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
            // Provenance PAR IDENTIFIANT — section rendue seulement si l'hôte
            // propose des candidats. Sans candidats, l'arbre est identique à
            // celui d'avant l'existence de ce paramètre.
            if (widget.availableSourceIds.isNotEmpty) ...<Widget>[
              SizedBox(height: theme.gapM),
              for (final id in widget.availableSourceIds)
                _FilterToggle(
                  tileKey: ZTestFiltersDialog.sourceIdKey(id),
                  // Un identifiant est opaque : le repli est l'identifiant
                  // lui-même, jamais un libellé inventé ici.
                  text: label(
                    context,
                    'zcrud.study.sourceId.$id',
                    fallback: id,
                  ),
                  selected: _sourceIds.contains(id),
                  onChanged: (value) => setState(() {
                    if (value) {
                      _sourceIds.add(id);
                    } else {
                      _sourceIds.remove(id);
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
            // Clé nue `'cancel'`, jamais un namespace `zcrud.action.*`
            // inventé ici : la table du cœur porte déjà `'cancel'`/`'confirm'`,
            // et c'est le patron attendu du dépôt. Avec un namespace inventé,
            // une application anglaise raterait la table du cœur et
            // retomberait sur le fallback français.
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
              // Restitué même quand aucune section n'est rendue : ce dialog
              // COMPOSE les filtres, il n'a jamais eu vocation à en effacer un
              // que l'hôte lui avait confié dans `initial`.
              sourceIds: _sourceIds,
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

/// Réglage du nombre de questions — stepper borné.
///
/// A11y (invariant AD-13) : la valeur passe par `Semantics(value:)`, jamais
/// seulement par le texte ; les deux boutons portent un libellé d'action
/// distinct du libellé du champ (« une question de plus » ≠ « Nombre de
/// questions »), et des cibles ≥ 48 dp. Un bouton désactivé aux bornes est
/// annoncé comme tel (`enabled:`), jamais silencieusement inerte.
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
            // La valeur est le nombre (jamais concaténée au label) — le lecteur
            // d'écran annonce « Nombre de questions, 10 ».
            value: '$value',
            // Le `Text` ci-dessous rend le même contenu : sans exclusion, il
            // serait annoncé une seconde fois.
            excludeSemantics: true,
            child: Text(
              // Interpolation pure pour le nombre : le sens est porté par
              // `text` (issu de `ZcrudLabels`), la valeur par le nombre.
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

/// Bouton d'incrément/décrément — le seul patron de ce fichier.
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
      // `excludeSemantics` masque l'action du bouton Material : on la
      // re-déclare ici, sinon le filtre deviendrait inactionnable au lecteur
      // d'écran.
      excludeSemantics: true,
      onTap: onPressed,
      child: ConstrainedBox(
        // Cible ≥ 48 dp (invariant AD-13).
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

/// Bascule d'un filtre — le seul patron, partagé entre seaux de maîtrise et
/// sources.
///
/// Les seaux et les sources traversent ce même widget : deux copies quasi
/// identiques seraient deux endroits où corriger, et un correctif appliqué à
/// l'un pourrait diverger de l'autre.
class _FilterToggle extends StatelessWidget {
  const _FilterToggle({
    required this.tileKey,
    required this.text,
    required this.selected,
    required this.onChanged,
  });

  final ValueKey<String> tileKey;

  /// Libellé déjà résolu via `ZcrudLabels` par l'appelant.
  final String text;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: tileKey,
      // Libellé a11y issu de `ZcrudLabels`.
      label: text,
      // `checked:`, pas `selected:` — c'est une case à cocher : le lecteur
      // d'écran doit annoncer « cochée / non cochée », jamais la couleur
      // seule (invariant AD-13). C'est aussi l'information que
      // `excludeSemantics` retire au `CheckboxListTile` : elle est donc
      // re-déclarée ici, jamais perdue.
      checked: selected,
      // L'action est re-déclarée pour la même raison : sans elle, la bascule
      // serait annoncée mais inactionnable au lecteur d'écran.
      onTap: () => onChanged(!selected),
      // Le `title: Text(text)` de la tuile rend le même libellé que ce
      // `Semantics(label:)` : sans exclusion, un lecteur d'écran annoncerait
      // le libellé deux fois.
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
