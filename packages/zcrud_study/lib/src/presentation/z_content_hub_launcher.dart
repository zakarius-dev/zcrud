/// **Lot 2 « étude »** — la voie de PREMIÈRE CLASSE pour dire « le `+` ouvre le
/// hub d'ajout », sans que le socle décide des entrées.
///
/// ## Le manque, MESURÉ avant écriture
///
/// `ZContentHubSheet` est complet depuis v0.51.0 (CR-IFFD-65) mais **branché
/// nulle part**. Grep négatif exécuté sur disque :
///
/// ```
/// $ grep -rn "ContentHub" --include="*.dart" packages/ \
///     | grep -E "z_study_folder_detail|z_study_tools_page|z_sectioned_study_layout"
/// (sortie VIDE)
/// ```
///
/// Il était **disponible**, pas **composé** : chaque hôte devait réécrire son
/// propre `showModalBottomSheet` et le recâbler à DEUX endroits (le `+`
/// d'app-bar et le `+` d'une section), sans aucune garantie que les deux
/// ouvrent la **même** feuille.
///
/// ## Les trois pièces, et ce que chacune refuse de faire
///
/// | Pièce | Ce qu'elle porte | Ce qu'elle refuse |
/// |---|---|---|
/// | [ZContentHubLauncher] | la **configuration** de la feuille + **comment** la présenter | décider d'une entrée, d'un libellé, d'un glyphe |
/// | [ZContentHubScope] | la **portée** : un seul hub configuré, plusieurs `+` | contenir un état, imposer une présence |
/// | slots hôtes | le **câblage** (`ZStudyFolderDetail.contentHubLauncher`, `ZStudyToolsSectionSpec.addOpensContentHub`) | changer quoi que ce soit quand ils sont absents |
///
/// 🔴 **ZÉRO libellé ajouté par le socle.** [ZContentHubLauncher] ne porte
/// **aucun** texte : pas de titre de feuille, pas de libellé de badge, pas de
/// défaut de constructeur littéral. Tout texte rendu vient des
/// `ZContentHubEntry`/`ZContentHubSection` que l'**hôte** construit. Le seul
/// vocabulaire que le socle ajoute est un jeu de **clés de couleur stables**
/// (`ZContentHubReference.colorKeyFlashcards`…), qui ne sont **pas** des
/// libellés : elles ne sont jamais rendues, jamais traduites, et leur raison
/// d'être est précisément de **ne pas** dépendre de la langue ni de la position
/// d'affichage (cf. `ZContentHubEntry.colorKey`).
///
/// ## 🔴 SM-1 — pourquoi la portée ne se lit PAS par dépendance
///
/// [ZContentHubScope.maybeOf] utilise `getInheritedWidgetOfExactType`, **jamais**
/// `dependOnInheritedWidgetOfExactType`. Ce n'est pas une négligence :
///
/// * ce dont un `+` a besoin, c'est d'un **callback**, résolu **au tap** — pas
///   d'une valeur au build ;
/// * un `dependOn…` inscrirait CHAQUE en-tête de section comme dépendant du
///   scope. Un hôte qui compose son launcher **dans son `build`** (le cas
///   ordinaire — les entrées portent des callbacks fraîchement capturés) rendrait
///   alors un launcher `!=` à chaque frame, donc **toutes** les sections
///   seraient reconstruites à chaque frame de l'hôte. C'est exactement l'anti-
///   patron qu'AD-2/SM-1 interdit ;
/// * l'**apparition/disparition** du scope reste propagée : insérer ou retirer un
///   `InheritedWidget` reconstruit son sous-arbre par construction. Seul le
///   **contenu** du launcher cesse d'être une source de rebuild — et il n'a pas
///   à l'être, puisqu'il est relu au tap.
///
/// ## AD-4 / AD-10
///
/// * Slot absent (`contentHubLauncher: null`, `addOpensContentHub: false`) ⇒
///   arbre **strictement identique** à avant ce lot (garde dédiée).
/// * `addOpensContentHub: true` **sans scope** ⇒ le `+` est **ABSENT** de
///   l'arbre, jamais un bouton mort ni un no-op silencieux.
/// * Une section vide, une palette vide, un `presenter` qui rend un `Future`
///   déjà complété : aucun chemin d'exception (le hub lui-même est total).
library;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart' show ZContentHubDensity;

import 'z_content_hub_sheet.dart';

/// **Comment** la feuille est présentée — seam de PRÉSENTATION (AD-4).
///
/// Reçoit le `context` d'appel et le **constructeur** de la feuille (jamais la
/// feuille déjà bâtie : elle doit être construite sous la route de présentation,
/// sinon elle hériterait du `Theme`/`Directionality` du site d'appel et non de
/// celui de la modale).
///
/// `null` sur [ZContentHubLauncher.presenter] ⇒ repli
/// `showModalBottomSheet` — le mode de présentation d'origine du hub
/// (`ZContentHubSheet.show`). Un hôte qui présente en dialogue, en page pleine
/// ou en panneau latéral fournit le sien : le socle n'impose pas la forme
/// d'enveloppe (elle est « une enveloppe, pas une capacité du hub » — cf.
/// `ZContentHubReference`).
typedef ZContentHubPresenter =
    Future<void> Function(BuildContext context, WidgetBuilder builder);

