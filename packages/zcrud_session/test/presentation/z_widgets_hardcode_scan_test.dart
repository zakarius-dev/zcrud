/// AC4 — ZÉRO couleur/label en dur dans les widgets de présentation.
/// AC5 — ZÉRO API non-directionnelle, ZÉRO `ListView(children:)`.
///
/// Scan des SOURCES (`dart:io`) de `lib/src/presentation/**`. Discriminants
/// INJ-4 (`Colors.`/`Color(0x`) et INJ-5 (`EdgeInsets.only(left:` etc.).
///
/// **Portée déclarée honnêtement** : cette garde couvre `zcrud_session/lib/src/
/// presentation/**` — le **code de prod** de ce package, et rien d'autre. Elle
/// ne scanne **pas** les tests (qui construisent légitimement un `Color(0x…)`
/// pour prouver un repli de thème), ni les autres packages (qui ont les leurs).
///
/// **Elle n'énumère JAMAIS une liste figée de widgets** : le scan est
/// **récursif** ⇒ tout futur widget (dont `ZFlashcardAnswerInput`, SU-3) est
/// capté **sans édition du test** (R16). su-3 la **DURCIT** (défaut D4) au lieu
/// d'en créer une parallèle : un `z_session_rtl_guard_test.dart` séparé serait
/// une garde **redondante**, qui divergerait de celle-ci avec le temps.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Énumère RÉCURSIVEMENT tous les `.dart` de `lib/src/presentation/**` — jamais
/// une liste figée : un futur widget codant `Colors.*`/API non-directionnelle
/// est capté sans édition du test (durabilité de la garde, R16).
List<String> _presentationFiles() {
  const root = 'lib/src/presentation';
  final dir = Directory(root);
  expect(
    dir.existsSync(),
    isTrue,
    reason: 'répertoire introuvable: $root (cwd=${Directory.current.path})',
  );
  return dir
      .listSync(recursive: true)
      .whereType<File>()
      .map((f) => f.path)
      .where((p) => p.endsWith('.dart'))
      .toList()
    ..sort();
}

/// Motifs de **couleur en dur** interdits (FR-26/AD-6 — AC4).
const List<String> _bannedColorPatterns = <String>[
  'Colors.',
  'Color(0x',
  'AppColors.',
];

/// Motifs **non-directionnels** interdits (AD-13 — AC5).
const List<String> _bannedDirectionalPatterns = <String>[
  'EdgeInsets.only(left:',
  'EdgeInsets.only(right:',
  'Alignment.centerLeft',
  'Alignment.centerRight',
  'Alignment.topLeft',
  'Alignment.topRight',
  'Alignment.bottomLeft',
  'Alignment.bottomRight',
  'TextAlign.left',
  'TextAlign.right',
  'Positioned(left:',
  'Positioned(right:',
  'ListView(children:',
];

