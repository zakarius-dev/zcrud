/// **Montage ÉNUMÉRÉ de session** — `ZStudySessionWiring` + `.wired`.
///
/// ## Le défaut visé
///
/// Le porteur de session déclare des dizaines de paramètres nommés dont la
/// quasi-totalité est **optionnelle et à défaut silencieux**. En retirer un —
/// ou en oublier un lors d'un remaniement — ne produit ni erreur de
/// compilation, ni test rouge : l'écran s'affiche, simplement ce n'est plus
/// celui qu'on voulait. Un montage qui perd son port d'indices, ses libellés
/// et sa voie de sortie compile, passe la suite, et se découvre à l'œil.
///
/// ## Ce que ces gardes mesurent
///
/// 1. **La partition, par le TYPE et non sur parole.** Les paramètres
///    nullables du constructeur par défaut sont lus DANS LA SOURCE, puis
///    partagés en *seams* et *cosmétiques* par une règle de type énoncée
///    ci-dessous. L'ensemble des seams doit être **exactement** l'ensemble des
///    champs de `ZStudySessionWiring` : un seam ajouté demain et non câblé
///    fait rougir, sans exemption possible.
/// 2. **`required` réel** — chaque champ du wiring est requis et sans valeur
///    par défaut. Un défaut `= null` rouvrirait exactement le trou fermé ici.
/// 3. **Transfert exhaustif** — un `x = wiring.x` par champ, une seule fois,
///    **et** l'effet de chaque seam observé dans le rendu ou le comportement.
/// 4. **Inertie** — à valeurs égales, l'arbre monté par `.wired` est celui du
///    constructeur par défaut, nœud pour nœud, et ce dernier est resté
///    identique au dump figé avant le lot.
///
/// 🔴 Chaque scanner est **partagé** avec ses contre-preuves : une contre-preuve
/// qui utiliserait un second motif prouverait le pouvoir du motif, jamais celui
/// du scanner.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart' show ZcrudScope;
import 'package:zcrud_session/zcrud_session.dart' show ZSrsQualityButtons;
import 'package:zcrud_study/zcrud_study.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart' show ZReviewMode;

import '../support/lotw1_seams.dart';
import '../support/z_sources.dart' as zsrc;
import '../support/z_study_session_harness.dart';

// ═══════════════════════════════════════════════════════════════════════════
// 1. LE SCANNER — partagé par les gardes et par leurs contre-preuves
// ═══════════════════════════════════════════════════════════════════════════

/// Un paramètre nommé d'un constructeur, tel que la source le déclare.
typedef CtorParam = ({String name, bool isRequired, bool hasDefault});

