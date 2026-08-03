/// `ZSubfolderNavSpec` — descripteur AGRÉGÉ (immuable) de la navigation de
/// sous-dossiers de `ZStudyFolderDetail` (SUF-3, T1).
///
/// Regroupe la liste des sous-dossiers, le libellé de l'item racine, les slots
/// (item builder, bouton « Ajouter », réordonnancement) et **tous** les libellés
/// a11y — tous **injectés** (jamais codés en dur, AD-13/FR-26). Il ne porte
/// **aucun état runtime** : la sélection, le repli et la largeur de la sidebar
/// sont détenus par le widget (`ValueNotifier`, AD-2/AD-15) — ce descripteur ne
/// fournit que la configuration et les bornes.
///
/// L'item de sous-dossier est rendu via [itemBuilder] **injectable** (défaut =
/// rangée neutre thémée) : `ZStudyFolderDetail` ne se couple donc PAS à la
/// signature exacte de `ZFolderCard` (D3/R-SUF2) — l'hôte peut y brancher un
/// rendu basé `ZFolderCard` s'il le souhaite.
library;

import 'package:flutter/widgets.dart';

import 'z_subfolder_ref.dart';

/// Construit l'item visuel d'un sous-dossier. [selected] permet à l'hôte de
/// styler la sélection ; le widget applique DÉJÀ sa propre surbrillance neutre
/// autour de l'item (ce builder n'est donc PAS obligé de la gérer).
///
/// **Le même builder sert les DEUX côtés du seuil de bascule** (sidebar ≥ 600 dp
/// / sélecteur compact < 600 dp — contrat R-SUF2), or leurs contraintes de mise
/// en page sont INCOMPATIBLES : la sidebar borne la largeur, le sélecteur
/// compact ne la borne pas (rangée défilante). Un `ListTile`, un `Expanded` ou
/// un `Spacer` exigent une largeur bornée et lèvent
/// `BoxConstraints forces an infinite width` côté compact.
///
/// ⚠️ **Ne PAS tenter de lire la contrainte via un `LayoutBuilder`** : côté
/// compact l'item est enveloppé dans un `ChoiceChip`, qui calcule un *dry
/// layout* de son enfant ⇒ `The _RenderLayoutBuilder class does not support dry
/// layout`. La voie est structurellement fermée.
///
/// ✅ **Lire le mode via le `context` DÉJÀ reçu** — aucun paramètre
/// supplémentaire, aucune duplication de la connaissance du seuil :
///
/// ```dart
/// itemBuilder: (context, ref, selected) =>
///     switch (ZSubfolderLayoutMode.of(context)) {
///       ZSubfolderLayoutMode.sidebar => ListTile(title: Text(ref.label)),
///       ZSubfolderLayoutMode.compact => Text(ref.label),
///     };
/// ```
typedef ZSubfolderItemBuilder = Widget Function(
  BuildContext context,
  ZSubfolderRef ref,
  bool selected,
);

/// Construit l'**action** d'un item de fratrie — slot TRAILING, distinct du
/// contenu (CR-IFFD-41, point 8).
///
/// 🔴 **Mesuré avant d'ajouter** : ni [ZSubfolderItemBuilder] ni
/// `ZSubfolderNavRenderer` ne servaient déjà ce besoin.
/// * `itemBuilder` construit le CONTENU, qui vit **à l'intérieur** de la zone
///   tapable de l'item : une action posée là est avalée par la sélection (et
///   se retrouverait inversée avec le reste du contenu quand l'item est
///   courant).
/// * `ZSubfolderNavRenderer` le permet, mais au prix du **remplacement de toute
///   la surface** — donc de la feuille modale, de l'indentation et de
///   l'inversion que ce socle rend justement. Ce n'est pas un slot d'action,
///   c'est une sortie de route.
///
/// [refOrNull] `null` ⇒ item RACINE. Rendre `null` ⇒ **aucune action pour cet
/// item** (AD-4) : c'est ainsi que la maquette IFFD n'en pose pas sur la racine.
typedef ZSubfolderItemActionBuilder = Widget? Function(
  BuildContext context,
  ZSubfolderRef? refOrNull,
  bool selected,
);

