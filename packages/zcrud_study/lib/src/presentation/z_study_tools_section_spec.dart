/// `ZStudyToolsSectionSpec` — descripteur PARAMÉTRIQUE d'une section « study
/// tools » (AD-25, forme de référence IFFD `folder_study_tools_page.dart`).
///
/// Data-class de PRÉSENTATION immuable (`const`) : elle décrit *quoi* rendre
/// (titre + compteur, items paginés par `itemBuilder`, état vide, action
/// d'ajout) SANS jamais référencer un modèle d'app (`FlashcardModel` & co.) ni
/// coder en dur une `Color`/`IconData`/un label — couleurs, libellés et l10n
/// sont FOURNIS par l'appelant (injectés, AD-13/FR-26). Le descripteur n'est
/// PAS l'entité domaine : c'est une projection présentation paramétrique.
library;

import 'package:flutter/widgets.dart';

/// Descripteur immuable d'une section de la page « study tools ».
///
/// Mapping des 4 sections IFFD mesurées (AD-25) → un `ZStudyToolsSectionSpec`
/// par section : rail flashcards, grille documents, grille notes, grille
/// mindmaps. Chaque section est rendue par [ZSectionedStudyLayout] dans son
/// propre sous-arbre isolé (frontière rebuild — pré-requis SM-1/ES-5.2).
@immutable
class ZStudyToolsSectionSpec {
  /// Construit un descripteur de section.
  ///
  /// [addAction] est **nullable** : `null` = action d'ajout ABSENTE (AD-4 —
  /// callback `null` = capacité absente, jamais un no-op silencieux).
  const ZStudyToolsSectionSpec({
    required this.id,
    required this.title,
    required this.itemCount,
    required this.itemBuilder,
    required this.emptyState,
    this.addAction,
    this.addActionIcon,
    this.addActionSemanticLabel,
    this.axis = Axis.vertical,
    this.itemIds,
    this.onReorder,
    this.reorderHandleSemanticLabel,
    this.reorderHandleIcon,
    this.reorderMoveBeforeSemanticLabel,
    this.reorderMoveAfterSemanticLabel,
    this.collapsible = false,
    this.initiallyExpanded = true,
    this.crossAxisMinItemWidth,
    this.crossAxisItemHeight,
    this.crossAxisAspectRatio,
    this.crossAxisMaxColumns,
    this.crossAxisVirtualized = false,
    this.crossAxisViewportHeight,
    this.collapseSemanticLabel,
    this.expandSemanticLabel,
    this.headerCount,
    this.secondaryAction,
    this.secondaryActionIcon,
    this.secondaryActionSemanticLabel,
  })  : assert(itemCount >= 0, 'itemCount ne peut être négatif'),
        // AD-4/AD-10 — cohérence de développement (assert, jamais de throw
        // runtime persistant) : une section réordonnable ([onReorder] non-null)
        // EXIGE des clés stables ([itemIds]) de longueur [itemCount] — sans quoi
        // `ReorderableListView` ne peut ni keyer ni mapper le déplacement.
        assert(
          onReorder == null ||
              (itemIds != null && itemIds.length == itemCount),
          'onReorder != null exige itemIds non-null de longueur itemCount',
        );

  /// Identifiant STABLE de la section (String opaque). Sert de clé de frontière
  /// de widget (`ValueKey('section:$id')`) — DOIT être unique dans une page.
  final String id;

  /// Titre de la section (déjà localisé par l'appelant — AD-13/FR-23).
  final String title;

  /// Nombre d'items de la section. `0` ⇒ [ZSectionedStudyLayout] rend
  /// [emptyState] (jamais [itemBuilder]).
  final int itemCount;

  /// Construit l'item à l'index donné (`0 <= index < itemCount`). L'appelant
  /// fournit ici la carte d'item (équivalent `_buildGridItemCard` IFFD) —
  /// couleurs/icônes/labels y sont injectés, jamais dans le descripteur.
  final Widget Function(BuildContext context, int index) itemBuilder;

