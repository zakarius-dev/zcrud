// CHAT-0 — AC1/AC4/AC14. Gardes **G16** (le faux-ami `WorkflowEffort` est
// INTERDIT — grep négatif PROUVÉ) et **G17** (pureté & neutralité du dossier
// `packages/zcrud_chat_kernel/lib/src/domain/`).
//
// 🔴 « Une absence non prouvée par un grep négatif n'est pas une preuve »
// (lentille « réalité du code »). Ce fichier est ce grep, exécuté par une
// machine à chaque `dart test`.
//
// ⚠️ CHAT-0r — `@TestOn('vm')` OBLIGATOIRE : cette garde lit les SOURCES du
// dépôt (`dart:io`), donc elle est incompilable en JavaScript. Tant que le chat
// vivait dans `zcrud_core` (package Flutter), le gate `test:js`
// (`scripts/ci/gate_web_determinism.dart`, qui rejoue `dart test -p node` sur
// CHAQUE package pur-Dart) ne l'atteignait pas. Relocalisée dans un kernel
// PUR-DART, elle y est désormais soumise : sans cette annotation, elle rend
// TOUTE la suite du package non exécutable en JS ⇒ `melos run verify` ROUGE.
// Même patron exact que `zcrud_study_kernel/test/z_kernel_purity_test.dart`.
@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';

// 🔴 CHAT-0b — les primitives de lecture des sources (`repoRoot`,
// `packageLibDartFiles`, `chatDartFiles`, `stripComment`) ont été EXTRAITES vers
// `support/z_repo_sources.dart` : la garde G-U1 en a besoin à l'identique, et
// deux copies auraient pu diverger. Le comportement de CE fichier est inchangé.
import 'support/z_repo_sources.dart';

