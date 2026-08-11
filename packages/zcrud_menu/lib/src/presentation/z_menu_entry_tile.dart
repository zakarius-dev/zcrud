/// [ZMenuEntryTile] — la cellule d'entrée, OFFERTE aux présentations injectées.
///
/// **Ce que ce widget résout.** Un slot de contenu injecté laisse l'hôte
/// libre de sa disposition, mais lui délègue du même geste les cibles ≥ 48 dp,
/// les `Semantics` et la directionnalité du contenu rendu — trois exigences
/// facilement manquées : une grille dont les cellules dérivent d'un
/// `childAspectRatio` peut tomber sous la cible tactile, et un `Semantics`
/// dont le sous-arbre n'est pas exclu fait annoncer le libellé **deux fois**.
///
/// Ces deux défauts ne sont pas une fatalité : la CELLULE peut rester la
/// propriété de ce paquet même quand la DISPOSITION appartient à l'hôte.
/// Cette tuile est le pendant, pour le contenu, de ce que [ZMenuRequest.select]
/// est pour l'effet.
///
/// L'hôte garde toute sa liberté : il l'utilise, ou il rend ce qu'il veut.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:zcrud_core/zcrud_core.dart' show ZcrudTheme;

import '../domain/z_menu_entry.dart';

/// Cible de taille interactive minimale (invariant AD-13).
const double kZMenuMinTapTarget = 48.0;

/// Cellule d'entrée de menu : ≥ 48 dp, `Semantics` correctes, directionnelle,
/// sans couleur ni chaîne codée en dur.
class ZMenuEntryTile extends StatelessWidget {
  /// Construit la cellule.
  ///
  /// [entry] : l'entrée à rendre (déjà filtrée par la règle d'absence).
  ///
  /// [onSelected] : appelée au tap. `null` ⇒ la cellule ne pose AUCUN détecteur
  /// de geste (cas du rendu par défaut, où `PopupMenuItem` porte déjà le sien —
  /// deux détecteurs superposés produiraient deux invocations).
  ///
  /// [direction] : [Axis.horizontal] (glyphe puis libellé, colonne de menu) ou
  /// [Axis.vertical] (glyphe au-dessus du libellé, cellule de grille — la forme
  /// adaptée à un panneau d'actions disposé en grille plutôt qu'en colonne).
  const ZMenuEntryTile({
    required this.entry,
    this.onSelected,
    this.direction = Axis.horizontal,
    super.key,
  });

  /// Entrée rendue.
  final ZMenuEntry entry;

  /// Callback de tap (`null` ⇒ aucun détecteur posé par la cellule).
  final VoidCallback? onSelected;

  /// Sens de composition glyphe/libellé.
  final Axis direction;

