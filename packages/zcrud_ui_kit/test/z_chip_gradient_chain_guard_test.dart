/// Aucun dégradé de ce paquet ne court-circuite la couture du socle.
///
/// `zSignatureGradientFor` est une fonction **pure** : elle indexe une palette
/// sans lire ni le scope ni le thème. L'appeler depuis un widget prive
/// l'application des deux maillons amont de la chaîne — le résolveur
/// `ZcrudScope.gradientResolver` et le jeton `ZcrudTheme.signaturePalette` —
/// et de la stratégie d'index déclarée par le thème. Le rendu reste correct
/// tant que personne ne configure rien, ce qui rend le défaut invisible aux
/// gardes de rendu par défaut : d'où une garde de SOURCE.
///
/// Tous les sites de dégradé de ce paquet vivent dans un `build` ou dans une
/// fabrique qui reçoit un `BuildContext`, donc `zResolveGradient(context, …)`
/// y est toujours disponible : il n'existe aucun cas légitime de
/// court-circuit.
///
/// La lecture directe de `ZSignaturePaletteReference`, elle, reste **permise**
/// — mais seulement pour la teinte de TÊTE d'une palette, cas où aucune
/// identité n'existe et où il n'y a donc aucune clé à soumettre au résolveur.
/// Deux contrôles l'encadrent alors : le jeton doit être consulté d'abord, et
/// la référence doit rester arbitrée par le profil.
///
/// ⚠️ Ce que cette garde NE couvre PAS :
///
/// * un alias local (`const f = zSignatureGradientFor;`) ou une lecture de la
///   référence via une variable intermédiaire déclarée dans un autre fichier —
///   la garde interdit un identifiant appelé et exige une co-occurrence dans
///   le MÊME fichier, pas un flux de données ;
/// * l'ORDRE réel des maillons dans un fichier : la co-occurrence de
///   `signaturePalette`, de `zLegacyOr` et de la référence est textuelle, pas
///   sémantique — c'est le test de rendu jumeau
///   (`z_chip_signature_seam_test.dart`) qui mesure l'ordre sur la couleur
///   peinte ;
/// * les autres paquets du dépôt : la garde ne lit que le `lib/` d'ici ;
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
      throw StateError(
        'melos.yaml introuvable au-dessus de ${Directory.current.path}',
      );
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
    '${_repoRoot().path}/packages/zcrud_ui_kit/lib',
  );

  List<File> dartFiles() => libDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((File f) => f.path.endsWith('.dart'))
      .toList();

  test('la source du paquet est bien là où la garde la cherche', () {
    expect(
      libDir.existsSync(),
      isTrue,
      reason:
          'ATTRAPE : une garde qui scannerait un dossier vide et passerait au '
          'vert sans rien lire',
    );
    expect(dartFiles().length, greaterThan(10));
  });

  test('aucun appel direct à `zSignatureGradientFor` dans `lib/`', () {
    final Map<String, List<int>> offenders = <String, List<int>>{};
    for (final File file in dartFiles()) {
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
          'ATTRAPE : un site qui indexe la palette sans passer par '
          '`zResolveGradient(context, …)` — le résolveur de l\'application et '
          'la stratégie d\'index du thème ne l\'atteignent alors jamais, et '
          'la seule prise qui reste à l\'hôte est d\'ÉTEINDRE la teinte en '
          'basculant le profil de référence. Sites fautifs : $offenders',
    );
  });

  test('toute lecture de la référence consulte le jeton dans le même fichier', () {
    final List<String> offenders = <String>[];
    for (final File file in dartFiles()) {
      final String code = _withoutComments(file.readAsStringSync());
      if (!code.contains('ZSignaturePaletteReference')) continue;
      if (!code.contains('signaturePalette')) offenders.add(file.path);
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'ATTRAPE : la palette de référence lue sans que le jeton '
          '`ZcrudTheme.signaturePalette` soit consulté — une palette posée '
          'par l\'hôte serait ignorée. Sites fautifs : $offenders',
    );
  });

  test('toute lecture de la référence est arbitrée par le profil', () {
    final List<String> offenders = <String>[];
    for (final File file in dartFiles()) {
      final String code = _withoutComments(file.readAsStringSync());
      if (!code.contains('ZSignaturePaletteReference')) continue;
      if (!RegExp(r'\bzLegacyOr(In)?\s*<').hasMatch(code)) {
        offenders.add(file.path);
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'ATTRAPE : la référence auditée peinte SANS arbitrage de profil — '
          'le défaut du socle (`neutral`) se mettrait à porter des couleurs '
          'de référence. Sites fautifs : $offenders',
    );
  });

  test('la teinte de sélection des puces passe bien par la couture', () {
    final String source = _withoutComments(
      File(
        '${libDir.path}/src/presentation/z_chip_style.dart',
      ).readAsStringSync(),
    );
    expect(
      RegExp(r'zResolveGradient\s*\(\s*\n?\s*context').hasMatch(source),
      isTrue,
      reason:
          'ATTRAPE : la teinte de sélection rebranchée ailleurs que sur la '
          'couture, ou sur un contexte qui n\'est pas celui du build',
    );
    expect(
      RegExp(r'zSignatureKey\s*\(\s*signatureKey\s*\)').hasMatch(source),
      isTrue,
      reason:
          'ATTRAPE : une clé de dégradé qui ne porte plus le préfixe '
          '`zcrud.signature.`, ou qui ne porte plus l\'identité reçue — '
          '`zResolveGradient` rendrait alors `null` pour toute clé, et la '
          'puce retomberait muette sur les rôles M3',
    );
  });
}
