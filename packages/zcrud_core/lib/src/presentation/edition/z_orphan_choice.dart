/// Rendu d'une **valeur orpheline** dans les familles à choix (`select`,
/// `radio`, `checkbox`, `relation`, `rowChips`) — helpers `src`-privés (non
/// exportés par le barrel), consommés par les widgets de famille et par le
/// formateur de mode lecture.
///
/// ## Le défaut fermé ici
///
/// Une valeur **orpheline** est une valeur **présente dans la tranche** mais
/// **absente des options du moment** (cascade : les options dépendent d'un autre
/// champ ; un agent muté sort de la population « du jour » sans que la donnée
/// historique soit fausse). Le socle **conserve** cette valeur : ni l'hôte ni
/// le socle ne purgent, et une purge écrirait, ce qui refermerait la boucle
/// d'une dépendance circulaire aujourd'hui inoffensive. **Ces helpers ne
/// touchent donc JAMAIS à la donnée : ils ne décident que du RENDU.**
///
/// Le rendu, sans cette règle unique, divergerait d'une famille à l'autre :
/// - voies `dropdown` (select et relation) : `values.contains(value) ? value :
///   null` effacerait la valeur de l'écran alors qu'elle va être **soumise**
///   — un *mensonge d'affichage* (un widget ne doit rendre que la donnée que
///   son propre geste écrit) ;
/// - voies `chips` (select multi et relation multi) : `_labelForValue(...) ??
///   '$v'` afficherait l'**identifiant technique brut**, défaut déjà proscrit
///   ailleurs dans ce paquet (cf. `fileRefUnresolved` : « une identité non
///   résolue doit être ABSENTE, jamais la clé montrée à l'utilisateur »).
///
/// ## La règle unique (troisième voie)
///
/// **Une valeur orpheline est RENDUE, à sa place normale dans le contrôle, sous
/// le libellé l10n [zOrphanChoiceLabelKey], dans l'état `disabled`.** La clé
/// technique n'apparaît **jamais** — ni à l'écran, ni dans l'arbre sémantique.
///
/// Les deux défauts sont évités *simultanément*, et c'est le seul rendu qui le
/// permette :
/// - **ni mensonge d'affichage** : l'utilisateur voit qu'une valeur occupe le
///   champ et sera soumise (la voie « effacer » l'en aurait privé) ;
/// - **ni clé à l'écran** : le texte rendu est un libellé traduit (la voie
///   « `'$v'` » l'aurait exposée).
///
/// ## Canal d'accessibilité (invariant AD-13)
///
/// L'état inhabituel est porté par du **texte** — donc par un canal disponible
/// au lecteur d'écran **et** à l'œil — jamais par une couleur ou une icône
/// seules. Il est doublé par l'état `disabled` natif du contrôle Material, que
/// Flutter projette dans l'arbre sémantique (`SemanticsFlag.hasEnabledState`).
/// Aucune couleur n'est posée ici (invariant FR-26).
///
/// ## Surcharge par l'hôte
///
/// Le libellé passe par `label(context, …)`, dont la chaîne de résolution est
/// **déjà** `ZcrudScope.labels` (hôte) > locale du delegate > table `en` >
/// clé. Un hôte surcharge donc le texte en enregistrant
/// [zOrphanChoiceLabelKey] dans ses `ZcrudLabels` — **aucun nouveau paramètre
/// public, aucun jeton `ZcrudTheme`** : ce qui est surchargé est un *libellé*,
/// et `ZcrudTheme` ne porte aucun libellé (ses seules `String` sont des noms de
/// **modes de style**). Y loger un texte ouvrirait un second canal de surcharge
/// concurrent de la l10n — exactement ce que l'invariant FR-26 proscrit.
library;

import 'package:flutter/widgets.dart';

import '../../domain/edition/z_field_choice.dart';
import '../l10n/z_localizations.dart';

/// Clé l10n du libellé d'une valeur orpheline (`en`/`fr` fournies par le
/// delegate ; surchargeable par `ZcrudScope.labels`).
const String zOrphanChoiceLabelKey = 'choiceUnresolved';

/// `true` si [value] est **orpheline** : non `null` et absente des [choices].
///
/// `null` n'est jamais orphelin (invariant AD-4 : `null` ⇒ absent de l'arbre, c'est la
/// place vide légitime du champ).
bool zIsOrphanValue(List<ZFieldChoice> choices, Object? value) {
  if (value == null) return false;
  for (final c in choices) {
    if (c.value == value) return false;
  }
  return true;
}

/// Les valeurs orphelines de [values] (multi), dans leur ordre d'origine.
List<Object?> zOrphanValues(List<ZFieldChoice> choices, List<Object?> values) =>
    <Object?>[for (final v in values) if (zIsOrphanValue(choices, v)) v];

/// Option **synthétique d'AFFICHAGE** représentant la valeur orpheline [value].
///
/// Conserve [value] à l'identique (c'est elle qui sera soumise) et porte
/// [zOrphanChoiceLabelKey] comme libellé — résolu en aval par le même
/// `label(context, choice.label)` que toute autre option, donc surchargeable et
/// jamais rendu comme clé brute. `disabled: true` : l'option est **visible et
/// accessible mais non re-sélectionnable**, ce qui est exactement son statut —
/// elle n'est plus proposée.
///
/// N'est **jamais** ajoutée à la donnée : elle ne vit que dans la liste
/// d'options passée au contrôle pour le temps d'un `build`.
ZFieldChoice zOrphanChoice(Object? value) =>
    ZFieldChoice(value: value, label: zOrphanChoiceLabelKey, disabled: true);

/// [choices] **augmentées** des options synthétiques des valeurs orphelines de
/// [values], appendues en fin de liste (l'ordre métier des options réelles est
/// préservé — il est significatif, cf. `ordonnerLesAgents`).
///
/// Retourne [choices] **inchangée** (même instance) s'il n'y a aucun orphelin :
/// un champ sans valeur orpheline rend donc exactement comme avant.
List<ZFieldChoice> zWithOrphanChoices(
  List<ZFieldChoice> choices,
  List<Object?> values,
) {
  final orphans = zOrphanValues(choices, values);
  if (orphans.isEmpty) return choices;
  return <ZFieldChoice>[
    ...choices,
    for (final v in orphans) zOrphanChoice(v),
  ];
}

/// Libellé résolu d'une valeur orpheline (texte, jamais la clé).
String zOrphanChoiceLabel(BuildContext context) =>
    label(context, zOrphanChoiceLabelKey);