  /// Disposition en GRILLE dont le plancher de 48 dp est **structurellement
  /// intenable à écraser** — à utiliser à la place d'un `childAspectRatio`.
  ///
  /// ## Pourquoi ce point d'entrée existe
  ///
  /// La cellule seule ne PEUT PAS tenir la cible de 48 dp quand son parent lui
  /// impose une contrainte serrée : le protocole de disposition de Flutter
  /// interdit à un enfant de se rendre plus grand que la place reçue
  /// (`BoxConstraints.enforce`). Mesuré sur une grille à deux colonnes dont
  /// les cellules dérivaient d'un `childAspectRatio: 3.5` : la cellule tombait
  /// à `Size(100.0, 28.6)`, soit 60 % de la cible — le plancher était
  /// **déclaré, jamais tenu**.
  ///
  /// Le seul remède structurel est donc de faire porter le plancher par la
  /// **disposition**, et de la faire appartenir au socle. `mainAxisExtent` est
  /// borné par le bas à [kZMenuMinTapTarget] : aucun appelant ne peut demander
  /// une cellule plus courte, et `childAspectRatio` — qui, lui, dérive la
  /// hauteur de la largeur et peut donc tomber à n'importe quelle valeur —
  /// n'est jamais consulté quand `mainAxisExtent` est fourni.
  ///
  /// L'hôte qui préfère sa propre grille reste libre : il sera simplement
  /// AVERTI (erreur de disposition en mode debug) si sa cellule écrase la cible.
  static SliverGridDelegate gridDelegate({
    required int crossAxisCount,
    double mainAxisExtent = kZMenuMinTapTarget,
    double mainAxisSpacing = 0,
    double crossAxisSpacing = 0,
  }) {
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: crossAxisCount,
      // `math.max` et non un `assert` : un hôte qui demande 32 dp obtient une
      // cellule CONFORME, pas une exception. Le plancher n'est pas négociable —
      // c'est précisément ce que « structurel » veut dire ici.
      mainAxisExtent: math.max(mainAxisExtent, kZMenuMinTapTarget),
      mainAxisSpacing: mainAxisSpacing,
      crossAxisSpacing: crossAxisSpacing,
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = _content(context);
    // Un tap n'est posé QUE si l'entrée est actionnable ET qu'on nous demande de
    // le poser : une entrée désactivée ne peut pas devenir cliquable par
    // l'insertion d'un `InkWell` (invariant AD-4 — pas de no-op silencieux).
    final tappable = onSelected != null && entry.isEnabled;
    return _ZMinTapTargetGuard(
      minSize: const Size(kZMenuMinTapTarget, kZMenuMinTapTarget),
      // Une cellule NON tappable n'a pas de cible propre : c'est l'ancêtre
      // (`PopupMenuItem`) qui porte le geste ET son propre plancher. L'exiger
      // ici ferait rougir un cas conforme.
      enforced: tappable,
      child: Semantics(
        button: true,
        enabled: entry.isEnabled,
        label: entry.label,
        // Motif de désactivation ANNONCÉ dans le slot prévu pour cela : aucune
        // chaîne n'est fabriquée par concaténation (donc aucun séparateur codé
        // en dur à localiser).
        hint: entry.disabledReason,
        // Sans cette exclusion, le libellé de ce nœud ET celui du `Text` enfant
        // sont tous deux annoncés — « Ouvrir\nOuvrir ». Retirer le `label:` à
        // la place NE MARCHE PAS : le nœud devient MUET.
        excludeSemantics: true,
        // Le `ConstrainedBox` porte le plancher quand la contrainte entrante est
        // LÂCHE (colonne de menu) : la cellule se rend à 48 dp. Il ne peut RIEN
        // quand elle est SERRÉE (`enforce` par le parent) — d'où le couple
        // [ZMenuEntryTile.gridDelegate] + [_ZMinTapTargetGuard] ci-dessous.
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: kZMenuMinTapTarget,
            minHeight: kZMenuMinTapTarget,
          ),
          child: tappable
              ? InkWell(onTap: onSelected, child: content)
              : content,
        ),
      ),
    );
  }

  Widget _content(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    final reason = entry.disabledReason;
    final label = Text(
      entry.label,
      // invariant AD-13 : jamais `TextAlign.left`/`right` — `start` suit la
      // directionnalité.
      textAlign: TextAlign.start,
    );
    final texts = <Widget>[
      label,
      if (reason != null)
        Text(
          reason,
          textAlign: TextAlign.start,
          // Style DÉRIVÉ du thème — aucune couleur littérale.
          style: Theme.of(context).textTheme.bodySmall,
        ),
    ];
    // Glyphe OPTIONNEL : une entrée sans icône ne réserve aucune gouttière.
    final icon = entry.icon;
    if (direction == Axis.vertical) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon), SizedBox(height: theme.gapS)],
          ...texts,
        ],
      );
    }
    return Row(
      children: [
        if (icon != null) ...[Icon(icon), SizedBox(width: theme.gapM)],
        Expanded(
          child: texts.length == 1
              ? texts.first
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: texts,
                ),
        ),
      ],
    );
  }
}

