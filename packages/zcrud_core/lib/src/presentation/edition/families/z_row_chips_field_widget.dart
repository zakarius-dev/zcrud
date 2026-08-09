/// Widget de la **famille rowChips** (E3-3b-1) : `rowChips`.
///
/// ## CR-DODLP-GAP2 — c'est CE type qui rend « le select en mode chips »
///
/// Le legacy DODLP demande `S2ChoiceType.chips` sur deux champs
/// (`gradeMillitaire`, `gradeOTR`) : **mono-choix**, options **statiques**,
/// `required`. C'est exactement [ZRowChipsFieldWidget] — la parité s'obtient en
/// déclarant `type: EditionFieldType.rowChips` au lieu de
/// `EditionFieldType.select`, **sans aucun mode d'affichage** à ajouter sur
/// `ZSelectConfig`. Un canal de plus aurait dupliqué ce widget.
///
/// Deux écarts mesurés ont été comblés pour que la substitution soit réellement
/// équivalente à un `select` :
/// * **choix dynamiques** — `rowChips` ne recevait que `field.choices` ; il
///   reçoit désormais les **choix effectifs** résolus par le dispatcher
///   ([choices] : `choicesSourceKey` → `choicesFromKey` → `derivedFrom.options`
///   → `field.choices`), comme `select` ;
/// * **multi-sélection** — [multiple] (alimenté par `ZFieldSpec.multiple`, la
///   **source unique** de multiplicité du dépôt) rend une rangée de
///   `FilterChip` dont la valeur de tranche est une `List`. C'est la forme
///   « toutes les options visibles, chacune bascule » (parité
///   `FormBuilderFilterChips`), **distincte** du `select` multi qui n'affiche
///   que les puces **déjà choisies** + un modal d'ajout.
///
/// Défaut `multiple: false` + `choices: null` ⇒ rendu E3-3b strictement
/// inchangé.
///
/// Rangée de puces **mono-choix** alimentée par `ZFieldSpec.choices`
/// (`ZFieldChoice{value,label}`) : la valeur sélectionnée (unique) vit **dans la
/// tranche** (lecture `value`, écriture via `onChanged` — aucun
/// `TextEditingController`, AD-2). Toucher une puce déjà sélectionnée la
/// désélectionne (`null`).
///
/// a11y/RTL (AD-13) : `ChoiceChip` porte l'état sélectionné sémantique et une
/// cible ≥ 48 dp (`materialTapTargetSize: padded` par défaut) ; `Wrap` respecte
/// la `Directionality` ambiante. Aucune couleur/inset non directionnel en dur
/// (FR-26).
library;

import 'package:flutter/material.dart';

import '../../../domain/edition/z_field_choice.dart';
import '../../../domain/edition/z_field_spec.dart';
import '../../l10n/z_localizations.dart';
import '../z_orphan_choice.dart';

/// Champ d'édition à **puces mono-choix** (rangée depuis `field.choices`).
class ZRowChipsFieldWidget extends StatelessWidget {
  /// Construit la rangée de puces liée à [field] (options = `field.choices`),
  /// valeur courante [value], notifiant [onChanged] avec la valeur choisie
  /// (ou `null` si désélection).
  const ZRowChipsFieldWidget({
    required this.field,
    required this.value,
    required this.onChanged,
    this.choices,
    this.multiple = false,
    super.key,
  });

  /// Spécification `const` du champ rendu (repli des `choices`).
  final ZFieldSpec field;

  /// Valeur courante sélectionnée (unique) ou `null` ; `List` si [multiple].
  final Object? value;

  /// Notifié avec la valeur choisie (ou `null` si désélection) ; avec la `List`
  /// des valeurs cochées si [multiple].
  final ValueChanged<Object?> onChanged;

  /// CR-DODLP-GAP2 — choix **effectifs** résolus par le dispatcher (dynamique
  /// cross-champ / dérivée), comme la famille `select`. `null` (défaut) ⇒
  /// `field.choices` (statique, rétro-compat stricte).
  final List<ZFieldChoice>? choices;

