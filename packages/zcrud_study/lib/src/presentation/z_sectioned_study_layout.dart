/// `ZSectionedStudyLayout` — échafaudage de composition qui rend une
/// `List<ZStudyToolsSectionSpec>` comme une **liste de sections INDÉPENDANTES**
/// (AD-25). Matérialise la décomposition du monolithe IFFD
/// `folder_study_tools_page.dart` (~1753 l., `build` unique 350→~1739) : chaque
/// section obtient sa PROPRE frontière de widget (`ValueKey('section:$id')`) —
/// pré-requis du rebuild ciblé SM-1 (ES-5.2) et de la réordonnabilité (ES-5.3).
///
/// Invariants (AD-2/AD-13/AD-15) : AUCUN gestionnaire d'état (réactivité
/// Flutter-native pure) ; directionnel (`EdgeInsetsDirectional`/
/// `AlignmentDirectional`/`TextAlign.start`) ; `Semantics` explicites ; cibles
/// interactives ≥ 48 dp ; thème injecté via `ZcrudTheme.of` (`ZcrudScope` →
/// `Theme.of` repli, aucune couleur codée en dur) ; `ListView.builder`.
///
/// CR-LEX-74 — DEUX enveloppes, UN seul contenu : [ZSectionedStudyLayout]
/// (boîte, `ListView.builder`) et [ZSectionedStudySliver] (sliver,
/// `SliverList.builder`, assemblable dans un `CustomScrollView` sans défilement
/// imbriqué). Le contenu, l'ordre et les clés viennent de la source unique
/// `_ZSectionsSource` — les deux chemins ne PEUVENT pas diverger.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart'
    show
        ZcrudScope,
        ZcrudTheme,
        ZDisplayStateBinding,
        ZReorderRenderRequest,
        ZStudySectionCollapsePlacement,
        ZStudySectionCountPlacement,
        ZStudySectionCountRole,
        ZStudySectionCountShape;
import 'package:zcrud_responsive/zcrud_responsive.dart'
    show ZAdaptiveGrid, ZDefaultReorderRenderer;

import 'z_content_hub_launcher.dart';
import 'z_reorder_ids.dart';
import 'z_study_tools_section_spec.dart';

/// Cible de taille interactive minimale (AD-13/NFR-S6).
const double _kMinTapTarget = 48.0;

/// Glyphe « add » de REPLI, appliqué UNIQUEMENT quand l'appelant n'injecte pas
/// `addActionIcon`. Ce n'est PAS un hardcode inconditionnel (solde DW-ES51-1
/// MEDIUM-1) : dès qu'une icône est injectée, elle prime ([_ZStudySection]). Le
/// glyphe conventionnel « + » est le défaut neutre justifié d'une action d'ajout.
const IconData _kAddActionFallbackIcon = Icons.add;

/// Glyphe de poignée de drag de REPLI, appliqué UNIQUEMENT quand l'appelant
/// n'injecte pas `reorderHandleIcon` (CR-LEX-79 §2) — même patron justifié que
/// [_kAddActionFallbackIcon]. Le nom « fallback » est désormais EXACT : il
/// existe bien un slot devant lequel se replier (`ZStudyToolsSectionSpec
/// .reorderHandleIcon`), là où la poignée était auparavant la seule icône du
/// layout à rester codée en dur INCONDITIONNELLEMENT alors que
/// `addActionIcon`/`secondaryActionIcon` étaient, eux, injectables. La
/// sémantique (label a11y) reste, elle, TOUJOURS injectée
/// (`reorderHandleSemanticLabel`, i18n) : aucun libellé n'est jamais codé en
/// dur (AD-13/FR-26).
const IconData _kDragHandleFallbackIcon = Icons.drag_handle;

/// Libellés de REPLI des actions sémantiques de la grille réordonnable
/// (CR-IFFD-15). MÊME patron toléré et documenté que `'Replier'`/`'Déplier'`
/// (CR-IFFD-11 §3) : dès qu'un libellé est INJECTÉ
/// (`reorderMoveBeforeSemanticLabel`/`reorderMoveAfterSemanticLabel`), il prime.
const String _kMoveBeforeFallbackLabel = 'Déplacer avant';

/// Voir [_kMoveBeforeFallbackLabel].
const String _kMoveAfterFallbackLabel = 'Déplacer après';

/// Rend une liste de sections « study tools » décomposée.
///
/// Chaque entrée de [sections] devient un sous-arbre `_ZStudySection` distinct,
/// keyé par `ValueKey('section:$id')`, assemblé par un `ListView.builder`
/// (jamais `ListView(children:)`). L'ordre visuel vertical SUIT l'ordre de
/// [sections] — aucun tri implicite (pré-requis ES-5.3).
class ZSectionedStudyLayout extends StatelessWidget {
  /// Construit le layout à partir des descripteurs de section (ordre préservé).
  ///
  /// [header]/[footer] sont des slots OPTIONNELS (CR-53) : `null` ⇒ slot
  /// ABSENT STRUCTURELLEMENT — le rendu est alors STRICTEMENT celui d'avant
  /// CR-53 (`itemCount == sections.length`, aucun item fantôme).
  const ZSectionedStudyLayout({
    required this.sections,
    this.header,
    this.footer,
    super.key,
  });

  /// Descripteurs de section, dans l'ordre visuel vertical voulu.
  final List<ZStudyToolsSectionSpec> sections;

  /// CR-53 — contenu LIBRE rendu **au-dessus de la première section**, dans le
  /// **MÊME défilement** qu'elles (premier item du `ListView.builder`, jamais
  /// un second `Scrollable` ni un bandeau figé hors-scroll).
  ///
  /// Répond au constat lex : la page-détail rend quatre blocs au-dessus des
  /// sections (CTA « Réviser », chips de sous-dossiers, bandeau de génération,
  /// filtre par tags) qui ne sont PAS des sections d'outils — les verser dans
  /// [sections] serait un détournement (ni titre, ni compteur, ni sémantique de
  /// section).
  ///
  /// **AD-4** : `null` ⇒ capacité absente — AUCUN item n'est réservé, aucun
  /// `SizedBox.shrink` fantôme n'est inséré, `itemCount` est inchangé.
  ///
  /// **AD-2** : c'est un `Widget` DÉJÀ CONSTRUIT (jamais un builder ré-invoqué
  /// par le layout). Le layout le RESTITUE tel quel comme enfant du sliver :
  /// tant que l'appelant repousse la MÊME instance, `Element.updateChild`
  /// court-circuite et le sous-arbre d'en-tête n'est NI reconstruit NI remonté
  /// quand [sections] change. Un `WidgetBuilder` fabriquerait au contraire une
  /// instance neuve à chaque rebuild du layout et détruirait cette garantie —
  /// c'est la raison EXPLICITE du choix `Widget?` plutôt que builder ici.
  /// (La granularité par sélection, elle, est portée un cran plus haut par
  /// `ZStudyFolderDetail.materialHeaderBuilder`.)
  final Widget? header;

  /// Symétrique de [header], rendu **après la dernière section**, dans le même
  /// défilement. Mêmes garanties (AD-4 : `null` ⇒ absent structurellement ;
  /// AD-2 : instance restituée telle quelle).
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    // CONTENU/ORDRE/CLÉS : SOURCE UNIQUE partagée avec [ZSectionedStudySliver]
    // (CR-74). Cette enveloppe ne décide QUE du transport (boîte scrollable).
    final source = _ZSectionsSource(
      sections: sections,
      header: header,
      footer: footer,
    );
    return ListView.builder(
      // Virtualisation PRÉSERVÉE : les slots sont des items du MÊME
      // `ListView.builder` (jamais un `Column`/`ListView(children:)` qui
      // construirait toutes les sections d'un coup).
      // Pas de tri : l'ordre d'entrée EST l'ordre de rendu (AC3, ES-5.3).
      itemCount: source.itemCount,
      itemBuilder: source.buildItem,
    );
  }
}

