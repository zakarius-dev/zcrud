/// **Unique** fichier de référence COULEUR de la famille « palette signature ».
///
/// ## Ce que ce fichier est
///
/// Les valeurs de référence de la palette signature — quatre familles de
/// dégradés — sous forme de littéraux hexadécimaux. C'est le seul endroit du
/// paquet où ces littéraux ont le droit d'exister : la garde de source
/// anti-couleurs (FR-26) l'exempte **nominativement par chemin exact**, et
/// elle seule. Toute recopie de ces valeurs ailleurs est un défaut, et la
/// garde le dit.
///
/// ## Ce que ce fichier n'est pas
///
/// Ce n'est pas un défaut inconditionnel. Les valeurs d'ici ne sont peintes
/// que par le **dernier maillon** d'une chaîne de priorité
/// **paramètre > jeton > référence**, et seulement sous le profil
/// [ZReferenceProfile.legacy], opt-in de l'hôte. Sous
/// [ZReferenceProfile.neutral] — **le défaut** —, ce fichier n'est jamais lu.
///
/// ## `onGradient` est MESURÉ, jamais décrété
///
/// Chaque [ZGradientSpec] porte un premier plan choisi par **mesure de
/// contraste** (WCAG 2.2) entre le blanc et le noir, et non par convention.
/// La surface de mesure est la **bande médiane** du dégradé (moyenne
/// composante à composante des deux arrêts) : c'est la zone où un contenu
/// centré se pose réellement. Le contrat rendu est
/// `zContrastRatio(onGradient, bande médiane) >= kZNonTextMinContrast`
/// (3.0:1) pour **tous** les dégradés de ce fichier — une garde le recalcule.
///
/// Aux **extrémités** d'un dégradé très étalé, le contraste peut descendre
/// sous ce plancher : c'est une limite assumée d'un fond en dégradé, pas un
/// défaut du calcul. Un contenu textuel qui doit tenir le plancher §1.4.3 sur
/// toute la largeur ne se pose pas sur un dégradé étalé.
///
/// ## Direction
///
/// Les arrêts sont posés `AlignmentDirectional.centerStart → centerEnd` :
/// le sens du dégradé suit la direction du texte (invariant AD-13).
library;

import 'package:flutter/widgets.dart';

import 'z_gradient_resolver.dart';
import 'z_readable_tint.dart';
import 'z_reference_profile.dart';

/// Blanc opaque — **candidat** de premier plan, retenu ou écarté par mesure.
const Color _kWhite = Color(0xFFFFFFFF);

/// Noir opaque — **candidat** de premier plan, retenu ou écarté par mesure.
const Color _kBlack = Color(0xFF000000);

/// Bande médiane d'un dégradé à deux arrêts : moyenne entière des composantes.
///
/// C'est la **surface de mesure** documentée du contraste de `onGradient`.
/// Exposée parce qu'un vérificateur externe doit pouvoir recalculer le même
/// chiffre que le fichier — jamais lui faire confiance sur parole.
Color zSignatureMidBand(Color a, Color b) {
  final int x = a.toARGB32();
  final int y = b.toARGB32();
  int mid(int shift) =>
      ((((x >> shift) & 0xFF) + ((y >> shift) & 0xFF)) ~/ 2) << shift;
  return Color(0xFF000000 | mid(16) | mid(8) | mid(0));
}

/// Premier plan MESURÉ pour les arrêts [stops] : celui des deux candidats
/// achromatiques qui contraste le plus avec la bande médiane.
Color zSignatureForegroundFor(List<Color> stops) {
  final Color mid = zSignatureMidBand(stops.first, stops.last);
  return zContrastRatio(_kWhite, mid) >= zContrastRatio(_kBlack, mid)
      ? _kWhite
      : _kBlack;
}

ZGradientSpec _spec(List<Color> stops) => ZGradientSpec(
      gradient: LinearGradient(
        // AD-13 : le sens du dégradé suit la direction du texte.
        begin: AlignmentDirectional.centerStart,
        end: AlignmentDirectional.centerEnd,
        colors: List<Color>.unmodifiable(stops),
      ),
      onGradient: zSignatureForegroundFor(stops),
    );

List<ZGradientSpec> _specs(List<List<Color>> palette) =>
    List<ZGradientSpec>.unmodifiable(palette.map(_spec));

// ── Valeurs de référence ────────────────────────────────────────────────────
// Chaque table cite le fichier:ligne DOMINANT d'où elle est relevée. La valeur
// retenue est celle qui VIT dans le code de référence (recopiée à la main dans
// plusieurs fichiers), pas une valeur déclarée nulle part.

