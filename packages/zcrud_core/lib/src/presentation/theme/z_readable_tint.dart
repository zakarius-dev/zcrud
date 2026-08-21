/// Rendre LISIBLE une teinte **arbitraire** sur la surface courante, avec un
/// **plancher de contraste MESURÉ**, en clair comme en sombre.
///
/// ## Pourquoi ce fichier vit dans le CŒUR
///
/// Un calculateur de contraste est **unique par construction** : deux copies
/// finissent toujours par diverger. Son domicile est donc `zcrud_core`, d'où
/// **tout** satellite l'atteint sans arête latérale — une arête
/// `zcrud_chat → zcrud_study` violerait l'invariant AD-1 (les satellites
/// dépendent du cœur, jamais l'un de l'autre). `zcrud_study` expose les mêmes
/// symboles **sous les mêmes noms**, par ré-export : un hôte qui les importait
/// de `zcrud_study` n'a rien à changer.
///
/// ## Le défaut MESURÉ que ce fichier ferme
///
/// Le socle disposait déjà d'une dérivation de teinte lisible —
/// `zReadableTypeTint` (`zcrud_study`). Elle borne la **clarté HSL**
/// (`0.25-0.45` en clair, `0.55-0.75` en sombre) et plancherise la saturation
/// à `0.4`. Cela **ne borne PAS le contraste** : à clarté HSL égale, un jaune
/// pèse `0.2126 + 0.7152 = 0.928` de luminance relative WCAG (canaux R+G)
/// contre `0.2126` pour un rouge. Mesuré sur pièces (thème clair
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
/// construction, et un sélecteur libre inclut trivialement le jaune. Même
/// constat côté chat : la teinte de référence de la capacité « carte mentale »
/// (`#FF9800`) passe sous le plancher §1.4.11 dans un thème clair.
///
/// ## 🔴 SUR QUELLE SURFACE UN CHIFFRE DE CONTRASTE EST-IL MESURÉ ?
///
/// **Un rapport de contraste n'existe pas dans l'absolu : il n'existe QUE
/// relativement à une surface.** [zContrastRatio] et [zReadableTintOn] ne
/// devinent aucune surface — [zReadableTintOn] mesure **exclusivement** contre
/// la surface passée en `surface`, ramenée à son opaque
/// (`surface.withValues(alpha: 1)`). Aucun appelant ne doit supposer que le
/// calculateur « sait » sur quoi il peint : c'est lui qui le dit.
///
/// Cette précision n'est pas cosmétique — deux chiffres différents ont circulé
/// pour la **même** couleur, et **tous deux sont exacts** :
///
/// | teinte    | surface de mesure                    | contraste |
/// |-----------|--------------------------------------|-----------|
/// | `#FF9800` | **blanc pur** (`#FFFFFF`)            | **2.155** |
/// | `#FF9800` | `surface` M3 clair (`#FEF7FF`)       | **2.049** |
///
/// Les tables de référence de cette bibliothèque sont exprimées sur **BLANC
/// PUR**, borne haute du cas clair : c'est la
/// convention de lecture. La surface réelle d'un thème clair **n'est jamais
/// blanche** (`ColorScheme.surface` de Material 3 est teintée), donc le
/// contraste réellement obtenu à l'écran est **légèrement plus faible** que le
/// chiffre de référence. C'est sans conséquence sur la garantie rendue : le
/// plancher est vérifié contre la surface **réelle** passée par l'appelant, pas
/// contre la surface de référence.
///
/// Corollaire pour les appelants : passer la surface **réellement peinte** —
/// composée par [zCompositeOver] si elle est semi-transparente — et jamais un
/// blanc supposé.
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
///   plancher de `zReadableTypeTint`, qui ne sert qu'à des **premiers plans**.
///
/// ## FR-26
///
/// **AUCUNE couleur littérale ici** : toutes les couleurs sont des ARGUMENTS
/// (la teinte d'entrée, la surface de l'hôte) ou des DÉRIVÉES calculées. Ce
/// fichier n'a donc **pas** besoin de l'exemption nominative de la garde de
/// source anti-couleurs — et ne l'a pas.
library;

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

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
/// OPAQUE (un alpha est une décision de peinture, pas une propriété de la
/// couleur — cf. [zCompositeOver] pour mesurer un aplat semi-transparent).
double zRelativeLuminance(Color color) =>
    0.2126 * _linearize(color.r) +
    0.7152 * _linearize(color.g) +
    0.0722 * _linearize(color.b);

/// **Rapport de contraste WCAG 2.x** entre les deux couleurs OPAQUES [a] et
/// [b], dans `[1.0, 21.0]`. Symétrique.
///
/// 🔴 Le chiffre rendu **n'a de sens que pour ce couple** : mesurer la même
/// teinte contre le blanc pur ou contre le `surface` teinté d'un thème clair
/// Material 3 ne donne pas le même nombre (cf. la table « sur quelle surface »
/// en tête de bibliothèque — `#FF9800` vaut `2.155` sur `#FFFFFF` et `2.049`
/// sur `#FEF7FF`). Passer la surface **réellement peinte**.
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
/// contre [surface] — pour une couleur d'entrée **ARBITRAIRE** (choisie par
/// l'utilisateur ou déclarée par l'hôte), dans **les deux luminosités**.
///
/// 🔴 **La mesure porte sur [surface], et sur rien d'autre.** [surface] est
/// ramenée à son opaque (`withValues(alpha: 1)`) avant mesure ; si la surface
/// réellement peinte est semi-transparente, la composer d'abord par
/// [zCompositeOver]. Les chiffres de référence de cette bibliothèque sont
/// exprimés sur **blanc pur** — la `surface` d'un thème clair réel est teintée
/// et rend donc un contraste un peu plus faible (cf. la table en tête de
/// bibliothèque). La **garantie**, elle, porte toujours sur la surface passée.
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
  // Historique, à ne pas rejouer : cet algorithme a d'abord vécu dans
  // `zcrud_study`, puis a été RECOPIÉ à l'identique dans `zcrud_chat` (le cœur
  // n'était alors pas touchable). Les deux copies ont commencé à diverger.
  // Une garde de source interdit désormais toute réimplémentation dans
  // `packages/*/lib` — elle se repère au motif des trois coefficients WCAG.
  final double floor = minContrast.clamp(1.0, 21.0);
  final Color opaqueSurface = surface.withValues(alpha: 1);
  double contrastAt(double t) =>
      zContrastRatio(_shift(base, t).withValues(alpha: 1), opaqueSurface);

  if (contrastAt(0) >= floor) return base;

  // Le plus petit déplacement suffisant du côté [edge] (`-1` assombrir, `1`
  // éclaircir), ou `null` si même l'extrémité ne tient pas le plancher. La
  // luminance étant monotone en `t`, le prédicat est vrai sur `[edge, seuil]`
  // et faux au-delà — la dichotomie est valide.
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
