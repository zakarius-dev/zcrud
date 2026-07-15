/// Garde **NÉGATIF** et **outillé** de la surface publique (ES-1.2, D3 — finding
/// **L4** du code-review).
///
/// `z_public_surface_test.dart` est **positif uniquement** : il prouve que la
/// surface historique E9 compile encore malgré le `hide`. Il est
/// **structurellement incapable** de détecter l'inverse — qu'un **nouvel**
/// utilitaire du kernel a **fuité** dans la surface publique de
/// `zcrud_flashcard` (si ES-1.3 ajoute `ZSyncMeta` au barrel kernel et oublie le
/// `hide`, rien ne casse : le symbole fuite en silence).
///
/// Ce test **outille** la règle de maintenance du `hide` : il croise les
/// symboles publics **réellement** exportés par le barrel `zcrud_study_kernel`
/// avec (a) la liste `hide` du barrel `zcrud_flashcard` et (b) une **allowlist
/// explicite** des symboles « pertinents flashcard ». Tout symbole kernel
/// **non classé** fait **ÉCHOUER** ce test — forçant la décision (masquer ou
/// allowlister) au lieu de la fuite silencieuse.
///
/// Technique : lecture des sources (même approche que le garde de pureté du
/// kernel), à défaut de réflexion sur les exports (indisponible en Dart).
///
/// Note : les symboles **générés** (`part '*.g.dart'` — `registerZStudyFolder`,
/// `$ZStudyFolderFieldSpecs`, …) ne sont **pas** énumérés (c'est tout l'intérêt
/// du `hide` vs `show`, D3) : ils suivent la classification de **leur entité**,
/// laquelle est, elle, classée ici.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Symboles publics du kernel **pertinents pour les flashcards** : ils DOIVENT
/// rester dans la surface publique de `zcrud_flashcard` (surface historique E9,
/// remontée en ES-1.1).
const Set<String> _flashcardAllowlist = <String>{
  'ZStudyFolder',
  'ZFolderExtensionParser',
  'validatePlacement',
  'ZReviewMode',
  'ZStudySessionConfig',
  'ZSessionConfigExtensionParser',
  'ZSessionCandidate',
  'ZStudySessionSelector',
  // ES-2.3 — tags first-class + primitives pures (pertinents flashcard :
  // migration DODLP, remap couleur / détection d'orphelins).
  'ZFlashcardTag',
  'ZFlashcardTagExtensionParser',
  'ZSuggestedTag',
  'remapColorKey',
  'orphanTagIds',
};

