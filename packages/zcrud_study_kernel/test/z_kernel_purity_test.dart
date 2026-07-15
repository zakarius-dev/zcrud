/// Garde-fou **outillé** de pureté du kernel (SM-S5, AD-17, D1) — ES-1.2,
/// findings **M1/L3** du code-review.
///
/// ## Pourquoi un fichier séparé annoté `@TestOn('vm')`
///
/// Ce garde lit les **sources** du package (`dart:io`) : il est donc
/// **incompilable en JavaScript**. Tant qu'il vivait dans
/// `z_color_palette_test.dart`, il rendait **toute** la suite du kernel
/// non exécutable sous `dart test -p node` — et les **vecteurs golden FNV** ne
/// tournaient donc **jamais** sur la plateforme (JS) que la multiplication
/// décomposée de `zFnv1a32` existe précisément pour protéger (une variante
/// naïve passe 100 % des tests sur la VM et diverge sur le web).
///
/// Isolé ici, il reste **VM-only** (skip propre sous `-p node`) et laisse le
/// reste de la suite — vecteurs FNV compris — s'exécuter réellement en JS
/// (script melos `test:js`, enchaîné dans `melos run verify`).
///
/// ## Pourquoi le garder malgré la garantie du `pubspec.yaml`
///
/// La pureté est déjà garantie **structurellement** : `zcrud_study_kernel` ne
/// dépend pas de Flutter (`pubspec.yaml`), donc `package:flutter`/`dart:ui` y
/// sont littéralement **inimportables** (échec d'`analyze`). Ce scan est un
/// **filet redondant assumé**, conservé pour deux raisons :
/// 1. il couvre ce que le pubspec ne couvre pas : un `Color`/`IconData`
///    **redéfini localement** ou un token interdit réintroduit par copier-coller ;
/// 2. il rend SM-S5 **exécutable** (« scan » outillé) et non narratif.
///
/// Correction du finding **L3(a)** : il scanne désormais **TOUT**
/// `lib/**/*.dart` du kernel (les 3 fichiers ES-1.2, les entités ES-1.1, le
/// barrel et le code généré), et non plus le seul `z_color_palette.dart`.
@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';

/// Racine du package `zcrud_study_kernel`, quel que soit le CWD du run
/// (`dart test` depuis le package, `melos exec` depuis la racine du repo…).
Directory _kernelLibDir() {
  var dir = Directory.current;
  for (var i = 0; i < 6; i++) {
    final nested = Directory('${dir.path}/packages/zcrud_study_kernel/lib');
    if (nested.existsSync()) return nested;
    final direct = Directory('${dir.path}/lib');
    if (direct.existsSync() &&
        File('${dir.path}/lib/zcrud_study_kernel.dart').existsSync()) {
      return direct;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  fail('lib/ de zcrud_study_kernel introuvable depuis ${Directory.current.path}');
}

/// Code du fichier, **lignes de commentaire retirées** (`//` et `///`) : la
/// dartdoc DOIT pouvoir nommer les tokens interdits pour documenter la règle
/// SM-S5 sans faire échouer le garde. Un vrai `Color(` en **code** ne commence
/// jamais par `//` → aucun faux négatif possible (cf. L3, réponse « le filtre
/// n'affaiblit pas le garde »).
String _codeOnly(File file) => file
    .readAsLinesSync()
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  group('SM-S5 / AD-17 — pureté du kernel (zéro Flutter, zéro Color/IconData)',
      () {
    final libDir = _kernelLibDir();
    final sources = libDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    test('le scan couvre bien TOUT lib/ (au moins les 3 fichiers ES-1.2)', () {
      expect(sources, isNotEmpty);
      for (final expected in <String>[
        'z_color_palette.dart',
        'apply_order.dart',
        'normalize_tag_title.dart',
        'zcrud_study_kernel.dart',
      ]) {
        expect(
          sources.any((f) => f.path.endsWith(expected)),
          isTrue,
          reason: '$expected doit être couvert par le scan de pureté SM-S5',
        );
      }
    });

    for (final forbidden in <String>[
      'dart:ui',
      'package:flutter',
      'Color(',
      'IconData',
      'Colors.',
      // ES-2.8 (AC13, NFR-S10/SM-S7) : le kernel COMPARE des empreintes OPAQUES,
      // il ne HASHE RIEN. `package:crypto`/SHA-256 est BANNI (l'invalidation
      // *content-addressed* de `ZStudyPodcast.sourceHash` reçoit le hash déjà
      // calculé par le seam d'app). Un `import 'package:crypto...'` fait ROUGIR.
      'package:crypto',
    ]) {
      test("aucun fichier de lib/ ne référence `$forbidden` en CODE", () {
        for (final file in sources) {
          expect(
            _codeOnly(file).contains(forbidden),
            isFalse,
            reason:
                '${file.path} référence le token interdit `$forbidden` (SM-S5 : '
                'aucun Color/IconData/Flutter dans zcrud_study* — la résolution '
                'colorKey → couleur vit dans zcrud_core, ZcrudScope.colorKeyResolver)',
          );
        }
      });
    }
  });
}
