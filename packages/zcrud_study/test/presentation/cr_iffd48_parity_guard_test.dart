/// **CR-IFFD-48 (+ complément CR-IFFD-47)** — garde de **PARITÉ automatique**
/// entre chaque carte par défaut et sa voie typée `ZStudyToolsSectionSpec.*`.
///
/// ## Le défaut structurel qu'elle ferme
///
/// Constaté sur CR-47 : `ZDefaultFlashcardCard` a gagné `semanticLabel`, et la
/// voie typée `.flashcards` ne l'a **pas** relayé — aucun test n'a rougi. La
/// dérive est structurelle : chaque option ajoutée demain à une carte devrait
/// être recopiée à la main dans son constructeur typé, et rien ne le rappelle.
///
/// ## Ce que la garde mesure — la CORRESPONDANCE NOMINALE, jamais un compte
///
/// 🔴 Une garde qui comparerait des **comptes** de paramètres resterait VERTE
/// si l'on ajoutait un paramètre des deux côtés **sans les relier**. Celle-ci
/// vérifie, paramètre par paramètre du constructeur de la carte (hors `key` et
/// le paramètre de modèle), qu'un pendant **NOMMÉ** existe dans la signature
/// de la voie typée, via une **table de correspondance explicite**
/// (`onTap` → `onCardTap`, `trailing` → `cardTrailingBuilder`…).
///
/// **La table vit ici et DOIT être complétée à chaque ajout** : un paramètre
/// de carte absent de la table fait ROUGIR la garde — c'est le rougissement
/// voulu, il force à décider du relais au moment où l'option naît.
///
/// ## Généralisation (CR-48)
///
/// La garde couvre **toutes** les paires constructeur-carte existantes
/// (flashcards, mindmaps, exams) **et se ferme sur l'avenir** : tout nouveau
/// constructeur nommé de `ZStudyToolsSectionSpec` non enregistré comme paire
/// fait échouer la garde de recensement. Les voies `.documents`/`.notes`
/// n'existent pas : leurs modèles (`ZStudyDocument`/`ZSmartNote`) vivent dans
/// `zcrud_document`/`zcrud_note`, non-dépendances de `zcrud_study` — une voie
/// typée exigerait une arête nouvelle (AD-1).
///
/// Garde de SOURCE ancrée sur `melos.yaml` (jamais un `../` relatif) ; échec
/// **bruyant** si un constructeur est introuvable (jamais « conforme » sur une
/// source non trouvée). Accès `dart:io` ⇒ `@TestOn('vm')`.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Sondes de source
// ---------------------------------------------------------------------------

