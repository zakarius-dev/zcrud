/// `ZCrudTitles` — porte-titres à **quatre états** de la surface d'édition
/// d'un `ZCrudScreen` : création, duplication, édition, **consultation**.
///
/// Chaque formulaire du parc recopiait son propre ternaire
/// `_isEdit ? … : …` ; cet objet le remplace par une déclaration unique.
/// Chaque titre est une **clé l10n ou un littéral** (résolu via
/// `label(context, …)`, repli sur le littéral lui-même — même contrat que
/// `ZCrudScreen.title`). Un titre `null` retombe sur la clé l10n générique
/// correspondante (`create` / `copy` / `edit` / `details`), résolue par le
/// même canal (labels du `ZcrudScope`, puis delegate, puis table `en`
/// intégrée).
library;

import 'package:flutter/foundation.dart';

/// Titres des quatre modes de la surface d'édition d'un `ZCrudScreen`.
///
/// La **duplication** est un mode distinct de la création nue : le formulaire
/// s'ouvre en création (entité sans identité), mais son intitulé dit qu'il
/// s'agit d'une copie (legacy DODLP : « Copie de la mutation »). La
/// **consultation** est distincte de l'édition pour la même raison : la même
/// surface, mais un intitulé qui annonce qu'on ne modifie rien.
@immutable
class ZCrudTitles {
  /// Construit un porte-titres — chaque champ est optionnel, `null` retombe
  /// sur la clé l10n générique du mode.
  const ZCrudTitles({this.create, this.copy, this.update, this.read});

  /// Titre du mode **création** (bouton « + »). `null` ⇒ clé l10n `create`.
  final String? create;

  /// Titre du mode **duplication** (geste « dupliquer »). `null` ⇒ clé l10n
  /// `copy`.
  final String? copy;

  /// Titre du mode **édition** (action de ligne). `null` ⇒ clé l10n `edit`.
  final String? update;

  /// Titre du mode **consultation** — la fiche de détail ouverte en mode
  /// `ZScreenMode.details`. `null` ⇒ clé l10n `details`.
  final String? read;

  @override
  bool operator ==(Object other) =>
      other is ZCrudTitles &&
      other.create == create &&
      other.copy == copy &&
      other.update == update &&
      other.read == read;

  @override
  int get hashCode => Object.hash(create, copy, update, read);
}