/// Repli de présentation — la feuille modale d'origine du hub.
Future<void> _presentAsModalSheet(
  BuildContext context,
  WidgetBuilder builder,
) => showModalBottomSheet<void>(context: context, builder: builder);

/// Configuration **VALEUR** d'un hub d'ajout de contenu, prête à être ouverte
/// depuis plusieurs `+`.
///
/// C'est un **value-type immuable** (`==`/`hashCode` de valeur) : il se hisse en
/// champ, se compare, se teste. Il ne contient **aucun état** et n'ouvre rien
/// tant que [open] n'est pas appelé.
///
/// Chaque champ de chrome est un **pass-through PUR** vers le paramètre
/// homonyme de [ZContentHubSheet] : la chaîne de priorité
/// **paramètre > jeton `ZcrudTheme.contentHub*` > [ZContentHubReference]** reste
/// donc celle de la feuille, intacte. Le launcher n'en résout **aucun** morceau
/// lui-même — il serait sinon un second endroit où la priorité peut diverger.
///
/// ```dart
/// // Chez l'hôte, hissé en champ (jamais reconstruit dans `build`) :
/// final _hub = ZContentHubLauncher(
///   sections: <ZContentHubSection>[
///     ZContentHubSection(
///       title: l10n.flashcards,                                   // INJECTÉ
///       entries: <ZContentHubEntry>[
///         ZContentHubEntry(
///           icon: Icons.auto_awesome,
///           label: l10n.generateWithAi,                           // INJECTÉ
///           colorKey: ZContentHubReference.colorKeyFlashcards,    // teinte STABLE
///           onTap: _generate,
///         ),
///       ],
///     ),
///   ],
/// );
/// ```
@immutable
class ZContentHubLauncher {
  /// Construit une configuration de hub. **Aucun paramètre n'a de défaut
  /// littéral textuel** (FR-26) : le socle n'ajoute pas un mot.
  const ZContentHubLauncher({
    this.entries = const <ZContentHubEntry>[],
    this.sections = const <ZContentHubSection>[],
    this.density,
    this.itemExtent,
    this.itemRadius,
    this.itemPadding,
    this.itemTintAlpha,
    this.avatarSize,
    this.avatarTintAlpha,
    this.glyphSize,
    this.accents,
    this.badgeColor,
    this.chevronGlyph,
    this.gridBreakpoint,
    this.gridCrossAxisCount,
    this.minContrast,
    this.sectionTitleStyle,
    this.padding,
    this.presenter,
  });

  /// Entrées NON groupées — rendues en section sans intitulé, en tête.
  final List<ZContentHubEntry> entries;

  /// Sections titrées.
  final List<ZContentHubSection> sections;

  /// Densité du rendu. `null` ⇒ jeton, puis référence.
  final ZContentHubDensity? density;

  /// Hauteur d'item de référence. `null` ⇒ jeton, puis référence.
  final double? itemExtent;

  /// Rayon d'une carte d'entrée. `null` ⇒ jeton, puis référence.
  final Radius? itemRadius;

  /// Padding interne d'une carte. `null` ⇒ jeton, puis référence.
  final EdgeInsetsGeometry? itemPadding;

  /// Opacité de la teinte de fond d'une carte. `null` ⇒ jeton, puis référence.
  final double? itemTintAlpha;

  /// Diamètre de la pastille d'identité. `null` ⇒ jeton, puis référence.
  final double? avatarSize;

  /// Opacité du fond de la pastille. `null` ⇒ jeton, puis référence.
  final double? avatarTintAlpha;

  /// Taille du glyphe d'entrée. `null` ⇒ jeton, puis référence.
  final double? glyphSize;

  /// Palette des teintes d'identité. `null` ⇒ jeton, puis référence.
  final List<Color>? accents;

  /// Teinte du badge de mise en avant. `null` ⇒ jeton, puis référence.
  final Color? badgeColor;

  /// Glyphe du chevron d'affordance. `null` ⇒ référence.
  final IconData? chevronGlyph;

  /// Largeur de bascule en grille. `null` ⇒ jeton, puis référence.
  final double? gridBreakpoint;

  /// Colonnes au-delà de [gridBreakpoint]. `null` ⇒ jeton, puis référence.
  final int? gridCrossAxisCount;

  /// Plancher de contraste des teintes peintes. `null` ⇒ jeton, puis référence.
  final double? minContrast;

  /// Style des intitulés de section. `null` ⇒ jeton, puis thème.
  final TextStyle? sectionTitleStyle;

  /// Padding de la zone défilante. `null` ⇒ référence.
  final EdgeInsetsGeometry? padding;

  /// Seam de PRÉSENTATION. `null` ⇒ feuille modale (repli documenté).
  final ZContentHubPresenter? presenter;

