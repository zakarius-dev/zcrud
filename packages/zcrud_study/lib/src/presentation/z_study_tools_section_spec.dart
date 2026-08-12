/// `ZStudyToolsSectionSpec` — descripteur paramétrique d'une section
/// « study tools » (rail de flashcards, grille de documents, de notes, de
/// cartes mentales…).
///
/// Data-class de présentation immuable (`const`) : elle décrit ce qu'il faut
/// rendre (titre et compteur, items paginés par `itemBuilder`, état vide,
/// action d'ajout) sans jamais référencer un modèle d'application, ni coder
/// en dur une `Color`, une `IconData` ou un libellé — couleurs, libellés et
/// localisation sont fournis par l'appelant (invariant AD-13). Le
/// descripteur n'est pas l'entité domaine : c'est une projection de
/// présentation paramétrique.
library;

import 'package:flutter/widgets.dart';
import 'package:zcrud_core/zcrud_core.dart'
    show
        ZGradientSpec,
        ZStudyCardContentAlignment,
        ZStudyCardHierarchy,
        ZToggleController;
import 'package:zcrud_exam/zcrud_exam.dart' show ZExam;
import 'package:zcrud_flashcard/zcrud_flashcard.dart'
    show ZFlashcard, ZFlashcardContentBuilder;
import 'package:zcrud_mindmap/zcrud_mindmap.dart' show ZMindmap;
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart'
    show ZColorPalette, ZFlashcardTag;

import 'z_default_exam_card.dart';
import 'z_default_flashcard_card.dart';
import 'z_default_mindmap_card.dart';
import 'z_flashcard_card_reference.dart';
import 'z_rail_item.dart';

/// Espacement de référence entre deux items d'un rail horizontal — 12 dp.
///
/// C'est le défaut des voies typées (qui rendent les cartes par défaut) ; le
/// constructeur principal, lui, garde `gapS` — voir `railItemGap`.
const double kZRailItemReferenceGap = 12;

/// Mode de présentation de la poignée de réordonnancement.
///
/// Ce réglage vit sur le descripteur de section plutôt que sur le thème,
/// parce qu'il ne déplace pas du chrome : il change le contrat de geste de
/// la section, et sa validité dépend du contenu de la section — un item dont
/// la carte consomme déjà l'appui long rendrait un mode [hiddenLongPress]
/// inopérant (glisser mort). Seul le descripteur, qui connaît
/// `onCardLongPress` sur les voies typées, peut refuser ce conflit à la
/// construction ; un token de thème l'aurait rendu indétectable puisque le
/// thème ne sait rien du contenu. C'est aussi la surface où vit déjà toute
/// la famille de la poignée (`reorderHandleIcon`,
/// `reorderHandleSemanticLabel`).
enum ZStudyReorderHandleMode {
  /// Poignée affichée (défaut, rendu inchangé) : glyphe `reorderHandleIcon`
  /// et nœud `Semantics` ≥ 48 dp sur chaque item.
  visible,

  /// Poignée masquée, réordonnancement par appui long sur l'item. La
  /// sémantique est conservée :
  /// - côté liste, les actions sémantiques du SDK (« déplacer vers le haut /
  ///   bas / au début / à la fin ») sont posées sur chaque item
  ///   indépendamment de toute poignée : le lecteur d'écran réordonne
  ///   encore, poignée absente ;
  /// - côté grille, les actions `reorderMoveBeforeSemanticLabel` et
  ///   `reorderMoveAfterSemanticLabel` vivent dans `ZReorderRenderRequest`,
  ///   pas dans la poignée, qui n'y a jamais été un déclencheur.
  ///
  /// Une carte qui consomme déjà l'appui long (`onLongPress` d'`InkWell`)
  /// gagne l'arène de gestes contre le glisser (grille comme liste) : le
  /// glisser ne démarre jamais depuis une telle carte. En mode [visible], la
  /// poignée reste un déclencheur qui échappe à l'`InkWell` de la carte ; en
  /// mode masqué, il ne resterait aucun déclencheur tactile si la carte
  /// consomme déjà l'appui long. Les voies typées refusent donc la
  /// combinaison `hiddenLongPress` + `onCardLongPress` + `onReorder` à la
  /// construction (assert ; en mode release, repli sur le mode [visible] —
  /// invariant AD-10, capacité conservée, jamais un glisser mort). Sur le
  /// constructeur principal, l'`itemBuilder` est opaque : ce paquet ne peut
  /// pas détecter un appui long consommé par l'item de l'hôte — c'est
  /// documenté ici, à l'hôte d'arbitrer.
  ///
  /// Côté grille, ce mode se traduit par l'absence de décoration de poignée
  /// en amont du renderer de réordonnancement. Le renderer par défaut
  /// réordonne déjà par appui long : le mode le traverse intact. Pour un
  /// renderer injecté par l'hôte, ce paquet garantit l'absence de poignée
  /// amont mais pas le geste du renderer lui-même — le déclencheur et la
  /// sémantique du glisser y appartiennent à l'hôte.
  hiddenLongPress,
}

