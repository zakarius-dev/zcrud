/// CR-LEX-78 — les façades `ZStudyNoteCard` / `ZStudyDocumentCard` sont des
/// **passe-plats** vers `ZStudyToolsItemCard`.
///
/// Le défaut corrigé n'est pas « il manque `leading` » : c'est que **rien ne
/// rougissait** quand le socle gagnait un slot (CR-LEX-70..75) sans que les
/// façades, écrites pour CR-LEX-67, ne suivent. La garde centrale de ce fichier
/// est donc **structurelle** : elle lit la surface du constructeur du socle
/// dans la SOURCE et exige, pour chaque slot, (1) un champ correspondant sur
/// chaque façade, (2) le **même défaut**, (3) une **transmission effective**
/// dans `build()`. Au prochain slot ajouté au socle, elle rougit d'elle-même.
///
/// Accès `dart:io` ⇒ `@TestOn('vm')`.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_study/src/presentation/z_study_document_card.dart';
import 'package:zcrud_study/src/presentation/z_study_note_card.dart';
import 'package:zcrud_study/src/presentation/z_study_tools_item_card.dart';

import 'support/z_sources.dart' show strippedLines;

const String _basePath = 'lib/src/presentation/z_study_tools_item_card.dart';
const String _notePath = 'lib/src/presentation/z_study_note_card.dart';
const String _docPath = 'lib/src/presentation/z_study_document_card.dart';

/// Renommages HISTORIQUES assumés par les façades (socle → façade). Toute autre
/// divergence de nom est un défaut, pas un choix.
const Map<String, String> _aliases = <String, String>{
  'badge': 'metadata',
  'trailing': 'actions',
};

/// Slots que la façade n'a **pas** à exposer. `key` est porté par `Widget`.
const Set<String> _notASlot = <String>{'key'};

String _read(String path) {
  final file = File(path);
  expect(
    file.existsSync(),
    isTrue,
    reason:
        'introuvable: $path (cwd=${Directory.current.path}) — lancer '
        '`flutter test` DEPUIS le package `zcrud_study`',
  );
  // 🔴 STRIPPÉ (campagne dartdoc P0A) : `ctorSurface`/`forwardedArgs` font une
  // extraction POSITIONNELLE (profondeur de délimiteurs) sur la liste des
  // paramètres — une dartdoc PAR PARAMÈTRE insérée dans le constructeur
  // pourrait porter des délimiteurs de prose qui fausseraient le comptage.
  return strippedLines(file.readAsStringSync().split('\n')).join('\n');
}

/// Découpe une liste d'arguments/paramètres sur les virgules de **niveau 0**
/// (hors parenthèses/crochets/accolades et hors littéraux `'…'`).
List<String> splitTopLevel(String body) {
  final parts = <String>[];
  final buffer = StringBuffer();
  var depth = 0;
  var inString = false;
  for (var i = 0; i < body.length; i++) {
    final c = body[i];
    if (inString) {
      buffer.write(c);
      if (c == "'") inString = false;
      continue;
    }
    switch (c) {
      case "'":
        inString = true;
        buffer.write(c);
      case '(':
      case '[':
      case '{':
        depth++;
        buffer.write(c);
      case ')':
      case ']':
      case '}':
        depth--;
        buffer.write(c);
      case ',':
        if (depth == 0) {
          parts.add(buffer.toString().trim());
          buffer.clear();
        } else {
          buffer.write(c);
        }
      default:
        buffer.write(c);
    }
  }
  final tail = buffer.toString().trim();
  if (tail.isNotEmpty) parts.add(tail);
  return parts.where((p) => p.isNotEmpty).toList();
}

