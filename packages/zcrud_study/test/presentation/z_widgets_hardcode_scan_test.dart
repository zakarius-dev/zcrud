/// ZÉRO couleur / libellé en dur, ZÉRO API non-directionnelle dans les widgets
/// de `zcrud_study` (SU-8/AC20 — FR-26/AD-6/AD-13).
///
/// ## Pourquoi CRÉÉE ici (extension de couverture, pas duplication)
///
/// La garde jumelle n'existait **que** dans `zcrud_session` et scanne
/// `Directory('lib/src/presentation')` **de son propre package** (chemin
/// RELATIF) : elle ne peut **structurellement pas** couvrir `zcrud_study`, et
/// `zcrud_session` ne dépend pas de `zcrud_study`. Mesuré avant écriture :
/// `zcrud_study/lib/src/presentation` était **déjà conforme** — cette garde
/// **verrouille** un état sain, elle ne légalise aucune dette.
///
/// **N'énumère JAMAIS une liste figée** : scan récursif ⇒ tout futur widget est
/// capté sans édition du test (R16).
///
/// ⚠️ **PORTÉE DÉCLARÉE HONNÊTEMENT — et volontairement ÉTROITE** (patron
/// `zcrud_session`). Elle ne prétend **pas** détecter « toute chaîne en dur » :
/// la plupart des littéraux sont **légitimes** (`ValueKey('tile-…')`, clés
/// opaques, `'flashcards'`). Elle vise les **PUITS RÉELLEMENT RENDUS**, où un
/// littéral est **toujours** un défaut : le 1ᵉʳ argument de `Text(`, et les
/// arguments nommés qui rendent du texte (`hintText:`, `tooltip:`,
/// `semanticLabel:`…).
///
/// Ce qu'elle **ne voit pas** (consigné, non prétendu) : un littéral passé par
/// une variable intermédiaire (`final s = 'Bonjour'; … Text(s)`).
///
/// Accès `dart:io` ⇒ `@TestOn('vm')`.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Énumère RÉCURSIVEMENT tous les `.dart` de `lib/src/presentation/**`.
List<String> _presentationFiles() {
  const root = 'lib/src/presentation';
  final dir = Directory(root);
  expect(dir.existsSync(), isTrue,
      reason: 'répertoire introuvable: $root (cwd=${Directory.current.path}) — '
          '⚠️ `flutter test` doit être lancé DEPUIS le package');
  return dir
      .listSync(recursive: true)
      .whereType<File>()
      .map((f) => f.path)
      .where((p) => p.endsWith('.dart'))
      .toList()
    ..sort();
}

/// Motifs de **couleur en dur** interdits (FR-26/AD-6).
const List<String> _bannedColorPatterns = <String>[
  'Colors.',
  'Color(0x',
  'AppColors.',
];

/// Motifs **non-directionnels** interdits (AD-13 — RTL).
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

/// Puits **réellement rendus à l'écran** : un littéral y est toujours un défaut.
final List<({String name, RegExp pattern})> _bannedUserStringRules =
    <({String name, RegExp pattern})>[
  (name: "Text('…') — libellé en dur affiché", pattern: RegExp(r"Text\(\s*'([^']*)'")),
  (name: 'Text("…") — libellé en dur affiché', pattern: RegExp(r'Text\(\s*"([^"]*)"')),
  (name: "hintText: '…' en dur", pattern: RegExp(r"hintText:\s*'([^']*)'")),
  (name: "labelText: '…' en dur", pattern: RegExp(r"labelText:\s*'([^']*)'")),
  (name: "errorText: '…' en dur", pattern: RegExp(r"errorText:\s*'([^']*)'")),
  (name: "tooltip: '…' en dur", pattern: RegExp(r"tooltip:\s*'([^']*)'")),
  (name: "semanticLabel: '…' en dur", pattern: RegExp(r"semanticLabel:\s*'([^']*)'")),
  (name: "Semantics(label: '…') en dur", pattern: RegExp(r"label:\s*'([^']*)'")),
  // 🔴 su-9 D2 — forme DÉFAUT DE CONSTRUCTEUR (`= '…'`), invisible aux règles
  // ci-dessus (site d'ARGUMENT `nom: '…'`). Un libellé de saisie de tag RENDU
  // (`inputLabel`→`labelText`, `inputHint`→`hintText`, `addSemanticLabel`→
  // `tooltip`/`semanticLabel`) fixé en défaut FR fuit en français dans une app
  // anglaise SANS voie d'override — récidive fermée à la RACINE (`ZTagEditor`) et
  // dans la feuille de confirmation su-9 (les 3 sont désormais REQUIS).
  (
    name: "inputLabel = '…' (défaut de constructeur en dur)",
    pattern: RegExp(r"\binputLabel\s*=\s*'([^']*)'")
  ),
  (
    name: "inputHint = '…' (défaut de constructeur en dur)",
    pattern: RegExp(r"\binputHint\s*=\s*'([^']*)'")
  ),
  (
    name: "addSemanticLabel = '…' (défaut de constructeur en dur)",
    pattern: RegExp(r"\baddSemanticLabel\s*=\s*'([^']*)'")
  ),
];

