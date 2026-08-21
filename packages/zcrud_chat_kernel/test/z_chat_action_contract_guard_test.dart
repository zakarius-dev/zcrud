// CHAT-0b — gardes STRUCTURELLES du contrat d'action, lues sur les SOURCES.
//
// 🔴 **G-U1 — « UN VERBE = UN SEUL SITE D'APPEL DANS LE CONTRÔLEUR ».**
//
// C'est l'invariant dont dépendent TOUTES les autres gardes du lot. Une
// exploration de 36 agents sur IFFD a trouvé une cause racine UNIQUE derrière
// NEUF défauts de son assistant IA : chaque écran réimplémente sa variante de
// « supprimer » / « annuler » / « régénérer », et les variantes divergent
// (`chatbot_conversation_screen.dart` : suppression confirmée l.2134 mais
// SILENCIEUSE l.3886 ; trois régénérations l.1979/2000/2026 ; annuler qui
// supprime la question tapée l.3618-3672 ; `CancelToken` d'instance partagé).
// Ce n'est pas neuf bugs, c'est UN défaut de structure à neuf symptômes.
//
// Tant que G-U1 restait NARRATIVE (une phrase de dartdoc), un second site
// d'appel des membres d'effet passait INAPERÇU — et les huit autres gardes
// devenaient décoratives : elles vérifient le chemin qui passe par le
// répartiteur, pas celui qui le contourne. Ce fichier est le grep négatif
// OUTILLÉ, exécuté par une machine à chaque `dart test`.
//
// ⚠️ `@TestOn('vm')` OBLIGATOIRE (paquet PUR-DART) : cette garde lit les
// sources via `dart:io`, incompilable en JS. Le gate `web-determinism` rejoue
// `dart test -p node` sur chaque package pur-Dart ; sans cette annotation, TOUTE
// la suite du package deviendrait non exécutable en JS. Patron :
// `zcrud_study_kernel/test/z_kernel_purity_test.dart`.
@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';

import 'support/z_repo_sources.dart';

/// Nom du **seul** fichier autorisé à invoquer un membre d'effet.
const String _dispatcherFile = 'z_chat_action_dispatcher.dart';

/// Les membres d'effet de `ZChatActionExecutor`, **DÉRIVÉS DE LA SOURCE**.
///
/// 🔴 Volontairement PAS une liste écrite à la main : un membre ajouté au port
/// serait alors gardé... seulement si quelqu'un pensait à l'ajouter ici. Le
/// contrat est la source, la garde le lit.
List<String> _effectMembers() {
  final File f = actionFile('z_chat_action_executor.dart');
  expect(f.existsSync(), isTrue,
      reason: 'port introuvable — la garde serait VACUELLE');
  final RegExp decl = RegExp(r'^\s*Future<[^;]*>\s+(\w+)\s*\(');
  final List<String> members = <String>[
    for (final String line in strippedLines(f))
      if (decl.firstMatch(line) case final RegExpMatch m) m.group(1)!,
  ];
  expect(members.length, greaterThanOrEqualTo(7),
      reason: '🔴 GARDE VACUELLE : aucun membre d\'effet extrait de '
          '`ZChatActionExecutor`. Si le port a changé de forme, c\'est CE '
          'parseur qu\'il faut corriger — surtout pas la liste qu\'il produit.');
  return members;
}

