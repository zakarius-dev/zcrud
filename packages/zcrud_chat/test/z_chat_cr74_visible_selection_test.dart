/// CR-IFFD-74 — **l'option choisie doit se VOIR**, pas seulement s'entendre.
///
/// ## Le défaut, et pourquoi aucune garde ne l'avait vu
///
/// `SET-R1` mesurait que l'option choisie porte bien le drapeau sémantique
/// `selected`. Elle était verte, mordante, correctement écrite — et elle
/// **regardait à côté** : elle ne disait rien de ce qu'un utilisateur VOIT.
/// L'enfant rendu était `Text(resolved, textAlign: TextAlign.start)`, identique
/// choisi ou non ; deux captures successives de la feuille étaient identiques au
/// pixel près (mesuré sur appareil le 2026-08-07).
///
/// C'est le patron « une garde hérite de l'angle mort de son auteur » : la
/// correction sémantique d'origine était juste, mais elle avait **remplacé** le
/// canal visuel du legacy au lieu de s'y ajouter. On était passé de « un seul
/// canal, visuel » à « un seul canal, sémantique ».
///
/// ## Ce que ce fichier mesure — et qui manquait
///
/// * **CR74-V1** — LA garde du lot : le rendu **effectif** d'une option choisie
///   et celui d'une option non choisie **diffèrent visiblement**, sur les CINQ
///   familles de tuiles. Pas « le drapeau diffère » : le `TextStyle` porté par
///   le `RenderParagraph`, c'est-à-dire l'entrée réelle de la peinture ;
/// * **CR74-V2** — le canal sémantique est **INTACT** : il s'est ajouté un
///   canal, aucun n'a été remplacé (l'erreur symétrique de celle qu'on corrige) ;
/// * **CR74-V3** — une SEULE primitive porte le canal, donc les cinq familles
///   ne peuvent pas diverger (grep de source) ;
/// * **CR74-V4** — le « non mesuré » n°1 de la CR : **le geste porte-t-il ?**
///   Contrôleur instrumenté, les cinq gestes du socle sont observés, et le rendu
///   bascule après le tap — le tour complet, pas la moitié ;
/// * **CR74-V5** — le « non mesuré » n°2 : **le mode sombre**. Le canal est
///   invariant de luminosité, par construction et par mesure ;
/// * **CR74-V6** — **strictement additif** : l'option NON choisie rend
///   exactement le style hérité ;
/// * **CR74-V7** — **remplaçable** par paramètre, et la référence atteignable ;
/// * **CR74-V8** — le canal ne peut pas s'**ANNULER** contre un style ambiant
///   déjà gras, ni déjà gras ET souligné (AD-10).
@TestOn('vm')
library;

import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';

import 'support/z_chat_render_harness.dart' show collectSemantics;
import 'support/z_chat_sources.dart';

const String _sheetFile = 'lib/src/presentation/view/z_chat_settings_sheet.dart';

/// Clés de corpus **fictives** — le socle ne connaît aucun corpus réel.
const List<ZChatCorpusOption> _catalogue = <ZChatCorpusOption>[
  ZChatCorpusOption(key: 'corpus-alpha', label: 'Alpha'),
  ZChatCorpusOption(key: 'corpus-beta', label: 'Beta'),
];

/// Le repli français d'une clé.
String fb(String key) => kZChatLabelFallbacks[key]!;

/// Monte [child] dans un hôte minimal, avec une **luminosité** et un style
/// ambiant maîtrisés.
///
/// 🔴 `material` est importé ICI, dans le test : `lib/` n'en dépend pas.
/// Le `DefaultTextStyle` optionnel est posé SOUS le `Material` du `Scaffold` —
/// sinon celui de Material l'écraserait et la mesure serait vraie par vacuité.
Widget mount(
  Widget child, {
  Brightness brightness = Brightness.light,
  TextStyle? ambient,
}) {
  Widget tree = child;
  if (ambient != null) {
    tree = DefaultTextStyle(style: ambient, child: tree);
  }
  return MaterialApp(
    theme: ThemeData(brightness: brightness),
    home: Directionality(
      textDirection: TextDirection.ltr,
      // La feuille est un `Column(min)` qui ne défile pas d'elle-même : c'est
      // l'hôte qui la borne (cf. SET-T2).
      child: Scaffold(body: SingleChildScrollView(child: tree)),
    ),
  );
}