/// Racine du dépôt, quel que soit le CWD (ancrage `melos.yaml`).
Directory _repoRoot() {
  Directory dir = Directory.current.absolute;
  for (int i = 0; i < 8; i++) {
    if (File('${dir.path}/melos.yaml').existsSync()) return dir;
    final Directory parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  fail('Racine du dépôt (melos.yaml) introuvable depuis ${Directory.current}');
}

String _sourceOf(String relative) {
  final File f = File('${_repoRoot().path}/packages/zcrud_study/$relative');
  expect(f.existsSync(), isTrue, reason: 'sonde cassée : ${f.path} introuvable');
  return f.readAsStringSync();
}

/// Extrait les **noms** des paramètres nommés du constructeur dont l'en-tête
/// est [ctorHeader] (ex. `'const ZDefaultFlashcardCard({'`) dans [source].
///
/// `null` si l'en-tête est introuvable — l'appelant DOIT alors échouer
/// bruyamment (jamais « conforme » par défaut).
///
/// Le découpage suit la profondeur de `()`/`<>`/`[]`/`{}` : les virgules d'un
/// `Map<String, String>?` ou d'un `void Function(ZFlashcard card)?` ne coupent
/// pas un paramètre. Les valeurs par défaut (`= const …`) sont écartées ; le
/// nom est le dernier identifiant du paramètre (`this.x` → `x`, `super.key` →
/// `key`).
List<String>? zNamedCtorParams(String source, String ctorHeader) {
  final int headerStart = source.indexOf(ctorHeader);
  if (headerStart < 0) return null;
  final int open = headerStart + ctorHeader.length; // juste après `({`
  int depth = 1; // la `{` des paramètres nommés
  int i = open;
  while (i < source.length && depth > 0) {
    final String c = source[i];
    if (c == '{' || c == '(' || c == '[' || c == '<') depth++;
    if (c == '}' || c == ')' || c == ']' || c == '>') depth--;
    i++;
  }
  if (depth != 0) return null;
  final String body = source.substring(open, i - 1);

  final List<String> params = <String>[];
  int level = 0;
  final StringBuffer current = StringBuffer();
  for (int j = 0; j < body.length; j++) {
    final String c = body[j];
    if (c == '{' || c == '(' || c == '[' || c == '<') level++;
    if (c == '}' || c == ')' || c == ']' || c == '>') level--;
    if (c == ',' && level == 0) {
      params.add(current.toString());
      current.clear();
    } else {
      current.write(c);
    }
  }
  if (current.toString().trim().isNotEmpty) params.add(current.toString());

  final List<String> names = <String>[];
  for (final String raw in params) {
    String p = raw.trim();
    if (p.isEmpty) continue;
    // Écarte la valeur par défaut (au niveau 0 du paramètre).
    int lvl = 0;
    for (int j = 0; j < p.length; j++) {
      final String c = p[j];
      if (c == '{' || c == '(' || c == '[' || c == '<') lvl++;
      if (c == '}' || c == ')' || c == ']' || c == '>') lvl--;
      if (c == '=' && lvl == 0) {
        p = p.substring(0, j);
        break;
      }
    }
    p = p.trim();
    if (p.endsWith('?')) p = p.substring(0, p.length - 1);
    final RegExpMatch? m =
        RegExp(r'([A-Za-z_$][A-Za-z0-9_$]*)$').firstMatch(p);
    if (m != null) names.add(m.group(1)!);
  }
  return names;
}

// ---------------------------------------------------------------------------
// Les paires constructeur-carte et leurs TABLES DE CORRESPONDANCE
// ---------------------------------------------------------------------------

/// Une paire « carte par défaut ↔ constructeur typé » sous garde de parité.
class _ParityPair {
  const _ParityPair({
    required this.name,
    required this.cardFile,
    required this.cardCtorHeader,
    required this.specCtorHeader,
    required this.modelParam,
    required this.table,
  });

  /// Nom du constructeur nommé (`flashcards`…) — sert au recensement.
  final String name;

  /// Fichier de la carte, relatif au package.
  final String cardFile;

  /// En-tête EXACT du constructeur de la carte.
  final String cardCtorHeader;

  /// En-tête EXACT du constructeur typé du descripteur.
  final String specCtorHeader;

  /// Paramètre de MODÈLE de la carte (porté par la liste côté spec :
  /// `card` → `cards`, `map` → `maps`, `exam` → `exams`).
  final String modelParam;

  /// 🔴 Correspondance NOMINALE `paramètre de carte → paramètre de la voie
  /// typée`. **À compléter à chaque option ajoutée** — c'est le rougissement
  /// voulu.
  final Map<String, String> table;
}

const String _specFile = 'lib/src/presentation/z_study_tools_section_spec.dart';

const List<_ParityPair> _pairs = <_ParityPair>[
  _ParityPair(
    name: 'flashcards',
    cardFile: 'lib/src/presentation/z_default_flashcard_card.dart',
    cardCtorHeader: 'const ZDefaultFlashcardCard({',
    specCtorHeader: 'ZStudyToolsSectionSpec.flashcards({',
    modelParam: 'card',
    table: <String, String>{
      'typeLabels': 'typeLabels',
      'tags': 'tagsOf',
      'emptyTagsLabel': 'emptyTagsLabel',
      'onTagsTap': 'onTagsTap',
      'palette': 'palette',
      'colorKey': 'colorKeyOf',
      'questionMaxLines': 'questionMaxLines',
      'trailing': 'cardTrailingBuilder',
      'onTap': 'onCardTap',
      'onLongPress': 'onCardLongPress',
      // CR-IFFD-48 (complément CR-47) : le relais qui MANQUAIT.
      'semanticLabel': 'semanticLabelOf',
    },
  ),
  _ParityPair(
    name: 'mindmaps',
    cardFile: 'lib/src/presentation/z_default_mindmap_card.dart',
    cardCtorHeader: 'const ZDefaultMindmapCard({',
    specCtorHeader: 'ZStudyToolsSectionSpec.mindmaps({',
    modelParam: 'map',
    table: <String, String>{
      'untitledLabel': 'untitledLabel',
      'nodeCountLabel': 'nodeCountLabel',
      'palette': 'palette',
      'colorKey': 'colorKeyOf',
      'titleMaxLines': 'titleMaxLines',
      'trailing': 'cardTrailingBuilder',
      'onTap': 'onCardTap',
      'onLongPress': 'onCardLongPress',
      'semanticLabel': 'semanticLabelOf',
      // CR-IFFD-56 : hiérarchie, glyphe, styles, géométrie, progression.
      'hierarchy': 'hierarchy',
      'icon': 'cardIcon',
      'titleStyle': 'cardTitleStyle',
      'subtitleStyle': 'cardSubtitleStyle',
      'contentPadding': 'cardContentPadding',
      'margin': 'cardMargin',
      'borderSide': 'cardBorderSide',
      'borderRadius': 'cardBorderRadius',
      'progress': 'progressOf',
      'progressMaxWidth': 'progressMaxWidth',
      'hidesTrailingWhileBusy': 'hidesTrailingWhileBusy',
    },
  ),
  _ParityPair(
    name: 'exams',
    cardFile: 'lib/src/presentation/z_default_exam_card.dart',
    cardCtorHeader: 'const ZDefaultExamCard({',
    specCtorHeader: 'ZStudyToolsSectionSpec.exams({',
    modelParam: 'exam',
    table: <String, String>{
      'untitledLabel': 'untitledLabel',
      'dateLabel': 'dateLabelOf',
      'reminderLabel': 'reminderLabel',
      'palette': 'palette',
      'colorKey': 'colorKeyOf',
      'titleMaxLines': 'titleMaxLines',
      'trailing': 'cardTrailingBuilder',
      'onTap': 'onCardTap',
      'onLongPress': 'onCardLongPress',
      'semanticLabel': 'semanticLabelOf',
    },
  ),
];

void main() {
  group('CR-IFFD-48 — garde de PARITÉ carte ↔ voie typée', () {
    for (final _ParityPair pair in _pairs) {
      test('paire `${pair.name}` : chaque option de la carte est atteignable',
          () {
        final List<String>? cardParams =
            zNamedCtorParams(_sourceOf(pair.cardFile), pair.cardCtorHeader);
        expect(cardParams, isNotNull,
            reason: '🔴 sonde cassée : `${pair.cardCtorHeader}` introuvable '
                'dans ${pair.cardFile} — la garde ne peut PAS conclure '
                '« conforme » sur une source non trouvée.');
        final List<String>? specParams =
            zNamedCtorParams(_sourceOf(_specFile), pair.specCtorHeader);
        expect(specParams, isNotNull,
            reason: '🔴 sonde cassée : `${pair.specCtorHeader}` introuvable '
                'dans $_specFile.');

        // 🔴 NON-VACUITÉ de l'extraction : une sonde qui rendrait une liste
        // vide « validerait » n'importe quoi.
        expect(cardParams!.length, greaterThan(4),
            reason: '🔴 extraction suspecte : ${pair.cardCtorHeader} rend '
                '$cardParams.');
        expect(cardParams, contains(pair.modelParam));
        expect(cardParams, contains('key'),
            reason: 'toute carte a `super.key` — son absence signale une '
                'extraction tronquée.');

        for (final String param in cardParams) {
          if (param == 'key' || param == pair.modelParam) continue;
          // 1) La table DOIT connaître le paramètre — c'est le rougissement
          //    voulu à chaque option nouvelle.
          expect(pair.table.containsKey(param), isTrue,
              reason: '🔴 PARITÉ ROMPUE (paire `${pair.name}`) : le paramètre '
                  '`$param` de la carte n\'a AUCUNE entrée dans la table de '
                  'correspondance. Ajoute son relais à '
                  '`ZStudyToolsSectionSpec.${pair.name}` PUIS l\'entrée '
                  '`\'$param\': \'<relais>\'` ici. Une option de carte '
                  'inatteignable depuis la voie typée est exactement la '
                  'dérive que CR-48 interdit.');
          // 2) …et le relais DOIT exister NOMMÉMENT côté voie typée (jamais
          //    un simple compte — deux ajouts non reliés resteraient rouges).
          expect(specParams, contains(pair.table[param]),
              reason: '🔴 PARITÉ ROMPUE (paire `${pair.name}`) : la table '
                  'promet `$param` → `${pair.table[param]}`, mais '
                  '`${pair.table[param]}` est ABSENT de la signature de '
                  '`ZStudyToolsSectionSpec.${pair.name}`.');
        }

        // 3) Table sans entrée MORTE : chaque clé de table est un paramètre
        //    réel de la carte (une entrée périmée masquerait un renommage).
        for (final String key in pair.table.keys) {
          expect(cardParams, contains(key),
              reason: '🔴 table PÉRIMÉE (paire `${pair.name}`) : `$key` '
                  'n\'est plus un paramètre de la carte.');
        }
      });
    }

    test('recensement : TOUT constructeur typé nommé est sous garde de parité',
        () {
      final String spec = _sourceOf(_specFile);
      final Set<String> declared = RegExp(r'ZStudyToolsSectionSpec\.(\w+)\(')
          .allMatches(spec)
          .map((RegExpMatch m) => m.group(1)!)
          .toSet();
      final Set<String> guarded =
          _pairs.map((_ParityPair p) => p.name).toSet();
      expect(declared, guarded,
          reason: '🔴 un constructeur typé de ZStudyToolsSectionSpec n\'est '
              'pas recensé dans la garde de parité (ou une paire gardée a '
              'disparu). Toute voie typée nouvelle (`.documents`, `.notes`…) '
              'DOIT entrer ici avec sa table de correspondance — c\'est la '
              'généralisation demandée par CR-48.');
      // Non-vacuité : les trois paires actuelles sont bien vues dans la source.
      expect(declared, containsAll(<String>['flashcards', 'mindmaps', 'exams']));
    });

    test('⛔ `.documents`/`.notes` n\'existent pas — et c\'est PROUVÉ, motivé',
        () {
      final String spec = _sourceOf(_specFile);
      // Grep négatif MONTRÉ : les modèles ZStudyDocument/ZSmartNote vivent
      // dans zcrud_document/zcrud_note, qui ne sont PAS des dépendances de
      // zcrud_study (AD-1 : aucune arête nouvelle). Le jour où l'arête est
      // décidée, ce test ET le recensement ci-dessus rougissent ensemble :
      // la paire devra entrer dans la table.
      expect(spec.contains('ZStudyToolsSectionSpec.documents('), isFalse);
      expect(spec.contains('ZStudyToolsSectionSpec.notes('), isFalse);
      final String pubspec = _sourceOf('pubspec.yaml');
      expect(RegExp(r'^\s{2}zcrud_document:', multiLine: true).hasMatch(pubspec),
          isFalse,
          reason: 'si `zcrud_document` devient une dépendance, la voie typée '
              '`.documents` devient POSSIBLE — livre-la avec sa paire.');
      expect(RegExp(r'^\s{2}zcrud_note:', multiLine: true).hasMatch(pubspec),
          isFalse,
          reason: 'si `zcrud_note` devient une dépendance, la voie typée '
              '`.notes` devient POSSIBLE — livre-la avec sa paire.');
    });
  });

  // -------------------------------------------------------------------------
  // 🔴 CONTRE-PREUVES — la sonde n'est ni aveugle, ni fragile, ni muette.
  //
  // Pourquoi sur l'ENTRÉE du scanner : la régression exacte (« un paramètre
  // ajouté à la carte sans relais ») exige d'ajouter un champ à une classe
  // publique — injection faite EN VRAI par ailleurs (campagne R3) ; ces
  // contre-preuves fixent en plus les cas de parsing difficiles, pour que la
  // garde ne devienne pas verte par extraction ratée.
  // -------------------------------------------------------------------------
  group('CR-IFFD-48 — contre-preuves du scanner', () {
    const String synthetic = '''
class ZFakeCard {
  const ZFakeCard({
    required this.card,
    this.typeLabels,
    Map<String, String>? renames,
    void Function(int a, int b)? onPair,
    ZColorPalette palette = const ZColorPalette.defaultStudy(),
    List<int> counts = const <int>[1, 2],
    this.newOption,
    super.key,
  });
}''';

    test('extrait les noms à travers génériques, fonctions et défauts', () {
      final List<String>? params =
          zNamedCtorParams(synthetic, 'const ZFakeCard({');
      expect(params, isNotNull);
      expect(
        params,
        <String>[
          'card',
          'typeLabels',
          'renames',
          'onPair',
          'palette',
          'counts',
          'newOption',
          'key',
        ],
        reason: '🔴 scanner AVEUGLE : une virgule de générique ou de type '
            'fonction qui couperait un paramètre ferait manquer une option '
            'réelle — la garde deviendrait verte à tort.',
      );
    });

    test('la logique de table ATTRAPE l\'option non relayée', () {
      final List<String> cardParams =
          zNamedCtorParams(synthetic, 'const ZFakeCard({')!;
      const Map<String, String> table = <String, String>{
        'typeLabels': 'typeLabels',
        'renames': 'renamesOf',
        'onPair': 'onCardPair',
        'palette': 'palette',
        'counts': 'countsOf',
        // `newOption` ABSENT : la régression exacte.
      };
      final List<String> missing = cardParams
          .where((String p) =>
              p != 'key' && p != 'card' && !table.containsKey(p))
          .toList();
      expect(missing, <String>['newOption'],
          reason: '🔴 la garde doit désigner PRÉCISÉMENT l\'option ajoutée '
              'sans relais.');
    });

    test('la logique de table ATTRAPE deux ajouts NON RELIÉS (jamais un compte)',
        () {
      // Même NOMBRE de paramètres des deux côtés — mais le relais promis
      // n'existe pas côté spec : un comptage serait VERT, la correspondance
      // nominale est ROUGE.
      final List<String> specParams = <String>['cards', 'unrelatedNewParam'];
      const Map<String, String> table = <String, String>{
        'newOption': 'newOptionOf',
      };
      expect(specParams.contains(table['newOption']), isFalse,
          reason: '🔴 angle mort du COMPTE : un paramètre ajouté de chaque '
              'côté sans lien doit rester une rupture de parité.');
    });

    test('la sonde ÉCHOUE BRUYAMMENT si le constructeur a disparu', () {
      expect(zNamedCtorParams('class X { const X(); }', 'const ZFakeCard({'),
          isNull,
          reason: '🔴 une sonde qui rend « conforme » sur une source qu\'elle '
              'n\'a pas trouvée est pire qu\'aucune sonde.');
    });
  });
}