/// La **DÉCLARATION** d'un constructeur nommé homonyme d'un membre d'effet.
///
/// 🔴 **Définition UNIQUE, partagée par les DEUX sens de la garde.** Une
/// déclaration comme `const ZChatArtifactAction.regenerate({` porte le nom
/// d'un verbe **sans l'invoquer**. Les deux tests de G-U1 la rencontrent, et
/// elle les trompe en sens INVERSE :
///   * « un seul site d'appel » la compterait pour un **second site d'appel**
///     inexistant — un faux ROUGE, bruyant donc corrigible ;
///   * « aucun verbe mort » la compterait pour un **aiguillage** — un faux
///     VERT, que rien ne signale.
///
/// Les avoir écrites séparément aurait laissé les deux sens diverger : c'est
/// exactement ce qui s'est produit, le premier ayant été corrigé seul.
///
/// Les trois traits EXIGÉS sont ceux d'une déclaration, et d'elle seule :
/// début de ligne (éventuellement précédé de `const`/`factory`), récepteur
/// commençant par une **MAJUSCULE** (donc un TYPE), et parenthèse
/// **immédiate**. Un appel réel n'en réunit jamais les trois : son récepteur
/// est une variable (`executor.regenerate(`, `aware.regenerateWithSettings(`,
/// `widget.executor.regenerate(`), donc en minuscule ; et un tear-off n'a pas
/// de parenthèse. Rien de ce que la garde protégeait n'est donc relâché.
RegExp _namedCtorDecl(String alternation) => RegExp(
      r'^\s*(?:const\s+|factory\s+)?[A-Z]\w*\.(?:' + alternation + r')\s*\(',
    );

/// Toutes les occurrences de `.<membre>` en position de RÉCEPTEUR (appel ou
/// tear-off) dans `packages/*/lib`, hors commentaires, par fichier.
///
/// 🔴 **UNE seule forme est exclue : la DÉCLARATION d'un constructeur nommé.**
/// `const ZChatArtifactAction.regenerate({` (`zcrud_chat`,
/// `presentation/view/z_chat_artifact_spec.dart:150`) porte le nom d'un verbe
/// **sans l'invoquer** : c'est le constructeur nommé d'une classe de l'UI, pas
/// un appel à `ZChatActionExecutor`. Le motif `\.(<membres>)\b` le comptait
/// pour un second site d'appel. Ce n'est pas la propriété gardée qui est
/// relâchée, c'est le PROXY qui la mesurait de travers — et le corriger en
/// exemptant des fichiers aurait, lui, ouvert un trou permanent.
///
/// Les **deux formes ont été mesurées sur les sources réelles** avant de
/// choisir le motif :
///   * un **APPEL** a un RÉCEPTEUR devant le membre, et ce récepteur n'est
///     jamais un TYPE : les huit appels réels du répartiteur s'écrivent
///     `() => executor.estimateImpact(action)`,
///     `() => aware.regenerateWithSettings(a)`, … ; les formes contournantes
///     redoutées (`_executor.regenerate(`, `widget.executor.regenerate(`) ont
///     elles aussi un récepteur en minuscule ;
///   * une **DÉCLARATION** commence la ligne par le TYPE (majuscule
///     initiale), éventuellement précédé de `const`/`factory`, et enchaîne
///     aussitôt sur la liste de paramètres.
///
/// Restent donc attrapés : `executor.regenerate(` même seul en tête de ligne
/// (récepteur en minuscule), les chaînes (`widget.executor.regenerate(`), et
/// le **tear-off sans parenthèses** (l'exclusion exige `(` juste après).
///
/// 🟡 **Perte de couverture assumée et bornée** : un appel STATIQUE écrit en
/// tête de ligne sur un type (`Machin.regenerate(`) échapperait désormais.
/// Les membres d'effet de `ZChatActionExecutor` sont tous des membres
/// d'INSTANCE : aucun ne peut être atteint ainsi — il faudrait un homonyme
/// statique, qui ne serait pas le verbe gardé.
Map<String, List<String>> _callSites(List<String> members) {
  final String alternation = members.join('|');
  final RegExp use = RegExp(r'\.(' + alternation + r')\b');
  final RegExp namedCtorDecl = _namedCtorDecl(alternation);
  final Map<String, List<String>> byFile = <String, List<String>>{};
  final List<File> files = packageLibDartFiles();
  expect(files, isNotEmpty, reason: 'aucun fichier scanné : garde VACUELLE');
  for (final File f in files) {
    final List<String> lines = strippedLines(f);
    for (int i = 0; i < lines.length; i++) {
      if (use.hasMatch(lines[i]) && !namedCtorDecl.hasMatch(lines[i])) {
        (byFile[f.path] ??= <String>[]).add('${i + 1}: ${lines[i].trim()}');
      }
    }
  }
  return byFile;
}