/// Motifs de **dimension typographique en dur** interdits (a11y / thème — R2).
///
/// Un `fontSize:` **littéral** (nombre) ignore la mise à l'échelle du texte
/// (`textScaler` — a11y) et code une taille **hors thème** (FR-26/AD-13). La
/// taille doit venir d'un `TextStyle` de thème (`Theme.of(context).textTheme.*`,
/// `ZcrudTheme`). Un `fontSize: theme.x` (variable) reste légitime — la garde ne
/// vise **QUE** le nombre en dur (`\s*[0-9]`), jamais une variable.
///
/// ⚠️ Le scan ligne-à-ligne jumeau (`zcrud_session`, comme cette garde) ne
/// regardait QUE couleurs + API non-directionnelles : un `fontSize: 11` passait
/// **invisible** (défaut réel de su-8, 3 sites). Cette règle ferme ce trou —
/// **extension** de la garde existante, pas une garde parallèle.
final List<({String name, RegExp pattern})> _bannedHardcodedStyleRules =
    <({String name, RegExp pattern})>[
  (name: 'fontSize: littéral en dur', pattern: RegExp(r'fontSize:\s*[0-9]')),
];

/// **Scanner RÉEL** des dimensions typographiques en dur — partagé avec les
/// contre-preuves.
List<String> scanForHardcodedStyle(List<String> lines, String path) {
  final violations = <String>[];
  for (var i = 0; i < lines.length; i++) {
    final raw = lines[i];
    final trimmed = raw.trimLeft();
    if (trimmed.startsWith('///') || trimmed.startsWith('//')) continue;
    for (final rule in _bannedHardcodedStyleRules) {
      if (rule.pattern.hasMatch(raw)) {
        violations.add('$path:${i + 1} → ${rule.name} : « ${raw.trim()} »');
      }
    }
  }
  return violations;
}

/// Le littéral [s] est-il un **texte à traduire** ?
///
/// 🔒 Une **interpolation pure** n'en est pas un : `Text('$threshold')` rend un
/// **nombre**, pas de la prose — le bannir serait un faux positif, et une garde
/// qui crie au loup est une garde qu'on désactive. On retire donc les
/// interpolations, puis on ne retient que ce qui porte encore une **lettre**
/// (accents inclus : « Réponse requise » comme « required »).
bool isTranslatable(String s) {
  final withoutInterpolation = s
      .replaceAll(RegExp(r'\$\{[^}]*\}'), '')
      .replaceAll(RegExp(r'\$\w+'), '');
  return RegExp(r'[a-zA-ZÀ-ÿ]').hasMatch(withoutInterpolation);
}

