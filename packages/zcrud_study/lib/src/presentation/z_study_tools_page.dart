/// `ZStudyToolsPage` — page « study tools » qui assemble une
/// `List<ZStudyToolsSectionSpec>` via `ZSectionedStudyLayout` (composition,
/// jamais une réimplémentation inline du layout).
///
/// Rebuilds granulaires (invariant AD-2, objectif produit n°1) : taper dans
/// un champ scopé ne reconstruit que le champ courant (rebuild ciblé via
/// `ZFieldListenableBuilder` sur la tranche `ValueListenable` du champ),
/// zéro rebuild des autres sections ni de la page, zéro perte de focus.
///
/// Invariants appliqués ici :
/// - le [ZFormController] est stable : créé une fois (`initState`) s'il
///   n'est pas injecté, jamais recréé au rebuild, disposé au `dispose`
///   uniquement s'il est possédé (un controller injecté par l'appelant
///   n'est pas disposé) ;
/// - aucun `setState` pour une valeur de champ ; aucun
///   `ListenableBuilder(listenable: controller)` enveloppant les sections,
///   ce qui réintroduirait un rebuild global. Seuls les
///   `ZFieldListenableBuilder` par champ (dans les `itemBuilder` fournis par
///   l'appelant) écoutent leur tranche ;
/// - aucun gestionnaire d'état (invariant AD-15) : réactivité Flutter-native
///   pure ; injection via `ZcrudScope` ou l'`InheritedWidget` interne.
library;

import 'package:flutter/widgets.dart';
import 'package:zcrud_core/zcrud_core.dart' show ZFormController;

import 'z_sectioned_study_layout.dart';
import 'z_study_tools_section_spec.dart';

/// Page « study tools » à scoping réactif ISOLÉ (invariant AD-2).
///
/// `StatefulWidget` **uniquement** pour le cycle de vie du [ZFormController]
/// stable (create/dispose) — JAMAIS pour l'état des champs (qui vit dans les
/// tranches du controller, observées champ par champ).
class ZStudyToolsPage extends StatefulWidget {
  /// Construit la page à partir des descripteurs de section (ordre préservé).
  ///
  /// [formController] : si fourni, la page l'UTILISE tel quel et NE le dispose
  /// PAS (propriété de l'appelant). Sinon la page en crée un et le possède
  /// (disposé au `dispose`). [globalEmptyState] : état vide GLOBAL injecté,
  /// rendu quand TOUTES les sections sont vides ; `null` = rendre les
  /// sections telles quelles.
  const ZStudyToolsPage({
    required this.sections,
    this.globalEmptyState,
    this.formController,
    super.key,
  });

  /// Descripteurs de section, dans l'ordre visuel voulu (aucun tri implicite).
  final List<ZStudyToolsSectionSpec> sections;

  /// État vide GLOBAL injecté. Rendu SSI toutes les sections sont vides ET
  /// non-`null`. Jamais un label codé en dur : l'appelant l'injecte (i18n).
  final Widget? globalEmptyState;

  /// Controller injecté (optionnel). `null` ⇒ la page en crée/possède un.
  final ZFormController? formController;

  /// Résout le [ZFormController] de la page englobante (owned OU injecté) depuis
  /// un [itemBuilder] scopé, sans coupler l'appelant à l'instanciation. Retourne
  /// `null` hors d'une [ZStudyToolsPage].
  static ZFormController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_ZStudyFormScope>()
      ?.controller;

  /// Comme [maybeOf], mais lève une [FlutterError] hors d'une [ZStudyToolsPage].
  static ZFormController of(BuildContext context) {
    final controller = maybeOf(context);
    assert(
      controller != null,
      'ZStudyToolsPage.of() appelé hors d\'une ZStudyToolsPage.',
    );
    return controller!;
  }

  @override
  State<ZStudyToolsPage> createState() => _ZStudyToolsPageState();
}

class _ZStudyToolsPageState extends State<ZStudyToolsPage> {
  /// Controller POSSÉDÉ (créé ici) — `null` si l'appelant en a injecté un.
  ZFormController? _owned;

  /// Controller effectif : injecté prioritaire, sinon le controller possédé.
  ZFormController get _controller => widget.formController ?? _owned!;

  @override
  void initState() {
    super.initState();
    // Controller STABLE créé UNE fois (jamais dans build()) — AD-2.
    if (widget.formController == null) {
      _owned = ZFormController();
    }
  }

  @override
  void didUpdateWidget(covariant ZStudyToolsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Transition possédé ↔ injecté (défensif ; jamais recréé pour un rebuild
    // ordinaire — seule une bascule de propriété reconstruit le controller).
    if (widget.formController != null && _owned != null) {
      // L'appelant fournit désormais son propre controller : libérer le nôtre.
      _owned!.dispose();
      _owned = null;
    } else if (widget.formController == null && _owned == null) {
      // L'appelant retire son controller : redevenir propriétaire.
      _owned = ZFormController();
    }
  }

  @override
  void dispose() {
    // Ne disposer QUE le controller possédé (jamais un controller injecté).
    _owned?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sections = widget.sections;
    final globalEmptyState = widget.globalEmptyState;

    // État vide GLOBAL : rendu SSI toutes les sections sont vides ET un
    // globalEmptyState est injecté. Sinon → composition du layout sectionné.
    final allEmpty = sections.every((s) => s.itemCount == 0);
    final Widget body = (globalEmptyState != null && allEmpty)
        ? globalEmptyState
        // COMPOSITION (AD-4) : le layout sectionné est RÉUTILISÉ, jamais
        // réimplémenté inline. AUCUN `ListenableBuilder` global ici.
        : ZSectionedStudyLayout(sections: sections);

    // Le controller stable est exposé aux itemBuilder scopés via un
    // InheritedWidget — identité STABLE ⇒ aucune propagation de rebuild
    // (setValue ne notifie que la tranche du champ, jamais ce scope).
    return _ZStudyFormScope(
      controller: _controller,
      child: body,
    );
  }
}

/// `InheritedWidget` interne exposant le [ZFormController] stable de la page aux
/// `itemBuilder` scopés. `updateShouldNotify` ne se déclenche QUE si l'identité
/// du controller change (jamais sur un `setValue`) — la stabilité du controller
/// garantit zéro rebuild propagé (invariant AD-2).
class _ZStudyFormScope extends InheritedWidget {
  const _ZStudyFormScope({required this.controller, required super.child});

  final ZFormController controller;

  @override
  bool updateShouldNotify(_ZStudyFormScope oldWidget) =>
      controller != oldWidget.controller;
}
