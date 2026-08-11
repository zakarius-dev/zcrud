/// Helper de câblage **responsivité → présentation** — le
/// « maillon vivant ».
///
/// [presentEdition] matérialise la chaîne complète, du breakpoint à la
/// surface : `largeur → ZWindowSizeClass → ZPresentationPolicy.resolve →
/// ZEditionPresentation → ZFormPresenter → surface`. C'est le **seul** endroit
/// qui lie `context → largeur` côté présentation (via
/// `ZWindowSizeClass.of(context)` de `zcrud_responsive`) — la politique de
/// résolution reste **pure** (sans `BuildContext`).
library;

import 'package:flutter/widgets.dart';
import 'package:zcrud_core/zcrud_core.dart' show ZcrudTheme;
import 'package:zcrud_responsive/zcrud_responsive.dart' show ZWindowSizeClass;

import '../domain/z_edition_presentation.dart';
import '../domain/z_form_weight.dart';
import '../domain/z_presentation_policy.dart';
import 'z_edition_body_fit.dart';
import 'z_edition_chrome.dart';
import 'z_edition_scaffold.dart';
import 'z_form_presenter.dart';
import 'z_form_presenter_scope.dart';
import 'z_implicit_dismiss_control.dart';
import 'z_sheet_frame.dart';

