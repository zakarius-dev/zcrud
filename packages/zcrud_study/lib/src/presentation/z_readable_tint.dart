/// **CR-IFFD-64** — rendre LISIBLE une teinte **arbitraire** sur la surface
/// courante, avec un **plancher de contraste MESURÉ**, en clair comme en
/// sombre.
///
/// ## Pourquoi ce fichier existe (le défaut MESURÉ qu'il ferme)
///
/// Le socle disposait déjà d'une dérivation de teinte lisible —
/// `zReadableTypeTint` (port du `adjustTagColor` legacy IFFD). Elle borne la
/// **clarté HSL** (`0.25-0.45` en clair, `0.55-0.75` en sombre) et plancherise
/// la saturation à `0.4`. Cela **ne borne PAS le contraste** : à clarté HSL
/// égale, un jaune pèse `0.2126 + 0.7152 = 0.928` de luminance relative WCAG
/// (canaux R+G) contre `0.2126` pour un rouge. Mesuré sur pièces (thème clair
/// `ThemeData.light`, fond `scaffoldBackgroundColor`) :
///
/// | entrée      | sortie `zReadableTypeTint` | contraste | verdict     |
/// |-------------|----------------------------|-----------|-------------|
/// | `#FFFF00`   | `#B3B300`                  | **2.13**  | échec (<3)  |
/// | `#00FF00`   | `#00B300`                  | **2.68**  | échec (<3)  |
/// | `#FFFFFE`   | `#E5E500`                  | **1.28**  | échec net   |
/// | `#667EEA`   | `#1732AB`                  | 9.59      | OK          |
///
/// Le jeu fermé des quatre types de flashcard (violet/vert/cyan/rose) évite la
/// zone jaune-vert **par chance de conception** : son pire score est 5.28. Une
/// **couleur de dossier est choisie par l'utilisateur** — donc arbitraire par
/// construction, et un sélecteur libre inclut trivialement le jaune.
///
/// ## Ce que [zReadableTintOn] fait, et pourquoi PAS en HSL
///
/// La correction n'agit **pas** sur la clarté HSL mais sur la **luminance
/// linéaire** : assombrir = multiplier les canaux linéarisés par `k` (une
/// baisse d'exposition, qui préserve la **chromaticité EXACTEMENT**) ;
/// éclaircir = les mélanger vers le blanc. Deux conséquences mesurées, toutes
/// deux hors de portée d'un ajustement HSL :
///
/// 1. une couleur **achromatique** le reste (`#808080` reste un gris ; la
///    plancherisation de saturation de `zReadableTypeTint` en fait un **rouge**
///    `#7D3636`, parce que HSL attribue la teinte `0` à tout gris) ;
/// 2. un **quasi-blanc** reste quasi-blanc en teinte (`#FFFFFE` s'assombrit en
///    gris, non en **jaune** — HSL calcule une saturation de `1.000` pour
///    `#FFFFFE`, artefact de `s = delta / (2 - max - min)` quand `l → 1`).
///
/// La luminance étant **monotone** en `t`, la recherche dichotomique n'évalue
/// le prédicat que sur des couleurs **déjà quantifiées en 8 bits** : le
/// plancher est donc garanti sur la couleur **réellement retournée**, pas sur
/// un intermédiaire flottant.
///
/// ## Planchers — lequel s'applique où (WCAG 2.2)
///
/// * [kZNonTextMinContrast] (**3.0:1**, §1.4.11 *Non-text Contrast*) : bande
///   d'accent, liseré, pastille, glyphe — tout ce qui est une **surface** ou un
///   **composant** graphique. C'est le plancher de la carte de dossier.
/// * [kZTextMinContrast] (**4.5:1**, §1.4.3 AA *texte normal*) : tout ce qui
///   porte du texte au corps courant (libellé de badge, sous-titre). C'est le
///   plancher de [zReadableTypeTint], qui ne sert qu'à des **premiers plans**.
///
/// ## FR-26
///
/// **AUCUNE couleur littérale ici** : toutes les couleurs sont des ARGUMENTS
/// (la teinte d'entrée, la surface de l'hôte) ou des DÉRIVÉES calculées. Ce
/// fichier n'a donc **pas** besoin de l'exemption nominative de la garde de
/// source anti-couleurs — et ne l'a pas.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Plancher WCAG 2.2 §1.4.11 — **composants d'interface et objets graphiques**
/// (bande d'accent, liseré, glyphe, pastille) : **3.0:1**.
const double kZNonTextMinContrast = 3.0;

/// Plancher WCAG 2.2 §1.4.3 AA — **texte normal** : **4.5:1**.
const double kZTextMinContrast = 4.5;

/// Nombre d'itérations de la dichotomie. `24` place la borne de recherche très
/// en dessous du pas de quantification 8 bits (`1/255`), donc la couleur
/// retournée est celle du dernier point **testé conforme**, jamais un voisin.
const int _kSearchIterations = 24;

/// Linéarise un canal sRGB (transfert WCAG 2.x / sRGB).
double _linearize(double channel) {
  final double c = channel.clamp(0.0, 1.0);
  return c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
}

/// Ré-encode un canal linéaire en sRGB (inverse de [_linearize]).
double _encode(double linear) {
  final double c = linear.clamp(0.0, 1.0);
  return c <= 0.0031308
      ? c * 12.92
      : 1.055 * math.pow(c, 1 / 2.4).toDouble() - 0.055;
}