/// `ZSectionedStudySliver` — **variante SLIVER** de [ZSectionedStudyLayout]
/// (CR-LEX-74).
///
/// ## Pourquoi un widget SÉPARÉ et non un drapeau `sliver: true`
///
/// Un drapeau qui change le **type de rendu** (`RenderBox` ↔ `RenderSliver`)
/// déplace une erreur de **compilation** vers une erreur d'**exécution** : un
/// `SliverList` posé dans un `Column`/`Padding` lève
/// « A RenderSliver expected a RenderBox child » au premier layout, et
/// symétriquement un `ListView` posé dans les `slivers:` d'un
/// `CustomScrollView` lève « RenderViewport expected a child of type
/// RenderSliver ». Le drapeau rendrait ces deux fautes indiscernables à
/// l'analyse : `ZSectionedStudyLayout(sliver: true)` reste un `Widget` boîte du
/// point de vue du typage, donc l'hôte compile puis plante. Deux widgets
/// distincts font porter le contrat par le TYPE : le mauvais choix ne compile
/// pas.
///
/// ## Zéro duplication (exigence stricte)
///
/// Le contenu, l'ORDRE, les clés (`ValueKey('section:$id')`), les slots
/// [header]/[footer] et le rail flashcards proviennent d'une **source unique**,
/// [_ZSectionsSource], partagée à l'identique par les deux enveloppes. Aucune
/// des deux n'a de branche de contenu qui lui soit propre — une divergence
/// future exigerait de modifier la source commune, donc les deux à la fois.
///
/// ## Usage
///
/// ```dart
/// CustomScrollView(
///   slivers: [
///     const SliverAppBar(pinned: true, ...),   // rétractable : PRÉSERVÉ
///     ZSectionedStudySliver(sections: sections),
///   ],
/// )
/// ```
///
/// **AD-2** : virtualisation PRÉSERVÉE (`SliverList.builder`, jamais
/// `SliverList(children:)` qui matérialiserait toutes les sections) ; aucun
/// gestionnaire d'état ; aucun `Scrollable` propre ⇒ **pas de défilement
/// imbriqué**, l'app-bar rétractable de l'hôte continue de réagir au geste.
class ZSectionedStudySliver extends StatelessWidget {
  /// Mêmes paramètres, mêmes sémantiques que [ZSectionedStudyLayout] — seule
  /// l'enveloppe (sliver au lieu de boîte) change.
  const ZSectionedStudySliver({
    required this.sections,
    this.header,
    this.footer,
    super.key,
  });

  /// Descripteurs de section, dans l'ordre visuel vertical voulu.
  /// Cf. [ZSectionedStudyLayout.sections].
  final List<ZStudyToolsSectionSpec> sections;

  /// Cf. [ZSectionedStudyLayout.header] (mêmes garanties AD-2/AD-4).
  final Widget? header;

  /// Cf. [ZSectionedStudyLayout.footer] (mêmes garanties AD-2/AD-4).
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final source = _ZSectionsSource(
      sections: sections,
      header: header,
      footer: footer,
    );
    return SliverList.builder(
      itemCount: source.itemCount,
      itemBuilder: source.buildItem,
    );
  }
}

/// SOURCE UNIQUE du contenu, de l'ordre et des clés des items de sections
/// (CR-LEX-74).
///
/// Extraite telle quelle du `build` historique de [ZSectionedStudyLayout] :
/// aucun comportement n'a changé, seul le point d'appel a été factorisé pour
/// que la variante sliver ne puisse PAS diverger. C'est le refus explicite du
/// défaut constaté chez IFFD (même mapping recopié en plusieurs exemplaires
/// dont un divergent).
@immutable
class _ZSectionsSource {
  const _ZSectionsSource({
    required this.sections,
    required this.header,
    required this.footer,
  });

  final List<ZStudyToolsSectionSpec> sections;
  final Widget? header;
  final Widget? footer;

  /// `null` ⇒ 0 item réservé (absence STRUCTURELLE, AD-4) — jamais un slot
  /// vide dans le décompte.
  int get _leading => header == null ? 0 : 1;
  int get _trailing => footer == null ? 0 : 1;

  int get itemCount => _leading + sections.length + _trailing;

  /// Item d'index [index] — MÊME contenu, MÊME ordre, MÊMES clés quelle que
  /// soit l'enveloppe.
  Widget? buildItem(BuildContext context, int index) {
    // Capture LOCALE des slots : la promotion de type permet de restituer
    // l'instance EXACTE (identité préservée ⇒ court-circuit d'updateChild).
    final Widget? headerSlot = header;
    final Widget? footerSlot = footer;
    if (headerSlot != null && index == 0) {
      // Restitué TEL QUEL (aucun emballage, aucune clé dérivée de
      // `sections`) — cf. la doc de [ZSectionedStudyLayout.header] (AD-2).
      return headerSlot;
    }
    final int sectionIndex = index - _leading;
    if (sectionIndex >= sections.length) {
      // Seul index restant possible : le pied.
      return footerSlot;
    }
    final spec = sections[sectionIndex];
    return _ZStudySection(
      // Frontière de widget STABLE par section — décomposition comptable
      // (AC5) et frontière rebuild (SM-1/ES-5.2). La clé reste dérivée du
      // SEUL id : elle ne dépend NI de l'index de liste, NI de la présence
      // ou du contenu des slots ⇒ changer l'en-tête ne remonte pas les
      // sections (leur état local de repli/ordre survit).
      key: ValueKey('section:${spec.id}'),
      spec: spec,
    );
  }
}

/// Sous-arbre isolé d'UNE section. `StatelessWidget` (aucun état local) — la
/// réactivité par champ sera branchée en ES-5.2 via `ValueListenable` sans
/// casser cette frontière.
class _ZStudySection extends StatelessWidget {
  const _ZStudySection({required this.spec, super.key});

  final ZStudyToolsSectionSpec spec;