/// Côté du seuil de bascule sur lequel un [ZSubfolderItemBuilder] est invoqué.
///
/// Publié pour lever l'ambiguïté de mise en page décrite sur
/// [ZSubfolderItemBuilder] : `ZSubfolderSidebar` et `ZSubfolderCompactSelector`
/// posent chacun un [ZSubfolderLayoutScope] AU-DESSUS de l'item (donc au-dessus
/// du `ChoiceChip` du sélecteur compact), et l'hôte le lit par [of]/[maybeOf].
///
/// **Non cassant par construction** : la signature de [ZSubfolderItemBuilder]
/// reste à TROIS paramètres — un builder existant continue de compiler et de
/// rendre à l'identique. C'est le choix retenu contre un 4ᵉ paramètre `mode`,
/// qui aurait forcé chaque hôte à réécrire son builder.
enum ZSubfolderLayoutMode {
  /// Colonne verticale de la sidebar : **largeur BORNÉE**. `ListTile`,
  /// `Expanded`, `Spacer`, `Row` pleine largeur sont utilisables.
  sidebar,

  /// Rangée horizontale défilante du sélecteur compact : **largeur NON bornée**.
  /// L'item doit se dimensionner sur son contenu (`MainAxisSize.min`, aucun
  /// `Expanded`, aucun `ListTile`).
  compact;

  /// Mode courant, ou `null` hors d'une surface de navigation zcrud (l'hôte
  /// réutilise alors son builder ailleurs et décide seul).
  static ZSubfolderLayoutMode? maybeOf(BuildContext context) =>
      ZSubfolderLayoutScope.maybeOf(context);

  /// Mode courant, avec repli documenté sur [compact].
  ///
  /// [compact] est le repli parce que c'est le SEUL mode dont les contraintes
  /// sont satisfaites partout : un item qui se dimensionne sur son contenu rend
  /// sans exception sous une largeur bornée COMME non bornée. Le repli inverse
  /// (`sidebar`) transformerait une absence de scope en
  /// `BoxConstraints forces an infinite width`.
  static ZSubfolderLayoutMode of(BuildContext context) =>
      maybeOf(context) ?? ZSubfolderLayoutMode.compact;
}

/// Scope exposant le [ZSubfolderLayoutMode] courant à l'`itemBuilder` injecté.
///
/// Posé par `ZSubfolderSidebar` ([ZSubfolderLayoutMode.sidebar]) et par
/// `ZSubfolderCompactSelector` ([ZSubfolderLayoutMode.compact]) AU-DESSUS de
/// tout le sous-arbre d'items. L'hôte n'a normalement pas à l'instancier : il
/// lit `ZSubfolderLayoutMode.of(context)`.
class ZSubfolderLayoutScope extends InheritedWidget {
  /// Pose [mode] sur tout [child].
  const ZSubfolderLayoutScope({
    required this.mode,
    required super.child,
    super.key,
  });

  /// Côté du seuil rendu par la surface englobante.
  final ZSubfolderLayoutMode mode;

  /// Mode courant, ou `null` si aucun scope n'englobe [context].
  static ZSubfolderLayoutMode? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<ZSubfolderLayoutScope>()
      ?.mode;

  @override
  bool updateShouldNotify(ZSubfolderLayoutScope oldWidget) =>
      oldWidget.mode != mode;
}