/// Le style **effectif** du texte peint pour [finder] — celui que porte le
/// `RenderParagraph`, donc l'entrée réelle de la peinture.
///
/// 🔴 Pas `tester.widget<Text>(…).style` : celui-là ne dit rien de ce qui est
/// hérité, et une garde ancrée dessus resterait verte si le style était écrasé
/// plus bas. Le `RenderParagraph` est le dernier maillon avant les pixels.
TextStyle painted(WidgetTester tester, Finder finder) {
  final RenderParagraph p = tester.renderObject<RenderParagraph>(finder);
  final TextStyle? style = p.text.style;
  expect(style, isNotNull,
      reason: '🔴 GARDE VACUELLE : le paragraphe peint n\'a AUCUN style');
  return style!;
}

/// Les canaux **visibles** d'un style, et eux seuls.
({FontWeight? weight, TextDecoration? decoration}) channels(TextStyle s) =>
    (weight: s.fontWeight, decoration: s.decoration);

/// Une famille de tuiles, montée **SEULE** : les quatre autres sont retirées de
/// l'arbre par un builder qui rend `null` (AD-4, mécanisme déjà mesuré par
/// SET-S3). C'est ce qui rend les libellés non ambigus sans inventer de sonde.
class _Family {
  const _Family({
    required this.name,
    required this.chosenLabel,
    required this.otherLabel,
    required this.select,
    required this.chosenIsLast,
  });

  /// Nom lisible, pour les messages d'échec.
  final String name;

  /// Libellé de l'option qui DOIT apparaître choisie.
  final String chosenLabel;

  /// Libellé d'une autre option de la MÊME famille.
  final String otherLabel;

  /// Pose l'état « [chosenLabel] est choisie » sur le contrôleur.
  final void Function(ZChatSettingsController c) select;

  /// `true` quand le libellé choisi est aussi celui du titre de groupe (la
  /// famille « raisonnement ») : le `Text` de l'OPTION est alors le dernier.
  final bool chosenIsLast;

  Finder get chosen =>
      chosenIsLast ? find.text(chosenLabel).last : find.text(chosenLabel);

  Finder get other => find.text(otherLabel);

  /// La feuille réduite à CETTE famille.
  ZChatSettingsSheet sheet(
    ZChatSettingsController c, {
    FontWeight? selectedWeight,
    TextDecoration? selectedDecoration,
  }) {
    Widget? drop(BuildContext context, ZChatSettingsSlot slot) => null;
    return ZChatSettingsSheet(
      controller: c,
      corpusCatalog: _catalogue,
      selectedWeight: selectedWeight,
      selectedDecoration: selectedDecoration,
      responseLengthBuilder: name == 'verbosité' ? null : drop,
      lengthBiasBuilder: name == 'biais' ? null : drop,
      computeBudgetBuilder: name == 'budget' ? null : drop,
      revealThinkingBuilder: name == 'raisonnement' ? null : drop,
      corpusBuilder: name == 'corpus' ? null : drop,
    );
  }
}

/// Les **CINQ** familles. La CR ne demandait que le catalogue de corpus ; les
/// quatre autres partagent la même primitive, donc le même défaut — c'est
/// vérifié ici, pas supposé.
final List<_Family> _kFamilies = <_Family>[
  _Family(
    name: 'verbosité',
    chosenLabel: fb(kZChatLabelLengthConcise),
    otherLabel: fb(kZChatLabelLengthStandard),
    chosenIsLast: false,
    select: (ZChatSettingsController c) =>
        c.setResponseLength(ZChatResponseLength.concise),
  ),
  _Family(
    name: 'biais',
    chosenLabel: fb(kZChatLabelBiasShorter),
    otherLabel: fb(kZChatLabelBiasLonger),
    chosenIsLast: false,
    select: (ZChatSettingsController c) =>
        c.setLengthBias(ZChatLengthBias.shorter),
  ),
  _Family(
    name: 'budget',
    chosenLabel: 'Niveau 3',
    otherLabel: 'Niveau 4',
    chosenIsLast: false,
    select: (ZChatSettingsController c) =>
        c.setComputeEffort(ZChatComputeEffort(3)),
  ),
  _Family(
    name: 'raisonnement',
    // 🔴 Le titre du groupe porte le MÊME libellé que l'option : le `Text` de
    // l'option est le dernier des deux (cf. [_Family.chosenIsLast]).
    chosenLabel: fb(kZChatLabelRevealThinking),
    otherLabel: fb(kZChatLabelSettingAuto),
    chosenIsLast: true,
    select: (ZChatSettingsController c) => c.setRevealThinkingSteps(true),
  ),
  _Family(
    name: 'corpus',
    chosenLabel: 'Alpha',
    otherLabel: 'Beta',
    chosenIsLast: false,
    select: (ZChatSettingsController c) => c.toggleCorpusKey('corpus-alpha'),
  ),
];