/// Motifs de **libellé UTILISATEUR en dur** interdits (AC11 — « zéro libellé en
/// dur : `label(context, 'zcrud.…', fallback: '…')` »).
///
/// 🔴 **SU-3 — TROU DE GARDE réel, fermé ici.** Ce fichier ne bannissait que les
/// **couleurs** et les **API non-directionnelles** : **aucun motif ne visait les
/// chaînes utilisateur**. L'AC11 « zéro libellé en dur » n'avait donc **AUCUN
/// EXÉCUTEUR** — et su-3 a livré `_validate` rendant le littéral **`'required'`**,
/// **affiché en anglais** sous le champ de réponse (`errorText`,
/// `autovalidateMode: onUserInteraction`), dans le **même diff** qui soldait la
/// dette `'ok'`/`'lapse'` de su-1. Sans cette garde, le prochain repassera.
///
/// ⚠️ **PORTÉE DÉCLARÉE HONNÊTEMENT — et volontairement ÉTROITE.** Cette garde
/// ne prétend **pas** détecter « toute chaîne en dur » : la majorité des
/// littéraux de ces fichiers sont **légitimes** (clés l10n `'zcrud.flashcard.*'`,
/// `fallback:` — le patron SANCTIONNÉ —, `ValueKey('zSubmit')`, `padLeft(2,
/// '0')`). Un scan large les capterait tous et serait désactivé sous les faux
/// positifs. Elle vise donc les **PUITS RÉELLEMENT RENDUS À L'ÉCRAN**, où un
/// littéral est **toujours** un défaut :
///  1. le 1ᵉʳ argument positionnel de `Text(` / `SelectableText(` ;
///  2. les arguments nommés qui rendent du texte (`errorText:`, `labelText:`…) ;
///  3. un **validateur** rendant un littéral — le puits EXACT du défaut su-3
///     (son message part en `errorText`).
///
/// Ce qu'elle **ne voit pas** (consigné, non prétendu) : (a) un littéral passé
/// par une variable intermédiaire (`final s = 'Bonjour'; … Text(s)`) ; (b)
/// `Semantics(label: '…')` — puits réel, mais l'ajouter rougirait sur du code
/// **hérité de su-1/su-2** hors du périmètre de su-3 (cf. code-review-su-3.md,
/// consigné au ledger su-4).
const List<({String name, String pattern})>
_bannedUserStringRules = <({String name, String pattern})>[
  (
    name: 'Text(\'…\') — libellé en dur affiché',
    pattern: r"Text\(\s*'([^']*)'",
  ),
  (name: 'Text("…") — libellé en dur affiché', pattern: r'Text\(\s*"([^"]*)"'),
  (name: 'errorText: \'…\' en dur', pattern: r"errorText:\s*'([^']*)'"),
  (name: 'labelText: \'…\' en dur', pattern: r"labelText:\s*'([^']*)'"),
  (name: 'hintText: \'…\' en dur', pattern: r"hintText:\s*'([^']*)'"),
  (name: 'helperText: \'…\' en dur', pattern: r"helperText:\s*'([^']*)'"),
  (name: 'tooltip: \'…\' en dur', pattern: r"tooltip:\s*'([^']*)'"),
  (name: 'semanticLabel: \'…\' en dur', pattern: r"semanticLabel:\s*'([^']*)'"),
];

/// Un **validateur** qui rend un littéral — le puits exact du défaut su-3 (son
/// message part en `errorText`, sous le champ, en toutes lettres).
///
/// ⚠️ **DEUX formes, parce qu'une seule ne suffit PAS** — mesuré : ma première
/// version n'ancrait que la **signature** `String? _validate(…)`, la forme
/// livrée par su-3. Rejouer l'injection sur le code **corrigé**
/// (`_cachedValidator = (value) => … ? 'required' : null;`) laissait le scan
/// **VERT** : la garde n'aurait attrapé que le défaut d'hier, pas celui de
/// demain. Les deux formes sont donc couvertes.
///
/// Toutes deux sont **ANCRÉES** (signature ou affectation), donc sans faux
/// positif sur le gros bloc `return Column(…)` recollé par `_declarations` —
/// qui contient légitimement des clés l10n mais aucune de ces ancres.
final List<RegExp> _bannedValidatorLiterals = <RegExp>[
  // `static String? _validate(String? value) => … ? 'required' : null;`
  RegExp(r"String\?\s+\w*[Vv]alidat\w*\([^)]*\)[^;]*'([^']*)'"),
  // `_cachedValidator = (value) => … ? 'required' : null;`
  RegExp(r"[Vv]alidator\w*\s*=\s*\([^)]*\)\s*=>[^;]*'([^']*)'"),
];

