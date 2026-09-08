/// Aucun dégradé de ce paquet ne court-circuite la couture du socle.
///
/// `zSignatureGradientFor` est une fonction **pure** : elle indexe la palette
/// de référence sans lire ni le scope ni le thème. L'appeler depuis un widget
/// prive l'application des deux maillons amont de la chaîne — le résolveur
/// `ZcrudScope.gradientResolver` et le jeton `ZcrudTheme.signaturePalette` —
/// et de la stratégie d'index déclarée par le thème. Le rendu reste correct
/// tant que personne ne configure rien, ce qui rend le défaut invisible aux
/// gardes de rendu par défaut : d'où une garde de SOURCE.
///
/// Tous les sites de dégradé de ce paquet vivent dans un `build`, donc avec un
/// `BuildContext` sous la main : `zResolveGradient(context, …)` y est toujours
/// disponible, et il n'existe aucun cas légitime de court-circuit.
///
/// ⚠️ Ce que cette garde NE couvre PAS :
///
/// * un site qui lirait `ZSignaturePaletteReference.gradients` directement, ou
///   qui passerait par un alias local (`const f = zSignatureGradientFor;`) —
///   la garde interdit un identifiant appelé, pas toutes les voies d'accès à
///   la référence ; un second contrôle ci-dessous ferme la voie du champ
///   statique, mais pas celle d'un alias ;
/// * les autres paquets du dépôt : la garde ne lit que `lib/` d'ici ;
/// * la présence d'un `BuildContext` n'est pas vérifiée symboliquement — elle
///   est établie par lecture, pas par analyse ;
/// * l'effacement des commentaires est textuel (`//` jusqu'à la fin de ligne,
///   `/* … */`) : un `//` à l'intérieur d'un littéral de chaîne masquerait la
///   fin de cette ligne-là.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Racine du dépôt : le dossier qui porte `melos.yaml`, atteint en remontant
/// depuis le répertoire courant. Jamais un `../` relatif, dont la résolution
/// dépend du dossier d'où le harnais est lancé.
Directory _repoRoot() {
  Directory dir = Directory.current;
  while (true) {
    if (File('${dir.path}/melos.yaml').existsSync()) return dir;
    final Directory parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('melos.yaml introuvable au-dessus de ${Directory.current.path}');
    }
    dir = parent;
  }
}

/// [source] débarrassé de ses commentaires de ligne et de bloc.
String _withoutComments(String source) {
  final String noBlocks = source.replaceAll(
    RegExp(r'/\*.*?\*/', dotAll: true),
    ' ',
  );
  return noBlocks
      .split('\n')
      .map((String line) {
        final int at = line.indexOf('//');
        return at < 0 ? line : line.substring(0, at);
      })
      .join('\n');
}

void main() {
  final Directory libDir = Directory(
    '${_repoRoot().path}/packages/zcrud_session/lib',
  );

  test('la source du paquet est bien là où la garde la cherche', () {
    expect(
      libDir.existsSync(),
      isTrue,
      reason:
          'ATTRAPE : une garde qui scannerait un dossier vide et passerait au '
          'vert sans rien lire',
    );
    final List<File> files = libDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((File f) => f.path.endsWith('.dart'))
        .toList();
    expect(files.length, greaterThan(10));
  });

  test('aucun appel direct à `zSignatureGradientFor` dans `lib/`', () {
    final Map<String, List<int>> offenders = <String, List<int>>{};
    for (final File file in libDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((File f) => f.path.endsWith('.dart'))) {
      final List<String> lines = _withoutComments(
        file.readAsStringSync(),
      ).split('\n');
      for (int i = 0; i < lines.length; i++) {
        if (RegExp(r'\bzSignatureGradientFor\s*\(').hasMatch(lines[i])) {
          offenders.putIfAbsent(file.path, () => <int>[]).add(i + 1);
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'ATTRAPE : un site qui indexe la palette de référence sans passer '
          'par `zResolveGradient(context, …)` — le résolveur de '
          'l\'application et le jeton `signaturePalette` ne l\'atteignent '
          'alors jamais, et la seule prise qui reste à l\'hôte est '
          'd\'ÉTEINDRE la bande en basculant le profil de référence. '
          'Sites fautifs : $offenders',
    );
  });

  test('aucune lecture directe de `ZSignaturePaletteReference` dans `lib/`', () {
    final Map<String, List<int>> offenders = <String, List<int>>{};
    for (final File file in libDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((File f) => f.path.endsWith('.dart'))) {
      final List<String> lines = _withoutComments(
        file.readAsStringSync(),
      ).split('\n');
      for (int i = 0; i < lines.length; i++) {
        if (lines[i].contains('ZSignaturePaletteReference')) {
          offenders.putIfAbsent(file.path, () => <int>[]).add(i + 1);
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'ATTRAPE : la voie de contournement jumelle — lire la palette de '
          'référence à la main contourne exactement les mêmes maillons. '
          'Sites fautifs : $offenders',
    );
  });

  test('le site du verdict passe bien par la couture', () {
    final String source = _withoutComments(
      File('${libDir.path}/src/presentation/z_session_summary_view.dart')
          .readAsStringSync(),
    );
    expect(
      RegExp(r'zResolveGradient\s*\(\s*\n?\s*context').hasMatch(source),
      isTrue,
      reason:
          'ATTRAPE : la bande de verdict rebranchée ailleurs que sur la '
          'couture, ou sur un contexte qui n\'est pas celui du build',
    );
    expect(
      source.contains('zSignatureKey(ZSessionSummaryView.verdictGradientIdentity)'),
      isTrue,
      reason:
          'ATTRAPE : une clé de dégradé qui ne porte plus le préfixe '
          '`zcrud.signature.` — `zResolveGradient` rend alors `null` pour '
          'toute clé, et la bande retombe muette sur les rôles M3',
    );
  });
}