/// Surface de navigation rendue SOUS le seuil de bascule (< 600 dp) —
/// CR-IFFD-40.
///
/// 🔴 **Enum SÉPARÉ de [ZSubfolderLayoutMode], et c'est délibéré.** Ajouter une
/// troisième valeur à [ZSubfolderLayoutMode] aurait cassé tout `switch`
/// exhaustif d'hôte sur ce type — or c'est **le patron que son dartdoc
/// recommande** et qu'un test de ce dépôt exerce
/// (`cr_iffd30_31_lex81_subfolder_nav_test.dart`, `switch (…of(context))` à deux
/// bras). Deux axes distincts, deux types : [ZSubfolderLayoutMode] dit à
/// l'`itemBuilder` **quelles contraintes de layout** il subit ; ce type-ci dit
/// **quelle surface** rend la navigation étroite.
///
/// Les deux surfaces posent `ZSubfolderLayoutMode.compact` : l'item doit se
/// dimensionner sur son contenu dans l'une comme dans l'autre — un `itemBuilder`
/// existant continue donc de rendre à l'identique.
enum ZSubfolderNarrowMode {
  /// **DÉFAUT** — barre de sélection : une seule ligne pleine largeur montrant
  /// l'élément COURANT (repli sur [ZSubfolderNavSpec.allSubfoldersLabel] quand
  /// aucun n'est sélectionné) avec un chevron ; la fratrie ne se déploie qu'à la
  /// demande.
  ///
  /// Corrige le défaut CR-IFFD-40 : dans une rangée défilante, un seul balayage
  /// sortait la sélection du champ visible et l'utilisateur perdait le « où
  /// suis-je ». La question de l'utilisateur est « lequel est actif ? » **avant**
  /// « lesquels existent ? ».
  ///
  /// 🔴 **CR-IFFD-41 — CHANGEMENT DE COMPORTEMENT** (nom du mode inchangé, API
  /// inchangée) : la fratrie se déploie désormais en **feuille modale** (≤ 80 %
  /// de la hauteur d'écran), et non plus **en ligne** sous la barre comme en
  /// v0.34.0. L'hôte de référence (IFFD) a explicitement repris la main sur la
  /// forme, et il ne prétend PAS que le déploiement en ligne fût un défaut :
  /// c'est un arbitrage de gouvernance visuelle, pas une correction.
  ///
  /// Conséquence pour un hôte qui vient d'adopter v0.34.0 : la fratrie n'est
  /// plus poussée dans le flux de la page — elle flotte. Un hôte qui
  /// **compensait** le déploiement en ligne (réserve de hauteur, `scrollTo`,
  /// fermeture pilotée à la sélection) doit **RETIRER sa compensation**.
  selector,

  /// Rangée de puces défilant horizontalement — comportement **historique**
  /// (≤ v0.33.1), conservé à l'identique pour l'hôte qui le demande
  /// explicitement. Aucune rupture d'API : la valeur reste valide et son rendu
  /// est inchangé.
  compact,
}

/// **Où** la navigation de fratrie est rendue dans une page à onglets
/// (`ZStudyFolderDetail`) — CR-IFFD-43.
///
/// 🔴 **Axe INDÉPENDANT du point de rupture.** Ce jeton dit *à quel niveau de la
/// page* vit la navigation ; [ZSubfolderNarrowMode] dit *quelle surface* est
/// rendue sous le seuil. Déduire le placement de la largeur reproduirait, sur
/// l'axe « onglet », l'erreur que CR-IFFD-40 a corrigée sur l'axe « largeur ».
enum ZSubfolderNavPlacement {
  /// **DÉFAUT** — la navigation est construite **dans** l'onglet Matériel, sous
  /// `ZResponsiveLayout` : sidebar ≥ 600 dp, surface étroite < 600 dp. Rendu
  /// strictement identique à celui d'avant CR-IFFD-43.
  ///
  /// Conséquence assumée (c'est le comportement historique) : la navigation
  /// **disparaît** sur les autres onglets.
  withinTab,

  /// La navigation est rendue **une seule fois**, au-dessus de la zone
  /// d'onglets (créneau `ZPageScaffold.aboveTabViews`) : elle devient le
  /// contexte de la page entière, donc visible et actionnable depuis **tous**
  /// les onglets. L'onglet Matériel ne rend alors que son corps filtré — la
  /// navigation n'y est **pas** dupliquée.
  ///
  /// 🔴 **Ce que devient la sidebar en forme large — arbitrage MESURÉ.**
  /// Sous `aboveTabs`, **aucune sidebar n'est rendue, à aucune largeur** : la
  /// surface hissée est la **bande** (`ZSubfolderNarrowNav` : coquille de
  /// l'hôte, barre de sélection, ou rangée de puces selon
  /// [ZSubfolderNavSpec.narrowMode]).
  ///
  /// Ce n'est pas une préférence esthétique, c'est une contrainte de layout
  /// **mesurée** : le créneau `aboveTabViews` est un enfant de `Column` dont le
  /// frère porte l'`Expanded` — il reçoit donc une hauteur **NON bornée**.
  /// `ZSubfolderSidebar` déployée contient un `Expanded` dans sa propre
  /// `Column` (la liste défilante) et lève, mesuré :
  /// *« RenderFlex children have non-zero flex but incoming height constraints
  /// are unbounded »*. Hisser la sidebar est donc **structurellement
  /// impossible**, pas seulement discutable.
  ///
  /// Le sens le confirme : une sidebar est par définition **une colonne du
  /// corps** — donc du contenu d'onglet. Déclarer la navigation « contexte de
  /// page » et la vouloir en colonne de corps sont deux demandes contradictoires
  /// ; `aboveTabs` tranche pour la première.
  ///
  /// Un hôte qui veut la sidebar en forme large et la bande en forme étroite
  /// garde exactement cela : c'est le défaut [withinTab].
  aboveTabs,
}