  /// Construit la feuille configurée — **sous** la route de présentation.
  ///
  /// Exposé (et non privé) parce qu'un hôte qui fournit son propre [presenter]
  /// en a besoin, et qu'un test doit pouvoir monter la feuille **sans** route.
  Widget buildSheet(BuildContext context) => ZContentHubSheet(
    entries: entries,
    sections: sections,
    density: density,
    itemExtent: itemExtent,
    itemRadius: itemRadius,
    itemPadding: itemPadding,
    itemTintAlpha: itemTintAlpha,
    avatarSize: avatarSize,
    avatarTintAlpha: avatarTintAlpha,
    glyphSize: glyphSize,
    accents: accents,
    badgeColor: badgeColor,
    chevronGlyph: chevronGlyph,
    gridBreakpoint: gridBreakpoint,
    gridCrossAxisCount: gridCrossAxisCount,
    minContrast: minContrast,
    sectionTitleStyle: sectionTitleStyle,
    padding: padding,
  );

  /// Ouvre le hub depuis [context] et se résout à sa fermeture.
  ///
  /// Le `context` sert **deux** rôles distincts, et c'est voulu : il désigne la
  /// route sous laquelle présenter, et il porte le `Theme`/`Directionality` que
  /// la présentation propagera. Un hôte qui veut découpler les deux fournit son
  /// [presenter].
  Future<void> open(BuildContext context) =>
      (presenter ?? _presentAsModalSheet)(context, buildSheet);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZContentHubLauncher &&
          listEquals(entries, other.entries) &&
          listEquals(sections, other.sections) &&
          density == other.density &&
          itemExtent == other.itemExtent &&
          itemRadius == other.itemRadius &&
          itemPadding == other.itemPadding &&
          itemTintAlpha == other.itemTintAlpha &&
          avatarSize == other.avatarSize &&
          avatarTintAlpha == other.avatarTintAlpha &&
          glyphSize == other.glyphSize &&
          listEquals(accents, other.accents) &&
          badgeColor == other.badgeColor &&
          chevronGlyph == other.chevronGlyph &&
          gridBreakpoint == other.gridBreakpoint &&
          gridCrossAxisCount == other.gridCrossAxisCount &&
          minContrast == other.minContrast &&
          sectionTitleStyle == other.sectionTitleStyle &&
          padding == other.padding &&
          presenter == other.presenter;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(entries),
    Object.hashAll(sections),
    density,
    itemExtent,
    itemRadius,
    itemPadding,
    itemTintAlpha,
    avatarSize,
    avatarTintAlpha,
    glyphSize,
    accents == null ? null : Object.hashAll(accents!),
    badgeColor,
    chevronGlyph,
    gridBreakpoint,
    gridCrossAxisCount,
    minContrast,
    sectionTitleStyle,
    padding,
    presenter,
  );
}

/// Portée d'un hub d'ajout **configuré une seule fois** — pour que le `+` de
/// l'app-bar et le `+` d'une section ouvrent LE MÊME hub.
///
/// C'est un `InheritedWidget` **sans état** : il ne transporte qu'une valeur
/// immuable. Le poser est le seul geste qui « branche » le hub ; ne pas le poser
/// laisse l'arbre strictement inchangé.
///
/// 🔴 Voir la dartdoc de bibliothèque : la lecture est **non dépendante**
/// (`getInheritedWidgetOfExactType`) — c'est ce qui rend l'ouverture du hub
/// sans effet sur les rebuilds de la liste (SM-1, mesuré par garde).
class ZContentHubScope extends InheritedWidget {
  /// Publie [launcher] pour tout le sous-arbre [child].
  const ZContentHubScope({
    required this.launcher,
    required super.child,
    super.key,
  });

  /// Le hub configuré, partagé par tous les `+` du sous-arbre.
  final ZContentHubLauncher launcher;

  /// Le hub en portée, ou `null` s'il n'y en a pas (AD-10 — jamais de throw,
  /// jamais d'`assert` : l'absence de hub est un cas ORDINAIRE, c'est même le
  /// défaut).
  ///
  /// 🔴 **Lecture NON dépendante** — cf. dartdoc de bibliothèque (SM-1).
  static ZContentHubLauncher? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ZContentHubScope>()?.launcher;

  /// Callback d'ouverture du hub en portée, ou `null` s'il n'y en a pas.
  ///
  /// `null` est le signal AD-4 attendu par les sites d'appel : **capacité
  /// absente ⇒ commande absente de l'arbre**, jamais un bouton grisé ni un
  /// no-op silencieux.
  ///
  /// Le launcher est relu **au moment du tap**, jamais capturé à la
  /// construction : un hôte qui échange son hub entre deux frames voit le
  /// nouveau s'ouvrir, sans qu'aucun bouton n'ait eu à se reconstruire.
  static VoidCallback? openerOf(BuildContext context) {
    if (context.getInheritedWidgetOfExactType<ZContentHubScope>() == null) {
      return null;
    }
    return () => maybeOf(context)?.open(context);
  }

  @override
  bool updateShouldNotify(ZContentHubScope oldWidget) =>
      launcher != oldWidget.launcher;
}