/// Descripteur immuable d'une section de la page « study tools ».
///
/// Une instance par section (rail de flashcards, grille de documents, grille
/// de notes, grille de cartes mentales…). Chaque section est rendue par
/// [ZSectionedStudyLayout] dans son propre sous-arbre isolé (frontière de
/// rebuild — invariant AD-2).
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
    this.addOpensContentHub = false,
    this.axis = Axis.vertical,
    this.itemIds,
    this.onReorder,
    this.reorderHandleSemanticLabel,
    this.reorderHandleIcon,
    this.reorderMoveBeforeSemanticLabel,
    this.reorderMoveAfterSemanticLabel,
    this.reorderHandleMode = ZStudyReorderHandleMode.visible,
    this.collapsible = false,
    this.initiallyExpanded = true,
    this.collapseOnHeaderTap = false,
    this.crossAxisMinItemWidth,
    this.crossAxisItemHeight,
    this.crossAxisAspectRatio,
    this.crossAxisMaxColumns,
    this.crossAxisVirtualized = false,
    this.crossAxisViewportHeight,
    this.railItemGap,
    this.railPadding,
    this.collapseSemanticLabel,
    this.expandSemanticLabel,
    this.headerCount,
    this.secondaryAction,
    this.secondaryActionIcon,
    this.secondaryActionLabel,
    this.secondaryActionSemanticLabel,
    this.expandController,
  })  : assert(itemCount >= 0, 'itemCount ne peut être négatif'),
        // AD-4/AD-10 — cohérence de développement (assert, jamais de throw
        // runtime persistant) : une section réordonnable ([onReorder] non-null)
        // EXIGE des clés stables ([itemIds]) de longueur [itemCount] — sans quoi
        // `ReorderableListView` ne peut ni keyer ni mapper le déplacement.
        assert(
          onReorder == null ||
              (itemIds != null && itemIds.length == itemCount),
          'onReorder != null exige itemIds non-null de longueur itemCount',
        ),
        // Un mode de poignée sur une section NON réordonnable serait un
        // réglage silencieusement inerte (invariant AD-4 : jamais de no-op).
        assert(
          reorderHandleMode == ZStudyReorderHandleMode.visible ||
              onReorder != null,
          'reorderHandleMode: hiddenLongPress exige onReorder — le mode de '
          'poignée n\'a de sens que sur une section réordonnable (AD-4 : '
          'jamais un réglage silencieusement inerte).',
        ),
        // Même règle : une zone de bascule sur une section non repliable
        // serait un réglage silencieusement inerte (invariant AD-4).
        assert(
          !collapseOnHeaderTap || collapsible,
          'collapseOnHeaderTap exige collapsible: true — la ligne d\'en-tête '
          'ne peut être une zone de bascule que si la section se replie '
          '(AD-4 : jamais un réglage silencieusement inerte).',
        );

  /// Section de **flashcards** dont le socle fournit le rendu d'item — la voie
  /// TYPÉE qui **porte les données**.
  ///
  /// **Pourquoi un constructeur nommé et PAS un `itemBuilder` facultatif.**
  /// Le descripteur porte `itemCount` + `itemBuilder(context, index)` et
  /// **aucune donnée** : rendre `itemBuilder` facultatif ne permettrait au socle
  /// de rendre **rien du tout**, faute de savoir ce qu'est l'item numéro *i*. Ce
  /// constructeur fournit l'information manquante ([cards]) et fabrique
  /// lui-même [itemCount] **et** un [itemBuilder] bâti sur
  /// [ZDefaultFlashcardCard].
  ///
  /// **Non-cassant par construction** : [itemBuilder] reste `required` dans le
  /// constructeur principal — un hôte qui fournit déjà le sien n'est **pas**
  /// touché, et ne **peut pas** l'être (aucune branche de repli n'existe).
  ///
  /// **Réordonnancement sans affaiblir l'invariant.** La voie typée accepte
  /// [onReorder] (et les libellés/glyphes de réordonnancement), mais
  /// [itemIds] n'est **jamais** fourni par l'hôte : il est **DÉRIVÉ ici** de
  /// `cards[i].id`, si bien que la garde générale du constructeur principal
  /// (« onReorder ⇒ identité stable par item ») devient **vérifiée sur
  /// pièces** — plus forte, pas assouplie. Une carte **éphémère**
  /// (`id == null`, ex. une duplication non persistée) ferait diverger
  /// l'espace d'indices affiché de l'espace persistable (un glisser
  /// déplacerait **silencieusement la mauvaise carte**) : avec [onReorder]
  /// fourni, elle est **refusée à la construction** (assert bruyant nommant
  /// l'index et le remède) ; en release (invariant AD-10), le
  /// réordonnancement est **retiré** ([onReorder]/[itemIds] `null`, capacité
  /// absente — invariant AD-4) plutôt que de risquer de déplacer la mauvaise
  /// carte. Même refus pour un `id` DUPLIQUÉ (le mapping id→index serait
  /// ambigu — même classe de défaut). [onReorder] exige `axis:
  /// Axis.vertical` (le rail horizontal n'est pas réordonnable — documenté
  /// sur [axis] — et un rail TRONQUÉ par [railPreviewCount] rendrait
  /// l'espace visible ≠ l'espace persistable).
  ///
  /// **Le rendu par défaut tient dans les DEUX axes.** En `axis:
  /// Axis.horizontal`, chaque carte fabriquée ici est **bornée en largeur**
  /// (sans quoi une carte à largeur non bornée dans un défileur horizontal ne
  /// peint RIEN en release, et lève en rafale « non-zero flex but incoming
  /// width constraints are unbounded » en debug). Priorité de la largeur :
  /// [railItemWidth] (paramètre explicite) > `ZcrudTheme.railItemWidth`
  /// (token) > 280 dp ([zRailItemFallbackWidth], arbitrage motivé sur
  /// place). L'enveloppe est le widget PUBLIC [ZRailItem] — réutilisable par
  /// un hôte qui assemble son propre défileur avec les mêmes cartes par
  /// défaut. Un `itemBuilder` d'HÔTE (constructeur principal) reste, lui,
  /// responsable de son propre bornage — neutralité stricte, aucun emballage
  /// n'y est ajouté.
  ///
  /// **Le COUPLAGE « rail des N premiers → grille complète »** est porté par
  /// [railPreviewCount]. Fourni (et `> 0`, avec `axis: Axis.horizontal` —
  /// assert sinon), il câble ENSEMBLE quatre décisions que l'hôte devrait
  /// sinon réussir séparément :
  /// - le rail ne rend que `min(N, total)` items ([itemCount] borné) ;
  /// - le badge d'en-tête porte le **TOTAL réel** (`cards.length`), jamais le
  ///   nombre rendu — [headerCount] explicite PRIME (cas légitime : données
  ///   paginées où `cards.length` est lui-même partiel) ;
  /// - l'action « afficher tout » passe par les créneaux EXISTANTS
  ///   ([secondaryAction] + [secondaryActionIcon] +
  ///   [secondaryActionSemanticLabel]) — aucun canal neuf : le libellé et
  ///   l'écran de destination restent à l'hôte ;
  /// - **total ≤ N** : le rail montre déjà tout, « afficher tout »
  ///   n'ajouterait rien ⇒ [secondaryAction] est SUPPRIMÉE (absente de
  ///   l'arbre, invariant AD-4 — jamais « présente et inutile ») ; le badge,
  ///   lui, reste rendu (total == rendu, information vraie).
  ///
  /// La **grille complète de destination** n'est pas à recopier : la MÊME voie
  /// typée en `axis: Axis.vertical` (sans [railPreviewCount]) EST la grille
  /// responsive complète — l'hôte ne construit que la navigation.
  ZStudyToolsSectionSpec.flashcards({
    required this.id,
    required this.title,
    required List<ZFlashcard> cards,
    required this.emptyState,
    Map<String, String>? typeLabels,
    List<ZFlashcardTag> Function(ZFlashcard card)? tagsOf,
    String? Function(ZFlashcard card)? colorKeyOf,
    // Le libellé sémantique de la carte est relayé PAR CARTE, patron
    // `colorKeyOf`/`tagsOf`. `null` (ou retour `null`) ⇒ repli de la carte
    // (l'énoncé) — rendu par défaut.
    String? Function(ZFlashcard card)? semanticLabelOf,
    String? emptyTagsLabel,
    void Function(ZFlashcard card)? onTagsTap,
    void Function(ZFlashcard card)? onCardTap,
    void Function(ZFlashcard card)? onCardLongPress,
    Widget? Function(BuildContext context, ZFlashcard card)? cardTrailingBuilder,
    ZColorPalette palette = const ZColorPalette.defaultStudy(),
    // L'axe TYPE et le chrome de référence, relayés à la carte (chaque
    // option de carte a son pendant ici).
    Map<String, ZGradientSpec>? typeColors,
    IconData? cardIcon,
    BorderSide? cardBorderSide,
    Radius? cardBorderRadius,
    Color? cardBackgroundColor,
    // Hauteur FIXE de référence — `null` EXPLICITE ⇒ hauteur intrinsèque,
    // même contrat que `ZDefaultFlashcardCard.height`.
    double? cardHeight = ZFlashcardCardReference.cardHeight,
    // Rendu riche injectable, borne de hauteur de référence, aperçu de
    // réponse en MODE et libellés de tampon (pendants nominaux des options
    // de la carte).
    ZFlashcardContentBuilder? questionBuilder,
    double questionMaxHeight = ZFlashcardCardReference.questionMaxHeight,
    // Fondu de continuation de l'énoncé et alignement vertical du contenu
    // de carte (pendants nominaux de la carte).
    double cardQuestionFadeExtent =
        ZFlashcardCardReference.questionFadeExtent,
    ZStudyCardContentAlignment? cardContentAlignment,
    // `null` (défaut) ⇒ le MODE suit la surface : la grille (axis vertical)
    // affiche l'aperçu de réponse, le rail horizontal NON. Explicite ⇒ la
    // valeur gouverne les deux axes.
    bool? showAnswerPreview,
    Map<String, String>? answerLabels,
    this.addAction,
    this.addActionIcon,
    this.addActionSemanticLabel,
    this.addOpensContentHub = false,
    Axis axis = Axis.vertical,
    // Largeur d'item du rail horizontal. `null` ⇒ token
    // `ZcrudTheme.railItemWidth`, puis repli 280 dp. Ignoré en vertical.
    double? railItemWidth,
    // Hauteur d'item du rail horizontal, patron EXACT de `railItemWidth`.
    // `null` ⇒ token `ZcrudTheme.railItemHeight`, puis AUCUNE contrainte
    // (asymétrie motivée sur `ZRailItem.height`). Ignoré en vertical.
    double? railItemHeight,
    // Rail des N premiers (couplage badge-total + « afficher tout »).
    // `null` ⇒ aucun couplage, rendu antérieur strictement inchangé.
    int? railPreviewCount,
    // Réordonnancement sur la voie typée : `itemIds` DÉRIVÉ des modèles
    // (jamais fourni par l'hôte), garde vérifiée SUR PIÈCES.
    void Function(int oldIndex, int newIndex)? onReorder,
    this.reorderHandleSemanticLabel,
    this.reorderHandleIcon,
    this.reorderMoveBeforeSemanticLabel,
    this.reorderMoveAfterSemanticLabel,
    // Mode de poignée, mêmes règles que le constructeur principal + refus
    // MESURÉ du conflit avec `onCardLongPress` (assert ; repli invariant
    // AD-10 en release : mode `visible`, jamais un glisser mort).
    ZStudyReorderHandleMode reorderHandleMode = ZStudyReorderHandleMode.visible,
    this.collapsible = false,
    this.initiallyExpanded = true,
    // La ligne d'en-tête comme zone de bascule (exige
    // `collapsible: true`, cf. constructeur principal).
    this.collapseOnHeaderTap = false,
    this.crossAxisMinItemWidth,
    this.crossAxisItemHeight,
    this.crossAxisAspectRatio,
    this.crossAxisMaxColumns,
    this.crossAxisVirtualized = false,
    this.crossAxisViewportHeight,
    this.railItemGap = kZRailItemReferenceGap,
    this.railPadding,
    this.collapseSemanticLabel,
    this.expandSemanticLabel,
    int? headerCount,
    VoidCallback? secondaryAction,
    this.secondaryActionIcon,
    this.secondaryActionLabel,
    this.secondaryActionSemanticLabel,
    this.expandController,
  })  : assert(
          railPreviewCount == null || railPreviewCount > 0,
          'railPreviewCount doit être strictement positif',
        ),
        assert(
          railPreviewCount == null || axis == Axis.horizontal,
          'railPreviewCount ne s\'applique qu\'au rail (axis: Axis.horizontal) '
          '— la même voie typée en Axis.vertical EST déjà la grille complète',
        ),
        // Le rail horizontal n'est PAS réordonnable (documenté sur `axis`) :
        // accepter `onReorder` en horizontal serait un no-op silencieux
        // (invariant AD-4). Transitivement, `railPreviewCount` (qui exige
        // l'horizontal) est INCOMPATIBLE avec `onReorder` : un rail tronqué
        // réordonnable ferait diverger l'espace visible de l'espace
        // persistable.
        assert(
          onReorder == null || axis == Axis.vertical,
          'ZStudyToolsSectionSpec.flashcards : onReorder exige axis: '
          'Axis.vertical — le rail horizontal n\'est pas réordonnable, et un '
          'rail tronqué (railPreviewCount) réordonnable ferait diverger '
          'l\'espace visible de l\'espace persistable.',
        ),
        // Conflit de geste MESURÉ (doc :
        // [ZStudyReorderHandleMode.hiddenLongPress]) : l'InkWell de la carte
        // gagne l'arène d'appui long, le drag ne démarre jamais depuis
        // l'item ; poignée masquée, il ne resterait AUCUN déclencheur tactile.
        assert(
          !(reorderHandleMode == ZStudyReorderHandleMode.hiddenLongPress &&
              onReorder != null &&
              onCardLongPress != null),
          'ZStudyToolsSectionSpec.flashcards : reorderHandleMode: '
          'hiddenLongPress est INCOMPATIBLE avec onCardLongPress — la carte '
          'consomme l\'appui long (mesuré : le drag ne démarre jamais depuis '
          'l\'item) et, poignée masquée, il ne reste aucun déclencheur '
          'tactile. Remède : garde le mode visible, ou retire onCardLongPress '
          'de cette section.',
        ),
        assert(
          reorderHandleMode == ZStudyReorderHandleMode.visible ||
              onReorder != null,
          'ZStudyToolsSectionSpec.flashcards : reorderHandleMode: '
          'hiddenLongPress exige onReorder (AD-4 : jamais un réglage '
          'silencieusement inerte).',
        ),
        assert(
          !collapseOnHeaderTap || collapsible,
          'ZStudyToolsSectionSpec.flashcards : collapseOnHeaderTap exige '
          'collapsible: true (AD-4 : jamais un réglage silencieusement '
          'inerte).',
        ),
        // Repli AD-10 (release) du conflit ci-dessus : mode `visible` —
        // capacité et affordance CONSERVÉES, jamais un glisser mort.
        reorderHandleMode =
            reorderHandleMode == ZStudyReorderHandleMode.hiddenLongPress &&
                    onReorder != null &&
                    onCardLongPress != null
                ? ZStudyReorderHandleMode.visible
                : reorderHandleMode,
        // Rail des N premiers : itemCount borné à min(N, total). Hors
        // couplage (ou axe vertical, repli invariant AD-10 en release), total.
        itemCount = railPreviewCount != null &&
                axis == Axis.horizontal &&
                railPreviewCount < cards.length
            ? railPreviewCount
            : cards.length,
        // Badge = TOTAL réel, jamais le nombre rendu. Un [headerCount]
        // explicite PRIME (données paginées : la liste locale est partielle).
        headerCount = headerCount ??
            (railPreviewCount != null && axis == Axis.horizontal
                ? cards.length
                : null),
        // total ≤ N ⇒ « afficher tout » n'ajoute rien : ABSENTE (AD-4).
        secondaryAction = railPreviewCount != null &&
                axis == Axis.horizontal &&
                cards.length <= railPreviewCount
            ? null
            : secondaryAction,
        axis = axis,
        // Identité DÉRIVÉE des modèles, vérifiée sur pièces (id nul/vide ou
        // dupliqué ⇒ assert à la construction ; en release, capacité RETIRÉE
        // — les deux champs retombent à `null` ENSEMBLE).
        itemIds = _zDeriveReorderIds<ZFlashcard>(
            cards, _zFlashcardReorderId, onReorder, axis, 'flashcards'),
        onReorder = _zGuardReorder<ZFlashcard>(
            cards, _zFlashcardReorderId, onReorder, axis),
        itemBuilder = ((BuildContext context, int index) {
          final ZFlashcard card = cards[index];
          final Widget item = ZDefaultFlashcardCard(
            // Clé STABLE par carte (AD-2) : l'identité d'un item suit sa carte,
            // jamais sa position — patron `ZFlashcardListView._buildTile`.
            key: ValueKey<String>(
              'zDefaultFlashcardCard-${card.id ?? 'ephemeral-$index'}',
            ),
            card: card,
            typeLabels: typeLabels,
            tags: tagsOf?.call(card) ?? const <ZFlashcardTag>[],
            emptyTagsLabel: emptyTagsLabel,
            onTagsTap: onTagsTap == null ? null : () => onTagsTap(card),
            palette: palette,
            colorKey: colorKeyOf?.call(card),
            // Relais de l'axe type + chrome, en parité avec la carte.
            typeColors: typeColors,
            icon: cardIcon,
            borderSide: cardBorderSide,
            borderRadius: cardBorderRadius,
            backgroundColor: cardBackgroundColor,
            height: cardHeight,
            questionBuilder: questionBuilder,
            questionMaxHeight: questionMaxHeight,
            questionFadeExtent: cardQuestionFadeExtent,
            contentAlignment: cardContentAlignment,
            // Mode surface : aperçu en grille (axe vertical), jamais dans le
            // rail — sauf choix EXPLICITE de l'hôte.
            showAnswerPreview: showAnswerPreview ?? axis == Axis.vertical,
            answerLabels: answerLabels,
            trailing: cardTrailingBuilder?.call(context, card),
            onTap: onCardTap == null ? null : () => onCardTap(card),
            onLongPress:
                onCardLongPress == null ? null : () => onCardLongPress(card),
            semanticLabel: semanticLabelOf?.call(card),
          );
          if (axis != Axis.horizontal) return item;
          // Item de RAIL borné en largeur (une carte non bornée dans un
          // défileur horizontal ne peint rien). Priorité : paramètre
          // explicite > token de thème > repli 280 dp. UNIQUEMENT sur la voie
          // typée : un itemBuilder d'hôte reste responsable de son bornage.
          return ZRailItem(
            width: railItemWidth,
            height: railItemHeight,
            child: item,
          );
        });

  /// Section de **cartes mentales** dont le socle fournit le rendu d'item —
  /// la voie TYPÉE qui **porte les données**.
  ///
  /// Mêmes règles que [ZStudyToolsSectionSpec.flashcards] : [itemBuilder]
  /// reste `required` dans le constructeur principal (non-cassant par
  /// construction) ; le réordonnancement est proposé sous garde **vérifiée sur
  /// pièces** ([itemIds] DÉRIVÉ de `maps[i].id`, un `id` vide = carte
  /// éphémère refusée à la construction, capacité retirée en release, cf. la
  /// doc de référence sur `.flashcards`) ; **parité complète** avec
  /// [ZDefaultMindmapCard] (chaque option de la carte a son pendant ici).
  ///
  /// [ZMindmap] vient de `zcrud_mindmap`, dépendance **déjà déclarée** —
  /// aucune arête nouvelle (invariant AD-1).
  ZStudyToolsSectionSpec.mindmaps({
    required this.id,
    required this.title,
    required List<ZMindmap> maps,
    required this.emptyState,
    String? untitledLabel,
    String Function(int nodeCount)? nodeCountLabel,
    String? Function(ZMindmap map)? colorKeyOf,
    String? Function(ZMindmap map)? semanticLabelOf,
    void Function(ZMindmap map)? onCardTap,
    void Function(ZMindmap map)? onCardLongPress,
    Widget? Function(BuildContext context, ZMindmap map)? cardTrailingBuilder,
    ZColorPalette palette = const ZColorPalette.defaultStudy(),
    // Nul vaut défaut de la hiérarchie de la carte, soit 1 en référence et
    // 2 en tintedTile, comme sur ZDefaultMindmapCard.
    int? titleMaxLines,
    // Relais de PARITÉ avec ZDefaultMindmapCard : hiérarchie, glyphe,
    // styles, géométrie, progression. Chaque valeur nulle laisse la carte
    // appliquer sa priorité jeton puis référence.
    ZStudyCardHierarchy? hierarchy,
    IconData? cardIcon,
    TextStyle? cardTitleStyle,
    TextStyle? cardSubtitleStyle,
    EdgeInsetsGeometry? cardContentPadding,
    EdgeInsetsGeometry? cardMargin,
    BorderSide? cardBorderSide,
    Radius? cardBorderRadius,
    // Progression PAR CARTE : le repli par item des hôtes n'est plus
    // nécessaire.
    Widget? Function(BuildContext context, ZMindmap map)? progressOf,
    double progressMaxWidth = 120,
    bool hidesTrailingWhileBusy = true,
    this.addAction,
    this.addActionIcon,
    this.addActionSemanticLabel,
    this.addOpensContentHub = false,
    Axis axis = Axis.vertical,
    // Largeur d'item du rail horizontal. `null` ⇒ token
    // `ZcrudTheme.railItemWidth`, puis repli 280 dp. Ignoré en vertical.
    double? railItemWidth,
    // Hauteur d'item du rail horizontal, patron EXACT de
    // `railItemWidth`. `null` ⇒ token `ZcrudTheme.railItemHeight`, puis
    // AUCUNE contrainte (asymétrie motivée sur `ZRailItem.height`). Ignoré en
    // vertical.
    double? railItemHeight,
    // Rail des N premiers (couplage badge-total + « afficher
    // tout »). `null` ⇒ aucun couplage, rendu antérieur strictement inchangé.
    int? railPreviewCount,
    // Mêmes règles que `.flashcards` (itemIds DÉRIVÉ, garde sur
    // pièces), voir la doc de référence sur cette voie-là.
    void Function(int oldIndex, int newIndex)? onReorder,
    this.reorderHandleSemanticLabel,
    this.reorderHandleIcon,
    this.reorderMoveBeforeSemanticLabel,
    this.reorderMoveAfterSemanticLabel,
    // Mode de poignée, mêmes règles que le constructeur principal + refus
    // MESURÉ du conflit avec `onCardLongPress` (assert ; repli invariant
    // AD-10 en release : mode `visible`, jamais un glisser mort).
    ZStudyReorderHandleMode reorderHandleMode = ZStudyReorderHandleMode.visible,
    this.collapsible = false,
    this.initiallyExpanded = true,
    // La ligne d'en-tête comme zone de bascule (exige
    // `collapsible: true`, cf. constructeur principal).
    this.collapseOnHeaderTap = false,
    this.crossAxisMinItemWidth,
    this.crossAxisItemHeight,
    this.crossAxisAspectRatio,
    this.crossAxisMaxColumns,
    this.crossAxisVirtualized = false,
    this.crossAxisViewportHeight,
    this.railItemGap = kZRailItemReferenceGap,
    this.railPadding,
    this.collapseSemanticLabel,
    this.expandSemanticLabel,
    int? headerCount,
    VoidCallback? secondaryAction,
    this.secondaryActionIcon,
    this.secondaryActionLabel,
    this.secondaryActionSemanticLabel,
    this.expandController,
    // Mêmes règles que `.flashcards` (rail borné, couplage
    // rail → grille), voir la doc de référence sur cette voie-là.
  })  : assert(
          railPreviewCount == null || railPreviewCount > 0,
          'railPreviewCount doit être strictement positif',
        ),
        assert(
          railPreviewCount == null || axis == Axis.horizontal,
          'railPreviewCount ne s\'applique qu\'au rail (axis: Axis.horizontal) '
          '— la même voie typée en Axis.vertical EST déjà la grille complète',
        ),
        // Cf. le même assert de `.flashcards`.
        assert(
          onReorder == null || axis == Axis.vertical,
          'ZStudyToolsSectionSpec.mindmaps : onReorder exige axis: '
          'Axis.vertical — le rail horizontal n\'est pas réordonnable, et un '
          'rail tronqué (railPreviewCount) réordonnable ferait diverger '
          'l\'espace visible de l\'espace persistable.',
        ),
        // Cf. les mêmes gardes de `.flashcards` (conflit
        // MESURÉ carte×appui-long, réglages jamais inertes, repli AD-10).
        assert(
          !(reorderHandleMode == ZStudyReorderHandleMode.hiddenLongPress &&
              onReorder != null &&
              onCardLongPress != null),
          'ZStudyToolsSectionSpec.mindmaps : reorderHandleMode: '
          'hiddenLongPress est INCOMPATIBLE avec onCardLongPress — la carte '
          'consomme l\'appui long (mesuré : le drag ne démarre jamais depuis '
          'l\'item) et, poignée masquée, il ne reste aucun déclencheur '
          'tactile. Remède : garde le mode visible, ou retire onCardLongPress '
          'de cette section.',
        ),
        assert(
          reorderHandleMode == ZStudyReorderHandleMode.visible ||
              onReorder != null,
          'ZStudyToolsSectionSpec.mindmaps : reorderHandleMode: '
          'hiddenLongPress exige onReorder (AD-4 : jamais un réglage '
          'silencieusement inerte).',
        ),
        assert(
          !collapseOnHeaderTap || collapsible,
          'ZStudyToolsSectionSpec.mindmaps : collapseOnHeaderTap exige '
          'collapsible: true (AD-4 : jamais un réglage silencieusement '
          'inerte).',
        ),
        reorderHandleMode =
            reorderHandleMode == ZStudyReorderHandleMode.hiddenLongPress &&
                    onReorder != null &&
                    onCardLongPress != null
                ? ZStudyReorderHandleMode.visible
                : reorderHandleMode,
        itemCount = railPreviewCount != null &&
                axis == Axis.horizontal &&
                railPreviewCount < maps.length
            ? railPreviewCount
            : maps.length,
        headerCount = headerCount ??
            (railPreviewCount != null && axis == Axis.horizontal
                ? maps.length
                : null),
        secondaryAction = railPreviewCount != null &&
                axis == Axis.horizontal &&
                maps.length <= railPreviewCount
            ? null
            : secondaryAction,
        axis = axis,
        // Identité DÉRIVÉE de `maps[i].id` (String non-nullable :
        // `''` = éphémère), même garde sur pièces que `.flashcards`.
        itemIds = _zDeriveReorderIds<ZMindmap>(
            maps, _zMindmapReorderId, onReorder, axis, 'mindmaps'),
        onReorder = _zGuardReorder<ZMindmap>(
            maps, _zMindmapReorderId, onReorder, axis),
        itemBuilder = ((BuildContext context, int index) {
          final ZMindmap map = maps[index];
          final Widget item = ZDefaultMindmapCard(
            // Clé STABLE par carte (AD-2) : l'identité suit la carte, jamais
            // sa position (`id` vide = éphémère, patron `.flashcards`).
            key: ValueKey<String>(
              'zDefaultMindmapCard-${map.id.isNotEmpty ? map.id : 'ephemeral-$index'}',
            ),
            map: map,
            untitledLabel: untitledLabel,
            nodeCountLabel: nodeCountLabel,
            palette: palette,
            colorKey: colorKeyOf?.call(map),
            hierarchy: hierarchy,
            icon: cardIcon,
            titleMaxLines: titleMaxLines,
            titleStyle: cardTitleStyle,
            subtitleStyle: cardSubtitleStyle,
            contentPadding: cardContentPadding,
            margin: cardMargin,
            borderSide: cardBorderSide,
            borderRadius: cardBorderRadius,
            trailing: cardTrailingBuilder?.call(context, map),
            progress: progressOf?.call(context, map),
            progressMaxWidth: progressMaxWidth,
            hidesTrailingWhileBusy: hidesTrailingWhileBusy,
            onTap: onCardTap == null ? null : () => onCardTap(map),
            onLongPress:
                onCardLongPress == null ? null : () => onCardLongPress(map),
            semanticLabel: semanticLabelOf?.call(map),
          );
          if (axis != Axis.horizontal) return item;
          // Cf. `.flashcards` (même règle, même priorité).
          return ZRailItem(
            width: railItemWidth,
            height: railItemHeight,
            child: item,
          );
        });

  /// Section d'**examens** dont le socle fournit le rendu d'item — la voie
  /// TYPÉE qui **porte les données**.
  ///
  /// Mêmes règles que [ZStudyToolsSectionSpec.flashcards] : [itemBuilder]
  /// reste `required` dans le constructeur principal ; réordonnancement sous
  /// garde **vérifiée sur pièces** ([itemIds] DÉRIVÉ de `exams[i].id`, `id`
  /// nul = examen éphémère refusé à la construction, capacité retirée en
  /// release, cf. la doc de référence sur `.flashcards`) ; **parité
  /// complète** avec [ZDefaultExamCard]. [dateLabelOf] rend une date **déjà
  /// formatée et localisée** par l'hôte — le socle ne formate jamais
  /// (invariant FR-26/invariant AD-13).
  ///
  /// [ZExam] vient de `zcrud_exam`, dépendance **déjà déclarée** — aucune
  /// arête nouvelle (invariant AD-1).
  ZStudyToolsSectionSpec.exams({
    required this.id,
    required this.title,
    required List<ZExam> exams,
    required this.emptyState,
    String? untitledLabel,
    String? Function(ZExam exam)? dateLabelOf,
    String? reminderLabel,
    String? Function(ZExam exam)? colorKeyOf,
    String? Function(ZExam exam)? semanticLabelOf,
    void Function(ZExam exam)? onCardTap,
    void Function(ZExam exam)? onCardLongPress,
    Widget? Function(BuildContext context, ZExam exam)? cardTrailingBuilder,
    ZColorPalette palette = const ZColorPalette.defaultStudy(),
    int titleMaxLines = 2,
    this.addAction,
    this.addActionIcon,
    this.addActionSemanticLabel,
    this.addOpensContentHub = false,
    Axis axis = Axis.vertical,
    // Largeur d'item du rail horizontal. `null` ⇒ token
    // `ZcrudTheme.railItemWidth`, puis repli 280 dp. Ignoré en vertical.
    double? railItemWidth,
    // Hauteur d'item du rail horizontal, patron EXACT de
    // `railItemWidth`. `null` ⇒ token `ZcrudTheme.railItemHeight`, puis
    // AUCUNE contrainte (asymétrie motivée sur `ZRailItem.height`). Ignoré en
    // vertical.
    double? railItemHeight,
    // Rail des N premiers (couplage badge-total + « afficher
    // tout »). `null` ⇒ aucun couplage, rendu antérieur strictement inchangé.
    int? railPreviewCount,
    // Mêmes règles que `.flashcards` (itemIds DÉRIVÉ, garde sur
    // pièces), voir la doc de référence sur cette voie-là.
    void Function(int oldIndex, int newIndex)? onReorder,
    this.reorderHandleSemanticLabel,
    this.reorderHandleIcon,
    this.reorderMoveBeforeSemanticLabel,
    this.reorderMoveAfterSemanticLabel,
    // Mode de poignée, mêmes règles que le constructeur principal + refus
    // MESURÉ du conflit avec `onCardLongPress` (assert ; repli invariant
    // AD-10 en release : mode `visible`, jamais un glisser mort).
    ZStudyReorderHandleMode reorderHandleMode = ZStudyReorderHandleMode.visible,
    this.collapsible = false,
    this.initiallyExpanded = true,
    // La ligne d'en-tête comme zone de bascule (exige
    // `collapsible: true`, cf. constructeur principal).
    this.collapseOnHeaderTap = false,
    this.crossAxisMinItemWidth,
    this.crossAxisItemHeight,
    this.crossAxisAspectRatio,
    this.crossAxisMaxColumns,
    this.crossAxisVirtualized = false,
    this.crossAxisViewportHeight,
    this.railItemGap = kZRailItemReferenceGap,
    this.railPadding,
    this.collapseSemanticLabel,
    this.expandSemanticLabel,
    int? headerCount,
    VoidCallback? secondaryAction,
    this.secondaryActionIcon,
    this.secondaryActionLabel,
    this.secondaryActionSemanticLabel,
    this.expandController,
    // Mêmes règles que `.flashcards` (rail borné, couplage
    // rail → grille), voir la doc de référence sur cette voie-là.
  })  : assert(
          railPreviewCount == null || railPreviewCount > 0,
          'railPreviewCount doit être strictement positif',
        ),
        assert(
          railPreviewCount == null || axis == Axis.horizontal,
          'railPreviewCount ne s\'applique qu\'au rail (axis: Axis.horizontal) '
          '— la même voie typée en Axis.vertical EST déjà la grille complète',
        ),
        // Cf. le même assert de `.flashcards`.
        assert(
          onReorder == null || axis == Axis.vertical,
          'ZStudyToolsSectionSpec.exams : onReorder exige axis: '
          'Axis.vertical — le rail horizontal n\'est pas réordonnable, et un '
          'rail tronqué (railPreviewCount) réordonnable ferait diverger '
          'l\'espace visible de l\'espace persistable.',
        ),
        // Cf. les mêmes gardes de `.flashcards` (conflit
        // MESURÉ carte×appui-long, réglages jamais inertes, repli AD-10).
        assert(
          !(reorderHandleMode == ZStudyReorderHandleMode.hiddenLongPress &&
              onReorder != null &&
              onCardLongPress != null),
          'ZStudyToolsSectionSpec.exams : reorderHandleMode: '
          'hiddenLongPress est INCOMPATIBLE avec onCardLongPress — la carte '
          'consomme l\'appui long (mesuré : le drag ne démarre jamais depuis '
          'l\'item) et, poignée masquée, il ne reste aucun déclencheur '
          'tactile. Remède : garde le mode visible, ou retire onCardLongPress '
          'de cette section.',
        ),
        assert(
          reorderHandleMode == ZStudyReorderHandleMode.visible ||
              onReorder != null,
          'ZStudyToolsSectionSpec.exams : reorderHandleMode: '
          'hiddenLongPress exige onReorder (AD-4 : jamais un réglage '
          'silencieusement inerte).',
        ),
        assert(
          !collapseOnHeaderTap || collapsible,
          'ZStudyToolsSectionSpec.exams : collapseOnHeaderTap exige '
          'collapsible: true (AD-4 : jamais un réglage silencieusement '
          'inerte).',
        ),
        reorderHandleMode =
            reorderHandleMode == ZStudyReorderHandleMode.hiddenLongPress &&
                    onReorder != null &&
                    onCardLongPress != null
                ? ZStudyReorderHandleMode.visible
                : reorderHandleMode,
        itemCount = railPreviewCount != null &&
                axis == Axis.horizontal &&
                railPreviewCount < exams.length
            ? railPreviewCount
            : exams.length,
        headerCount = headerCount ??
            (railPreviewCount != null && axis == Axis.horizontal
                ? exams.length
                : null),
        secondaryAction = railPreviewCount != null &&
                axis == Axis.horizontal &&
                exams.length <= railPreviewCount
            ? null
            : secondaryAction,
        axis = axis,
        // Identité DÉRIVÉE de `exams[i].id`, même garde sur
        // pièces que `.flashcards`.
        itemIds = _zDeriveReorderIds<ZExam>(
            exams, _zExamReorderId, onReorder, axis, 'exams'),
        onReorder = _zGuardReorder<ZExam>(
            exams, _zExamReorderId, onReorder, axis),
        itemBuilder = ((BuildContext context, int index) {
          final ZExam exam = exams[index];
          final Widget item = ZDefaultExamCard(
            // Clé STABLE par carte (AD-2), patron `.flashcards`.
            key: ValueKey<String>(
              'zDefaultExamCard-${exam.id ?? 'ephemeral-$index'}',
            ),
            exam: exam,
            untitledLabel: untitledLabel,
            dateLabel: dateLabelOf?.call(exam),
            reminderLabel: reminderLabel,
            palette: palette,
            colorKey: colorKeyOf?.call(exam),
            titleMaxLines: titleMaxLines,
            trailing: cardTrailingBuilder?.call(context, exam),
            onTap: onCardTap == null ? null : () => onCardTap(exam),
            onLongPress:
                onCardLongPress == null ? null : () => onCardLongPress(exam),
            semanticLabel: semanticLabelOf?.call(exam),
          );
          if (axis != Axis.horizontal) return item;
          // Cf. `.flashcards` (même règle, même priorité).
          return ZRailItem(
            width: railItemWidth,
            height: railItemHeight,
            child: item,
          );
        });

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

  /// **Lot 2** — le `+` de cette section ouvre le **hub d'ajout partagé** en
  /// portée (`ZContentHubScope`), au lieu d'une commande propre.
  ///
  /// `false` (défaut) ⇒ comportement STRICTEMENT antérieur : le `+` est rendu
  /// ssi [addAction] est non-null, et il n'invoque qu'elle.
  ///
  /// `true` ⇒ la commande du `+` est résolue ainsi, **dans cet ordre** :
  ///
  /// | 1 | [addAction] non-null | **elle gagne** — le paramètre de l'hôte prime |
  /// | 2 | un `ZContentHubScope` est en portée | le hub s'ouvre |
  /// | 3 | aucun scope | le `+` est **ABSENT de l'arbre** (AD-4) |
  ///
  /// **Le cas 3 est le point qui compte** : un `+` déclaré « ouvre le hub »
  /// alors qu'aucun hub n'est branché ne doit pas être un bouton grisé, ni un
  /// bouton qui ne fait rien — deux façons de mentir à l'utilisateur. La
  /// capacité est absente, la commande l'est aussi (garde dédiée).
  ///
  /// **Aucune apparence n'est fournie par le socle** : [addActionIcon] et
  /// [addActionSemanticLabel] restent les seules sources de glyphe et
  /// d'annonce, exactement comme sur le chemin `addAction`. Ce drapeau
  /// n'apporte qu'une **commande**.
  final bool addOpensContentHub;

  /// Orientation de la disposition des items de la section.
  ///
  /// [Axis.vertical] (défaut) = grille empilée (documents/notes/mindmaps).
  /// [Axis.horizontal] = **rail** défilant (flashcards). La réordonnabilité
  /// ne s'applique QU'À [Axis.vertical] (grilles docs/notes/mindmaps) ; le
  /// rail horizontal flashcards N'EST PAS réordonnable.
  final Axis axis;

  // ── Slots ADDITIFS de réordonnabilité (invariant AD-4) ──────────────────
  // Tous const-compatibles et défaut `null` ⇒ non-cassant pour les sections
  // qui ne réordonnent pas (une section reste non réordonnable tant que
  // [onReorder] n'est pas fourni).

  /// Ordre COURANT des ids d'items rendus (clés STABLES de réordonnancement).
  ///
  /// `null` par défaut. Quand la section est réordonnable ([onReorder] non-null),
  /// l'appelant FOURNIT ici les ids déjà ordonnés — typiquement issus d'un
  /// tri stable appliqué en amont (`applyOrder<T>`). `itemIds[i]` est l'id de
  /// l'item rendu par `itemBuilder(context, i)` : `ReorderableListView` keye
  /// chaque enfant par `ValueKey(itemIds[i])` (clé requise) et mappe le
  /// déplacement d'index vers le nouvel ordre d'ids. Longueur DOIT ==
  /// [itemCount] (assert).
  final List<String>? itemIds;

  /// Callback de réordonnancement. **`null` = section NON réordonnable**
  /// (invariant AD-4 — capacité ABSENTE, jamais un no-op silencieux).
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

  /// Glyphe INJECTÉ de la poignée de réordonnancement.
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

  /// Libellé LOCALISÉ de l'action sémantique « déplacer avant » du mode
  /// GRILLE réordonnable. `null` ⇒ repli neutre documenté côté layout.
  ///
  /// En grille, le geste est un **appui long sur la cellule** : il n'existe pas
  /// de poignée, et un appui long est **inatteignable au lecteur d'écran**.
  /// L'alternative accessible obligatoire (invariant AD-13) passe donc par
  /// deux actions sémantiques, dont ce libellé.
  final String? reorderMoveBeforeSemanticLabel;

  /// Libellé LOCALISÉ de l'action sémantique « déplacer après » du mode
  /// GRILLE réordonnable. Voir [reorderMoveBeforeSemanticLabel].
  final String? reorderMoveAfterSemanticLabel;

  /// Mode de présentation de la poignée de réordonnancement.
  ///
  /// [ZStudyReorderHandleMode.visible] (défaut) ⇒ rendu **strictement
  /// inchangé** (poignée + `Semantics` ≥ 48 dp sur chaque item).
  /// [ZStudyReorderHandleMode.hiddenLongPress] ⇒ poignée absente de l'arbre
  /// (invariant AD-4), réordonnancement par **appui long sur l'item entier**
  /// — sémantique CONSERVÉE dans les deux modes et sur les deux chemins
  /// (liste : actions du SDK ; grille : actions
  /// [reorderMoveBeforeSemanticLabel]/[reorderMoveAfterSemanticLabel] —
  /// détail, arbitrage spec-vs-thème et conflit MESURÉ avec l'appui long des
  /// cartes : doc de [ZStudyReorderHandleMode]).
  ///
  /// N'a de sens que si [onReorder] est fourni (assert — invariant AD-4 :
  /// jamais un réglage silencieusement inerte).
  final ZStudyReorderHandleMode reorderHandleMode;

  // ── Capacités additives de la page « study tools » ──────────────────────

  /// Section **repliable**. `false` par défaut — le rendu antérieur
  /// (toujours déplié) est strictement préservé.
  ///
  /// L'état plié/déplié vit **localement** sous la frontière keyée de la
  /// section (invariant AD-2) : replier une section ne reconstruit NI les
  /// autres sections NI la page.
  final bool collapsible;

  /// État initial quand [collapsible] est `true`. Ignoré sinon.
  ///
  /// Permet le patron « déplié seulement si la section a des éléments » :
  /// `initiallyExpanded: items.isNotEmpty`.
  final bool initiallyExpanded;

  /// **Toute la ligne d'en-tête** devient zone de bascule du repli. `false`
  /// (défaut) ⇒ rendu et arbre **strictement inchangés** : le chevron reste
  /// la seule cible (invariant AD-4 : la zone est ABSENTE de l'arbre).
  ///
  /// ## Pourquoi un réglage de SPEC et non un token de thème
  ///
  /// Le geste dépend du **contenu** de la section : une ligne d'en-tête qui
  /// porte des actions cliquables ([secondaryAction], [addAction]) n'a pas le
  /// même arbitrage qu'une ligne nue — et c'est la spec, pas le thème, qui
  /// sait ce que SA ligne contient. La capacité qu'il étend ([collapsible])
  /// est elle-même un champ de spec : porter le geste au thème aurait créé un
  /// réglage global inerte sur toute section non repliable (no-op silencieux,
  /// invariant AD-4) et non débrayable par section. Le token de thème
  /// `studySectionCollapsePlacement` place du CHROME uniforme ; il ne décide
  /// pas ce qu'un GESTE fait sur un contenu que l'hôte injecte.
  /// Un hôte qui veut la bascule partout la règle au point unique où il
  /// fabrique ses specs.
  ///
  /// ## Priorité tactile (MESURÉE, gardée)
  ///
  /// Les contrôles INTERNES de la ligne gagnent l'arène contre la zone de
  /// bascule (résolution d'arène : le reconnaisseur le plus profond gagne) :
  /// un tap sur [secondaryAction]/[addAction] déclenche l'action et ne replie
  /// JAMAIS ; un tap sur le chevron bascule UNE fois (jamais deux) ; un tap
  /// sur le titre, le badge ou l'espace libre bascule. Vaut aussi sous
  /// `studySectionCollapsePlacement: inHeaderRow` et en RTL.
  ///
  /// ## Sémantique — une seule annonce
  ///
  /// La ligne est une **extension de cible pour le pointeur**, pas un second
  /// nœud d'action : sa zone de tap est EXCLUE de la sémantique
  /// (`excludeFromSemantics`), et l'annonce de bascule reste portée par le
  /// seul chevron (libellés injectés, ≥ 48 dp) — l'arbre sémantique est
  /// STRICTEMENT celui d'avant, jamais deux annonces de bascule. La demande
  /// est le GESTE, pas la structure : la ligne reste STATIQUE (hors tranche
  /// réactive — elle n'écoute pas l'état, le closure de tap écrit à la
  /// source), SM-1 préservé et gardé par comptage de builds.
  ///
  /// Exige [collapsible] (assert — invariant AD-4 : jamais un réglage inerte).
  final bool collapseOnHeaderTap;

  /// Largeur minimale d'un item pour un rendu **multi-colonnes**.
  ///
  /// `null` (défaut) ⇒ une seule colonne, rendu antérieur inchangé. Sinon le
  /// nombre de colonnes est dérivé de la largeur disponible — la grille
  /// s'étale ainsi sur desktop/tablette au lieu d'empiler.
  final double? crossAxisMinItemWidth;

  /// Hauteur fixe d'une cellule de grille. `null` ⇒ forme par défaut de la
  /// grille.
  ///
  /// Une carte BASSE (≈ 76 dp) sans ce paramètre prendrait la hauteur par
  /// défaut de la grille et perdrait sa densité, précisément sur grand
  /// écran, là où la grille sert.
  /// Exclusif avec [crossAxisAspectRatio] — si les deux sont fournis, la hauteur
  /// fixe l'emporte (elle est plus déterministe).
  final double? crossAxisItemHeight;

  /// Ratio largeur/hauteur d'une cellule, alternative à [crossAxisItemHeight]
  /// quand la hauteur doit suivre la largeur de colonne.
  final double? crossAxisAspectRatio;

  /// **Plafond** du nombre de colonnes de la grille.
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

  /// **COMBINABLE avec [onReorder]** : déclarer les deux produit une **grille
  /// multi-colonnes RÉORDONNABLE** (`ZReorderableAdaptiveGrid` de
  /// `zcrud_responsive`), et non une liste mono-colonne signalée par un
  /// `assert`. L'activation est **implicite** — aucun drapeau supplémentaire.
  /// Le geste est un **appui long sur la cellule**, doublé de deux actions
  /// sémantiques ([reorderMoveBeforeSemanticLabel] /
  /// [reorderMoveAfterSemanticLabel]) pour le lecteur d'écran (invariant
  /// AD-13).
  ///
  /// **L'AFFORDANCE est présente sur les DEUX chemins** : la poignée
  /// n'existant QUE sur le chemin liste ferait DISPARAÎTRE la poignée d'une
  /// section réordonnable passée en grille (renseigner cette largeur)
  /// **sans aucun signal** — ni erreur, ni `assert`, et le glisser
  /// continuerait de passer en test. Chaque cellule de grille porte donc la
  /// MÊME poignée que le mode liste : glyphe [reorderHandleIcon] (repli
  /// `Icons.drag_handle`), nœud `Semantics` au libellé INJECTÉ
  /// ([reorderHandleSemanticLabel], repli [title]) et cible ≥ 48 dp.
  ///
  /// **Écart ASSUMÉ et documenté entre les deux chemins** : en liste, la
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
  /// Reste **exclusif avec [crossAxisVirtualized]** : une cellule non
  /// construite ne peut pas être une cible de dépôt. Une section à la fois
  /// réordonnable et virtualisée est rendue **eager** (réordonnable), la
  /// virtualisation cédant — documenté, jamais dégradé en silence.
  ///
  /// Grille **virtualisée** : ne construit que les cellules du viewport et
  /// scrolle d'elle-même. `false` par défaut (grille *eager*,
  /// imbriquée dans le défilement de la page — rendu antérieur inchangé).
  ///
  /// À activer dès qu'une section peut porter plusieurs dizaines d'items : en
  /// mode *eager*, TOUTES les cellules sont construites ET layoutées, même hors
  /// écran. Une section alimentée par tout le contenu d'un dossier (héritage
  /// parent compris) est exactement ce cas.
  final bool crossAxisVirtualized;

  /// Hauteur du viewport d'une grille [crossAxisVirtualized] — **obligatoire**
  /// dans ce mode.
  ///
  /// Une grille virtualisée EST la surface scrollable : imbriquée sans hauteur
  /// bornée dans le défilement de la page, elle lève « Vertical viewport was
  /// given unbounded height ». La déclarer, c'est accepter en connaissance de
  /// cause un **défilement imbriqué** — le prix de la virtualisation à ce
  /// niveau. Sans elle, la grille retombe défensivement en mode *eager*.
  final double? crossAxisViewportHeight;

  /// ESPACEMENT entre deux items du **rail horizontal**.
  ///
  /// Sans effet en [Axis.vertical].
  ///
  /// Priorité : ce paramètre > jeton `ZcrudTheme.railItemGap` > `gapS` (le
  /// repli HISTORIQUE).
  ///
  /// **Le défaut DIFFÈRE selon le constructeur** :
  /// - constructeur PRINCIPAL (l'hôte fournit son `itemBuilder`) ⇒ `null`,
  ///   donc `gapS` : **rendu strictement inchangé** pour un hôte qui compose
  ///   son propre rail ;
  /// - voies TYPÉES (`.flashcards`/`.mindmaps`/`.exams`, qui fabriquent les
  ///   cartes PAR DÉFAUT) ⇒ [kZRailItemReferenceGap] (12), la valeur de
  ///   référence — « le défaut EST la référence » ne vaut que des rendus
  ///   par défaut.
  ///
  /// Ce réglage existe parce que l'espacement du rail réutilisait `gapS`,
  /// jeton que l'hôte règle déjà pour ses écarts inter-slots, ce qui liait
  /// deux besoins distincts à une même valeur.
  final double? railItemGap;

  /// PADDING du défileur du **rail horizontal** — son retrait latéral
  /// propre. Sans effet en [Axis.vertical].
  ///
  /// `null` (défaut, TOUS constructeurs) ⇒ le rail est inséré dans le padding
  /// de section (`horizontal: gapM`) — **rendu strictement inchangé**.
  /// Non-null ⇒ le padding horizontal de section n'est PLUS appliqué au rail
  /// (il reste appliqué à l'EN-TÊTE et à l'état vide) : le retrait du rail
  /// devient ABSOLU et atteignable, y compris `EdgeInsets.zero` pour un rail
  /// qui affleure le bord.
  ///
  /// Priorité : ce paramètre > jeton `ZcrudTheme.railPadding` > padding de
  /// section (comportement historique).
  ///
  /// **Pourquoi le défaut n'est PAS la valeur de référence (8 dp), contre
  /// la règle habituelle** : le titre de section et le rail partagent le
  /// même padding de section (`horizontal: gapM`). Poser 8 ici, alors que
  /// l'en-tête reste à `gapM`, DÉSALIGNERAIT le titre et les cartes — un
  /// défaut pire que l'écart de référence. La valeur de référence reste
  /// atteignable en une ligne, mais c'est une décision de PAGE, que seul
  /// l'hôte peut prendre en cohérence avec son en-tête.
  ///
  /// **Le retrait effectif au bord de la première CARTE vaut ce padding
  /// PLUS la marge externe de la carte** (`CardThemeData.margin` de l'hôte,
  /// ou `ZcrudTheme.studyCardMargin`) : les deux s'AJOUTENT — à prendre en
  /// compte pour tout calibrage visuel.
  final EdgeInsetsGeometry? railPadding;

  /// Libellé accessible du contrôle de repli quand la section est DÉPLIÉE.
  /// Repli : `'Replier'`.
  ///
  /// C'était le SEUL libellé non injecté de ce layout — un hôte non francophone
  /// obtenait un `semanticLabel` en français sur un contrôle d'accessibilité,
  /// contredisant AD-13 et le principe d'injection appliqué partout ailleurs.
  final String? collapseSemanticLabel;

  /// Libellé accessible du contrôle de repli quand la section est REPLIÉE.
  /// Repli : `'Déplier'`.
  final String? expandSemanticLabel;

  /// Compteur affiché dans l'en-tête, **découplé** du nombre d'items rendus.
  /// `null` (défaut) ⇒ le badge affiche [itemCount].
  ///
  /// Permet le patron « badge = total (42), rail = `take(10)` » :
  /// `itemCount: 10, headerCount: 42`.
  ///
  /// Sur une voie typée avec `railPreviewCount`, ce champ est **résolu au
  /// TOTAL réel** de la liste quand l'appelant ne le fournit pas : le badge
  /// ne peut plus afficher silencieusement le nombre rendu.
  final int? headerCount;

  /// Action d'en-tête **secondaire**, en plus de [addAction] — typiquement
  /// « Afficher tout » (navigation). `null` ⇒ action ABSENTE (invariant AD-4).
  ///
  /// Sans elle, un hôte devait détourner [addAction] pour la navigation : jamais
  /// les deux à la fois, et une sémantique approximative.
  ///
  /// Sur une voie typée avec `railPreviewCount`, c'est le créneau EXISTANT
  /// de l'action « afficher tout » (aucun canal neuf) ; elle est SUPPRIMÉE
  /// (absente de l'arbre, invariant AD-4) quand le total ≤ N — le rail
  /// montre déjà tout.
  final VoidCallback? secondaryAction;

  /// Icône de [secondaryAction] (repli neutre si absente).
  final IconData? secondaryActionIcon;

  /// Libellé **VISIBLE** de [secondaryAction] — ex. « Afficher tout », rendu
  /// **à côté** de l'icône.
  ///
  /// `null` (défaut) ⇒ icône seule, rendu **strictement inchangé**. Non-null ⇒
  /// le libellé est affiché dans le bouton, à côté de l'icône ; cible ≥ 48 dp
  /// conservée. C'est de l'**information**, pas du style — une icône seule
  /// n'est pas auto-descriptive (invariant AD-13 : la forme ne peut pas être
  /// le seul canal) — d'où un champ de SPEC (libellé localisé par l'hôte,
  /// invariant FR-26) et non un token de thème.
  ///
  /// A11y : le libellé visible devient l'annonce du bouton — **une seule
  /// source de sémantique** : [secondaryActionSemanticLabel] n'est utilisé
  /// en plus que s'il est fourni, et il PRIME alors comme annonce (jamais
  /// deux annonces divergentes).
  final String? secondaryActionLabel;

  /// Libellé accessible de [secondaryAction] (a11y invariant AD-13 — repli
  /// sur [title], ou sur [secondaryActionLabel] visible quand il existe).
  final String? secondaryActionSemanticLabel;

  /// Pilote **optionnel** du déplié/replié de CETTE section (patron
  /// `ZDisplayState` de `zcrud_core`).
  ///
  /// - `null` (défaut) ⇒ l'état de repli vit **localement** dans la section,
  ///   initialisé par [initiallyExpanded] : rendu et comportement **strictement
  ///   inchangés** pour tout hôte qui ne renseigne pas ce slot ;
  /// - non-null ⇒ **le contrôleur EST la source de vérité**. Le repli devient
  ///   commandable depuis un **second chemin** (un en-tête cliquable, un
  ///   sommaire externe, un « tout replier ») **et** depuis le chevron de la
  ///   section — sans jamais deux états à synchroniser : la section ne garde
  ///   aucun miroir. [initiallyExpanded] est alors **ignoré** (la valeur
  ///   initiale appartient au contrôleur, seul propriétaire de l'état).
  ///
  /// **POSSESSION — qui crée le contrôleur quand il y a N sections.**
  /// L'hôte, **jamais** ce package. Une section est un **élément de liste** :
  /// c'est le `State` qui construit la liste de specs qui possède les N
  /// contrôleurs (un champ, une `Map<String, ZToggleController>` indexée par
  /// [id], ou `initState`), avec `ZDisplayStateOwnerMixin` qui les libère et
  /// **refuse** une création dans `build`. Faire créer les contrôleurs par le
  /// layout aurait exigé de les créer là où les specs sont lues — c'est-à-dire
  /// **dans `build`** : chaque rebuild aurait remplacé les instances, et la
  /// commande de l'hôte serait devenue silencieusement inerte. C'est
  /// exactement le défaut mesuré chez l'hôte, et le patron existe pour le
  /// rendre impossible, pas pour l'industrialiser.
  ///
  /// Un contrôleur déclaré et **jamais passé** dans une spec rendue reste
  /// détectable (`wasEverConsumed` — assert au `dispose` du mixin) : un
  /// « tout replier » câblé sur un contrôleur orphelin ne peut pas passer pour
  /// branché.
  final ZToggleController? expandController;
}

