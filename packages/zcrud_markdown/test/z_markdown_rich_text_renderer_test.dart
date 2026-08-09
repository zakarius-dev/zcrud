/// Gardes de `ZMarkdownRichTextRenderer` — moteur Markdown du port
/// `ZRichTextRenderer` de `zcrud_core` (DP-RT).
///
/// Ce que ces gardes éprouvent, et pourquoi :
///  * le **déclin** (`null`) sur chacun des quatre cas prévus — c'est le chemin
///    par lequel l'appelant retombe sur son repli texte, et il vaut mieux que
///    n'importe quelle approximation ;
///  * le **style de base honoré**, avec la précaution qui rend la garde non
///    vacante : le `baseStyle` attendu est d'abord asserté DIFFÉRENT du style
///    ambiant ET du plancher Quill, sinon la mesure ne prouverait rien ;
///  * la **sémantique** du rendu riche comparée au repli texte simple, comptée
///    en OCCURRENCES de mots et non en nœuds (un `Semantics` posé sur du texte
///    fusionne, il ne crée pas de nœud : compter les nœuds serait faux) ;
///  * **AD-2/SM-1** : le controller Quill du rendu n'est pas recréé au rebuild
///    de l'hôte ;
///  * **FR-26** : aucune couleur ni libellé en dur dans le fichier source.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_markdown/zcrud_markdown.dart';

/// Localise un fichier source du paquet, quel que soit l'ancrage du run.
File _srcFile(String relative) {
  for (final base in <String>['.', '../zcrud_markdown', 'packages/zcrud_markdown']) {
    final f = File('$base/$relative');
    if (f.existsSync()) return f;
  }
  fail('Introuvable: $relative (cwd ${Directory.current.path})');
}

/// Codec qui LÈVE — un `ZCodec` injecté par un hôte peut ne pas tenir la
/// promesse défensive du contrat. Rien ne doit s'échapper du `build` (AD-10).
class _ThrowingCodec implements ZCodec {
  const _ThrowingCodec();

  @override
  Object? encode(List<Map<String, dynamic>> deltaOps) => '';

  @override
  List<Map<String, dynamic>> decode(Object? persisted) =>
      throw StateError('codec hostile');
}

/// Codec qui ne décode RIEN (le contrat `ZCodec` prescrit `[]` sur illisible).
class _EmptyCodec implements ZCodec {
  const _EmptyCodec();

  @override
  Object? encode(List<Map<String, dynamic>> deltaOps) => '';

  @override
  List<Map<String, dynamic>> decode(Object? persisted) =>
      const <Map<String, dynamic>>[];
}

/// Monte [child] et retourne le `BuildContext` d'où appeler `build`.
Future<BuildContext> _pumpHost(
  WidgetTester tester, {
  ThemeData? theme,
  required Widget Function(BuildContext context) builder,
}) async {
  late BuildContext captured;
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Scaffold(
        body: Builder(
          builder: (context) {
            captured = context;
            return builder(context);
          },
        ),
      ),
    ),
  );
  return captured;
}

/// Collecte les libellés de TOUS les nœuds sémantiques de l'arbre monté.
List<String> _semanticLabels(WidgetTester tester) {
  final SemanticsNode root = tester.getSemantics(find.byType(Scaffold));
  final labels = <String>[];
  void walk(SemanticsNode node) {
    if (node.label.isNotEmpty) labels.add(node.label);
    node.visitChildren((child) {
      walk(child);
      return true;
    });
  }

  walk(root);
  return labels;
}

/// Fragments de texte rendus, avec leur style **effectif**.
///
/// 🔴 Mesuré : le style d'une ligne Quill vit sur le span RACINE du `RichText`,
/// les spans feuilles ne portant que les DEVIATIONS d'attribut (gras, code…).
/// Lire la seule feuille rendrait `null` — une garde qui s'en contenterait
/// mesurerait le vide.
List<({String text, TextStyle style})> _renderedRuns(WidgetTester tester) {
  final runs = <({String text, TextStyle style})>[];
  for (final RichText rt in tester.widgetList<RichText>(find.byType(RichText))) {
    final TextStyle root = rt.text.style ?? const TextStyle();
    rt.text.visitChildren((InlineSpan span) {
      if (span is TextSpan && (span.text ?? '').isNotEmpty) {
        runs.add((text: span.text!, style: root.merge(span.style)));
      }
      return true;
    });
  }
  return runs;
}