/// Le littéral [s] est-il un **texte à traduire** ?
///
/// 🔒 Une **interpolation pure** n'en est pas un : `Text('$count')` ou
/// `Text('${data.correct}/${data.total}')` rendent un **nombre**, pas de la
/// prose — les bannir serait un faux positif, et une garde qui crie au loup est
/// une garde qu'on désactive. On retire donc les interpolations, puis on ne
/// retient que ce qui porte encore une **lettre** (accents inclus : « Réponse
/// requise » comme « required »).
bool _isTranslatable(String s) => s
    .replaceAll(RegExp(r'\$\{[^}]*\}'), '')
    .replaceAll(RegExp(r'\$\w+'), '')
    .contains(RegExp(r'[A-Za-zÀ-ÖØ-öø-ÿ]'));

/// Recolle les **déclarations** d'un source Dart (même technique et même raison
/// que `z_widgets_purity_test.dart`).
///
/// 🔴 **SU-3 (T4bis) — défaut D4** : ce scan était **LIGNE-À-LIGNE**, donc
/// **aveugle** au wrapping de `dart format` (80 colonnes) :
///
/// ```dart
/// padding: const EdgeInsets.only(
///     left: 8),        // ← AUCUNE ligne ne contient 'EdgeInsets.only(left:'
/// ```
///
/// C'est la forme **naturelle** d'un appel un peu long — et c'est précisément
/// une violation RTL (AD-13) qui serait passée. On raisonne par **déclaration**.
List<({int line, String text})> _declarations(String path) {
  final lines = File(path).readAsLinesSync();
  final out = <({int line, String text})>[];
  final buffer = StringBuffer();
  var startLine = 0;
  var inBlockComment = false;

  void flush() {
    if (buffer.isNotEmpty) {
      out.add((line: startLine, text: buffer.toString()));
      buffer.clear();
    }
  }

  for (var i = 0; i < lines.length; i++) {
    var trimmed = lines[i].trim();

    if (inBlockComment) {
      if (trimmed.contains('*/')) {
        inBlockComment = false;
        trimmed = trimmed.substring(trimmed.indexOf('*/') + 2).trim();
      } else {
        continue;
      }
    }
    if (trimmed.startsWith('/*')) {
      if (!trimmed.contains('*/')) {
        inBlockComment = true;
        continue;
      }
      trimmed = trimmed.substring(trimmed.indexOf('*/') + 2).trim();
    }
    // Les lignes de commentaire/doc ne sont pas du code : elles CITENT
    // légitimement les motifs interdits (ex. « jamais de `Colors.*` »).
    if (trimmed.startsWith('//') || trimmed.startsWith('*')) continue;
    final slash = trimmed.indexOf('//');
    if (slash >= 0) trimmed = trimmed.substring(0, slash).trim();
    if (trimmed.isEmpty) continue;

    if (buffer.isEmpty) startLine = i + 1;
    // Recollage SANS espace : `EdgeInsets.only(\n    left: 8)` doit redevenir
    // `EdgeInsets.only(left: 8)`.
    buffer.write(trimmed);

    if (trimmed.endsWith(';') ||
        trimmed.endsWith('{') ||
        trimmed.endsWith('}')) {
      flush();
    }
  }
  flush();
  return out;
}

List<String> _scan(List<String> patterns) {
  final files = _presentationFiles();
  // Contre-preuve R12 : le scan DOIT réellement voir des fichiers (une garde
  // qui ne scanne rien serait verte pour de mauvaises raisons).
  expect(files, isNotEmpty, reason: 'aucun fichier de présentation scanné');

  final violations = <String>[];
  for (final path in files) {
    for (final decl in _declarations(path)) {
      for (final pattern in patterns) {
        if (decl.text.contains(pattern)) {
          violations.add('$path:${decl.line} → $pattern :: ${decl.text}');
        }
      }
    }
  }
  return violations;
}