/// Types **cosmétiques** : liste FERMÉE de scalaires, de valeurs de peinture et
/// de types de mise en page.
///
/// 🔴 La règle est volontairement orientée : *tout ce qui n'est pas dans cette
/// liste (ni suffixé `Style`) est un SEAM*. Un type inédit ajouté demain tombe
/// donc du côté « seam », et la garde de complétude rougit tant qu'il n'est pas
/// câblé — la direction sûre.
///
/// ## Ce qui vaut à un type d'entrer ici
///
/// Un type est cosmétique quand il **ne câble rien** : ni port, ni callback, ni
/// constructeur de rendu, ni contrôleur, ni descripteur de forme interprété par
/// l'écran. Il ne porte que des dimensions — tailles, rapports, écarts,
/// alignement, comportement de débordement. L'oublier coûte une FORME, jamais
/// une CAPACITÉ : l'écran rendu reste celui qu'on voulait, aux proportions
/// près. C'est exactement la frontière que la partition trace, et c'est à ce
/// titre que `ZSessionDotsGeometry` y figure — un objet de géométrie, dont
/// chaque champ est une mesure.
///
/// 🔴 L'admission est **NOMINATIVE**, jamais par suffixe : un futur
/// `…Geometry` retombe du côté « seam » tant que personne ne l'a examiné. Une
/// règle par suffixe transformerait cette liste fermée en porte ouverte, et le
/// premier type de « géométrie » qui porterait un callback entrerait sans que
/// rien ne le signale.
///
/// ## Seconde famille admise : les réglages de DIAGNOSTIC
///
/// `ZStudySeamAuditPolicy` ne porte pas de dimensions — il n'en est pas moins
/// cosmétique au sens exact de la règle : **il ne câble rien**. Ni port, ni
/// callback, ni constructeur de rendu, ni contrôleur, ni forme interprétée par
/// l'écran. Posé ou non, l'arbre rendu est identique NŒUD POUR NŒUD (garde G7
/// de `lotw3_seam_audit_test.dart`) ; son absence ne coûte donc ni une forme,
/// ni une capacité — seulement le **signal** qu'un seam, lui, manque. L'exiger
/// dans le montage énuméré serait un contresens : le montage énuméré n'a rien
/// à auditer, puisqu'il ne peut pas laisser un seam sans réponse.
///
/// L'admission reste NOMINATIVE, pour la même raison qu'au-dessus : un futur
/// `…Policy` qui porterait un callback ou une décision de rendu doit retomber
/// du côté « seam » tant que personne ne l'a examiné.
///
/// ## Troisième famille admise : les FORMES de la surface de saisie
///
/// `ZAnswerChoiceLayout`, `ZAnswerActionsLayout`, `ZAnswerSubmitWidth` et
/// `ZAnswerGradingVisibility` disent comment la surface de saisie est BÂTIE :
/// une ligne de choix nue ou en tuile, deux contrôles d'aide empilés ou côte à
/// côte, une soumission au contenu ou pleine largeur, une rangée de paliers
/// montée après la réponse ou d'emblée. Aucun ne câble quoi que ce soit — ni
/// port, ni callback, ni constructeur de rendu, ni contrôleur. Les oublier
/// coûte une FORME (l'écran reste celui qu'on voulait, autrement proportionné),
/// jamais une CAPACITÉ : la voie de notation, l'évaluation, les indices et le
/// verrou one-shot sont exactement les mêmes dans les deux dispositions.
///
/// 🔴 `ZAnswerGradingVisibility.always` déplace l'ordre des gestes ; cela ne
/// change pas son classement. Ce qu'il déplace est le MOMENT d'une affordance
/// déjà branchée : sans `onQualitySelected` — le seam, lui — aucune rangée
/// n'est montée, ni avant ni après, et le réglage n'a aucun effet. Un réglage
/// dont l'effet est nul quand le seam manque n'est pas un seam.
///
/// L'admission reste NOMINATIVE, pour la raison qui vaut au-dessus : une règle
/// de suffixe ferait entrer sans examen tout futur `…Layout`, `…Width` ou
/// `…Visibility`, y compris celui qui porterait un callback.
///
/// ## Quatrième famille admise : les COMPOSITIONS DE FACE de la carte
///
/// `ZFlashcardQuestionFaceChoices` et `ZFlashcardFaceContent` disent ce que la
/// carte du socle rend : ses choix de QCM sur la face question, et son contenu
/// selon son rang dans la pile. Aucun des deux ne câble quoi que ce soit — ni
/// port, ni callback, ni constructeur de rendu, ni contrôleur. Les oublier ne
/// coûte aucune CAPACITÉ : les choix restent saisissables dans la surface de
/// saisie, la carte de devant reste pleine, et la voie de notation est
/// identique dans les quatre combinaisons.
///
/// 🔴 Leur défaut `null` n'est pas « rien » : il vaut *la décision de
/// l'assemblage* (la carte ne rend pas les choix que la saisie rend déjà ; les
/// cartes de rang > 0 sont muettes). Cela ne change pas leur classement — un
/// montage énuméré qui devrait les nommer obligerait chaque écran à réécrire
/// une décision que l'assemblage prend justement pour lui, et un `null` y
/// signifierait la même chose qu'ici.
///
/// L'admission reste NOMINATIVE : un futur `ZFlashcard…Content` porteur d'un
/// builder retomberait du côté « seam » tant que personne ne l'a examiné.
const Set<String> kCosmeticTypes = <String>{
  'double',
  'int',
  'num',
  'bool',
  'String',
  'Color',
  'EdgeInsets',
  'EdgeInsetsGeometry',
  'EdgeInsetsDirectional',
  'BorderRadius',
  'BorderRadiusGeometry',
  'Alignment',
  'AlignmentGeometry',
  'Duration',
  'Curve',
  'ZSessionDotsGeometry',
  'ZStudySeamAuditPolicy',
  'ZAnswerChoiceLayout',
  'ZAnswerActionsLayout',
  'ZAnswerSubmitWidth',
  'ZAnswerGradingVisibility',
  'ZFlashcardQuestionFaceChoices',
  'ZFlashcardFaceContent',
};

/// Applique la règle de type : `true` ⇒ **cosmétique**, `false` ⇒ **seam**.
///
/// Un type porteur de `Function` (ou d'une parenthèse de signature) est
/// toujours un seam. Sinon, le nom nu (sans `?`, sans generics) doit être dans
/// [kCosmeticTypes] **ou** finir par `Style` (`TextStyle`,
/// `ZSessionProgressStyle`…).
bool isCosmeticType(String type) {
  final String t = type.replaceAll('?', '').trim();
  if (t.contains('Function') || t.contains('(')) return false;
  final String base = t.split('<').first.trim();
  return kCosmeticTypes.contains(base) || base.endsWith('Style');
}

/// Le corps textuel d'une classe, entre son en-tête et l'ancre qui la suit.
///
/// Lève si l'une des deux ancres a bougé : une garde qui ne trouve plus son
/// sujet ne mesure plus rien, et doit le dire fort.
String classBody(String source, String header, String nextAnchor) {
  final int start = source.indexOf(header);
  if (start < 0) {
    throw StateError('en-tête introuvable : $header — la garde est aveugle');
  }
  final int end = source.indexOf(nextAnchor, start + header.length);
  if (end < 0) {
    throw StateError('ancre de fin introuvable : $nextAnchor');
  }
  return source.substring(start, end);
}

/// Le bloc de paramètres d'un constructeur nommé, entre `(\{` et sa parenthèse
/// fermante en colonne 3.
///
/// La borne est `\n  })` et non `\n  });` : un constructeur qui enchaîne sur
/// une liste d'initialisation écrit `})  : x = …` — la chercher avec le
/// point-virgule rendrait la garde aveugle sur exactement le constructeur de
/// transfert qu'elle doit mesurer.
String ctorBlock(String source, String header) {
  final int start = source.indexOf(header);
  if (start < 0) {
    throw StateError('constructeur introuvable : $header — la garde est '
        'aveugle');
  }
  const String close = '\n  })';
  final int end = source.indexOf(close, start);
  if (end < 0) throw StateError('fin de constructeur introuvable : $header');
  return source.substring(start + header.length, end);
}

/// Les paramètres `this.x` d'un bloc de constructeur, avec leur régime.
List<CtorParam> ctorParams(String block) {
  final List<CtorParam> out = <CtorParam>[];
  for (final String raw in block.split('\n')) {
    final RegExpMatch? m =
        RegExp(r'^\s*(required\s+)?this\.(\w+)(\s*=\s*.+?)?,\s*$')
            .firstMatch(raw);
    if (m == null) continue;
    out.add((
      name: m.group(2)!,
      isRequired: m.group(1) != null,
      hasDefault: m.group(3) != null,
    ));
  }
  return out;
}

