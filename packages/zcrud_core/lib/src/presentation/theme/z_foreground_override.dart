/// `ZForegroundOverride` — primitive d'**imposition d'une couleur de premier
/// plan** (texte **et** icônes) sur un sous-arbre, **sans peindre aucun fond**.
///
/// 🔴 **La classe de défaut que cette primitive ferme.**
///
/// Un socle qui veut colorer un contenu injecté (un *slot* d'hôte) écrit
/// naturellement le duo :
///
/// ```dart
/// IconTheme.merge(data: IconThemeData(color: c), child: slot)
/// DefaultTextStyle.merge(style: TextStyle(color: c), child: slot)
/// ```
///
/// Ce duo ne couvre QUE le contenu qui **hérite** : un `Text` nu, une `Icon`
/// nue. Il **n'atteint pas** le contenu stylé depuis
/// `Theme.of(context).textTheme.*`, parce que les rôles de `TextTheme` de la
/// typographie Material sont construits avec **`inherit: false`** et portent
/// **leur propre couleur** — celle du thème ambiant. Un `Text` auquel on passe
/// `textTheme.titleSmall` **court-circuite entièrement** le `DefaultTextStyle`
/// ambiant : aucune enveloppe d'héritage ne peut l'atteindre, seule la
/// **réécriture du `TextTheme`** le fait.
///
/// Conséquence : **le défaut punit la bonne pratique**. Le slot d'hôte qui
/// respecte la typographie de l'application garde la couleur ambiante ; celui
/// qui code un `TextStyle(fontSize: 14)` en dur, lui, s'en tire.
///
/// [ZForegroundOverride] ferme les **trois** chemins d'un coup — `TextTheme`,
/// `DefaultTextStyle`, `IconTheme` — et constitue le **seul** point du socle où
/// ce duo d'enveloppes a le droit d'être écrit avec une couleur. Une garde de
/// source (`test/presentation/z_foreground_merge_source_guard_test.dart`)
/// interdit de le recopier ailleurs.
///
/// **FR-26** : aucune couleur littérale — [color] est un **paramètre**, résolu
/// par l'appelant depuis `ColorScheme` / `ZcrudTheme`.
/// **AD-1** : `zcrud_core` reste sans dépendance sortante (CORE OUT = 0).
/// **AD-2** : `StatelessWidget` pur-Flutter, aucun gestionnaire d'état.
/// **AD-13** : aucune contrainte de taille ni de direction imposée au contenu.
library;

import 'package:flutter/material.dart';

/// Impose [color] comme couleur de premier plan de [child] — texte **et**
/// icônes — **sans peindre de fond**.
///
/// ## Ce que la primitive couvre
///
/// | Chemin de style du contenu | Couvert |
/// |---|---|
/// | `Text('x')` nu (hérite du `DefaultTextStyle`) | ✅ |
/// | `Icon(...)` nue (hérite de l'`IconTheme`) | ✅ |
/// | `Text('x', style: Theme.of(c).textTheme.titleSmall)` | ✅ |
/// | tout autre rôle de `TextTheme` (`body*`, `label*`, `display*`, …) | ✅ |
/// | `IconTheme.of(c).color` lu par un builder d'hôte | ✅ |
///
/// ## Ce que la primitive NE couvre PAS — délibérément
///
/// Les composants Material qui résolvent leur premier plan depuis le
/// **`ColorScheme`** et non depuis `TextTheme`/`DefaultTextStyle`/`IconTheme` :
/// `ElevatedButton`, `TextButton`, `FilledButton`, `OutlinedButton`,
/// `IconButton`, `Chip`, `InputDecorator`… Leurs couleurs restent celles du
/// thème ambiant.
///
/// 🔴 **C'est un choix, pas un oubli.** Substituer un `ColorScheme` entier
/// recolorerait aussi boutons, cartes, séparateurs et états d'erreur de l'hôte —
/// un effet de bord bien plus large que le problème résolu, et impossible à
/// annuler localement. La primitive se borne aux **rôles de texte et d'icône**.
///
/// ## Impact pour un hôte
///
/// - Hôte **passif** (slot nu : `Text('x')`, `Icon(...)`) : rendu **inchangé** —
///   il héritait déjà de la couleur via le duo d'enveloppes.
/// - Hôte dont **le slot lit le thème** (`Theme.of(c).textTheme.*`,
///   `Theme.of(c).iconTheme.color`) : rendu **corrigé** — la couleur passe de
///   l'ambiante à celle voulue par le socle. C'est le correctif.
@immutable
class ZForegroundOverride extends StatelessWidget {
  /// Impose [color] au premier plan de [child].
  const ZForegroundOverride({
    required this.color,
    required this.child,
    super.key,
    this.iconSize,
  });

  /// Couleur de premier plan imposée — **paramètre**, jamais un littéral
  /// (FR-26). L'appelant la résout depuis `ColorScheme` / `ZcrudTheme`.
  final Color color;

  /// Taille d'icône imposée conjointement. `null` ⇒ la taille ambiante est
  /// conservée (la primitive ne touche alors QUE la couleur).
  ///
  /// Ce paramètre existe pour qu'un appelant qui doit fixer taille **et**
  /// couleur n'ait pas à empiler un `IconTheme.merge` supplémentaire — ce qui
  /// rouvrirait précisément le chemin que la garde de source interdit.
  final double? iconSize;

  /// Contenu coloré. Il est construit **sous** les enveloppes : un builder
  /// d'hôte qui lit `Theme.of(context)`, `DefaultTextStyle.of(context)` ou
  /// `IconTheme.of(context)` pour se colorer lui-même y trouve donc bien la
  /// couleur imposée, et non la couleur ambiante.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData ambient = Theme.of(context);

    // 🔴 LE point de la CR-IFFD-42 : `textTheme.apply(bodyColor:, displayColor:)`
    // repeint la couleur de CHAQUE rôle typographique (`titleSmall` compris).
    // Sans lui, un slot stylé depuis `Theme.of(context).textTheme.*` récupère la
    // couleur AMBIANTE, qui écrase le `DefaultTextStyle` posé ci-dessous.
    //
    // `copyWith` cible les seuls rôles de TEXTE et d'ICÔNE : le `ColorScheme`
    // reste celui de l'hôte, donc ses boutons ne sont pas détournés.
    final ThemeData overridden = ambient.copyWith(
      textTheme: ambient.textTheme.apply(
        bodyColor: color,
        displayColor: color,
      ),
      iconTheme: ambient.iconTheme.copyWith(color: color, size: iconSize),
    );

    // Le widget `Theme` réinstalle lui-même un `IconTheme` (celui de
    // `ThemeData.iconTheme`) au-dessus de son enfant ; les `merge` internes
    // restent néanmoins nécessaires pour les contenus qui héritent sans passer
    // par `Theme.of` — et, posés SOUS le `Theme`, ils gagnent.
    return Theme(
      data: overridden,
      child: IconTheme.merge(
        data: IconThemeData(color: color, size: iconSize),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: color),
          child: child,
        ),
      ),
    );
  }
}
