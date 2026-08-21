/// Rendre LISIBLE une teinte **arbitraire** sur la surface courante, avec un
/// **plancher de contraste MESURÉ** — la version `zcrud_chat` du patron du
/// dépôt.
///
/// ## Pourquoi ce fichier existe ICI, et pas une dépendance
///
/// Le patron canonique du dépôt est `zReadableTintOn`
/// (`zcrud_study/lib/src/presentation/z_readable_tint.dart`). `zcrud_study`
/// est un **satellite frère** : une arête `zcrud_chat -> zcrud_study` serait
/// une violation directe de l'invariant AD-1 (les satellites ne se
/// dépendent pas entre eux), et `zcrud_chat` ne prend aucune dépendance
/// nouvelle. Le seul emplacement qui supprimerait la duplication est
/// `zcrud_core` — hors du périmètre de ce lot, et écrit en parallèle par un
/// autre workstream. L'algorithme est donc porté ici, à l'identique, avec la
/// même garantie mesurée ; le remonter au cœur reste le geste à faire quand
/// les deux paquets pourront être touchés ensemble.
///
/// ## Le défaut MESURÉ que ce fichier ferme (CR-IFFD-84, défaut ④)
///
/// La teinte de référence de la capacité « carte mentale » (`#FF9800`)
/// mesure **2.05:1** sur une surface blanche : sous le plancher WCAG 2.2
/// §1.4.11 (3.0:1) d'un composant graphique. Peindre la teinte **brute**
/// d'un hôte reproduirait exactement ce défaut — y compris quand c'est
/// l'hôte lui-même qui déclare la couleur, ce qui est le cas nominal du
/// mécanisme d'artefacts.
///
/// ## Pourquoi la correction agit sur la LUMINANCE et pas sur la clarté HSL
///
/// Assombrir = multiplier les canaux **linéarisés** (une baisse d'exposition,
/// qui préserve la chromaticité exactement) ; éclaircir = mélanger vers le
/// blanc en linéaire. Une couleur achromatique le reste, et un quasi-blanc ne
/// vire pas au jaune — deux artefacts qu'une correction HSL produit.
///
/// La luminance étant **monotone** en `t`, la dichotomie n'évalue le prédicat
/// que sur des couleurs déjà quantifiées en 8 bits : le plancher est garanti
/// sur la couleur **réellement retournée**.
///
/// ## FR-26
///
/// **Aucune couleur littérale** : toutes les couleurs sont des arguments ou
/// des dérivées calculées. Ce fichier n'a donc pas besoin de l'exemption
/// nominative de la garde anti-couleurs — et ne l'a pas.
library;

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Plancher WCAG 2.2 §1.4.11 — **composants et objets graphiques** (glyphe,
/// pastille, liseré) : **3.0:1**.
const double kZChatNonTextMinContrast = 3.0;

/// Plancher WCAG 2.2 §1.4.3 AA — **texte normal** : **4.5:1**.
const double kZChatTextMinContrast = 4.5;

/// Itérations de la dichotomie. `24` place la borne de recherche très en
/// dessous du pas de quantification 8 bits (`1/255`).
const int _kSearchIterations = 24;

/// Linéarise un canal sRGB (transfert WCAG 2.x / sRGB).
double _linearize(double channel) {
  final double c = channel.clamp(0.0, 1.0);
  return c <= 0.03928
      ? c / 12.92
      : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
}

/// Ré-encode un canal linéaire en sRGB (inverse de [_linearize]).
double _encode(double linear) {
  final double c = linear.clamp(0.0, 1.0);
  return c <= 0.0031308
      ? c * 12.92
      : 1.055 * math.pow(c, 1 / 2.4).toDouble() - 0.055;
}

/// **Luminance relative WCAG 2.x** de [color], mesurée sur sa composante
/// OPAQUE.
double zChatRelativeLuminance(Color color) =>
    0.2126 * _linearize(color.r) +
    0.7152 * _linearize(color.g) +
    0.0722 * _linearize(color.b);

/// **Rapport de contraste WCAG 2.x** entre deux couleurs OPAQUES, dans
/// `[1.0, 21.0]`. Symétrique.
double zChatContrastRatio(Color a, Color b) {
  final double la = zChatRelativeLuminance(a);
  final double lb = zChatRelativeLuminance(b);
  final double hi = math.max(la, lb);
  final double lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// Applique à [color] un décalage de luminance `t ∈ [-1, 1]` : `t < 0`
/// assombrit (chromaticité PRÉSERVÉE), `t > 0` éclaircit, `t == 0` est
/// l'identité. L'alpha est conservé.
Color _shift(Color color, double t) {
  if (t == 0) return color;
  double apply(double channel) {
    final double linear = _linearize(channel);
    final double shifted = t < 0 ? linear * (1 + t) : linear + (1 - linear) * t;
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
/// contre [surface].
///
/// * [base] qui satisfait DÉJÀ le plancher est rendue **inchangée** : la
///   couleur déclarée par l'hôte n'est jamais réécrite sans nécessité.
/// * Sinon, la teinte est déplacée en luminance du plus petit écart
///   suffisant, du côté qui coûte le moins.
/// * **Chaîne TOTALE (invariant AD-10)** : ne lève jamais, ne rend jamais
///   `null` ; si aucune luminance n'atteint le plancher, la meilleure des
///   deux extrémités est rendue.
Color zChatReadableTintOn(
  Color base, {
  required Color surface,
  double minContrast = kZChatNonTextMinContrast,
}) {
  final double floor = minContrast.clamp(1.0, 21.0);
  final Color opaqueSurface = surface.withValues(alpha: 1);
  double contrastAt(double t) =>
      zChatContrastRatio(_shift(base, t).withValues(alpha: 1), opaqueSurface);

  if (contrastAt(0) >= floor) return base;

  double? search(double edge) {
    if (contrastAt(edge) < floor) return null;
    double ok = edge;
    double ko = 0;
    for (int i = 0; i < _kSearchIterations; i++) {
      final double mid = (ok + ko) / 2;
      if (contrastAt(mid) >= floor) {
        ok = mid;
      } else {
        ko = mid;
      }
    }
    return ok;
  }

  final double? darker = search(-1);
  final double? lighter = search(1);

  if (darker == null && lighter == null) {
    // Plancher inatteignable : la MEILLEURE extrémité, jamais un échec.
    return contrastAt(-1) >= contrastAt(1) ? _shift(base, -1) : _shift(base, 1);
  }
  if (lighter == null) return _shift(base, darker!);
  if (darker == null) return _shift(base, lighter);

  // Les deux côtés conviennent : celui dont la LUMINANCE s'écarte le moins.
  final double reference = zChatRelativeLuminance(base.withValues(alpha: 1));
  final Color darkCandidate = _shift(base, darker);
  final Color lightCandidate = _shift(base, lighter);
  final double dDark =
      (zChatRelativeLuminance(darkCandidate.withValues(alpha: 1)) - reference)
          .abs();
  final double dLight =
      (zChatRelativeLuminance(lightCandidate.withValues(alpha: 1)) - reference)
          .abs();
  return dDark <= dLight ? darkCandidate : lightCandidate;
}