/// Extrait le corps de la première liste délimitée par [open]/[close] qui suit
/// [marker] dans [source], en équilibrant les délimiteurs.
String _blockAfter(String source, String marker, String open, String close) {
  final start = source.indexOf(marker);
  expect(start, isNot(-1), reason: 'motif introuvable dans la source: $marker');
  final from = source.indexOf(open, start) + 1;
  var depth = 1;
  var i = from;
  while (i < source.length && depth > 0) {
    if (source[i] == open) depth++;
    if (source[i] == close) depth--;
    i++;
  }
  return source.substring(from, i - 1);
}

/// Surface d'un constructeur nommé : `nom du paramètre` → `défaut littéral`
/// (`null` quand aucun défaut n'est écrit). Couvre `this.x`, `this.x = v`,
/// `required this.x` et `super.key`.
Map<String, String?> ctorSurface(String source, String className) {
  final body = _blockAfter(source, 'const $className({', '{', '}');
  final surface = <String, String?>{};
  final re = RegExp(r'^(?:required\s+)?(?:this|super)\.(\w+)(?:\s*=\s*(.+))?$');
  for (final raw in splitTopLevel(body)) {
    final param = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    final m = re.firstMatch(param);
    if (m == null) continue;
    surface[m.group(1)!] = m.group(2)?.trim();
  }
  return surface;
}

/// Arguments réellement transmis à `ZStudyToolsItemCard(...)` dans `build()` :
/// `nom du paramètre du socle` → `expression transmise`.
Map<String, String> forwardedArgs(String source) {
  final body = _blockAfter(source, 'ZStudyToolsItemCard(\n', '(', ')');
  final args = <String, String>{};
  for (final raw in splitTopLevel(body)) {
    final arg = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    final colon = arg.indexOf(':');
    if (colon <= 0) continue;
    args[arg.substring(0, colon).trim()] = arg.substring(colon + 1).trim();
  }
  return args;
}

Widget _host(Widget child, {TextDirection direction = TextDirection.ltr}) =>
    MaterialApp(
      home: Directionality(
        textDirection: direction,
        child: Scaffold(body: Center(child: child)),
      ),
    );