/// **Où** l'affordance d'ajout de la barre de fratrie est offerte — CR-IFFD-44,
/// manque 1.
///
/// Avant CR-IFFD-44, `ZSubfolderNavSpec.addAction != null` commandait
/// **simultanément** le bouton `+` de la BARRE et le pied « Ajouter… » de la
/// FEUILLE : un hôte dont la référence pose l'ajout à un seul des deux endroits
/// n'avait que « les deux » ou « aucun » — et « aucun » **retire une action
/// réelle**. Ce n'est donc pas un réglage de masquage : l'action est la même,
/// sa cible est la même ; seul son **emplacement** devient adressable.
///
/// 🔴 **Ce jeton vit dans la SPEC, pas dans le thème — et c'est mesuré, pas
/// stylistique.** Trois raisons, dans l'ordre de force :
/// 1. Il décide de la **présence d'un contrôle interactif** dans l'arbre. Faire
///    dépendre l'atteignabilité d'une action d'un `ThemeExtension` ferait de
///    l'a11y une conséquence du thème — un thème doit pouvoir être remplacé
///    sans qu'une action disparaisse. C'est de la **structure** (le même
///    critère qui a placé [ZSubfolderNavPlacement] hors du thème).
/// 2. Il gouverne le rendu de `addAction`/`addLabel`/`addIcon`, qui vivent
///    **déjà** dans la spec. Séparer les deux couperait la capacité en deux
///    canaux d'injection (« tu me donnes l'action ici, tu dis où elle
///    apparaît là »).
/// 3. Un thème est **ambiant** : posé à la racine, il vaudrait pour toutes les
///    fratries de l'app. Le placement de l'ajout est une décision par
///    **descripteur de navigation** — deux pages peuvent légitimement diverger.
///
/// À l'inverse, `ZcrudTheme.subfolderBarPadding` (manque 2) est bien un token de
/// thème : une marge ne fait apparaître ni disparaître aucune action.
///
/// ⚠️ **Sans effet hors de la barre de sélection** ([ZSubfolderNarrowMode.selector]) :
/// la rangée de puces et la sidebar n'ont **pas de feuille**, donc pas de second
/// emplacement à arbitrer. Leur bouton d'ajout reste commandé par le seul
/// `addAction` — y appliquer [sheetOnly] retirerait une action sans lui offrir
/// de remplaçante, ce qui est exactement ce que ce jeton refuse.
enum ZSubfolderAddPlacement {
  /// **DÉFAUT** — l'ajout est offert **aux deux endroits** : bouton `+` de la
  /// barre ET pied de la feuille. Rendu strictement identique à celui d'avant
  /// CR-IFFD-44 ⇒ aucun hôte existant ne bouge.
  barAndSheet,

  /// L'ajout n'est offert que dans la **feuille** (pied). Le `+` de la barre est
  /// **absent de l'arbre** (AD-4) — la barre gagne d'autant en largeur pour son
  /// déclencheur.
  sheetOnly,

  /// L'ajout n'est offert que sur la **barre** (`+`). Le pied de la feuille est
  /// **absent de l'arbre** (AD-4).
  barOnly;

  /// L'affordance est-elle offerte sur la BARRE ?
  bool get inBar => this != ZSubfolderAddPlacement.sheetOnly;

  /// L'affordance est-elle offerte dans la FEUILLE ?
  bool get inSheet => this != ZSubfolderAddPlacement.barOnly;
}