/// Les champs `final <type> <nom>;` d'un corps de classe, type compris.
///
/// Les champs initialisés (`= …`) sont hors sujet : ce sont des états privés,
/// jamais des paramètres de montage.
Map<String, String> finalFields(String body) {
  final String flat = body.replaceAll(RegExp(r'\s+'), ' ');
  final Map<String, String> out = <String, String>{};
  for (final RegExpMatch m
      in RegExp(r'final ([^;=]+?) (\w+) ?;').allMatches(flat)) {
    out[m.group(2)!] = m.group(1)!.trim();
  }
  return out;
}

/// La partition mesurée d'une source de porteur.
typedef Partition = ({List<String> seams, List<String> cosmetics});

/// Partage les paramètres NULLABLES (ni requis, ni à défaut) du constructeur
/// par défaut, par la règle de type.
Partition partitionOf(String hostSource) {
  final String block =
      ctorBlock(hostSource, '  const ZStudySessionHost({');
  final Map<String, String> types = finalFields(
    classBody(
      hostSource,
      'class ZStudySessionHost extends StatefulWidget {',
      'class _ZStudySessionHostState',
    ),
  );
  final List<String> seams = <String>[];
  final List<String> cosmetics = <String>[];
  for (final CtorParam p in ctorParams(block)) {
    if (p.isRequired || p.hasDefault) continue;
    final String? type = types[p.name];
    if (type == null) {
      throw StateError('champ `${p.name}` sans déclaration `final` : le '
          'scanner de types a perdu son sujet');
    }
    (isCosmeticType(type) ? cosmetics : seams).add(p.name);
  }
  return (seams: seams, cosmetics: cosmetics);
}

/// Les champs du wiring, lus dans la source.
List<String> wiringFields(String hostSource) => finalFields(
      classBody(hostSource, 'class ZStudySessionWiring {',
          'class ZStudySessionHost extends StatefulWidget {'),
    ).keys.toList(growable: false);

String hostSource() =>
    zsrc.strippedOf('lib/src/presentation/z_study_session_host.dart');

// ═══════════════════════════════════════════════════════════════════════════
// 2. LE MONTAGE — `.wired`, à valeurs sentinelles
// ═══════════════════════════════════════════════════════════════════════════

/// Construit le wiring à partir du jeu de sentinelles.
ZStudySessionWiring lotW1Wiring(LotW1Seams s) => ZStudySessionWiring(
      reviewer: s.reviewer,
      cardBuilder: s.cardBuilder,
      cardSlotBuilder: s.cardSlotBuilder,
      contentBuilder: s.contentBuilder,
      questionTypeBadgeBuilder: s.questionTypeBadgeBuilder,
      instructionBanner: s.instructionBanner,
      evaluationPort: s.evaluationPort,
      hintPort: s.hintPort,
      onQualitySelected: s.onQualitySelected,
      qualityColorKeyFor: s.qualityColorKeyFor,
      qualityPreviewLabelFor: s.qualityPreviewLabelFor,
      headerBuilder: s.headerBuilder,
      counterBuilder: s.counterBuilder,
      gradingBuilder: s.gradingBuilder,
      summaryBuilder: s.summaryBuilder,
      emptyBuilder: s.emptyBuilder,
      celebrationBuilder: s.celebrationBuilder,
      labels: s.labels,
      onSessionEnd: s.onSessionEnd,
      onExit: s.onExit,
      indexController: s.indexController,
      preset: s.preset,
    );

/// Monte le porteur par le constructeur de TRANSFERT.
ZStudySessionHost lotW1WiredHost(
  LotW1Seams s, {
  ZReviewMode mode = ZReviewMode.learn,
  int cards = 2,
}) =>
    ZStudySessionHost.wired(
      wiring: lotW1Wiring(s),
      mode: mode,
      queue: writtenCards(cards),
    );

Widget _wrap(Widget child) =>
    MaterialApp(home: ZcrudScope(child: Scaffold(body: child)));

/// Arbre RÉELLEMENT monté, nœud pour nœud.
List<String> treeDump(WidgetTester tester) => tester.allWidgets
    .map((Widget w) => w.runtimeType.toString())
    .toList(growable: false);

/// Le dump figé sur disque AVANT le lot.
List<String> baseline(String name) {
  final File file = File('${zsrc.packageRoot().path}/test/support/$name');
  if (!file.existsSync()) {
    throw StateError('dump de référence introuvable : ${file.path} — la '
        'garde d\'inertie ne mesure plus rien');
  }
  return file.readAsLinesSync();
}

Material _buttonMaterial(WidgetTester tester, int q) => tester.widget<Material>(
      find
          .descendant(
            of: find.byKey(
                ValueKey<String>('${ZSrsQualityButtons.buttonKeyPrefix}$q')),
            matching: find.byType(Material),
          )
          .first,
    );

// ═══════════════════════════════════════════════════════════════════════════
// 3. LES SONDES — un effet observable par seam, et sa contre-preuve
// ═══════════════════════════════════════════════════════════════════════════

/// Ce qu'on fait à l'écran avant d'observer.
typedef Drive = Future<void> Function(WidgetTester tester);

/// Ce qu'on observe, avec ou sans le seam.
typedef Observe = Future<void> Function(WidgetTester tester, LotW1Seams s);

