/// `ZDecoratedFieldTrigger` — **déclencheur décoré** partagé par les familles
/// qui ne s'éditent pas au clavier mais ouvrent un sélecteur modal
/// (`date`/`time`/`dateTime` et `dateRange`), CR-DODLP-DATE-FIELD.
///
/// Motif : ces familles rendaient un `OutlinedButton` (« Libellé : valeur »),
/// donc **aspect bouton**, sans libellé flottant, sans astérisque « requis » et
/// hors de la chaîne de décoration du paquet — alors que `text`/`number`/
/// `select` passent tous par [zFieldDecoration]. Ce widget referme l'écart en
/// réutilisant **exactement la même chaîne** : `InputDecorator` +
/// [zFieldDecoration] ⇒ libellé enrichi ([ZFieldLabel], astérisque requis),
/// bordure, remplissage, ornements déclaratifs, et les jetons
/// `fieldFillColor` / `fieldBorderColor` / `fieldFocusedBorderColor` **sans une
/// ligne de code nouvelle**.
///
/// Deux états de libellé (parité `InputDecorator`) : champ **vide** ⇒ libellé
/// **au repos** dans la boîte ; champ **rempli** ⇒ libellé **flottant** et
/// valeur rendue dans le corps.
///
/// a11y (AD-13) : un **seul** nœud sémantique (bouton + libellé + valeur +
/// `isRequired`), la sémantique descendante étant exclue — l'arbre annoncé est
/// donc strictement celui de l'ancien déclencheur, augmenté du seul canal
/// « requis ». L'astérisque reste **décoratif** (`ExcludeSemantics` dans
/// [ZFieldLabel], puis exclu une seconde fois par le wrapper).
///
/// AD-2/SM-1 : `StatelessWidget` pur — aucun `TextEditingController`, aucun
/// `FocusNode`, aucun `Listenable`. Il est monté **dans** la tranche réactive du
/// champ : ouvrir/choisir/effacer ne reconstruit que cette tranche.
///
/// FR-26 : aucune couleur ni libellé en dur (tout vient du thème / de la l10n).
library;

import 'package:flutter/material.dart';

import '../../domain/edition/z_field_size.dart';
import '../../domain/edition/z_field_spec.dart';
import '../theme/z_theme.dart';
import 'z_field_adornment_view.dart';

/// Déclencheur de sélecteur rendu comme un **champ décoré**.
class ZDecoratedFieldTrigger extends StatelessWidget {
  /// Construit le déclencheur de [field]. [semanticsLabel] est le libellé
  /// **déjà résolu l10n** (annoncé par le nœud sémantique unique) ;
  /// [placeholder] le texte de substitution l10n annoncé quand il n'y a pas de
  /// valeur ; [valueText] le rendu de la valeur courante ([hasValue] faux ⇒
  /// ignoré). [onTap] `null` ⇒ déclencheur désactivé (champ en lecture seule).
  const ZDecoratedFieldTrigger({
    required this.field,
    required this.semanticsLabel,
    required this.placeholder,
    required this.valueText,
    required this.hasValue,
    required this.onTap,
    this.trailingIcon,
    super.key,
  });

  /// Spécification `const` du champ rendu (source du libellé enrichi, des
  /// ornements déclaratifs et de `isRequired`).
  final ZFieldSpec field;

  /// Libellé résolu l10n — porté par le **nœud sémantique** unique.
  final String semanticsLabel;

  /// Texte de substitution l10n (annoncé quand [hasValue] est faux).
  final String placeholder;

  /// Rendu textuel de la valeur courante (ignoré si [hasValue] est faux).
  final String valueText;

  /// Une valeur est-elle présente ? Pilote le libellé **flottant vs au repos**
  /// (`InputDecorator.isEmpty`) et la valeur annoncée.
  final bool hasValue;

  /// Action de tap (ouverture du sélecteur). `null` ⇒ désactivé.
  final VoidCallback? onTap;

  /// Icône d'affordance de fin de ligne. Posée en `suffixIcon` **uniquement si**
  /// le champ ne déclare aucun ornement de fin (`suffix`/`suffixIcon` issus de
  /// [zFieldDecoration]) — un ornement déclaratif de l'hôte n'est jamais écrasé.
  final Widget? trailingIcon;

  /// Rendu `bare` (le décor est porté par `ZLargeFieldCard`) — dérivé de la
  /// spec, exactement comme le fait le dispatcher (`fieldSize == large`).
  bool get _bare => field.fieldSize == ZFieldSize.large;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bare = _bare;
    var decoration = zFieldDecoration(context, field, bare: bare);
    if (trailingIcon != null &&
        decoration.suffixIcon == null &&
        decoration.suffix == null &&
        decoration.suffixText == null) {
      decoration = decoration.copyWith(suffixIcon: trailingIcon);
    }
    decoration = decoration.copyWith(enabled: onTap != null);

    // En `bare` aucun libellé n'est posé (porté par la Card) : le texte de
    // substitution doit rester VISIBLE, sinon la Card n'affiche plus rien.
    // Hors `bare`, le libellé AU REPOS tient ce rôle (parité Material) et le
    // corps reste vide — c'est ce qui donne les deux états de libellé.
    final bodyText = hasValue
        ? valueText
        : bare
            ? placeholder
            : '';
    final bodyStyle = hasValue
        ? theme.textTheme.bodyLarge
        : theme.textTheme.bodyLarge?.copyWith(color: theme.hintColor);

    return Semantics(
      button: true,
      enabled: onTap != null,
      label: semanticsLabel,
      // La valeur annoncée reste le texte de substitution quand le champ est
      // vide : l'annonce ne perd rien de ce que rendait l'ancien bouton.
      value: hasValue ? valueText : placeholder,
      // Canal sémantique « requis » (AD-13) : l'information passe par là, JAMAIS
      // par l'astérisque (qui reste décoratif). Aligné sur la règle de
      // `ZFieldLabel` : requis ET éditable.
      // `null` (et non `false`) hors du cas requis : le nœud reste alors
      // EXACTEMENT celui d'avant (`Tristate.none`) — l'unique delta de l'arbre
      // sémantique est le signal POSITIF ajouté sur un champ requis.
      isRequired: (field.isRequired && !field.readOnly) ? true : null,
      excludeSemantics: true,
      onTap: onTap,
      // 🔴 Cible tactile (AD-13) : contrainte LIANTE de 48 dp posée ici — elle
      // ne dépend pas de la hauteur intrinsèque de l'`InputDecorator` (qui la
      // dépasse avec le padding par défaut, mais pas nécessairement avec un
      // `inputContentPadding` réduit par l'hôte).
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: InkWell(
          onTap: onTap,
          child: InputDecorator(
            decoration: decoration,
            isEmpty: !hasValue,
            // `InputDecorator` sans champ de saisie : jamais focalisé/en survol.
            child: Text(bodyText, textAlign: TextAlign.start, style: bodyStyle),
          ),
        ),
      ),
    );
  }
}

/// Résout la bascule d'apparence (CR-DODLP-DATE-FIELD) pour les familles date :
/// **paramètre > jeton `ZcrudTheme.dateFieldDecorated` > référence (`true`)**.
///
/// La référence du paquet est le **champ décoré** ; l'échappatoire vers le rendu
/// `OutlinedButton` historique est un opt-out explicite de l'hôte.
bool zResolveDateFieldDecorated(BuildContext context, bool? parameter) =>
    parameter ?? ZcrudTheme.of(context).dateFieldDecorated ?? true;