/// Descripteur immuable de la navigation de sous-dossiers.
@immutable
class ZSubfolderNavSpec {
  /// Construit le descripteur. [subfolders] et [allSubfoldersLabel] sont requis.
  const ZSubfolderNavSpec({
    required this.subfolders,
    required this.allSubfoldersLabel,
    this.itemBuilder,
    this.itemActionBuilder,
    this.narrowMode = ZSubfolderNarrowMode.selector,
    this.sidebarHeader,
    this.sheetTitle,
    this.addAction,
    this.addLabel,
    this.addIcon,
    this.addPlacement = ZSubfolderAddPlacement.barAndSheet,
    this.onReorder,
    this.reorderHandleLabel,
    this.moveBeforeLabel,
    this.moveAfterLabel,
    this.collapseLabel,
    this.expandLabel,
    this.resizeLabel,
    this.minSidebarWidth = 300,
    this.maxSidebarWidthFraction = 0.5,
    this.collapsedWidth = 56,
    this.initialSidebarWidth = 300,
    this.onSidebarWidthChanged,
  })  : assert(minSidebarWidth > 0, 'minSidebarWidth doit être > 0'),
        assert(
          maxSidebarWidthFraction > 0 && maxSidebarWidthFraction <= 1,
          'maxSidebarWidthFraction ∈ ]0, 1]',
        ),
        assert(collapsedWidth > 0, 'collapsedWidth doit être > 0');

  /// Sous-dossiers, dans l'ordre d'affichage voulu (l'item racine est ajouté en
  /// tête par le widget — il n'est PAS dans cette liste).
  final List<ZSubfolderRef> subfolders;

  /// Libellé **injecté** de l'item racine « Tous les sous-dossiers »
  /// (`id` de sélection `null`). Toujours présent en tête (AC8).
  final String allSubfoldersLabel;

  /// Constructeur d'item **injectable** (défaut : rangée neutre thémée, D3).
  final ZSubfolderItemBuilder? itemBuilder;

  /// Slot d'**action par item** de la feuille de fratrie (CR-IFFD-41, point 8).
  ///
  /// **`null` ⇒ capacité ABSENTE** (AD-4) : aucun élément trailing dans l'arbre,
  /// rendu strictement inchangé. Cf. [ZSubfolderItemActionBuilder] pour la
  /// mesure qui a justifié un slot dédié plutôt qu'un détournement de
  /// [itemBuilder].
  final ZSubfolderItemActionBuilder? itemActionBuilder;

  /// Titre **injecté** de la feuille de fratrie (CR-IFFD-41, point 4).
  ///
  /// **`null` ⇒ slot ABSENT** (AD-4). C'est un LIBELLÉ : il ne peut donc PAS
  /// être un token de thème (FR-26/NFR-S7 — un paquet ne code aucune chaîne, et
  /// une chaîne visible relève de la l10n de l'hôte). Le préréglage « façon
  /// IFFD » le fournit depuis `example/`, seul endroit du dépôt où une valeur
  /// décorative est admise.
  ///
  /// zcrud ne pose dessus qu'une **typographie dérivée** (`titleLarge`) —
  /// aucune couleur.
  final String? sheetTitle;

  /// Surface de navigation SOUS le seuil de bascule (< 600 dp).
  ///
  /// **Défaut : [ZSubfolderNarrowMode.selector]** (CR-IFFD-40) — changement de
  /// COMPORTEMENT par défaut, **sans rupture d'API** : un hôte qui veut la
  /// rangée de puces historique la redemande en une ligne
  /// (`narrowMode: ZSubfolderNarrowMode.compact`) et retrouve un rendu
  /// strictement identique.
  ///
  /// Sans effet ≥ 600 dp (la sidebar est alors rendue).
  final ZSubfolderNarrowMode narrowMode;

  /// En-tête **injecté** de la sidebar (titre de panneau, p. ex. « Sous-dossiers »).
  ///
  /// **`null` ⇒ slot ABSENT** (AD-4) : rendu strictement inchangé par défaut.
  ///
  /// Rendu UNIQUEMENT par `ZSubfolderSidebar` à l'état **déployé**, sous le
  /// contrôle de repli. Il **disparaît automatiquement à l'état replié** (56 dp)
  /// et n'existe pas dans le sélecteur compact : c'est précisément la décision
  /// qu'un hôte ne peut PAS prendre proprement de l'extérieur sans s'abonner
  /// lui-même à l'état `collapsed`, donc sans rejouer une logique détenue par le
  /// widget (CR-IFFD-30).
  ///
  /// Il vit dans la spec (et non en paramètre de `ZSubfolderSidebar`) pour
  /// traverser la façade `ZStudyFolderDetail`, qui instancie la sidebar
  /// elle-même : un paramètre de widget serait inatteignable pour l'hôte.
  ///
  /// zcrud ne pose AUCUN style dessus (ni typographie, ni gouttière, ni couleur
  /// — FR-26) : l'hôte fournit un widget déjà habillé.
  final Widget? sidebarHeader;

