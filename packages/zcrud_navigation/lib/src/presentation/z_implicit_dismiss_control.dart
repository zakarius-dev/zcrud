/// Port **additionnel** de contrôle des fermetures IMPLICITES (CR
/// chrome-presentation-aware) — [ZImplicitDismissControl].
///
/// ## Le défaut mesuré (Flutter 3.44.4, 2026-08-09)
///
/// `ZDiscardGuard` (`zcrud_core`) est un `PopScope`. Or **`PopScope` n'est
/// consulté que par `Navigator.maybePop`** (bouton retour, geste système, tap
/// sur la barrière modale), **jamais par `Navigator.pop`**. Et
/// `showModalBottomSheet` ferme la feuille **par glissement** via
/// `BottomSheet.onClosing → Navigator.pop(context)`
/// (`packages/flutter/lib/src/material/bottom_sheet.dart`).
///
/// Mesuré en test widget, feuille *dirty* + `ZDiscardGuard` monté :
///
/// | Voie de fermeture      | Seam de confirmation appelé ? | Feuille fermée ? |
/// |------------------------|-------------------------------|------------------|
/// | tap sur la barrière    | **oui** (`maybePop`)          | non (refusé)     |
/// | **glissement**         | **NON**                       | **OUI**          |
///
/// ⇒ **la saisie est perdue sans confirmation** sur la voie du glissement.
/// Aucun widget placé *dans* la feuille ne peut intercepter cette voie : la
/// décision appartient à la **route**, donc au **presenter**.
///
/// ## Pourquoi un port SÉPARÉ (AD-4, et pas une signature élargie)
///
/// Ajouter un paramètre nommé à `ZFormPresenter.present` **casserait** toute
/// implémentation externe : au moment de l'introduction de ce port,
/// `ZGetFormPresenter` (`zcrud_get`) faisait `implements ZFormPresenter` et
/// n'aurait plus compilé. Le contrôle est donc offert par une **interface
/// additionnelle et optionnelle** : `presentEdition` la teste
/// (`is ZImplicitDismissControl`) et retombe silencieusement sur
/// `ZFormPresenter.present` quand le presenter ne l'implémente pas (AD-10 :
/// repli, jamais d'exception).
///
/// ✅ **État réel au 2026-08-09** (mesuré sur disque, pas supposé) :
/// `packages/zcrud_get/lib/src/presentation/z_get_form_presenter.dart` déclare
/// `class ZGetFormPresenter implements ZFormPresenter, ZImplicitDismissControl`
/// — le présentateur GetX a **adopté** ce port. Le repli AD-10 ci-dessus reste
/// la voie de tout presenter tiers qui ne l'implémenterait pas ; il n'est plus
/// la voie de `zcrud_get`.
library;

import 'package:flutter/widgets.dart';

import '../domain/z_edition_presentation.dart';
import 'z_sheet_frame.dart';

/// Capacité **optionnelle** d'un `ZFormPresenter` : neutraliser les voies de
/// fermeture qui **court-circuitent `PopScope`**.
///
/// Un presenter qui ne l'implémente pas reste parfaitement valide — il
/// n'offrira simplement pas la garantie « aucune saisie perdue par
/// glissement ».
abstract interface class ZImplicitDismissControl {
  /// Comme `ZFormPresenter.present`, plus [allowImplicitDismiss].
  ///
  /// * `allowImplicitDismiss: true` (défaut) ⇒ comportement **strictement
  ///   identique** à `present` : c'est la voie que `present` lui-même emprunte.
  /// * `allowImplicitDismiss: false` ⇒ les voies de fermeture **non gardées**
  ///   sont désactivées. Concrètement, en mode `sheet` : `enableDrag: false`.
  ///   Le tap sur la barrière **reste** actif (il passe par `maybePop`, donc
  ///   par `PopScope`) — le neutraliser aussi retirerait une voie de sortie
  ///   parfaitement sûre, ce qui serait une régression d'ergonomie.
  ///
  /// [sheetFrame] (CR-IFFD-SHEET, 2026-08-09) surcharge **par paramètre** la
  /// feuille contrainte et encadrée (cf. `z_sheet_frame.dart`). `null` ⇒ le
  /// maillon suivant décide (jetons `ZcrudTheme.editionSheet*`, puis
  /// `ZSheetFrameReference`) — **ce n'est donc PAS « pas de cadre »** : le
  /// défaut du socle encadre. Pour ne pas encadrer, il faut le **dire** :
  /// `sheetFrame: ZSheetFrameSpec(mode: ZSheetFrameMode.never)`.
  ///
  /// ⚠️ **Changement de signature** de ce port (introduit la veille, aucun
  /// implémenteur hors `ZAdaptivePresenter` — grep négatif au rapport de CR).
  /// Paramètre **nommé et optionnel** : aucun appelant existant ne casse ; une
  /// implémentation externe devrait ajouter le paramètre.
  Future<T?> presentWithDismissControl<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    required ZEditionPresentation mode,
    double? maxWidth,
    double? maxHeight,
    bool useSafeArea = true,
    bool barrierDismissible = true,
    bool allowImplicitDismiss = true,
    ZSheetFrameSpec? sheetFrame,
  });
}