/// Racine du repo, quel que soit le CWD du run.
Directory _repoRoot() {
  var dir = Directory.current;
  for (var i = 0; i < 6; i++) {
    if (Directory('${dir.path}/packages/zcrud_study_kernel').existsSync() &&
        Directory('${dir.path}/packages/zcrud_flashcard').existsSync()) {
      return dir;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  throw StateError('racine du repo introuvable depuis ${Directory.current.path}');
}

/// Lignes de **code** (commentaires `//`/`///` retirés).
List<String> _codeLines(File file) => file
    .readAsLinesSync()
    .where((line) => !line.trimLeft().startsWith('//'))
    .toList();

/// Liste `hide` appliquée au réexport du kernel dans le barrel `zcrud_flashcard`.
Set<String> _hiddenKernelSymbols(File flashcardBarrel) {
  final code = _codeLines(flashcardBarrel).join('\n');
  final match = RegExp(
    r"export\s+'package:zcrud_study_kernel/zcrud_study_kernel\.dart'([^;]*);",
  ).firstMatch(code);
  if (match == null) {
    throw StateError(
      'Réexport du barrel kernel introuvable dans zcrud_flashcard.dart — la '
      'politique D3 (export ... hide ...) a-t-elle été supprimée ?',
    );
  }
  final clause = match.group(1) ?? '';
  final hide = RegExp(r'hide\s+([^;]+)').firstMatch(clause);
  if (hide == null) return <String>{};
  return hide
      .group(1)!
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toSet();
}

/// Symboles publics **écrits à la main** exportés par le barrel du kernel
/// (les `.g.dart` générés sont volontairement hors périmètre — cf. dartdoc).
Set<String> _publicKernelSymbols(Directory kernelRoot) {
  final barrel = File('${kernelRoot.path}/lib/zcrud_study_kernel.dart');
  final symbols = <String>{};

  for (final line in _codeLines(barrel)) {
    final export = RegExp(r"export\s+'(src/[^']+)'([^;]*);").firstMatch(line);
    if (export == null) continue;

    // `hide` propre au barrel kernel (extensions générées masquées à la source).
    final selfHidden = <String>{};
    final selfHide = RegExp(r'hide\s+([^;]+)').firstMatch(export.group(2) ?? '');
    if (selfHide != null) {
      selfHidden.addAll(
        selfHide.group(1)!.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty),
      );
    }

    final source = File('${kernelRoot.path}/lib/${export.group(1)}');
    if (!source.existsSync()) {
      throw StateError('Source exportée introuvable : ${source.path}');
    }

    for (final raw in _codeLines(source)) {
      // Déclarations top-level uniquement (colonne 0).
      if (raw.isEmpty || raw.startsWith(' ') || raw.startsWith('\t')) continue;

      final typeDecl = RegExp(
        r'^(?:abstract\s+|base\s+|final\s+|sealed\s+|interface\s+)*'
        r'(?:class|enum|mixin|extension|typedef)\s+([A-Za-z_$][\w$]*)',
      ).firstMatch(raw);
      if (typeDecl != null) {
        symbols.add(typeDecl.group(1)!);
        continue;
      }

      // Fonctions / variables top-level : `<Type> nom(` ou `<Type> nom =`.
      final member = RegExp(
        r'^(?:const\s+|final\s+|late\s+)?[A-Za-z_$][\w$<>,?\s\.]*?\s+'
        r'([A-Za-z_$][\w$]*)\s*(?:<[^>(]*>)?\s*[(=]',
      ).firstMatch(raw);
      if (member != null) symbols.add(member.group(1)!);
    }

    symbols.removeAll(selfHidden);
  }

  // Privés / générés éventuels.
  symbols.removeWhere((s) => s.startsWith('_') || s.startsWith(r'$'));
  return symbols;
}

void main() {
  // NB : la lecture des sources se fait dans `setUpAll` (et non au chargement du
  // fichier) — `expect`/`fail` hors d'un test lèvent `OutsideTestException`.
  late Set<String> kernelSymbols;
  late Set<String> hidden;

  setUpAll(() {
    final root = _repoRoot();
    kernelSymbols = _publicKernelSymbols(
      Directory('${root.path}/packages/zcrud_study_kernel'),
    );
    hidden = _hiddenKernelSymbols(
      File('${root.path}/packages/zcrud_flashcard/lib/zcrud_flashcard.dart'),
    );
  });

  group('D3 / L4 — aucune FUITE du kernel dans la surface zcrud_flashcard', () {
    test('le scan trouve bien la surface du kernel (méta-garde)', () {
      // Si la lecture des sources échouait silencieusement, le test principal
      // passerait pour de mauvaises raisons (ensemble vide ⊆ tout).
      expect(kernelSymbols, contains('ZStudyFolder'));
      expect(kernelSymbols, contains('ZColorPalette'));
      expect(kernelSymbols, contains('applyOrder'));
      expect(kernelSymbols.length, greaterThanOrEqualTo(12));
      expect(hidden, isNotEmpty);
    });

    test('TOUT symbole public du kernel est CLASSÉ (hide ∪ allowlist)', () {
      final unclassified =
          kernelSymbols.difference(hidden).difference(_flashcardAllowlist);
      expect(
        unclassified,
        isEmpty,
        reason:
            'FUITE POTENTIELLE — symbole(s) public(s) du barrel zcrud_study_kernel '
            'ni masqué(s) par le `hide` de zcrud_flashcard, ni allowlisté(s) comme '
            'pertinent(s) flashcard : $unclassified.\n'
            'Décider EXPLICITEMENT (règle de maintenance D3) :\n'
            '  - hors périmètre flashcard  -> ajouter au `hide` de '
            'packages/zcrud_flashcard/lib/zcrud_flashcard.dart ;\n'
            '  - pertinent flashcard       -> ajouter à `_flashcardAllowlist` de '
            'ce test.',
      );
    });

    test('les utilitaires ES-1.2 sont EFFECTIVEMENT masqués', () {
      for (final util in <String>[
        'ZColorPalette',
        'ZKeyHash',
        'zFnv1a32',
        'ZUnorderedPlacement',
        'applyOrder',
        'normalizeTagTitle',
        'dedupeByNormalizedTitle',
      ]) {
        expect(
          hidden,
          contains(util),
          reason: '$util (utilitaire ES-1.2) doit rester hors de la surface '
              'publique de zcrud_flashcard (D3).',
        );
      }
    });

    test('le `hide` ne contient pas d\'entrée obsolète', () {
      final stale = hidden.difference(kernelSymbols);
      expect(
        stale,
        isEmpty,
        reason: 'Le `hide` de zcrud_flashcard masque des symboles qui n\'existent '
            'plus dans le barrel kernel : $stale (nettoyer).',
      );
    });

    test('allowlist et hide sont disjoints', () {
      expect(_flashcardAllowlist.intersection(hidden), isEmpty);
    });
  });
}