/// **Scanner RÉEL** des motifs simples — partagé avec les contre-preuves.
List<String> scanForPatterns(
  List<String> lines,
  String path,
  List<String> patterns,
) {
  final violations = <String>[];
  for (var i = 0; i < lines.length; i++) {
    final raw = lines[i];
    final trimmed = raw.trimLeft();
    if (trimmed.startsWith('///') || trimmed.startsWith('//')) continue;
    for (final pattern in patterns) {
      if (raw.contains(pattern)) {
        violations.add('$path:${i + 1} → « $pattern » dans « ${raw.trim()} »');
      }
    }
  }
  return violations;
}

/// **Scanner RÉEL** des libellés utilisateur — partagé avec les contre-preuves.
List<String> scanForUserStrings(List<String> lines, String path) {
  final violations = <String>[];
  for (var i = 0; i < lines.length; i++) {
    final raw = lines[i];
    final trimmed = raw.trimLeft();
    if (trimmed.startsWith('///') || trimmed.startsWith('//')) continue;

    for (final rule in _bannedUserStringRules) {
      for (final m in rule.pattern.allMatches(raw)) {
        final literal = m.group(1) ?? '';
        if (!isTranslatable(literal)) continue; // interpolation pure / clé
        violations.add('$path:${i + 1} → ${rule.name} : « $literal »');
      }
    }
  }
  return violations;
}

