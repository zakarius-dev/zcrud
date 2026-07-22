/// Carte d'item d'outils d'étude — **primitive de base + slots** (CR-IFFD-16).
///
/// `ZStudyToolsSectionSpec.itemBuilder` est fourni par l'**hôte** : le socle
/// livrait le *layout de section* (titre, compteur, grille, repli, actions
/// d'en-tête) et laissait **toute la carte d'item** à l'application. Chaque hôte
/// réimplémentait donc les mêmes ornements — et, avec eux, refaisait à chaque
/// fois le travail d'accessibilité (cible ≥ 48 dp, `Semantics`, RTL).
///
/// **Voie B, arbitrée par l'owner** : les *ornements* sont communs à toutes les
/// applications d'étude ; les *items* ne le sont pas — un document, une carte
/// mémoire et une note n'ont ni le même contenu ni les mêmes actions. Une carte
/// entièrement fournie par le socle serait rigide ; le statu quo fait tout
/// réécrire. La base + slots capture le commun sans figer le spécifique.
///
/// ⚠️ **Ce que cette carte NE connaît PAS**, et ne doit jamais connaître : les
/// *types* d'items d'un hôte (document / note / carte mentale), ses règles de
/// permissions, sa nomenclature d'extensions. Tout cela arrive **par les slots**.
/// Le socle fournit la structure et la mise en forme, jamais la sémantique
/// métier. Un slot qui aurait besoin de savoir « quel type d'item » serait le
/// signe d'une frontière mal placée.
///
/// Tous les slots sont **optionnels et `null` par défaut** : une carte réduite à
/// son [title] rend exactement ce qu'un `ListTile` rendait, sans ornement.
///
/// AD-13 : la carte entière est une **cible d'activation unique** ≥ 48 dp portant
/// un `Semantics(button:)` lorsqu'elle est activable, et **aucun** inset ou
/// alignement non directionnel (RTL). FR-26 : aucune couleur codée en dur — tout
/// vient de `ZcrudTheme`/`Theme.of(context)`.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Hauteur minimale d'une cible tactile (AD-13). La carte ne descend jamais
/// en dessous, quels que soient les slots fournis.
const double kZStudyToolsItemMinHeight = 48;

/// Carte d'item d'étude à **slots** — primitive de base réutilisable par tout
/// hôte du socle (CR-IFFD-16).
///
/// ```dart
/// ZStudyToolsItemCard(
///   leading: const Icon(Icons.description_outlined),
///   title: 'Cours de chimie.pdf',
///   subtitle: 'Modifié hier',
///   badge: const Text('PDF'),          // qualificatif fourni par l'hôte
///   trailing: monMenuContextuel,       // le socle ignore ce qu'il contient
///   onTap: () => ouvrir(doc),
/// )
/// ```
class ZStudyToolsItemCard extends StatelessWidget {
  /// Construit une carte d'item ; seul [title] est requis.
  const ZStudyToolsItemCard({
    required this.title,
    this.leading,
    this.subtitle,
    this.badge,
    this.trailing,
    this.progress,
    this.progressMaxWidth = 120,
    this.hidesTrailingWhileBusy = true,
    this.onTap,
    this.borderSide,
    this.semanticLabel,
    super.key,
  });

  /// Libellé principal — **seul slot requis**.
  final String title;

  /// Icône ou vignette en tête de carte (`null` ⇒ aucun espace réservé).
  final Widget? leading;

  /// Libellé secondaire sous le titre.
  final String? subtitle;

  /// Qualificatif court du contenu (type, extension, état). Le socle le pose et
  /// le met en forme ; **il n'en interprète jamais le contenu**.
  final Widget? badge;

  /// Zone d'actions de fin de carte — y compris un menu contextuel fourni par
  /// l'hôte, avec ses propres règles de droits (que le socle ignore).
  final Widget? trailing;

  /// Indicateur de traitement en cours (téléversement, conversion, génération).
  ///
  /// ⚠️ **Contrainte de layout (CR-IFFD-20)** : le slot est rendu dans une
  /// `Row`, donc dans un espace horizontal **non borné**. Un
  /// `LinearProgressIndicator` **nu** y lève *« unbounded width »* — un
  /// `CircularProgressIndicator`, qui s'auto-dimensionne, passe. La carte borne
  /// donc elle-même le slot à [progressMaxWidth] : la variante linéaire est
  /// utilisable telle quelle, sans que l'hôte ait à deviner l'exigence.
  final Widget? progress;

  /// Largeur maximale allouée au slot [progress].
  ///
  /// Existe parce qu'un indicateur **linéaire** n'a pas de largeur intrinsèque :
  /// sans borne il lèverait. Une valeur nulle ou négative est ignorée (repli sur
  /// le défaut) plutôt que de produire une contrainte invalide (AD-10).
  final double progressMaxWidth;

  /// Politique d'éviction de [trailing] pendant un traitement (**CR-IFFD-21**).
  ///
  /// Le défaut `true` évince [trailing] : offrir des actions sur une ressource
  /// en cours de traitement invite à lancer une opération **concurrente**
  /// dessus.
  ///
  /// ⚠️ **Mais toutes les actions d'un `trailing` ne sont pas concurrentes.**
  /// Écouter une note pendant qu'on la résume est une **consultation**, pas une
  /// mutation. L'éviction inconditionnelle rangeait donc sous « action » des
  /// choses qui n'en sont pas — et **seul l'hôte** sait lesquelles des siennes
  /// sont concurrentes. Passer `false` conserve [trailing] à côté de [progress] ;
  /// c'est alors à l'hôte de n'y laisser que le consultable.
  final bool hidesTrailingWhileBusy;