/// Sonde d'un seam : la scène, ce qu'on retire d'office, ce qu'on conduit, et
/// les deux observations.
typedef SeamProbe = ({
  W1Scene scene,
  ZReviewMode mode,
  Set<String> baseOmit,
  int cards,
  Drive drive,
  Observe present,
  Observe absent,
});

Future<void> _idle(WidgetTester tester) async {}

Future<void> _submit(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const ValueKey<String>('zAnswerField')),
    'ma réponse',
  );
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey<String>('zSubmit')));
  await tester.pumpAndSettle();
}

/// Conduit la session jusqu'à son épuisement.
///
/// La continuation est tentée AVANT la soumission : depuis la retenue
/// post-soumission, la surface de saisie reste montée mais gelée — retaper
/// « je ne sais pas » ne ferait plus rien, et la boucle tournerait à vide sur
/// une session jamais terminée.
Future<void> _finish(WidgetTester tester) async {
  for (int i = 0; i < 8; i++) {
    final Finder cont = find.byKey(ZStudySessionHost.continueActionKey);
    if (cont.evaluate().isNotEmpty) {
      await tester.tap(cont);
      await tester.pumpAndSettle();
      continue;
    }
    if (find.byKey(const ValueKey<String>('zAnswerField')).evaluate().isEmpty) {
      return;
    }
    // Une réponse SOUMISE, jamais « je ne sais pas » : un lapse réinsère la
    // carte dans la file du moteur SRS, et la session ne s'épuiserait jamais.
    await _submit(tester);
  }
}

Observe _text(String value, {required bool expected}) =>
    (WidgetTester tester, LotW1Seams s) async => expect(
          find.text(value),
          expected ? findsWidgets : findsNothing,
          reason: expected
              ? '🔴 l\'effet du seam n\'atteint pas l\'écran par `.wired`'
              : '🔴 l\'effet observé survit au retrait du seam : '
                  'l\'observation ne mesure pas ce seam',
        );

Observe _key(Key key, {required bool expected}) =>
    (WidgetTester tester, LotW1Seams s) async => expect(
          find.byKey(key),
          expected ? findsWidgets : findsNothing,
        );

