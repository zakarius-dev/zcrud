/// 🔴 NON-RUPTURE — les symboles de teinte lisible restent atteignables depuis
/// `zcrud_study`, **sous les mêmes noms**.
///
/// L'implémentation a remonté dans `zcrud_core` pour que `zcrud_chat` cesse
/// d'en porter une copie sans acquérir d'arête vers ce paquet (AD-1). Mais
/// `zcrud_study` **exportait publiquement** `zReadableTintOn` & co
/// (`lib/zcrud_study.dart`) : tout hôte qui les importait d'ici casserait si le
/// ré-export disparaissait. Cette garde est là pour rougir dans ce cas.
///
/// ## Pourquoi une assertion, et pas seulement un usage
///
/// Un simple appel à `zReadableTintOn` dans un test aurait échoué à la
/// COMPILATION si le ré-export tombait — un rouge de compilation n'est pas un
/// constat lisible, et la discipline R3 ne le compte pas. La garde asserte
/// donc (a) l'**identité de fonction** entre le symbole vu de `zcrud_study` et
/// celui du cœur — ce qui prouve en outre qu'aucune COPIE n'est revenue — et
/// (b) la présence textuelle du ré-export dans le barrel.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart' as core;
import 'package:zcrud_study/zcrud_study.dart' as study;

/// Le barrel du paquet, que le test tourne depuis `packages/zcrud_study` ou
/// depuis la racine du dépôt.
File _barrel() {
  for (final String p in <String>[
    'lib/zcrud_study.dart',
    'packages/zcrud_study/lib/zcrud_study.dart',
  ]) {
    final File f = File(p);
    if (f.existsSync()) return f;
  }
  fail('barrel de zcrud_study introuvable depuis ${Directory.current.path}');
}

void main() {
  group('🔴 les six symboles restent exposés par `zcrud_study`', () {
    test('ce sont EXACTEMENT ceux du cœur (aucune copie n\'est revenue)', () {
      expect(identical(study.zReadableTintOn, core.zReadableTintOn), isTrue,
          reason: '🔴 `zcrud_study` expose un `zReadableTintOn` qui n\'est PAS '
              'celui du cœur : une seconde implémentation est réapparue.');
      expect(identical(study.zContrastRatio, core.zContrastRatio), isTrue);
      expect(identical(study.zRelativeLuminance, core.zRelativeLuminance),
          isTrue);
      expect(identical(study.zCompositeOver, core.zCompositeOver), isTrue);
      expect(study.kZNonTextMinContrast, core.kZNonTextMinContrast);
      expect(study.kZTextMinContrast, core.kZTextMinContrast);
    });

    test('ils fonctionnent, vus de `zcrud_study` (le contrat de l\'hôte)', () {
      const Color yellow = Color(0xFFFFFF00);
      const Color white = Color(0xFFFFFFFF);
      expect(study.zContrastRatio(yellow, white),
          lessThan(study.kZNonTextMinContrast),
          reason: '🔴 GARDE VACUELLE : le témoin passe déjà le plancher');
      final Color out = study.zReadableTintOn(yellow, surface: white);
      expect(
        study.zContrastRatio(out.withValues(alpha: 1), white),
        greaterThanOrEqualTo(study.kZNonTextMinContrast),
        reason: '🔴 la teinte rendue depuis `zcrud_study` reste sous le '
            'plancher',
      );
    });

    test('le barrel porte le RÉ-EXPORT nominatif — le retirer casse les hôtes',
        () {
      final String src = _barrel().readAsStringSync();
      expect(src, contains("export 'package:zcrud_core/zcrud_core.dart'"),
          reason: '🔴 le ré-export du calculateur de teinte a disparu du '
              'barrel : tout hôte qui importait `zReadableTintOn` depuis '
              '`zcrud_study` ne compile plus.');
      for (final String name in <String>[
        'kZNonTextMinContrast',
        'kZTextMinContrast',
        'zCompositeOver',
        'zContrastRatio',
        'zReadableTintOn',
        'zRelativeLuminance',
      ]) {
        expect(src, contains(name),
            reason: '🔴 `$name` n\'est plus ré-exporté par le barrel.');
      }
    });

    test('AUCUN fichier `z_readable_tint.dart` ne subsiste dans `lib/`', () {
      final Directory lib = Directory(
        File('lib/zcrud_study.dart').existsSync()
            ? 'lib'
            : 'packages/zcrud_study/lib',
      );
      final List<String> hits = lib
          .listSync(recursive: true, followLinks: false)
          .whereType<File>()
          .map((File f) => f.path.replaceAll(r'\', '/'))
          .where((String p) => p.endsWith('/z_readable_tint.dart'))
          .toList();
      expect(hits, isEmpty,
          reason: '🔴 la copie locale est revenue : $hits');
    });
  });
}