/// Applique les règles de libellé à **une** déclaration recollée, et rend les
/// noms des règles violées.
///
/// 🔒 Chaque règle **capture le littéral** et ne le retient que s'il est
/// [_isTranslatable] : un simple préfixe (`Text('`) confondrait « required »
/// (défaut) et `'$count'` (légitime).
List<String> _userStringViolations(String declText) {
  final out = <String>[];
  for (final rule in _bannedUserStringRules) {
    for (final m in RegExp(rule.pattern).allMatches(declText)) {
      if (_isTranslatable(m.group(1)!)) out.add(rule.name);
    }
  }
  for (final re in _bannedValidatorLiterals) {
    final v = re.firstMatch(declText);
    if (v != null && _isTranslatable(v.group(1)!)) {
      out.add('validateur rendant un LITTÉRAL (son message part en errorText)');
      break;
    }
  }
  return out;
}

/// Scan des **libellés utilisateur en dur** (AC11) sur `presentation/**`.
List<String> _scanUserStrings() {
  final files = _presentationFiles();
  expect(files, isNotEmpty, reason: 'aucun fichier de présentation scanné');

  final violations = <String>[];
  for (final path in files) {
    for (final decl in _declarations(path)) {
      for (final name in _userStringViolations(decl.text)) {
        violations.add('$path:${decl.line} → $name :: ${decl.text}');
      }
    }
  }
  return violations;
}