  /// Widget affiché quand la section est vide (`itemCount == 0`). Fourni par
  /// l'appelant (équivalent `EmtyFolderContent` IFFD) — jamais un `SizedBox`
  /// silencieux imposé par le descripteur.
  final Widget emptyState;

  /// Action d'ajout de la section (`+`). `null` = action ABSENTE (AD-4).
  final VoidCallback? addAction;

  /// Glyphe INJECTÉ du bouton d'ajout (`+`). `null` = l'appelant n'impose pas
  /// d'icône ; le layout se replie sur un glyphe « add » neutre documenté
  /// ([ZSectionedStudyLayout]). Solde DW-ES51-1 MEDIUM-1 : plus aucun
  /// `Icons.add` codé en dur INCONDITIONNELLEMENT dans le package (FR-26 — les
  /// `IconData` significatifs sont fournis par l'appelant).
  final IconData? addActionIcon;

  /// Label sémantique LOCALISÉ du bouton d'ajout (lecteur d'écran). `null` = le
  /// layout se replie sur [title] (toléré, documenté). Solde DW-ES51-1
  /// MEDIUM-1 : le label injecté PRIME sur [title] pour lever l'ambiguïté
  /// `« <titre>, bouton »` (le screen-reader annonce l'ACTION « ajouter … », pas
  /// l'en-tête homonyme). JAMAIS de « Ajouter »/« Add » codé en dur (i18n —
  /// AD-13/FR-23).
  final String? addActionSemanticLabel;

  /// Orientation de la disposition des items de la section.
  ///
  /// [Axis.vertical] (défaut, non-cassant pour les sections ES-5.1) = grille
  /// empilée (documents/notes/mindmaps). [Axis.horizontal] = **rail** défilant
  /// (flashcards) — résidu d'apparence IFFD soldé en ES-5.2. La réordonnabilité
  /// (ES-5.3) ne s'applique QU'À [Axis.vertical] (grilles docs/notes/mindmaps) ;
  /// le rail horizontal flashcards N'EST PAS réordonnable (documenté, l'epic ne
  /// cible que « grilles réordonnables »).
  final Axis axis;

  // ── Slots ADDITIFS de réordonnabilité (ES-5.3, AD-4/AD-25) ─────────────────
  // Tous const-compatibles et défaut `null` ⇒ non-cassant pour les sections
  // ES-5.1/5.2 et les fixtures golden (une section reste non réordonnable tant
  // que [onReorder] n'est pas fourni).

  /// Ordre COURANT des ids d'items rendus (clés STABLES de réordonnancement).
  ///
  /// `null` par défaut. Quand la section est réordonnable ([onReorder] non-null),
  /// l'appelant FOURNIT ici les ids déjà ordonnés — typiquement issus de
  /// `ZFolderContentsOrder.applyTo(sectionKey, items, idOf:)` (tri stable
  /// `applyOrder<T>`, ES-1.2/ES-2.4). `itemIds[i]` est l'id de l'item rendu par
  /// `itemBuilder(context, i)` : `ReorderableListView` keye chaque enfant par
  /// `ValueKey(itemIds[i])` (clé requise) et mappe le déplacement d'index vers le
  /// nouvel ordre d'ids. Longueur DOIT == [itemCount] (assert).
  final List<String>? itemIds;

  /// Callback de réordonnancement. **`null` = section NON réordonnable** (AD-4 —
  /// capacité ABSENTE, jamais un no-op silencieux) : rendu ES-5.2 inchangé.
  ///
  /// Non-null ⇒ la section (vertical uniquement) est rendue via un
  /// `ReorderableListView.builder`. Les indices reçus sont **en convention
  /// `removeAt(oldIndex)`/`insert(newIndex)`** (le layout consomme le callback
  /// SDK `onReorderItem`, dont le `newIndex` est déjà ajusté pour le retrait de
  /// l'item à `oldIndex`) : l'appelant persiste directement via
  /// `order.copyWith(sectionOrders: {…, sectionKey: zReorderIds(ids, oldIndex,
  /// newIndex)})` — MÊME opération que celle appliquée localement au rendu
  /// (symétrie test/impl). AUCUNE écriture kernel : `ZFolderContentsOrder` est
  /// réutilisé EN LECTURE + `copyWith` (AD-26).
  final void Function(int oldIndex, int newIndex)? onReorder;