/// Garde de disposition : rend un plancher écrasé **impossible à livrer en
/// silence**.
///
/// ## Ce qu'elle remplace, et pourquoi
///
/// Une approche alternative tiendrait le plancher par extension du `hitTest`
/// au-delà des bornes peintes (motif `_InputPadding` de Material). **Mesuré :
/// elle ne se déclenche jamais dans le cas cible.** Tout ancêtre `RenderBox`
/// filtre le pointeur par `size.contains(position)` avant de le transmettre —
/// et une grille interpose d'office un `RepaintBoundary` autour de chaque
/// cellule. Sondes : gouttière de 20 dp d'une grille 2 × 2, taps à
/// +20 / +23 dp du centre ⇒ **aucune sélection**. Un dispositif inerte est
/// pire que rien : il promettrait un plancher qu'il ne tient pas.
///
/// Ce qui reste tenable depuis la cellule, c'est le **signal** : si la place
/// reçue écrase la cible, on émet une erreur de disposition en mode debug — le
/// même idiome que `RenderFlex overflowed`. Elle rougit dans les tests de
/// l'hôte, s'affiche dans sa console, et **ne casse jamais la production**.
/// Le remède est nommé dans le message : [ZMenuEntryTile.gridDelegate].
class _ZMinTapTargetGuard extends SingleChildRenderObjectWidget {
  const _ZMinTapTargetGuard({
    required this.minSize,
    required this.enforced,
    required Widget super.child,
  });

  /// Cible minimale exigée.
  final Size minSize;

  /// `false` ⇒ la cellule ne porte pas de geste propre (l'ancêtre le porte).
  final bool enforced;

  @override
  _RenderZMinTapTargetGuard createRenderObject(BuildContext context) =>
      _RenderZMinTapTargetGuard(minSize: minSize, enforced: enforced);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderZMinTapTargetGuard renderObject,
  ) {
    renderObject
      ..minSize = minSize
      ..enforced = enforced;
  }
}

// Champs privés à setter (chaque écriture doit `markNeedsLayout`) : les
// formals d'initialisation ne conviennent pas ici.
// ignore_for_file: prefer_initializing_formals
class _RenderZMinTapTargetGuard extends RenderProxyBox {
  _RenderZMinTapTargetGuard({required Size minSize, required bool enforced})
    : _minSize = minSize,
      _enforced = enforced;

  Size get minSize => _minSize;
  Size _minSize;
  set minSize(Size value) {
    if (value == _minSize) return;
    _minSize = value;
    markNeedsLayout();
  }

  bool get enforced => _enforced;
  bool _enforced;
  set enforced(bool value) {
    if (value == _enforced) return;
    _enforced = value;
    markNeedsLayout();
  }

  /// Tolérance d'arrondi : une cellule de 47,7 dp n'est pas le défaut visé
  /// (la mesure du défaut réel était 28,6 dp).
  static const double _tolerance = 0.5;

  @override
  void performLayout() {
    super.performLayout();
    assert(() {
      if (!_enforced) return true;
      final manquantW = _minSize.width - size.width;
      final manquantH = _minSize.height - size.height;
      if (manquantW <= _tolerance && manquantH <= _tolerance) return true;
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: FlutterError.fromParts(<DiagnosticsNode>[
            ErrorSummary(
              'ZMenuEntryTile : cible tactile ÉCRASÉE — '
              '${size.width.toStringAsFixed(1)} × '
              '${size.height.toStringAsFixed(1)} dp au lieu de '
              '${_minSize.width.toStringAsFixed(0)} × '
              '${_minSize.height.toStringAsFixed(0)} dp (AD-13/NFR-S6).',
            ),
            ErrorDescription(
              'La cellule a reçu une contrainte SERRÉE plus petite que la cible '
              'minimale. Un enfant ne peut pas se rendre plus grand que la place '
              'que son parent lui impose : le plancher ne peut PAS être tenu '
              'depuis la cellule — il doit l\'être par la DISPOSITION.',
            ),
            ErrorHint(
              'Remède : composer la grille avec '
              '`ZMenuEntryTile.gridDelegate(crossAxisCount: …)`, qui borne '
              '`mainAxisExtent` par le bas à ${kZMenuMinTapTarget.toStringAsFixed(0)} dp. '
              'Un `childAspectRatio` dérive la hauteur de la largeur et peut '
              'tomber à n\'importe quelle valeur : c\'est le cas mesuré à '
              '28,6 dp qui a motivé cette garde.',
            ),
          ]),
          library: 'zcrud_menu',
          context: ErrorDescription('pendant la disposition de ZMenuEntryTile'),
        ),
      );
      return true;
    }());
  }
}
