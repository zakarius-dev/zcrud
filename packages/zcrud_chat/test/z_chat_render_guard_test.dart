/// Gardes de **SOURCE** du rendu neutre — grep NÉGATIF outillé (CHAT-3).
///
/// Les gardes de comportement (`z_chat_render_behavior_test.dart`) prouvent ce
/// qui se produit sur le chemin qu'elles montent. Elles sont **aveugles** à un
/// fichier de rendu qu'aucun test ne monte — et c'est exactement ainsi qu'une
/// deuxième surface divergente s'installe (la « surface B » d'IFFD). Ce fichier
/// est le balayage exhaustif, exécuté par une machine.
@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';

import 'support/z_chat_sources.dart';

/// Préfixes d'import ADMIS dans tout `lib/` (AD-57 : zéro dépendance tierce).
const List<String> _allowedImportPrefixes = <String>[
  'dart:',
  'package:flutter/',
  'package:zcrud_',
];

/// Fichiers du régime « rendu ».
bool _isRenderFile(String path) {
  final String p = path.replaceAll(r'\', '/');
  return p.contains('lib/src/presentation/render/') ||
      p.contains('lib/src/presentation/view/');
}

/// Extrait l'URI d'une directive `import`/`export`.
String? _uriOf(String directive) =>
    RegExp("""(?:import|export)\\s+['"]([^'"]+)['"]""")
        .firstMatch(directive)
        ?.group(1);

/// Les directives d'une source dé-commentée.
List<String> _directives(List<String> lines) => <String>[
  for (final String l in lines)
    if (l.trimLeft().startsWith('import ') ||
        l.trimLeft().startsWith('export '))
      l.trim(),
];

/// Motif d'une **chaîne d'interface en dur**, forme DIRECTE : un littéral passé
/// immédiatement à un `Text(...)` ou à un paramètre de libellé sémantique.
final RegExp _hardcodedUiString = RegExp(
  r"""\bText\(\s*['"]|"""
  r"""\b(label|semanticsLabel|hintText|tooltip)\s*:\s*['"]""",
);

/// 🔴 **DÉFAUT DE GARDE TROUVÉ PAR R3, et corrigé ici.**
///
/// [_hardcodedUiString] est un motif de LIGNE, ancré sur `Text(` suivi d'un
/// guillemet. L'injection R3 n°5 — le repli français de
/// `ZDefaultReorderRenderer` transposé au bouton de dépli — l'a traversé sans
/// rougir, sous une forme parfaitement banale :
///
/// ```dart
/// child: Text(
///   expanded ? 'Afficher moins' : 'Afficher plus',
/// ),
/// ```
///
/// Deux raisons de passer au travers, cumulées : le littéral est sur la ligne
/// SUIVANTE (le scan est ligne à ligne), et il n'est pas le premier jeton après
/// la parenthèse (il est derrière un ternaire). Aucune retouche du motif direct
/// ne rattrape le second cas : ce n'est pas une question d'ancrage, c'est que
/// « littéral en position d'argument » n'est pas décidable par une regex.
///
/// La cible n'est donc pas baissée mais DÉPLACÉE : dans les fichiers de rendu,
/// **aucun littéral porteur de mot** n'est admis, où qu'il soit. C'est plus
/// strict que la règle d'origine, et indépendant de la mise en forme.
///
/// Exemptions, toutes deux justifiées :
/// * `z_chat_labels.dart` — le fichier QUI DÉCLARE les clés ;
/// * les lignes portant `ValueKey` — une clé de widget n'est jamais affichée.
/// Les SEULS fichiers de rendu exemptés du grep de littéraux — liste
/// **nominative**, jamais un motif.
///
/// * `z_chat_labels.dart` — il DÉCLARE les clés et, depuis HIGH-1, leurs
///   **replis lisibles** ([kZChatLabelFallbacks]). C'est le fichier dont le
///   contenu EST du texte, et c'est précisément pour cela que tout le reste du
///   package n'a pas le droit d'en porter : un repli y est visible, greppable et
///   traduisible en un seul endroit.
/// * `z_chat_seam_failure.dart` — il ne porte **aucun texte affiché** : sa prose
///   part dans `FlutterError.reportError`, c'est-à-dire dans la console et les
///   rapports de crash du DÉVELOPPEUR hôte. Exactement le régime déjà accordé au
///   corps d'un `toString()` par cette même garde. Exiger qu'un message de
///   diagnostic soit localisé n'a pas de sens ; l'y interdire pousserait à ne
///   plus rien diagnostiquer.
///
/// 🔴 La liste est assertée **de taille exacte** par la garde de narrowness :
/// on ne peut pas y ajouter un fichier sans que quelqu'un le voie.
/// * `z_chat_notebook_reference.dart` — le fichier de RÉFÉRENCE audité du lot γ
///   (CR-IFFD-72), patron `ZFlashcardCardReference`. Ses littéraux ne sont pas
///   des libellés : ce sont des **clés de capacité** (`'mindmap'`,
///   `'flashcards'`, …) et un **motif de format** legacy
///   (`'dd/MM/yyyy HH:mm:ss'`, dont le mot `yyyy` déclenche le détecteur). Aucun
///   n'est affiché ni annoncé — le seul texte de ce fichier, l'état « déjà
///   généré », y est une **clé** (`kZChatLabelGenerated`) résolue par
///   `zChatLabel`, exactement comme partout ailleurs. L'exemption est
///   NOMINATIVE, par nom de fichier exact : un littéral déplacé d'un pixel hors
///   de ce fichier rougit (prouvé par injection R3).
const List<String> _kLiteralExemptFiles = <String>[
  'z_chat_labels.dart',
  'z_chat_seam_failure.dart',
  'z_chat_notebook_reference.dart',
];

final RegExp _wordBearingLiteral = RegExp(r'[A-Za-zÀ-ÖØ-öø-ÿ]{4,}');

/// Littéraux d'une ligne, interpolations `${…}` / `$ident` **retirées** (leur
/// contenu est du CODE, pas du texte affiché).
/// 🔴 Balayage MANUEL plutôt qu'une regex : une regex de littéral Dart doit
/// gérer les deux guillemets, les échappements et l'imbrication
/// `'${x ?? ''}'`. La première rédaction en portait une, syntaxiquement
/// invalide — `flutter analyze` l'a signalée (`valid_regexps`) et deux tests
/// rougissaient. Un scanner explicite est lisible et vérifiable.
List<String> _stringLiterals(String line) {
  final List<String> out = <String>[];
  int i = 0;
  while (i < line.length) {
    final String c = line[i];
    if (c != "'" && c != '"') {
      i++;
      continue;
    }
    final String quote = c;
    final StringBuffer buf = StringBuffer();
    i++;
    while (i < line.length && line[i] != quote) {
      if (line[i] == r'\') {
        i += 2;
        continue;
      }
      buf.write(line[i]);
      i++;
    }
    i++; // le guillemet fermant
    out.add(
      buf
          .toString()
          // Le contenu d'une interpolation est du CODE, pas du texte affiché.
          .replaceAll(RegExp(r'\$\{[^}]*\}'), '')
          .replaceAll(RegExp(r'\$\w+'), ''),
    );
  }
  return out;
}

void main() {
  group('🔴 G-R8 — AUCUNE dépendance tierce, prouvé par grep NÉGATIF', () {
    test('toutes les directives de `lib/` visent dart:, flutter ou zcrud_*',
        () {
      final List<String> offenders = <String>[];
      int scanned = 0;
      for (final MapEntry<String, List<String>> e in strippedLib().entries) {
        for (final String d in _directives(e.value)) {
          final String? uri = _uriOf(d);
          if (uri == null) continue;
          if (uri.startsWith('package:')) {
            scanned++;
            if (!_allowedImportPrefixes.any(uri.startsWith)) {
              offenders.add('${e.key} → $d');
            }
          }
        }
      }
      expect(scanned, greaterThan(8),
          reason: '🔴 GARDE VACUELLE : seulement $scanned imports `package:` '
              'scannés');
      expect(
        offenders,
        isEmpty,
        reason: '🔴 AD-57 : le rendu par défaut est ZÉRO-DÉPENDANCE. Ni '
            'Syncfusion (lot C6, dans SON package), ni Quill via '
            '`zcrud_markdown` — un hôte qui n\'affiche que du texte ne doit pas '
            'tirer un moteur d\'édition riche. Le rendu riche passe par la '
            'couture `ZChatRenderer`.\n${offenders.join('\n')}',
      );
    });

    test('🔬 contre-preuve — le détecteur voit un import tiers RÉEL', () {
      const List<String> witness = <String>[
        "import 'package:syncfusion_flutter_chat/chat.dart';",
        "import 'package:zcrud_markdown/zcrud_markdown.dart';",
        "import 'package:flutter/widgets.dart';",
        "  final String s = 'package:syncfusion_flutter_chat/chat.dart';",
      ];
      final List<String> found = <String>[
        for (final String d in _directives(witness))
          if (_uriOf(d) != null && _uriOf(d)!.startsWith('package:'))
            if (!_allowedImportPrefixes.any(_uriOf(d)!.startsWith)) d,
      ];
      expect(found, hasLength(1),
          reason: '🔴 le détecteur accuse `zcrud_markdown` (autorisé au titre '
              'du préfixe `zcrud_`, et c\'est VOULU : s\'il devenait une '
              'dépendance il faudrait qu\'il apparaisse dans le pubspec, ce '
              'que la garde de pureté interdit) ou rate Syncfusion');
      expect(found.single, contains('syncfusion'));
    });
  });

  group('🔴 G-R9 — `ListView.builder`, JAMAIS `ListView(children:)`', () {
    test('aucun constructeur de liste EAGER dans `lib/`', () {
      final List<String> offenders = <String>[];
      for (final MapEntry<String, List<String>> e in strippedLib().entries) {
        for (int i = 0; i < e.value.length; i++) {
          if (RegExp(r'\b(ListView|GridView|Column|Row)\s*\(\s*children:')
              .hasMatch(e.value[i])) {
            // Un `Column(children:)` est légitime (contenu BORNÉ d'un message) ;
            // une LISTE eager ne l'est pas.
            if (RegExp(r'\b(ListView|GridView)\s*\(').hasMatch(e.value[i])) {
              offenders.add('${e.key}:${i + 1}: ${e.value[i].trim()}');
            }
          }
          if (RegExp(r'\bListView\s*\((?!\s*\))').hasMatch(e.value[i]) &&
              !e.value[i].contains('ListView.builder') &&
              !e.value[i].contains('ListView.separated')) {
            offenders.add('${e.key}:${i + 1}: ${e.value[i].trim()}');
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason: '🔴 SM-1 : une conversation NON virtualisée monte toutes ses '
            'bulles. IFFD : 0 `ListView.builder` dans 5153 lignes.\n'
            '${offenders.join('\n')}',
      );
    });

    test('…et la liste virtualisée est bien PRÉSENTE (non-vacuité)', () {
      final int builders = strippedLib().values
          .expand((List<String> lines) => lines)
          .where((String l) => l.contains('ListView.builder('))
          .length;
      expect(builders, greaterThanOrEqualTo(1),
          reason: '🔴 aucune `ListView.builder` dans le package : la garde '
              'ci-dessus serait verte sur un rendu qui n\'affiche RIEN');
    });

    test('🔬 contre-preuve — le motif distingue eager et builder', () {
      bool eager(String l) =>
          RegExp(r'\bListView\s*\((?!\s*\))').hasMatch(l) &&
          !l.contains('ListView.builder') &&
          !l.contains('ListView.separated');
      expect(eager('      child: ListView(children: <Widget>[a, b]),'), isTrue);
      expect(eager('      child: ListView.builder('), isFalse);
      expect(eager('  final ListView v = tester.widget(f);'), isFalse);
    });
  });

  group('🔴 G-R10 — AUCUNE chaîne d\'interface en dur (FR-26/FR-23)', () {
    test('aucun littéral rendu ou annoncé dans `lib/`', () {
      final List<String> offenders = <String>[];
      for (final MapEntry<String, List<String>> e in strippedLib().entries) {
        for (int i = 0; i < e.value.length; i++) {
          if (_hardcodedUiString.hasMatch(e.value[i])) {
            offenders.add('${e.key}:${i + 1}: ${e.value[i].trim()}');
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason: '🔴 tout texte affiché ou annoncé passe par '
            '`label(context, clé)` — `ZcrudScope.labels` → delegate → table `en` '
            '→ clé brute. Un libellé figé dans un socle multi-consommateurs est '
            'une régression de localisation SILENCIEUSE. Contrairement à '
            '`ZDefaultReorderRenderer`, ce package ne code même pas de repli '
            'français.\n${offenders.join('\n')}',
      );
    });

    test('AUCUN littéral PORTEUR DE MOT dans un fichier de rendu — quelle que '
        'soit sa mise en forme', () {
      final List<String> offenders = <String>[];
      int scanned = 0;
      for (final MapEntry<String, List<String>> e in strippedLib().entries) {
        if (!_isRenderFile(e.key)) continue;
        if (_kLiteralExemptFiles
            .any((String f) => e.key.replaceAll(r'\', '/').endsWith(f))) {
          continue;
        }
        // Un `toString()` est un outil de DÉBOGAGE : son texte n'atteint jamais
        // l'utilisateur, et l'exiger localisé n'aurait aucun sens. L'exemption
        // est une PORTÉE (jusqu'à la fin de l'expression), pas un mot-clé sur la
        // ligne — le corps d'un `toString` s'étend sur plusieurs lignes.
        bool inToString = false;
        for (int i = 0; i < e.value.length; i++) {
          final String line = e.value[i];
          if (RegExp(r'\bString\s+toString\s*\(').hasMatch(line)) {
            inToString = true;
          }
          if (inToString) {
            if (line.trimRight().endsWith(';')) inToString = false;
            continue;
          }
          // Une URI d'import est un littéral, jamais un texte affiché.
          if (line.trimLeft().startsWith('import ') ||
              line.trimLeft().startsWith('export ')) {
            continue;
          }
          if (line.contains('ValueKey')) continue;
          for (final String literal in _stringLiterals(line)) {
            scanned++;
            if (_wordBearingLiteral.hasMatch(literal)) {
              offenders.add('${e.key}:${i + 1}: "$literal"');
            }
          }
        }
      }
      expect(scanned, greaterThan(0),
          reason: '🔴 GARDE VACUELLE : aucun littéral extrait — l\'extracteur '
              'est cassé et la garde serait verte sur n\'importe quoi');
      expect(
        offenders,
        isEmpty,
        reason: '🔴 un mot écrit en dur dans le rendu. Toute chaîne affichée '
            'passe par `label(context, clé)`. Cette règle a été RESSERRÉE après '
            'que R3 eut prouvé que le motif ancré sur `Text(` laissait passer '
            'un ternaire multi-ligne.\n${offenders.join('\n')}',
      );
    });

    test('🔬 contre-preuve R3 — l\'extracteur de littéraux voit EXACTEMENT ce '
        'que l\'injection n°5 lui a échappé', () {
      // La forme littérale qui avait traversé la garde d'origine.
      expect(
        _stringLiterals(
          "              expanded ? 'Afficher moins' : 'Afficher plus',",
        ).where(_wordBearingLiteral.hasMatch).toList(),
        <String>['Afficher moins', 'Afficher plus'],
        reason: '🔴 la garde resserrée ne voit toujours pas l\'injection n°5',
      );
      // …et le motif DIRECT, lui, ne la voyait pas — c'est la preuve que le
      // resserrement n'est pas décoratif.
      expect(
        _hardcodedUiString
            .hasMatch("              expanded ? 'Afficher moins' : 'x',"),
        isFalse,
      );
      // Les formes CONFORMES du package restent innocentées.
      for (final String ok in <String>[
        // NB : `'zchat.showMore'` N'EST PAS dans cette liste — pris isolément,
        // ce littéral EST porteur de mot et la garde l'accuserait. Il est
        // innocenté par l'exemption de FICHIER (`z_chat_labels.dart`), pas par
        // le motif. Le dire ici évite de croire à une exemption qui n'existe
        // pas : déplacer une clé hors du fichier de clés la ferait rougir.
        r"        _strong(context, '${e.date} — ${e.title}'),",
        r"      key: ValueKey<String>('stream#$requestId'),",
        '        _text(context, block.code),',
      ]) {
        final bool flagged = !ok.contains('ValueKey') &&
            _stringLiterals(ok).any(_wordBearingLiteral.hasMatch);
        expect(flagged, isFalse,
            reason: '🔴 FAUX POSITIF sur `$ok` — une garde qui crie au loup '
                'finit désactivée');
      }
    });

    test('🔬 contre-preuve — chaque forme du motif SAIT rougir, et les formes '
        'conformes ne sont PAS accusées', () {
      for (final String witness in <String>[
        "            child: Text('Afficher plus'),",
        '            child: Text("Show more"),',
        "        label: 'réponse en cours',",
        "          semanticsLabel: 'chargement',",
      ]) {
        expect(_hardcodedUiString.hasMatch(witness), isTrue,
            reason: '🔴 le motif est aveugle à `$witness`');
      }
      for (final String ok in <String>[
        '            child: Text(label(context, kZChatLabelShowMore)),',
        '        label: block.level,',
        '      Text(value, textAlign: TextAlign.start),',
        "  const String kZChatLabelShowMore = 'zchat.showMore';",
      ]) {
        expect(_hardcodedUiString.hasMatch(ok), isFalse,
            reason: '🔴 FAUX POSITIF sur `$ok` — une garde qui crie au loup '
                'finit désactivée');
      }
    });

    test('🔬 les exemptions de littéral restent NOMINATIVES et étroites', () {
      // Une exemption qui grossit sans bruit vide la garde. TROIS fichiers, pas
      // un de plus — et tous trois justifiés au point de déclaration (le
      // troisième au lot γ, CR-IFFD-72 : le fichier de référence audité).
      expect(_kLiteralExemptFiles, hasLength(3),
          reason: '🔴 une exemption a été AJOUTÉE au grep de littéraux. '
              'Justifiez-la au point de déclaration et mettez ce compte à '
              'jour — délibérément, jamais par accident.');
      // …et elles désignent des fichiers qui EXISTENT (une exemption pendante
      // serait une porte ouverte sur un nom que plus personne ne relit).
      final Iterable<String> paths =
          strippedLib().keys.map((String k) => k.replaceAll(r'\', '/'));
      for (final String f in _kLiteralExemptFiles) {
        expect(paths.any((String p) => p.endsWith(f)), isTrue,
            reason: '🔴 exemption PENDANTE : `$f` n\'existe plus.');
      }
    });

    test('les clés du rendu sont TOUTES préfixées et distinctes', () {
      expect(kZChatLabelKeys, isNotEmpty);
      expect(kZChatLabelKeys.toSet(), hasLength(kZChatLabelKeys.length),
          reason: '🔴 deux clés identiques : un hôte ne pourrait pas les '
              'distinguer dans son registre');
      for (final String key in kZChatLabelKeys) {
        expect(key, startsWith(kZChatLabelPrefix));
      }
    });

    test('toute clé DÉCLARÉE est réellement UTILISÉE par le rendu', () {
      // Une clé déclarée mais jamais consommée est une promesse faite à l'hôte
      // que le socle ne tient pas : il l'alimente et rien ne change.
      final String all = strippedLib().entries
          .where((MapEntry<String, List<String>> e) => _isRenderFile(e.key))
          .map((MapEntry<String, List<String>> e) => e.value.join('\n'))
          .join('\n');
      final List<String> unused = <String>[
        for (final String key in kZChatLabelKeys)
          if (!all.contains(_constNameOf(key))) key,
      ];
      expect(unused, isEmpty,
          reason: '🔴 clé(s) déclarée(s) mais jamais rendue(s) : $unused');
    });
  });

  group('🔴 G-R11 — le rendu est ANNOTÉ (AD-13) : `Semantics` présent', () {
    test('les fichiers de rendu portent des annotations sémantiques', () {
      final int annotations = strippedLib().entries
          .where((MapEntry<String, List<String>> e) => _isRenderFile(e.key))
          .expand((MapEntry<String, List<String>> e) => e.value)
          .where((String l) => l.contains('Semantics('))
          .length;
      expect(annotations, greaterThanOrEqualTo(3),
          reason: '🔴 IFFD : 0 `Semantics` sur 5153 lignes de chat. Une réponse '
              'qui arrive en streaming y est MUETTE. Vu ici : $annotations.');
    });

    test('la région live est déclarée `liveRegion` — une annotation muette ne '
        'sert à rien', () {
      final String all = strippedLib().entries
          .where((MapEntry<String, List<String>> e) => _isRenderFile(e.key))
          .map((MapEntry<String, List<String>> e) => e.value.join('\n'))
          .join('\n');
      expect(all, contains('liveRegion: true'),
          reason: '🔴 un `Semantics` sans `liveRegion` est LU quand on le '
              'traverse, jamais ANNONCÉ quand il change');
    });

    test('la cible tactile minimale est ≥ 48 dp (AD-13)', () {
      expect(kZChatMinTapTarget, greaterThanOrEqualTo(48.0));
    });
  });
}

/// Nom de la constante Dart correspondant à [key] (`zchat.showMore` →
/// `kZChatLabelShowMore`).
String _constNameOf(String key) {
  final String bare = key.substring(kZChatLabelPrefix.length);
  return 'kZChatLabel${bare[0].toUpperCase()}${bare.substring(1)}';
}
