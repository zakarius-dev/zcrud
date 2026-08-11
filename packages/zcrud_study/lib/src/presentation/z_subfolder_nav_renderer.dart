/// Port de rendu de **SURFACE** de navigation de sous-dossiers —
/// `ZSubfolderNavRenderer` (invariants AD-4/AD-10).
///
/// ## Pourquoi ce port existe
///
/// `ZSubfolderNavSpec.itemBuilder` construit un **ÉLÉMENT**, jamais le
/// **CONTENEUR**. Sans ce port, chaque nouveau besoin de surface (barre de
/// sélection, onglets, menu…) exigerait **une nouvelle valeur d'énumération**
/// côté paquet à chaque fois — le mode `selector` n'aurait corrigé que
/// l'occurrence du jour, pas la cause racine.
///
/// Le motif est **générique** : chapitres d'un manuel, étapes d'un parcours,
/// onglets de document, filtres de catégorie. Un hôte qui veut sa propre surface
/// l'injecte ici, sans que ce paquet connaisse son vocabulaire.
///
/// ## Patron
///
/// Jumeau **exact** de `ZChatShellRenderer` / `ZListRenderer` et de la chaîne
/// totale de `zResolveGradient` :
///
/// 1. **`null` est une réponse VALIDE et FONCTIONNELLE** : « je ne prends pas
///    cette navigation, garde la surface du socle ».
/// 2. **`const`** : le renderer est comparé par IDENTITÉ dans
///    [ZSubfolderNavRendererScope.updateShouldNotify].
/// 3. **AD-10** : une implémentation ne lève pas pour dire qu'elle ne sait pas
///    rendre — elle rend `null`. Et si elle lève quand même, [zResolveSubfolderNav]
///    **absorbe** : l'exception part dans `FlutterError.reportError` (console +
///    rapports de crash de l'hôte, avec sa pile) et la surface du socle est
///    rendue. Une navigation ne disparaît pas parce qu'une coquille tierce a
///    échoué.
///
/// ## Ce qu'une surface tierce ne peut PAS faire perdre
///
/// ```
/// ZSubfolderNarrowNav
///   └── zResolveSubfolderNav(...)          ← LE SEAM : la surface, et rien d'autre
///         └── request.itemContentBuilder() ← EN DESSOUS : la fabrique du socle
///               ├── spec.itemBuilder injecté (seam d'ÉLÉMENT de l'hôte)
///               └── chrome neutre (pastille d'accent + libellé + compteur)
/// ```
///
/// Une coquille reçoit **la place du conteneur**. Elle ne peut pas court-circuiter
/// le seam d'élément : elle ne peut que **rappeler** la fabrique du socle. La
/// seule dégradation qui lui reste est de ne pas l'appeler — auquel cas elle
/// n'affiche rien, panne bruyante et non silencieuse.
///
/// **Sans scope injecté, le rendu est STRICTEMENT inchangé** : l'absence de
/// scope, un `renderer` `null` et une coquille qui décline sont trois chemins
/// qui rendent tous la surface du socle.
library;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/widgets.dart';

import 'z_subfolder_nav_spec.dart';
import 'z_subfolder_ref.dart';

/// Fabrique du SOCLE remise à une surface tierce : contenu visuel d'un item.
///
/// [refOrNull] `null` ⇒ item racine (« tous »). Honore
/// [ZSubfolderNavSpec.itemBuilder] injecté et, à défaut, rend le chrome neutre
/// (pastille d'accent + libellé + compteur).
typedef ZSubfolderItemContentBuilder = Widget Function(
  BuildContext context,
  ZSubfolderRef? refOrNull,
  bool selected,
);

/// Requête **neutre** de rendu d'une surface de navigation étroite.
///
/// Ne porte AUCUN type de backend : un renderer d'hôte n'a besoin que de ce
/// vocabulaire (spec + tranche réactive de sélection + rappel de sélection +
/// fabrique d'item).
@immutable
class ZSubfolderNavRenderRequest {
  /// Construit la requête (instanciée par le socle, jamais par l'hôte).
  const ZSubfolderNavRenderRequest({
    required this.spec,
    required this.selected,
    required this.onSelect,
    required this.itemContentBuilder,
  });

  /// Descripteur de navigation (données + libellés, tout injecté).
  final ZSubfolderNavSpec spec;

  /// Tranche réactive de sélection (`null` = item racine « tous »).
  ///
  /// **AD-2** : la surface tierce s'y abonne par `ValueListenableBuilder` — elle
  /// ne DÉTIENT pas la sélection et ne doit pas la recopier dans un état local.
  final ValueListenable<String?> selected;

  /// À émettre quand l'utilisateur choisit un item (`null` pour la racine).
  final ValueChanged<String?> onSelect;

  /// Fabrique d'item du SOCLE — cf. [ZSubfolderItemContentBuilder].
  final ZSubfolderItemContentBuilder itemContentBuilder;
}

/// Abstraction de rendu de la **surface** de navigation étroite.
///
/// Injectée via [ZSubfolderNavRendererScope]. Ce paquet ne connaît QUE ce
/// contrat.
abstract class ZSubfolderNavRenderer {
  /// Constructeur `const` pour permettre des renderers immuables/`const`.
  const ZSubfolderNavRenderer();

  /// Rend la surface de [request], ou renvoie `null` pour **déléguer à la
  /// surface du socle** (barre de sélection ou rangée de puces selon
  /// [ZSubfolderNavSpec.narrowMode]).
  Widget? buildNav(BuildContext context, ZSubfolderNavRenderRequest request);
}

/// Porte le [ZSubfolderNavRenderer] injecté par l'hôte jusqu'à la navigation.
class ZSubfolderNavRendererScope extends InheritedWidget {
  /// Injecte [renderer] pour le sous-arbre [child].
  const ZSubfolderNavRendererScope({
    required this.renderer,
    required super.child,
    super.key,
  });

  /// La surface de l'hôte. `null` ⇒ surface du socle partout (état par défaut,
  /// strictement identique à l'absence de scope).
  final ZSubfolderNavRenderer? renderer;

  /// Le scope le plus proche, ou `null` — **jamais de throw** (AD-10).
  static ZSubfolderNavRendererScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ZSubfolderNavRendererScope>();

  @override
  bool updateShouldNotify(ZSubfolderNavRendererScope oldWidget) =>
      !identical(renderer, oldWidget.renderer);
}

/// Chaîne **TOTALE** : seam hôte → `null`.
///
/// Scope absent, renderer absent, coquille qui décline **ou qui lève** rendent
/// tous `null` sans propager d'exception. `null` signifie « surface du socle »,
/// ce qui garantit qu'un consommateur non configuré rend exactement comme si ce
/// port n'existait pas.
Widget? zResolveSubfolderNav(
  BuildContext context,
  ZSubfolderNavRenderRequest request,
) {
  final ZSubfolderNavRenderer? renderer =
      ZSubfolderNavRendererScope.maybeOf(context)?.renderer;
  if (renderer == null) return null;
  try {
    return renderer.buildNav(context, request);
  } catch (error, stack) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'zcrud_study',
        context: ErrorDescription(
          'lors du rendu de la surface de navigation de sous-dossiers '
          '(ZSubfolderNavRenderer) — repli sur la surface du socle',
        ),
      ),
    );
    return null;
  }
}