  /// CR-DODLP-GAP2 — **multi-sélection** (alimentée par `ZFieldSpec.multiple`,
  /// source unique de multiplicité). `false` (défaut) ⇒ `ChoiceChip` mono
  /// inchangé ; `true` ⇒ `FilterChip` par option, valeur de tranche = `List`.
  final bool multiple;

  /// Options effectives (dynamiques) ou repli statique `field.choices`.
  List<ZFieldChoice> get _choices => choices ?? field.choices;

  /// Valeurs cochées en multi (défensif AD-10 : scalaire/`null` normalisés).
  List<Object?> get _selected {
    final v = value;
    if (v is List) return List<Object?>.from(v);
    if (v == null) return const <Object?>[];
    return <Object?>[v];
  }

  /// MIN-2 (parité DODLP « sous-titre rowChips ») — puce avec **sous-titre**
  /// optionnel (`ZFieldChoice.subtitle`). Sans sous-titre ⇒ `ChoiceChip` simple
  /// (rendu E3-3b inchangé) ; avec sous-titre ⇒ label sur deux lignes (titre +
  /// ligne secondaire `bodySmall`) et `Tooltip` a11y portant le sous-titre.
  Widget _chip(BuildContext context, ZFieldChoice choice) {
    final title = label(context, choice.label, fallback: choice.label);
    final sub = choice.subtitle == null
        ? null
        : label(context, choice.subtitle!, fallback: choice.subtitle!);
    final selected =
        multiple ? _selected.contains(choice.value) : value == choice.value;
    // CR-ORPHAN : une option `disabled` (dont l'option synthétique d'une valeur
    // orpheline) est visible et lue, mais non (re)sélectionnable — comme dans
    // les familles `select` et `relation`.
    final onSelected = (field.readOnly || choice.disabled)
        ? null
        : (bool s) => multiple
            ? _toggle(choice.value, s)
            : onChanged(s ? choice.value : null);

    final Widget content = sub == null
        ? Text(title)
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, textAlign: TextAlign.start),
              Text(sub,
                  textAlign: TextAlign.start,
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          );

    // AD-13 — l'état sélectionné n'est JAMAIS porté par la seule couleur :
    // `ChoiceChip`/`FilterChip` exposent `SemanticsFlag.isSelected` et peignent
    // leur coche (`showCheckmark`, laissé au thème). Cible ≥ 48 dp par le
    // `materialTapTargetSize: padded` par défaut des chips Material.
    final Widget chip = multiple
        ? FilterChip(
            label: content,
            selected: selected,
            onSelected: onSelected,
          )
        : ChoiceChip(
            label: content,
            selected: selected,
            onSelected: onSelected,
          );

    if (sub == null) return chip;
    return Tooltip(message: sub, child: chip);
  }

  /// Bascule d'une valeur en multi : écrit la `List` complète (jamais un
  /// scalaire), copie défensive (la tranche n'est pas mutée en place).
  void _toggle(Object? v, bool selected) {
    final next = _selected;
    if (selected) {
      if (!next.contains(v)) next.add(v);
    } else {
      next.remove(v);
    }
    onChanged(List<Object?>.unmodifiable(next));
  }

  @override
  Widget build(BuildContext context) {
    final resolvedLabel = label(context, field.label ?? field.name,
        fallback: field.label ?? field.name);

    return Semantics(
      container: true,
      // Pas de `label:` ici : le `Text(resolvedLabel)` visible ci-dessous fournit
      // déjà le nom accessible du conteneur — le dupliquer sur le Semantics
      // provoquerait une DOUBLE annonce (cf. correctif fp-4-4/fp-5-1).
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
            child:
                Text(resolvedLabel, style: Theme.of(context).textTheme.bodySmall),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: <Widget>[
                // CR-ORPHAN — voie supplémentaire trouvée au balayage : une
                // valeur absente de `field.choices` ne rendait AUCUNE puce
                // sélectionnée, alors qu'elle serait soumise. Même règle que
                // les huit voies : puce synthétique, libellé traduit, jamais
                // la clé, non re-sélectionnable.
                for (final choice in zWithOrphanChoices(
                    _choices, multiple ? _selected : <Object?>[value]))
                  _chip(context, choice),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
