/// Widget de la **famille booléen** (E3-3a) : `boolean`.
///
/// `SwitchListTile` : lit `value` (coché si `== true`) et écrit via `onChanged`
/// (aucun `TextEditingController` — AD-2). Le `SwitchListTile` porte nativement
/// l'**état sémantique** (coché/décoché, rôle `switch`) et une cible ≥ 48 dp
/// (hauteur de `ListTile`), satisfaisant AC5/AC6 sans style codé en dur (FR-26).
///
/// Convention (story #3) : `boolean` = **toggle unique** ; la multi-sélection
/// par cases relève de `checkb` (famille select).
///
/// ## CR-DODLP-BOOL — texte d'état optionnel (2026-08-10)
///
/// Avec un `ZBooleanConfig` dont [ZBooleanConfig.showsStateLabel] est vrai, un
/// **texte d'état** (« Oui »/« Non », clés l10n `yes`/`no`, surchargeables) est
/// rendu **à la fin du `title`**, donc immédiatement avant le `Switch` — la
/// position de parité legacy DODLP (`Le magasin… ●— Non`).
///
/// **Forme retenue et pourquoi.** La CR proposait `SwitchListTile.secondary`, un
/// sous-titre, ou un `Row[Switch, Text]` fait main :
/// * `secondary` occupe le slot **leading** (le `Switch` est déjà en trailing) :
///   le texte atterrirait du mauvais côté ;
/// * `subtitle` place le texte sous le libellé, loin du switch ;
/// * un `Row[Switch, Text]` fait main **remplacerait** `SwitchListTile` : il
///   faudrait re-fabriquer à l'identique le `MergeSemantics`, l'`onTap` de
///   ligne, le `ListTileTheme` et la hauteur minimale — donc réintroduire à la
///   main la cible ≥ 48 dp et le nœud sémantique `switch` que Material fournit.
///
/// Injecter le texte dans le `title` garde **le même `SwitchListTile`** dans les
/// deux cas : la cible tactile, le `MergeSemantics` et l'`onTap` restent ceux de
/// Material, et le chemin de l'hôte passif est **littéralement le chemin
/// antérieur** (`title: Text(resolvedLabel)`).
///
/// **A11y (AD-13) — le texte d'état est DÉCORATIF.** `SwitchListTile` annonce
/// déjà l'état via le drapeau `toggled` du nœud fusionné ; laisser « Non »
/// entrer dans le `label` le ferait entendre **deux fois** (« … Non,
/// interrupteur, désactivé »). Le `Text` d'état est donc enveloppé dans
/// `ExcludeSemantics`, comme l'astérisque du champ requis. La couleur n'est
/// jamais le seul canal : l'information est portée par du **texte** (et l'état
/// reste porté par le `Switch` lui-même).
///
/// **Lecture seule.** `field.readOnly` désactive le switch mais **conserve** le
/// texte d'état : c'est le cas où la seule position d'un toggle grisé est la
/// plus difficile à lire, et cela s'aligne sur le mode lecture (DP-13), où
/// `zReadOnlyValueOf` rend déjà `Oui`/`Non` en toutes lettres pour un `boolean`.
library;

import 'package:flutter/material.dart';

import '../../../domain/edition/z_field_config.dart';
import '../../../domain/edition/z_field_spec.dart';
import '../../l10n/z_localizations.dart';

/// Champ d'édition **booléen** (interrupteur avec libellé et état sémantique).
class ZBooleanFieldWidget extends StatelessWidget {
  /// Construit l'interrupteur lié à [field] ; [value] est la valeur courante
  /// (coché si `== true`), [onChanged] écrit le nouvel état.
  const ZBooleanFieldWidget({
    required this.field,
    required this.value,
    required this.onChanged,
    super.key,
  });

  /// Spécification `const` du champ rendu.
  final ZFieldSpec field;

  /// Valeur courante de la tranche (coché si `== true`).
  final Object? value;

  /// Notifié avec le nouvel état booléen.
  final ValueChanged<bool> onChanged;

  /// Config booléenne depuis `field.config` (défaut sûr : config vide ⇒ aucun
  /// texte d'état, rendu antérieur strictement inchangé — AD-10).
  ZBooleanConfig get _config {
    final config = field.config;
    return config is ZBooleanConfig ? config : const ZBooleanConfig();
  }

  /// Texte d'état pour [checked] : libellé de l'hôte s'il est fourni et non
  /// vide, sinon repli sur les clés l10n `yes`/`no` (FR-26 — aucun littéral en
  /// dur ici ; les deux clés existent en `en` et en `fr`).
  String _stateText(BuildContext context, ZBooleanConfig config, bool checked) {
    final custom = checked ? config.trueLabel : config.falseLabel;
    if (custom != null && custom.isNotEmpty) return custom;
    return label(context, checked ? 'yes' : 'no');
  }

  @override
  Widget build(BuildContext context) {
    final resolvedLabel =
        label(context, field.label ?? field.name, fallback: field.label ?? field.name);
    final checked = value == true;
    final config = _config;

    return SwitchListTile(
      value: checked,
      onChanged: field.readOnly ? null : onChanged,
      title: config.showsStateLabel
          // Le texte d'état termine la ligne de titre ⇒ accolé au `Switch`
          // (trailing). `Row`/`EdgeInsetsDirectional` suivent la
          // `Directionality` : en RTL le texte reste du côté du switch (AD-13).
          ? Row(
              children: <Widget>[
                Expanded(child: Text(resolvedLabel)),
                // DÉCORATIF : l'état est déjà annoncé par le `Switch` fusionné.
                // Sans cette exclusion, le lecteur d'écran l'entendrait 2 fois.
                ExcludeSemantics(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(8, 0, 0, 0),
                    child: Text(_stateText(context, config, checked)),
                  ),
                ),
              ],
            )
          : Text(resolvedLabel),
      // `ListTile` fournit une cible ≥ 48 dp et fusionne le libellé du titre
      // avec l'état `switch` du contrôle (Semantics natif).
      contentPadding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
    );
  }
}
