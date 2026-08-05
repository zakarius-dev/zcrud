/// **CR-IFFD-64 — le cœur du lot** : une teinte dérivée d'une couleur
/// **ARBITRAIRE** doit tenir un **plancher de contraste MESURÉ** sur la surface
/// courante, en clair comme en sombre.
///
/// ## Pourquoi un BALAYAGE et pas trois exemples
///
/// Le défaut fermé ici est invisible sur le corpus du socle : les quatre
/// couleurs de type de flashcard forment un **jeu fermé** qui évite la zone
/// jaune-vert *par chance de conception*. Une couleur de dossier est choisie
/// par l'utilisateur — un sélecteur libre inclut trivialement `#FFFF00`. Trois
/// exemples bien choisis auraient donc été verts pour rien. Le balayage
/// parcourt **36 teintes × 5 saturations × 5 clartés** (900 couleurs) plus les
/// cas durs nommés, contre **quatre surfaces** (clair, sombre, blanc pur, noir
/// pur) et **deux planchers**.
///
/// ## Les contre-preuves (la garde mesure-t-elle MA propriété ?)
///
/// Trois, toutes exigées parce qu'une garde de contraste verte peut l'être pour
/// de mauvaises raisons :
/// 1. le balayage **attrape** les couleurs brutes (sinon il testerait un
///    ensemble déjà conforme, et serait vacant) ;
/// 2. `zReadableTypeTint` **SANS** surface échoue sur le même balayage (donc le
///    balayage mesure bien la correction ajoutée, pas le plancher du SDK) ;
/// 3. la correction ne s'applique **PAS** quand elle n'est pas nécessaire (une
///    garantie qui réécrirait tout serait une garantie qui détruit le choix de
///    l'utilisateur).
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_study/zcrud_study.dart';

/// Les quatre couleurs primaires du **jeu fermé** des types de flashcard —
/// celles dont la sortie de `zReadableTypeTint` doit rester **bit-identique**.
const Map<String, Color> _closedSet = <String, Color>{
  'multipleChoice': Color(0xFF667EEA),
  'trueOrFalse': Color(0xFF11998E),
  'openQuestion': Color(0xFF4FACFE),
  'exercise': Color(0xFFF093FB),
};

/// Cas DURS nommés — chacun a un mécanisme de rupture distinct.
const Map<String, Color> _hardCases = <String, Color>{
  // Saturation HSL calculée à 1.000 (artefact de `s = delta/(2-max-min)`).
  'quasi-blanc #FFFFFE': Color(0xFFFFFFFE),
  // delta EXACTEMENT nul ⇒ saturation 0, comportement opposé au précédent.
  'quasi-noir #010101': Color(0xFF010101),
  'gris neutre #808080': Color(0xFF808080),
  // Poids de luminance R+G = 0.928 : le pire cas de la fenêtre HSL.
  'jaune saturé #FFFF00': Color(0xFFFFFF00),
  'vert saturé #00FF00': Color(0xFF00FF00),
  'cyan saturé #00FFFF': Color(0xFF00FFFF),
  'blanc pur': Color(0xFFFFFFFF),
  'noir pur': Color(0xFF000000),
};

/// Le balayage : 36 teintes × 5 saturations × 5 clartés + les cas durs.
List<({String name, Color color})> _sweep() {
  final List<({String name, Color color})> out =
      <({String name, Color color})>[];
  for (int h = 0; h < 360; h += 10) {
    for (final double s in <double>[0, 0.25, 0.5, 0.75, 1]) {
      for (final double l in <double>[0.05, 0.25, 0.5, 0.75, 0.95]) {
        out.add((
          name: 'hsl($h, $s, $l)',
          color: HSLColor.fromAHSL(1, h.toDouble(), s, l).toColor(),
        ));
      }
    }
  }
  for (final MapEntry<String, Color> e in _hardCases.entries) {
    out.add((name: e.key, color: e.value));
  }
  return out;
}