  /// Action d'ajout d'un sous-dossier. `null` ⇒ bouton « Ajouter » ABSENT
  /// (AD-4), dans la sidebar comme dans le sélecteur compact (AC13).
  final VoidCallback? addAction;

  /// Libellé a11y/tooltip **injecté** du bouton « Ajouter » (repli : néant, le
  /// bouton reste présent avec [allSubfoldersLabel] comme dernier recours pour
  /// ne jamais rendre un contrôle sans annonce).
  final String? addLabel;

  /// Glyphe **injecté** du bouton « Ajouter » (repli neutre `Icons.add` côté
  /// widget — un `IconData` conventionnel, jamais un libellé).
  final IconData? addIcon;

  /// **Où** l'affordance d'ajout est offerte sur la barre de sélection
  /// (CR-IFFD-44, manque 1).
  ///
  /// Défaut [ZSubfolderAddPlacement.barAndSheet] ⇒ **rendu strictement
  /// inchangé** pour tout hôte existant. Sans effet quand [addAction] est
  /// `null` (aucune affordance nulle part, AD-4) ni hors de
  /// [ZSubfolderNarrowMode.selector] — voir [ZSubfolderAddPlacement].
  final ZSubfolderAddPlacement addPlacement;

  /// Callback de réordonnancement des sous-dossiers. **`null` ⇒ capacité
  /// ABSENTE** (AD-4) : aucune poignée de drag, aucune action sémantique de
  /// déplacement. Non-null ⇒ indices en convention `removeAt(old)`/`insert(new)`
  /// (indices **linéaires** sur [subfolders], l'item racine exclu — AC12).
  final void Function(int oldIndex, int newIndex)? onReorder;

  /// Libellé a11y **injecté** de la poignée de drag (repli : [allSubfoldersLabel]
  /// en dernier recours — jamais un libellé codé en dur).
  final String? reorderHandleLabel;

  /// Libellé a11y **injecté** de l'action sémantique « déplacer avant » (AD-13).
  /// `null` ⇒ action sémantique absente (le drag reste disponible).
  final String? moveBeforeLabel;

  /// Libellé a11y **injecté** de l'action sémantique « déplacer après » (AD-13).
  final String? moveAfterLabel;

  /// Libellé a11y **injecté** du contrôle de repli quand la sidebar est
  /// DÉPLOYÉE. `null` ⇒ repli sur [allSubfoldersLabel] (jamais codé en dur).
  final String? collapseLabel;

  /// Libellé a11y **injecté** du contrôle de repli quand la sidebar est REPLIÉE.
  final String? expandLabel;

  /// Libellé a11y **injecté** de la **poignée de redimensionnement** de la
  /// sidebar (AD-13/WCAG 2.1.1 & 2.5.7). La poignée est focusable au clavier
  /// (flèches ← → , inversées en RTL) et expose les actions sémantiques
  /// `increase`/`decrease` — alternatives au drag. `null` ⇒ repli sur
  /// [allSubfoldersLabel] (jamais un libellé codé en dur, jamais un contrôle
  /// interactif muet).
  final String? resizeLabel;

  /// Largeur minimale de la sidebar déployée (dp, défaut `300`). Borne basse du
  /// clamp de redimensionnement (AC10).
  final double minSidebarWidth;

  /// Fraction MAXIMALE de la largeur écran pour la sidebar (défaut `0.5`). Borne
  /// haute du clamp (AC10).
  final double maxSidebarWidthFraction;

  /// Largeur de la sidebar REPLIÉE (dp, défaut `56`) — icône + badge (AC11).
  final double collapsedWidth;

  /// Largeur initiale de la sidebar déployée (dp, défaut `300`).
  final double initialSidebarWidth;

  /// Callback **injecté** notifié à chaque redimensionnement stabilisé (fin de
  /// drag) avec la largeur **clampée**. **Aucune I/O dans le widget** : la
  /// persistance (SharedPreferences/fichier/repo) est du ressort de l'hôte
  /// (AC10).
  final ValueChanged<double>? onSidebarWidthChanged;
}