  @override
  Widget build(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    final isEmpty = spec.itemCount == 0;
    // CR-IFFD-50 ④ — placement de l'affordance de repli. `null` ⇒ SOUS le
    // titre (rendu historique, strictement inchangé). `inHeaderRow` ⇒ le
    // chevron entre dans la LIGNE d'en-tête, côté fin : l'en-tête est alors
    // construit PAR `_CollapsibleBody` (qui possède l'état de repli), via
    // `headerBuilder` — même `_buildHeader`, jamais un second en-tête.
    final ZStudySectionCollapsePlacement placement =
        theme.studySectionCollapsePlacement ??
            ZStudySectionCollapsePlacement.belowTitle;
    final bool collapseInHeader = spec.collapsible &&
        placement == ZStudySectionCollapsePlacement.inHeaderRow;
    // CR-IFFD-54 ① — l'en-tête doit être construit PAR `_CollapsibleBody`
    // (propriétaire de l'état de repli) dès que la ligne est zone de bascule
    // OU que le chevron y entre (CR-50 ④) : même `_buildHeader`, jamais un
    // second en-tête. La ligne reste STATIQUE (le closure de tap écrit à la
    // source, il n'écoute pas l'état — SM-1).
    final bool headerInBody = spec.collapsible &&
        (collapseInHeader || spec.collapseOnHeaderTap);

    // CR-IFFD-62 ④ — retrait latéral PROPRE du rail. Quand il est demandé
    // (paramètre de spec, ou jeton de thème), le padding horizontal de section
    // cesse de s'appliquer au RAIL (il reste sur l'en-tête et l'état vide) :
    // sans cela le retrait demandé s'AJOUTERAIT au padding de section et ne
    // serait jamais atteignable. `null` des deux côtés ⇒ arbre et rendu
    // STRICTEMENT inchangés.
    final EdgeInsetsGeometry? railPadding = spec.axis == Axis.horizontal
        ? (spec.railPadding ?? theme.railPadding)
        : null;
    return Padding(
      padding: railPadding == null
          ? EdgeInsetsDirectional.symmetric(
              horizontal: theme.gapM,
              vertical: theme.gapS,
            )
          : EdgeInsetsDirectional.symmetric(vertical: theme.gapS),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!headerInBody)
            _inset(railPadding, theme, _buildHeader(context, theme)),
          // CR-IFFD-10 §1 — le corps est masqué quand la section est repliée.
          // L'état vit LOCALEMENT (`_CollapsibleBody`, sous la frontière keyée
          // de la section) : replier ne reconstruit NI les autres sections NI la
          // page (SM-1/AD-2).
          if (spec.collapsible)
            _CollapsibleBody(
              spec: spec,
              theme: theme,
              body: _body(context, theme, isEmpty, railPadding),
              collapseInHeader: collapseInHeader,
              headerBuilder: headerInBody
                  ? (BuildContext context, Widget? trailingCollapse) =>
                      _inset(
                        railPadding,
                        theme,
                        _buildHeader(
                          context,
                          theme,
                          trailingCollapse: trailingCollapse,
                        ),
                      )
                  : null,
            )
          else ...[
            SizedBox(height: theme.gapS),
            _body(context, theme, isEmpty, railPadding),
          ],
        ],
      ),
    );
  }

  /// Restitue le retrait horizontal de section RETIRÉ du `Padding` externe
  /// quand un retrait de rail propre est demandé (**CR-IFFD-62 ④**).
  /// [railPadding] `null` ⇒ enfant restitué TEL QUEL (aucun nœud ajouté).
  Widget _inset(
    EdgeInsetsGeometry? railPadding,
    ZcrudTheme theme,
    Widget child,
  ) =>
      railPadding == null
          ? child
          : Padding(
              padding: EdgeInsetsDirectional.symmetric(horizontal: theme.gapM),
              child: child,
            );

  /// Corps de la section : `emptyState` si vide, items sinon (jamais l'inverse,
  /// AC3). Extrait pour être partagé entre le rendu direct et le rendu repliable.
  ///
  /// [railPadding] non-`null` ⇒ le RAIL porte ce retrait à la place du padding
  /// de section (CR-IFFD-62 ④) ; l'état vide, lui, garde le retrait de section
  /// (il s'aligne sur le titre, pas sur les cartes).
  Widget _body(
    BuildContext context,
    ZcrudTheme theme,
    bool isEmpty,
    EdgeInsetsGeometry? railPadding,
  ) =>
      isEmpty
          ? _inset(
              railPadding,
              theme,
              Semantics(
                container: true,
                label: spec.title,
                child: spec.emptyState,
              ),
            )
          : _buildItems(context, theme, railPadding);

  /// Items de la section selon [ZStudyToolsSectionSpec.axis] :
  /// - [Axis.vertical] réordonnable ([onReorder] non-null) → grille
  ///   `ReorderableListView` (ES-5.3, sous-arbre local isolé) ;
  /// - [Axis.vertical] (défaut) → empilement (grille) ;
  /// - [Axis.horizontal] → **rail** défilant horizontalement (flashcards).
  Widget _buildItems(
    BuildContext context,
    ZcrudTheme theme,
    EdgeInsetsGeometry? railPadding,
  ) {
    // ES-5.3 — réordonnabilité UNIQUEMENT sur les grilles verticales. `null` =
    // capacité absente (AD-4) ⇒ rendu ES-5.2 inchangé (non-régression).
    //
    // CR-IFFD-15 (voie A/C) — RÉORDONNANCEMENT et GRILLE ne sont PLUS exclusifs.
    // L'ancien `assert` d'exclusivité a disparu : la coexistence de `onReorder`
    // et de `crossAxisMinItemWidth` PRODUIT désormais une grille multi-colonnes
    // réordonnable, par **activation implicite** (aucun changement d'API hôte).
    //
    // La capacité a été remontée dans le socle : `ZReorderableAdaptiveGrid`
    // (`zcrud_responsive`) est le DÉFAUT zéro-dépendance : bâtie sur le seul SDK
    // (`LongPressDraggable`/`DragTarget`/`Scrollable`), elle délègue le calcul
    // de colonnes à `ZAdaptiveGrid`, donc à `computeCrossAxisCount`.
    //
    // RECTIFICATION (AD-57) — un commentaire de ce fichier a longtemps
    // affirmé que `reorderable_grid_view` était « refusé par AD-1 ». C'ÉTAIT
    // FAUX : AD-1 ne contraint que `zcrud_core`, et 15 satellites dépendaient
    // déjà de paquets pub.dev. Le rendu est désormais choisi via le port
    // `ZReorderRenderer` — le maison n'est que le repli, un satellite peut
    // brancher un paquet de l'écosystème.
    //
    // Seule exclusivité restante : réordonner + VIRTUALISER. Une cellule non
    // construite ne peut pas être une cible de dépôt ; en cas de conflit, la
    // réordonnabilité l'emporte et la grille est rendue *eager* (documenté sur
    // `ZStudyToolsSectionSpec.crossAxisMinItemWidth`, jamais silencieux).
    if (spec.axis == Axis.vertical && spec.onReorder != null) {
      final reorderableMinWidth = spec.crossAxisMinItemWidth;
      if (reorderableMinWidth != null && reorderableMinWidth > 0) {
        return _reorderableGrid(context, theme, reorderableMinWidth);
      }
      return _ReorderableItemList(spec: spec, theme: theme);
    }
    if (spec.axis == Axis.horizontal) {
      // CR-IFFD-62 ④ — espacement inter-items ADRESSABLE : paramètre de spec >
      // jeton `ZcrudTheme.railItemGap` > `gapS` (repli HISTORIQUE). Les voies
      // typées posent la référence (12) ; le constructeur principal garde
      // `gapS` — rendu strictement inchangé pour un hôte qui compose son rail.
      final double itemGap =
          spec.railItemGap ?? theme.railItemGap ?? theme.gapS;
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        // CR-IFFD-62 ④ — retrait latéral PROPRE du rail (`null` ⇒ aucun
        // padding sur le défileur : le retrait vient du padding de section,
        // rendu inchangé).
        padding: railPadding,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < spec.itemCount; i++)
              Padding(
                padding: EdgeInsetsDirectional.only(end: itemGap),
                child: spec.itemBuilder(context, i),
              ),
          ],
        ),
      );
    }
    // CR-IFFD-10 §2 — grille MULTI-COLONNES via `ZAdaptiveGrid` (zcrud_responsive),
    // DÉJÀ dépendu par ce package et déjà utilisé par `z_flashcard_list_view` /
    // `z_multi_flashcard_editor`. On NE réimplémente PAS le calcul de colonnes :
    // `computeCrossAxisCount` gère déjà gouttière, padding, plancher/plafond et
    // les replis AD-10 (NaN/infini/négatif). `null` ⇒ une colonne (rendu antérieur).
    final minWidth = spec.crossAxisMinItemWidth;
    if (minWidth != null && minWidth > 0) {
      // CR-IFFD-11 §2 — hauteur/ratio de cellule TRANSMIS (la primitive les
      // acceptait déjà : seul le câblage manquait, d'où un écart de parité
      // visible sur grand écran).
      // CR-IFFD-11 §4 — mode VIRTUALISÉ : ne construit que le viewport et
      // scrolle de lui-même. Indispensable dès quelques dizaines d'items — en
      // mode eager, TOUT est construit ET layouté, même hors écran.
      if (spec.crossAxisVirtualized) {
        // La grille virtualisée EST la surface scrollable (ni `shrinkWrap`,
        // ni `NeverScrollableScrollPhysics`). Imbriquée telle quelle dans le
        // `ListView.builder` du layout, elle reçoit une hauteur NON BORNÉE et
        // lève « Vertical viewport was given unbounded height ». Une hauteur de
        // viewport EXPLICITE est donc obligatoire — c'est le prix du défilement
        // imbriqué, et l'hôte doit le décider en connaissance de cause.
        assert(
          spec.crossAxisViewportHeight != null,
          'ZStudyToolsSectionSpec(id: ${spec.id}) : `crossAxisVirtualized` exige '
          '`crossAxisViewportHeight` — une grille virtualisee scrolle d\'elle-meme '
          'et ne peut pas etre imbriquee sans hauteur bornee.',
        );
        final viewport = spec.crossAxisViewportHeight;
        if (viewport == null) {
          // Repli DÉFENSIF en release (AD-10) : plutôt la grille eager qu'un
          // crash de rendu.
          return _eagerGrid(context, theme, minWidth);
        }
        return SizedBox(
          height: viewport,
          child: ZAdaptiveGrid.builder(
          itemCount: spec.itemCount,
          itemBuilder: spec.itemBuilder,
          minItemWidth: minWidth,
          spacing: theme.gapS,
          itemHeight: spec.crossAxisItemHeight,
            aspectRatio: spec.crossAxisItemHeight == null
                ? spec.crossAxisAspectRatio
                : null,
            // CR-LEX-77 (chemin 2/3 — VIRTUALISÉ) : plafond de colonnes
            // transmis. `null` ⇒ illimité, rendu inchangé.
            maxColumns: spec.crossAxisMaxColumns,
          ),
        );
      }
      return _eagerGrid(context, theme, minWidth);
    }
    return _singleColumn(context, theme);
  }

  /// Grille MULTI-COLONNES **RÉORDONNABLE** (CR-IFFD-15) — primitive du socle.
  ///
  /// L'ordre optimiste, le geste d'appui long, les actions sémantiques et
  /// l'autoscroll vivent dans `ZReorderableAdaptiveGrid` : ce layout ne fait que
  /// **câbler** le descripteur. Les indices de `onReorder` sont dans la MÊME
  /// convention `removeAt`/`insert` que le mode liste (`zReorderIds`) — l'hôte
  /// persiste à l'identique quel que soit le mode de rendu.
  /// Grille RÉORDONNABLE — résolue par le port `ZReorderRenderer` (AD-57).
  ///
  /// L'hôte peut injecter, via `ZcrudScope(reorderRenderer: …)`, un satellite
  /// adossé à un paquet de l'écosystème ou sa propre implémentation. Sans
  /// injection, le repli **zéro-dépendance** de `zcrud_responsive` s'applique :
  /// la capacité reste fonctionnelle, jamais absente — c'est l'exigence de
  /// défaut d'AD-57, et c'est pourquoi ce chemin ne lève PAS de `ZScopeError`
  /// (contrairement à `ZListRenderer`, dont aucun repli n'est possible sans
  /// backend de grille).
  Widget _reorderableGrid(
    BuildContext context,
    ZcrudTheme theme,
    double minWidth,
  ) {
    final renderer = ZcrudScope.maybeOf(context)?.reorderRenderer ??
        const ZDefaultReorderRenderer();
    // CR-LEX-79 §1 — AFFORDANCE de réordonnancement sur le chemin GRILLE.
    //
    // Elle manquait ENTIÈREMENT ici (ni poignée, ni `Semantics`, ni cible ≥
    // 48 dp) alors que le chemin liste la portait : un hôte qui ajoutait
    // `crossAxisMinItemWidth` à une section déjà réordonnable perdait
    // l'affordance SANS AUCUN SIGNAL — pas d'erreur, pas d'assert, et le
    // glisser continuait de passer en test. L'information « cet élément se
    // déplace » n'est pas une décoration (AD-13).
    //
    // Elle est posée AUTOUR de l'item, EN AMONT du renderer : le port
    // `ZReorderRenderer` (AD-57) ne transporte pas de slot de poignée, et
    // décorer ici garantit l'affordance pour TOUT renderer — le repli
    // `zcrud_responsive` comme un satellite injecté par l'hôte. Aucune
    // modification de `zcrud_responsive` n'est requise.
    final IconData handleIcon = spec.reorderHandleIcon ?? _kDragHandleFallbackIcon;
    final String handleLabel = spec.reorderHandleSemanticLabel ?? spec.title;
    // CR-IFFD-54 ② — mode `hiddenLongPress` : AUCUNE décoration de poignée en
    // amont du renderer (absence STRUCTURELLE, AD-4). Le geste du renderer par
    // défaut est DÉJÀ l'appui long sur la cellule, et la sémantique du
    // déplacement ne vit PAS dans la poignée : les actions « déplacer
    // avant/après » traversent la requête ci-dessous, identiques dans les deux
    // modes (exigence « sémantique conservée » de la CR). Pour un renderer
    // INJECTÉ par l'hôte, le socle garantit l'absence de poignée amont mais
    // pas le geste du renderer (documenté sur [ZStudyReorderHandleMode]).
    final bool hiddenHandle =
        spec.reorderHandleMode == ZStudyReorderHandleMode.hiddenLongPress;
    return renderer.build(
      context,
      ZReorderRenderRequest(
        itemIds: spec.itemIds!,
        itemBuilder: hiddenHandle
            ? spec.itemBuilder
            : (context, index) => _ReorderableGridCell(
                  icon: handleIcon,
                  handleSemanticLabel: handleLabel,
                  theme: theme,
                  child: spec.itemBuilder(context, index),
                ),
        onReorder: spec.onReorder!,
        minItemWidth: minWidth,
        spacing: theme.gapS,
        itemHeight: spec.crossAxisItemHeight,
        aspectRatio:
            spec.crossAxisItemHeight == null ? spec.crossAxisAspectRatio : null,
        // CR-LEX-77 (chemin 3/3 — RÉORDONNABLE) : plafond de colonnes transmis
        // au port `ZReorderRenderer`, dont la requête l'acceptait DÉJÀ (seul le
        // câblage manquait). `null` ⇒ illimité, rendu inchangé.
        maxColumns: spec.crossAxisMaxColumns,
        // Libellés INJECTÉS, avec repli neutre documenté — MÊME patron que
        // `collapseSemanticLabel`/`expandSemanticLabel` (CR-IFFD-11 §3).
        moveBeforeSemanticLabel:
            spec.reorderMoveBeforeSemanticLabel ?? _kMoveBeforeFallbackLabel,
        moveAfterSemanticLabel:
            spec.reorderMoveAfterSemanticLabel ?? _kMoveAfterFallbackLabel,
      ),
    );
  }

  /// Grille EAGER — imbriquée dans le défilement de la page (rendu par défaut).
  Widget _eagerGrid(BuildContext context, ZcrudTheme theme, double minWidth) =>
      ZAdaptiveGrid(
        minItemWidth: minWidth,
        spacing: theme.gapS,
        itemHeight: spec.crossAxisItemHeight,
        aspectRatio:
            spec.crossAxisItemHeight == null ? spec.crossAxisAspectRatio : null,
        // CR-LEX-77 (chemin 1/3 — EAGER) : plafond de colonnes transmis.
        // `null` ⇒ illimité, rendu inchangé.
        maxColumns: spec.crossAxisMaxColumns,
        children: <Widget>[
          for (var i = 0; i < spec.itemCount; i++) spec.itemBuilder(context, i),
        ],
      );

  /// Empilement mono-colonne — rendu historique, préservé à l'identique.
  Widget _singleColumn(BuildContext context, ZcrudTheme theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < spec.itemCount; i++)
          Padding(
            padding: EdgeInsetsDirectional.only(bottom: theme.gapS),
            child: spec.itemBuilder(context, i),
          ),
      ],
    );
  }

  /// En-tête : titre + badge compteur + (optionnel) action d'ajout ≥ 48 dp.
  ///
  /// [trailingCollapse] (CR-IFFD-50 ④) : chevron de repli à poser EN FIN de
  /// ligne quand le thème demande `inHeaderRow`. `null` ⇒ ligne inchangée. Le
  /// titre est le SEUL enfant flexible (`Expanded`) : les cibles tactiles
  /// (actions, chevron) gardent leur largeur ≥ 48 dp même quand le titre est
  /// long — c'est le titre qui s'ellipse, jamais une cible qui rétrécit.
  Widget _buildHeader(
    BuildContext context,
    ZcrudTheme theme, {
    Widget? trailingCollapse,
  }) {
    // **Lot 2** — commande du `+` : paramètre de l'hôte > hub en portée >
    // ABSENT. `addOpensContentHub == false` (défaut) ⇒ `spec.addAction` tel
    // quel : AUCUNE lecture d'`InheritedWidget`, aucun chemin nouveau, rendu
    // strictement antérieur.
    //
    // La résolution du hub est **non dépendante** (`ZContentHubScope.openerOf`
    // → `getInheritedWidgetOfExactType`) : cet en-tête ne s'inscrit PAS comme
    // dépendant du scope. Un hôte qui recompose son launcher à chaque frame ne
    // reconstruit donc AUCUNE section (SM-1, mesuré par garde).
    final VoidCallback? addAction = spec.addAction ??
        (spec.addOpensContentHub ? ZContentHubScope.openerOf(context) : null);
    final Widget title = Text(
      spec.title,
      textAlign: TextAlign.start,
      // CR-IFFD-50 ① — le style du titre est un JETON
      // (`studySectionTitleStyle`) : `null` ⇒ repli historique
      // strictement inchangé (`labelTextStyle`, puis `titleMedium`).
      style: theme.studySectionTitleStyle ??
          theme.labelTextStyle ??
          Theme.of(context).textTheme.titleMedium,
      // CR-IFFD-61 ④ — le titre s'ELLIPSE, dans les DEUX placements. En
      // `adjacentToTitle` il n'est plus `Expanded` mais `Flexible` : sans
      // ellipse, un titre long déborderait au lieu de rétrécir (mesuré à
      // 320 dp). En `lineEnd` le comportement est INCHANGÉ (le `Text` d'un
      // `Expanded` était déjà borné en largeur, et sans `maxLines` il
      // enroulait — c'est pourquoi l'ellipse n'est posée QUE sur le chemin
      // adjacent, ci-dessous).
    );
    // CR-IFFD-61 ④ — écart titre↔compteur ADRESSABLE (`null` ⇒ `gapS`, le
    // rendu historique) : il ridait `gapS`, partagé avec toutes les autres
    // gouttières de l'en-tête, alors que la référence pose 12 ICI seulement.
    final double countGap = theme.studySectionCountGap ?? theme.gapS;
    final Widget countBadge =
        _CountBadge(count: spec.headerCount ?? spec.itemCount, theme: theme);
    // CR-IFFD-61 ④ — PLACEMENT du compteur. `null`/`lineEnd` ⇒ titre `Expanded`
    // qui POUSSE le compteur à l'extrémité (rendu historique, strictement
    // inchangé). `adjacentToTitle` ⇒ le compteur SUIT le titre : c'est le titre
    // qu'il qualifie (« Notes — 6 »), pas le bord de l'écran.
    //
    // Le compteur n'est JAMAIS écrasé par un titre long : il reste
    // INFLEXIBLE et c'est le titre qui est `Flexible` + ellipsé. Le `Expanded`
    // enveloppant l'ensemble garde les cibles tactiles (actions, chevron) à
    // leur largeur pleine — l'invariant de CR-IFFD-50 est préservé.
    final bool adjacent = theme.studySectionCountPlacement ==
        ZStudySectionCountPlacement.adjacentToTitle;
    return Semantics(
      header: true,
      child: Row(
        children: [
          if (adjacent)
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: DefaultTextStyle.merge(
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      child: title,
                    ),
                  ),
                  SizedBox(width: countGap),
                  countBadge,
                ],
              ),
            )
          else ...[
            Expanded(child: title),
            SizedBox(width: countGap),
            countBadge,
          ],
          // CR-IFFD-10 §3 — action secondaire (ex. « Afficher tout »), rendue
          // AVANT l'ajout : consultation avant création. `null` ⇒ ABSENTE (AD-4).
          if (spec.secondaryAction != null) ...[
            SizedBox(width: theme.gapS),
            ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: _kMinTapTarget,
                minHeight: _kMinTapTarget,
              ),
              // CR-IFFD-50 ③ — libellé VISIBLE à côté de l'icône quand
              // `secondaryActionLabel` est fourni (c'est de l'INFORMATION :
              // une icône seule n'est pas auto-descriptive, AD-13). `null` ⇒
              // icône seule, strictement le rendu antérieur.
              child: spec.secondaryActionLabel == null
                  ? IconButton(
                      key: ValueKey<String>(
                        'section:${spec.id}:secondaryAction',
                      ),
                      onPressed: spec.secondaryAction,
                      tooltip: spec.secondaryActionSemanticLabel ?? spec.title,
                      icon: Icon(
                        spec.secondaryActionIcon ?? Icons.arrow_forward,
                        semanticLabel:
                            spec.secondaryActionSemanticLabel ?? spec.title,
                      ),
                    )
                  : TextButton.icon(
                      key: ValueKey<String>(
                        'section:${spec.id}:secondaryAction',
                      ),
                      onPressed: spec.secondaryAction,
                      // Glyphe DÉCORATIF (aucun `semanticLabel`) : l'annonce
                      // vient du libellé — UNE seule source de sémantique,
                      // jamais deux annonces divergentes (règle v0.36.0,
                      // feuille de fratrie).
                      icon: Icon(spec.secondaryActionIcon ?? Icons.arrow_forward),
                      // `secondaryActionSemanticLabel` fourni ⇒ il PRIME comme
                      // annonce (l'hôte sait) — le libellé visible reste rendu,
                      // sa sémantique propre est REMPLACÉE (pas doublée).
                      label: spec.secondaryActionSemanticLabel == null
                          ? Text(spec.secondaryActionLabel!)
                          : Semantics(
                              label: spec.secondaryActionSemanticLabel,
                              excludeSemantics: true,
                              child: Text(spec.secondaryActionLabel!),
                            ),
                    ),
            ),
          ],
          // Callback `null` = action ABSENTE (AD-4) : aucun bouton rendu.
          if (addAction != null) ...[
            SizedBox(width: theme.gapS),
            // Solde DW-ES51-1 MEDIUM-1 + LOW-2 : UNE seule source de sémantique
            // de bouton — le label INJECTÉ (qui prime sur `spec.title`) porté
            // par `Icon.semanticLabel` et fusionné dans le nœud bouton de
            // l'`IconButton` ; plus de `Semantics(button:true)` enveloppant
            // redondant. Icône INJECTÉE (repli neutre documenté). Le `tooltip`
            // rend le MÊME label visible au survol (desktop) sans dupliquer le
            // nœud bouton.
            ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: _kMinTapTarget,
                minHeight: _kMinTapTarget,
              ),
              child: IconButton(
                onPressed: addAction,
                tooltip: spec.addActionSemanticLabel ?? spec.title,
                icon: Icon(
                  spec.addActionIcon ?? _kAddActionFallbackIcon,
                  semanticLabel: spec.addActionSemanticLabel ?? spec.title,
                ),
              ),
            ),
          ],
          // CR-IFFD-50 ④ — chevron de repli DANS la ligne d'en-tête, côté fin
          // (après les actions), quand le thème le demande. `null` ⇒ absent
          // (le chevron reste rendu sous le titre, rendu historique).
          if (trailingCollapse != null) ...[
            SizedBox(width: theme.gapS),
            trailingCollapse,
          ],
        ],
      ),
    );
  }
}

