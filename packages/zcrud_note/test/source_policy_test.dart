@TestOn('vm')
/// Politiques de SOURCE tenues par machine (AC3, AC4/R5, D4, AD-28).
///
/// ## ⚠️ Pourquoi ce fichier est SÉPARÉ et taggé `@TestOn('vm')`
///
/// Ces tests **lisent le disque** (`dart:io`) : ils ne peuvent pas s'exécuter sur
/// la plateforme **JS**. Or `gate:web` (`scripts/ci/gate_web_determinism.dart`)
/// est **default-ON** — il rejoue sous `dart test -p node` la suite de **TOUT**
/// package `packages/*` **pur-Dart** possédant un `test/`, donc `zcrud_note` **dès
/// sa création**, sans qu'aucun gate ne soit édité. Sa dartdoc l'annonce :
/// *« un package pur-Dart dont un test importe `dart:io` sans `@TestOn('vm')` fera
/// ROUGIR ce gate à sa création. C'est VOULU. On n'ajoute PAS d'opt-out de
/// confort : soit le test est taggé `@TestOn('vm')`, soit le package sort de la
/// cible pour une raison ÉCRITE. »*
///
/// ⇒ On **tagge**, on n'opt-out pas. **Et on ISOLE** : `z_note_content_test.dart`
/// reste **libre de `dart:io`**, donc la **matrice de coercition D5 est rejouée
/// EN JS** — ce qui a une valeur réelle, [normalizeNoteContentOps] reposant sur
/// `jsonDecode`.
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
  // AC3 / AD-28 / D4 — surface et dépendances du package.
  // ═══════════════════════════════════════════════════════════════════════════
  group('AC3 / AD-28 / D4 — aucun codec, aucune dép lourde', () {
    test('⛔ AUCUNE classe `implements ZCodec` dans ce package (AD-28)', () {
      final coupables = <String>[];
      _libSources().forEach((path, src) {
        if (src.contains('implements ZCodec')) coupables.add(path);
      });
      expect(
        coupables,
        isEmpty,
        reason: 'AD-28 : aucun nouveau codec, jamais dupliqué. La coercition D5 '
            'ne convertit entre AUCUN format — elle coerce une valeur persistée '
            'vers la forme canonique du champ (comme `_\$asInt` le fait pour la '
            'sienne).',
      );
    });

    test('⛔ AUCUN import de zcrud_markdown / Flutter / Quill / Firebase (D4)',
        () {
      _libSources().forEach((path, src) {
        expect(src, isNot(contains('package:zcrud_markdown/')), reason: path);
        expect(src, isNot(contains('package:flutter/')), reason: path);
        expect(src, isNot(contains('package:flutter_quill/')), reason: path);
        expect(src, isNot(contains('package:cloud_firestore/')), reason: path);
        expect(src, isNot(contains('package:zcrud_study_kernel/')),
            reason: path);
      });
    });

    test('⛔ le pubspec ne déclare QUE zcrud_core + zcrud_annotations (AC1)', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final deps = pubspec
          .split('dev_dependencies:')
          .first
          .split('dependencies:')
          .last;
      expect(deps, contains('zcrud_core:'));
      expect(deps, contains('zcrud_annotations:'));
      expect(deps, isNot(contains('zcrud_markdown:')), reason: 'D4');
      expect(deps, isNot(contains('zcrud_study_kernel:')), reason: 'D7 / L2');
      expect(deps, isNot(contains('sdk: flutter')), reason: 'pur-Dart');
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
  // 🔴 DW-ES22-1 — VERROU : les DEUX coercitions d'ops DIVERGENT, **EN SENS
  // OPPOSÉ SUR LA DONNÉE**. À RÉCONCILIER AVANT ES-6.1.
  //
  // | Entrée          | `DeltaNeutralOps.asDeltaOps` (zcrud_markdown) | `normalizeNoteContentOps` (zcrud_note) |
  // |-----------------|-----------------------------------------------|----------------------------------------|
  // | `String` markdown | `null` ⇒ `[]`  ⛔ **DÉTRUIT**                | texte VERBATIM  ✅ **PRÉSERVE**         |
  //
  // En ES-6.1, `note.content` traversera l'éditeur (`ZMarkdownField` →
  // `decodeDefensiveOps` → `asDeltaOps`) : **un aller-retour domaine → éditeur →
  // domaine peut EFFACER ce que le domaine avait sauvé**. La dette DW-ES22-1 était
  // écrite comme une simple DUPLICATION (« ~20 lignes ») ; c'est en réalité une
  // **DIVERGENCE SÉMANTIQUE SUR LA PRÉSERVATION DES DONNÉES**, et elle est DÉJÀ LÀ.
  //
  // ⚠️ REFUTATION PARTIELLE DE LA CONSIGNE (code-review, geste minimal demandé) :
  //    un verrou qui EXÉCUTERAIT les deux fonctions est **IMPOSSIBLE** dans ce
  //    périmètre, pour DEUX raisons de disque (vérifiées, pas supposées) :
  //      1. `DeltaNeutralOps` vit sous `lib/src/data/` de `zcrud_markdown` et
  //         **N'EST PAS EXPORTÉ** par son barrel ⇒ inatteignable, même avec l'arête ;
  //      2. `zcrud_markdown` est un package **FLUTTER** (`flutter_quill`) ⇒ l'importer
  //         ferait basculer `zcrud_note` de `dart test` à `flutter test` et casserait
  //         `gate:web` (D4/AC1).
  //    ⇒ Le verrou exécute la moitié qu'il PEUT exécuter (`zcrud_note`, pour de
  //      vrai) et **ÉPINGLE L'AUTRE PAR SA SOURCE**. Il rougit dès que la
  //      contrepartie destructrice bouge — c'est exactement le signal attendu.
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
      //     DÉTRUIT (là où `normalizeNoteContentOps` le préserve VERBATIM).
      expect(
        src,
        contains('if (ops == null) return const <Map<String, dynamic>>[];'),
        reason: '🔴 DW-ES22-1 : ce repli est LA divergence. S\'il a disparu, les '
            'deux coercitions ont peut-être CONVERGÉ (ou divergé AUTREMENT) : '
            'RE-LIRE `decodeDefensiveOps` et RÉCONCILIER AVANT de brancher '
            '`note.content` sur `ZMarkdownField` (ES-6.1) — sinon l\'aller-retour '
            'domaine → éditeur → domaine EFFACE le corpus markdown legacy.',
      );
    });

    test('la primitive de `zcrud_markdown` est INATTEIGNABLE (barrel privé)', () {
      final barrelMd =
          File('../zcrud_markdown/lib/zcrud_markdown.dart').readAsStringSync();
      expect(
        barrelMd,
        isNot(contains('delta_neutral_ops')),
        reason: 'si `DeltaNeutralOps` devient PUBLIC, un verrou EXÉCUTABLE '
            'devient possible (et la réconciliation DW-ES22-1 aussi) : ce test '
            'DOIT alors être remplacé par la comparaison en machine des deux '
            'coercitions.',
      );
    });
  });
}

/// Sources de `lib/`, **commentaires DÉPOUILLÉS** (`path → code`).
///
/// ⚠️ Le dépouillement est **indispensable** : les dartdoc de ce package **CITENT
/// VERBATIM** le code qu'elles interdisent — l'heuristique d'IFFD
/// (`startsWith('[') && contains('"insert"')`) et `implements ZCodec` — pour
/// expliquer **pourquoi** zcrud les refuse. Sans dépouillement, ces filets
/// mordraient sur **leur propre documentation** (ils l'ont fait au premier
/// passage : deux ROUGES sur la prose).
///
/// (Approximation assumée : un `//` à l'intérieur d'un littéral de chaîne serait
/// pris pour un commentaire. Aucun n'existe dans ce package, et l'erreur irait
/// dans le sens du **dépouillement**, jamais du faux positif.)
Map<String, String> _libSources() {
  final out = <String, String>{};
  for (final f in Directory('lib')
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
