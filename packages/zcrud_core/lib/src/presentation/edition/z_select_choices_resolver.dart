/// Résolution des **choix effectifs** d'un champ à choix — source UNIQUE,
/// partagée par le dispatcher d'édition (`ZFieldWidget`) et par les voies de
/// **projection d'affichage** (résumé de sous-liste compact).
///
/// La projection de résumé du mode compact a besoin de la même priorité pour
/// résoudre un libellé de `select` **dynamique** ; la recopier localement
/// aurait dupliqué un motif déjà partagé ailleurs dans ce paquet (cf.
/// `zValidationText`). Elle est donc **extraite ici**, pas dupliquée — le
/// dispatcher délègue à cette fonction.
///
/// Le seul état requis est un [ZFormController] (pour les lectures cross-champ)
/// et un `BuildContext` (pour le registre injecté au `ZcrudScope`) : la fonction
/// est donc utilisable depuis n'importe quel `build`, y compris celui d'un
/// **sous-formulaire imbriqué** dont le contrôleur est celui de l'item.
library;

import 'package:flutter/widgets.dart';

import '../../domain/edition/z_derivation.dart';
import '../../domain/edition/z_field_choice.dart';
import '../../domain/edition/z_field_config.dart';
import '../../domain/edition/z_field_spec.dart';
import '../z_form_controller.dart';
import '../zcrud_scope.dart';

/// Résout les **choix effectifs** d'un `select`/`rowChips` (défensif
/// invariant AD-10). Priorité **stable** :
/// 1. `choicesSourceKey` (si le registre + la clé résolvent une `ZChoicesSource`)
///    → options calculées depuis le `filterContext` (snapshot des `filterKeys`) ;
/// 2. `choicesFromKey` (si la tranche référencée porte une `List<ZFieldChoice>`
///    NON vide) ;
/// 3. options DÉRIVÉES (`derivedFrom.options`) ;
/// 4. `field.choices` (statique).
///
/// Toute résolution absente/vide/mal typée / source en erreur ⇒ repli sur le
/// niveau suivant, **jamais un throw dans le build**.
///
/// **Entièrement SYNCHRONE** — c'est ce qui la rend utilisable dans une
/// cellule de résumé. La famille `relation` (dont la source est un `Stream`,
/// `ZRelationSource`) n'est PAS couverte : rien de son flux n'est atteignable
/// sans souscrire, donc sans élargir la tranche.
List<ZFieldChoice> zResolveSelectChoices(
  BuildContext context,
  ZFormController controller,
  ZFieldSpec field,
  ZSelectConfig? selCfg,
) {
  // Options DÉRIVÉES, lues AVANT le repli statique et AVANT le retour
  // anticipé ci-dessous : un champ qui déclare `derivedFrom.options` sans
  // `ZSelectConfig` doit quand même les recevoir. Un `choicesSourceKey` ou un
  // `choicesFromKey` EXPLICITE reste prioritaire — l'hôte qui câble à la main
  // a le dernier mot.
  final derived = zDerivedChoices(controller, field);
  if (selCfg == null) return derived ?? field.choices;
  // 1. Source CALCULÉE (registre injecté + clé).
  final sourceKey = selCfg.choicesSourceKey;
  if (sourceKey != null) {
    final source =
        ZcrudScope.maybeOf(context)?.choicesSourceRegistry?.trySourceFor(sourceKey);
    if (source != null) {
      final filterContext = <String, Object?>{};
      for (final k in selCfg.filterKeys) {
        filterContext[k] = controller.valueOf(k);
      }
      try {
        // Priorité au résultat de la source résolue (même vide).
        return source.options(filterContext);
      } catch (_) {
        // Invariant AD-10 : source en erreur ⇒ repli sur les niveaux suivants.
      }
    }
  }
  // 2. Lecture cross-champ directe.
  final fromKey = selCfg.choicesFromKey;
  if (fromKey != null) {
    final slice = controller.valueOf(fromKey);
    if (slice is List<ZFieldChoice> && slice.isNotEmpty) return slice;
    if (slice is List &&
        slice.isNotEmpty &&
        slice.every((e) => e is ZFieldChoice)) {
      return slice.cast<ZFieldChoice>();
    }
  }
  // 3. Options DÉRIVÉES.
  if (derived != null) return derived;
  // 4. Repli statique.
  return field.choices;
}

/// Options publiées par le moteur de dérivation pour ce champ, ou `null` si
/// le champ n'en dérive pas / si la tranche ne porte encore rien d'exploitable.
///
/// **DÉFENSIF** (invariant AD-10) : une tranche d'un autre type est ignorée
/// plutôt que de faire échouer le rendu du champ.
List<ZFieldChoice>? zDerivedChoices(
  ZFormController controller,
  ZFieldSpec field,
) {
  if (field.derivedFrom?.options == null) return null;
  final slice =
      controller.valueOf(ZDerivationChannels.optionsKey(field.name));
  if (slice is List<ZFieldChoice>) return slice;
  if (slice is List && slice.every((e) => e is ZFieldChoice)) {
    return slice.cast<ZFieldChoice>();
  }
  return null;
}
