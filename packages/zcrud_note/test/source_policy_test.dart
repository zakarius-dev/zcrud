@TestOn('vm')
/// Politiques de SOURCE tenues par machine (AC4/R5, D4, D6, AD-28) — **RETARGET
/// ES-6.1** (D6).
///
/// ## ⚠️ Pourquoi ce fichier est SÉPARÉ et taggé `@TestOn('vm')`
///
/// Ces tests **lisent le disque** (`dart:io`) : ils tournent sur la VM (pas en
/// JS). Depuis la bascule Flutter d'ES-6.1 (D2/D4), `zcrud_note` **sort de la
/// cible `gate:web`** (`gate_web_determinism.dart` EXCLUT tout package
/// `sdk: flutter`) — la matrice de coercition D5 de `z_note_content_test.dart`
/// n'est **plus rejouée sous `dart test -p node`**. C'est une **perte de
/// couverture de PLATEFORME** documentée (**DW-ES-6.1-1**), **pas** une régression
/// (les suites tournent toujours, sous VM, via `flutter test`).
///
/// ## 🔴 RETARGET (D6 puis D3/ES-6.2) — la pureté est déplacée, JAMAIS supprimée
///
/// ES-6.1 (D6) a introduit `lib/src/presentation/` (`ZSmartNoteEditor`/
/// `ZSmartNoteReader`), autorisé à importer Flutter/Quill(indirect)/zcrud_markdown.
///
/// **ES-6.2 (D3)** introduit `lib/src/data/z_note_table_migration.dart` — la couche
/// d'ADAPTATION legacy. Le migrateur **DOIT** importer la couture NEUTRE
/// `zTableEmbedOp`/`kTableEmbedType` de `package:zcrud_markdown` (fabrique d'op
/// embed tableau, comblement SM-S4). La garde de pureté **STRICTE** est donc
/// RE-SCOPÉE une nouvelle fois :
///
/// - `lib/src/domain/` : **PUR-DART strict** — AUCUN import zcrud_markdown /
///   Flutter / Quill / Firebase / study_kernel (le cœur reste réutilisable sans
///   Flutter — NFR-S10) ;
/// - `lib/src/data/` : **couche d'adaptation** — `package:zcrud_markdown/…`
///   (couture NEUTRE) est **AUTORISÉ**, mais tout import **DIRECT** de
///   `package:flutter/` ou `package:flutter_quill/` reste **INTERDIT** (la couche
///   data ne connaît QUE la couture neutre, jamais Quill) ;
/// - `lib/src/presentation/` : **AUTORISÉ** à importer Flutter/Quill/zcrud_markdown.
///
/// Supprimer la garde perdrait la preuve que le domaine reste pur ⇒ interdit
/// (RE-TARGET, jamais suppression — miroir du principe D6 d'ES-6.1).
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:zcrud_note/zcrud_note.dart';

