/// Couture neutre de dégradé : seam hôte prioritaire, repli dérivé ou `null`.
library;

import 'package:flutter/material.dart';

import '../../domain/edition/edition_field_type.dart';
import '../zcrud_scope.dart';
import 'z_reference_profile.dart';
import 'z_signature_palette_reference.dart';
import 'z_theme.dart';

/// Préfixe des clés de dégradé **par type de champ** (cf. [zFieldTypeTintKey]).
const String zFieldTypeTintKeyPrefix = 'zcrud.fieldType.';

/// Clé de dégradé sous laquelle la décoration d'un champ interroge le
/// résolveur du scope pour la **teinte par type de champ** :
/// `'zcrud.fieldType.<type.name>'` (`zcrud.fieldType.text`,
/// `zcrud.fieldType.number`, …).
///
/// C'est le contrat côté hôte : un résolveur qui veut teinter les champs par
/// type répond à ces clés-là (et rend `null` pour les autres). Aucun résolveur
/// injecté ⇒ aucune teinte ⇒ décoration strictement inchangée.
String zFieldTypeTintKey(EditionFieldType type) =>
    '$zFieldTypeTintKeyPrefix${type.name}';

/// Préfixe des clés de couleur d'accent **par champ** (cf. [zFieldAccentKey]).
const String zFieldAccentKeyPrefix = 'zcrud.fieldAccent.';

/// Clé de dégradé sous laquelle la **barre d'accent supérieure** d'un champ
/// interroge le résolveur du scope pour une couleur déclarée **champ par
/// champ** : `'zcrud.fieldAccent.<field.name>'`.
///
/// Contrat côté hôte : un résolveur qui veut accentuer un champ **nommé**
/// répond à cette clé-là ; pour les autres champs il rend `null`, et l'accent
/// retombe alors sur la teinte **par type** ([zFieldTypeTintKey]). Aucun
/// résolveur injecté ⇒ aucune couleur ⇒ aucune barre, rendu strictement
/// inchangé.
String zFieldAccentKey(String fieldName) => '$zFieldAccentKeyPrefix$fieldName';

/// Préfixe des clés de **palette signature** (cf. [zSignatureKey]).
const String zSignatureKeyPrefix = 'zcrud.signature.';

/// Clé de dégradé indexant la **palette signature** par une identité libre
/// (titre de section, nom de dossier, matière…) :
/// `'zcrud.signature.<identité>'`.
///
/// Contrairement à [zFieldTypeTintKey] et [zFieldAccentKey] — qui restent
/// **seam-only** (aucun résolveur injecté ⇒ `null`) — cette clé-ci porte une
/// valeur par défaut : sous le profil [ZReferenceProfile.legacy] (le défaut),
/// [zResolveGradient] y répond avec la palette signature. Le seam de l'hôte
/// reste prioritaire, et le profil neutre la ramène à `null`.
String zSignatureKey(String identity) => '$zSignatureKeyPrefix$identity';

/// Comment une identité textuelle se change en **index** dans une palette.
enum ZPaletteIndexStrategy {
  /// `identity.hashCode.abs() % n`.
  ///
  /// ⚠️ `String.hashCode` **n'est pas stable** : sa valeur dépend de
  /// l'implémentation Dart (VM, Wasm, JavaScript) et peut changer d'une
  /// version à l'autre. La même section peut donc recevoir une couleur
  /// différente sur le web et sur mobile, et une mise à jour du SDK peut
  /// rebattre les couleurs. C'est le comportement retenu par défaut pour
  /// **fidélité** au rendu de référence ; [stableFnv] est le choix à faire dès
  /// que la couleur doit être reproductible.
  titleHash,

  /// L'index est fourni par l'appelant (position dans une liste), l'identité
  /// n'est pas consultée. Utile pour colorer des éléments par leur ORDRE.
  ordinal,