/// Liste d'items RÉORDONNABLE d'une section (ES-5.3) — sous-arbre LOCAL isolé.
///
/// `StatefulWidget` **délibéré** (SM-1/AD-2) : l'ordre optimiste vit ICI, sous la
/// frontière keyée `ValueKey('section:$id')` — réordonner ne déclenche donc
/// AUCUN `setState` au niveau page/section et ne reconstruit NI les autres
/// sections NI la page (invariant AC2). Le rendu se fait via
/// `ReorderableListView.builder` du **SDK Flutter** (repli zéro-dépendance,
/// AD-57 — et NON parce qu'un paquet tiers serait interdit), `shrinkWrap: true` +
/// `NeverScrollableScrollPhysics` (imbriqué dans le `ListView.builder` du
/// layout), enfants keyés `ValueKey(id)` (clé STABLE requise), poignée
/// directionnelle a11y ≥ 48 dp.
class _ReorderableItemList extends StatefulWidget {
  const _ReorderableItemList({required this.spec, required this.theme});

  final ZStudyToolsSectionSpec spec;
  final ZcrudTheme theme;

  @override
  State<_ReorderableItemList> createState() => _ReorderableItemListState();
}

class _ReorderableItemListState extends State<_ReorderableItemList> {
  /// Ordre OPTIMISTE local des ids (permutation de `spec.itemIds`), porté par un
  /// `ValueNotifier` — réactivité Flutter-native pure (AD-2/AD-15, **aucun
  /// `setState`** : le rebuild est confiné au seul [ValueListenableBuilder] du
  /// sous-arbre de la section, jamais propagé à la page ni aux autres sections —
  /// invariant SM-1/AC2). Muté au drop pour un retour visuel immédiat, puis
  /// persisté par l'appelant via `spec.onReorder` (AD-26). Resynchronisé si
  /// l'appelant repousse un nouvel ordre persisté (didUpdateWidget).
  late final ValueNotifier<List<String>> _ids;

