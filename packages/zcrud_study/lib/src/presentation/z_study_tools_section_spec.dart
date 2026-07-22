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
    this.collapsible = false,
    this.initiallyExpanded = true,
    this.crossAxisMinItemWidth,
    this.crossAxisItemHeight,
    this.crossAxisAspectRatio,
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

  /// ⚠️ **EXCLUSIF avec [onReorder]** (CR-IFFD-11 §1) : le réordonnancement
  /// s'appuie sur `ReorderableListView` (SDK Flutter), qui ne dispose pas en
  /// grille. Déclarer les deux rend une liste **mono-colonne** et ignore cette
  /// largeur — un `assert` le signale en debug. Une grille réordonnable exigerait
  /// un paquet tiers refusé par AD-1, ou une implémentation maison du
  /// drag-and-drop bidimensionnel.
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
