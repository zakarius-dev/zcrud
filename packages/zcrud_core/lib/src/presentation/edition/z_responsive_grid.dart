/// Grille responsive **12 colonnes** du moteur d'édition (E3-4, FR-3, AD-13).
///
/// Descripteur de layout **pur-présentation** ([ZResponsiveSpan]) + widget de
/// disposition ([ZResponsiveGrid]). Additif : n'altère NI le générateur NI les
/// annotations (le domaine reste pur — les `span` sont un paramètre d'authoring
/// de présentation passé à `DynamicEdition`, pas une donnée de schéma).
///
/// INVARIANTS (NON-NÉGOCIABLES) :
/// - **12 colonnes** ; un champ occupe `span/12` de la largeur disponible ; la
///   ligne **reflow** (wrap) quand la somme des `span` d'une rangée dépasse 12.
/// - **Breakpoints** résolus par la largeur du **conteneur** (`LayoutBuilder`,
///   composable dans un scroll/split-view) — jamais `MediaQuery` écran (AD-2/E7).
/// - **Directionnel exclusif** (AD-13) : gouttières `EdgeInsetsDirectional`, flux
///   `Wrap` (suit `Directionality` : LTR→start=gauche, RTL→start=droite). Aucun
///   `EdgeInsets.only(left/right)`/`Alignment.centerLeft` (garde style_purity).
/// - **Place stable** : la `ValueKey(name)` de chaque champ (posée par
///   `DynamicEdition`) est **remontée sur l'enfant direct du `Wrap`** (le
///   `SizedBox` de cellule) pour que `Wrap` réconcilie PAR CLÉ et non par
///   position — sinon un conditionnel inséré avant un champ focalisé détruirait
///   son `State` (focus/curseur perdus).
library;

import 'package:flutter/widgets.dart';

/// MIN-2 (colocalisation span — **test de cohérence des clés `layout`**) : le
/// `layout` de `DynamicEdition` est une `Map<String, ZResponsiveSpan>` dont les
/// clés sont des **noms de champ** (non typés). Cette fonction pure retourne les
/// clés du [layout] qui ne correspondent à **aucun** champ de [fieldNames] — une
/// clé orpheline (typiquement un champ renommé) dont le span serait silencieusement
/// ignoré au rendu. Permet à l'app/aux tests de **détecter la dérive** au lieu de
/// la subir. Pur-Dart, ne lève jamais ; ensemble vide ⇒ layout cohérent.
Set<String> zUnknownLayoutKeys(
  Set<String> fieldNames,
  Map<String, ZResponsiveSpan> layout,
) {
  final unknown = <String>{};
  for (final key in layout.keys) {
    if (!fieldNames.contains(key)) unknown.add(key);
  }
  return unknown;
}

/// Breakpoints responsives (style Bootstrap — cf. [ZResponsiveBreakpoints]).
enum ZBreakpoint {
  /// Extra-small (téléphone portrait).
  xs,

  /// Small (téléphone paysage).
  sm,

  /// Medium (tablette portrait).
  md,

  /// Large (tablette paysage / petit desktop).
  lg,

  /// Extra-large (desktop).
  xl,
}

/// Seuils de largeur (dp) des [ZBreakpoint] — hypothèse **Bootstrap** (FR-3 ne
/// fixe pas les seuils ; documentés et testés, ajustables).
///
/// `xs < 576 ≤ sm < 768 ≤ md < 992 ≤ lg < 1200 ≤ xl`.
abstract final class ZResponsiveBreakpoints {
  /// Seuil `sm` (largeur ≥ 576 dp).
  static const double sm = 576;

  /// Seuil `md` (largeur ≥ 768 dp).
  static const double md = 768;

  /// Seuil `lg` (largeur ≥ 992 dp).
  static const double lg = 992;

  /// Seuil `xl` (largeur ≥ 1200 dp).
  static const double xl = 1200;