/// **Luminance relative WCAG 2.x** de [color], mesurée sur sa composante
/// OPAQUE (un alpha est une décision de peinture, pas une propriété de la
/// couleur — cf. [zCompositeOver] pour mesurer un aplat semi-transparent).
double zRelativeLuminance(Color color) =>
    0.2126 * _linearize(color.r) +
    0.7152 * _linearize(color.g) +
    0.0722 * _linearize(color.b);

/// **Rapport de contraste WCAG 2.x** entre deux couleurs OPAQUES, dans
/// `[1.0, 21.0]`. Symétrique.
double zContrastRatio(Color a, Color b) {
  final double la = zRelativeLuminance(a);
  final double lb = zRelativeLuminance(b);
  final double hi = math.max(la, lb);
  final double lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// Compose [foreground] (avec SON alpha) **par-dessus** [background] supposé
/// opaque, et rend la couleur OPAQUE réellement peinte — la seule contre
/// laquelle un contraste a un sens quand un aplat est semi-transparent
/// (ex. le fond `couleur du dossier @ tintAlpha` d'une carte teintée).
Color zCompositeOver(Color foreground, Color background) {
  final double a = foreground.a.clamp(0.0, 1.0);
  return Color.from(
    alpha: 1,
    red: foreground.r * a + background.r * (1 - a),
    green: foreground.g * a + background.g * (1 - a),
    blue: foreground.b * a + background.b * (1 - a),
  );
}

/// Applique à [color] un décalage de luminance `t ∈ [-1, 1]` : `t < 0`
/// assombrit (multiplication linéaire, chromaticité PRÉSERVÉE), `t > 0`
/// éclaircit (mélange linéaire vers le blanc), `t == 0` est l'identité.
/// L'alpha est conservé.
Color _shift(Color color, double t) {
  if (t == 0) return color;
  double apply(double channel) {
    final double linear = _linearize(channel);
    final double shifted =
        t < 0 ? linear * (1 + t) : linear + (1 - linear) * t;
    return _encode(shifted);
  }

  return Color.from(
    alpha: color.a,
    red: apply(color.r),
    green: apply(color.g),
    blue: apply(color.b),
  );
}

/// Teinte **LISIBLE** dérivée de [base], garantie à au moins [minContrast]
/// contre [surface] — pour une couleur d'entrée **ARBITRAIRE** (choisie par
/// l'utilisateur), dans **les deux luminosités**.
///
/// * Si [base] satisfait DÉJÀ le plancher, elle est rendue **inchangée** :
///   le choix de l'utilisateur n'est jamais réécrit sans nécessité.
/// * Sinon, la teinte est déplacée en luminance du **plus petit écart
///   suffisant**, du côté (assombrir / éclaircir) qui coûte le moins — la
///   chromaticité est préservée à l'assombrissement, et une couleur
///   achromatique le reste (contrairement à une correction HSL).
/// * **Chaîne TOTALE (AD-10)** : ne lève jamais, ne rend jamais `null`. Si
///   AUCUNE luminance n'atteint le plancher (possible seulement pour
///   `minContrast > 4.58`, borne théorique d'une surface médiane), la
///   meilleure des deux extrémités est rendue — jamais un échec de rendu.
///
/// L'alpha de [base] est **préservé** ; la mesure porte sur l'opaque.
Color zReadableTintOn(
  Color base, {
  required Color surface,
  double minContrast = kZNonTextMinContrast,
}) {
  final double floor = minContrast.clamp(1.0, 21.0);
  final Color opaqueSurface = surface.withValues(alpha: 1);
  double contrastAt(double t) =>
      zContrastRatio(_shift(base, t).withValues(alpha: 1), opaqueSurface);

  if (contrastAt(0) >= floor) return base;

  // Côté SOMBRE : le plus petit assombrissement suffisant (t le plus proche
  // de 0 dans [-1, 0]). La luminance étant monotone en t, le prédicat est
  // vrai sur [-1, seuil] et faux au-delà — la dichotomie est valide.
  double? darker;
  if (contrastAt(-1) >= floor) {
    double ok = -1;
    double ko = 0;
    for (int i = 0; i < _kSearchIterations; i++) {
      final double mid = (ok + ko) / 2;
      if (contrastAt(mid) >= floor) {
        ok = mid;
      } else {
        ko = mid;
      }
    }
    darker = ok;
  }

  // Côté CLAIR, symétrique.
  double? lighter;
  if (contrastAt(1) >= floor) {
    double ok = 1;
    double ko = 0;
    for (int i = 0; i < _kSearchIterations; i++) {
      final double mid = (ok + ko) / 2;
      if (contrastAt(mid) >= floor) {
        ok = mid;
      } else {
        ko = mid;
      }
    }
    lighter = ok;
  }

  if (darker == null && lighter == null) {
    // Plancher inatteignable : la MEILLEURE extrémité, jamais un échec.
    return contrastAt(-1) >= contrastAt(1)
        ? _shift(base, -1)
        : _shift(base, 1);
  }
  if (lighter == null) return _shift(base, darker!);
  if (darker == null) return _shift(base, lighter);

  // Les deux côtés conviennent : celui dont la LUMINANCE s'écarte le moins de
  // l'originale (mesure homogène entre les deux paramétrages).
  final double reference = zRelativeLuminance(base.withValues(alpha: 1));
  final Color darkCandidate = _shift(base, darker);
  final Color lightCandidate = _shift(base, lighter);
  final double dDark =
      (zRelativeLuminance(darkCandidate.withValues(alpha: 1)) - reference).abs();
  final double dLight =
      (zRelativeLuminance(lightCandidate.withValues(alpha: 1)) - reference)
          .abs();
  return dDark <= dLight ? darkCandidate : lightCandidate;
}
