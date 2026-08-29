// GARDE — la RÉFÉRENCE COULEUR de la palette signature ne dérive pas.
//
// Le défaut visé : une valeur de référence « corrigée parce que plus jolie »,
// ou recopiée de travers. La table ci-dessous est FIGÉE DANS LE TEST, relevée
// à la main sur le code de référence, `fichier:ligne` à l'appui — elle n'est
// JAMAIS relue depuis `z_signature_palette_reference.dart`, sinon la garde
// suivrait la dérive qu'elle prétend interdire.
//
// Elle vérifie aussi ce que la référence PROMET et qu'aucun oeil ne peut
// contrôler : `onGradient` est MESURÉ (contraste >= 3.0 contre la bande
// médiane), et jamais décrété.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

// ── Table FIGÉE, relevée sur le dépôt de référence (branche `main`) ─────────
// Chaque paire est `[début, fin]` en ARGB opaque.

/// `lib/src/utils/functions/forms_utils.dart:57-63` (`_sectionGradientsLight`).
const List<List<int>> _l1 = <List<int>>[
  <int>[0xFF667EEA, 0xFF764BA2],
  <int>[0xFF11998E, 0xFF38EF7D],
  <int>[0xFFF093FB, 0xFFF5576C],
  <int>[0xFF4FACFE, 0xFF00F2FE],
  <int>[0xFFFA709A, 0xFFFEE140],
];

/// `lib/src/presentation/features/folders/pages/folders_page.dart:60-66`
/// (`folderGradientsDark`).
const List<List<int>> _l2 = <List<int>>[
  <int>[0xFF8E2DE2, 0xFF4A00E0],
  <int>[0xFF00B4DB, 0xFF0083B0],
  <int>[0xFFFC466B, 0xFF3F5EFB],
  <int>[0xFF56AB2F, 0xFF134E5E],
  <int>[0xFFF12711, 0xFFF5AF19],
];

/// `lib/src/utils/functions/forms_utils.dart:65-71` (`_sectionGradientsDark`).
const List<List<int>> _l3 = <List<int>>[
  <int>[0xFF1E3A5F, 0xFF2D5A87],
  <int>[0xFF0D4840, 0xFF1A7F64],
  <int>[0xFF5C2A53, 0xFF8B3A62],
  <int>[0xFF1A4B6D, 0xFF0D5C6D],
  <int>[0xFF6B3654, 0xFF8B7355],
];

/// `lib/src/presentation/features/subjects/pages/subjects_page.dart:49-58`
/// (`subjectGradients`) : les 5 premières entrées SONT `_l1`, suivies de 3.
const List<List<int>> _l6extra = <List<int>>[
  <int>[0xFF30CFD0, 0xFF330867],
  <int>[0xFF5EE7DF, 0xFFB490CA],
  <int>[0xFF89F7FE, 0xFF66A6FF],
];

List<int> _stops(ZGradientSpec spec) =>
    spec.gradient.colors.map((Color c) => c.toARGB32()).toList();

String _hex(int argb) =>
    '#${argb.toRadixString(16).toUpperCase().padLeft(8, '0')}';

void _attendu(String nom, List<ZGradientSpec> reel, List<List<int>> fige) {
  expect(reel.length, fige.length, reason: '$nom : cardinal de la palette');
  for (int i = 0; i < fige.length; i++) {
    expect(
      _stops(reel[i]).map(_hex).toList(),
      fige[i].map(_hex).toList(),
      reason: '$nom[$i] : arrêts du dégradé — la référence a DÉRIVÉ de la '
          'valeur relevée sur le code de référence',
    );
  }
}