  /// Label sémantique LOCALISÉ (i18n) de la poignée de drag (lecteur d'écran).
  ///
  /// `null` = repli sur [title] (toléré, documenté). JAMAIS de « Réordonner »/
  /// « Drag » codé en dur (AD-13/FR-23) : le label est INJECTÉ par l'appelant.
  final String? reorderHandleSemanticLabel;

  /// Glyphe INJECTÉ de la poignée de réordonnancement (CR-LEX-79 §2).
  ///
  /// `null` (défaut) ⇒ repli sur `Icons.drag_handle` — **rendu strictement
  /// inchangé** pour tout hôte qui ne renseigne pas ce slot. MÊME patron que
  /// [addActionIcon] et [secondaryActionIcon], qui étaient déjà injectables : la
  /// poignée était la seule icône du layout à rester CODÉE EN DUR, ce qui
  /// obligeait l'hôte à aligner ses assertions sur le glyphe amont au lieu de
  /// choisir sa propre iconographie (ex. `Icons.drag_handle_rounded`).
  ///
  /// S'applique aux **DEUX** chemins réordonnables — liste mono-colonne ET
  /// grille multi-colonnes (cf. [crossAxisMinItemWidth]).
  final IconData? reorderHandleIcon;

  /// Libellé LOCALISÉ de l'action sémantique « déplacer avant » du mode GRILLE
  /// réordonnable (CR-IFFD-15). `null` ⇒ repli neutre documenté côté layout.
  ///
  /// En grille, le geste est un **appui long sur la cellule** : il n'existe pas
  /// de poignée, et un appui long est **inatteignable au lecteur d'écran**.
  /// L'alternative accessible obligatoire (AD-13) passe donc par deux actions
  /// sémantiques, dont ce libellé.
  final String? reorderMoveBeforeSemanticLabel;

  /// Libellé LOCALISÉ de l'action sémantique « déplacer après » du mode GRILLE
  /// réordonnable (CR-IFFD-15). Voir [reorderMoveBeforeSemanticLabel].
  final String? reorderMoveAfterSemanticLabel;

  // ── CR-IFFD-10 : capacités de la page d'origine absentes du portage ────────

  /// Section **repliable** (CR-IFFD-10 §1). `false` par défaut — le rendu
  /// antérieur (toujours déplié) est strictement préservé.
  ///
  /// L'état plié/déplié vit **localement** sous la frontière keyée de la section
  /// (SM-1/AD-2) : replier une section ne reconstruit NI les autres sections NI
  /// la page.
  final bool collapsible;

  /// État initial quand [collapsible] est `true` (CR-IFFD-10 §1). Ignoré sinon.
  ///
  /// Permet le patron d'origine « déplié seulement si la section a des
  /// éléments » : `initiallyExpanded: items.isNotEmpty`.
  final bool initiallyExpanded;

  /// Largeur minimale d'un item pour un rendu **multi-colonnes** (CR-IFFD-10 §2).
  ///
  /// `null` (défaut) ⇒ une seule colonne, rendu antérieur inchangé. Sinon le
  /// nombre de colonnes est dérivé de la largeur disponible — la page d'origine
  /// s'étale ainsi sur desktop/tablette au lieu d'empiler.
  final double? crossAxisMinItemWidth;

