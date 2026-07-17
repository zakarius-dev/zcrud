/// Garde d'ÉTANCHÉITÉ des types riches dans l'API publique de `zcrud_flashcard`
/// (SU-1, AC4 — AD-7/AD-40).
///
/// AD-40 : le rendu riche est une **INJECTION**, jamais une dépendance du
/// contrat. Aucun type `Quill`/`flutter_math_fork` ne doit apparaître dans une
/// **signature publique** de `zcrud_flashcard` : un consommateur qui n'injecte
/// aucun rendu riche ne doit pas se voir imposer ces types.
///
/// ⚠️ **Pourquoi une garde de SOURCE et non de GRAPHE** (portée honnête) :
/// `zcrud_flashcard` **dépend légitimement** de `zcrud_markdown` (arête
/// PRÉEXISTANTE, `z_flashcard_api.dart` la rattache). Une preuve de graphe
/// « flashcard ne voit pas Quill » serait donc **fausse par construction** et
/// n'aurait aucun pouvoir. Ce qu'AD-40 exige réellement est plus fin : que les
/// types riches ne **fuient pas dans les signatures**. C'est ce que ce test
/// vérifie, et rien de plus — l'isolation de graphe de `zcrud_core`, elle, est
/// déjà couverte par `flutter_quill_isolation_graph_test.dart` côté markdown.
///
/// Scan hors dartdoc/commentaires (patron `z_linear_no_srs_test.dart`) : la
/// prose DOIT pouvoir nommer Quill pour expliquer l'invariant.
/// Accès `dart:io` ⇒ `@TestOn('vm')`.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Types/paquets de rendu riche interdits dans une signature publique (AC4).
const List<String> _bannedRichTypes = <String>[
  'flutter_quill',
  'flutter_math_fork',
  'QuillController',
  'QuillEditor',
  'QuillToolbar',
  'Math.tex',
  'TeXView',
];

/// Vrai si [declaration] déclare une API **publique** (ni privée, ni locale).
///
/// Reçoit une **déclaration ENTIÈRE** recollée (cf. [scanForRichTypeLeaks]), pas
/// une ligne isolée : `dart format` (80 col.) wrappe toute signature un peu
/// longue, si bien que le multi-lignes est le cas **NOMINAL**. Un filtre
/// ligne-à-ligne laisserait passer le type riche porté par une ligne de
/// paramètre (`  QuillController content,`), qui ne commence par aucun préfixe.
///
/// Heuristique volontairement LARGE : on préfère scanner trop (y compris des
/// déclarations internes) que trop peu — un faux positif se corrige, un type
/// riche qui fuit dans une signature publique casse les consommateurs.
bool _isPublicDeclaration(String declaration) {
  // Annotations en tête (`@override`, `@immutable`…) : les retirer, sinon la
  // déclaration qu'elles décorent échapperait à tous les préfixes ci-dessous.
  var trimmed = declaration.trimLeft();
  while (trimmed.startsWith('@')) {
    final space = trimmed.indexOf(' ');
    if (space < 0) return false;
    trimmed = trimmed.substring(space + 1).trimLeft();
  }
  if (trimmed.startsWith('_')) return false; // déclaration privée
  return trimmed.startsWith('typedef ') ||
      trimmed.startsWith('class ') ||
      trimmed.startsWith('abstract ') ||
      trimmed.startsWith('mixin ') ||
      trimmed.startsWith('extension ') ||
      trimmed.startsWith('final ') ||
      trimmed.startsWith('const ') ||
      trimmed.startsWith('static ') ||
      trimmed.startsWith('Widget ') ||
      trimmed.startsWith('void ') ||
      trimmed.contains(' Function(');
}

/// **Scanner RÉEL de la garde** — l'unique implémentation du scan.
///
/// Raisonne par **DÉCLARATION** et non par ligne : les lignes de continuation
/// sont **recollées** jusqu'au `;`/`{`/`}` qui clôt l'unité syntaxique, puis les
/// espaces sont normalisés. C'est ce qui donne à la garde son pouvoir sur la
/// forme réelle du code — un typedef wrappé sur 4 lignes par `dart format` :
///
/// ```dart
/// typedef ZFlashcardContentBuilder = Widget Function(
///   BuildContext context,
///   QuillController content,   // ← fuite : invisible à un scan ligne-à-ligne
/// );
/// ```
///
/// Exercé À LA FOIS par la garde (sur le code de prod) et par sa contre-preuve :
/// sans ce partage, la contre-preuve prouverait le pouvoir des MOTIFS, jamais
/// celui du SCANNER — c'est exactement ainsi que la cécité au multi-lignes avait
/// pu survivre à une contre-preuve verte.
List<String> scanForRichTypeLeaks(List<String> lines, String path) {
  final violations = <String>[];
  final buffer = StringBuffer();
  var startLine = 0;

  void flush() {
    final declaration = buffer.toString().trim().replaceAll(RegExp(r'\s+'), ' ');
    buffer.clear();
    if (declaration.isEmpty) return;
    if (!_isPublicDeclaration(declaration)) return;
    for (final banned in _bannedRichTypes) {
      if (declaration.contains(banned)) {
        violations.add('$path:$startLine → « $banned » dans « $declaration »');
      }
    }
  }

  for (var i = 0; i < lines.length; i++) {
    final raw = lines[i];
    final trimmed = raw.trimLeft();
    if (trimmed.startsWith('///') || trimmed.startsWith('//')) {
      continue; // la prose doit pouvoir NOMMER Quill
    }
    if (trimmed.isEmpty) {
      // Ligne vide : elle ne peut pas couper une signature, mais elle borne
      // sûrement une unité restée ouverte (sécurité anti-agrégation).
      flush();
      continue;
    }
    if (buffer.isEmpty) startLine = i + 1;
    buffer
      ..write(' ')
      ..write(trimmed);
    // Fin d'unité syntaxique : `;` (déclaration/typedef/champ), `{` (en-tête de
    // classe ou de corps), `}` (fermeture).
    if (trimmed.endsWith(';') || trimmed.endsWith('{') || trimmed.endsWith('}')) {
      flush();
    }
  }
  flush(); // unité résiduelle en fin de fichier
  return violations;
}