  /// Résout le [ZBreakpoint] courant depuis une largeur de conteneur [width].
  static ZBreakpoint of(double width) {
    if (width >= xl) return ZBreakpoint.xl;
    if (width >= lg) return ZBreakpoint.lg;
    if (width >= md) return ZBreakpoint.md;
    if (width >= sm) return ZBreakpoint.sm;
    return ZBreakpoint.xs;
  }
}

/// Nombre de colonnes qu'occupe un champ **par breakpoint** (1..12).
///
/// Défaut = **12** (pleine largeur) à tous les breakpoints — compatibilité
/// ascendante : un champ sans `span` déclaré remplit la ligne (AC13). Chaque
/// breakpoint non fourni **hérite** du plus petit breakpoint renseigné en
/// dessous (cascade « mobile-first ») ; à défaut, 12.
@immutable
class ZResponsiveSpan {
  /// Construit un span par breakpoint. [xs] défaut 12 ; chaque cran supérieur
  /// non fourni hérite du cran inférieur (cascade mobile-first — voir [spanAt]).
  const ZResponsiveSpan({
    this.xs = 12,
    this.sm,
    this.md,
    this.lg,
    this.xl,
  });

  /// Raccourci : un span **uniforme** [span] sur tous les breakpoints.
  const ZResponsiveSpan.all(int span)
      : xs = span,
        sm = span,
        md = span,
        lg = span,
        xl = span;

  /// Span brut au breakpoint `xs` (défaut 12).
  final int xs;

  /// Span brut au breakpoint `sm` (`null` ⇒ hérite de [xs]).
  final int? sm;

  /// Span brut au breakpoint `md` (`null` ⇒ hérite du cran inférieur).
  final int? md;

  /// Span brut au breakpoint `lg` (`null` ⇒ hérite du cran inférieur).
  final int? lg;

  /// Span brut au breakpoint `xl` (`null` ⇒ hérite du cran inférieur).
  final int? xl;

  /// Span effectif (1..12) au breakpoint [bp], avec cascade mobile-first et
  /// bornage défensif dans `[1, 12]`.
  int spanAt(ZBreakpoint bp) {
    int raw;
    switch (bp) {
      case ZBreakpoint.xs:
        raw = xs;
      case ZBreakpoint.sm:
        raw = sm ?? xs;
      case ZBreakpoint.md:
        raw = md ?? sm ?? xs;
      case ZBreakpoint.lg:
        raw = lg ?? md ?? sm ?? xs;
      case ZBreakpoint.xl:
        raw = xl ?? lg ?? md ?? sm ?? xs;
    }
    if (raw < 1) return 1;
    if (raw > 12) return 12;
    return raw;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZResponsiveSpan &&
          runtimeType == other.runtimeType &&
          xs == other.xs &&
          sm == other.sm &&
          md == other.md &&
          lg == other.lg &&
          xl == other.xl;

  @override
  int get hashCode => Object.hash(runtimeType, xs, sm, md, lg, xl);
}

/// Dispose [children] sur une grille **12 colonnes** responsive.
///
/// Chaque enfant est associé (même index) à un [ZResponsiveSpan] via [spans] ;
/// un enfant sans span occupe 12 colonnes. La largeur d'une cellule vaut
/// `span/12 × (largeur - gouttières)` ; les rangées **reflow** au-delà de 12.
///
/// La direction du flux suit `Directionality` (AD-13) : `Wrap` place les cellules
/// depuis le bord **start**. La gouttière horizontale est [ZResponsiveGrid.gutter]
/// (posée en `Wrap.spacing`) ; la gouttière verticale est [ZResponsiveGrid.runGutter]
/// si fournie, sinon [ZResponsiveGrid.gutter] (posée en `Wrap.runSpacing`). Toutes
/// deux directionnellement neutres (mesures dp).
class ZResponsiveGrid extends StatelessWidget {
  /// Construit la grille pour [children], espacés de [gutter] (défaut 8 dp).
  ///
  /// [keys] (optionnel, aligné par index sur [children]) porte la `ValueKey(name)`
  /// de place stable **sur la cellule** (l'enfant direct du `Wrap`) — voir
  /// invariant *Place stable*. À défaut (`keys` vide), la clé lue est celle
  /// portée par `children[i]` (compat ascendante) : dans ce cas, pour ne pas
  /// dupliquer la clé, l'appelant fournit des enfants NON keyés au niveau racine.
  const ZResponsiveGrid({
    required this.children,
    required this.spans,
    this.keys = const <Key?>[],
    this.gutter = 8,
    this.runGutter,
    super.key,
  })  : assert(children.length == spans.length,
            'children et spans doivent être alignés (même longueur)'),
        assert(keys.length == 0 || keys.length == children.length,
            'keys, si fourni, doit être aligné sur children (même longueur)');