void main() {
  group('G16 — le faux-ami `WorkflowEffort` est INTERDIT (grep négatif)', () {
    test('0 occurrence de `WorkflowEffort` dans packages/*/lib', () {
      final List<String> offenders = <String>[];
      final List<File> files = packageLibDartFiles();
      expect(files, isNotEmpty, reason: 'aucun fichier scanné : garde VACUELLE');
      for (final File f in files) {
        int no = 0;
        for (final String raw in f.readAsLinesSync()) {
          no++;
          final String line = stripComment(raw);
          if (line.contains('WorkflowEffort')) {
            offenders.add('${f.path}:$no: $line');
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason: '🔴 FAUX-AMI RÉINTRODUIT. `WorkflowEffort` désigne DEUX '
            'concepts incompatibles :\n'
            '  • lex — LONGUEUR de réponse (concis/standard/detaille) ;\n'
            '  • IFFD — EFFORT DE CALCUL du routeur (low/medium/high).\n'
            'Utilisez `ZChatResponseLength` (longueur). Un effort de calcul, '
            'si retenu, naîtra sous `ZChatComputeEffort` en CHAT-1.\n'
            '${offenders.join('\n')}',
      );
    });

    test('aucun symbole `*Effort*` dans le modèle de chat', () {
      final List<String> offenders = <String>[];
      for (final File f in chatDartFiles()) {
        int no = 0;
        for (final String raw in f.readAsLinesSync()) {
          no++;
          final String line = stripComment(raw);
          // 🔴 CHAT-1 — le nom RÉSERVÉ par CHAT-0 est le SEUL autorisé :
          // `ZChatComputeEffort` porte l'axe CALCUL (entier 1..5, commun aux
          // DEUX backends). Tout autre symbole `*Effort*` reste interdit —
          // `WorkflowEffort` en premier (test précédent, sans exception).
          // Deux formes AUTORISÉES et deux seulement : le type réservé et
          // le membre qui le porte. Toute autre orthographe rougit.
          //
          // 🔴 CHAT-1b — l'exception est posée avec des LIMITES DE MOT. Écrite
          // en `replaceAll` de sous-chaîne, elle blanchissait aussi
          // `computeEffortLevel`, `ZChatComputeEffortV2` ou
          // `myComputeEffortHack` : la dérogation accordée à UN nom exact
          // dispensait toute une famille d'orthographes voisines — c'est-à-dire
          // exactement la confusion des deux axes que G16 existe pour
          // interdire, sous un nom qui ressemble au bon.
          final String reste = line.replaceAll(
            RegExp(r'\b(ZChatComputeEffort|computeEffort)\b'),
            '',
          );
          if (reste.contains('Effort')) {
            offenders.add('${f.path}:$no: $line');
          }
        }
      }
      expect(offenders, isEmpty,
          reason: 'symbole `*Effort*` dans le chat :\n${offenders.join('\n')}');
    });

    test('la dartdoc de `ZChatResponseLength` cite les DEUX origines', () {
      final File f = File(
        '${repoRoot().path}/packages/zcrud_chat_kernel/lib/src/domain/'
        'z_chat_enums.dart',
      );
      final String src = f.readAsStringSync();
      expect(src, contains('enum ZChatResponseLength'));
      expect(src, contains('domain/enums/chat_enums.dart:20-26'),
          reason: 'le fichier d\'origine LEX doit être cité nommément');
      expect(src, contains('lib/src/domain/models/ai/ai_models.dart:119-122'),
          reason: 'le fichier d\'origine IFFD doit être cité nommément');
      expect(src, contains('ZChatComputeEffort'),
          reason: 'le nom RÉSERVÉ au concept IFFD doit être nommé');
    });

    test('CHAT-1 — le nom réservé est HONORÉ : `ZChatComputeEffort` existe, '
        'porte l\'axe CALCUL, et ne se confond pas avec la VERBOSITÉ', () {
      final File f = File(
        '${repoRoot().path}/packages/zcrud_chat_kernel/lib/src/domain/ai/'
        'z_chat_compute_effort.dart',
      );
      expect(f.existsSync(), isTrue,
          reason: 'CHAT-0 avait RÉSERVÉ ce nom ; CHAT-1 devait le poser');
      final String src = f.readAsStringSync();
      expect(src, contains('class ZChatComputeEffort'));
      // Les DEUX backends portent le MÊME entier 1..5 : la preuve est citée.
      expect(src, contains('backend/app/models/chat.py:261'),
          reason: 'l\'origine LEX de l\'axe calcul doit être citée');
      expect(src, contains('shared/schemas/base_request.py:104'),
          reason: 'l\'origine IFFD de l\'axe calcul doit être citée');
      expect(src, contains('static const int min = 1;'));
      expect(src, contains('static const int max = 5;'));
      // 🔴 Aucune valeur de VERBOSITÉ ne doit fuir dans l'axe CALCUL.
      for (final String verbosite in <String>['concis', 'detaille', 'standard']) {
        expect(src.contains("'$verbosite'"), isFalse,
            reason: 'la verbosité appartient à `ZChatResponseLength`');
      }
    });

    test('CHAT-1b — G16 RETENDUE : les deux axes restent NON CONFONDABLES sur '
        'la requête', () {
      // 🔴 Le BUT RÉEL de G16 n'a jamais été le mot « Effort » : c'est
      // d'empêcher qu'un seul réglage porte DEUX demandes incompatibles (le
      // faux-ami `WorkflowEffort`, qui vaut `concis/standard/detaille` chez lex
      // et `low/medium/high` chez IFFD). Interdire le mot était un PROXY ;
      // CHAT-1 a dû y ouvrir une dérogation pour poser l'axe calcul. La garde
      // ne s'affaiblit donc que si l'on s'arrête là : ce test rétablit ce que
      // le proxy protégeait, mais sur la STRUCTURE — deux champs, deux types
      // distincts, aucun des deux ne connaissant le vocabulaire de l'autre. Un
      // hôte ne peut PAS écrire l'un en croyant écrire l'autre : le
      // compilateur l'en empêche, et ce test le prouve sur disque.
      final Directory domain = Directory(
        '${repoRoot().path}/packages/zcrud_chat_kernel/lib/src/domain',
      );
      final File port =
          File('${domain.path}/ai/z_chat_generation_port.dart');
      final File calcul = File('${domain.path}/ai/z_chat_compute_effort.dart');
      final File enums = File('${domain.path}/z_chat_enums.dart');
      for (final File f in <File>[port, calcul, enums]) {
        expect(f.existsSync(), isTrue, reason: '${f.path} : garde VACUELLE');
      }

      // (1) Les DEUX axes coexistent sur la requête, chacun sous SON type.
      final String portCode = strippedLines(port).join('\n');
      expect(portCode, contains('final ZChatResponseLength? responseLength;'),
          reason: '🔴 l\'axe VERBOSITÉ a disparu de la requête — absorbé par '
              'l\'axe calcul ?');
      expect(portCode, contains('final ZChatComputeEffort? computeEffort;'),
          reason: '🔴 l\'axe CALCUL a disparu de la requête — absorbé par la '
              'verbosité ?');

      // (2) L'axe CALCUL ignore le type de la verbosité, et réciproquement :
      //     aucune conversion implicite ne peut exister entre les deux.
      final String calculCode = strippedLines(calcul).join('\n');
      for (final String etranger in <String>[
        'ZChatResponseLength',
        'ZChatLengthBias',
        'responseLength',
        'lengthBias',
      ]) {
        expect(calculCode.contains(etranger), isFalse,
            reason: '🔴 `$etranger` (VERBOSITÉ) référencé dans le type de '
                'l\'axe CALCUL : une passerelle entre les deux axes est '
                'précisément ce que le faux-ami `WorkflowEffort` a produit.');
      }
      final String enumsCode = strippedLines(enums).join('\n');
      expect(enumsCode.contains('ZChatComputeEffort'), isFalse,
          reason: '🔴 le type de l\'axe CALCUL référencé dans le CODE des '
              'enums de verbosité (la dartdoc, elle, doit le citer — cf. le '
              'test précédent).');

      // (3) L'axe CALCUL est un ENTIER borné, la verbosité un ENUM : les deux
      //     formes ne peuvent pas se substituer l'une à l'autre par erreur.
      expect(calculCode, contains('final int level;'),
          reason: '🔴 l\'axe calcul n\'est plus l\'entier 1..5 commun aux deux '
              'backends');
      expect(enumsCode, contains('enum ZChatResponseLength'),
          reason: '🔴 la verbosité n\'est plus un enum fermé');
    });
  });

  group('G17 — pureté & neutralité de `zcrud_chat_kernel/lib/` — périmètre ÉLARGI en fin d\'epic (le barrel était hors scan)', () {
    test('aucun import Flutter / dart:ui / backend / gestionnaire d\'état', () {
      const List<String> interdits = <String>[
        'package:flutter/',
        'dart:ui',
        'package:cloud_firestore/',
        'package:firebase',
        'package:hive',
        'package:riverpod',
        'package:flutter_riverpod/',
        'package:get/',
        'package:provider/',
        'package:json_annotation/',
      ];
      // 🔴 CHAT-0r — le kernel a EXACTEMENT UNE arête `zcrud_*` autorisée :
      // `package:zcrud_core/domain.dart` (surface PUR-DART du cœur). Toute autre
      // (`zcrud_flashcard`, `zcrud_markdown`, `zcrud_firestore`, …) est
      // interdite : le noyau de chat est un PUITS du graphe (AD-1, CORE OUT=0).
      // Tant que le domaine vivait DANS le cœur, la règle s'écrivait « aucun
      // `package:zcrud_` » ; relocalisé, elle devient « `zcrud_core/domain.dart`
      // et RIEN d'autre » — même interdit, exprimé depuis le nouveau site.
      const String seuleAreteAutorisee = 'package:zcrud_core/domain.dart';
      final List<String> offenders = <String>[];
      for (final File f in chatDartFiles()) {
        for (final String raw in f.readAsLinesSync()) {
          final String line = raw.trimLeft();
          if (!line.startsWith('import ') && !line.startsWith('export ')) {
            continue;
          }
          for (final String bad in interdits) {
            if (line.contains(bad)) offenders.add('${f.path}: $line');
          }
          if (line.contains('package:zcrud_') &&
              !line.contains(seuleAreteAutorisee)) {
            offenders.add('${f.path}: $line');
          }
        }
      }
      expect(offenders, isEmpty,
          reason: 'AD-1/AD-14 violés :\n${offenders.join('\n')}');
    });

    test('aucun codegen : ni `part` GÉNÉRÉ, ni annotation de sérialisation '
        '(D1)', () {
      final List<String> offenders = <String>[];
      // 🔴 **Garde RETENDUE (fin d'epic), pas relâchée.** Elle interdisait TOUT
      // `part '`, ce qui confondait deux choses : le `part` d'un fichier
      // GÉNÉRÉ (le vrai interdit D1) et le `part` d'un frère écrit à la main —
      // le seul mécanisme par lequel Dart étend la portée du PRIVÉ à un second
      // fichier, et donc la seule façon de rendre `ZChatActionPlan._` privé
      // tout en laissant `ZChatActionDispatcher.prepare` le nommer. Le critère
      // devient : la cible doit être un fichier source **présent sur disque**
      // et n'être ni `.g.dart` ni `.freezed.dart`. Un `part` de codegen reste
      // rouge — et un `part` PENDANT (cible absente), que l'ancienne rédaction
      // laissait passer dès lors qu'elle n'existait pas encore, l'est aussi.
      final RegExp partDecl = RegExp(r"""^\s*part\s+['"]([^'"]+)['"]\s*;""");
      for (final File f in chatDartFiles()) {
        int no = 0;
        for (final String raw in f.readAsLinesSync()) {
          no++;
          final String line = stripComment(raw);
          if (partDecl.firstMatch(line) case final RegExpMatch m) {
            final String uri = m.group(1)!;
            final bool genere =
                uri.endsWith('.g.dart') || uri.endsWith('.freezed.dart');
            final bool existe =
                File('${f.parent.path}/$uri').existsSync();
            if (genere || !existe) {
              offenders.add('${f.path}:$no: $line');
            }
            continue;
          }
          if (line.contains('@JsonSerializable') ||
              line.contains('@ZcrudModel') ||
              line.contains('@ZcrudField')) {
            offenders.add('${f.path}:$no: $line');
          }
        }
      }
      expect(offenders, isEmpty,
          reason: 'ni `zcrud_core` ni `zcrud_chat_kernel` n\'ont de codegen '
              '(D1) :\n${offenders.join('\n')}');
      // CHAT-0r — la garde vaut désormais pour les DEUX packages : le cœur
      // (invariant historique) ET le kernel relocalisé (aucune toolchain codegen
      // dans son pubspec, donc aucun `.g.dart` ne peut y apparaître).
      for (final String pkg in <String>['zcrud_core', 'zcrud_chat_kernel']) {
        expect(
          Directory('${repoRoot().path}/packages/$pkg/lib')
              .listSync(recursive: true)
              .whereType<File>()
              .where((File f) => f.path.endsWith('.g.dart'))
              .toList(),
          isEmpty,
          reason: '$pkg ne doit porter AUCUN fichier généré',
        );
      }
    });

    test('aucune couleur, icône ni libellé d\'affichage (AD-13/FR-26)', () {
      final List<String> offenders = <String>[];
      for (final File f in chatDartFiles()) {
        int no = 0;
        for (final String raw in f.readAsLinesSync()) {
          no++;
          final String line = stripComment(raw);
          if (line.contains('Color(0x') ||
              line.contains('Colors.') ||
              line.contains('colorValue') ||
              line.contains('iconName') ||
              line.contains('Icons.')) {
            offenders.add('${f.path}:$no: $line');
          }
        }
      }
      expect(offenders, isEmpty,
          reason: 'présentation dans le domaine :\n${offenders.join('\n')}');
    });

    test('aucun type backend en clair (AD-5)', () {
      const List<String> types = <String>[
        'Timestamp',
        'FirebaseException',
        'DocumentSnapshot',
        'QuerySnapshot',
        'CollectionReference',
      ];
      final List<String> offenders = <String>[];
      for (final File f in chatDartFiles()) {
        int no = 0;
        for (final String raw in f.readAsLinesSync()) {
          no++;
          final String line = stripComment(raw);
          for (final String bad in types) {
            if (line.contains(bad)) offenders.add('${f.path}:$no: $line');
          }
        }
      }
      expect(offenders, isEmpty,
          reason: 'type backend en clair :\n${offenders.join('\n')}');
    });

    test('AC2 — `pubspec.yaml` de `zcrud_core` ET de `zcrud_chat_kernel` '
        'restent SANS dépendance de codegen', () {
      for (final String pkg in <String>['zcrud_core', 'zcrud_chat_kernel']) {
        // Commentaires RETIRÉS : la prose du pubspec DOIT pouvoir nommer les
        // dépendances interdites pour documenter POURQUOI elles le sont (même
        // filtre que `_stripComment` sur le Dart). Un vrai `zcrud_annotations:`
        // déclaré n'est jamais précédé d'un `#` ⇒ aucun faux négatif.
        final String pubspec = File(
          '${repoRoot().path}/packages/$pkg/pubspec.yaml',
        )
            .readAsLinesSync()
            .map((String l) => l.replaceFirst(RegExp(r'#.*$'), ''))
            .join('\n');
        for (final String interdit in <String>[
          'json_annotation',
          'build_runner',
          'json_serializable',
          'zcrud_annotations',
        ]) {
          expect(pubspec.contains(interdit), isFalse,
              reason: '`$interdit` déclaré dans $pkg ⇒ codegen réintroduit '
                  '(D1) / AD-1');
        }
      }
      // 🔴 CHAT-0r — CORE OUT = 0 : le cœur ne déclare AUCUNE arête sortante
      // vers un package `zcrud_*`. Le grep négatif est ici, exécuté par une
      // machine (la relocalisation du chat ne vaut que si le cœur reste PUITS).
      final List<String> aretes = File(
        '${repoRoot().path}/packages/zcrud_core/pubspec.yaml',
      )
          .readAsLinesSync()
          .map((String l) => l.replaceFirst(RegExp(r'#.*$'), ''))
          .where((String l) => RegExp(r'^\s+zcrud_\w+\s*:').hasMatch(l))
          .toList();
      expect(aretes, isEmpty,
          reason: 'graph_proof CORE OUT ≠ 0 :\n${aretes.join('\n')}');
    });

    test('AC11 — les deux entités citent `ZSyncMeta.reservedKeys` (règle (B) '
        'du gate)', () {
      for (final String nom in <String>[
        'z_chat_message.dart',
        'z_chat_conversation.dart',
      ]) {
        final String src = File(
          '${repoRoot().path}/packages/zcrud_chat_kernel/lib/src/domain/$nom',
        ).readAsStringSync();
        expect(src, contains('ZSyncMeta.reservedKeys'), reason: nom);
      }
    });

    test('AC1 (révisé CHAT-0r) — le module chat est exporté par SON kernel, '
        'plus par le cœur ; ses primitives de lecture restent la surface '
        'PARTAGÉE du cœur, pas un helper local', () {
      final String kernelBarrel = File(
        '${repoRoot().path}/packages/zcrud_chat_kernel/lib/'
        'zcrud_chat_kernel.dart',
      ).readAsStringSync();
      expect(kernelBarrel, contains('src/domain/z_chat_message.dart'));
      expect(kernelBarrel, contains('src/domain/z_chat_conversation.dart'));
      expect(kernelBarrel, contains('src/domain/action/z_chat_action.dart'));

      final String barrel = File(
        '${repoRoot().path}/packages/zcrud_core/lib/domain.dart',
      ).readAsStringSync();
      // 🔴 CHAT-0r — grep NÉGATIF : le cœur n'exporte PLUS une seule ligne de
      // chat. 30 packages sur 31 en dépendent ; toute réintroduction leur
      // reimposerait un domaine métier qu'ils n'utilisent pas.
      expect(barrel.contains('src/domain/chat/'), isFalse,
          reason: 'le cœur réexporte du chat — relocalisation CHAT-0r annulée');
      expect(barrel, contains('json/z_json_read.dart'));
      // 🔴 Décision owner (CHAT-0) : aucun helper JSON PRIVÉ au module chat —
      // les primitives défensives sont partagées par TOUS les modules. Un
      // `z_chat_json.dart` qui réapparaîtrait serait la duplication que cette
      // décision existe pour empêcher (classe de défaut DW-ES22-4).
      expect(
        File('${repoRoot().path}/packages/zcrud_chat_kernel/lib/src/domain/'
                'z_chat_json.dart')
            .existsSync(),
        isFalse,
        reason: 'les helpers JSON doivent vivre dans `src/domain/json/`, '
            'partagés, jamais recopiés par module',
      );
    });
  });
}