  /// Activation de la carte. `null` ⇒ carte non interactive : **aucun**
  /// `InkWell`, et pas de rôle `button` annoncé (AD-45 : l'absence de capacité
  /// est structurelle, pas un bouton désactivé).
  final VoidCallback? onTap;

  /// Contour explicite de la carte (**CR-IFFD-19**).
  ///
  /// `null` ⇒ la forme vient de `CardThemeData.shape` s'il est fourni, sinon du
  /// jeton `radiusM` — c'est-à-dire **exactement** le rendu antérieur. Ce slot
  /// est une capacité qui manquait, pas un changement de défaut.
  final BorderSide? borderSide;

  /// Libellé sémantique de la carte entière. Repli : [title] — complété de
  /// [subtitle] pour que le lecteur d'écran annonce la carte comme un tout
  /// plutôt que comme une suite de fragments.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    final textTheme = Theme.of(context).textTheme;
    final busy = progress != null;

    final content = Padding(
      padding: EdgeInsetsDirectional.all(theme.gapM),
      child: Row(
        children: <Widget>[
          if (leading != null) ...<Widget>[
            leading!,
            SizedBox(width: theme.gapM),
          ],
          // ExcludeSemantics CIBLÉ sur les seuls libellés : le nœud de la carte
            // les porte déjà dans son `label`, et les répéter ferait annoncer
            // l'item deux fois. ⚠️ Volontairement NON étendu à `leading`/`badge`/
            // `trailing` : exclure tout le contenu rendrait le menu contextuel de
            // l'hôte INATTEIGNABLE au lecteur d'écran — l'a11y qu'on prétend
            // apporter serait retirée d'une main pendant qu'on la donne de l'autre.
          Expanded(
            child: ExcludeSemantics(
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        title,
                        style: textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (badge != null) ...<Widget>[
                      SizedBox(width: theme.gapS),
                      badge!,
                    ],
                  ],
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          // CR-IFFD-20 — le slot est BORNÉ par la carte. Sans cela un
          // `LinearProgressIndicator` nu lève « unbounded width » dans la `Row` :
          // une exigence de layout réelle, INVISIBLE depuis la signature du slot.
          if (busy) ...<Widget>[
            SizedBox(width: theme.gapM),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: progressMaxWidth > 0 ? progressMaxWidth : 120,
              ),
              child: progress,
            ),
          ],
          // CR-IFFD-21 — l'éviction est une POLITIQUE, plus une fatalité.
          if (trailing != null && !(busy && hidesTrailingWhileBusy)) ...<Widget>[
            SizedBox(width: theme.gapM),
            trailing!,
          ],
        ],
      ),
    );

    final tap = onTap;
    // CR-IFFD-19 — un `shape:` explicite l'emporte sur `CardThemeData.shape` :
    // en le construisant en dur, la carte rendait TOUTE bordure d'hôte
    // inatteignable — ni par le thème, ni par un slot. Le rayon venait bien d'un
    // jeton, mais la FORME, elle, échappait au thème.
    //
    // Priorité : `side` du slot > `CardThemeData.shape` du thème > jeton `radiusM`
    // (le défaut historique, strictement préservé quand rien n'est fourni).
    final themed = CardTheme.of(context).shape;
    final ShapeBorder shape = borderSide != null
        ? RoundedRectangleBorder(
            borderRadius: BorderRadius.all(theme.radiusM),
            side: borderSide!,
          )
        : themed ??
            RoundedRectangleBorder(
              borderRadius: BorderRadius.all(theme.radiusM),
            );

    return Semantics(
      container: true,
      button: tap != null,
      // L'action d'activation est portée par le NŒUD de la carte, pas par
      // l'`InkWell` : le sous-arbre est exclu de la sémantique (sinon le lecteur
      // d'écran annonce deux fois le même item), ce qui emporterait aussi
      // l'action tactile de l'`InkWell`. Sans ce `onTap`, la carte serait
      // annoncée « bouton » et resterait INACTIVABLE au lecteur d'écran.
      onTap: tap,
      label: semanticLabel ??
          (subtitle == null ? title : '$title, ${subtitle!}'),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: kZStudyToolsItemMinHeight,
        ),
        child: Card(
          margin: EdgeInsets.zero,
          shape: shape,
          clipBehavior: Clip.antiAlias,
          child: tap == null
              // AD-45 — pas d'`InkWell` inerte : l'absence d'activation est
              // structurelle, elle ne se rend pas comme un bouton éteint.
              ? content
              : InkWell(
                  onTap: tap,
                  customBorder: shape,
                  // `excludeFromSemantics` : l'encre et le tap de pointeur sont
                  // conservés, mais l'action sémantique est portée UNE SEULE fois
                  // — par le nœud de la carte. Sans cela, le lecteur d'écran
                  // verrait un bouton imbriqué dans un bouton.
                  excludeFromSemantics: true,
                  child: content,
                ),
        ),
      ),
    );
  }
}