  /// FNV-1a 32 bits sur les unités UTF-16 de l'identité, puis `% n`.
  ///
  /// **Stable** : même identité ⇒ même index, sur toute plateforme et toute
  /// version du SDK.
  stableFnv,
}

/// FNV-1a 32 bits sur les unités UTF-16 de [s]. Déterministe et stable.
int _fnv1a32(String s) {
  int hash = 0x811C9DC5;
  for (int i = 0; i < s.length; i++) {
    hash ^= s.codeUnitAt(i);
    // Multiplication par le premier FNV 16777619, tronquée à 32 bits.
    // `toUnsigned(32)` plutôt qu'un masque littéral : la garde de source
    // anti-couleurs lit un `0x` suivi de six à huit chiffres hexadécimaux
    // comme une couleur, et un masque de bits n'en est pas une.
    hash = (hash * 0x01000193).toUnsigned(32);
  }
  return hash;
}

/// Index d'une identité dans une palette de [length] entrées.
///
/// Rend toujours un index valide (`0 <= index < length`) ; rend `0` si
/// [length] est nul ou négatif — la fonction ne lève jamais.
int zPaletteIndexFor(
  String identity,
  int length, {
  ZPaletteIndexStrategy strategy = ZPaletteIndexStrategy.titleHash,
  int ordinal = 0,
}) {
  if (length <= 0) return 0;
  switch (strategy) {
    case ZPaletteIndexStrategy.titleHash:
      return identity.hashCode.abs() % length;
    case ZPaletteIndexStrategy.ordinal:
      return ordinal.abs() % length;
    case ZPaletteIndexStrategy.stableFnv:
      return _fnv1a32(identity) % length;
  }
}

/// Dégradé de la palette signature portant l'identité [identity].
///
/// Fonction **pure** : aucun contexte, aucune lecture de thème. [palette] vaut
/// par défaut la palette de référence à 5 dégradés.
///
/// Rend `null` si la palette est vide — jamais une exception.
ZGradientSpec? zSignatureGradientFor(
  String identity, {
  List<ZGradientSpec>? palette,
  ZPaletteIndexStrategy strategy = ZPaletteIndexStrategy.titleHash,
  int ordinal = 0,
}) {
  final List<ZGradientSpec> p =
      palette ?? ZSignaturePaletteReference.gradients;
  if (p.isEmpty) return null;
  return p[zPaletteIndexFor(
    identity,
    p.length,
    strategy: strategy,
    ordinal: ordinal,
  )];
}

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
/// **Limite explicite : une exception levée PAR LE RESOLVER DE L'HÔTE se
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
  final ZGradientSpec? fromHost = ZcrudScope.maybeOf(
    context,
  )?.gradientResolver?.call(scheme, gradientKey);
  if (fromHost != null) return fromHost;
  // Dernier maillon : les clés `zcrud.signature.*` — et ELLES SEULES — portent
  // une valeur de référence. Les préfixes `fieldType`/`fieldAccent` restent
  // seam-only : un formulaire sans résolveur ne se teinte pas.
  if (!gradientKey.startsWith(zSignatureKeyPrefix)) return null;
  final String identity = gradientKey.substring(zSignatureKeyPrefix.length);
  if (identity.isEmpty) return null;
  final ZcrudTheme theme = ZcrudTheme.of(context);
  // Priorité paramètre > jeton > référence : le jeton d'abord, la référence
  // seulement s'il se tait ET si le profil est `legacy`.
  final List<ZGradientSpec>? palette =
      theme.signaturePalette ??
      zLegacyOrIn<List<ZGradientSpec>>(
        theme.referenceProfile,
        ZSignaturePaletteReference.gradients,
      );
  if (palette == null) return null;
  return zSignatureGradientFor(
    identity,
    palette: palette,
    strategy:
        theme.signaturePaletteIndexStrategy ?? ZPaletteIndexStrategy.titleHash,
  );
}