/// Les surfaces de mesure : les deux vraies surfaces de carte Material 3, plus
/// les deux extrêmes (une surface d'hôte peut être n'importe quoi).
Map<String, Color> _surfaces() => <String, Color>{
  'clair (surfaceContainerLow)':
      ThemeData.light(useMaterial3: true).colorScheme.surfaceContainerLow,
  'sombre (surfaceContainerLow)':
      ThemeData.dark(useMaterial3: true).colorScheme.surfaceContainerLow,
  'blanc pur': const Color(0xFFFFFFFF),
  'noir pur': const Color(0xFF000000),
};

String _hex(Color c) {
  String h(double v) =>
      (v * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
  return '#${h(c.r)}${h(c.g)}${h(c.b)}';
}

void main() {
  final List<({String name, Color color})> sweep = _sweep();
  final Map<String, Color> surfaces = _surfaces();

  test('la sonde du balayage est PLAUSIBLE (900 + cas durs)', () {
    expect(
      sweep.length,
      36 * 5 * 5 + _hardCases.length,
      reason: '🔴 balayage tronqué : la garde ne prouverait plus rien',
    );
    expect(surfaces.length, 4);
  });

  group('🔴 CR-IFFD-64 — plancher GARANTI sur le balayage entier', () {
    for (final double floor in <double>[
      kZNonTextMinContrast,
      kZTextMinContrast,
    ]) {
      test('plancher $floor:1 tenu par zReadableTintOn — 4 surfaces', () {
        final List<String> failures = <String>[];
        for (final MapEntry<String, Color> surface in surfaces.entries) {
          for (final ({String name, Color color}) entry in sweep) {
            final Color out = zReadableTintOn(
              entry.color,
              surface: surface.value,
              minContrast: floor,
            );
            final double ratio = zContrastRatio(out, surface.value);
            if (ratio < floor) {
              failures.add(
                '${surface.key} · ${entry.name} ${_hex(entry.color)} → '
                '${_hex(out)} = ${ratio.toStringAsFixed(3)}:1',
              );
            }
          }
        }
        expect(
          failures,
          isEmpty,
          reason:
              '🔴 ${failures.length} teintes sous le plancher $floor:1 '
              '(sur ${sweep.length * surfaces.length} mesures) :\n'
              '${failures.take(12).join('\n')}',
        );
      });
    }

    test(
      '🔴 CONTRE-PREUVE 1 — le balayage ATTRAPE les couleurs BRUTES '
      '(sans quoi il serait vacant)',
      () {
        int caught = 0;
        for (final MapEntry<String, Color> surface in surfaces.entries) {
          for (final ({String name, Color color}) entry in sweep) {
            if (zContrastRatio(entry.color, surface.value) <
                kZNonTextMinContrast) {
              caught++;
            }
          }
        }
        // Sans correction, une part MASSIVE du balayage échoue : le plancher
        // vert ci-dessus n'est donc pas une propriété de l'ensemble testé.
        expect(
          caught,
          greaterThan(sweep.length),
          reason:
              '🔴 sonde cassée : le balayage brut passe déjà — il ne prouve '
              'alors rien de la correction (garde VACANTE).',
        );
      },
    );

    test(
      '🔴 CONTRE-PREUVE 2 — zReadableTypeTint SANS surface ÉCHOUE sur le '
      'même balayage (la fenêtre HSL ne borne pas le contraste)',
      () {
        final Color light = surfaces['clair (surfaceContainerLow)']!;
        final List<String> failures = <String>[];
        for (final ({String name, Color color}) entry in sweep) {
          final Color out = zReadableTypeTint(entry.color, isDark: false);
          if (zContrastRatio(out, light) < kZNonTextMinContrast) {
            failures.add(entry.name);
          }
        }
        expect(
          failures,
          isNotEmpty,
          reason:
              '🔴 sonde cassée : si la fenêtre HSL suffisait, la correction '
              'de CR-IFFD-64 n\'aurait aucune raison d\'exister.',
        );
        // …et les cas durs nommés en font partie, nominativement.
        for (final Color hard in <Color>[
          _hardCases['jaune saturé #FFFF00']!,
          _hardCases['quasi-blanc #FFFFFE']!,
        ]) {
          expect(
            zContrastRatio(
              zReadableTypeTint(hard, isDark: false),
              light,
            ),
            lessThan(kZNonTextMinContrast),
          );
        }
      },
    );

    test(
      '🔴 CONTRE-PREUVE 3 — la correction ne s\'applique PAS quand elle est '
      'inutile : le choix de l\'utilisateur n\'est jamais réécrit sans raison',
      () {
        final Color light = surfaces['blanc pur']!;
        // Un bleu foncé contraste déjà largement sur blanc.
        const Color alreadyFine = Color(0xFF1732AB);
        expect(
          zContrastRatio(alreadyFine, light),
          greaterThan(kZTextMinContrast),
        );
        expect(
          zReadableTintOn(
            alreadyFine,
            surface: light,
            minContrast: kZNonTextMinContrast,
          ),
          alreadyFine,
        );
        // …et un cas SOUS le plancher est, lui, réellement déplacé.
        const Color tooPale = Color(0xFFFFFF00);
        expect(
          zReadableTintOn(
            tooPale,
            surface: light,
            minContrast: kZNonTextMinContrast,
          ),
          isNot(tooPale),
        );
      },
    );
  });

  group('🔴 CR-IFFD-64 — la CHROMATICITÉ survit à la correction', () {
    test(
      'un gris NEUTRE reste gris (la correction HSL en fait un ROUGE)',
      () {
        const Color grey = Color(0xFF808080);
        final Color out = zReadableTintOn(
          grey,
          surface: const Color(0xFF8A8A8A),
          minContrast: kZNonTextMinContrast,
        );
        // Les trois canaux restent égaux à ±1/255 : c'est encore un gris.
        expect(
          ((out.r - out.g).abs() * 255).round(),
          lessThanOrEqualTo(1),
          reason: '🔴 la correction a introduit une teinte : ${_hex(out)}',
        );
        expect(((out.g - out.b).abs() * 255).round(), lessThanOrEqualTo(1));
        // …alors que la voie HSL legacy le vire au rouge (defaut MESURÉ).
        final Color legacy = zReadableTypeTint(grey, isDark: false);
        expect(
          (legacy.r - legacy.b).abs(),
          greaterThan(0.1),
          reason:
              '🔴 sonde cassée : la plancherisation de saturation HSL doit '
              'bien produire un rouge sur une entrée achromatique.',
        );
      },
    );

    test('un quasi-blanc s\'assombrit en GRIS, pas en JAUNE', () {
      const Color nearWhite = Color(0xFFFFFFFE);
      final Color out = zReadableTintOn(
        nearWhite,
        surface: const Color(0xFFFFFFFF),
        minContrast: kZNonTextMinContrast,
      );
      expect(((out.r - out.b).abs() * 255).round(), lessThanOrEqualTo(2));
      // La voie HSL en fait `#E5E500` — un jaune franc.
      final Color legacy = zReadableTypeTint(nearWhite, isDark: false);
      expect((legacy.r - legacy.b).abs(), greaterThan(0.5));
    });
  });

  group(
    '🔴 CR-IFFD-64 — NON-RÉGRESSION du jeu fermé (option (a) : corriger '
    'zReadableTypeTint sans déplacer une seule de ses sorties)',
    () {
      // Valeurs RVB relevées AVANT le lot, couleur par couleur, sur les deux
      // luminosités. Si la correction mordait sur le jeu fermé, ces huit
      // assertions rougiraient — c'est la preuve, pas une affirmation.
      const Map<String, ({int light, int dark})> expected =
          <String, ({int light, int dark})>{
            'multipleChoice': (light: 0xFF1732AB, dark: 0xFF8FA0F0),
            'trueOrFalse': (light: 0xFF0D736A, dark: 0xFF5EEDE2),
            'openQuestion': (light: 0xFF0167C1, dark: 0xFF80C3FE),
            'exercise': (light: 0xFFB307C8, dark: 0xFFEE84FA),
          };

      for (final MapEntry<String, Color> entry in _closedSet.entries) {
        test('${entry.key} — sortie bit-identique, avec ET sans surface', () {
          final Color lightSurface = ThemeData.light(
            useMaterial3: true,
          ).scaffoldBackgroundColor;
          final Color darkSurface = ThemeData.dark(
            useMaterial3: true,
          ).scaffoldBackgroundColor;
          final ({int light, int dark}) want = expected[entry.key]!;

          // Sans surface : comportement legacy STRICT.
          expect(
            zReadableTypeTint(entry.value, isDark: false).toARGB32(),
            want.light,
          );
          expect(
            zReadableTypeTint(entry.value, isDark: true).toARGB32(),
            want.dark,
          );
          // AVEC la surface réelle : la correction ne mord pas — la sortie est
          // la MÊME, bit pour bit.
          expect(
            zReadableTypeTint(
              entry.value,
              isDark: false,
              surface: lightSurface,
            ).toARGB32(),
            want.light,
            reason:
                '🔴 la garantie de contraste a DÉPLACÉ une teinte du jeu '
                'fermé — le rendu de la carte de flashcard a changé.',
          );
          expect(
            zReadableTypeTint(
              entry.value,
              isDark: true,
              surface: darkSurface,
            ).toARGB32(),
            want.dark,
          );
          // …et la raison pour laquelle elle ne mord pas est MESURÉE :
          // ces sorties sont déjà au-dessus du plancher du TEXTE.
          expect(
            zContrastRatio(
              zReadableTypeTint(entry.value, isDark: false),
              lightSurface,
            ),
            greaterThanOrEqualTo(kZTextMinContrast),
          );
          expect(
            zContrastRatio(
              zReadableTypeTint(entry.value, isDark: true),
              darkSurface,
            ),
            greaterThanOrEqualTo(kZTextMinContrast),
          );
        });
      }
    },
  );

  group('🔴 CR-IFFD-64 — les primitives de mesure elles-mêmes', () {
    test('zContrastRatio est symétrique et borné [1, 21]', () {
      const Color a = Color(0xFF000000);
      const Color b = Color(0xFFFFFFFF);
      expect(zContrastRatio(a, b), closeTo(21, 0.01));
      expect(zContrastRatio(b, a), closeTo(21, 0.01));
      expect(zContrastRatio(a, a), closeTo(1, 0.001));
    });

    test('zRelativeLuminance suit les poids WCAG (le vert pèse le plus)', () {
      expect(
        zRelativeLuminance(const Color(0xFF00FF00)),
        closeTo(0.7152, 0.0001),
      );
      expect(
        zRelativeLuminance(const Color(0xFFFF0000)),
        closeTo(0.2126, 0.0001),
      );
      expect(
        zRelativeLuminance(const Color(0xFF0000FF)),
        closeTo(0.0722, 0.0001),
      );
    });

    test('zCompositeOver rend la couleur RÉELLEMENT peinte (opaque)', () {
      const Color black50 = Color(0x80000000);
      final Color out = zCompositeOver(black50, const Color(0xFFFFFFFF));
      expect(out.a, 1);
      expect((out.r * 255).round(), closeTo(128, 1));
      // Un aplat OPAQUE est rendu tel quel.
      expect(
        zCompositeOver(const Color(0xFF123456), const Color(0xFFFFFFFF)),
        const Color(0xFF123456),
      );
    });

    test(
      '🔴 plancher INATTEIGNABLE ⇒ la MEILLEURE extrémité, jamais un échec '
      '(chaîne totale, AD-10)',
      () {
        // Une surface médiane borne le contraste maximal à ≈4.58 : demander 21
        // est impossible. La fonction ne lève pas et rend le meilleur possible.
        const Color mid = Color(0xFF767676);
        final Color out = zReadableTintOn(
          const Color(0xFF777777),
          surface: mid,
          minContrast: 21,
        );
        expect(zContrastRatio(out, mid), greaterThan(4));
      },
    );
  });
}
