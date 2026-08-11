/// Couture neutre de dégradé : seam hôte prioritaire, repli dérivé ou `null`.
library;

import 'package:flutter/material.dart';

import '../zcrud_scope.dart';

/// Dégradé et premier plan associé : l'hôte fournit les deux car un [Gradient]
/// seul ne permet pas de déduire un contraste fiable.
@immutable
class ZGradientSpec {
  /// Crée une spécification immuable de dégradé contrastée.
  const ZGradientSpec({required this.gradient, required this.onGradient});

  /// Fond en dégradé.
  final Gradient gradient;

  /// Premier plan choisi par l'hôte pour rester lisible sur [gradient].
  final Color onGradient;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZGradientSpec &&
          gradient == other.gradient &&
          onGradient == other.onGradient;

  @override
  int get hashCode => Object.hash(gradient, onGradient);
}

/// Résolveur injecté par l'hôte. Le conserver `const` ou mémoïsé hors de
/// `build`, car [ZcrudScope.updateShouldNotify] compare son identité.
typedef ZGradientResolver =
    ZGradientSpec? Function(ColorScheme scheme, String gradientKey);

/// Résolveur dérivé du [ColorScheme], **OPT-IN** : il n'est JAMAIS appliqué
/// automatiquement — l'hôte le branche explicitement s'il en veut un.
///
/// ```dart
/// ZcrudScope(gradientResolver: zDerivedGradientResolver, child: …)
/// ```
///
/// **Pourquoi opt-in et non un repli automatique de [zResolveGradient]** : ce
/// repli rend un dégradé pour **toute** clé non vide. Placé dans la chaîne,
/// il romprait deux garanties :
/// * sans aucun `ZcrudScope`, `zResolveGradient(c, 'dossier-42')` rendrait un
///   dégradé au lieu de `null` — l'invariant « pas d'injection ⇒ accent uni
///   inchangé » serait violé dès le premier consommateur ;
/// * un hôte dont le résolveur rend `null` pour signifier « accent uni pour
///   cette clé » verrait sa décision **écrasée** par le repli — son `null`
///   deviendrait inexprimable.
/// Le rendu par défaut identique au pixel près est l'invariant non
/// négociable : il l'emporte, et le repli reste explicite (jamais implicite).
///
/// Une clé vide rend `null` (aucune identité ⇒ aucun dégradé).
ZGradientSpec? zDerivedGradientResolver(
  ColorScheme scheme,
  String gradientKey,
) {
  if (gradientKey.isEmpty) return null;
  // Le choix des RÔLES est ce qui décide qu'un dégradé se voie. Dans un
  // `ColorScheme.fromSeed`, `primaryContainer` et `secondaryContainer` sont
  // trop voisins et le « dégradé » se lit comme un aplat ; `primaryContainer`
  // → `tertiaryContainer` porte un écart réel de teinte, retenu ici.
  final HSLColor start = HSLColor.fromColor(scheme.primaryContainer);
  final HSLColor end = HSLColor.fromColor(scheme.tertiaryContainer);
  return ZGradientSpec(
    gradient: LinearGradient(
      // AD-13 : alignements DIRECTIONNELS — jamais `centerLeft`/`centerRight`,
      // qui figeraient le sens du dégradé en RTL.
      begin: AlignmentDirectional.centerStart,
      end: AlignmentDirectional.centerEnd,
      colors: <Color>[start.toColor(), end.toColor()],
    ),
    onGradient: scheme.onPrimaryContainer,
  );
}

/// Chaîne **totale** : seam hôte → `null`. Aucune clé n'est rejetée, aucun
/// déréférencement nul n'est possible — scope absent, resolver absent, clé vide
/// ou inconnue rendent tous `null` sans lever.
///
/// `null` est une valeur FONCTIONNELLE : « aucun dégradé, garde l'accent uni ».
/// C'est ce qui garantit qu'un consommateur non configuré rend exactement
/// comme un consommateur qui n'a jamais injecté de dégradé. Le repli dérivé
/// n'est PAS dans cette chaîne : voir [zDerivedGradientResolver] pour
/// l'arbitrage qui l'en exclut.
///
/// ⚠️ **Limite explicite : une exception levée PAR LE RESOLVER DE L'HÔTE se
/// propage** — elle n'est pas avalée. C'est délibéré, et c'est le comportement
/// de [zResolveColorKey], la couture jumelle, qui appelle elle aussi le seam
/// hôte sans protection. Deux raisons :
/// * un resolver qui lève est un **défaut de l'hôte** ; l'étouffer le rendrait
///   indébogable (l'hôte verrait « pas de dégradé » sans jamais savoir pourquoi) ;
/// * protéger ce seam-ci seulement ferait **diverger** les garanties de deux
///   coutures voisines — un piège pire que le défaut qu'on prétend couvrir.
/// La totalité promise porte donc sur la LOGIQUE DE LA CHAÎNE, pas sur le code
/// arbitraire que l'hôte y branche.
ZGradientSpec? zResolveGradient(BuildContext context, String gradientKey) {
  final ColorScheme scheme = Theme.of(context).colorScheme;
  return ZcrudScope.maybeOf(context)?.gradientResolver?.call(
    scheme,
    gradientKey,
  );
}
