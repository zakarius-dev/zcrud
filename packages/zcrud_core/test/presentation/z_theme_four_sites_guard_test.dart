/// Garde STRUCTURELLE : tout jeton de `ZcrudTheme` est câblé aux **4 sites**.
///
/// 🔴 **Le piège que cette garde ferme** (rencontré plusieurs fois dans ce
/// dépôt) : un jeton ajouté en déclaration + constructeur, mais **oublié dans
/// `copyWith` ou dans `lerp`**, COMPILE parfaitement — ce sont des paramètres
/// nommés optionnels. Le défaut ne se voit qu'à l'usage : `copyWith` perd
/// silencieusement la valeur, ou `lerp` la remet à `null` à la première
/// transition de thème. Aucune garde de rendu ne le dit, puisque le rendu
/// immédiat est correct.
///
/// Les quatre sites : **déclaration** (`final T? x;`), **constructeur**
/// (`this.x`), **`copyWith`** (signature ET corps), **`lerp`**.
///
/// Accès `dart:io` ⇒ `@TestOn('vm')`. Chemin RELATIF au package : lancer
/// `flutter test` DEPUIS `packages/zcrud_core`.
///
/// 🔴 **Toute l'analyse porte sur la source STRIPPÉE de ses commentaires**
/// (`test/support/z_sources.dart`, numérotation préservée) : une dartdoc
/// insérée entre deux membres — ou citant littéralement une ancre comme
/// `ZcrudTheme copyWith({` — ne peut ni décaler les blocs extraits, ni faire
/// démarrer un bloc dans la prose. Le chantier documentation insère
/// massivement de la dartdoc dans `lib/` : la garde doit y être insensible
/// sans devenir aveugle aux vraies dérives du CODE.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support/z_sources.dart';

const String _kPath = 'lib/src/presentation/theme/z_theme.dart';

/// Déclarations de champs : `  final <Type…> <nom>;` au niveau de la classe.
final RegExp _fieldRe = RegExp(r'^  final [^;]+? (\w+);', multiLine: true);

/// Extrait la portion de [source] entre [debut] et [fin] (bornes exclues).
String _bloc(String source, String debut, String fin) {
  final int i = source.indexOf(debut);
  expect(i, isNot(-1), reason: 'ancre introuvable : $debut');
  final int j = source.indexOf(fin, i + debut.length);
  expect(j, isNot(-1), reason: 'fin introuvable : $fin (après $debut)');
  return source.substring(i + debut.length, j);
}

void main() {
  final File file = File(_kPath);
  // Source STRIPPÉE (commentaires remplacés par du vide, lignes conservées) :
  // les ancres et le scan de champs ne voient JAMAIS la prose.
  final String source = file.existsSync() ? strippedSource(file) : '';

  test('le fichier de thème est lisible', () {
    expect(
      file.existsSync(),
      isTrue,
      reason:
          'introuvable: $_kPath (cwd=${Directory.current.path}) — lancer '
          '`flutter test` DEPUIS le package',
    );
  });

  test('chaque jeton déclaré est câblé aux 4 sites', () {
    final List<String> champs = _fieldRe
        .allMatches(source)
        .map((RegExpMatch m) => m.group(1)!)
        .toList();
    // Le compteur DOIT être plausible : un `_fieldRe` qui cesserait de matcher
    // rendrait la garde vide et donc verte sur tout.
    expect(
      champs.length,
      greaterThan(40),
      reason: '🔴 le scanner ne trouve plus les champs — garde INERTE',
    );

    final String ctor = _bloc(source, 'const ZcrudTheme({', '\n  });');
    final String copyWith = _bloc(source, 'ZcrudTheme copyWith({', '\n  );');
    final String lerp = _bloc(source, 'ZcrudTheme lerp(', '\n  }\n}');

    final List<String> manquants = <String>[];
    for (final String c in champs) {
      final List<String> ou = <String>[];
      if (!ctor.contains('this.$c')) ou.add('constructeur');
      if (!RegExp('\\b$c,').hasMatch(copyWith)) ou.add('copyWith(signature)');
      if (!copyWith.contains('$c:')) ou.add('copyWith(corps)');
      if (!lerp.contains('$c:')) ou.add('lerp');
      if (ou.isNotEmpty) manquants.add('$c → manque dans ${ou.join(", ")}');
    }
    expect(
      manquants,
      isEmpty,
      reason:
          '🔴 jeton(s) NON câblé(s) aux 4 sites — la valeur serait perdue par '
          '`copyWith` ou remise à zéro par `lerp`, SANS erreur de '
          'compilation :\n${manquants.join("\n")}',
    );
  });

  test('CONTRE-PREUVE : le scanner ATTRAPE un oubli de `lerp`', () {
    // La garde ci-dessus est verte par construction si le scanner ne sait rien
    // détecter. On lui soumet donc une source MUTÉE dont on connaît le défaut.
    final String mute = source.replaceFirst(
      RegExp(r'\n      subfolderBarPadding: _lerpNullableInsets\([^;]+?\),'),
      '',
    );
    expect(mute, isNot(source), reason: 'la mutation n\'a rien changé');
    final String lerp = _bloc(mute, 'ZcrudTheme lerp(', '\n  }\n}');
    expect(lerp.contains('subfolderBarPadding:'), isFalse);
    // …et le même jeton reste bien présent aux trois autres sites : c'est
    // précisément ce qui rend l'oubli INVISIBLE au compilateur.
    expect(mute.contains('this.subfolderBarPadding'), isTrue);
    expect(
      _bloc(mute, 'ZcrudTheme copyWith({', '\n  );')
          .contains('subfolderBarPadding:'),
      isTrue,
    );
  });
}