  @override
  void initState() {
    super.initState();
    _ids = ValueNotifier<List<String>>(List<String>.of(widget.spec.itemIds!));
  }

  @override
  void didUpdateWidget(covariant _ReorderableItemList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // L'appelant a persisté puis repoussé un nouvel ordre (ou la section a
    // changé d'items) : réaligner l'ordre local sur la source de vérité.
    if (!_listEquals(widget.spec.itemIds!, oldWidget.spec.itemIds!)) {
      _ids.value = List<String>.of(widget.spec.itemIds!);
    }
  }

  @override
  void dispose() {
    _ids.dispose();
    super.dispose();
  }

  void _handleReorder(int oldIndex, int newIndex) {
    // `onReorderItem` (SDK ≥ v3.41) fournit un `newIndex` DÉJÀ ajusté pour le
    // retrait de l'item à `oldIndex` — c.-à-d. déjà en convention
    // `removeAt(oldIndex)`/`insert(newIndex)` (aucun `-1` manuel à appliquer).
    // Mutation de la tranche ⇒ rebuild ciblé du seul ValueListenableBuilder.
    _ids.value = zReorderIds(_ids.value, oldIndex, newIndex);
    // Notifie l'appelant (persistance ZFolderContentsOrder, AD-26) avec les
    // MÊMES indices normalisés que ceux appliqués localement (symétrie).
    widget.spec.onReorder!(oldIndex, newIndex);
  }

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    final theme = widget.theme;
    return ValueListenableBuilder<List<String>>(
      valueListenable: _ids,
      builder: (context, ids, _) => ReorderableListView.builder(
        // Imbriqué dans le ListView.builder du layout (GOTCHA R14).
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        // Poignée FOURNIE (directionnelle + a11y ≥ 48 dp) plutôt que la poignée
        // par défaut du SDK (non directionnelle, sans label injecté).
        buildDefaultDragHandles: false,
        itemCount: ids.length,
        // `onReorderItem` (remplace `onReorder`, obsolète) : `newIndex` ajusté.
        onReorderItem: _handleReorder,
        itemBuilder: (context, index) {
          final id = ids[index];
          // Index d'origine (côté appelant) de l'item courant : `itemBuilder`
          // rend par l'index de `spec.itemIds`, or l'ordre local a pu permuter.
          final originalIndex = spec.itemIds!.indexOf(id);
          // CR-IFFD-54 ② — mode `hiddenLongPress` : la poignée est ABSENTE de
          // l'arbre (AD-4) et le déclencheur devient l'APPUI LONG sur l'item
          // entier (`ReorderableDelayedDragStartListener` du SDK — mesuré : le
          // drag délayé réordonne réellement). La sémantique est CONSERVÉE
          // sans la poignée : `SliverReorderableList` pose ses actions
          // « move up/down/to start/to end » (`WidgetsLocalizations`) sur
          // CHAQUE item, indépendamment de tout drag handle — prouvé par
          // garde (l'action sémantique répond encore en mode masqué).
          if (spec.reorderHandleMode ==
              ZStudyReorderHandleMode.hiddenLongPress) {
            return ReorderableDelayedDragStartListener(
              // Clé STABLE requise par ReorderableListView — même règle que le
              // mode visible (l'id opaque, jamais l'index).
              key: ValueKey(id),
              index: index,
              child: Padding(
                padding: EdgeInsetsDirectional.only(bottom: theme.gapS),
                child: spec.itemBuilder(
                    context, originalIndex < 0 ? index : originalIndex),
              ),
            );
          }
          return _ReorderableItemRow(
            // Clé STABLE requise par ReorderableListView (« every item must have
            // a key ») — l'id opaque de l'item, jamais l'index.
            key: ValueKey(id),
            index: index,
            handleSemanticLabel: spec.reorderHandleSemanticLabel ?? spec.title,
            // CR-LEX-79 §2 — glyphe INJECTÉ (repli neutre documenté), MÊME
            // patron que `addActionIcon`/`secondaryActionIcon`.
            handleIcon: spec.reorderHandleIcon ?? _kDragHandleFallbackIcon,
            theme: theme,
            child: spec.itemBuilder(
                context, originalIndex < 0 ? index : originalIndex),
          );
        },
      ),
    );
  }
}

