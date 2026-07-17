/// Golden DISCRIMINANT du rendu LaTeX concret (su-11, AC4).
///
/// Un rendu visuel se prouve par des propriétés **PORTABLES et FALSIFIABLES** de
/// l'image PNG produite par `ZFlutterMathLatexRasterizer` (seule impl avec
/// `flutter_math_fork` + rendu hors écran) — JAMAIS par une égalité octet-exacte
/// d'un PNG police-rasterisé.
///
/// 🔴 **Pourquoi PAS d'octet-exact** (su-11 D4, prouvé sur disque) : la MÊME
/// formule rend des dimensions/octets DIFFÉRENTS selon le chargement des polices
/// KaTeX (ex. `x^2+1` : 307×82 police chargée vs 252×50 capture committée). Une
/// assertion `equals(goldenBytes)` ROUGIT alors sur un rendu CORRECT en CI /
/// autre toolchain → gate non portable. `matchesGoldenFile` est par ailleurs un
/// NO-OP headless (rien à comparer). On prouve donc, de façon portable :
///  (a) le PNG DÉCODE, dimensions dans une PLAGE plausible, ratio d'aspect sain ;
///  (b) l'image est **non-uniforme** (vrais glyphes rendus, pas une image vide) ;
///  (c) le rendu SUIT la `fontSize` de production : un rendu à la fontSize par
///      défaut ÉGALE (en dimensions) une référence à la même taille et DIFFÈRE
///      d'une référence à une autre taille → si quelqu'un change la fontSize de
///      production, ce test ROUGIT (falsifiable), sans octet committé ;
///  (d) deux formules DISTINCTES → octets DISTINCTS (le rendu suit la source) ;
///  (e) rendu SENSIBLE à la couleur (altéré ⇒ octets ≠ du canonique) ;
///  (f) formule vide / invalide → `null` (repli texte, AD-10/AC9).
@TestOn('vm')
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_export_ui/zcrud_export_ui.dart';

Future<ui.Image> _decode(Uint8List bytes) => decodeImageFromList(bytes);

/// Dimensions (largeur, hauteur) d'un PNG décodé.
Future<(int, int)> _dims(Uint8List png) async {
  final img = await _decode(png);
  final d = (img.width, img.height);
  img.dispose();
  return d;
}

/// L'image est-elle **non-uniforme** (au moins deux octets RGBA distincts) ? Un
/// rendu vide/blanc/transparent uniforme donnerait `false` → discriminant contre
/// un rendu dégénéré (SizedBox.shrink rasterisé, canevas vide).
Future<bool> _isNonUniform(Uint8List png) async {
  final img = await _decode(png);
  final data = await img.toByteData();
  img.dispose();
  final bytes = data!.buffer.asUint8List();
  if (bytes.isEmpty) return false;
  final first = bytes.first;
  for (final b in bytes) {
    if (b != first) return true;
  }
  return false;
}