void main() {
  // ═══════════════════════════════════════════════════════════════════════════
  // AC4 / R5 — La détection Delta est STRUCTURELLE. JAMAIS textuelle.
  //
  // C'est LITTÉRALEMENT le code d'IFFD que zcrud refuse — répété VERBATIM en
  // 4 sites (`rich_text_editor_screen.dart:206` / `:607` /
  // `delta_to_markdown_helper.dart:39` / `editors/markdown_edition_field.dart:68`) :
  //     if (trimmedValue.startsWith('[') && trimmedValue.contains('"insert"'))
  //
  // ⚠️ RESTE scopé à TOUT `lib/` (domaine ET présentation) : une heuristique
  //    textuelle markdown-vs-Delta ne doit apparaître NULLE PART, pas même dans
  //    l'adaptateur d'édition (D1 : aucune devinette de format).
  // ═══════════════════════════════════════════════════════════════════════════
  group('AC4 / R5 — aucune heuristique TEXTUELLE dans le package', () {
    test('⛔ AUCUN `startsWith(\'[\')` / `contains(\'"insert"\')` dans lib/', () {
      final coupables = <String>[];
      _libSources().forEach((path, src) {
        if (src.contains("startsWith('[')") ||
            src.contains('startsWith("[")') ||
            src.contains('contains(\'"insert"\')') ||
            src.contains(r'''contains("\"insert\"")''')) {
          coupables.add(path);
        }
      });
      expect(
        coupables,
        isEmpty,
        reason: 'R5 / AD-28 : l\'ambiguïté markdown-vs-Delta ne doit JAMAIS être '
            'résolue par une heuristique textuelle. Le TYPE dit le format ; la '
            'détection legacy est STRUCTURELLE (`jsonDecode` + forme `List<Map>` '
            'portant `insert`).',
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // AC9 / AD-28 / SM-S4 — aucun nouveau codec, aucune duplication de zcrud_markdown.
  // ═══════════════════════════════════════════════════════════════════════════
  group('AC9 / AD-28 / SM-S4 — aucun codec, réutilisation TOTALE', () {
    test('⛔ AUCUNE classe `implements ZCodec` dans ce package (AD-28)', () {
      final coupables = <String>[];
      _libSources().forEach((path, src) {
        if (src.contains('implements ZCodec')) coupables.add(path);
      });
      expect(
        coupables,
        isEmpty,
        reason: 'AD-28 / SM-S4 : aucun nouveau codec, jamais dupliqué. Le codec '
            'applicable est `ZDeltaCodec` (identité) de zcrud_markdown, réutilisé '
            'TEL QUEL — `note.content` EST déjà la valeur neutre.',
      );
    });

    test(
        '✅ la PRÉSENTATION compose `zcrud_markdown` (ZMarkdownField/'
        'ZMarkdownReader + ZDeltaCodec), aucune réimplémentation', () {
      final presentation = _presentationSources();
      expect(
        presentation,
        isNotEmpty,
        reason: 'ES-6.1 crée `lib/src/presentation/` — si le dossier a disparu, '
            'les widgets ne sont plus livrés.',
      );
      // Preuve de RÉUTILISATION (SM-S4) : chaque widget importe le barrel de
      // zcrud_markdown ET référence un widget réutilisé.
      final editor = presentation.entries.firstWhere(
        (e) => e.key.contains('z_smart_note_editor'),
      );
      final reader = presentation.entries.firstWhere(
        (e) => e.key.contains('z_smart_note_reader'),
      );
      for (final e in <MapEntry<String, String>>[editor, reader]) {
        expect(e.value, contains('package:zcrud_markdown/zcrud_markdown.dart'),
            reason: '${e.key} : la réutilisation de zcrud_markdown est le cœur '
                'd\'ES-6.1 (SM-S4).');
        expect(e.value, contains('ZDeltaCodec'),
            reason: '${e.key} : le pont domaine ↔ widget est une IDENTITÉ ⇒ '
                'codec `ZDeltaCodec` (identité), jamais un codec maison.');
      }
      expect(editor.value, contains('ZMarkdownField'),
          reason: 'l\'éditeur compose `ZMarkdownField` (voie controller).');
      expect(reader.value, contains('ZMarkdownReader'),
          reason: 'le lecteur compose `ZMarkdownReader`.');

      // ⛔ AUCUNE réimplémentation d'un widget rich-text maison (StatefulWidget
      //    portant un QuillController) : les adaptateurs délèguent, ils ne
      //    recréent pas l'éditeur/lecteur (SM-S4).
      _libSources().forEach((path, src) {
        expect(src, isNot(contains('QuillController')),
            reason: '$path : aucun `QuillController` manipulé à la main — il est '
                'ISOLÉ dans zcrud_markdown (AC8/AD-7).');
      });
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // D3 (ES-6.2) / NFR-S10 — pureté RE-SCOPÉE : `domain/` STRICT, `data/` NEUTRE.
  //
  // `lib/src/domain/`       : AUCUN import zcrud_markdown / Flutter / Quill.
  // `lib/src/data/`         : zcrud_markdown (couture NEUTRE) OK ; Flutter/Quill
  //                           DIRECTS interdits.
  // `lib/src/presentation/` : AUTORISÉ à importer Flutter/Quill(indirect)/
  //                           zcrud_markdown (il compose les widgets rich-text).
  // ═══════════════════════════════════════════════════════════════════════════
  group('D3 / NFR-S10 — pureté STRICTE du DOMAINE (`domain/` seul)', () {
    test('⛔ le DOMAINE n\'importe NI zcrud_markdown NI Flutter NI Quill '
        'NI Firebase NI study_kernel', () {
      final domain = _domainSources();
      expect(
        domain,
        isNotEmpty,
        reason: 'le domaine `zcrud_note` a disparu — RE-STATUER la garde.',
      );
      domain.forEach((path, src) {
        expect(src, isNot(contains('package:zcrud_markdown/')), reason: path);
        expect(src, isNot(contains('package:flutter/')), reason: path);
        expect(src, isNot(contains('package:flutter_quill/')), reason: path);
        expect(src, isNot(contains('package:cloud_firestore/')), reason: path);
        expect(src, isNot(contains('package:zcrud_study_kernel/')),
            reason: path);
      });
    });

    test('✅ le DOMAINE reste sur la surface PUR-DART `zcrud_core/domain.dart` '
        '(jamais le barrel Flutter)', () {
      _domainSources().forEach((path, src) {
        expect(src, isNot(contains('package:zcrud_core/zcrud_core.dart')),
            reason: '$path : le barrel COMPLET de zcrud_core ré-exporte la '
                'présentation (Flutter) — le domaine DOIT rester sur '
                '`package:zcrud_core/domain.dart`.');
      });
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // D3 (ES-6.2) — la couche `data/` (migrateur legacy) ne connaît QUE la couture
  // NEUTRE de zcrud_markdown : jamais Flutter ni Quill en DIRECT.
  // ═══════════════════════════════════════════════════════════════════════════
  group('D3 (ES-6.2) — `data/` : couture NEUTRE OK, Flutter/Quill DIRECT interdit',
      () {
    test('⛔ `data/` n\'importe NI `package:flutter/` NI `package:flutter_quill/` '
        'NI Firebase NI study_kernel (en DIRECT)', () {
      final data = _dataSources();
      expect(
        data,
        isNotEmpty,
        reason: 'ES-6.2 crée `lib/src/data/z_note_table_migration.dart` — si le '
            'dossier a disparu, le migrateur n\'est plus livré.',
      );
      data.forEach((path, src) {
        expect(src, isNot(contains('package:flutter/')), reason: path);
        expect(src, isNot(contains('package:flutter_quill/')), reason: path);
        expect(src, isNot(contains('package:cloud_firestore/')), reason: path);
        expect(src, isNot(contains('package:zcrud_study_kernel/')),
            reason: path);
      });
    });

    test('✅ le migrateur RÉUTILISE la couture NEUTRE de zcrud_markdown (SM-S4) : '
        'importe `zTableEmbedOp`/`kTableEmbedType`, jamais le contrat en dur', () {
      final data = _dataSources();
      final migration = data.entries.firstWhere(
        (e) => e.key.contains('z_note_table_migration'),
        orElse: () => throw StateError(
            'z_note_table_migration.dart absent — le migrateur n\'est pas livré.'),
      );
      final String src = migration.value;
      // (a) RÉUTILISATION : importe la couture NEUTRE de l'origine.
      expect(src, contains('package:zcrud_markdown/zcrud_markdown.dart'),
          reason: 'SM-S4 : la fabrique d\'op table est comblée DANS '
              'zcrud_markdown et RÉUTILISÉE, jamais dupliquée.');
      expect(src, contains('zTableEmbedOp'),
          reason: 'la construction d\'op passe par la fabrique neutre importée.');
      expect(src, contains('kTableEmbedType'),
          reason: 'le TYPE d\'embed vient de l\'origine (source unique), jamais '
              'd\'un littéral local.');
      // (b) NO-DUP : le contrat table (`rows`/`columns`/`cells`, type `table`)
      //     n\'est PAS re-codé en dur — R3 #4 : un `const _t = 'table'` rougit ici.
      for (final banned in const <String>[
        "'table'",
        "'rows'",
        "'columns'",
        "'cells'",
      ]) {
        expect(src, isNot(contains(banned)),
            reason: 'SM-S4 : le contrat table est IMPORTÉ (kTableEmbedType / '
                'zTableEmbedOp), jamais dupliqué par le littéral $banned.');
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // D4 / AD-1 — pubspec : l'arête zcrud_markdown est NÉE (ES-6.1), la bascule
  // Flutter est ASSUMÉE ; study_kernel/firestore restent EXCLUS.
  // ═══════════════════════════════════════════════════════════════════════════
  group('D4 / AD-1 — pubspec après bascule Flutter', () {
    late final String deps;
    setUpAll(() {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      deps = pubspec
          .split('dev_dependencies:')
          .first
          .split('dependencies:')
          .last;
    });

    test('✅ déclare zcrud_core + zcrud_annotations + zcrud_markdown + flutter',
        () {
      expect(deps, contains('zcrud_core:'));
      expect(deps, contains('zcrud_annotations:'));
      expect(deps, contains('zcrud_markdown:'),
          reason: '🔴 ES-6.1/D2 : la NOUVELLE arête vers zcrud_markdown est née '
              'avec le premier widget (présentation).');
      expect(deps, contains('sdk: flutter'),
          reason: '🔴 ES-6.1/D2 : composer les widgets Quill de zcrud_markdown '
              'requiert le SDK Flutter (bascule assumée).');
    });

    test('⛔ n\'introduit NI zcrud_study_kernel NI cloud_firestore', () {
      expect(deps, isNot(contains('zcrud_study_kernel:')), reason: 'D7 / L2');
      expect(deps, isNot(contains('cloud_firestore')));
    });

    test('(h) le barrel MASQUE l\'extension générée `ZSmartNoteZcrud`', () {
      final barrel = File('lib/zcrud_note.dart').readAsStringSync();
      expect(
        barrel,
        contains("export 'src/domain/z_smart_note.dart' hide ZSmartNoteZcrud;"),
        reason: 'finding H3 d\'ES-2.1 : `ZFlashcardZcrud` était EXPORTÉE, et son '
            '`copyWith` GÉNÉRÉ détruisait `extra`/`extension`/`source` en '
            'silence, sous 1000+ tests verts. Le gate tient désormais la règle '
            '(règle (h)) — ce test la double côté package.',
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 🔴 DW-ES22-1 — VERROU CONSERVÉ. Les DEUX coercitions d'ops DIVERGENT, **EN
  // SENS OPPOSÉ SUR LA DONNÉE**.
  //
  // | Entrée          | `DeltaNeutralOps.asDeltaOps` (zcrud_markdown) | `normalizeNoteContentOps` (zcrud_note) |
  // |-----------------|-----------------------------------------------|----------------------------------------|
  // | `String` markdown | `null` ⇒ `[]`  ⛔ **DÉTRUIT**                | texte VERBATIM  ✅ **PRÉSERVE**         |
  //
  // 🟢 ES-6.1 — RÉCONCILIATION PAR CONSTRUCTION : `ZSmartNoteEditor` n'injecte
  //    JAMAIS une `String` brute dans `ZMarkdownField` — il seed la tranche avec
  //    `note.content` (ops `List<Map>` déjà canoniques). La branche destructrice
  //    `asDeltaOps(String)→null→[]` n'est donc JAMAIS atteinte. La PREUVE
  //    EXÉCUTABLE du round-trip legacy sans perte vit dans
  //    `z_smart_note_editor_test.dart` › AC5.
  //
  // ⚠️ Ce verrou-SOURCE reste NÉCESSAIRE tant que `DeltaNeutralOps` est PRIVÉ
  //    (barrel de zcrud_markdown ne l'exporte pas) : un verrou qui EXÉCUTERAIT
  //    les deux fonctions reste impossible ici (primitive inatteignable). Il
  //    ÉPINGLE la contrepartie destructrice par sa source et rougit si elle bouge.
  // ═══════════════════════════════════════════════════════════════════════════
  group('DW-ES22-1 — VERROU : divergence `normalizeNoteContentOps` ↔ `asDeltaOps`',
      () {
    final markdownSrc = File(
      '../zcrud_markdown/lib/src/data/delta_neutral_ops.dart',
    );

    test('CÔTÉ zcrud_note (EXÉCUTÉ) : une `String` markdown est PRÉSERVÉE', () {
      expect(normalizeNoteContentOps('# T').single['insert'], '# T\n');
    });

    test('CÔTÉ zcrud_markdown (SOURCE) : le repli DESTRUCTEUR est TOUJOURS là',
        () {
      expect(markdownSrc.existsSync(), isTrue,
          reason: 'DW-ES22-1 : `delta_neutral_ops.dart` a été déplacé/supprimé — '
              'la divergence a changé de nature : RE-STATUER la dette.');
      final src = markdownSrc.readAsStringSync();

      // (1) `asDeltaOps` rend `null` sur une `String` qui n'est pas du JSON Delta…
      expect(src, contains('static List<Map<String, dynamic>>? asDeltaOps('),
          reason: 'la primitive a changé de signature ⇒ RE-STATUER DW-ES22-1.');
      // (2) …et `decodeDefensiveOps` transforme ce `null` en `[]` : LE CORPS EST
      //     DÉTRUIT (là où `normalizeNoteContentOps` le préserve VERBATIM). C'est
      //     EXACTEMENT la branche qu'ES-6.1 évite PAR CONSTRUCTION (jamais de
      //     `String` brute dans `ZMarkdownField`).
      expect(
        src,
        contains('if (ops == null) return const <Map<String, dynamic>>[];'),
        reason: '🔴 DW-ES22-1 : ce repli est LA divergence. S\'il a disparu, les '
            'deux coercitions ont peut-être CONVERGÉ (ou divergé AUTREMENT) : '
            'RE-LIRE `decodeDefensiveOps` et RE-STATUER la réconciliation ES-6.1 '
            '(preuve exécutable = `z_smart_note_editor_test.dart` › AC5).',
      );
    });

    test('la primitive de `zcrud_markdown` est INATTEIGNABLE (barrel privé)', () {
      final barrelMd =
          File('../zcrud_markdown/lib/zcrud_markdown.dart').readAsStringSync();
      expect(
        barrelMd,
        isNot(contains('delta_neutral_ops')),
        reason: 'si `DeltaNeutralOps` devient PUBLIC, un verrou EXÉCUTABLE '
            'devient possible : ce test DOIT alors être remplacé par la '
            'comparaison en machine des deux coercitions.',
      );
    });
  });
}

/// Sources de `lib/`, **commentaires DÉPOUILLÉS** (`path → code`).
///
/// ⚠️ Le dépouillement est **indispensable** : les dartdoc de ce package **CITENT
/// VERBATIM** le code qu'elles interdisent — l'heuristique d'IFFD
/// (`startsWith('[') && contains('"insert"')`), `implements ZCodec`,
/// `QuillController` — pour expliquer **pourquoi** zcrud les refuse / où ils
/// vivent. Sans dépouillement, ces filets mordraient sur **leur propre
/// documentation**.
///
/// (Approximation assumée : un `//` à l'intérieur d'un littéral de chaîne serait
/// pris pour un commentaire. Aucun n'existe dans ce package, et l'erreur irait
/// dans le sens du **dépouillement**, jamais du faux positif.)
Map<String, String> _libSources() => _sourcesUnder('lib');

/// Sources du DOMAINE PUR (`lib/src/domain/` SEUL) — cible de la garde de pureté
/// STRICTE RE-SCOPÉE (D3/ES-6.2 : `data/` n'en fait PLUS partie).
Map<String, String> _domainSources() {
  final out = <String, String>{};
  _libSources().forEach((path, src) {
    if (path.replaceAll(r'\', '/').contains('/src/domain/')) {
      out[path] = src;
    }
  });
  return out;
}

/// Sources de la couche d'ADAPTATION (`lib/src/data/`) — cible de la garde NEUTRE
/// (D3/ES-6.2 : couture zcrud_markdown OK, Flutter/Quill DIRECT interdits).
Map<String, String> _dataSources() {
  final out = <String, String>{};
  _libSources().forEach((path, src) {
    if (path.replaceAll(r'\', '/').contains('/src/data/')) {
      out[path] = src;
    }
  });
  return out;
}

/// Sources de la PRÉSENTATION (`lib/src/presentation/`) — autorisée à importer
/// Flutter/Quill(indirect)/zcrud_markdown (D6).
Map<String, String> _presentationSources() {
  final out = <String, String>{};
  _libSources().forEach((path, src) {
    if (path.replaceAll(r'\', '/').contains('/src/presentation/')) {
      out[path] = src;
    }
  });
  return out;
}

Map<String, String> _sourcesUnder(String root) {
  final out = <String, String>{};
  for (final f in Directory(root)
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))) {
    out[f.path] = _stripComments(f.readAsStringSync());
  }
  return out;
}

String _stripComments(String src) {
  final sansBlocs = src.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');
  return sansBlocs
      .split('\n')
      .map((l) {
        final i = l.indexOf('//');
        return i == -1 ? l : l.substring(0, i);
      })
      .join('\n');
}