void main() {
  test('palette signature : 5 dégradés, valeurs exactes du relevé', () {
    _attendu('gradients', ZSignaturePaletteReference.gradients, _l1);
  });

  test('variante sombre saturée : 5 dégradés, valeurs exactes du relevé', () {
    _attendu('deepGradients', ZSignaturePaletteReference.deepGradients, _l2);
  });

  test('variante sombre désaturée : 5 dégradés, valeurs exactes du relevé', () {
    _attendu('mutedGradients', ZSignaturePaletteReference.mutedGradients, _l3);
  });

  test('palette matière : 8 dégradés = les 5 de base PUIS les 3 propres', () {
    _attendu(
      'subjectGradients',
      ZSignaturePaletteReference.subjectGradients,
      <List<int>>[..._l1, ..._l6extra],
    );
  });

  test('🔴 `onGradient` est MESURÉ : contraste ≥ 3.0 sur la bande médiane des '
      '18 dégradés', () {
    final List<ZGradientSpec> tous = <ZGradientSpec>[
      ...ZSignaturePaletteReference.gradients,
      ...ZSignaturePaletteReference.deepGradients,
      ...ZSignaturePaletteReference.mutedGradients,
      ...ZSignaturePaletteReference.subjectGradients,
    ];
    // 5 + 5 + 5 + 8 = 23 specs, dont 18 dégradés DISTINCTS (la palette matière
    // reprend les 5 de base). Le plancher est vérifié sur tous.
    expect(tous.length, 23, reason: 'cardinal total — parsing cassé ?');
    final List<String> sousLePlancher = <String>[];
    for (final ZGradientSpec spec in tous) {
      final List<Color> stops = spec.gradient.colors;
      final Color mid = zSignatureMidBand(stops.first, stops.last);
      final double ratio = zContrastRatio(spec.onGradient, mid);
      if (ratio < kZNonTextMinContrast) {
        sousLePlancher.add(
          '${_hex(stops.first.toARGB32())}→${_hex(stops.last.toARGB32())} '
          'on=${_hex(spec.onGradient.toARGB32())} ratio=${ratio.toStringAsFixed(2)}',
        );
      }
      // Et le premier plan retenu est bien LE MEILLEUR des deux candidats :
      // un `onGradient` figé « au blanc » passerait le plancher sur la moitié
      // des dégradés sans être le bon choix.
      expect(
        spec.onGradient,
        zSignatureForegroundFor(stops),
        reason: 'premier plan DÉCRÉTÉ au lieu de mesuré pour '
            '${_hex(stops.first.toARGB32())}',
      );
    }
    expect(sousLePlancher, isEmpty,
        reason: '🔴 contraste sous le plancher §1.4.11 (3.0:1) : '
            '${sousLePlancher.join(' | ')}');
  });

  test('les deux candidats de premier plan sont réellement DÉPARTAGÉS '
      '(ni tout blanc, ni tout noir)', () {
    final Set<int> plans = <int>{
      for (final ZGradientSpec s in ZSignaturePaletteReference.gradients)
        s.onGradient.toARGB32(),
    };
    // Sur la palette de base, la mesure retient le blanc pour le dégradé
    // violet et le noir pour les quatre autres : une garde qui verrait un seul
    // premier plan attesterait d'un choix décrété.
    expect(plans.length, 2,
        reason: 'un seul premier plan sur 5 dégradés : la mesure ne départage '
            'plus rien');
  });

  test('AD-13 : les dégradés de référence sont DIRECTIONNELS', () {
    for (final ZGradientSpec spec in ZSignaturePaletteReference.gradients) {
      final Gradient g = spec.gradient;
      expect(g, isA<LinearGradient>());
      expect((g as LinearGradient).begin, AlignmentDirectional.centerStart);
      expect(g.end, AlignmentDirectional.centerEnd);
    }
  });

  test('bande médiane : moyenne entière composante par composante', () {
    expect(
      zSignatureMidBand(const Color(0xFF000000), const Color(0xFFFFFFFF))
          .toARGB32(),
      0xFF7F7F7F,
    );
    expect(
      zSignatureMidBand(const Color(0xFF667EEA), const Color(0xFF764BA2))
          .toARGB32(),
      0xFF6E64C6,
    );
  });
}