/// Contrôleur **instrumenté** : il note chaque geste reçu, sans rien changer à
/// son comportement (il délègue à `super`).
class _SpyController extends ZChatSettingsController {
  final List<String> gestures = <String>[];

  @override
  void setResponseLength(ZChatResponseLength? value) {
    gestures.add('setResponseLength');
    super.setResponseLength(value);
  }

  @override
  void setLengthBias(ZChatLengthBias? value) {
    gestures.add('setLengthBias');
    super.setLengthBias(value);
  }

  @override
  void setComputeEffort(ZChatComputeEffort? value) {
    gestures.add('setComputeEffort');
    super.setComputeEffort(value);
  }

  @override
  void setRevealThinkingSteps(bool? value) {
    gestures.add('setRevealThinkingSteps');
    super.setRevealThinkingSteps(value);
  }

  @override
  void toggleCorpusKey(String key) {
    gestures.add('toggleCorpusKey');
    super.toggleCorpusKey(key);
  }
}

/// Le geste attendu par famille — l'inverse de [_Family.select].
const Map<String, String> kExpectedGesture = <String, String>{
  'verbosité': 'setResponseLength',
  'biais': 'setLengthBias',
  'budget': 'setComputeEffort',
  'raisonnement': 'setRevealThinkingSteps',
  'corpus': 'toggleCorpusKey',
};