void main() {
  group('CR-LEX-78 — garde STRUCTURELLE de passe-plat', () {
    late final Map<String, String?> base = ctorSurface(
      _read(_basePath),
      'ZStudyToolsItemCard',
    );

    test('la surface du socle est réellement lue (garde-fou de la garde)', () {
      // Si l'extracteur cassait, il rendrait une map vide et TOUTES les
      // assertions ci-dessous passeraient à vide : un vert sans preuve.
      expect(base.length, greaterThanOrEqualTo(15));
      expect(base.keys, containsAll(<String>['title', 'leading', 'key']));
      expect(base['title'], isNull, reason: '`required this.title` sans défaut');
      expect(base['progressMaxWidth'], '120');
    });

    for (final entry in <String, String>{
      'ZStudyNoteCard': _notePath,
      'ZStudyDocumentCard': _docPath,
    }.entries) {
      final className = entry.key;
      final path = entry.value;

      group(className, () {
        late final String source = _read(path);
        late final Map<String, String?> facade = ctorSurface(source, className);
        late final Map<String, String> forwarded = forwardedArgs(source);

        test('expose TOUS les slots du socle (aucun slot fermé)', () {
          final missing = <String>[];
          for (final slot in base.keys) {
            if (_notASlot.contains(slot)) continue;
            final field = _aliases[slot] ?? slot;
            if (!facade.containsKey(field)) missing.add('$slot (→ $field)');
          }
          expect(
            missing,
            isEmpty,
            reason:
                '🔴 $className ferme des slots livrés par ZStudyToolsItemCard :\n'
                '${missing.join('\n')}\n'
                'Une façade plus pauvre que la voie directe est un RECUL '
                '(CR-LEX-78) : ajoute le champ et transmets-le tel quel.',
          );
        });

        test('reprend les défauts du socle À L’IDENTIQUE', () {
          final drift = <String>[];
          for (final slot in base.keys) {
            if (_notASlot.contains(slot)) continue;
            final field = _aliases[slot] ?? slot;
            if (!facade.containsKey(field)) continue;
            if (facade[field] != base[slot]) {
              drift.add(
                '$field: façade=${facade[field]} ≠ socle[$slot]=${base[slot]}',
              );
            }
          }
          expect(
            drift,
            isEmpty,
            reason:
                '🔴 $className invente un défaut : un passe-plat ne décide '
                'rien.\n${drift.join('\n')}',
          );
        });

        test('transmet EFFECTIVEMENT chaque slot dans build()', () {
          final broken = <String>[];
          for (final slot in base.keys) {
            if (_notASlot.contains(slot)) continue;
            final field = _aliases[slot] ?? slot;
            final expr = forwarded[slot];
            if (expr == null) {
              broken.add('$slot : non transmis');
              continue;
            }
            if (slot == 'semanticLabel') {
              // SEULE valeur ajoutée légitime de la façade : le repli documenté.
              if (!expr.startsWith('semanticLabel ??')) {
                broken.add('$slot : repli attendu « semanticLabel ?? … », '
                    'trouvé « $expr »');
              }
              continue;
            }
            if (expr != field) {
              broken.add('$slot : attendu « $field », transmis « $expr »');
            }
          }
          expect(
            broken,
            isEmpty,
            reason:
                '🔴 $className n’est plus un passe-plat :\n${broken.join('\n')}',
          );
        });

        test('n’ajoute aucun champ étranger au socle', () {
          final foreign = facade.keys
              .where((f) => f != 'key')
              .where((f) => !base.containsKey(_reverseAlias(f)))
              .toList();
          expect(
            foreign,
            isEmpty,
            reason:
                '🔴 $className expose un champ que le socle ne connaît pas : '
                '$foreign — un passe-plat n’ajoute pas de surface.',
          );
        });
      });
    }
  });

  group('CR-LEX-78 — CONTRE-PREUVES des extracteurs', () {
    test('ctorSurface attrape défauts, required et super.key', () {
      const src = '''
class X extends StatelessWidget {
  const X({
    required this.title,
    this.leading,
    this.max = 120,
    this.flag = true,
    super.key,
  });
}
''';
      final s = ctorSurface(src, 'X');
      expect(s.keys, <String>['title', 'leading', 'max', 'flag', 'key']);
      expect(s['title'], isNull);
      expect(s['max'], '120');
      expect(s['flag'], 'true');
    });

    test('splitTopLevel ignore les virgules imbriquées ET dans un littéral', () {
      expect(
        splitTopLevel("a: b, c: f(x, y), d: 'p, q'"),
        <String>['a: b', 'c: f(x, y)', "d: 'p, q'"],
      );
    });

    test('forwardedArgs relit un appel multi-lignes avec repli', () {
      const src = '''
  Widget build(BuildContext context) => ZStudyToolsItemCard(
    title: title,
    badge: metadata,
    semanticLabel:
        semanticLabel ?? (subtitle == null ? title : '\$title, \$subtitle'),
  );
''';
      final a = forwardedArgs(src);
      expect(a['title'], 'title');
      expect(a['badge'], 'metadata');
      expect(a['semanticLabel'], startsWith('semanticLabel ??'));
    });
  });

  group('CR-LEX-78 — passe-plat OBSERVÉ au rendu', () {
    testWidgets('ZStudyNoteCard pose le leading, la puce et la marge', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const ZStudyNoteCard(
            title: 'Note',
            subtitle: 'Hier',
            leading: Icon(Icons.notes, key: ValueKey<String>('lead')),
            belowSubtitle: Text('brouillon', key: ValueKey<String>('below')),
            margin: EdgeInsetsDirectional.all(4),
            contentPadding: EdgeInsetsDirectional.all(12),
            titleMaxLines: 2,
          ),
        ),
      );

      expect(find.byKey(const ValueKey<String>('lead')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('below')), findsOneWidget);
      final card = tester.widget<Card>(find.byType(Card));
      expect(card.margin, const EdgeInsetsDirectional.all(4));
      final title = tester.widget<Text>(find.text('Note'));
      expect(title.maxLines, 2);
    });

    testWidgets('ZStudyDocumentCard pose la bordure et les typographies', (
      tester,
    ) async {
      const titleStyle = TextStyle(fontSize: 21);
      const subtitleStyle = TextStyle(fontSize: 11);
      await tester.pumpWidget(
        _host(
          const ZStudyDocumentCard(
            title: 'Doc',
            subtitle: 'PDF',
            borderSide: BorderSide(width: 3),
            titleStyle: titleStyle,
            subtitleStyle: subtitleStyle,
          ),
        ),
      );

      final card = tester.widget<Card>(find.byType(Card));
      final shape = card.shape! as RoundedRectangleBorder;
      expect(shape.side.width, 3);
      expect(tester.widget<Text>(find.text('Doc')).style?.fontSize, 21);
      expect(tester.widget<Text>(find.text('PDF')).style?.fontSize, 11);
    });

    testWidgets('hidesTrailingWhileBusy=false conserve les actions', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const ZStudyDocumentCard(
            title: 'Import',
            progress: CircularProgressIndicator(),
            actions: Icon(Icons.close, key: ValueKey<String>('cancel')),
            hidesTrailingWhileBusy: false,
          ),
        ),
      );
      expect(find.byKey(const ValueKey<String>('cancel')), findsOneWidget);
    });

    testWidgets('défaut true : les actions sont évincées pendant le travail', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const ZStudyNoteCard(
            title: 'Résumé',
            progress: CircularProgressIndicator(),
            actions: Icon(Icons.close, key: ValueKey<String>('cancel')),
          ),
        ),
      );
      expect(find.byKey(const ValueKey<String>('cancel')), findsNothing);
    });

    testWidgets('slots null ⇒ rendu strictement identique à la voie directe', (
      tester,
    ) async {
      Future<String> render(Widget child) async {
        await tester.pumpWidget(_host(child));
        final card = tester.widget<Card>(find.byType(Card));
        final padding = tester.widget<Padding>(
          find
              .descendant(of: find.byType(Card), matching: find.byType(Padding))
              .first,
        );
        final box = tester.getSize(find.byType(Card));
        return '${card.margin}|${card.shape}|${padding.padding}|$box';
      }

      final direct = await render(
        const ZStudyToolsItemCard(title: 'T', subtitle: 'S'),
      );
      final viaNote = await render(
        const ZStudyNoteCard(title: 'T', subtitle: 'S'),
      );
      final viaDoc = await render(
        const ZStudyDocumentCard(title: 'T', subtitle: 'S'),
      );

      expect(viaNote, direct);
      expect(viaDoc, direct);
    });

    testWidgets('AD-13 — cible ≥ 48 dp et label sémantique conservés', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          ZStudyNoteCard(title: 'Note', subtitle: 'Hier', onTap: () {}),
        ),
      );
      expect(
        tester.getSize(find.byType(Card)).height,
        greaterThanOrEqualTo(kZStudyToolsItemMinHeight),
      );
      expect(find.bySemanticsLabel('Note, Hier'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('FR-26 — aucune couleur littérale : le thème reste la source', (
      tester,
    ) async {
      // Le socle lit `ZcrudTheme` ; la façade ne doit rien intercaler.
      await tester.pumpWidget(
        _host(const ZStudyDocumentCard(title: 'Doc')),
      );
      expect(find.byType(ZStudyToolsItemCard), findsOneWidget);
      expect(
        ZcrudTheme.of(tester.element(find.byType(ZStudyToolsItemCard))),
        isNotNull,
      );
    });
  });
}

/// Nom de slot du socle correspondant à un champ de façade (inverse de
/// [_aliases]).
String _reverseAlias(String field) {
  for (final e in _aliases.entries) {
    if (e.value == field) return e.key;
  }
  return field;
}