/// Palette signature — 5 dégradés vifs, thème clair.
///
/// Relevé : `lib/src/utils/functions/forms_utils.dart:57-63`
/// (`_sectionGradientsLight`), identique à
/// `lib/src/presentation/features/folders/pages/folders_page.dart:51-57`
/// (`folderGradientsLight`) et aux 5 premières entrées de
/// `lib/src/presentation/features/subjects/pages/subjects_page.dart:49-54`
/// (`subjectGradients`). Ces 5 dégradés sont recopiés à la main dans 18
/// fichiers du code de référence (65 occurrences du seul `667eea`) : c'est la
/// valeur DOMINANTE, donc la référence.
const List<List<Color>> _l1 = <List<Color>>[
  <Color>[Color(0xFF667EEA), Color(0xFF764BA2)], // violet → pourpre
  <Color>[Color(0xFF11998E), Color(0xFF38EF7D)], // sarcelle → vert
  <Color>[Color(0xFFF093FB), Color(0xFFF5576C)], // rose → corail
  <Color>[Color(0xFF4FACFE), Color(0xFF00F2FE)], // bleu → cyan
  <Color>[Color(0xFFFA709A), Color(0xFFFEE140)], // rose → jaune
];

/// Variante SOMBRE et saturée (« deeper, richer tones »).
///
/// Relevé : `folders_page.dart:60-66` (`folderGradientsDark`) — déclaration
/// unique dans le code de référence.
const List<List<Color>> _l2 = <List<Color>>[
  <Color>[Color(0xFF8E2DE2), Color(0xFF4A00E0)], // violet profond
  <Color>[Color(0xFF00B4DB), Color(0xFF0083B0)], // bleu océan
  <Color>[Color(0xFFFC466B), Color(0xFF3F5EFB)], // rose → bleu
  <Color>[Color(0xFF56AB2F), Color(0xFF134E5E)], // vert forêt
  <Color>[Color(0xFFF12711), Color(0xFFF5AF19)], // orange feu
];

/// Variante SOMBRE et désaturée (bandes d'en-tête de section en thème sombre).
///
/// Relevé : `forms_utils.dart:65-71` (`_sectionGradientsDark`) — déclaration
/// unique dans le code de référence.
const List<List<Color>> _l3 = <List<Color>>[
  <Color>[Color(0xFF1E3A5F), Color(0xFF2D5A87)],
  <Color>[Color(0xFF0D4840), Color(0xFF1A7F64)],
  <Color>[Color(0xFF5C2A53), Color(0xFF8B3A62)],
  <Color>[Color(0xFF1A4B6D), Color(0xFF0D5C6D)],
  <Color>[Color(0xFF6B3654), Color(0xFF8B7355)],
];

/// Palette « matière » à 8 entrées = [_l1] + 3 dégradés supplémentaires.
///
/// Relevé : `subjects_page.dart:49-58` (`subjectGradients`) — déclaration
/// unique ; ses 5 premières entrées sont exactement [_l1].
const List<List<Color>> _l6extra = <List<Color>>[
  <Color>[Color(0xFF30CFD0), Color(0xFF330867)],
  <Color>[Color(0xFF5EE7DF), Color(0xFFB490CA)],
  <Color>[Color(0xFF89F7FE), Color(0xFF66A6FF)],
];

/// Les quatre familles de dégradés de la palette signature, avec leur premier
/// plan mesuré.
///
/// Aucune de ces listes n'est peinte sans passer par la chaîne
/// **paramètre > jeton > référence** : voir [ZcrudTheme.signaturePalette] pour
/// remplacer la palette, et [ZReferenceProfile] pour la neutraliser
/// entièrement.
abstract final class ZSignaturePaletteReference {
  /// Palette signature de base : **5** dégradés vifs. C'est la palette lue par
  /// défaut par la clé de dégradé `zcrud.signature.<clé>`.
  static final List<ZGradientSpec> gradients = _specs(_l1);

  /// Variante sombre **saturée** : 5 dégradés, mêmes rôles que [gradients].
  static final List<ZGradientSpec> deepGradients = _specs(_l2);

  /// Variante sombre **désaturée** : 5 dégradés, mêmes rôles que [gradients].
  static final List<ZGradientSpec> mutedGradients = _specs(_l3);

  /// Palette « matière » : **8** dégradés — [gradients] suivis de trois
  /// dégradés supplémentaires.
  static final List<ZGradientSpec> subjectGradients =
      _specs(<List<Color>>[..._l1, ..._l6extra]);
}
