/// Port de **rendu de texte riche** du cœur `zcrud_core` (abstraction pure —
/// AD-1/AD-8).
///
/// origine: le legacy DODLP `dynamic_stepper.dart` rend le **sous-titre
/// d'étape** en Markdown, via `GptMarkdown` importé directement dans le widget
/// (deux sites : l. 406 et l. 790). Deux défauts, mesurés :
///
///  1. **Une dépendance de rendu riche dans le moteur.** AD-1 l'interdit à
///     `zcrud_core` — au même titre que Syncfusion l'est pour la liste (port
///     [ZListRenderer], implémenté par `zcrud_list`). Ce port est le pendant
///     exact pour le texte riche : le satellite (`zcrud_markdown`) fournira
///     l'implémentation, le cœur ne connaît QUE ce contrat.
///  2. **La donnée passée en contrebande dans un widget.** Leur
///     `Step.subtitle` est un `Widget` dont ils **redéballent** la chaîne par
///     `(step.subtitle as Text).data ?? ""`. Ici, la donnée reste une
///     `String` de bout en bout (`ZEditionStep.subtitle`) : le cast disparaît
///     **par construction**, et un sous-titre qui ne serait pas un `Text` ne
///     peut plus se perdre silencieusement.
///
/// ## Pourquoi un PORT sur `ZcrudScope`, et non une closure sur le widget
///
/// Mesuré : `ZcrudScope` porte **neuf** seams de rendu/résolution, et ce sont
/// **tous** des ports abstraits (`ZListRenderer`, `ZSelectPresenter`,
/// `ZColorPicker`, `ZAppFileResolver`, `ZGradientResolver`, …) — **aucun** n'est
/// une fonction nue. Le rendu du texte riche est une décision **d'application**
/// (« mes libellés riches se rendent en Markdown »), pas une décision de site
/// d'appel : elle doit valoir pour tous les steppers d'un coup. Une closure par
/// widget obligerait chaque écran à la re-câbler.
///
/// 🔴 Ce seam n'est **PAS** porté par `ZFieldSpec` : AD-3/AD-14 interdisent
/// toute closure dans une spec (sérialisable, comparable, `const`).
///
/// Imports limités à `package:flutter/widgets.dart` : AUCUN moteur de rendu,
/// AUCUNE dépendance lourde (garde `presentation_purity_test.dart`).
library;

import 'package:flutter/widgets.dart';

/// Abstraction de rendu d'une **chaîne de balisage** en widget.
///
/// Le backend concret (injecté via `ZcrudScope.richTextRenderer`) traduit
/// [source] en widget — Markdown, HTML, Delta… Le cœur ne connaît QUE ce
/// contrat et **ne suppose aucune syntaxe**.
abstract class ZRichTextRenderer {
  /// Constructeur `const` pour permettre des renderers immuables/`const`.
  const ZRichTextRenderer();

  /// Construit le widget de rendu riche de [source].
  ///
  /// [baseStyle] est le style **attendu par l'appelant** pour le corps de texte
  /// (le socle passe `TextTheme.bodySmall` pour un sous-titre d'étape — la
  /// mesure exacte du legacy). Un renderer doit le prendre pour base et n'en
  /// dévier que pour les rôles qu'il matérialise (gras, titre, code…).
  ///
  /// 🔴 **Rendre `null` = DÉCLINER** : l'appelant retombe alors sur un rendu
  /// texte simple. C'est le chemin par lequel un renderer signale « je ne sais
  /// pas rendre ceci » sans lever (AD-10). Lever est également toléré — le
  /// socle rattrape et retombe sur le texte simple — mais décliner est le
  /// contrat propre.
  Widget? build(BuildContext context, String source, {TextStyle? baseStyle});
}