void main() {
  group('🔴 G-U1 — un verbe = un seul site d\'appel', () {
    test('les membres d\'effet ne sont invoqués QUE depuis le répartiteur', () {
      final List<String> members = _effectMembers();
      final Map<String, List<String>> sites = _callSites(members);

      final List<String> offenders = <String>[
        for (final MapEntry<String, List<String>> e in sites.entries)
          if (!e.key.endsWith('/$_dispatcherFile'))
            '${e.key}\n    ${e.value.join('\n    ')}',
      ];

      expect(
        offenders,
        isEmpty,
        reason: '🔴 SECOND SITE D\'APPEL — la récidive IFFD.\n'
            'Les membres d\'effet de `ZChatActionExecutor` '
            '(${members.join(', ')}) ne peuvent être invoqués QUE depuis '
            '`$_dispatcherFile`. Un widget, un controller, un repository ou un '
            'second répartiteur qui les appelle crée une VARIANTE du verbe : '
            'c\'est exactement la « surface B » d\'IFFD '
            '(chatbot_conversation_screen.dart ≈ l.3600-4120), où supprimer '
            'était silencieux alors que la surface A confirmait.\n'
            'Passer par `ZChatActionDispatcher.prepare` puis `.execute`.\n'
            'Fichiers fautifs :\n${offenders.join('\n')}',
      );

      // Volet NON-VACUITÉ : le répartiteur, lui, DOIT en porter.
      expect(
        sites.keys.where((String p) => p.endsWith('/$_dispatcherFile')),
        hasLength(1),
        reason: '🔴 GARDE VACUELLE : le répartiteur n\'invoque plus AUCUN '
            'membre d\'effet — la garde ci-dessus passerait pour un contrat '
            'MORT (le défaut « Copier » d\'IFFD, `onTap: () {}`).',
      );
    });

    // 🔴 **ANGLE MORT REFERMÉ — le SENS INVERSE de celui corrigé sur le test
    // ci-dessus.** Ce test cherchait `\.<membre>\s*\(` dans la source ENTIÈRE
    // du répartiteur, sans exclure la déclaration d'un constructeur nommé. Un
    // `const ZChatActionDispatcher.regenerate(this.executor);` ajouté au
    // répartiteur aurait donc suffi à faire passer `regenerate` pour ROUTÉ
    // alors qu'il aurait été MORT.
    //
    // C'est un faux VERT, pas un faux rouge : rien ne l'aurait signalé.
    //
    // ⚠️ Et il est ATTEIGNABLE — mesuré, contrairement à ce qui avait été
    // supposé. G-U2 (ci-dessous) n'y fait pas obstacle : son motif exige un
    // BLANC juste avant le nom du membre (`^\s{2}[A-Za-z_][\w<>?,\s.]*?\s(\w+)`),
    // or un constructeur nommé porte un POINT à cette place. Vérifié sur les
    // trois formes — `const T.verbe(`, `T.verbe(`, `factory T.verbe(` : G-U2
    // n'en voit AUCUNE. La surface publique restreinte ne fermait donc rien.
    //
    // Ce que l'exclusion NE relâche PAS : elle exige les trois traits d'une
    // DÉCLARATION (cf. `_namedCtorDecl`). Un aiguillage réel du répartiteur
    // s'écrit `() => executor.regenerate(messageId: …)` — récepteur en
    // minuscule, jamais en tête de ligne : il reste compté. Un verbe
    // réellement non routé reste donc signalé, et l'injection R3 qui retire
    // son aiguillage fait toujours rougir cette assertion.
    test('CHAQUE membre d\'effet est réellement routé (aucun verbe MORT)', () {
      final List<String> members = _effectMembers();
      final List<String> lines = strippedLines(actionFile(_dispatcherFile));
      final List<String> jamaisAppeles = <String>[
        for (final String m in members)
          if (!lines.any((String l) =>
              RegExp(r'\.' + m + r'\s*\(').hasMatch(l) &&
              !_namedCtorDecl(m).hasMatch(l)))
            m,
      ];
      expect(
        jamaisAppeles,
        isEmpty,
        reason: '🔴 VERBE MORT — déclaré au port, jamais routé : '
            '${jamaisAppeles.join(', ')}. C\'est le défaut « Copier » d\'IFFD '
            '(le verbe existe dans l\'UI, `onTap: () {}` l.1513, callback '
            'jamais invoqué l.4208). Un verbe non routé est un silence.',
      );
    });

    test('G-U2 — la surface publique du répartiteur est EXACTEMENT '
        '{prepare, execute}', () {
      final List<String> lines = strippedLines(actionFile(_dispatcherFile));
      // Un membre au premier niveau de la classe = indentation de 2 espaces,
      // un type de retour (ou `const`) puis un nom suivi de `(` ou `<`. Les
      // génériques IMBRIQUÉS (`Future<ZResult<ZChatActionPlan>>`) interdisent
      // un `<[^>]*>` naïf.
      final RegExp method = RegExp(r'^\s{2}[A-Za-z_][\w<>?,\s.]*?\s(\w+)\s*[(<]');
      final Set<String> publics = <String>{
        for (final String l in lines)
          if (method.firstMatch(l) case final RegExpMatch m)
            if (!m.group(1)!.startsWith('_') &&
                m.group(1) != 'ZChatActionDispatcher')
              m.group(1)!,
      };
      expect(
        publics,
        <String>{'prepare', 'execute'},
        reason: '🔴 Égalité d\'ENSEMBLE, pas « contient » : chaque membre '
            'public ajouté (`deleteMessage()`, `regenerate()`, un raccourci de '
            'confort…) est UN SITE D\'APPEL DE PLUS, donc une divergence '
            'possible entre deux surfaces d\'UI. C\'est la forme (a) rejetée '
            'par D1 — celle d\'IFFD.',
      );
    });

    test('G-D1/D4 — le répartiteur est SANS ÉTAT (aucun jeton partagé)', () {
      final List<String> lines = strippedLines(actionFile(_dispatcherFile));
      // 🔴 On liste TOUS les champs, pas seulement ceux introduits par un
      // mot-clé : un champ mutable s'écrit `String? currentRequestId;` — sans
      // `var`, sans `late`, sans `final`. Une garde qui n'aurait cherché que
      // ces mots-clés serait passée à côté du défaut IFFD exact (INJECTION R3
      // n°4, qui l'a démontré).
      // Un champ = une ligne au premier niveau de la classe, terminée par `;`,
      // sans parenthèse ni accolade (⇒ ni méthode, ni corps).
      final List<String> champs = <String>[
        for (final String l in lines)
          if (RegExp(r'^\s{2}[A-Za-z_][^(){}]*;\s*$').hasMatch(l)) l.trim(),
      ];
      expect(champs, hasLength(1),
          reason: '🔴 Le SEUL champ autorisé est `final ZChatActionExecutor '
              'executor`. Un champ mutable — un `CancelToken` d\'instance, '
              'typiquement — réintroduit le défaut IFFD où annuler un message '
              'annulait le MAUVAIS flux. Champs vus : $champs');
      expect(champs.single, contains('ZChatActionExecutor executor'));
      expect(champs.single, startsWith('final '));
      for (final String interdit in <String>[
        'CancelToken',
        'StreamSubscription',
        'Completer',
      ]) {
        expect(lines.join('\n').contains(interdit), isFalse,
            reason: '🔴 `$interdit` dans le répartiteur : transport dans le '
                'domaine + état partagé (D4).');
      }
    });
  });

  group('Scellement & réutilisation — les autres gardes de source', () {
    test('G-SEAL — le `switch` du répartiteur n\'a AUCUN fourre-tout', () {
      final List<String> lines = strippedLines(actionFile(_dispatcherFile));
      final List<String> fourreTout = <String>[
        for (final String l in lines)
          if (RegExp(r'^\s*(default\s*:|case\s+_\s*[:)]|case\s+final\s+'
                  r'ZChatAction\s+\w+\s*:)')
              .hasMatch(l))
            l.trim(),
      ];
      expect(
        fourreTout,
        isEmpty,
        reason: '🔴 SCELLEMENT DÉFAIT. Un `default:` (ou `case _`) rend le '
            '`switch` non exhaustif au compilateur : un NOUVEAU verbe ajouté à '
            'la famille scellée compilerait alors SANS être routé — le verbe '
            'mort d\'IFFD, réintroduit en silence. Sans fourre-tout, l\'oubli '
            'NE COMPILE PAS.\n${fourreTout.join('\n')}',
      );
    });

    test('G-SEAL — tout variant de `ZChatAction` a son `case` dans le '
        'répartiteur', () {
      final RegExp variant = RegExp(r'class\s+(\w+)\s+extends\s+ZChatAction\b');
      final List<String> variants = <String>[
        for (final String l in strippedLines(actionFile('z_chat_action.dart')))
          if (variant.firstMatch(l) case final RegExpMatch m) m.group(1)!,
      ];
      expect(variants, hasLength(6),
          reason: 'garde VACUELLE ou famille modifiée : $variants');
      final String src = strippedLines(actionFile(_dispatcherFile)).join('\n');
      final List<String> nonRoutes = <String>[
        for (final String v in variants)
          if (!RegExp(r'case\s+final\s+' + v + r'\s+\w+\s*:').hasMatch(src)) v,
      ];
      expect(nonRoutes, isEmpty,
          reason: '🔴 variant non routé par le répartiteur : $nonRoutes');
    });

    test('G-S1 — AUCUN membre de suppression DURE dans le contrat (AD-9)', () {
      final List<String> offenders = <String>[];
      for (final File f in actionDir().listSync().whereType<File>()) {
        final List<String> lines = strippedLines(f);
        for (int i = 0; i < lines.length; i++) {
          for (final String bad in <String>[
            'hardDelete',
            'deleteForever',
            'purge',
            'permanentlyDelete',
            'deletePermanently',
          ]) {
            if (lines[i].contains(bad)) {
              offenders.add('${f.path}:${i + 1}: ${lines[i].trim()}');
            }
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason: '🔴 lex (`chat_repository_impl.dart:408-424`) et IFFD '
            '(`FirebaseCrudRepositoryImpl.delete()`) font tous deux un HARD '
            'delete et divergent d\'AD-9 : zcrud PRIME sur ses deux sources. '
            'Le seul membre de retrait est `softDeleteMessages`.\n'
            '${offenders.join('\n')}',
      );
    });

    test('G-C2 — le jeton reste INFALSIFIABLE : constructeur privé, colocalisé '
        'avec sa seule fabrique', () {
      final File plan = actionFile('z_chat_action_plan.dart');
      final String src = strippedLines(plan).join('\n');
      // Les trois types DOIVENT vivre dans le même fichier : en Dart le privé
      // est à portée de BIBLIOTHÈQUE. Les séparer forcerait un constructeur
      // public ⇒ jeton forgeable par n'importe quel hôte.
      expect(src, contains('class ZChatActionPlan'));
      expect(src, contains('class ZChatConfirmedAction'));
      expect(src, contains('ZChatConfirmedAction._('),
          reason: 'constructeur privé absent');
      expect(RegExp(r'\n\s*(const\s+)?ZChatConfirmedAction\s*\(').hasMatch(src),
          isFalse,
          reason: '🔴 CONSTRUCTEUR PUBLIC de `ZChatConfirmedAction` : le jeton '
              'devient FORGEABLE, et une suppression en cascade peut alors '
              's\'exécuter sans être passée par un impact chiffré (D2/D6).');
      expect(src, contains('final class ZChatActionPlan'),
          reason: '🔴 un `ZChatActionPlan` sous-classable permettrait de '
              'surcharger `requiresConfirmation` pour rendre `false` sur une '
              'suppression en cascade (D2).');
      expect(src, contains('final class ZChatConfirmedAction'));

      // 🔴 **Correction de fin d'epic (MAJEUR) — le PLAN aussi est infabricable.**
      // G-C2 ne gardait que le jeton. `ZChatActionPlan` avait, lui, un
      // constructeur PUBLIC : un hôte écrivait
      // `ZChatActionPlan(action: …, impact: ZChatActionImpact())`, obtenait un
      // jeton par `proceedWithoutConfirmation()` — l'impact fabriqué déclarant
      // 0 message touché — et exécutait **sans qu'`estimateImpact` ait jamais
      // été appelé**. Le jeton restait « infalsifiable » au sens littéral… et
      // le protocole entier était contourné. La dartdoc « aucun chemin
      // d'exécution ne contourne un impact chiffré » était FAUSSE ; elle
      // redevient vraie ici, et c'est cette assertion qui l'atteste.
      expect(src, contains('ZChatActionPlan._('),
          reason: '🔴 constructeur privé du PLAN absent');
      expect(
        RegExp(r'\n\s*(const\s+)?ZChatActionPlan\s*\(').hasMatch(src),
        isFalse,
        reason: '🔴 CONSTRUCTEUR PUBLIC de `ZChatActionPlan` : un hôte '
            'fabrique un plan de toutes pièces, avec l\'impact de son choix, '
            'et exécute sans qu\'`estimateImpact` ait jamais été appelé. '
            'La seule fabrique doit rester `ZChatActionDispatcher.prepare`.',
      );
      // Volet NON-VACUITÉ de l'assertion ci-dessus : la fabrique légitime
      // existe bien, et elle est dans CETTE bibliothèque (le répartiteur est un
      // `part` — sans quoi le constructeur privé serait injoignable et la
      // classe MORTE, ce qui rendrait la garde verte pour la mauvaise raison).
      expect(src, contains("part 'z_chat_action_dispatcher.dart';"),
          reason: '🔴 le répartiteur doit rester dans la MÊME bibliothèque que '
              'le plan : c\'est ce qui permet au constructeur d\'être privé.');
      expect(
        strippedLines(actionFile(_dispatcherFile)).join('\n'),
        contains('ZChatActionPlan._('),
        reason: '🔴 GARDE VACUELLE : plus aucune fabrique de plan dans le '
            'répartiteur — `prepare` ne produirait plus rien.',
      );
      // `requiresConfirmation` est DÉRIVÉ : jamais un paramètre.
      expect(RegExp(r'this\.requiresConfirmation').hasMatch(src), isFalse,
          reason: '🔴 `requiresConfirmation` devenu un PARAMÈTRE : tout '
              'appelant peut alors l\'affaiblir. Il doit rester un getter '
              'dérivé.');
    });

    test('G-R2 — une SEULE failure déclarée par le lot (réutilisation D9)', () {
      final List<String> declared = <String>[];
      for (final File f in actionDir().listSync().whereType<File>()) {
        for (final String l in strippedLines(f)) {
          if (RegExp(r'class\s+(\w+)\s+extends\s+Z\w*Failure\b')
              .firstMatch(l) case final RegExpMatch m) {
            declared.add(m.group(1)!);
          }
        }
      }
      expect(declared, <String>['ZChatActionNotConfirmedFailure'],
          reason: '🔴 D9 : quota → `ZQuotaExceededFailure`, verbe non supporté '
              '→ `ZUnsupportedOperationFailure`, règle métier → '
              '`ZDomainFailure`. Aucune redéclaration. Vu : $declared');
    });
  });
}