/// Présente un formulaire d'édition en **dérivant le mode du breakpoint courant**.
///
/// Étapes :
/// 1. mesure la classe de fenêtre : `ZWindowSizeClass.of(context)`
///    (`zcrud_responsive`, `MediaQuery.sizeOf` — jamais `Get.width`) ;
/// 2. dérive le mode : `policy.resolve(sizeClass, formWeight: formWeight)`
///    (`ZPresentationPolicy`, **pure**) ;
/// 3. résout le présentateur effectif : [presenter] fourni, **sinon** le seam
///    `ZFormPresenterScope.of(context)` (défaut `const ZAdaptivePresenter()`) ;
/// 4. délègue à `present<T>(context, builder: ..., mode: ...)`.
///
/// [policy] **et** [presenter] sont **injectables** (défauts M3 + défaut
/// pur-Flutter) — surchargeables par app sans modifier le package (invariants
/// AD-6/AD-4).
///
/// ## [chrome] — STRICTEMENT opt-in
///
/// * `chrome: null` (**le défaut**) ⇒ le builder est passé **tel quel** au
///   presenter : l'arbre rendu est **strictement identique** au rendu sans
///   chrome — pas « équivalent ». Épinglé par une garde d'identité d'arbre
///   (empreinte SHA-256, non-vacuité prouvée).
/// * `chrome != null` ⇒ le builder est enveloppé dans un [ZEditionScaffold]
///   monté sur le **mode résolu**, qui fournit titre / actions / comportement
///   d'en-tête propre au mode.
///
/// De plus, si le chrome arme un garde d'abandon
/// ([ZEditionChrome.guardsDiscard]) **et** que le presenter effectif implémente
/// [ZImplicitDismissControl], les voies de fermeture qui **court-circuitent
/// `PopScope`** sont neutralisées (en `sheet` : le **glissement**, qui
/// perdrait sinon la saisie sans confirmation). Un presenter qui n'implémente
/// pas cette capacité optionnelle est utilisé **tel quel** (invariant AD-10 :
/// repli, jamais d'exception) — il n'offrira simplement pas cette garantie.
///
/// La **sélection du mode par breakpoint** n'est touchée en RIEN par
/// [chrome] : elle reste la chaîne `largeur → ZWindowSizeClass → policy`.
///
/// ## [forcedMode] — TROISIÈME point de contrôle, et sa règle de priorité
///
/// **`forcedMode` (appel) > `policy` (app) > politique par défaut (M3)**.
///
/// Les trois coexistent parce qu'ils répondent à trois questions différentes :
/// * la **politique par défaut** dit ce que M3 recommande ;
/// * [policy] **change la règle** pour toute une app (« chez nous, `medium`
///   ouvre une page ») — elle reste dérivée du breakpoint ;
/// * [forcedMode] **court-circuite la règle pour UN appel précis** (« ce
///   formulaire-ci s'ouvre toujours en page »). Il ne redéfinit rien
///   globalement — c'est un échappement local, pas une politique.
///
/// Quand [forcedMode] est non-`null` :
/// * [policy] **n'est pas consultée du tout** (ni `resolve`, ni instanciée) ;
/// * `ZWindowSizeClass.of(context)` **n'est pas lu** — donc **aucune dépendance
///   à `MediaQuery`** n'est enregistrée sur le contexte appelant. Lire la
///   classe de fenêtre depuis un `build` fait reconstruire le call-site à
///   chaque changement de taille de fenêtre ; quand le résultat est ignoré,
///   c'est une reconstruction gratuite — évitée ici par construction.
/// * **aucune cohérence n'est exigée** avec le breakpoint : forcer `page` sur un
///   écran `compact`, ou `dialog` sur mobile, **fonctionne** — aucune assertion,
///   aucun repli silencieux. C'est tout l'intérêt du paramètre.
/// * [chrome], s'il est fourni, est monté sur le mode **effectif** — donc sur le
///   mode **forcé**, jamais sur un mode dérivé qu'on aurait recalculé.
///
/// ## [sheetFrame] — feuille CONTRAINTE et ENCADRÉE
///
/// En mode `sheet`, le socle contraint la largeur (`min(largeur × 0,9,
/// 640 dp)`) et peint un **cadre** (`BorderSide` sur le rôle
/// `ColorScheme.outlineVariant`) — voir `z_sheet_frame.dart` pour le détail
/// de cette décision.
///
/// **Hôte qui compensait** : si vous restituiez cette marge par vos propres
/// moyens (un `Padding` externe, un `Container(constraints: maxWidth: …)`
/// autour de votre contenu, une carte encadrée interne), **retirez votre
/// compensation** : elle s'additionne au socle. Sinon vous obtiendrez une
/// marge double et **deux bords concentriques**.
///
/// **Échappatoires** (chaîne **paramètre > jeton `ZcrudTheme.editionSheet*` >
/// référence**) :
/// * pour UN appel : `sheetFrame: ZSheetFrameSpec(mode: ZSheetFrameMode.never)` ;
/// * pour toute l'app : `ZcrudTheme(editionSheetFrameMode:
///   ZSheetFrameMode.never.name)` (le jeton est un `String` — l'invariant AD-1
///   interdit à `zcrud_core` d'importer l'énumération ; l'enum reste la
///   source du nom) ;
/// * pleine largeur : `ZSheetFrameSpec(widthRatio: 1, maxWidth: double.infinity)`
///   — **indépendant** du cadre (retirer la bordure ne rend PAS la feuille
///   pleine largeur, et inversement) ;
/// * [maxWidth] explicite **prime sur tout** (inchangé depuis toujours).
///
/// [ZSheetFrameMode.unlessChrome] est résolu **ici**, et seulement ici : c'est
/// le seul endroit qui sait si l'appelant a **déclaré** un [chrome]. Le socle
/// ne devine jamais « ceci est une édition » par une heuristique de type sur
/// le contenu.
///
/// Un presenter qui n'implémente pas [ZImplicitDismissControl] est appelé
/// par `present` **tel quel** : il n'aura ni la marge ni le cadre (invariant
/// AD-10 : repli, jamais d'exception).
///
/// ## [isDismissible] — barrière de la FEUILLE
///
/// Défaut `true` ⇒ **rien ne bouge** pour un hôte passif. `false` rend la
/// barrière de la bottom-sheet **non fermante** — voie « interdire le
/// renoncement », à ne pas confondre avec le « garder le renoncement » que pose
/// un [chrome] armant `guardsDiscard`. Les deux réglages sont **orthogonaux** et
/// se composent : la règle complète est au dartdoc de
/// `ZImplicitDismissControl.presentWithDismissControl`.
///
/// **Inerte** en `page` et en `dialog` — en `dialog`, c'est
/// [barrierDismissible] qui règle la barrière.
///
/// Comme [sheetFrame], ce paramètre ne transite que par
/// [ZImplicitDismissControl] : un presenter **tiers** qui ne l'implémente pas
/// est appelé par `present` et ne le recevra pas (invariant AD-10 : repli,
/// jamais d'exception).
///
/// ## [bodyFit] — corps qui DÉFILE
///
/// Ne concerne que la voie [chrome] (sans chrome, le socle ne place rien).
/// Défaut [ZEditionBodyFit.intrinsic] ⇒ **aucun changement** pour un hôte
/// passif. Si votre corps défile (`DynamicEdition`/`ZStepperEdition` par
/// défaut, une `ListView`…), déclarez
/// `bodyFit: ZEditionBodyFit.scrollable` : le **contenant** le bornera, et le
/// corps gardera son propre défilement.
///
/// **Hôte qui contournait** : si vous passiez `shrinkWrap: true` +
/// `NeverScrollableScrollPhysics()` à votre `DynamicEdition` pour survivre au
/// mode `page`, **retirez ce contournement en même temps** que vous déclarez
/// [ZEditionBodyFit.scrollable] — les deux ensemble donneraient un corps
/// non-scrollable placé dans un contenant qui l'attend scrollable. Garder le
/// contournement **et** le défaut [ZEditionBodyFit.intrinsic] reste, lui,
/// parfaitement valide et inchangé.
Future<T?> presentEdition<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  ZFormWeight formWeight = ZFormWeight.light,
  ZPresentationPolicy policy = const ZPresentationPolicy(),
  ZFormPresenter? presenter,
  double? maxWidth,
  double? maxHeight,
  bool useSafeArea = true,
  bool barrierDismissible = true,
  bool isDismissible = true,
  ZEditionChrome? chrome,
  ZEditionPresentation? forcedMode,
  ZSheetFrameSpec? sheetFrame,
  ZEditionBodyFit bodyFit = ZEditionBodyFit.intrinsic,
}) {
  // Court-circuit TOTAL quand le mode est forcé : ni lecture de la classe de
  // fenêtre (donc aucune dépendance `MediaQuery` enregistrée), ni consultation
  // de la politique.
  final ZEditionPresentation mode = forcedMode ??
      policy.resolve(
        ZWindowSizeClass.of(context),
        formWeight: formWeight,
      );
  final effective = presenter ?? ZFormPresenterScope.of(context);

  // ── Collapse de `unlessChrome` ──────────────────────────────────────────
  //
  // Seul cet endroit SAIT si l'appelant a déclaré un chrome. Le presenter, lui,
  // ne voit qu'un `WidgetBuilder` opaque — le laisser trancher l'obligerait à
  // inspecter le contenu par une heuristique de type. On lui transmet donc un
  // mode déjà réduit à `always`/`never`.
  ZSheetFrameSpec? effectiveSheetFrame = sheetFrame;
  if (mode == ZEditionPresentation.sheet) {
    // invariant AD-10 : un jeton `editionSheetFrameMode` INCONNU (chaîne libre, thème
    // sérialisé par une version plus récente) rend `null` ⇒ la référence
    // décide. Jamais d'exception.
    final ZSheetFrameMode declared = sheetFrame?.mode ??
        zSheetFrameModeFromToken(
          ZcrudTheme.of(context).editionSheetFrameMode,
        ) ??
        ZSheetFrameReference.mode;
    if (declared == ZSheetFrameMode.unlessChrome) {
      effectiveSheetFrame = (sheetFrame ?? const ZSheetFrameSpec()).copyWith(
        mode: chrome == null
            ? ZSheetFrameMode.always
            : ZSheetFrameMode.never,
      );
    }
  }

  // ── Voie HISTORIQUE (chrome absent) ─────────────────────────────────────
  //
  // Elle passe désormais par `presentWithDismissControl` quand le presenter
  // l'offre — c'est le SEUL canal qui porte `sheetFrame`, et cette voie est
  // documentée iso-rendu (`ZAdaptivePresenter.present` y délègue déjà avec
  // `allowImplicitDismiss: true`). Un presenter sans cette capacité retombe sur
  // `present` et n'aura ni marge ni cadre (AD-10).
  if (chrome == null) {
    if (effective is ZImplicitDismissControl) {
      return (effective as ZImplicitDismissControl)
          .presentWithDismissControl<T>(
        context,
        builder: builder,
        mode: mode,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        useSafeArea: useSafeArea,
        barrierDismissible: barrierDismissible,
        isDismissible: isDismissible,
        sheetFrame: effectiveSheetFrame,
      );
    }
    return effective.present<T>(
      context,
      builder: builder,
      mode: mode,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      useSafeArea: useSafeArea,
      barrierDismissible: barrierDismissible,
    );
  }

  // ── Voie CHROME (opt-in) ────────────────────────────────────────────────
  Widget wrapped(BuildContext ctx) => ZEditionScaffold(
        mode: mode,
        chrome: chrome,
        body: builder(ctx),
        bodyFit: bodyFit,
      );

  if (effective is ZImplicitDismissControl) {
    return (effective as ZImplicitDismissControl).presentWithDismissControl<T>(
      context,
      builder: wrapped,
      mode: mode,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      useSafeArea: useSafeArea,
      barrierDismissible: barrierDismissible,
      allowImplicitDismiss: !chrome.guardsDiscard,
      isDismissible: isDismissible,
      sheetFrame: effectiveSheetFrame,
    );
  }

  return effective.present<T>(
    context,
    builder: wrapped,
    mode: mode,
    maxWidth: maxWidth,
    maxHeight: maxHeight,
    useSafeArea: useSafeArea,
    barrierDismissible: barrierDismissible,
  );
}
