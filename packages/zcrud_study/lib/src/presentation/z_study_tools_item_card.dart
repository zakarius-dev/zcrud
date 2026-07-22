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
    this.onTap,
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
  /// ⚠️ Rendu **à la place** de [trailing] tant qu'il est non-`null` : afficher
  /// des actions sur un item en cours de traitement invite à déclencher une
  /// opération concurrente sur une ressource instable.
  final Widget? progress;

  /// Activation de la carte. `null` ⇒ carte non interactive : **aucun**
  /// `InkWell`, et pas de rôle `button` annoncé (AD-45 : l'absence de capacité
  /// est structurelle, pas un bouton désactivé).
  final VoidCallback? onTap;

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
          // Le traitement en cours ÉVINCE les actions (cf. [progress]).
          if (busy) ...<Widget>[
            SizedBox(width: theme.gapM),
            progress!,
          ] else if (trailing != null) ...<Widget>[
            SizedBox(width: theme.gapM),
            trailing!,
          ],
        ],
      ),
    );

    final tap = onTap;
    final shape = RoundedRectangleBorder(
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