/// Une ligne réordonnable : l'item de l'appelant + une poignée de drag
/// DIRECTIONNELLE, a11y (`Semantics` label INJECTÉ) et cible ≥ 48 dp.
class _ReorderableItemRow extends StatelessWidget {
  const _ReorderableItemRow({
    required this.index,
    required this.handleSemanticLabel,
    required this.handleIcon,
    required this.theme,
    required this.child,
    super.key,
  });

  final int index;
  final String handleSemanticLabel;

  /// Glyphe de la poignée — INJECTÉ par l'appelant, repli neutre documenté
  /// ([_kDragHandleFallbackIcon]) résolu par l'appelant (CR-LEX-79 §2).
  final IconData handleIcon;
  final ZcrudTheme theme;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.only(bottom: theme.gapS),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: child),
          SizedBox(width: theme.gapS),
          // Poignée : label a11y INJECTÉ, cible ≥ 48 dp, déclencheur de drag SDK.
          ReorderableDragStartListener(
            index: index,
            child: Semantics(
              container: true,
              label: handleSemanticLabel,
              button: true,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: _kMinTapTarget,
                  minHeight: _kMinTapTarget,
                ),
                // Le glyphe est décoratif ; l'annonce a11y vient du Semantics
                // parent (label INJECTÉ) — pas de label sur l'icône.
                child: Icon(handleIcon),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Cellule de GRILLE réordonnable : l'item de l'appelant + la MÊME poignée
/// visible que le chemin liste (CR-LEX-79 §1).
///
/// ## Pourquoi ce widget existe
///
/// `ZReorderableAdaptiveGrid` (`zcrud_responsive`) déclenche le déplacement par
/// **appui long sur la cellule entière** et n'affiche rien : la capacité était
/// donc **invisible au voyant** et **inatteignable comme information** pour le
/// lecteur d'écran, alors que le chemin liste portait poignée + label + cible
/// 48 dp. Pire, la perte était SILENCIEUSE à l'adoption (ajouter
/// `crossAxisMinItemWidth` suffisait à la provoquer, sans erreur ni assert).
///
/// ## Ce qu'elle est — et ce qu'elle n'est PAS
///
/// C'est une **affordance** : un repère visuel + un nœud `Semantics` au libellé
/// INJECTÉ, dimensionné ≥ 48 dp (AD-13). Ce n'est **pas** un second déclencheur
/// de drag : le geste reste l'appui long, qui fonctionne sur la poignée comme
/// sur le reste de la cellule (la poignée est *à l'intérieur* du
/// `LongPressDraggable`). `ReorderableDragStartListener` serait ici **inerte** —
/// il ne fait rien hors d'un `SliverReorderableList` du SDK — et un `Draggable`
/// local ne connaîtrait pas la **position d'affichage** attendue par le
/// protocole de dépôt (l'`itemBuilder` reçoit l'index SOURCE). Une poignée qui
/// *paraîtrait* déclencher sans déclencher serait pire que pas de poignée.
///
/// Le nœud n'est donc PAS marqué `button: true` (contrairement au chemin liste,
/// où la poignée EST le point de départ du geste) : il annonce une information,
/// il n'ouvre pas d'action. L'alternative accessible au geste reste portée par
/// les actions sémantiques « déplacer avant/après » de la cellule du socle.
class _ReorderableGridCell extends StatelessWidget {
  const _ReorderableGridCell({
    required this.icon,
    required this.handleSemanticLabel,
    required this.theme,
    required this.child,
  });

  final IconData icon;
  final String handleSemanticLabel;
  final ZcrudTheme theme;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      // MÊME structure que `_ReorderableItemRow` (poignée en fin de ligne, côté
      // `end` — directionnelle par construction, jamais `left`/`right`).
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(child: child),
        SizedBox(width: theme.gapS),
        Semantics(
          container: true,
          label: handleSemanticLabel,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: _kMinTapTarget,
              minHeight: _kMinTapTarget,
            ),
            // Glyphe décoratif : l'annonce vient du `Semantics` parent (label
            // INJECTÉ) — jamais un second label sur l'icône.
            child: Icon(icon),
          ),
        ),
      ],
    );
  }
}

