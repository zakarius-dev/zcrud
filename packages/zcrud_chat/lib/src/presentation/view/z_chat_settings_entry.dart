/// Le modèle d'entrées déclaratif de la feuille de réglages.
///
/// ## Ce que ce fichier est — et n'est pas
///
/// C'est le modèle de données : une entrée est un `id` opaque, un `kind`
/// ouvert (`String` — invariant AD-4, jamais un enum fermé), une icône
/// d'hôte optionnelle, un titre et un sous-titre (clé de libellé du socle ou
/// texte déjà localisé par l'hôte), une section d'appartenance, et un
/// contrôle typé selon le kind. Le rendu vit dans `z_chat_settings_sheet.dart`
/// — une seule voie de rendu, celle que les familles standard empruntent
/// aussi depuis leur re-expression.
///
/// ## Le `kind` est ouvert
///
/// Les kinds que le socle sait rendre sont des constantes `String`
/// ([kZChatSettingsKindToggle]…), jamais un enum : un hôte déclare son propre
/// kind en implémentant [ZChatSettingsControl] et en fournissant son builder
/// (`kindBuilders`). Un kind que personne ne sait rendre laisse l'entrée
/// absente de l'arbre, ou rendue par `unknownEntryBuilder` — jamais un
/// `throw` (invariant AD-10).
///
/// ## Aucune valeur métier
///
/// Comme le catalogue de corpus : les libellés d'hôte arrivent déjà
/// localisés, les clés du socle passent par le registre et son repli
/// (`kZChatLabelFallbacks`). Le socle ne connaît ni un nom de domaine, ni un
/// nom de document, ni un nom de modèle d'IA.
library;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/widgets.dart';

// ── Kinds que le socle sait rendre (constantes ouvertes, jamais un enum) ──

/// Interrupteur booléen, rendu au canal non chromatique du socle.
const String kZChatSettingsKindToggle = 'toggle';

/// Échelle discrète ordonnée (labels), rendue en segments à coche.
const String kZChatSettingsKindScale = 'scale';

/// Choix parmi des options, rendu en segments.
const String kZChatSettingsKindSelect = 'select';

/// Ligne de navigation (chevron) : l'hôte possède la destination, le socle
/// rend l'affordance.
const String kZChatSettingsKindNavigation = 'navigation';

/// Nombre borné : les bornes sont réellement appliquées au rendu.
const String kZChatSettingsKindNumberBounded = 'numberBounded';

/// Un libellé à double source : clé du socle (registre + repli
/// `kZChatLabelFallbacks`) ou texte déjà localisé par l'hôte — exactement
/// l'une des deux, propriété du type.
@immutable
class ZChatSettingsLabel {
  /// Libellé par clé du registre (convention du paquet : toute clé a un
  /// repli).
  const ZChatSettingsLabel.key(String this.labelKey) : text = null;

  /// Libellé déjà résolu par l'hôte, dans sa langue.
  const ZChatSettingsLabel.text(String this.text) : labelKey = null;

  /// Clé de libellé, exclusive de [text].
  final String? labelKey;

  /// Texte d'hôte, exclusif de [labelKey].
  final String? text;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatSettingsLabel &&
          labelKey == other.labelKey &&
          text == other.text;

  @override
  int get hashCode => Object.hash(labelKey, text);
}

/// Un segment d'un contrôle à options (scale/select) : libellé à double
/// source, état, geste. C'est la projection déclarative exacte de la
/// primitive d'option de la feuille — donc l'emphase et la sémantique
/// `selected` s'appliquent au rendu de chaque choix.
@immutable
class ZChatSettingsChoice {
  /// Construit un segment.
  const ZChatSettingsChoice({
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
    this.enabled = true,
  });

  /// Libellé du segment.
  final ZChatSettingsLabel label;

  /// `true` pour un segment choisi — annoncé (`Semantics.selected`) et
  /// visible (emphase du thème), jamais l'un sans l'autre.
  final bool selected;

  /// Geste du segment.
  final VoidCallback onTap;

  /// Substitué à `{n}` quand la clé en porte un.
  final int? count;

  /// `false` pour un segment présent mais non sélectionnable (deux canaux,
  /// aucun chromatique).
  final bool enabled;
}

/// Le contrôle typé d'une entrée — interface ouverte : un hôte implémente
/// la sienne avec son propre [kind] et la rend par `kindBuilders`.
abstract class ZChatSettingsControl {
  /// Kind du contrôle — `String` ouverte, jamais un enum (invariant AD-4).
  String get kind;
}