  /// Hauteur fixe d'une cellule de grille (CR-IFFD-11 §2). `null` ⇒ forme par
  /// défaut de la grille.
  ///
  /// La page d'origine pose des cartes BASSES (≈ 76 dp) : sans ce paramètre, les
  /// cellules prennent une hauteur par défaut et l'écart de parité est visible
  /// précisément sur grand écran, là où la grille sert.
  /// Exclusif avec [crossAxisAspectRatio] — si les deux sont fournis, la hauteur
  /// fixe l'emporte (elle est plus déterministe).
  final double? crossAxisItemHeight;

  /// Ratio largeur/hauteur d'une cellule (CR-IFFD-11 §2), alternative à
  /// [crossAxisItemHeight] quand la hauteur doit suivre la largeur de colonne.
  final double? crossAxisAspectRatio;

  /// **Plafond** du nombre de colonnes de la grille (CR-LEX-77).
  ///
  /// `null` (défaut) ⇒ **illimité** : le nombre de colonnes reste dérivé de la
  /// seule largeur disponible — **rendu strictement inchangé** pour tout hôte
  /// qui ne renseigne pas ce slot.
  ///
  /// Non-null ⇒ le nombre de colonnes est borné en haut, dans les **TROIS**
  /// chemins de grille (eager, virtualisé, réordonnable) : un hôte qui rendait
  /// `ResponsiveGrid(minItemWidth: 220, maxColumns: 3)` conserve ses 3 colonnes
  /// à 1200 dp au lieu de passer à 5. Le plafond ne mord qu'au-dessus de la
  /// largeur où la responsive donne déjà moins de colonnes — sous ce seuil le
  /// rendu est identique avec ou sans plafond.
  ///
  /// **AD-10 — repli défensif ALIGNÉ sur la primitive** : la valeur est
  /// transmise TELLE QUELLE à `computeCrossAxisCount`, dont le contrat est déjà
  /// écrit : un plafond `< minColumns` (donc `0` ou négatif) est **remonté au
  /// plancher** (≥ 1 colonne garantie) — jamais de grille vide, jamais de
  /// `RangeError`. Aucun assainissement local n'est fait ici : un plafond qui se
  /// comporterait différemment selon le chemin serait pire que pas de plafond.
  final int? crossAxisMaxColumns;

  /// ✅ **COMBINABLE avec [onReorder]** depuis CR-IFFD-15 (voie A/C, arbitrée
  /// par l'owner) : déclarer les deux produit désormais une **grille
  /// multi-colonnes RÉORDONNABLE** (`ZReorderableAdaptiveGrid` de
  /// `zcrud_responsive`), et non plus une liste mono-colonne signalée par un
  /// `assert`. L'activation est **implicite** — aucun drapeau supplémentaire.
  /// Le geste est un **appui long sur la cellule**, doublé de deux actions
  /// sémantiques ([reorderMoveBeforeSemanticLabel] /
  /// [reorderMoveAfterSemanticLabel]) pour le lecteur d'écran (AD-13).
  ///
  /// **CR-LEX-79 §1 — l'AFFORDANCE est désormais présente sur les DEUX chemins.**
  /// Jusqu'ici la poignée n'existait QUE sur le chemin liste : passer une section
  /// déjà réordonnable en grille (renseigner cette largeur) faisait DISPARAÎTRE
  /// la poignée **sans aucun signal** — ni erreur, ni `assert`, et le glisser
  /// continuait de passer en test. Chaque cellule de grille porte désormais la
  /// MÊME poignée que le mode liste : glyphe [reorderHandleIcon] (repli
  /// `Icons.drag_handle`), nœud `Semantics` au libellé INJECTÉ
  /// ([reorderHandleSemanticLabel], repli [title]) et cible ≥ 48 dp.
  ///
  /// ⚠️ **Écart ASSUMÉ et documenté entre les deux chemins** : en liste, la
  /// poignée est un `ReorderableDragStartListener` — un point de départ de drag
  /// DISTINCT (glisser depuis la poignée, sans appui long). En grille, le
  /// déclencheur reste l'**appui long sur la cellule entière** (poignée
  /// comprise) : la poignée y est une **affordance**, pas un second déclencheur.
  /// La raison est structurelle — `ReorderableDragStartListener` ne fait rien
  /// hors d'un `SliverReorderableList` du SDK (absent du chemin grille), et un
  /// `Draggable` local ne connaîtrait pas la **position d'affichage** attendue
  /// par le protocole de dépôt de la grille (l'`itemBuilder` reçoit l'index
  /// SOURCE, pas la position courante). Une poignée qui *paraîtrait* déclencher
  /// sans déclencher serait pire que pas de poignée.
  ///
  /// ℹ️ L'affordance est posée **autour de l'item, en amont du renderer** : elle
  /// s'applique donc AUSSI à un `ZReorderRenderer` injecté par l'hôte (AD-57),
  /// et pas seulement au repli `zcrud_responsive`.
  ///
  /// ⚠️ Reste **exclusif avec [crossAxisVirtualized]** : une cellule non
  /// construite ne peut pas être une cible de dépôt. Une section à la fois
  /// réordonnable et virtualisée est rendue **eager** (réordonnable), la
  /// virtualisation cédant — documenté, jamais dégradé en silence.
  ///
  /// Grille **virtualisée** (CR-IFFD-11 §4) : ne construit que les cellules du
  /// viewport et scrolle d'elle-même. `false` par défaut (grille *eager*,
  /// imbriquée dans le défilement de la page — rendu antérieur inchangé).
  ///
  /// ⚠️ À activer dès qu'une section peut porter plusieurs dizaines d'items : en
  /// mode *eager*, TOUTES les cellules sont construites ET layoutées, même hors
  /// écran. Une section alimentée par tout le contenu d'un dossier (héritage
  /// parent compris) est exactement ce cas.
  final bool crossAxisVirtualized;