void main() {
  group('🔴 CR74-V1 — LE canal VISIBLE : choisi et non choisi ne se peignent '
      'PAS pareil, sur les CINQ familles', () {
    for (final _Family f in _kFamilies) {
      testWidgets('${f.name} — le style PEINT diffère (pas seulement le '
          'drapeau sémantique)', (WidgetTester tester) async {
        final ZChatSettingsController c = ZChatSettingsController();
        addTearDown(c.dispose);
        f.select(c);
        await tester.pumpWidget(mount(f.sheet(c)));

        // 🔬 Non-vacuité : les deux options sont bien à l'écran, sinon la
        // comparaison ci-dessous serait vraie faute de sujet.
        expect(f.chosen, findsOneWidget, reason: '🔴 ${f.name} : option choisie '
            'introuvable — garde VACUELLE');
        expect(f.other, findsOneWidget);

        final TextStyle chosen = painted(tester, f.chosen);
        final TextStyle other = painted(tester, f.other);

        expect(
          channels(chosen),
          isNot(channels(other)),
          reason: '🔴 CR-IFFD-74, LE défaut : dans la famille « ${f.name} », '
              'l\'option CHOISIE et une option non choisie se peignent à '
              'l\'identique. L\'utilisateur ne peut pas savoir ce qu\'il a '
              'choisi — ni même si son geste a porté. Deux captures '
              'successives sont identiques au pixel.\n'
              'choisie   : ${channels(chosen)}\n'
              'non choisie : ${channels(other)}',
        );
        // Et les DEUX canaux du socle sont réellement engagés, pas un seul.
        expect(chosen.fontWeight, kZChatSettingsReferenceSelectedWeight,
            reason: '🔴 ${f.name} : la GRAISSE d\'emphase n\'est pas appliquée');
        expect(chosen.decoration, kZChatSettingsReferenceSelectedDecoration,
            reason: '🔴 ${f.name} : le SOULIGNEMENT d\'emphase n\'est pas '
                'appliqué — il reste seul quand la graisse s\'annule');
      });
    }

    testWidgets('🔬 contre-preuve — SANS sélection, aucune option n\'est '
        'emphasée (le canal DISCRIMINE, il ne peint pas tout)', (
      WidgetTester tester,
    ) async {
      final ZChatSettingsController c = ZChatSettingsController();
      addTearDown(c.dispose);
      // Aucune sélection dans la famille « corpus » : `null` ⇒ « tous ».
      await tester.pumpWidget(mount(_kFamilies.last.sheet(c)));

      for (final String label in <String>['Alpha', 'Beta']) {
        final TextStyle s = painted(tester, find.text(label));
        expect(s.decoration, isNot(kZChatSettingsReferenceSelectedDecoration),
            reason: '🔴 « $label » est peinte comme CHOISIE alors que rien ne '
                'l\'est : le canal ne discriminerait rien');
        expect(s.fontWeight, isNot(kZChatSettingsReferenceSelectedWeight));
      }
    });
  });

  group('🔴 CR74-V2 — le canal SÉMANTIQUE est INTACT : on a AJOUTÉ, jamais '
      'remplacé', () {
    for (final _Family f in _kFamilies) {
      testWidgets('${f.name} — `selected` reste porté par le nœud qui porte le '
          'libellé, et par LUI SEUL', (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        final ZChatSettingsController c = ZChatSettingsController();
        addTearDown(c.dispose);
        f.select(c);
        await tester.pumpWidget(mount(f.sheet(c)));

        final List<SemanticsNode> hit = collectSemantics(
          tester,
          (SemanticsNode n) =>
              n.getSemanticsData().flagsCollection.isSelected ==
                  Tristate.isTrue &&
              n.label == f.chosenLabel,
        );
        expect(hit, hasLength(1),
            reason: '🔴 le lot CR-74 a AJOUTÉ un canal visible et PERDU le '
                'canal sémantique de « ${f.name} » : c\'est exactement '
                'l\'erreur qu\'il corrige, dans l\'autre sens. Un lecteur '
                'd\'écran réannoncerait des boutons indiscernables.');
        final List<SemanticsNode> wrong = collectSemantics(
          tester,
          (SemanticsNode n) =>
              n.getSemanticsData().flagsCollection.isSelected ==
                  Tristate.isTrue &&
              n.label == f.otherLabel,
        );
        expect(wrong, isEmpty,
            reason: '🔴 ${f.name} : une option NON choisie se dit choisie');
        handle.dispose();
      });
    }
  });

  group('🔴 CR74-V3 — UNE SEULE primitive porte le canal (grep de source)', () {
    test('`_ZChatSettingsOption` est déclarée une fois, et c\'est le seul site '
        'qui résout l\'emphase', () {
      final List<String> lines = stripped(libFile(_sheetFile));
      final String src = lines.join('\n');
      expect(
        RegExp(r'^class _ZChatSettingsOption\b', multiLine: true)
            .allMatches(src)
            .length,
        1,
        reason: '🔴 DEUX primitives d\'option : le canal visible peut diverger '
            'd\'une famille à l\'autre — c\'est ainsi que la CR n\'a trouvé le '
            'défaut que sur le catalogue de corpus.',
      );
      expect(RegExp(r'_optionStyles\(').allMatches(src).length, 2,
          reason: '🔴 la résolution du style d\'option doit exister à UN seul '
              'site d\'appel (plus sa déclaration) : un second site est un '
              'second rendu possible pour le même état.');
      // …et les CINQ familles passent bien par cette primitive.
      for (final String method in <String>[
        '_responseLength',
        '_lengthBias',
        '_computeBudget',
        '_revealThinking',
        '_corpus',
      ]) {
        final int start = lines.indexWhere(
          (String l) => l.contains('$method(BuildContext context'),
        );
        expect(start, greaterThanOrEqualTo(0),
            reason: '🔴 méthode `$method` introuvable — garde VACUELLE');
        int end = lines.length;
        for (int i = start + 1; i < lines.length; i++) {
          // Fin du membre : un membre suivant au même niveau, OU la fin de la
          // classe (sans quoi la dernière méthode avalerait tout le fichier et
          // la garde passerait pour la mauvaise raison).
          if (RegExp(r'^\}').hasMatch(lines[i]) ||
              (RegExp(r'^  \S').hasMatch(lines[i]) &&
                  !RegExp(r'^  [});]').hasMatch(lines[i]))) {
            end = i;
            break;
          }
        }
        expect(
          lines.sublist(start, end).join('\n'),
          contains('_ZChatSettingsOption'),
          reason: '🔴 la famille `$method` ne passe PAS par la primitive '
              'commune : son état choisi ne porterait aucun canal visible.',
        );
      }
    });

    test('🔴 le drapeau sémantique est TOUJOURS écrit dans la primitive', () {
      final String src = stripped(libFile(_sheetFile)).join('\n');
      expect(src, contains('selected: selected'),
          reason: '🔴 le canal sémantique a disparu de la source : le lot '
              'aurait REMPLACÉ un canal par un autre.');
      expect(src, contains('style: selected ?'),
          reason: '🔴 le canal VISIBLE a disparu de la source : retour au '
              '`Text` nu de CR-IFFD-74.');
    });
  });

  group('🔴 CR74-V4 — « non mesuré » n°1 de la CR : LE GESTE PORTE-T-IL ?', () {
    for (final _Family f in _kFamilies) {
      testWidgets('${f.name} — le tap atteint le CONTRÔLEUR, et le rendu '
          'BASCULE derrière', (WidgetTester tester) async {
        final _SpyController c = _SpyController();
        addTearDown(c.dispose);
        await tester.pumpWidget(mount(f.sheet(c)));

        final TextStyle before = painted(tester, f.chosen);
        await tester.tap(f.chosen);
        await tester.pump();

        // (1) le geste porte — instrumentation du contrôleur.
        expect(
          c.gestures,
          <String>[kExpectedGesture[f.name]!],
          reason: '🔴 « ${f.name} » : le tap n\'a atteint AUCUN geste du '
              'contrôleur (ou en a déclenché un autre). C\'est l\'hypothèse '
              'que la CR n\'avait pas pu écarter : « le geste ne porte pas » '
              'et « il porte sans retour » produisent la même capture. Gestes '
              'observés : ${c.gestures}',
        );

        // (2) …et il se VOIT — le tour complet, pas la moitié.
        final TextStyle after = painted(tester, f.chosen);
        expect(channels(after), isNot(channels(before)),
            reason: '🔴 « ${f.name} » : le geste a porté jusqu\'au contrôleur, '
                'mais l\'écran n\'a pas bougé. C\'est le défaut CR-IFFD-74 '
                'exactement — et c\'est pourquoi la mesure du geste SEUL ne '
                'suffisait pas.');
        expect(after.fontWeight, kZChatSettingsReferenceSelectedWeight);
        expect(after.decoration, kZChatSettingsReferenceSelectedDecoration);
      });
    }
  });

  group('🔴 CR74-V5 — « non mesuré » n°2 de la CR : le MODE SOMBRE', () {
    for (final Brightness b in Brightness.values) {
      testWidgets('en ${b.name}, le canal rend la MÊME différence', (
        WidgetTester tester,
      ) async {
        final ZChatSettingsController c = ZChatSettingsController();
        addTearDown(c.dispose);
        final _Family f = _kFamilies.first;
        f.select(c);
        await tester.pumpWidget(mount(f.sheet(c), brightness: b));

        final TextStyle chosen = painted(tester, f.chosen);
        final TextStyle other = painted(tester, f.other);
        expect(channels(chosen), isNot(channels(other)),
            reason: '🔴 en ${b.name}, l\'état choisi redevient INVISIBLE. '
                'C\'est ce que la CR n\'avait pas pu mesurer.');
        expect(chosen.fontWeight, kZChatSettingsReferenceSelectedWeight);
        expect(chosen.decoration, kZChatSettingsReferenceSelectedDecoration);
      });
    }

    testWidgets('🔴 et le canal est INVARIANT de luminosité — mesuré, pas '
        'supposé', (WidgetTester tester) async {
      final _Family f = _kFamilies.first;
      final Map<Brightness, ({FontWeight? weight, TextDecoration? decoration})>
      seen =
          <Brightness, ({FontWeight? weight, TextDecoration? decoration})>{};
      for (final Brightness b in Brightness.values) {
        final ZChatSettingsController c = ZChatSettingsController();
        addTearDown(c.dispose);
        f.select(c);
        await tester.pumpWidget(mount(f.sheet(c), brightness: b));
        seen[b] = channels(painted(tester, f.chosen));
      }
      expect(seen[Brightness.light], seen[Brightness.dark],
          reason: '🔴 le canal DÉPEND de la luminosité : c\'est la signature '
              'd\'un canal coloré, que FR-26 interdit au socle et que la CR '
              'redoutait ("une graisse ou un contour peut se comporter '
              'autrement"). Vu : $seen');
      // 🔬 Non-vacuité : la mesure a bien vu deux luminosités distinctes.
      expect(seen, hasLength(2));
    });
  });

  group('🔴 CR74-V6 — STRICTEMENT ADDITIF : l\'option non choisie ne bouge '
      'PAS', () {
    testWidgets('son style peint est EXACTEMENT le style hérité', (
      WidgetTester tester,
    ) async {
      const TextStyle ambient = TextStyle(fontSize: 17, letterSpacing: 1.5);
      final ZChatSettingsController c = ZChatSettingsController();
      addTearDown(c.dispose);
      final _Family f = _kFamilies.first;
      f.select(c);
      await tester.pumpWidget(mount(f.sheet(c), ambient: ambient));

      final TextStyle other = painted(tester, f.other);
      expect(other, ambient,
          reason: '🔴 le correctif a MODIFIÉ le rendu des options non '
              'choisies : il ne serait donc pas additif, et un hôte qui a posé '
              'son propre style le verrait bouger. Vu : $other');
      // …tandis que l'option choisie ne perd RIEN du style hérité non plus.
      final TextStyle chosen = painted(tester, f.chosen);
      expect(chosen.fontSize, ambient.fontSize);
      expect(chosen.letterSpacing, ambient.letterSpacing);
    });
  });

  group('🔴 CR74-V7 — REMPLAÇABLE : paramètre > référence', () {
    testWidgets('CR74-V7a — le PARAMÈTRE l\'emporte sur la référence', (
      WidgetTester tester,
    ) async {
      final ZChatSettingsController c = ZChatSettingsController();
      addTearDown(c.dispose);
      final _Family f = _kFamilies.first;
      f.select(c);
      await tester.pumpWidget(
        mount(
          f.sheet(
            c,
            selectedWeight: FontWeight.w300,
            selectedDecoration: TextDecoration.lineThrough,
          ),
        ),
      );
      final TextStyle chosen = painted(tester, f.chosen);
      expect(chosen.fontWeight, FontWeight.w300,
          reason: '🔴 le paramètre `selectedWeight` ne règle RIEN : le canal '
              'serait imposé par le socle, ce que FR-26 interdit');
      expect(chosen.decoration, TextDecoration.lineThrough);
      // 🔬 Non-vacuité : les valeurs du test ne sont PAS les références.
      expect(FontWeight.w300, isNot(kZChatSettingsReferenceSelectedWeight));
      expect(TextDecoration.lineThrough,
          isNot(kZChatSettingsReferenceSelectedDecoration));
    });

    testWidgets('CR74-V7b — un hôte peut ÉTEINDRE un canal sans perdre '
        'l\'autre', (WidgetTester tester) async {
      final ZChatSettingsController c = ZChatSettingsController();
      addTearDown(c.dispose);
      final _Family f = _kFamilies.first;
      f.select(c);
      await tester.pumpWidget(
        mount(f.sheet(c, selectedDecoration: TextDecoration.none)),
      );
      final TextStyle chosen = painted(tester, f.chosen);
      final TextStyle other = painted(tester, f.other);
      expect(chosen.decoration, TextDecoration.none);
      expect(channels(chosen), isNot(channels(other)),
          reason: '🔴 éteindre UN canal a rendu l\'état invisible : les deux '
              'canaux ne seraient donc pas indépendants');
    });

    testWidgets('CR74-V7c — sans paramètre, la RÉFÉRENCE est ATTEINTE', (
      WidgetTester tester,
    ) async {
      final ZChatSettingsController c = ZChatSettingsController();
      addTearDown(c.dispose);
      final _Family f = _kFamilies.first;
      f.select(c);
      await tester.pumpWidget(mount(f.sheet(c)));
      final TextStyle chosen = painted(tester, f.chosen);
      expect(chosen.fontWeight, kZChatSettingsReferenceSelectedWeight,
          reason: '🔴 la référence du socle est INATTEIGNABLE — une référence '
              'que rien n\'atteint est une garde vacante déguisée en '
              'gouvernance (même leçon que SET-T3)');
      expect(chosen.decoration, kZChatSettingsReferenceSelectedDecoration);
    });
  });

  group('🔴 CR74-V8 — le canal ne peut pas s\'ANNULER contre le style de '
      'l\'hôte (AD-10)', () {
    testWidgets('CR74-V8a — sous un ambiant DÉJÀ GRAS, la graisse s\'annule — '
        'et le soulignement SAUVE l\'état', (WidgetTester tester) async {
      final ZChatSettingsController c = ZChatSettingsController();
      addTearDown(c.dispose);
      final _Family f = _kFamilies.first;
      f.select(c);
      await tester.pumpWidget(
        mount(
          f.sheet(c),
          ambient: const TextStyle(
            fontWeight: kZChatSettingsReferenceSelectedWeight,
          ),
        ),
      );
      final TextStyle chosen = painted(tester, f.chosen);
      final TextStyle other = painted(tester, f.other);
      // 🔬 Le scénario est bien celui qu'on croit : la graisse est IDENTIQUE.
      expect(chosen.fontWeight, other.fontWeight,
          reason: '🔴 le scénario n\'est pas atteint : la garde ne mesure pas '
              'l\'annulation qu\'elle prétend mesurer');
      expect(channels(chosen), isNot(channels(other)),
          reason: '🔴 UN SEUL canal : sous un style ambiant gras, l\'état '
              'choisi redevient invisible. C\'est la mesure qui a fait '
              'retenir DEUX canaux plutôt qu\'une graisse seule.');
    });

    testWidgets('CR74-V8b — sous un ambiant GRAS **et** SOULIGNÉ, la '
        'différence subsiste encore', (WidgetTester tester) async {
      final ZChatSettingsController c = ZChatSettingsController();
      addTearDown(c.dispose);
      final _Family f = _kFamilies.first;
      f.select(c);
      await tester.pumpWidget(
        mount(
          f.sheet(c),
          ambient: const TextStyle(
            fontWeight: kZChatSettingsReferenceSelectedWeight,
            decoration: kZChatSettingsReferenceSelectedDecoration,
          ),
        ),
      );
      final TextStyle chosen = painted(tester, f.chosen);
      final TextStyle other = painted(tester, f.other);
      expect(channels(chosen), isNot(channels(other)),
          reason: '🔴 les DEUX canaux se sont annulés contre le style de '
              'l\'hôte : l\'état redevient invisible sans que personne '
              'l\'ait demandé. AD-10 exige un repli, pas une disparition.');
      expect(other.decoration, TextDecoration.none,
          reason: '🔴 le repli attendu est le RETRAIT du soulignement sur les '
              'options NON choisies — le seul qui ne dépende pas de ce que '
              'l\'hôte a posé');
      expect(chosen.decoration, kZChatSettingsReferenceSelectedDecoration);
    });

    testWidgets('🔬 CR74-V8c — hors de ce cas, le repli NE SE DÉCLENCHE PAS '
        '(il est ciblé, pas permanent)', (WidgetTester tester) async {
      const TextStyle ambient = TextStyle(
        decoration: TextDecoration.lineThrough,
      );
      final ZChatSettingsController c = ZChatSettingsController();
      addTearDown(c.dispose);
      final _Family f = _kFamilies.first;
      f.select(c);
      await tester.pumpWidget(mount(f.sheet(c), ambient: ambient));

      expect(painted(tester, f.other).decoration, TextDecoration.lineThrough,
          reason: '🔴 le repli a mangé la décoration de l\'hôte alors que les '
              'deux canaux fonctionnaient : le correctif ne serait plus '
              'additif');
      expect(
        painted(tester, f.chosen).decoration,
        TextDecoration.combine(<TextDecoration>[
          TextDecoration.lineThrough,
          kZChatSettingsReferenceSelectedDecoration,
        ]),
        reason: '🔴 l\'emphase a REMPLACÉ la décoration de l\'hôte au lieu de '
            's\'y ajouter',
      );
    });
  });
}
