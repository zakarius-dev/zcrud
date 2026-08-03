/// `ZInvertedSurface` — enveloppe RÉUTILISABLE d'inversion de surface (CR-IFFD-42).
///
/// 🔴 **Pourquoi une enveloppe partagée, et pas un `IconTheme` + un
/// `DefaultTextStyle` recopiés sur chaque surface.**
///
/// Poser un fond opaque (`ColorScheme.inverseSurface`) sans retourner le premier
/// plan rend le contenu illisible. La parade « évidente » —
/// `IconTheme.merge` + `DefaultTextStyle.merge` — ne couvre QUE le contenu qui
/// hérite : un `Text` nu, une `Icon` nue. Elle **n'atteint pas** le contenu
/// stylé depuis `Theme.of(context).textTheme.*`, parce que chaque rôle de
/// `TextTheme` **porte sa propre couleur** (celle du thème ambiant) qui écrase
/// le `DefaultTextStyle` posé au-dessus.
///
/// Conséquence mesurée chez un hôte : `Text(x, style:
/// Theme.of(context).textTheme.titleSmall)` — c'est-à-dire **la façon
/// recommandée** de respecter la typographie d'une application — reste peint en
/// couleur ambiante sur le fond inversé, donc illisible ; tandis qu'un
/// `TextStyle(fontSize: 14)` codé en dur, lui, s'en tire. **Le défaut punit la
/// bonne pratique** : le pire profil possible pour un socle partagé.
///
/// [ZInvertedSurface] ferme les trois chemins d'un coup — `TextTheme`,
/// `DefaultTextStyle`, `IconTheme` — et existe dans `zcrud_core` pour que toute
/// surface d'inversion à venir (sélection, mise en avant, état actif) l'obtienne
/// **gratuitement**, au lieu de rejouer le même défaut une troisième fois.
///
/// **FR-26** : aucune couleur littérale — l'inversion se modélise par le couple
/// de rôles `ColorScheme.inverseSurface` / `ColorScheme.onInverseSurface`, qui
/// est par définition le contraste maximal disponible dans n'importe quel
/// schéma (clair, sombre, seedé).
///
/// **AD-2** : `StatelessWidget` pur-Flutter, aucun gestionnaire d'état.
/// **AD-13** : le padding et le rayon sont directionnels / symétriques ; aucune
/// contrainte de taille n'est imposée au contenu.
library;

import 'package:flutter/material.dart';

/// Surface dont le premier plan est **retourné** pour rester lisible sur un fond
/// `ColorScheme.inverseSurface`.
///
/// ## Ce que l'enveloppe couvre
///
/// | Chemin de style du contenu | Couvert |
/// |---|---|
/// | `Text('x')` nu (hérite du `DefaultTextStyle`) | ✅ |
/// | `Icon(...)` nue (hérite de l'`IconTheme`) | ✅ |
/// | `Text('x', style: Theme.of(c).textTheme.titleSmall)` | ✅ |
/// | tout autre rôle de `TextTheme` (`body*`, `label*`, `display*`, …) | ✅ |
/// | `IconTheme.of(c).color` lu par un builder d'hôte | ✅ |
///
/// ## Ce que l'enveloppe NE couvre PAS — délibérément
///
/// Les composants Material qui résolvent leur premier plan depuis le
/// **`ColorScheme`** et non depuis `TextTheme`/`DefaultTextStyle`/`IconTheme` :
/// `ElevatedButton`, `TextButton`, `FilledButton`, `OutlinedButton`,
/// `IconButton`, `Chip`, `InputDecorator`… Leurs couleurs restent celles du
/// thème ambiant.
///
/// 🔴 **C'est un choix, pas un oubli.** Substituer un `ColorScheme` entier
/// (`inverseSurface` comme `surface`, `onInverseSurface` comme `onSurface`)
/// recolorerait aussi les boutons, les cartes, les séparateurs et les états
/// d'erreur d'un hôte — un effet de bord bien plus large que le problème résolu,
/// et impossible à annuler localement. L'enveloppe se borne donc aux **rôles de
/// texte et d'icône**. Une surface d'inversion qui embarque un bouton doit
/// styler ce bouton elle-même.
@immutable
class ZInvertedSurface extends StatelessWidget {
  /// Enveloppe [child] : fond `inverseSurface` + premier plan `onInverseSurface`.
  const ZInvertedSurface({
    required this.child,
    super.key,
    this.padding,
    this.borderRadius,
    this.paintBackground = true,
  });

  /// Contenu inversé. Il est construit **sous** les enveloppes : un builder
  /// d'hôte qui lit `Theme.of(context)`, `DefaultTextStyle.of(context)` ou
  /// `IconTheme.of(context)` pour se colorer lui-même y trouve donc bien les
  /// valeurs inversées, et non les valeurs ambiantes.
  final Widget child;

  /// Marge intérieure — directionnelle (AD-13). `null` ⇒ aucune.
  final EdgeInsetsDirectional? padding;

  /// Rayon du fond. Ignoré si [paintBackground] est `false`.
  final BorderRadius? borderRadius;

  /// Peindre le fond `ColorScheme.inverseSurface`.
  ///
  /// `false` ⇒ **seul le premier plan** est retourné : pour une surface qui
  /// peint son propre fond inversé (encre, dégradé, sélection animée) tout en
  /// voulant la même garantie de lisibilité.
  final bool paintBackground;

  @override
  Widget build(BuildContext context) {
    final ThemeData ambient = Theme.of(context);
    final ColorScheme scheme = ambient.colorScheme;
    final Color foreground = scheme.onInverseSurface;

    // 🔴 LE point de la CR : `textTheme.apply(bodyColor:, displayColor:)`
    // repeint la couleur de CHAQUE rôle typographique (`titleSmall` compris).
    // Sans lui, un hôte stylant depuis `Theme.of(context).textTheme.*` récupère
    // la couleur AMBIANTE, qui écrase le `DefaultTextStyle` ci-dessous.
    //
    // `copyWith` cible les seuls rôles de TEXTE et d'ICÔNE : le `ColorScheme`
    // reste celui de l'hôte, donc ses boutons ne sont pas détournés.
    final ThemeData inverted = ambient.copyWith(
      textTheme: ambient.textTheme.apply(
        bodyColor: foreground,
        displayColor: foreground,
      ),
      iconTheme: ambient.iconTheme.copyWith(color: foreground),
    );

    // Le widget `Theme` réinstalle lui-même un `IconTheme` (celui de
    // `ThemeData.iconTheme`) au-dessus de son enfant ; les `merge` internes
    // restent néanmoins nécessaires pour les contenus qui héritent sans passer
    // par `Theme.of` — et, posés SOUS le `Theme`, ils gagnent.
    final Widget content = Theme(
      data: inverted,
      child: IconTheme.merge(
        data: IconThemeData(color: foreground),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: foreground),
          child: child,
        ),
      ),
    );

    if (!paintBackground) {
      return padding == null
          ? content
          : Padding(padding: padding!, child: content);
    }
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: scheme.inverseSurface,
        borderRadius: borderRadius,
      ),
      child: content,
    );
  }
}
