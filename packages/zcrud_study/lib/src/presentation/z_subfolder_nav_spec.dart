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

/// Descripteur immuable de la navigation de sous-dossiers.
@immutable
class ZSubfolderNavSpec {
  /// Construit le descripteur. [subfolders] et [allSubfoldersLabel] sont requis.
  const ZSubfolderNavSpec({
    required this.subfolders,
    required this.allSubfoldersLabel,
    this.itemBuilder,
    this.sidebarHeader,
    this.addAction,
    this.addLabel,
    this.addIcon,
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