void main() {
  test('AC4 — aucune couleur en dur (Colors./Color(0x/AppColors.)', () {
    final violations = _scan(_bannedColorPatterns);
    expect(
      violations,
      isEmpty,
      reason: 'couleur codée en dur détectée :\n${violations.join('\n')}',
    );
  });

  test('AC5 — aucune API non-directionnelle ni ListView(children:)', () {
    final violations = _scan(_bannedDirectionalPatterns);
    expect(
      violations,
      isEmpty,
      reason:
          'API non-directionnelle / ListView(children:) :\n${violations.join('\n')}',
    );
  });

  test(
    '🔴 AC11 — aucun libellé UTILISATEUR en dur (trou de garde su-3 fermé)',
    () {
      final violations = _scanUserStrings();
      expect(
        violations,
        isEmpty,
        reason:
            'libellé utilisateur codé en dur — utiliser '
            '`label(context, \'zcrud.…\', fallback: \'…\')` :\n'
            '${violations.join('\n')}',
      );
    },
  );

  group('🔬 contre-preuve R12 — le scanner SAIT rougir (défaut D6)', () {
    // ⚠️ D6 : on exerce le VRAI `_declarations` sur un VRAI fichier — on ne
    // ré-implémente pas le scanner (ce serait tester sa propre copie).
    late Directory tmp;

    setUp(() => tmp = Directory.systemTemp.createTempSync('z_hardcode_probe'));
    tearDown(() => tmp.deleteSync(recursive: true));

    bool detects(String source, String pattern) {
      final f = File('${tmp.path}/probe.dart')..writeAsStringSync(source);
      return _declarations(f.path).any((d) => d.text.contains(pattern));
    }

    test('une couleur en dur SUR UNE LIGNE est captée', () {
      expect(detects('final c = Colors.red;', 'Colors.'), isTrue);
    });

    test('🔴 une API non-directionnelle COUPÉE PAR dart format est captée — '
        'défaut D4 RÉELLEMENT fermé', () {
      // ⚠️ Sortie VERBATIM de `dart format --line-length 80` sur
      // `SomeWidget(padding: const EdgeInsets.only(left: <expression longue>))`
      // — rejouée sur disque, pas imaginée. C'est l'angle mort D4 AUTHENTIQUE :
      // le motif `EdgeInsets.only(left:` ne survit sur AUCUNE ligne, alors que
      // le code EST une violation RTL (AD-13).
      const wrapped = '''
final w = SomeWidget(
  padding: const EdgeInsets.only(
    left: someVeryLongValueName + anotherQuiteLongValueName,
  ),
);
''';
      expect(
        wrapped.split('\n').any((l) => l.contains('EdgeInsets.only(left:')),
        isFalse,
        reason:
            'aucune LIGNE ne porte le motif ⇒ le scan ligne-à-ligne était '
            'STRUCTURELLEMENT aveugle sur cette forme (mesuré)',
      );
      expect(
        detects(wrapped, 'EdgeInsets.only(left:'),
        isTrue,
        reason: 'le recollage par déclaration, lui, le voit',
      );
    });

    test(
      '🔴 un `Color(0x…)` coupé par dart format est capté (angle mort RÉEL)',
      () {
        // Idem : sortie verbatim du formateur sur un argument long.
        const wrapped = '''
final c = SomeWidget(
  color: Color(
    0xFF00AA00 + someOffsetValueThatIsLong + anotherOffsetValueHere,
  ),
);
''';
        expect(
          wrapped.split('\n').any((l) => l.contains('Color(0x')),
          isFalse,
          reason:
              'angle mort D4 authentique : une couleur EN DUR invisible au '
              'scan ligne-à-ligne',
        );
        expect(detects(wrapped, 'Color(0x'), isTrue);
      },
    );

    test(
      'un COMMENTAIRE citant un motif interdit n\'est PAS une violation',
      () {
        expect(
          detects('// jamais de Colors.red ici\nfinal x = 1;', 'Colors.'),
          isFalse,
        );
        expect(
          detects(
            '/// AD-13 : TextAlign.left interdit\nfinal x = 1;',
            'TextAlign.left',
          ),
          isFalse,
        );
      },
    );

    // 🔬 Contre-preuves de la garde NEUVE (AC11 — libellés). Même discipline D6 :
    // on exerce le **VRAI** `_declarations` et les **VRAIS** motifs sur de VRAIS
    // fichiers — on ne ré-implémente rien.

    /// Rejoue le scan de libellés sur une source arbitraire — via le **VRAI**
    /// `_declarations` et les **VRAIES** règles (D6 : jamais une ré-implémentation).
    List<String> scanUserStringsOf(String source) {
      final f = File('${tmp.path}/probe.dart')..writeAsStringSync(source);
      return <String>[
        for (final decl in _declarations(f.path))
          ..._userStringViolations(decl.text),
      ];
    }

    test(
      '🔴 LE DÉFAUT su-3 EXACT est capté : un validateur rendant `\'required\'`',
      () {
        // Copie VERBATIM du code livré par su-3 (`z_flashcard_answer_input.dart`,
        // ancien `_WrittenInput._validate`) — celui qui affichait « required » en
        // anglais à un apprenant francophone. La garde d'alors ne le voyait pas.
        const defect = '''
class W {
  static String? _validate(String? value) =>
      (value == null || value.trim().isEmpty) ? 'required' : null;
}
''';
        expect(
          scanUserStringsOf(defect),
          contains(
            'validateur rendant un LITTÉRAL (son message part en errorText)',
          ),
          reason: '🔴 si ceci ne rougit pas, le prochain « required » repasse',
        );
      },
    );

    test('🔴 le défaut REJOUÉ SUR LA FORME CORRIGÉE est capté aussi '
        '(la garde d\'hier ne suffit pas)', () {
      // ⚠️ Mesuré : ma première version de cette garde n'ancrait que la
      // signature `String? _validate(…)` — la forme livrée par su-3. Rejouer
      // l'injection `'required'` sur le code CORRIGÉ (une closure affectée à
      // `_cachedValidator`) laissait le scan **VERT**. Une garde qui n'attrape
      // que le défaut d'hier est une garde qui laissera passer celui de demain.
      const regressed = '''
class S {
  FormFieldValidator<String> _requiredValidator(BuildContext context) {
    final text = label(context, 'zcrud.x', fallback: 'Réponse requise');
    _cachedValidator = (value) =>
        (value == null || value.trim().isEmpty) ? 'required' : null;
    return _cachedValidator!;
  }
}
''';
      expect(
        scanUserStringsOf(regressed),
        contains(
          'validateur rendant un LITTÉRAL (son message part en errorText)',
        ),
      );
    });

    test(
      '🔒 une INTERPOLATION PURE n\'est PAS un libellé (`Text(\'\$count\')`) — '
      'sinon la garde crie au loup et finit désactivée',
      () {
        expect(scanUserStringsOf("final w = Text('\$count');"), isEmpty);
        expect(
          scanUserStringsOf(
            "final w = Text('\${data.correct}/\${data.total}');",
          ),
          isEmpty,
          reason:
              'ces deux formes existent RÉELLEMENT dans '
              '`z_session_quality_breakdown.dart` et `z_study_progress_rings.dart` '
              '— elles rendent un NOMBRE, pas de la prose',
        );
        // …mais de la prose AUTOUR d'une interpolation reste une violation.
        expect(
          scanUserStringsOf("final w = Text('il reste \$n cartes');"),
          contains('Text(\'…\') — libellé en dur affiché'),
        );
      },
    );

    test('🔴 un `Text(\'…\')` en dur est capté, MÊME coupé par dart format', () {
      expect(
        scanUserStringsOf("final w = Text('Bonjour');"),
        contains('Text(\'…\') — libellé en dur affiché'),
      );
      // Sortie verbatim du formateur sur un argument long : aucune LIGNE ne
      // porte `Text('` — seul le recollage par déclaration le voit (défaut D4).
      const wrapped = '''
final w = Padding(
  padding: EdgeInsets.zero,
  child: Text(
    'Un libellé assez long pour que le formateur le passe à la ligne',
  ),
);
''';
      expect(
        wrapped.split('\n').any((l) => l.contains("Text('")),
        isFalse,
        reason:
            'aucune LIGNE ne porte le motif ⇒ un scan ligne-à-ligne serait '
            'STRUCTURELLEMENT aveugle sur cette forme',
      );
      expect(
        scanUserStringsOf(wrapped),
        contains('Text(\'…\') — libellé en dur affiché'),
      );
    });

    test(
      '🔴 un `errorText:`/`hintText:` en dur est capté (espaces indifférents)',
      () {
        expect(
          scanUserStringsOf("final w = F(errorText: 'requis');"),
          contains('errorText: \'…\' en dur'),
        );
        expect(
          scanUserStringsOf("final w = F(hintText:'tapez ici');"),
          contains('hintText: \'…\' en dur'),
        );
      },
    );

    test('🔒 le patron SANCTIONNÉ ne rougit PAS (sinon la garde serait désactivée '
        'sous les faux positifs)', () {
      // Le patron l10n officiel : clé + fallback, tous deux littéraux LÉGITIMES.
      expect(
        scanUserStringsOf(
          "final w = Text(label(context, 'zcrud.flashcard.hint', "
          "fallback: 'Indice'));",
        ),
        isEmpty,
      );
      // Un `Text` sur variable, une clé de test, un `padLeft` : tous légitimes.
      expect(scanUserStringsOf('final w = Text(hint);'), isEmpty);
      expect(
        scanUserStringsOf(
          "static const ValueKey<String> k = ValueKey<String>('zSubmit');",
        ),
        isEmpty,
      );
      expect(
        scanUserStringsOf("final s = d.inMinutes.toString().padLeft(2, '0');"),
        isEmpty,
      );
      // Le validateur CORRIGÉ (message résolu par `label`, passé en variable).
      expect(
        scanUserStringsOf(
          'FormFieldValidator<String> v(String text) => (value) => '
          '(value == null || value.trim().isEmpty) ? text : null;',
        ),
        isEmpty,
      );
    });

    test(
      'un COMMENTAIRE citant un libellé en dur n\'est PAS une violation',
      () {
        expect(
          scanUserStringsOf("// jamais de Text('Bonjour') ici\nfinal x = 1;"),
          isEmpty,
        );
      },
    );
  });
}
