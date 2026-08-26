/// Réservation de la place du **clavier logiciel** sous une feuille modale.
///
/// Une bottom-sheet ouverte avec `isScrollControlled: true` est posée par le
/// SDK **au bas de l'écran entier**, encarts système compris : le clavier se
/// pose donc PAR-DESSUS ses derniers champs. Prendre le contrôle du
/// défilement, c'est prendre en charge `MediaQuery.viewInsets` — le SDK ne le
/// fait plus pour vous.
library;

import 'package:flutter/widgets.dart';

/// Enveloppe le contenu d'une feuille modale et **retranche l'encart bas**
/// (`MediaQuery.viewInsets.bottom`, la hauteur du clavier) de la place qui lui
/// est offerte, de sorte que la zone utile reste **au-dessus du clavier**.
///
/// ## Contrat
///
/// * **Encart nul ⇒ rendu inchangé.** Le rembourrage vaut alors
///   `EdgeInsets.zero` : aucune géométrie ne bouge d'un pixel.
/// * **Le nœud est INCONDITIONNEL.** Il reste dans l'arbre même à encart nul,
///   et c'est une garantie, pas un oubli : un rembourrage qui apparaîtrait à
///   la montée du clavier changerait la *forme* de l'arbre au moment précis
///   où l'utilisateur saisit — l'élément du corps serait reconstruit depuis
///   zéro, son `State` recréé et **la saisie en cours perdue**.
/// * **La lecture est réactive.** Les encarts changent *pendant* que la
///   feuille est ouverte ; seul ce widget est abonné, si bien que la montée du
///   clavier ne reconstruit **que lui** — le corps de la feuille, dont
///   l'instance ne change pas, n'est pas reconstruit.
///
/// ## Portée
///
/// Réservé à la feuille modale. Une `Dialog` retranche déjà les encarts
/// elle-même, et une route pleine page les confie au `Scaffold` : les envelopper
/// **doublerait** la réservation.
///
/// ```dart
/// showModalBottomSheet<void>(
///   context: context,
///   isScrollControlled: true,
///   builder: (BuildContext ctx) => ZSheetKeyboardInset(child: builder(ctx)),
/// );
/// ```
class ZSheetKeyboardInset extends StatelessWidget {
  /// Enveloppe [child], le contenu de la feuille.
  const ZSheetKeyboardInset({required this.child, super.key});

  /// Contenu de la feuille, rendu tel quel sous le rembourrage.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // `viewInsetsOf` (et non `MediaQuery.of`) : l'abonnement porte sur les
    // SEULS encarts, pas sur la taille de l'écran ni l'orientation. Mesuré :
    // sur la montée du clavier, le `build` du corps de la feuille n'est PAS
    // rejoué (1 build avant, 1 build après), parce que l'instance de widget
    // passée en `child` est inchangée.
    //
    // `bottom` seul : `EdgeInsets.only(bottom:)` n'est pas un motif
    // directionnel (aucune variante RTL n'existe pour un encart vertical).
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: child,
    );
  }
}
