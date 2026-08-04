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

import 'z_folder_card.dart' show zResolveCardShadowDecoration;

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
    this.aboveTitle,
    this.subtitle,
    this.belowSubtitle,
    this.badge,
    this.trailing,
    this.progress,
    this.progressMaxWidth = 120,
    this.hidesTrailingWhileBusy = true,
    this.onTap,
    this.onLongPress,
    this.borderSide,
    this.borderRadius,
    this.accent,
    this.semanticLabel,
    this.contentPadding,
    this.margin,
    this.titleStyle,
    this.subtitleStyle,
    this.titleMaxLines = 1,
    super.key,
  });

  /// Libellé principal — **seul slot requis**.
  final String title;

  /// Icône ou vignette en tête de carte (`null` ⇒ aucun espace réservé).
  final Widget? leading;

  /// Contenu rendu **AU-DESSUS de [title]**, dans la même colonne (**CR-IFFD-47**).
  ///
  /// Pendant EXACT de [belowSubtitle] (CR-LEX-75/CR-IFFD-37) : même type, même
  /// colonne, même espacement (`gapS`), même traitement sémantique (contenu
  /// d'hôte **non repris** dans le `label` de la carte, donc **non exclu** — le
  /// masquer le rendrait muet sans rien dédupliquer), et même **coût vertical
  /// nul en cellule contrainte** (`Flexible` en fit LOOSE : le slot *participe*
  /// à la hauteur allouée au lieu de s'y *ajouter*).
  ///
  /// ⚠️ **Pourquoi [leading] ne pouvait pas en tenir lieu** : il vit dans la
  /// `Row` de tête, donc **à côté** du bloc titre — pas au-dessus. Un ordre de
  /// lecture « ornement, puis énoncé » (celui de la carte de flashcard de
  /// référence : accent, badge de type, balises, **puis** énoncé) était donc
  /// **inatteignable** avec les slots existants, et obligeait à réécrire la
  /// carte au lieu de la composer.
  ///
  /// `null` ⇒ **rendu strictement inchangé** (aucun nœud, aucun espacement).
  final Widget? aboveTitle;

  /// Libellé secondaire sous le titre.
  final String? subtitle;

  /// Contenu secondaire rendu **sous [subtitle]**, dans la même colonne que
  /// [title] (**CR-LEX-75**) : puce d'état, chip, méta-information.
  ///
  /// ⚠️ **Pourquoi [progress] ne pouvait pas en tenir lieu**, pour deux raisons
  /// distinctes : (1) il est rendu dans la `Row` de tête, donc **à côté** du
  /// bloc titre/sous-titre et non dessous — l'y placer déplace la lecture de la
  /// carte ; (2) il est **borné à [progressMaxWidth]**, borne justifiée pour un
  /// `LinearProgressIndicator` (CR-IFFD-20) mais qui **tronque un libellé** —
  /// mesuré chez un hôte : `RenderFlex overflowed` de 41 px, et cette largeur
  /// **dépend de la locale** (7 langues, dont l'arabe) ⇒ aucune valeur codée en
  /// dur ne serait sûre. Ce slot n'impose donc **aucune contrainte de largeur**.
  ///
  /// Il se rend correctement que [subtitle] soit fourni ou non.
  ///
  /// ♿ **Sa sémantique est PRÉSERVÉE**, comme celle de [badge] (CR-LEX-71) :
  /// le contenu vient de l'hôte et n'est **pas** repris dans le `label` de la
  /// carte, donc l'en exclure ne préviendrait aucune double annonce — cela le
  /// rendrait seulement muet.
  ///
  /// 📐 **Coût vertical NUL en cellule contrainte (CR-IFFD-37)** : le slot
  /// **participe** à la hauteur allouée au lieu de s'y **ajouter** — espacement
  /// compris. Une grille dense (hauteur d'item fixe) débordait sur *chaque*
  /// carte dès que le slot était rempli ; désormais, toute hauteur où la carte
  /// tient **sans** le slot est une hauteur où elle tient **avec**. À l'extrême,
  /// c'est le contenu du slot qui se borne au reliquat, jamais la carte qui
  /// déborde. Même correction sur `ZFolderCard` et, par passe-plat, sur
  /// `ZStudyNoteCard` : les trois cartes sœurs se comportent à l'identique.
  ///
  /// `null` ⇒ **rendu strictement inchangé** (aucun nœud, aucun espacement).
  final Widget? belowSubtitle;

  /// Qualificatif court du contenu (type, extension, état). Le socle le pose et
  /// le met en forme ; **il n'en interprète jamais le contenu**.
  ///
  /// ♿ **Sa sémantique est PRÉSERVÉE** (CR-LEX-71) : un `Semantics` posé ici
  /// par l'hôte — un cadenas « lecture seule », par exemple — est réellement
  /// annoncé au lecteur d'écran, comme pour [leading] et [trailing]. Seuls
  /// [title] et [subtitle] sont exclus, parce qu'eux sont déjà portés par le
  /// `label` de la carte.
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
  ///
  /// ⚠️ **Piège du défaut `true` (CR-LEX-75)** : dès que [progress] est rempli,
  /// [trailing] — souvent un **menu contextuel** — **disparaît pendant tout le
  /// traitement**. Un hôte dont le trailing porte une action de
  /// **RÉCUPÉRATION** (annuler, supprimer un import bloqué) perd donc son seul
  /// recours au moment précis où il en a besoin, sans qu'aucun test ne rougisse.
  /// Un tel hôte doit passer `false`.
  final bool hidesTrailingWhileBusy;

  /// Activation de la carte. `null` **et** [onLongPress] `null` ⇒ carte non
  /// interactive : **aucun** `InkWell`, et pas de rôle `button` annoncé (AD-45 :
  /// l'absence de capacité est structurelle, pas un bouton désactivé).
  final VoidCallback? onTap;

  /// Appui long sur la carte (**CR-IFFD-47**) — typiquement l'ouverture d'un
  /// menu contextuel par l'hôte. `null` ⇒ capacité **ABSENTE** (AD-4).
  ///
  /// ♿ Un appui long est **inatteignable au lecteur d'écran** s'il n'est pas
  /// déclaré : il est donc porté par le **nœud sémantique de la carte**
  /// (`Semantics(onLongPress:)`), comme l'est déjà [onTap] — jamais laissé au
  /// seul `InkWell`, dont la sémantique est exclue.
  ///
  /// ⚠️ Il ne rend **pas** la carte « bouton » à lui seul : le rôle `button`
  /// reste conditionné à [onTap] (un appui long n'est pas une activation
  /// primaire, et l'annoncer comme telle mentirait sur la cible).
  final VoidCallback? onLongPress;

  /// Contour explicite de la carte (**CR-IFFD-19**).
  ///
  /// `null` ⇒ la forme vient de `CardThemeData.shape` s'il est fourni, sinon du
  /// jeton `radiusM` — c'est-à-dire **exactement** le rendu antérieur. Ce slot
  /// est une capacité qui manquait, pas un changement de défaut.
  final BorderSide? borderSide;

  /// Rayon d'angle EXPLICITE de la carte (**CR-IFFD-56**).
  ///
  /// `null` ⇒ le rayon vient du jeton `radiusM` (ou de `CardThemeData.shape`
  /// s'il est fourni et qu'aucun [borderSide] n'est passé) — c'est-à-dire
  /// **exactement** le rendu antérieur. Ce slot est une capacité qui manquait
  /// (le rendu de référence des cartes d'étude exige un rayon de carte
  /// distinct du `radiusM` global), pas un changement de défaut — même motif
  /// que [borderSide] (CR-IFFD-19).
  final Radius? borderRadius;

  /// Décor d'accent superposé, fourni par l'hôte.
  ///
  /// Un [Widget] permet autant une barre, une texture qu'un dégradé résolu par
  /// l'application, sans imposer de couleur ni de dégradé par défaut. Il est
  /// ignoré par les gestes et la sémantique : il ne transforme pas un décor en
  /// contrôle. `null` conserve strictement le rendu historique.
  final Widget? accent;

  /// Libellé sémantique de la carte entière. Repli : [title] — complété de
  /// [subtitle] pour que le lecteur d'écran annonce la carte comme un tout
  /// plutôt que comme une suite de fragments.
  final String? semanticLabel;

  /// Marge intérieure de la carte (**CR-LEX-70**).
  ///
  /// Le jeton `gapM` servait à la fois de **padding de carte** et
  /// d'**espacement inter-slots** : deux rôles pour un seul token, donc aucune
  /// valeur ne pouvait satisfaire un hôte voulant 12 de padding et 16 de gap.
  /// Ce slot sépare les deux rôles. `null` ⇒ `EdgeInsetsDirectional.all(gapM)`,
  /// c'est-à-dire **exactement** le rendu antérieur.
  final EdgeInsetsGeometry? contentPadding;

  /// Marge **extérieure** de la carte (**CR-LEX-73**).
  ///
  /// Priorité : ce slot > `CardThemeData.margin` du thème de l'hôte >
  /// `EdgeInsets.zero` (le défaut historique, strictement préservé quand ni
  /// l'un ni l'autre n'est fourni). Même motif que `CardThemeData.shape`
  /// (CR-IFFD-19 / CR-LEX-61) : une marge écrite en dur rend la marge du thème
  /// inatteignable et force chaque hôte à la réécrire dans un `Padding`
  /// externe.
  final EdgeInsetsGeometry? margin;

  /// Style du [title] (**CR-LEX-72**). `null` ⇒ `textTheme.titleSmall`.
  final TextStyle? titleStyle;

  /// Style du [subtitle] (**CR-LEX-72**). `null` ⇒ `textTheme.bodySmall`.
  ///
  /// Aucune couleur n'est imposée par le socle (FR-26) : un hôte qui veut
  /// atténuer son sous-titre en `onSurfaceVariant` le fait par ce slot ou par
  /// son `textTheme`.
  final TextStyle? subtitleStyle;

  /// Nombre maximal de lignes du [title] (**CR-LEX-72**). Défaut `1`, le
  /// comportement historique ; une valeur ≤ 0 est ignorée et replie sur `1`
  /// plutôt que de produire une contrainte invalide (AD-10).
  final int titleMaxLines;

  @override
  Widget build(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    final textTheme = Theme.of(context).textTheme;
    final busy = progress != null;

    // CR-LEX-70 — le padding de carte et l'espacement inter-slots sont deux
    // rôles distincts : le premier est injectable, le second reste le jeton.
    final content = Padding(
      padding: contentPadding ?? EdgeInsetsDirectional.all(theme.gapM),
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
          //
          // CR-LEX-71 — l'exclusion enveloppait la `Column` ENTIÈRE, donc aussi
          // `badge` : un cadenas « lecture seule » posé par l'hôte était visible
          // à l'œil et MUET au lecteur d'écran, à rebours de ce commentaire. La
          // raison d'être de l'exclusion est la DOUBLE ANNONCE de `title`/
          // `subtitle`, qui sont déjà dans le `label` de la carte ; `badge`, lui,
          // n'y est PAS — l'en sortir ne peut donc rien dupliquer. L'exclusion
          // est désormais posée sur les deux `Text` eux-mêmes : même layout,
          // portée réellement conforme à la dartdoc.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // CR-IFFD-47 — pendant EXACT de `belowSubtitle` : `Flexible`
                // en fit LOOSE (espacement COMPRIS, d'où le `Padding` et non
                // un `SizedBox` frère), pour que le slot PARTICIPE à la hauteur
                // allouée en cellule contrainte au lieu de s'y AJOUTER (leçon
                // CR-IFFD-37 : une grille dense débordait sur *chaque* carte).
                if (aboveTitle != null)
                  Flexible(
                    child: Padding(
                      padding: EdgeInsetsDirectional.only(bottom: theme.gapS),
                      child: aboveTitle!,
                    ),
                  ),
                Row(
                  children: <Widget>[
                    Flexible(
                      child: ExcludeSemantics(
                        child: Text(
                          title,
                          style: titleStyle ?? textTheme.titleSmall,
                          maxLines: titleMaxLines > 0 ? titleMaxLines : 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    if (badge != null) ...<Widget>[
                      SizedBox(width: theme.gapS),
                      badge!,
                    ],
                  ],
                ),
                if (subtitle != null)
                  ExcludeSemantics(
                    child: Text(
                      subtitle!,
                      style: subtitleStyle ?? textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                // CR-LEX-75 — contenu secondaire SOUS le sous-titre, dans la
                // `Column` et **sans borne de largeur** : `progress`, borné à
                // 120 dp dans la `Row` de tête, tronquait toute puce d'état
                // localisée (débordement mesuré de 41 px, variable selon la
                // locale). Volontairement HORS `ExcludeSemantics`, comme
                // `badge` (CR-LEX-71) : ce contenu n'est pas dans le `label` de
                // la carte, l'exclure le rendrait muet sans rien dédupliquer.
                //
                // 🔴 CR-IFFD-37 — le slot AJOUTAIT sa hauteur à la colonne au
                // lieu d'y PARTICIPER : dans une cellule de hauteur fixe
                // (grille dense), cette `Column` sizée au contenu et à enfants
                // tous INFLEXIBLES débordait la hauteur que la `Row` lui prête
                // (`RenderFlex overflowed` mesuré dès 210 dp). Le `Flexible`
                // (fit LOOSE) rend le slot — espacement COMPRIS, d'où le
                // `Padding` en lieu et place du `SizedBox` — comptable de la
                // contrainte : hauteur naturelle tant qu'il y a la place,
                // reliquat sinon. Le titre et le sous-titre, eux, gardent
                // exactement le comportement qu'ils avaient sans le slot : le
                // slot ne coûte donc plus rien de plus que son absence.
                // En hauteur NON BORNÉE, un `Flexible` en fit LOOSE sous une
                // `Column(MainAxisSize.min)` est licite : `RenderFlex` le
                // traite alors comme un enfant ordinaire (rendu inchangé).
                if (belowSubtitle != null)
                  Flexible(
                    child: Padding(
                      padding: EdgeInsetsDirectional.only(top: theme.gapS),
                      child: belowSubtitle!,
                    ),
                  ),
              ],
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
          if (trailing != null &&
              !(busy && hidesTrailingWhileBusy)) ...<Widget>[
            SizedBox(width: theme.gapM),
            trailing!,
          ],
        ],
      ),
    );

    final tap = onTap;
    final longPress = onLongPress;
    // CR-IFFD-19 — un `shape:` explicite l'emporte sur `CardThemeData.shape` :
    // en le construisant en dur, la carte rendait TOUTE bordure d'hôte
    // inatteignable — ni par le thème, ni par un slot. Le rayon venait bien d'un
    // jeton, mais la FORME, elle, échappait au thème.
    //
    // Priorité : `side` du slot > `CardThemeData.shape` du thème > jeton `radiusM`
    // (le défaut historique, strictement préservé quand rien n'est fourni).
    final CardThemeData cardTheme = CardTheme.of(context);
    final themed = cardTheme.shape;
    // CR-IFFD-56 — `borderRadius` explicite > `CardThemeData.shape` du thème
    // (comme `borderSide` : un slot explicite prime le thème) > jeton
    // `radiusM` (défaut historique, strictement préservé à `null`).
    final Radius corner = borderRadius ?? theme.radiusM;
    final ShapeBorder shape = borderSide != null || borderRadius != null
        ? RoundedRectangleBorder(
            borderRadius: BorderRadius.all(corner),
            side: borderSide ?? BorderSide.none,
          )
        : themed ??
              RoundedRectangleBorder(
                borderRadius: BorderRadius.all(corner),
              );

    // CR-IFFD-27 — les jetons `ZcrudTheme.cardShadow*` n'étaient lus par AUCUN
    // widget. La CR visait les DEUX cartes porteuses du défaut, pour ne pas le
    // voir réapparaître sur une troisième. `null` (aucun jeton) ⇒ arbre et
    // rendu STRICTEMENT identiques à l'historique.
    final BoxDecoration? shadow = zResolveCardShadowDecoration(
      context,
      shape: shape,
    );
    // Priorité slot > thème > zéro (le défaut historique).
    final EdgeInsetsGeometry cardMargin =
        margin ?? cardTheme.margin ?? EdgeInsets.zero;

    final Widget innerCard = Card(
      // CR-LEX-73 — même motif que `shape` : une marge en dur rendait la
      // marge du `CardTheme` de l'hôte inatteignable et l'obligeait à la
      // réécrire dans un `Padding` externe.
      //
      // Quand l'ombre des jetons est active, la marge passe à un `Padding`
      // externe : la boîte ombrée doit épouser la carte, pas sa marge.
      margin: shadow == null ? cardMargin : EdgeInsets.zero,
      shape: shape,
      // Deux ombres ne se superposent pas : l'élévation native cède la place.
      elevation: shadow == null ? null : 0,
      clipBehavior: Clip.antiAlias,
      child: tap == null && longPress == null
          // AD-45 — pas d'`InkWell` inerte : l'absence d'activation est
          // structurelle, elle ne se rend pas comme un bouton éteint.
          // CR-IFFD-47 : la condition porte désormais sur les DEUX gestes —
          // une carte qui n'a QUE l'appui long doit bien être activable.
          ? _withAccent(content)
          : InkWell(
              onTap: tap,
              onLongPress: longPress,
              customBorder: shape,
              // `excludeFromSemantics` : l'encre et le tap de pointeur sont
              // conservés, mais l'action sémantique est portée UNE SEULE fois
              // — par le nœud de la carte. Sans cela, le lecteur d'écran
              // verrait un bouton imbriqué dans un bouton.
              excludeFromSemantics: true,
              child: _withAccent(content),
            ),
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
      // CR-IFFD-47 — MÊME raison pour l'appui long : l'`InkWell` étant exclu de
      // la sémantique, un `onLongPress` qui n'y serait pas déclaré serait
      // INATTEIGNABLE au lecteur d'écran (AD-13).
      onLongPress: longPress,
      label:
          semanticLabel ?? (subtitle == null ? title : '$title, ${subtitle!}'),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: kZStudyToolsItemMinHeight),
        child: shadow == null
            ? innerCard
            : Padding(
                padding: cardMargin,
                child: DecoratedBox(decoration: shadow, child: innerCard),
              ),
      ),
    );
  }

  Widget _withAccent(Widget content) {
    if (accent == null) return content;
    return Stack(
      fit: StackFit.passthrough,
      children: <Widget>[
        content,
        PositionedDirectional(
          top: 0,
          start: 0,
          end: 0,
          child: IgnorePointer(child: ExcludeSemantics(child: accent!)),
        ),
      ],
    );
  }
}