void main() {
  // Établit le binding de TEST AVANT tout appel au rasteriseur : ce dernier
  // appelle `WidgetsFlutterBinding.ensureInitialized()` (idiome runtime), qui
  // retourne alors le binding de test déjà en place (aucune double init).
  TestWidgetsFlutterBinding.ensureInitialized();

  const rasterizer = ZFlutterMathLatexRasterizer();

  group('AC4 — rendu concret PORTABLE & FALSIFIABLE (≥ 2 formules)', () {
    for (final (name, latex) in <(String, String)>[
      ('quadratique', 'x^2 + 1'),
      ('fraction', r'\frac{a}{b}'),
    ]) {
      test('formule $name → PNG réel (décode, dimensions, non-uniforme)',
          () async {
        final bytes = await rasterizer.rasterize(latex);
        expect(bytes, isNotNull, reason: 'une formule valide doit produire un PNG');
        expect(bytes!.length, greaterThan(8), reason: 'PNG non vide');

        final (w, h) = await _dims(bytes);
        // Plage PLAUSIBLE (portable) : ni dégénéré (0/1 px), ni aberrant.
        expect(w, inInclusiveRange(8, 4000), reason: 'largeur hors plage : $w');
        expect(h, inInclusiveRange(8, 4000), reason: 'hauteur hors plage : $h');
        // Ratio d'aspect sain (pas un trait 1×N).
        expect(w / h, inInclusiveRange(0.1, 40.0),
            reason: 'ratio d\'aspect aberrant : ${w / h}');

        // 🔴 non-uniforme : de VRAIS glyphes ont été peints (pas un canevas vide).
        expect(await _isNonUniform(bytes), isTrue,
            reason: '🔴 image uniforme : aucun glyphe rendu (rendu dégénéré)');
      });
    }

    test('🔴 le rendu SUIT la fontSize de PRODUCTION (falsifiable, portable)',
        () async {
      // Toutes les images sont rendues DANS LE MÊME environnement → comparaison
      // RELATIVE de dimensions (aucun octet committé, donc portable). La fontSize
      // de production est 20.0 (contrat) : le rendu de `rasterizer` ÉGALE (en
      // dimensions) une référence à 20.0 et DIFFÈRE d'une référence à 28.0. Si un
      // dev change la fontSize de production, les DEUX assertions s'inversent.
      const ref20 = ZFlutterMathLatexRasterizer(fontSize: 20.0);
      const ref28 = ZFlutterMathLatexRasterizer(fontSize: 28.0);
      final prod = (await rasterizer.rasterize('x^2 + 1'))!;
      final r20 = (await ref20.rasterize('x^2 + 1'))!;
      final r28 = (await ref28.rasterize('x^2 + 1'))!;

      final dProd = await _dims(prod);
      final d20 = await _dims(r20);
      final d28 = await _dims(r28);

      expect(dProd, equals(d20),
          reason: '🔴 la fontSize de production n\'est plus 20.0 (rendu ≠ ref20)');
      expect(dProd, isNot(equals(d28)),
          reason: '🔴 le rendu N\'EST PAS sensible à la fontSize — golden vacant '
              '(20.0 et 28.0 rendent la même taille)');
    });
  });

  group('AC4(a) — byte-diff : deux formules distinctes → octets distincts', () {
    test('quadratique ≠ fraction (le rendu SUIT la source)', () async {
      final a = await rasterizer.rasterize('x^2 + 1');
      final b = await rasterizer.rasterize(r'\frac{a}{b}');
      expect(a, isNotNull);
      expect(b, isNotNull);
      expect(a, isNot(equals(b)),
          reason: 'des formules différentes ne peuvent pas rendre les mêmes octets');
    });
  });

  group('AC4(b) — le golden SAIT rougir : le rendu est sensible (falsifiable)',
      () {
    test('altérer la couleur du rendu change les octets ⇒ le golden régresserait',
        () async {
      final canonical = await rasterizer.rasterize('x^2 + 1');
      // Rendu ALTÉRÉ (couleur différente) = mutant : s'il produisait les mêmes
      // octets, le golden serait infalsifiable.
      const altered = ZFlutterMathLatexRasterizer(textColor: Color(0xFFFF0000));
      final mutated = await altered.rasterize('x^2 + 1');
      expect(canonical, isNotNull);
      expect(mutated, isNotNull);
      expect(mutated, isNot(equals(canonical)),
          reason: '🔴 un rendu altéré DOIT diverger — sinon le golden ne '
              'rougirait jamais et ne prouverait rien');
    });
  });

  group('AC9 — repli défensif (AD-10) : jamais de bytes trompeurs', () {
    test('formule VIDE → null', () async {
      expect(await rasterizer.rasterize(''), isNull);
      expect(await rasterizer.rasterize('   '), isNull);
    });

    test('LaTeX INVALIDE → null (repli texte brut côté gabarit)', () async {
      // Une commande inexistante / accolades non fermées : onErrorFallback → null.
      final r = await rasterizer.rasterize(r'\frac{a}{');
      expect(r, isNull,
          reason: 'un LaTeX invalide ne doit pas produire un PNG trompeur');
    });
  });
}