  /// Hauteur du viewport d'une grille [crossAxisVirtualized] — **obligatoire**
  /// dans ce mode (CR-IFFD-11 §4).
  ///
  /// Une grille virtualisée EST la surface scrollable : imbriquée sans hauteur
  /// bornée dans le défilement de la page, elle lève « Vertical viewport was
  /// given unbounded height ». La déclarer, c'est accepter en connaissance de
  /// cause un **défilement imbriqué** — le prix de la virtualisation à ce
  /// niveau. Sans elle, la grille retombe défensivement en mode *eager*.
  final double? crossAxisViewportHeight;

  /// Libellé accessible du contrôle de repli quand la section est DÉPLIÉE
  /// (CR-IFFD-11 §3). Repli : `'Replier'`.
  ///
  /// C'était le SEUL libellé non injecté de ce layout — un hôte non francophone
  /// obtenait un `semanticLabel` en français sur un contrôle d'accessibilité,
  /// contredisant AD-13 et le principe d'injection appliqué partout ailleurs.
  final String? collapseSemanticLabel;

  /// Libellé accessible du contrôle de repli quand la section est REPLIÉE
  /// (CR-IFFD-11 §3). Repli : `'Déplier'`.
  final String? expandSemanticLabel;

  /// Compteur affiché dans l'en-tête, **découplé** du nombre d'items rendus
  /// (CR-IFFD-10 §4). `null` (défaut) ⇒ le badge affiche [itemCount].
  ///
  /// Permet le patron d'origine « badge = total (42), rail = `take(10)` » :
  /// `itemCount: 10, headerCount: 42`.
  final int? headerCount;

  /// Action d'en-tête **secondaire**, en plus de [addAction] (CR-IFFD-10 §3) —
  /// typiquement « Afficher tout » (navigation). `null` ⇒ action ABSENTE (AD-4).
  ///
  /// Sans elle, un hôte devait détourner [addAction] pour la navigation : jamais
  /// les deux à la fois, et une sémantique approximative.
  final VoidCallback? secondaryAction;

  /// Icône de [secondaryAction] (repli neutre si absente).
  final IconData? secondaryActionIcon;

  /// Libellé accessible de [secondaryAction] (a11y AD-13 — repli sur [title]).
  final String? secondaryActionSemanticLabel;
}