void main() {
  test(
    'AC4 — aucun type riche (Quill/flutter_math_fork) dans une signature '
    'publique de zcrud_flashcard (AD-7/AD-40)',
    () {
      final libDir = Directory('lib');
      expect(libDir.existsSync(), isTrue,
          reason: 'lib/ introuvable (cwd = ${Directory.current.path})');

      final sources = libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where((f) => !f.path.endsWith('.g.dart'))
          .toList();

      // Contre-preuve R12 : le scan DOIT voir des fichiers ET voir le fichier
      // du slot — sinon la garde serait morte (faux vert éternel).
      expect(sources, isNotEmpty, reason: 'aucune source scannée — garde morte');
      expect(
        sources.any((f) => f.path.endsWith('z_flashcard_content_slot.dart')),
        isTrue,
        reason: 'le fichier du slot AD-40 n\'a pas été vu par le scan',
      );

      final violations = <String>[];
      for (final source in sources) {
        violations.addAll(
          scanForRichTypeLeaks(source.readAsLinesSync(), source.path),
        );
      }

      expect(
        violations,
        isEmpty,
        reason: 'TYPE RICHE dans une signature publique de `zcrud_flashcard` : '
            'le rendu riche doit rester une INJECTION via '
            '`ZFlashcardContentBuilder` (AD-40), jamais une dépendance du '
            'contrat :\n${violations.join('\n')}',
      );
    },
  );

  test(
    'AC4 — le chemin PAR DÉFAUT du slot n\'importe AUCUN rendu riche',
    () {
      // Le défaut ne doit atteindre ni Quill, ni flutter_math_fork, ni même
      // `zcrud_markdown` : sinon le « défaut texte brut » d'AD-40 serait un
      // mensonge (le consommateur paierait le rendu riche sans l'injecter).
      //
      // 🔴 D11 — `ZFlashcardReviewCard` EST scanné, lui aussi. La garde
      // n'inspectait que le fichier du slot et ignorait le widget qui RÉSOUT
      // réellement le défaut (`contentBuilder ?? …`) : un futur
      // `?? ZFlashcardMarkdownContent.builder()` aurait fait payer Quill à TOUT
      // consommateur — AD-40 violé, garde VERTE.
      final defaultPath = <File>[
        File('lib/src/presentation/z_flashcard_content_slot.dart'),
        File('lib/src/presentation/z_flashcard_review_card.dart'),
      ];

      for (final source in defaultPath) {
        expect(source.existsSync(), isTrue,
            reason: 'fichier du chemin par défaut introuvable : ${source.path} '
                '(cwd = ${Directory.current.path})');

        final lines = source.readAsLinesSync();
        expect(lines, isNotEmpty,
            reason: 'fichier vide — rien scanné (R12) : ${source.path}');

        final imports = lines
            .map((l) => l.trimLeft())
            .where((l) => l.startsWith('import ') || l.startsWith('export '))
            .toList();
        expect(imports, isNotEmpty,
            reason: 'aucun import vu dans ${source.path} — scan suspect');

        for (final import in imports) {
          expect(import.contains('flutter_quill'), isFalse,
              reason: 'le chemin par défaut importe Quill (${source.path}) : '
                  '« $import »');
          expect(import.contains('flutter_math_fork'), isFalse,
              reason: 'le chemin par défaut importe flutter_math_fork '
                  '(${source.path}) : « $import »');
          expect(import.contains('zcrud_markdown'), isFalse,
              reason: 'le chemin par défaut importe zcrud_markdown — il doit '
                  'être PUR texte brut (AD-40) (${source.path}) : « $import »');
        }
      }
    },
  );

  test(
    '🔴 D11 — le défaut RÉSOLU par ZFlashcardReviewCard est bien celui de su-1 '
    '(jamais l\'adaptateur riche)',
    () {
      // Complément de SOURCE au test d'identité (`sm1_test`) : il ferme la
      // porte à la réintroduction d'un défaut riche par le call-site réel, que
      // le scan d'imports ci-dessus ne verrait pas si l'adaptateur venait à
      // vivre dans le MÊME fichier.
      final card = File('lib/src/presentation/z_flashcard_review_card.dart');
      final lines = card.readAsLinesSync();
      expect(lines, isNotEmpty, reason: 'fichier vide — rien scanné (R12)');

      final resolutions = <String>[];
      for (var i = 0; i < lines.length; i++) {
        final trimmed = lines[i].trimLeft();
        if (trimmed.startsWith('///') || trimmed.startsWith('//')) continue;
        if (trimmed.contains('contentBuilder ??')) {
          resolutions.add('${card.path}:${i + 1} → « $trimmed »');
        }
      }

      // Contre-preuve R12 : le scan voit bien LA ligne de résolution — sinon
      // l'assertion suivante ne prouverait rien.
      expect(resolutions, hasLength(1),
          reason: 'la résolution du défaut est introuvable ou dupliquée : le '
              'scan est aveugle (${resolutions.length} occurrence(s))');
      expect(resolutions.single, contains('ZFlashcardDefaultContent.builder'),
          reason: 'le défaut résolu n\'est PAS le texte brut de su-1 : AD-40 '
              'est violé (tout consommateur paierait le rendu riche) — '
              '${resolutions.single}');
    },
  );

  test(
    'AC4 — la garde a bien du pouvoir : le SCANNER RÉEL détecte un type riche '
    'en signature MONO-ligne (contre-preuve du scanner lui-même)',
    () {
      // Prouve que le scanner N'EST PAS tautologique : on exerce ici la
      // fonction que la garde ci-dessus exécute RÉELLEMENT, pas une copie.
      const injected = <String>[
        '/// Le rendu riche via QuillController est une injection — NON détecté',
        'typedef ZFlashcardContentBuilder = Widget Function(QuillController c);',
        '  final QuillController controller;',
        '  final String content;', // légitime — NE DOIT PAS être détecté
      ];

      final violations = scanForRichTypeLeaks(injected, 'artificiel.dart');

      expect(violations.any((v) => v.startsWith('artificiel.dart:2')), isTrue,
          reason: 'typedef exposant Quill non détecté — garde morte');
      expect(violations.any((v) => v.startsWith('artificiel.dart:3')), isTrue,
          reason: 'champ public Quill non détecté — garde morte');
      expect(violations.any((v) => v.startsWith('artificiel.dart:1')), isFalse,
          reason: 'faux positif sur du dartdoc — la prose doit rester libre');
      expect(violations.any((v) => v.startsWith('artificiel.dart:4')), isFalse,
          reason: 'faux positif sur une signature légitime (String content)');
    },
  );

  test(
    'AC4 — POUVOIR SUR LE CAS NOMINAL : le scanner détecte un type riche dans '
    'une signature MULTI-LIGNES (la forme que `dart format` impose)',
    () {
      // Le typedef protégé est lui-même wrappé sur 4 lignes : un scan
      // ligne-à-ligne ne verrait JAMAIS « QuillController content, », qui ne
      // commence par aucun préfixe de déclaration. C'est le cas NOMINAL, pas
      // l'exception — et c'était le trou réel de cette garde.
      const injected = <String>[
        'typedef ZFlashcardContentBuilder = Widget Function(',
        '  BuildContext context,',
        '  QuillController content,',
        ');',
      ];

      final violations = scanForRichTypeLeaks(injected, 'artificiel.dart');

      expect(violations, isNotEmpty,
          reason: 'FUITE MULTI-LIGNES NON DÉTECTÉE — le scanner raisonne '
              'encore par ligne : il est aveugle à la forme réelle du code');
      expect(violations.single, contains('QuillController'));
      expect(violations.single, startsWith('artificiel.dart:1'),
          reason: 'la violation doit pointer la LIGNE D\'OUVERTURE de la '
              'déclaration, pas la ligne de continuation');
    },
  );

  test(
    'AC4 — le scanner n\'agrège pas à tort : une déclaration légitime '
    'multi-lignes ne fait PAS un faux positif',
    () {
      // Anti-sur-blocage : le recollage ne doit pas fusionner une déclaration
      // saine avec une déclaration PRIVÉE voisine mentionnant un type riche —
      // sinon la garde crierait au loup et finirait par être désarmée.
      const injected = <String>[
        'typedef ZFlashcardContentBuilder = Widget Function(',
        '  BuildContext context,',
        '  String content,',
        ');',
        '',
        'class _RichAdapter {',
        '  final QuillController _controller;',
        '}',
      ];

      final violations = scanForRichTypeLeaks(injected, 'artificiel.dart');

      expect(violations.any((v) => v.startsWith('artificiel.dart:1')), isFalse,
          reason: 'le typedef légitime (String content) ne doit PAS être '
              'signalé — recollage trop gourmand');
    },
  );
}