/// Comparaison positionnelle de deux listes d'ids (ordre-sensible).
bool _listEquals(List<String> a, List<String> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Badge de compteur d'items (chrome thémé, aucune couleur codée en dur).
///
/// Solde DW-ES51-1 LOW-1/LOW-2 : rayon/paddings tirés des tokens
/// [ZcrudTheme.radiusM]/[ZcrudTheme.gapS]/[ZcrudTheme.gapM] (plus de
/// `circular(10)`/`8`/`2` en dur) ; `Semantics(label:)` redondant supprimé (le
/// `Text('$count')` porte déjà l'annonce — une seule source de sémantique).
///
/// CR-IFFD-50 ② — forme ([ZcrudTheme.studySectionCountShape]) et RÔLE de
/// couleur ([ZcrudTheme.studySectionCountRole]) adressables : la couleur vient
/// TOUJOURS d'un rôle du `ColorScheme` choisi par l'hôte, jamais d'un hex
/// (FR-26 — la frontière CR-IFFD-48 : la forme monte, la matière reste au
/// thème). `null`/`null` ⇒ rectangle arrondi `secondaryContainer`, rendu
/// **strictement inchangé**.
///
/// 🔵 **Pourquoi PAS [ZCountBadge]** (public, `z_subfolder_item_chrome.dart`) :
/// ce n'est pas un doublon divergent mais un contrat DIFFÉRENT — `ZCountBadge`
/// (1) **exige une icône** injectée (le compteur d'en-tête n'en a pas),
/// (2) **refuse `count == 0`** par assert (une section vide affiche
/// légitimement « 0 »), (3) impose une cible `kMinInteractiveDimension`
/// (≥ 48 dp) là où ce badge est une annotation informative non interactive —
/// l'adopter changerait la géométrie par défaut de tous les en-têtes.
class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count, required this.theme});

  final int count;
  final ZcrudTheme theme;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // CR-IFFD-50 ② — rôle → couple (fond, premier plan) du `ColorScheme`
    // COURANT. Aucun hex : l'hôte nomme un rôle, le schéma fournit la matière.
    final ZStudySectionCountRole role =
        theme.studySectionCountRole ?? ZStudySectionCountRole.secondaryContainer;
    final (Color background, Color foreground) = switch (role) {
      ZStudySectionCountRole.secondaryContainer => (
          scheme.secondaryContainer,
          scheme.onSecondaryContainer,
        ),
      ZStudySectionCountRole.primaryContainer => (
          scheme.primaryContainer,
          scheme.onPrimaryContainer,
        ),
      ZStudySectionCountRole.primary => (scheme.primary, scheme.onPrimary),
      ZStudySectionCountRole.tertiaryContainer => (
          scheme.tertiaryContainer,
          scheme.onTertiaryContainer,
        ),
      ZStudySectionCountRole.inverseSurface => (
          scheme.inverseSurface,
          scheme.onInverseSurface,
        ),
    };
    final ZStudySectionCountShape shape =
        theme.studySectionCountShape ?? ZStudySectionCountShape.rounded;
    return Container(
      padding: EdgeInsetsDirectional.symmetric(
        horizontal: theme.gapM,
        vertical: theme.gapS,
      ),
      // `pill` = stadium (coins à la demi-hauteur, quel que soit le contenu) ;
      // `rounded` (défaut) = rectangle `radiusM`, rendu historique inchangé.
      decoration: shape == ZStudySectionCountShape.pill
          ? ShapeDecoration(
              color: background,
              shape: const StadiumBorder(),
            )
          : BoxDecoration(
              color: background,
              borderRadius: BorderRadius.all(theme.radiusM),
            ),
      child: Text(
        '$count',
        textAlign: TextAlign.start,
        style: TextStyle(color: foreground),
      ),
    );
  }
}

/// Corps repliable d'une section (CR-IFFD-10 §1) — **état local par DÉFAUT**,
/// **commandable par l'hôte** quand la spec porte un
/// [ZStudyToolsSectionSpec.expandController] (CR-IFFD-38).
///
/// `StatefulWidget` sous la frontière keyée `ValueKey('section:$id')` : basculer
/// le repli ne déclenche AUCUN `setState` au niveau page/section et ne
/// reconstruit NI les autres sections NI la page (SM-1/AD-2), exactement comme
/// l'ordre optimiste de `_ReorderableItems`.
///
/// Depuis CR-IFFD-38, le repli n'est même plus reconstruit par un `setState`
/// **de section** : il est lu par un `ValueListenableBuilder` branché sur la
/// liaison. Et quand l'hôte pilote, la valeur est lue **et écrite chez lui** —
/// la section n'en garde aucune copie, donc rien ne peut diverger (le chevron
/// et le second chemin de l'hôte commandent le même et unique état).
class _CollapsibleBody extends StatefulWidget {
  const _CollapsibleBody({
    required this.spec,
    required this.theme,
    required this.body,
    required this.collapseInHeader,
    this.headerBuilder,
  });

  final ZStudyToolsSectionSpec spec;
  final ZcrudTheme theme;
  final Widget body;

  /// CR-IFFD-50 ④ — `true` quand le thème place le chevron DANS la ligne
  /// d'en-tête. Distinct de la présence de [headerBuilder] depuis CR-IFFD-54 ①
  /// (une ligne-bascule en placement historique construit AUSSI l'en-tête ici,
  /// chevron restant SOUS le titre).
  final bool collapseInHeader;