/// Contrôle « interrupteur » ([kZChatSettingsKindToggle]).
@immutable
class ZChatToggleControl implements ZChatSettingsControl {
  /// Construit l'interrupteur.
  const ZChatToggleControl({required this.value, required this.onChanged});

  /// État courant — l'état vit chez l'hôte, jamais ici.
  final bool value;

  /// Bascule — l'hôte range la valeur chez lui.
  final ValueChanged<bool> onChanged;

  @override
  String get kind => kZChatSettingsKindToggle;
}

/// Contrôle « échelle discrète » ([kZChatSettingsKindScale]) — segments à
/// coche : l'état choisi est porté par la sémantique et l'emphase du thème,
/// et par [selectionMark] si l'hôte fournit un glyphe (le socle n'invente ni
/// glyphe ni couleur).
@immutable
class ZChatScaleControl implements ZChatSettingsControl {
  /// Construit l'échelle.
  const ZChatScaleControl({
    required this.choices,
    this.selectionMark,
    this.footer,
  });

  /// Les échelons, dans l'ordre de l'échelle.
  final List<ZChatSettingsChoice> choices;

  /// Glyphe d'hôte posé devant le segment choisi. `null` signifie l'emphase
  /// du thème seule — jamais un glyphe inventé par le socle.
  final Widget? selectionMark;

  /// Rangée sous les segments (échelle labellisée, filtres…). `null`
  /// signifie absent (invariant AD-4).
  final Widget? footer;

  @override
  String get kind => kZChatSettingsKindScale;
}

/// Contrôle « choix parmi des options » ([kZChatSettingsKindSelect]) — même
/// forme rendue que l'échelle ; la distinction est sémantique (une échelle
/// est ordonnée, un choix ne l'est pas) et reste disponible aux builders
/// d'hôte qui veulent des rendus différents par kind.
@immutable
class ZChatSelectControl implements ZChatSettingsControl {
  /// Construit le choix.
  const ZChatSelectControl({
    required this.choices,
    this.selectionMark,
    this.footer,
  });

  /// Les options.
  final List<ZChatSettingsChoice> choices;

  /// Glyphe d'hôte du segment choisi. `null` signifie l'emphase du thème
  /// seule.
  final Widget? selectionMark;

  /// Rangée sous les options. `null` signifie absent (invariant AD-4).
  final Widget? footer;

  @override
  String get kind => kZChatSettingsKindSelect;
}

/// Contrôle « navigation » ([kZChatSettingsKindNavigation]) — la destination
/// appartient à l'hôte ; le socle rend l'affordance (cible ≥ 48 dp,
/// `Semantics(button:)`).
@immutable
class ZChatNavigationControl implements ZChatSettingsControl {
  /// Construit la navigation.
  const ZChatNavigationControl({required this.onTap, this.value, this.trailing});

  /// Geste d'ouverture — l'hôte navigue, le socle ne connaît aucune route.
  final VoidCallback onTap;

  /// Valeur courante affichée sous le titre, déjà localisée par l'hôte.
  /// `null` signifie absente (invariant AD-4).
  final ZChatSettingsLabel? value;

  /// Glyphe de fin d'hôte (le chevron). `null` signifie absent — le socle
  /// n'invente aucun glyphe.
  final Widget? trailing;

  @override
  String get kind => kZChatSettingsKindNavigation;
}

/// Contrôle « nombre borné » ([kZChatSettingsKindNumberBounded]) — les
/// bornes sont réellement appliquées : le geste hors bornes n'est pas émis,
/// l'affordance correspondante est désactivée.
@immutable
class ZChatNumberControl implements ZChatSettingsControl {
  /// Construit le nombre borné. [min] ≤ [value] ≤ [max] exigé de l'hôte ;
  /// hors de cet intervalle la valeur est écrêtée au rendu (invariant AD-10,
  /// jamais un `throw`).
  const ZChatNumberControl({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.step = 1,
    this.decrementGlyph,
    this.incrementGlyph,
  });

  /// Valeur courante — l'état vit chez l'hôte.
  final int value;

  /// Borne basse, incluse.
  final int min;

  /// Borne haute, incluse.
  final int max;

  /// Nouvelle valeur — toujours dans `[min, max]`.
  final ValueChanged<int> onChanged;

  /// Pas d'un geste.
  final int step;

