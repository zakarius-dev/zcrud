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
  ///
  /// ## [isDismissible] — INTERDIRE le renoncement (CR-IFFD-78, ②)
  ///
  /// 🔴 Ne pas confondre avec [allowImplicitDismiss] : **ce sont deux
  /// intentions opposées, et elles se composent sans se contredire.**
  ///
  /// | Réglage | Voie visée | Intention |
  /// |---|---|---|
  /// | `allowImplicitDismiss: false` | **glissement** de la feuille | *garder* le renoncement — la voie qui court-circuite `PopScope` est retirée, celle qui l'honore reste |
  /// | `isDismissible: false` | **barrière** de la feuille | *interdire* le renoncement — la voie est retirée, `PopScope` n'est même plus consulté |
  ///
  /// Conséquences **mesurées** de la combinaison (mode `sheet`) :
  ///
  /// * `allowImplicitDismiss: false` seul (ce que pose un `ZEditionChrome` qui
  ///   garde l'abandon) ⇒ glissement mort, **tap barrière vivant** et passant
  ///   par `Navigator.maybePop`, donc par le garde d'abandon : l'utilisateur
  ///   peut renoncer, on lui demande confirmation. C'est le choix délibéré du
  ///   lot v0.60.0, et il est **inchangé**.
  /// * `isDismissible: false` seul ⇒ glissement vivant (et **non gardé** :
  ///   `BottomSheet.onClosing` appelle `Navigator.pop`), barrière morte. Un
  ///   hôte qui coupe la barrière **sans** couper le glissement se retire la
  ///   voie sûre en laissant la voie non gardée : combinaison déconseillée.
  /// * les deux à `false` ⇒ **aucune** sortie implicite : ni glissement, ni
  ///   barrière. La seule sortie est celle que le contenu offre (bouton
  ///   « Annuler », `Navigator.pop`). C'est la voie « interdire le
  ///   renoncement » demandée par la CR ; elle **n'annule pas** le garde
  ///   d'abandon, elle le rend sans objet sur ces deux voies — mesuré :
  ///   le seam de confirmation n'est appelé sur aucune des deux.
  ///
  /// Défaut `true` ⇒ **comportement d'aujourd'hui strictement conservé**
  /// (barrière fermante), pour tout hôte passif.
  ///
  /// ⚠️ Portée : mode **`sheet`** uniquement. En `dialog`, la barrière se règle
  /// par [barrierDismissible] (un second canal pour la même propriété serait le
  /// motif de divergence que ce dépôt s'interdit) ; en `page`, il n'y a pas de
  /// barrière. Ces deux inerties sont **mesurées** par la matrice de paramètres
  /// (`doc/parameter-matrix-z-adaptive-presenter.md`), pas déclarées à la main.
  Future<T?> presentWithDismissControl<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    required ZEditionPresentation mode,
    double? maxWidth,
    double? maxHeight,
    bool useSafeArea = true,
    bool barrierDismissible = true,
    bool allowImplicitDismiss = true,
    bool isDismissible = true,
    ZSheetFrameSpec? sheetFrame,
  });
}