  /// Non-null quand l'en-tête doit être construit PAR ce widget (propriétaire
  /// de l'état de repli) : chevron dans la ligne (CR-50 ④, `trailingCollapse`
  /// non-null) et/ou ligne-bascule (CR-54 ①). Toujours via le `_buildHeader`
  /// de la section — jamais un second en-tête. `null` ⇒ l'en-tête reste
  /// construit par la section, chevron SOUS le titre (rendu historique).
  final Widget Function(BuildContext context, Widget? trailingCollapse)?
      headerBuilder;

  @override
  State<_CollapsibleBody> createState() => _CollapsibleBodyState();
}

class _CollapsibleBodyState extends State<_CollapsibleBody> {
  /// Liaison CR-IFFD-38 — état interne par défaut, contrôleur de l'hôte s'il
  /// y en a un. **Jamais un miroir** : quand l'hôte pilote, lecture et écriture
  /// le traversent (cf. `ZDisplayStateBinding`).
  late final ZDisplayStateBinding<bool> _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = ZDisplayStateBinding<bool>(
      consumer: this,
      initialValue: widget.spec.initiallyExpanded,
    )..bind(widget.spec.expandController);
  }

  @override
  void didUpdateWidget(covariant _CollapsibleBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    // L'hôte a le droit de changer (ou de retirer) son pilote : sans cela la
    // section resterait branchée sur l'ancien, muette pour le nouveau.
    _expanded.bind(widget.spec.expandController);
  }

  @override
  void dispose() {
    // Ne dispose JAMAIS le contrôleur de l'hôte : il ne nous appartient pas.
    _expanded.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget Function(BuildContext, Widget?)? headerBuilder =
        widget.headerBuilder;
    if (headerBuilder == null) {
      // Rendu HISTORIQUE (chevron sous le titre) — structure inchangée.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // AD-2/SM-1 — SEULE la tranche de repli se reconstruit : ni la page,
          // ni les autres sections, ni le corps déjà construit.
          ValueListenableBuilder<bool>(
            valueListenable: _expanded.listenable,
            builder: _buildCollapse,
          ),
        ],
      );
    }
    // CR-IFFD-50 ④ — chevron DANS la ligne d'en-tête, côté fin. L'en-tête
    // lui-même reste STATIQUE (hors tranche réactive) : seuls le glyphe du
    // chevron et le corps replié écoutent l'état — SM-1 préservé.
    Widget header = headerBuilder(
      context,
      widget.collapseInHeader
          ? ValueListenableBuilder<bool>(
              valueListenable: _expanded.listenable,
              builder: (BuildContext context, bool expanded, Widget? _) =>
                  _collapseButton(expanded),
            )
          : null,
    );
    if (widget.spec.collapseOnHeaderTap) {
      // CR-IFFD-54 ① — TOUTE la ligne d'en-tête est zone de bascule.
      //
      // La demande est le GESTE, pas la structure : l'`InkWell` n'écoute pas
      // l'état (le closure ÉCRIT à la source au tap) — la ligne reste hors
      // tranche réactive, SM-1 intact (gardé par comptage de builds).
      //
      // Priorité tactile MESURÉE : les reconnaisseurs INTERNES (chevron,
      // `secondaryAction`, `addAction`) gagnent l'arène contre cette zone —
      // un tap sur « Afficher tout » ne replie JAMAIS ; un tap sur le chevron
      // bascule UNE fois (l'arène n'accorde qu'un vainqueur).
      //
      // UNE seule annonce (règle v0.36.0) : la zone est EXCLUE de la
      // sémantique — l'annonce de bascule reste portée par le seul chevron
      // (libellés injectés). L'arbre sémantique est STRICTEMENT inchangé.
      //
      // AD-13 : la ligne entière ≥ 48 dp (elle est désormais interactive).
      header = InkWell(
        key: ValueKey<String>('section:${widget.spec.id}:headerToggle'),
        onTap: () => _expanded.value = !_expanded.value,
        excludeFromSemantics: true,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _kMinTapTarget),
          child: header,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        header,
        if (widget.collapseInHeader)
          ValueListenableBuilder<bool>(
            valueListenable: _expanded.listenable,
            builder: (BuildContext context, bool expanded, Widget? _) =>
                _animatedBody(expanded),
          )
        else
          // CR-IFFD-54 ① en placement HISTORIQUE (`belowTitle`) : le chevron
          // reste rendu SOUS le titre — même tranche `_buildCollapse` que le
          // rendu historique, seule la ligne d'en-tête a migré ci-dessus.
          ValueListenableBuilder<bool>(
            valueListenable: _expanded.listenable,
            builder: _buildCollapse,
          ),
      ],
    );
  }

  /// Chevron de repli — MÊME bouton (clé, libellés, cible ≥ 48 dp) quel que
  /// soit le placement (CR-IFFD-50 ④) : une seule source, aucune divergence.
  ///
  /// CR-IFFD-11 §3 — libellés INJECTÉS ; les replis `'Replier'`/`'Déplier'`
  /// sont un HÉRITAGE assumé (chaînes FR en dur, écart FR-26 documenté et
  /// conservé pour la rétro-compatibilité stricte — tout hôte i18n DOIT
  /// fournir `collapseSemanticLabel`/`expandSemanticLabel`).
  Widget _collapseButton(bool expanded) {
    final label = expanded
        ? (widget.spec.collapseSemanticLabel ?? 'Replier')
        : (widget.spec.expandSemanticLabel ?? 'Déplier');
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: _kMinTapTarget,
        minHeight: _kMinTapTarget,
      ),
      child: IconButton(
        key: ValueKey<String>('section:${widget.spec.id}:collapse'),
        // Écrit À LA SOURCE : avec un contrôleur, le chevron commande
        // l'état de l'hôte — les deux chemins n'en font qu'un.
        onPressed: () => _expanded.value = !_expanded.value,
        tooltip: label,
        icon: Icon(
          expanded ? Icons.expand_less : Icons.expand_more,
          semanticLabel: '$label ${widget.spec.title}',
        ),
      ),
    );
  }

  /// Corps replié/déplié animé — partagé par les deux placements.
  ///
  /// CR-IFFD-11 §5 — transition ANIMÉE, sauf sous Reduce Motion.
  /// Comportement demandé et retenu : ~200 ms, courbe standard ; sous
  /// `MediaQuery.disableAnimationsOf` la transition est INSTANTANÉE (durée
  /// nulle) — aucun mouvement, mais **état final identique** dans les deux
  /// modes. `AnimatedSize` avec `duration: Duration.zero` rend exactement
  /// l'état final sans frame intermédiaire : une seule branche de rendu,
  /// jamais deux arbres divergents (AD-13).
  Widget _animatedBody(bool expanded) => _AnimatedCollapse(
        expanded: expanded,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(height: widget.theme.gapS),
            widget.body,
          ],
        ),
      );

  Widget _buildCollapse(BuildContext context, bool expanded, Widget? _) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: _collapseButton(expanded),
        ),
        _animatedBody(expanded),
      ],
    );
  }
}

/// Transition de repli — animée, **instantanée sous Reduce Motion** (CR-IFFD-11 §5).
///
/// Sous Reduce Motion, **aucun animateur n'est monté** : le sous-arbre est rendu
/// directement. Ce n'est pas une animation de durée nulle — `AnimatedSize` avec
/// `Duration.zero` se re-salit pendant son propre `performLayout` et lève
/// « A RenderAnimatedSize was mutated in its own performLayout implementation ».
/// L'**état final est identique** dans les deux modes ; seule disparaît la
/// transition (AD-13).
class _AnimatedCollapse extends StatelessWidget {
  const _AnimatedCollapse({required this.expanded, required this.child});

  final bool expanded;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final body = expanded ? child : const SizedBox.shrink();
    if (MediaQuery.disableAnimationsOf(context)) return body;
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      alignment: AlignmentDirectional.topStart.resolve(
        Directionality.of(context),
      ),
      child: body,
    );
  }
}