  /// Cellules à disposer. Chacune reçoit sa clé de place stable via [keys] (ou,
  /// à défaut, via la clé racine de l'enfant — voir constructeur).
  final List<Widget> children;

  /// Clés de place stable (`ValueKey(name)`) posées **sur la cellule directe** du
  /// `Wrap` (aligné par index sur [children]). Vide ⇒ repli sur `children[i].key`.
  final List<Key?> keys;

  /// Span (1..12) de chaque cellule, aligné par index sur [children].
  final List<ZResponsiveSpan> spans;

  /// Gouttière (dp) entre cellules — appliquée en `spacing` (inter-colonnes) et,
  /// par défaut, en `runSpacing` (inter-rangées) si [runGutter] est `null`.
  final double gutter;

  /// Gouttière **inter-rangées** (dp) posée en `Wrap.runSpacing` (AD-54, FR-38).
  /// **Additif non-cassant** : `null` (défaut) ⇒ repli sur [gutter] (comportement
  /// symétrique EXACT d'avant). Non `null` ⇒ gouttière verticale distincte (parité
  /// DODLP `verticalSpacing`, ex. `gutter: 16, runGutter: 8`). Directionnellement
  /// neutre (mesure dp ; `Wrap` suit `Directionality`).
  final double? runGutter;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;
        final bp = ZResponsiveBreakpoints.of(width);
        // Largeur d'UNE colonne : on retranche 11 gouttières inter-colonnes du
        // total pour que 12 colonnes + 11 gouttières tiennent EXACTEMENT dans la
        // largeur (reflow au-delà géré par `Wrap`).
        const columns = 12;
        final usable = width - gutter * (columns - 1);
        final colWidth = usable <= 0 ? 0.0 : usable / columns;

        final cells = <Widget>[
          for (var i = 0; i < children.length; i++)
            SizedBox(
              // PLACE STABLE (AD-2/FR-1) : la `ValueKey(name)` du champ est
              // portée sur l'ENFANT DIRECT du `Wrap` (cette cellule), pas
              // seulement sur un descendant. `Wrap` est un multi-enfant NON
              // paresseux qui réconcilie ses enfants directs PAR CLÉ quand elle
              // est présente (sinon par position). Sans clé ici, l'insertion
              // d'une cellule conditionnelle AVANT une cellule focalisée
              // décalerait les `SizedBox` par position et détruirait
              // l'`Element`/`State` du champ focalisé ⇒ focus + curseur perdus.
              key: i < keys.length ? keys[i] : children[i].key,
              // Une cellule de `span` colonnes couvre `span` colonnes + les
              // `span-1` gouttières internes qu'elle enjambe.
              width: _cellWidth(spans[i].spanAt(bp), colWidth),
              child: children[i],
            ),
        ];

        return Wrap(
          spacing: gutter,
          // Gouttière inter-rangées : `runGutter` si fourni, sinon repli sur
          // `gutter` (symétrie historique — API additive non-cassante).
          runSpacing: runGutter ?? gutter,
          children: cells,
        );
      },
    );
  }

  /// Largeur d'une cellule de [span] colonnes : `span` largeurs de colonne +
  /// `span-1` gouttières internes enjambées.
  double _cellWidth(int span, double colWidth) =>
      colWidth * span + gutter * (span - 1);
}