void main() {
  // ────────────────────────────── Contrat du port ─────────────────────────────

  test('le renderer EST une implémentation `const` du port', () {
    const ZRichTextRenderer renderer = ZMarkdownRichTextRenderer();
    expect(renderer, isA<ZRichTextRenderer>());
    // `const` canonicalisé : deux instances `const` sont la MÊME (aucune
    // allocation à l'injection dans `ZcrudScope`).
    expect(
      identical(const ZMarkdownRichTextRenderer(),
          const ZMarkdownRichTextRenderer()),
      isTrue,
    );
  });

  // ────────────────────────────── Les quatre déclins ──────────────────────────

  testWidgets('DÉCLINE (null) une source vide ou uniquement blanche',
      (tester) async {
    late final List<Widget?> results;
    await _pumpHost(tester, builder: (context) {
      const renderer = ZMarkdownRichTextRenderer();
      results = <Widget?>[
        renderer.build(context, ''),
        renderer.build(context, '   '),
        renderer.build(context, '\n\n  \t '),
      ];
      return const SizedBox.shrink();
    });
    expect(results, everyElement(isNull));
  });

  testWidgets('DÉCLINE (null) un texte PUR — le repli de l\'appelant est '
      'strictement équivalent et moins cher', (tester) async {
    late final Widget? result;
    late final Widget? multi;
    await _pumpHost(tester, builder: (context) {
      const renderer = ZMarkdownRichTextRenderer();
      result = renderer.build(context, 'Informations légales');
      // Mesuré chez DODLP : la majorité des `stepSubtitle` sont de cette forme,
      // y compris sur plusieurs paragraphes.
      multi = renderer.build(context, 'Premier para.\n\nSecond para.');
      return const SizedBox.shrink();
    });
    expect(result, isNull);
    expect(multi, isNull);
  });

  testWidgets('DÉCLINE (null) une source qui porte un EMBED (tableau, filet)',
      (tester) async {
    late final Widget? table;
    late final Widget? rule;
    await _pumpHost(tester, builder: (context) {
      const renderer = ZMarkdownRichTextRenderer();
      table = renderer.build(context, '| a | b |\n| --- | --- |\n| 1 | 2 |');
      rule = renderer.build(context, 'Avant\n\n---\n\nAprès');
      return const SizedBox.shrink();
    });
    expect(table, isNull, reason: 'un tableau réclame une place de bloc');
    expect(rule, isNull, reason: 'un filet réclame une place de bloc');
  });

  testWidgets('DÉCLINE (null) SANS LEVER quand le codec injecté lève (AD-10)',
      (tester) async {
    // 🔴 L'appel est enveloppé ICI, dans la garde, pour que le défaut se
    // manifeste en ASSERTION (`escaped` non nul) et non en `LateError` : un
    // rouge d'exception ne dirait pas QUOI a échoué.
    Widget? result;
    Object? escaped;
    await _pumpHost(tester, builder: (context) {
      const renderer = ZMarkdownRichTextRenderer(codec: _ThrowingCodec());
      try {
        result = renderer.build(context, '**gras**');
      } catch (error) {
        escaped = error;
      }
      return const SizedBox.shrink();
    });
    expect(escaped, isNull,
        reason: 'aucune exception ne doit s\'échapper de `build` (AD-10)');
    expect(result, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('DÉCLINE (null) quand le codec ne décode RIEN', (tester) async {
    late final Widget? result;
    await _pumpHost(tester, builder: (context) {
      const renderer = ZMarkdownRichTextRenderer(codec: _EmptyCodec());
      result = renderer.build(context, 'peu importe');
      return const SizedBox.shrink();
    });
    expect(result, isNull);
  });

  // ────────────────────────── Ce qu'il rend VRAIMENT ──────────────────────────

  testWidgets('REND les quatre constructions mesurées chez DODLP : gras, '
      'liste à puces, liste numérotée, paragraphe enrichi', (tester) async {
    final rendered = <String, Widget?>{};
    await _pumpHost(tester, builder: (context) {
      const renderer = ZMarkdownRichTextRenderer();
      rendered['gras'] = renderer.build(context, '**Procédure :**');
      rendered['puces'] = renderer.build(context, '- Certifier\n- Empêcher');
      rendered['numérotée'] =
          renderer.build(context, '1. Vérifier\n2. Apposer');
      rendered['mixte'] = renderer.build(
          context, 'Texte\n\n**Procédure :**\n\n1. Vérifier\n2. Signer');
      return const SizedBox.shrink();
    });
    for (final entry in rendered.entries) {
      expect(entry.value, isNotNull, reason: 'construction « ${entry.key} »');
    }
  });

  // ──────────────────────────── Style de base honoré ──────────────────────────

  testWidgets('le baseStyle demandé se retrouve DANS le rendu (et il diffère '
      'de l\'ambiant ET du plancher Quill — garde non vacante)', (tester) async {
    // 🔴 Anti-vacance : l'ambiant est à 21, le plancher paragraphe de Quill est
    // à 16 (mesuré : `DefaultStyles.getInstance` force `fontSize: 16`), et le
    // style attendu à 11. Les trois DIFFÈRENT : retrouver 11 dans le rendu ne
    // peut donc venir ni de l'ambiant ni du défaut.
    const double ambientSize = 21;
    const double quillFloor = 16;
    const double expectedSize = 11;
    expect(expectedSize, isNot(ambientSize));
    expect(expectedSize, isNot(quillFloor));

    final ThemeData theme = ThemeData(
      textTheme: const TextTheme(
        bodyMedium: TextStyle(fontSize: ambientSize),
        bodySmall: TextStyle(fontSize: ambientSize),
      ),
    );
    await _pumpHost(
      tester,
      theme: theme,
      builder: (context) {
        const renderer = ZMarkdownRichTextRenderer();
        return renderer.build(
              context,
              'Contrôles effectués\n\n- Accès au local\n- Inventaire visuel',
              baseStyle: const TextStyle(fontSize: expectedSize),
            ) ??
            const SizedBox.shrink();
      },
    );
    await tester.pumpAndSettle();

    final List<({String text, TextStyle style})> runs = _renderedRuns(tester);
    expect(runs, isNotEmpty, reason: 'aucun fragment de texte rendu');
    expect(
      runs.map((r) => r.text).join(),
      contains('Inventaire visuel'),
      reason: 'le contenu attendu doit bien être celui qu\'on mesure',
    );
    expect(
      runs.map((r) => r.style.fontSize).toSet(),
      everyElement(expectedSize),
      reason: 'le corps ET les marqueurs de liste doivent être rendus au '
          "baseStyle demandé, pas à l'ambiant ($ambientSize) ni au plancher "
          'Quill ($quillFloor) — mesuré : '
          '${runs.map((r) => '${r.text}=${r.style.fontSize}').toList()}',
    );
  });

  testWidgets('un rôle MATÉRIALISÉ dévie délibérément du baseStyle : le gras '
      'garde la taille de base et change la graisse', (tester) async {
    const double expectedSize = 11;
    const TextStyle base =
        TextStyle(fontSize: expectedSize, fontWeight: FontWeight.w300);
    await _pumpHost(
      tester,
      builder: (context) {
        const renderer = ZMarkdownRichTextRenderer();
        return renderer.build(context, 'avant **GRAS** après', baseStyle: base) ??
            const SizedBox.shrink();
      },
    );
    await tester.pumpAndSettle();

    final List<({String text, TextStyle style})> runs = _renderedRuns(tester);
    final ({String text, TextStyle style}) boldRun =
        runs.firstWhere((r) => r.text.contains('GRAS'));
    final ({String text, TextStyle style}) plainRun =
        runs.firstWhere((r) => r.text.contains('avant'));
    expect(
      boldRun.style.fontWeight,
      FontWeight.bold,
      reason: 'le rôle gras doit être matérialisé',
    );
    expect(
      plainRun.style.fontWeight,
      base.fontWeight,
      reason: 'le corps non-gras doit rester à la graisse de base',
    );
    // 🔴 La déviation est DÉLIBÉRÉE et BORNÉE : elle porte sur la graisse
    // seulement — la taille de base est conservée, y compris sur le gras.
    expect(runs.map((r) => r.style.fontSize).toSet(), everyElement(expectedSize));
  });

  // ─────────────────────────────── Accessibilité ──────────────────────────────

  testWidgets('sémantique du rendu riche vs repli texte : ni PERTE ni DOUBLON '
      '(compté en OCCURRENCES de mots, pas en nœuds)', (tester) async {
    const String source = 'Procédure :\n\n- Certifier\n- Empêcher';
    final SemanticsHandle handle = tester.ensureSemantics();

    // (a) Repli de l'appelant : le texte simple.
    await _pumpHost(tester, builder: (_) => const Text(source));
    await tester.pumpAndSettle();
    final List<String> plainLabels = _semanticLabels(tester);

    // (b) Rendu riche.
    await _pumpHost(
      tester,
      builder: (context) {
        const renderer = ZMarkdownRichTextRenderer();
        return renderer.build(context, source) ?? const SizedBox.shrink();
      },
    );
    await tester.pumpAndSettle();
    final List<String> richLabels = _semanticLabels(tester);

    int occurrences(List<String> labels, String word) =>
        labels.fold(0, (acc, l) => acc + RegExp(RegExp.escape(word)).allMatches(l).length);

    for (final String word in const <String>[
      'Procédure',
      'Certifier',
      'Empêcher',
    ]) {
      final int plain = occurrences(plainLabels, word);
      final int rich = occurrences(richLabels, word);
      // Le repli annonce chaque mot exactement une fois — socle de comparaison.
      expect(plain, 1, reason: 'repli : « $word »');
      // NI PERTE (>= 1) NI DOUBLON (<= 1) côté rendu riche.
      expect(rich, plain,
          reason: 'rendu riche : « $word » annoncé $rich fois au lieu de $plain');
    }
    handle.dispose();
  });

  // ─────────────────────────────── AD-2 / SM-1 ────────────────────────────────

  testWidgets('AD-2/SM-1 : un rebuild de l\'hôte ne recrée PAS le rendu '
      '(controller Quill conservé)', (tester) async {
    final ValueNotifier<int> tick = ValueNotifier<int>(0);
    addTearDown(tick.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<int>(
            valueListenable: tick,
            builder: (context, value, _) {
              const renderer = ZMarkdownRichTextRenderer();
              return Column(
                children: <Widget>[
                  Text('tick $value'),
                  renderer.build(context, '- Accès\n- Inventaire') ??
                      const SizedBox.shrink(),
                ],
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final State first = tester.state(find.byType(ZMarkdownReader));
    tick.value = 1;
    await tester.pumpAndSettle();
    expect(find.text('tick 1'), findsOneWidget, reason: 'l\'hôte a bien rebâti');
    final State second = tester.state(find.byType(ZMarkdownReader));
    expect(
      identical(first, second),
      isTrue,
      reason: 'le State (donc le QuillController créé en initState) doit '
          'survivre au rebuild de l\'hôte',
    );
  });

  // ──────────────────────────────────── FR-26 ─────────────────────────────────

  test('FR-26 : aucune couleur ni libellé codés en dur dans le renderer', () {
    final String src =
        _srcFile('lib/src/presentation/z_markdown_rich_text_renderer.dart')
            .readAsStringSync();
    final String code = src
        .split('\n')
        .where((l) {
          final t = l.trimLeft();
          return !t.startsWith('///') && !t.startsWith('//');
        })
        .join('\n');
    for (final String banned in const <String>[
      'Color(',
      'Colors.',
      '0xFF',
      '0xff',
      'TextStyle(',
    ]) {
      expect(code.contains(banned), isFalse,
          reason: 'valeur de présentation codée en dur : $banned');
    }
  });
}