/// Une sonde par seam. La clé est le NOM DU CHAMP du wiring : la garde de
/// complétude compare cet ensemble à la source.
final Map<String, SeamProbe> kProbes = <String, SeamProbe>{
  'reviewer': (
    scene: W1Scene.socle,
    mode: ZReviewMode.learn,
    baseOmit: const <String>{},
    cards: 2,
    drive: _idle,
    present: _key(const ValueKey<String>('zAnswerField'), expected: true),
    absent: _key(const ValueKey<String>('zAnswerField'), expected: false),
  ),
  'cardBuilder': (
    scene: W1Scene.hote,
    mode: ZReviewMode.learn,
    baseOmit: const <String>{'cardSlotBuilder', 'gradingBuilder'},
    cards: 2,
    drive: _idle,
    present: _text('$kW1:carte:c0', expected: true),
    absent: _text('$kW1:carte:c0', expected: false),
  ),
  'cardSlotBuilder': (
    scene: W1Scene.hote,
    mode: ZReviewMode.learn,
    baseOmit: const <String>{'gradingBuilder'},
    cards: 2,
    drive: _idle,
    present: _text('$kW1:creneau:c0', expected: true),
    absent: _text('$kW1:creneau:c0', expected: false),
  ),
  'contentBuilder': (
    scene: W1Scene.socle,
    mode: ZReviewMode.learn,
    baseOmit: const <String>{},
    cards: 2,
    drive: _idle,
    present: _text('$kW1:contenu', expected: true),
    absent: _text('$kW1:contenu', expected: false),
  ),
  'questionTypeBadgeBuilder': (
    scene: W1Scene.socle,
    mode: ZReviewMode.learn,
    baseOmit: const <String>{},
    cards: 2,
    drive: _idle,
    present: _text('$kW1:pastille', expected: true),
    absent: _text('$kW1:pastille', expected: false),
  ),
  'instructionBanner': (
    scene: W1Scene.socle,
    mode: ZReviewMode.learn,
    baseOmit: const <String>{},
    cards: 2,
    drive: _idle,
    present: _text('$kW1:consigne', expected: true),
    absent: _text('$kW1:consigne', expected: false),
  ),
  'evaluationPort': (
    scene: W1Scene.socle,
    mode: ZReviewMode.learn,
    baseOmit: const <String>{},
    cards: 2,
    drive: _submit,
    present: (WidgetTester tester, LotW1Seams s) async {
      expect(find.text('$kW1:bareme'), findsWidgets,
          reason: '🔴 le retour du barème n\'est pas rendu');
      expect(s.evalSpy.calls, greaterThan(0),
          reason: '🔴 le port n\'a jamais été appelé');
    },
    absent: _text('$kW1:bareme', expected: false),
  ),
  'hintPort': (
    scene: W1Scene.socle,
    mode: ZReviewMode.learn,
    baseOmit: const <String>{},
    cards: 2,
    drive: _idle,
    present: _key(const ValueKey<String>('zHintButton'), expected: true),
    absent: _key(const ValueKey<String>('zHintButton'), expected: false),
  ),
  'onQualitySelected': (
    scene: W1Scene.socle,
    mode: ZReviewMode.learn,
    baseOmit: const <String>{},
    cards: 2,
    drive: _submit,
    present: (WidgetTester tester, LotW1Seams s) async {
      expect(find.byType(ZSrsQualityButtons), findsOneWidget);
      await tester.tap(find.byKey(
          ValueKey<String>('${ZSrsQualityButtons.buttonKeyPrefix}5')));
      await tester.pumpAndSettle();
      expect(s.qualityTaps, <int>[5],
          reason: '🔴 commande morte : le cran tapé n\'atteint pas l\'hôte');
    },
    absent: (WidgetTester tester, LotW1Seams s) async =>
        expect(find.byType(ZSrsQualityButtons), findsNothing),
  ),
  'qualityColorKeyFor': (
    scene: W1Scene.socle,
    mode: ZReviewMode.learn,
    baseOmit: const <String>{},
    cards: 2,
    drive: _submit,
    present: (WidgetTester tester, LotW1Seams s) async => expect(
          _buttonMaterial(tester, 5).color,
          _buttonMaterial(tester, 0).color,
          reason: '🔴 la clé CONSTANTE n\'atteint pas la rangée : les crans '
              'restent peints par le seuil de réussite',
        ),
    absent: (WidgetTester tester, LotW1Seams s) async => expect(
          _buttonMaterial(tester, 5).color,
          isNot(_buttonMaterial(tester, 0).color),
          reason: 'sans le seam, réussite et lapse se peignent DIFFÉREMMENT — '
              'sans quoi l\'observation ne prouverait rien',
        ),
  ),
  'qualityPreviewLabelFor': (
    scene: W1Scene.socle,
    mode: ZReviewMode.learn,
    baseOmit: const <String>{},
    cards: 2,
    drive: _submit,
    present: _text('$kW1:J+5', expected: true),
    absent: _text('$kW1:J+5', expected: false),
  ),
  'headerBuilder': (
    scene: W1Scene.socle,
    mode: ZReviewMode.learn,
    baseOmit: const <String>{},
    cards: 2,
    drive: _idle,
    present: _text('$kW1:entete', expected: true),
    absent: _text('$kW1:entete', expected: false),
  ),
  'counterBuilder': (
    scene: W1Scene.socle,
    mode: ZReviewMode.learn,
    baseOmit: const <String>{},
    cards: 2,
    drive: _idle,
    present: _text('$kW1:compteur', expected: true),
    absent: _text('$kW1:compteur', expected: false),
  ),
  'gradingBuilder': (
    scene: W1Scene.hote,
    mode: ZReviewMode.learn,
    baseOmit: const <String>{},
    cards: 2,
    drive: _idle,
    present: _text('$kW1:notation', expected: true),
    absent: _text('$kW1:notation', expected: false),
  ),
  'summaryBuilder': (
    scene: W1Scene.socle,
    mode: ZReviewMode.learn,
    baseOmit: const <String>{},
    cards: 1,
    drive: _finish,
    present: _text('$kW1:resume', expected: true),
    absent: _text('$kW1:resume', expected: false),
  ),
  'emptyBuilder': (
    scene: W1Scene.socle,
    mode: ZReviewMode.learn,
    baseOmit: const <String>{},
    cards: 0,
    drive: _idle,
    present: _text('$kW1:vide', expected: true),
    absent: _text('$kW1:vide', expected: false),
  ),
  'celebrationBuilder': (
    scene: W1Scene.socle,
    mode: ZReviewMode.learn,
    baseOmit: const <String>{},
    cards: 1,
    drive: _finish,
    present: _text('$kW1:bravo', expected: true),
    absent: _text('$kW1:bravo', expected: false),
  ),
  'labels': (
    scene: W1Scene.socle,
    mode: ZReviewMode.learn,
    baseOmit: const <String>{'emptyBuilder'},
    cards: 0,
    drive: _idle,
    present: _text('$kW1:message-vide', expected: true),
    absent: _text('$kW1:message-vide', expected: false),
  ),
  'onSessionEnd': (
    scene: W1Scene.socle,
    mode: ZReviewMode.learn,
    baseOmit: const <String>{},
    cards: 1,
    drive: _finish,
    present: (WidgetTester tester, LotW1Seams s) async {
      expect(find.text('$kW1:resume'), findsWidgets,
          reason: 'la conduite atteint bien la fin de session');
      expect(s.ends, hasLength(1),
          reason: '🔴 la notification de fin n\'atteint pas l\'hôte');
    },
    absent: (WidgetTester tester, LotW1Seams s) async {
      expect(find.text('$kW1:resume'), findsWidgets,
          reason: '🔴 la conduite n\'atteint plus la fin : le `isEmpty` qui '
              'suit ne prouverait rien');
      expect(s.ends, isEmpty);
    },
  ),
  'onExit': (
    scene: W1Scene.socle,
    mode: ZReviewMode.learn,
    baseOmit: const <String>{'emptyBuilder'},
    cards: 0,
    drive: _idle,
    present: _key(ZStudySessionView.exitButtonKey, expected: true),
    absent: _key(ZStudySessionView.exitButtonKey, expected: false),
  ),
  'indexController': (
    scene: W1Scene.socle,
    mode: ZReviewMode.learn,
    baseOmit: const <String>{},
    cards: 2,
    drive: _idle,
    present: (WidgetTester tester, LotW1Seams s) async => expect(
          s.indexSpy.wasEverConsumed,
          isTrue,
          reason: '🔴 le contrôleur posé n\'est CONSOMMÉ par aucun nœud monté : '
              'il est inerte',
        ),
    absent: (WidgetTester tester, LotW1Seams s) async => expect(
          s.indexSpy.wasEverConsumed,
          isFalse,
          reason: 'sans le seam, le contrôleur reste vierge — sans quoi '
              'l\'observation ne prouverait rien',
        ),
  ),
  'preset': (
    scene: W1Scene.socle,
    mode: ZReviewMode.learn,
    baseOmit: const <String>{'headerBuilder'},
    cards: 2,
    drive: _idle,
    present: _text('$kW1:preset', expected: true),
    absent: _text('$kW1:preset', expected: false),
  ),
};