  /// Glyphe d'hôte du bouton « diminuer ». `null` signifie le libellé
  /// résolu (`zchat.decrease`).
  final Widget? decrementGlyph;

  /// Glyphe d'hôte du bouton « augmenter ». `null` signifie le libellé
  /// résolu (`zchat.increase`).
  final Widget? incrementGlyph;

  @override
  String get kind => kZChatSettingsKindNumberBounded;
}

/// Une entrée déclarative de la feuille de réglages (icône + titre +
/// sous-titre + contrôle typé).
@immutable
class ZChatSettingsEntry {
  /// Construit une entrée.
  const ZChatSettingsEntry({
    required this.id,
    required this.title,
    required this.control,
    this.sectionId,
    this.icon,
    this.subtitle,
  });

  /// Identifiant opaque et stable — cible des `entryBuilders`.
  final String id;

  /// Titre de la tuile.
  final ZChatSettingsLabel title;

  /// Le contrôle typé — son [ZChatSettingsControl.kind] choisit le rendu.
  final ZChatSettingsControl control;

  /// Section d'appartenance. `null` signifie la section de génération du
  /// socle (`kZChatSettingsSectionGeneration`) — les entrées d'hôte
  /// s'injectent dans les mêmes sections que les familles standard.
  final String? sectionId;

  /// Icône d'hôte (glyphe déjà stylé par lui). `null` signifie absente
  /// (invariant AD-4) — le socle n'importe aucune banque d'icônes.
  final Widget? icon;

  /// Sous-titre. `null` signifie absent (invariant AD-4).
  final ZChatSettingsLabel? subtitle;

  /// Kind de l'entrée — celui de son contrôle.
  String get kind => control.kind;
}

/// Une section titrée de la feuille, déclarée par l'hôte.
///
/// Les deux sections du socle ([kZChatSettingsSectionGeneration],
/// [kZChatSettingsSectionCorpus]) existent sans titre par défaut — l'arbre
/// d'un hôte passif ne bouge pas ; un hôte qui déclare la section avec un
/// [title] la voit titrée.
@immutable
class ZChatSettingsSection {
  /// Construit une section.
  const ZChatSettingsSection({required this.id, this.title});

  /// Identifiant opaque et stable — cible des `sectionBuilders` et des
  /// [ZChatSettingsEntry.sectionId].
  final String id;

  /// Titre de la section. `null` signifie aucun en-tête rendu (invariant
  /// AD-4).
  final ZChatSettingsLabel? title;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatSettingsSection && id == other.id && title == other.title;

  @override
  int get hashCode => Object.hash(id, title);
}

/// Section du socle portant les familles standard de génération (verbosité,
/// biais, budget, raisonnement) — les entrées d'hôte sans
/// [ZChatSettingsEntry.sectionId] s'y injectent, après les familles standard.
const String kZChatSettingsSectionGeneration = 'zchat.section.generation';

/// Section du socle portant la portée documentaire.
const String kZChatSettingsSectionCorpus = 'zchat.section.corpus';

/// Id d'entrée de la famille standard « verbosité » — cible d'`entryBuilders`.
const String kZChatSettingsEntryResponseLength = 'zchat.entry.responseLength';

/// Id d'entrée de la famille standard « biais de régénération ».
const String kZChatSettingsEntryLengthBias = 'zchat.entry.lengthBias';

/// Id d'entrée de la famille standard « budget de calcul ».
const String kZChatSettingsEntryComputeBudget = 'zchat.entry.computeBudget';

/// Id d'entrée de la famille standard « exposer le raisonnement ».
const String kZChatSettingsEntryRevealThinking = 'zchat.entry.revealThinking';

/// Id d'entrée de la famille standard « portée documentaire ».
const String kZChatSettingsEntryCorpus = 'zchat.entry.corpus';

/// Toutes les entrées standard — surface pour un hôte qui cible les
/// `entryBuilders`, et cible de la garde d'unicité.
const List<String> kZChatSettingsStandardEntryIds = <String>[
  kZChatSettingsEntryResponseLength,
  kZChatSettingsEntryLengthBias,
  kZChatSettingsEntryComputeBudget,
  kZChatSettingsEntryRevealThinking,
  kZChatSettingsEntryCorpus,
];

/// `listEquals` re-exporté pour les implémentations d'égalité d'hôte — évite
/// un import `foundation` de plus chez le consommateur.
bool zChatSettingsChoicesEqual(
  List<ZChatSettingsChoice>? a,
  List<ZChatSettingsChoice>? b,
) => listEquals(a, b);