void main() {
  group('AC20/FR-26 — ZÉRO couleur en dur', () {
    test('aucun Colors./Color(0x dans la présentation', () {
      final files = _presentationFiles();
      expect(files, isNotEmpty, reason: 'sonde cassée : aucun fichier scanné');

      final violations = <String>[];
      for (final path in files) {
        violations.addAll(scanForPatterns(
            File(path).readAsLinesSync(), path, _bannedColorPatterns));
      }

      expect(violations, isEmpty,
          reason: '🔴 couleur codée en dur :\n${violations.join('\n')}\n'
              'FR-26 : le thème est INJECTÉ (`ZcrudTheme.of`, repli '
              '`Theme.of`) — une couleur en dur casse le thème sombre de '
              'l\'app hôte et son contraste.');
    });
  });

  group('AC20/AD-13 — ZÉRO API non-directionnelle (RTL)', () {
    test('aucun left:/right:/centerLeft… ni ListView(children:)', () {
      final violations = <String>[];
      for (final path in _presentationFiles()) {
        violations.addAll(scanForPatterns(
            File(path).readAsLinesSync(), path, _bannedDirectionalPatterns));
      }

      expect(violations, isEmpty,
          reason: '🔴 API non-directionnelle :\n${violations.join('\n')}\n'
              'AD-13 : `EdgeInsetsDirectional`/`AlignmentDirectional`/'
              '`TextAlign.start|end` — sinon l\'UI est cassée en arabe. '
              '`ListView(children:)` matérialise TOUT (jamais virtualisé).');
    });
  });

  group('🔴 AC20 — ZÉRO libellé utilisateur en dur', () {
    test('aucun Text(\'…\')/hintText:/tooltip:/label: littéral', () {
      final violations = <String>[];
      for (final path in _presentationFiles()) {
        violations.addAll(scanForUserStrings(File(path).readAsLinesSync(), path));
      }

      expect(violations, isEmpty,
          reason: '🔴 libellé en dur :\n${violations.join('\n')}\n'
              'Les libellés sont INJECTÉS (patron `ZItemActionsMenu.label`, '
              '`ZFlashcardListLabels`) — un libellé en dur s\'afficherait en '
              'français dans une app anglaise, sans qu\'aucun test ne rougisse.');
    });
  });

  group('🔴 R2 — ZÉRO dimension typographique en dur', () {
    test('aucun fontSize: littéral dans la présentation', () {
      final violations = <String>[];
      for (final path in _presentationFiles()) {
        violations.addAll(
            scanForHardcodedStyle(File(path).readAsLinesSync(), path));
      }

      expect(violations, isEmpty,
          reason: '🔴 taille de police en dur :\n${violations.join('\n')}\n'
              'La taille vient du thème (`textTheme.labelSmall`, `ZcrudTheme`) '
              '— un `fontSize:` littéral ignore la mise à l\'échelle du texte '
              '(a11y) et casse le thème (FR-26/AD-13).');
    });
  });

  group('🔴 CONTRE-PREUVES — les scanners RÉELS ne sont pas aveugles', () {
    test('une couleur en dur est ATTRAPÉE', () {
      expect(
        scanForPatterns(
            <String>['  color: Colors.red,'], 'f.dart', _bannedColorPatterns),
        isNotEmpty,
      );
    });

    test('une API non-directionnelle est ATTRAPÉE', () {
      expect(
        scanForPatterns(<String>['  padding: EdgeInsets.only(left: 8),'],
            'f.dart', _bannedDirectionalPatterns),
        isNotEmpty,
      );
    });

    test('🔴 un libellé en dur est ATTRAPÉ', () {
      expect(scanForUserStrings(<String>["      Text('Bonjour'),"], 'f.dart'),
          isNotEmpty);
      expect(scanForUserStrings(<String>["  hintText: 'Rechercher',"], 'f.dart'),
          isNotEmpty);
    });

    test('🔴 su-9 D2 — un DÉFAUT DE CONSTRUCTEUR `= \'…\'` est ATTRAPÉ', () {
      // La forme qui échappait aux règles de site d'argument (su-9 D2) : un
      // libellé de saisie de tag fixé en défaut FR. Prouve que la garde n'est
      // PAS aveugle à `= '…'` — sinon la prochaine récidive repasserait.
      expect(
          scanForUserStrings(<String>["    this.inputLabel = 'Nom du tag',"], 'f.dart'),
          isNotEmpty);
      expect(
          scanForUserStrings(<String>["    this.inputHint = 'Ajouter un tag',"], 'f.dart'),
          isNotEmpty);
      expect(
          scanForUserStrings(
              <String>["    this.addSemanticLabel = 'Ajouter le tag',"], 'f.dart'),
          isNotEmpty);
      // …mais un défaut REQUIS (pas de littéral) ne déclenche PAS de faux positif.
      expect(scanForUserStrings(<String>["    required this.inputLabel,"], 'f.dart'),
          isEmpty);
    });

    test('🔴 un fontSize: en dur est ATTRAPÉ (une variable ne l\'est PAS)', () {
      // Le nombre en dur est capté…
      expect(
        scanForHardcodedStyle(
            <String>['      style: TextStyle(color: c, fontSize: 11),'],
            'f.dart'),
        isNotEmpty,
      );
      // …mais une taille issue du thème (variable) n'est PAS un faux positif :
      // une garde qui crie au loup est une garde qu'on désactive.
      expect(
        scanForHardcodedStyle(
            <String>['      style: TextStyle(fontSize: theme.captionSize),'],
            'f.dart'),
        isEmpty,
      );
    });

    test('🔴 une interpolation PURE n\'est PAS un faux positif', () {
      // `Text('$threshold')` rend un NOMBRE — le bannir ferait crier la garde au
      // loup, et une garde qui crie au loup est une garde qu'on désactive.
      expect(scanForUserStrings(<String>["      Text('\$threshold'),"], 'f.dart'),
          isEmpty);
      expect(
        scanForUserStrings(
            <String>["      Text('\${data.correct}/\${data.total}'),"], 'f.dart'),
        isEmpty,
      );
    });

    test('la prose peut montrer les motifs sans faire rougir', () {
      final proseOnly = <String>[
        "/// Jamais `Colors.red` ni `Text('Bonjour')` — FR-26/AD-13.",
        "// EdgeInsets.only(left: 8) est interdit : utiliser Directional.",
        "// jamais un `fontSize: 11` littéral (a11y) — utiliser le thème.",
      ];
      expect(
          scanForPatterns(proseOnly, 'p.dart', _bannedColorPatterns), isEmpty);
      expect(scanForPatterns(proseOnly, 'p.dart', _bannedDirectionalPatterns),
          isEmpty);
      expect(scanForUserStrings(proseOnly, 'p.dart'), isEmpty);
      expect(scanForHardcodedStyle(proseOnly, 'p.dart'), isEmpty);
    });
  });
}