void main() {
  // ═════════════════════════════════════════════════════════════════════════
  // G1 — complétude du wiring
  // ═════════════════════════════════════════════════════════════════════════
  group('🧮 G1 — la partition mesurée EST l\'ensemble des champs du wiring',
      () {
    test('l\'extraction aboutit et n\'est pas vide', () {
      final Partition p = partitionOf(hostSource());
      expect(p.seams.length, greaterThan(15),
          reason: 'un scanner qui ne trouve presque rien est VACUEL');
      expect(p.cosmetics, isNotEmpty,
          reason: 'aucun cosmétique retranché ⇒ la règle de type ne fait rien');
      expect(wiringFields(hostSource()), isNotEmpty);
    });

    test('🔴 CHAQUE seam du porteur est un champ de `ZStudySessionWiring`, et '
        'RÉCIPROQUEMENT', () {
      final Partition p = partitionOf(hostSource());
      final Set<String> seams = p.seams.toSet();
      final Set<String> wired = wiringFields(hostSource()).toSet();
      expect(seams.difference(wired), isEmpty,
          reason: '🔴 seam du porteur ABSENT du wiring — il pourra être oublié '
              'en silence par un montage');
      expect(wired.difference(seams), isEmpty,
          reason: '🔴 champ du wiring qui n\'est plus un seam du porteur — le '
              'montage exige de nommer ce qui n\'existe plus');
      expect(seams.intersection(p.cosmetics.toSet()), isEmpty,
          reason: 'la partition doit être disjointe');
    });

    test('la partition classe bien les cas décidés', () {
      final Partition p = partitionOf(hostSource());
      for (final String seam in <String>[
        'preset',
        'questionTypeBadgeBuilder',
        'instructionBanner',
        'labels',
        'reviewer',
        'indexController',
      ]) {
        expect(p.seams, contains(seam));
      }
      for (final String cosmetic in <String>[
        'progressStyle',
        'progressDotsGeometry',
        'progressLinearThickness',
        'progressSegmentedMarkerThickness',
        'cardBackgroundColor',
        'cardTypeGradientKey',
        'cardAccentHeight',
        'counterStyle',
        'contentPadding',
        'seamAudit',
        'answerChoiceLayout',
        'answerActionsLayout',
        'answerSubmitWidth',
        'answerGradingVisibility',
        'questionFaceChoices',
        'backCardsContent',
      ]) {
        expect(p.cosmetics, contains(cosmetic));
      }
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  // G2 — non-vacuité du scanner (contre-preuves sur texte synthétique)
  // ═════════════════════════════════════════════════════════════════════════
  group('🧪 G2 — le scanner SIGNALE un seam neuf et se TAIT sur un cosmétique',
      () {
    String synthetic({required String param, required String field}) => '''
class ZStudySessionWiring {
  const ZStudySessionWiring({required this.reviewer});
  final ZSessionReviewer? reviewer;
}

class ZStudySessionHost extends StatefulWidget {
  const ZStudySessionHost({
    required this.mode,
    this.reviewer,
    $param
    this.counterStyle,
    super.key,
  });
  final ZReviewMode mode;
  final ZSessionReviewer? reviewer;
  $field
  final TextStyle? counterStyle;
}

class _ZStudySessionHostState extends State<ZStudySessionHost> {}
''';

    test('un PORT neuf (`ZSomePort?`) est classé SEAM', () {
      final Partition p = partitionOf(synthetic(
        param: 'this.newPort,',
        field: 'final ZSomePort? newPort;',
      ));
      expect(p.seams, contains('newPort'));
      expect(p.cosmetics, isNot(contains('newPort')));
    });

    test('🔴 l\'admission d\'un objet de géométrie ne vaut QUE pour lui', () {
      final Partition admis = partitionOf(synthetic(
        param: 'this.dotsGeometry,',
        field: 'final ZSessionDotsGeometry? dotsGeometry;',
      ));
      expect(admis.cosmetics, contains('dotsGeometry'),
          reason: 'le type admis NOMMÉMENT est bien retranché');

      final Partition voisin = partitionOf(synthetic(
        param: 'this.futureGeometry,',
        field: 'final ZFutureGeometry? futureGeometry;',
      ));
      expect(voisin.seams, contains('futureGeometry'),
          reason: '🔴 l\'admission a fui en règle de SUFFIXE : tout type '
              'nommé `…Geometry` entrerait désormais sans examen');
    });

    test('🔴 l\'admission du réglage de DIAGNOSTIC ne vaut QUE pour lui', () {
      final Partition admis = partitionOf(synthetic(
        param: 'this.seamAudit,',
        field: 'final ZStudySeamAuditPolicy? seamAudit;',
      ));
      expect(admis.cosmetics, contains('seamAudit'),
          reason: 'le type admis NOMMÉMENT est bien retranché');

      final Partition voisin = partitionOf(synthetic(
        param: 'this.futurePolicy,',
        field: 'final ZFuturePolicy? futurePolicy;',
      ));
      expect(voisin.seams, contains('futurePolicy'),
          reason: '🔴 l\'admission a fui en règle de SUFFIXE : tout type '
              'nommé `…Policy` entrerait désormais sans examen');
    });

    test('🔴 l\'admission des FORMES de saisie ne vaut QUE pour elles', () {
      const Map<String, String> admises = <String, String>{
        'choiceLayout': 'ZAnswerChoiceLayout',
        'actionsLayout': 'ZAnswerActionsLayout',
        'submitWidth': 'ZAnswerSubmitWidth',
        'gradingVisibility': 'ZAnswerGradingVisibility',
      };
      admises.forEach((String champ, String type) {
        final Partition p = partitionOf(synthetic(
          param: 'this.$champ,',
          field: 'final $type? $champ;',
        ));
        expect(p.cosmetics, contains(champ),
            reason: 'le type admis NOMMÉMENT n\'est pas retranché : $type');
      });

      // Contre-preuve : les trois SUFFIXES employés par ces admissions restent
      // sans pouvoir. Un type inédit qui les porterait entrerait sans examen si
      // l'admission avait fui en règle de suffixe.
      const Map<String, String> voisines = <String, String>{
        'futureLayout': 'ZFutureLayout',
        'futureWidth': 'ZFutureWidth',
        'futureVisibility': 'ZFutureVisibility',
      };
      voisines.forEach((String champ, String type) {
        final Partition p = partitionOf(synthetic(
          param: 'this.$champ,',
          field: 'final $type? $champ;',
        ));
        expect(p.seams, contains(champ),
            reason: '🔴 l\'admission a fui en règle de SUFFIXE : tout type '
                'nommé « $type » entrerait désormais sans examen');
      });
    });

    test('🔴 un PORT inédit reste un SEAM malgré les trois admissions', () {
      final Partition p = partitionOf(synthetic(
        param: 'this.otherPort,',
        field: 'final ZSomeOtherPort? otherPort;',
      ));
      expect(p.seams, contains('otherPort'),
          reason: '🔴 la règle fail-safe a été relâchée : un port inédit '
              'n\'est plus réclamé par le montage');
    });

    test('un ÉCART neuf (`double?`) est classé COSMÉTIQUE', () {
      final Partition p = partitionOf(synthetic(
        param: 'this.newGap,',
        field: 'final double? newGap;',
      ));
      expect(p.cosmetics, contains('newGap'));
      expect(p.seams, isNot(contains('newGap')));
    });

    test('🔴 la garde MORD : un seam neuf non câblé fait échouer la '
        'comparaison', () {
      final String muted = synthetic(
        param: 'this.newPort,',
        field: 'final ZSomePort? newPort;',
      );
      final Set<String> seams = partitionOf(muted).seams.toSet();
      final Set<String> wired = wiringFields(muted).toSet();
      expect(seams.difference(wired), contains('newPort'),
          reason: 'sans cela, la garde G1 resterait verte sur un seam oublié');
    });

    test('la garde LÈVE si le constructeur est renommé', () {
      final String muted = hostSource()
          .replaceAll('const ZStudySessionHost({', 'const Autre({');
      expect(() => partitionOf(muted), throwsStateError);
    });

    test('la garde LÈVE si la classe du wiring disparaît', () {
      final String muted =
          hostSource().replaceAll('class ZStudySessionWiring {', 'class X {');
      expect(() => wiringFields(muted), throwsStateError);
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  // G3 — `required` réel sur chaque champ du wiring
  // ═════════════════════════════════════════════════════════════════════════
  group('🔒 G3 — chaque champ du wiring est `required`, et sans défaut', () {
    List<CtorParam> wiringCtor(String source) =>
        ctorParams(ctorBlock(source, '  const ZStudySessionWiring({'));

    test('l\'extraction aboutit', () {
      expect(wiringCtor(hostSource()).length, greaterThan(15));
    });

    test('🔴 AUCUN champ n\'est optionnel, AUCUN ne porte de valeur par défaut',
        () {
      final List<CtorParam> params = wiringCtor(hostSource());
      final List<String> lax = params
          .where((CtorParam p) => !p.isRequired || p.hasDefault)
          .map((CtorParam p) => p.name)
          .toList();
      expect(lax, isEmpty,
          reason: '🔴 un champ optionnel (ou à défaut `= null`) rouvre le trou '
              'que ce type ferme : on l\'omet, on ne le nomme pas');
    });

    test('le constructeur énumère EXACTEMENT les champs de la classe', () {
      expect(
        wiringCtor(hostSource()).map((CtorParam p) => p.name).toSet(),
        wiringFields(hostSource()).toSet(),
      );
    });

    test('🔴 le détecteur MORD : un champ non requis est signalé', () {
      const String muted = '''
  const ZStudySessionWiring({
    required this.reviewer,
    this.hintPort,
  });
''';
      final List<CtorParam> params =
          ctorParams(ctorBlock(muted, '  const ZStudySessionWiring({'));
      expect(
        params.where((CtorParam p) => !p.isRequired).map((CtorParam p) => p.name),
        contains('hintPort'),
      );
    });

    test('🔴 le détecteur MORD : un défaut `= null` est signalé', () {
      const String muted = '''
  const ZStudySessionWiring({
    required this.reviewer,
    required this.hintPort = null,
  });
''';
      final List<CtorParam> params =
          ctorParams(ctorBlock(muted, '  const ZStudySessionWiring({'));
      expect(
        params.where((CtorParam p) => p.hasDefault).map((CtorParam p) => p.name),
        contains('hintPort'),
      );
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  // G4a — transfert exhaustif, mesuré dans la SOURCE
  // ═════════════════════════════════════════════════════════════════════════
  group('🔁 G4a — un `x = wiring.x` par champ, une seule fois', () {
    String wiredBody(String source) {
      const String head = '  ZStudySessionHost.wired({';
      final int start = source.indexOf(head);
      if (start < 0) {
        throw StateError('constructeur `.wired` introuvable — la garde est '
            'aveugle');
      }
      // La liste d'initialisation se ferme au PREMIER `;` : aucun paramètre
      // du bloc nommé n'en porte (leurs valeurs par défaut sont des
      // expressions, jamais des instructions).
      final int end = source.indexOf(';', start);
      if (end < 0) throw StateError('liste d\'initialisation non terminée');
      return source.substring(start, end + 1);
    }

    test('CHAQUE champ est transféré, exactement une fois', () {
      final String body = wiredBody(hostSource());
      for (final String f in wiringFields(hostSource())) {
        final int hits = RegExp('(?:^|\\s)$f = wiring\\.$f[,;]')
            .allMatches(body)
            .length;
        expect(hits, 1,
            reason: '🔴 `$f` transféré $hits fois par `.wired` (attendu : 1)');
      }
    });

    test('AUCUNE lecture de `wiring.` en trop (pas de transfert croisé)', () {
      final String body = wiredBody(hostSource());
      expect(RegExp(r'wiring\.').allMatches(body).length,
          wiringFields(hostSource()).length);
    });

    test('🔴 `.wired` n\'accepte AUCUN seam à plat', () {
      final String head = ctorBlock(hostSource(), '  ZStudySessionHost.wired({');
      final Set<String> flat =
          ctorParams(head).map((CtorParam p) => p.name).toSet();
      expect(flat.intersection(wiringFields(hostSource()).toSet()), isEmpty,
          reason: '🔴 un seam posable à plat rouvrirait une règle de fusion');
    });

    test('🔴 le scanner MORD : un transfert retiré est signalé', () {
      final String muted = hostSource()
          .replaceFirst('hintPort = wiring.hintPort,', 'hintPort = null,');
      expect(muted, isNot(hostSource()), reason: 'mutation non appliquée');
      final String body = wiredBody(muted);
      expect(RegExp(r'(?:^|\s)hintPort = wiring\.hintPort[,;]').allMatches(body),
          isEmpty);
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  // G4b — l'effet de CHAQUE seam, observé à l'écran
  // ═════════════════════════════════════════════════════════════════════════
  group('👁️ G4b — chaque seam transféré atteint le rendu ou le comportement',
      () {
    test('une sonde par champ du wiring — ni plus, ni moins', () {
      expect(kProbes.keys.toSet(), wiringFields(hostSource()).toSet(),
          reason: '🔴 un seam sans sonde de comportement : son transfert ne '
              'serait prouvé que dans la source');
    });

    Future<LotW1Seams> mount(
      WidgetTester tester,
      SeamProbe probe, {
      required Set<String> omit,
    }) async {
      useTallSurface(tester);
      final LotW1Seams s = LotW1Seams(scene: probe.scene, omit: omit);
      await tester.pumpWidget(
        _wrap(lotW1WiredHost(s, mode: probe.mode, cards: probe.cards)),
      );
      await tester.pumpAndSettle();
      await probe.drive(tester);
      return s;
    }

    kProbes.forEach((String seam, SeamProbe probe) {
      testWidgets('`$seam` — posé : son effet est là', (tester) async {
        final LotW1Seams s = await mount(tester, probe, omit: probe.baseOmit);
        await probe.present(tester, s);
      });

      testWidgets('`$seam` — retiré : son effet DISPARAÎT (non-vacuité)',
          (tester) async {
        final LotW1Seams s = await mount(tester, probe,
            omit: <String>{...probe.baseOmit, seam});
        await probe.absent(tester, s);
      });
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  // Inertie — l'arbre de `.wired` EST celui du constructeur par défaut
  // ═════════════════════════════════════════════════════════════════════════
  group('🧊 inertie — arbre identique au dump figé AVANT le lot', () {
    String dumpName(W1Scene scene) =>
        'z_session_tree_before_lotw1_${scene.name}.txt';

    test('les dumps de référence sont non vides et portent la session', () {
      for (final W1Scene scene in W1Scene.values) {
        final List<String> dump = baseline(dumpName(scene));
        expect(dump, isNotEmpty);
        expect(dump, contains('ZStudySessionHost'),
            reason: '🔴 un dump sans porteur ne prouverait rien');
      }
    });

    for (final W1Scene scene in W1Scene.values) {
      testWidgets('${scene.name} : le constructeur PAR DÉFAUT est intact',
          (tester) async {
        useTallSurface(tester);
        await tester.pumpWidget(
          _wrap(lotW1FlatHost(LotW1Seams(scene: scene))),
        );
        await tester.pumpAndSettle();
        expect(treeDump(tester), baseline(dumpName(scene)),
            reason: '🔴 le lot a changé l\'arbre d\'un montage à plat');
      });

      testWidgets('${scene.name} : `.wired` rend le MÊME arbre, nœud pour nœud',
          (tester) async {
        useTallSurface(tester);
        await tester.pumpWidget(
          _wrap(lotW1WiredHost(LotW1Seams(scene: scene))),
        );
        await tester.pumpAndSettle();
        expect(treeDump(tester), baseline(dumpName(scene)),
            reason: '🔴 le constructeur de transfert ne rend pas l\'écran du '
                'constructeur par défaut');
      });
    }

    testWidgets('`.none()` ne pose RIEN — et le dump le montre',
        (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(
        _wrap(ZStudySessionHost.wired(
          wiring: const ZStudySessionWiring.none(),
          mode: ZReviewMode.list,
          queue: writtenCards(2),
        )),
      );
      await tester.pumpAndSettle();
      expect(treeDump(tester), isNot(baseline(dumpName(W1Scene.socle))),
          reason: 'un montage sans aucun seam ne peut pas rendre le même '
              'arbre qu\'un montage complet — sinon les dumps ne mesurent '
              'rien');
      expect(find.text('$kW1:entete'), findsNothing);
    });
  });
}
