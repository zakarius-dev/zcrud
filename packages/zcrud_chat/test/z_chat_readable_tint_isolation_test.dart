/// 🔴 AD-1 — `zcrud_chat` consomme le calculateur de teinte du **cœur**, et
/// n'acquiert AUCUNE arête vers `zcrud_study`.
///
/// La copie `z_chat_readable_tint.dart` existait pour une seule raison : une
/// arête `zcrud_chat → zcrud_study` (satellite frère) aurait violé AD-1. Le
/// calculateur ayant remonté dans `zcrud_core`, la copie est supprimée — mais
/// le motif qui l'avait justifiée reste interdit. Cette garde rougit si
/// quiconque « simplifie » en dépendant de `zcrud_study`, ou si une copie
/// locale réapparaît.
///
/// Les arêtes sortantes exactes (`flutter`, `zcrud_chat_kernel`, `zcrud_core`)
/// sont déjà tenues en ÉGALITÉ D'ENSEMBLE par `z_chat_c5_guard_test.dart` —
/// **compte inchangé : 3**. Ce fichier ne le redouble pas : il nomme
/// `zcrud_study` explicitement, et vérifie que la copie n'est pas revenue.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/z_chat_sources.dart';

void main() {
  group('🔴 aucune arête vers `zcrud_study`', () {
    test('le pubspec ne déclare AUCUN paquet `zcrud_study*`', () {
      final File pubspec = File('${packageRoot().path}/pubspec.yaml');
      expect(pubspec.existsSync(), isTrue, reason: '🔴 pubspec introuvable');
      final List<String> offenders = <String>[
        for (final String l in pubspec.readAsLinesSync())
          if (RegExp(r'^\s{2}zcrud_study\w*\s*:').hasMatch(l)) l.trim(),
      ];
      expect(offenders, isEmpty,
          reason: '🔴 AD-1 : `zcrud_study` est un satellite FRÈRE. Le '
              'calculateur de teinte lisible vit dans `zcrud_core`, qui est '
              'atteignable sans cette arête.\n${offenders.join('\n')}');
    });

    test('aucune SOURCE de `lib/` n\'importe `zcrud_study`', () {
      final Map<String, List<String>> lib = strippedLib();
      expect(lib, isNotEmpty, reason: '🔴 GARDE VACUELLE : aucune source lue');
      final List<String> offenders = <String>[
        for (final MapEntry<String, List<String>> e in lib.entries)
          for (int i = 0; i < e.value.length; i++)
            if (RegExp(
              """(?:import|export)\\s+['"]package:zcrud_study\\w*/""",
            ).hasMatch(e.value[i].trimLeft()))
              '${e.key}:${i + 1}',
      ];
      expect(offenders, isEmpty,
          reason: '🔴 AD-1 violé par un import.\n${offenders.join('\n')}');
    });
  });

  group('🔴 la copie du calculateur est SUPPRIMÉE, pas déplacée', () {
    test('aucun fichier `*readable_tint*` dans `lib/`', () {
      final Directory lib = Directory('${packageRoot().path}/lib');
      final List<String> hits = lib
          .listSync(recursive: true, followLinks: false)
          .whereType<File>()
          .map((File f) => f.path.replaceAll(r'\', '/'))
          .where((String p) => p.contains('readable_tint'))
          .toList();
      expect(hits, isEmpty, reason: '🔴 la copie est revenue : $hits');
    });

    test('aucune source de `lib/` ne recalcule la luminance WCAG', () {
      // Motif STRUCTUREL (les coefficients), pas un nom : la copie supprimée
      // s'appelait `zChatRelativeLuminance` — un doublon se renomme.
      const List<String> coefficients = <String>['0.2126', '0.7152', '0.0722'];
      final Map<String, List<String>> lib = strippedLib();
      final List<String> offenders = <String>[
        for (final MapEntry<String, List<String>> e in lib.entries)
          if (coefficients.every(e.value.join('\n').contains)) e.key,
      ];
      expect(offenders, isEmpty,
          reason: '🔴 une seconde implémentation du contraste est réapparue '
              'dans `zcrud_chat`. Deux calculateurs de contraste finissent '
              'toujours par diverger — celui du cœur '
              '(`zReadableTintOn`) est la seule voie.\n'
              '${offenders.join('\n')}');
    });

    test('la barre d\'artefacts appelle bien le calculateur du CŒUR', () {
      final Map<String, List<String>> lib = strippedLib();
      final MapEntry<String, List<String>> bar = lib.entries.singleWhere(
        (MapEntry<String, List<String>> e) =>
            e.key.replaceAll(r'\', '/').endsWith('view/z_chat_artifact_bar.dart'),
        orElse: () => fail('🔴 `z_chat_artifact_bar.dart` introuvable'),
      );
      final String src = bar.value.join('\n');
      expect(src, contains('zReadableTintOn('),
          reason: '🔴 la teinte déclarée par l\'hôte est peinte BRUTE : le '
              'défaut ④ de CR-IFFD-84 est de retour.');
      expect(src, contains("import 'package:zcrud_core/zcrud_core.dart'"),
          reason: '🔴 le calculateur ne vient plus du cœur.');
    });
  });
}