// ---------------------------------------------------------------------------
// Dérivation d'identité des voies typées (garde SUR PIÈCES)
// ---------------------------------------------------------------------------

/// Id de réordonnancement d'une [ZFlashcard] (`null` = éphémère).
String? _zFlashcardReorderId(ZFlashcard card) => card.id;

/// Id de réordonnancement d'une [ZMindmap] (`''` = éphémère, id non-nullable).
String? _zMindmapReorderId(ZMindmap map) => map.id;

/// Id de réordonnancement d'un [ZExam] (`null` = éphémère).
String? _zExamReorderId(ZExam exam) => exam.id;

/// Dérive les `itemIds` d'une voie typée depuis ses modèles.
///
/// La garde du constructeur principal (« [ZStudyToolsSectionSpec.onReorder] ⇒
/// identité stable par item ») y est **déclarée par l'hôte** ; ici elle est
/// **vérifiée sur pièces** — la voie typée détient les données :
/// - `onReorder == null` (ou axe non vertical) ⇒ `null` — capacité absente,
///   rendu antérieur **strictement inchangé** ;
/// - un id **nul/vide** (item éphémère, ex. duplication non persistée) ⇒
///   **assert à la construction** nommant l'index et le remède ; en release
///   (AD-10), retour `null` — le réordonnancement est **retiré** (AD-4, jamais
///   un glisser qui déplacerait la mauvaise carte) ;
/// - un id **dupliqué** ⇒ même refus : le mapping id→index du rendu
///   (`itemIds.indexOf`) serait ambigu — même classe de défaut que l'éphémère.
///
/// [_zGuardReorder] applique la MÊME décision au callback : les deux champs
/// retombent à `null` ENSEMBLE (l'invariant du constructeur principal reste
/// vrai par construction).
List<String>? _zDeriveReorderIds<T>(
  List<T> items,
  String? Function(T item) idOf,
  void Function(int oldIndex, int newIndex)? onReorder,
  Axis axis,
  String ctor,
) {
  if (onReorder == null || axis != Axis.vertical) return null;
  final List<String> ids = <String>[];
  final Set<String> seen = <String>{};
  for (int i = 0; i < items.length; i++) {
    final String? id = idOf(items[i]);
    assert(
      id != null && id.isNotEmpty,
      'ZStudyToolsSectionSpec.$ctor : onReorder est fourni mais l\'item '
      'd\'index $i a un id nul/vide (item ÉPHÉMÈRE, ex. duplication non '
      'persistée). Un glisser déplacerait silencieusement la mauvaise carte. '
      'Remède : persiste l\'item avant de le rendre réordonnable, ou retire '
      'onReorder (ou filtre les items éphémères de la liste).',
    );
    if (id == null || id.isEmpty) return null;
    assert(
      !seen.contains(id),
      'ZStudyToolsSectionSpec.$ctor : onReorder est fourni mais l\'id "$id" '
      '(index $i) est DUPLIQUÉ — le mapping id→index du réordonnancement '
      'serait ambigu. Remède : garantis l\'unicité des ids de la liste.',
    );
    if (!seen.add(id)) return null;
    ids.add(id);
  }
  return List<String>.unmodifiable(ids);
}

/// Pendant de [_zDeriveReorderIds] pour le callback : rend [onReorder] tel
/// quel si (et seulement si) la dérivation d'ids aboutirait — sinon `null`
/// (capacité retirée, AD-10/AD-4). Les deux décisions sont prises sur les
/// MÊMES pièces : elles ne peuvent pas diverger.
void Function(int oldIndex, int newIndex)? _zGuardReorder<T>(
  List<T> items,
  String? Function(T item) idOf,
  void Function(int oldIndex, int newIndex)? onReorder,
  Axis axis,
) {
  if (onReorder == null || axis != Axis.vertical) return null;
  final Set<String> seen = <String>{};
  for (final T item in items) {
    final String? id = idOf(item);
    if (id == null || id.isEmpty || !seen.add(id)) return null;
  }
  return onReorder;
}
