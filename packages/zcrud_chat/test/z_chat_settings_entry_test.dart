/// Lot « mode Tile + sélecteur de modèle » (arbitrage 1 — HYBRIDE) —
/// **comportement** du modèle d'entrées déclaratif.
///
/// Ce que ce fichier MESURE (attendu ≠ ambiant, sujet monté, géométrie rendue) :
/// * **EN-K** — un kind INCONNU est **absent sans throw** (AD-10), et
///   `unknownEntryBuilder` le récupère quand l'hôte en fournit un ;
/// * **EN-O** — la règle des trois cas aux TROIS niveaux (entrée, kind,
///   section) et leur priorité (entrée > kind > défaut) ;
/// * **EN-S** — sections : injection des entrées d'hôte dans la section de
///   génération, en-tête rendu SEULEMENT si l'hôte a titré la section, entrée
///   à section orpheline JAMAIS perdue ;
/// * **EN-T** — kind `toggle` : geste porté, état à DEUX canaux (drapeau
///   `toggled` + texte d'état stylé CR-74), cible ≥ 48 dp en géométrie rendue ;
/// * **EN-N** — kind `numberBounded` : bornes APPLIQUÉES (jamais le
///   `MinMaxFormatter` mort d'IFFD), valeur écrêtée (AD-10) ;
/// * **EN-V** — kind `navigation` : geste, valeur d'hôte, glyphe de fin ;
/// * **EN-M** — la coche d'hôte (`selectionMark`) suit le segment CHOISI, et
///   lui seul ;
/// * **EN-G** — grep NÉGATIF : le fichier du modèle ne rend aucun widget et ne
///   porte aucun libellé affiché.
library;

import 'dart:io';
import 'dart:ui' show Tristate;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';

import 'support/z_chat_render_harness.dart';

String _fb(String key) => kZChatLabelFallbacks[key]!;

/// Le style peint — dernier maillon avant les pixels (patron CR74).
TextStyle _painted(WidgetTester tester, Finder finder) {
  final RenderParagraph p = tester.renderObject<RenderParagraph>(finder);
  expect(p.text.style, isNotNull);
  return p.text.style!;
}

/// Un contrôle d'HÔTE à kind inconnu du socle — la porte AD-4.
class _AlienControl implements ZChatSettingsControl {
  const _AlienControl();
  @override
  String get kind => 'hologramme';
}

Widget _sheet({
  required ZChatSettingsController controller,
  List<ZChatSettingsEntry> entries = const <ZChatSettingsEntry>[],
  List<ZChatSettingsSection> sections = const <ZChatSettingsSection>[],
  Map<String, ZChatSettingsEntryTileBuilder> entryBuilders =
      const <String, ZChatSettingsEntryTileBuilder>{},
  Map<String, ZChatSettingsEntryTileBuilder> kindBuilders =
      const <String, ZChatSettingsEntryTileBuilder>{},
  Map<String, ZChatSettingsTileBuilder> sectionBuilders =
      const <String, ZChatSettingsTileBuilder>{},
  ZChatSettingsEntryTileBuilder? unknownEntryBuilder,
}) => harness(
  SingleChildScrollView(
    child: ZChatSettingsSheet(
      controller: controller,
      entries: entries,
      sections: sections,
      entryBuilders: entryBuilders,
      kindBuilders: kindBuilders,
      sectionBuilders: sectionBuilders,
      unknownEntryBuilder: unknownEntryBuilder,
    ),
  ),
);

void main() {
  group('🔴 EN-K — kind INCONNU : absent SANS THROW (AD-10)', () {
    testWidgets('l\'entrée au kind que personne ne sait rendre est ABSENTE, '
        'la feuille reste montée et les familles standard rendent',
        (WidgetTester tester) async {
      final ZChatSettingsController c = ZChatSettingsController();
      addTearDown(c.dispose);
      await tester.pumpWidget(
        _sheet(
          controller: c,
          entries: const <ZChatSettingsEntry>[
            ZChatSettingsEntry(
              id: 'e-alien',
              title: ZChatSettingsLabel.text('Titre fantôme'),
              control: _AlienControl(),
            ),
          ],
        ),
      );
      // Aucune exception, l'entrée est absente…
      expect(tester.takeException(), isNull);
      expect(find.text('Titre fantôme'), findsNothing);
      // …et le SUJET est monté : les familles standard rendent bien (la garde
      // ne passe pas sur une feuille vide).
      expect(find.text(_fb(kZChatLabelResponseLength)), findsOneWidget);
    });

    testWidgets('`unknownEntryBuilder` RÉCUPÈRE l\'entrée — et reçoit '
        'l\'entrée elle-même', (WidgetTester tester) async {
      final ZChatSettingsController c = ZChatSettingsController();
      addTearDown(c.dispose);
      ZChatSettingsEntry? received;
      await tester.pumpWidget(
        _sheet(
          controller: c,
          entries: const <ZChatSettingsEntry>[
            ZChatSettingsEntry(
              id: 'e-alien',
              title: ZChatSettingsLabel.text('Titre fantôme'),
              control: _AlienControl(),
            ),
          ],
          unknownEntryBuilder:
              (BuildContext context, ZChatSettingsSlot slot,
                  ZChatSettingsEntry entry) {
            received = entry;
            return const Text('repli-hôte');
          },
        ),
      );
      expect(find.text('repli-hôte'), findsOneWidget);
      expect(received?.id, 'e-alien');
      expect(received?.kind, 'hologramme');
    });
  });

  group('🔴 EN-O — la règle des TROIS CAS, aux trois niveaux', () {
    ZChatSettingsEntry toggleEntry({String id = 'e-t'}) => ZChatSettingsEntry(
      id: id,
      title: const ZChatSettingsLabel.text('Interrupteur hôte'),
      control: ZChatToggleControl(value: false, onChanged: (bool _) {}),
    );

    testWidgets('`entryBuilders[id]` remplace ; rendre `null` RETIRE (AD-4)',
        (WidgetTester tester) async {
      final ZChatSettingsController c = ZChatSettingsController();
      addTearDown(c.dispose);
      await tester.pumpWidget(
        _sheet(
          controller: c,
          entries: <ZChatSettingsEntry>[toggleEntry()],
          entryBuilders: <String, ZChatSettingsEntryTileBuilder>{
            'e-t': (BuildContext _, ZChatSettingsSlot _, ZChatSettingsEntry _) =>
                const Text('remplacée'),
          },
        ),
      );
      expect(find.text('remplacée'), findsOneWidget);
      expect(find.text('Interrupteur hôte'), findsNothing);

      final ZChatSettingsController c2 = ZChatSettingsController();
      addTearDown(c2.dispose);
      await tester.pumpWidget(
        _sheet(
          controller: c2,
          entries: <ZChatSettingsEntry>[toggleEntry()],
          entryBuilders: <String, ZChatSettingsEntryTileBuilder>{
            'e-t': (BuildContext _, ZChatSettingsSlot _, ZChatSettingsEntry _) =>
                null,
          },
        ),
      );
      expect(find.text('Interrupteur hôte'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('`entryBuilders` PRIME sur `kindBuilders`, qui prime sur le '
        'défaut', (WidgetTester tester) async {
      final ZChatSettingsController c = ZChatSettingsController();
      addTearDown(c.dispose);
      await tester.pumpWidget(
        _sheet(
          controller: c,
          entries: <ZChatSettingsEntry>[toggleEntry()],
          entryBuilders: <String, ZChatSettingsEntryTileBuilder>{
            'e-t': (BuildContext _, ZChatSettingsSlot _, ZChatSettingsEntry _) =>
                const Text('par-entrée'),
          },
          kindBuilders: <String, ZChatSettingsEntryTileBuilder>{
            kZChatSettingsKindToggle:
                (BuildContext _, ZChatSettingsSlot _, ZChatSettingsEntry _) =>
                    const Text('par-kind'),
          },
        ),
      );
      expect(find.text('par-entrée'), findsOneWidget);
      expect(find.text('par-kind'), findsNothing);

      final ZChatSettingsController c2 = ZChatSettingsController();
      addTearDown(c2.dispose);
      await tester.pumpWidget(
        _sheet(
          controller: c2,
          entries: <ZChatSettingsEntry>[toggleEntry(id: 'e-u')],
          kindBuilders: <String, ZChatSettingsEntryTileBuilder>{
            kZChatSettingsKindToggle:
                (BuildContext _, ZChatSettingsSlot _, ZChatSettingsEntry _) =>
                    const Text('par-kind'),
          },
        ),
      );
      expect(find.text('par-kind'), findsOneWidget);
      expect(find.text('Interrupteur hôte'), findsNothing);
    });

    testWidgets('les kinds par défaut du socle sont SURCHARGEABLES par kind — '
         'y compris pour une famille STANDARD (via son entrée)',
        (WidgetTester tester) async {
      final ZChatSettingsController c = ZChatSettingsController();
      addTearDown(c.dispose);
      await tester.pumpWidget(
        _sheet(
          controller: c,
          entryBuilders: <String, ZChatSettingsEntryTileBuilder>{
            kZChatSettingsEntryResponseLength:
                (BuildContext _, ZChatSettingsSlot _, ZChatSettingsEntry e) =>
                    Text('verbosité-remplacée:${e.id}'),
          },
        ),
      );
      expect(
        find.text('verbosité-remplacée:$kZChatSettingsEntryResponseLength'),
        findsOneWidget,
      );
      expect(find.text(_fb(kZChatLabelResponseLength)), findsNothing);
      // Les autres familles, elles, rendent toujours (le remplacement est
      // CIBLÉ, pas global).
      expect(find.text(_fb(kZChatLabelLengthBias)), findsOneWidget);
    });

    testWidgets('`sectionBuilders` remplace le BLOC entier — et rendre `null` '
        'retire la section AVEC ses entrées d\'hôte',
        (WidgetTester tester) async {
      final ZChatSettingsController c = ZChatSettingsController();
      addTearDown(c.dispose);
      await tester.pumpWidget(
        _sheet(
          controller: c,
          entries: <ZChatSettingsEntry>[toggleEntry()],
          sectionBuilders: <String, ZChatSettingsTileBuilder>{
            kZChatSettingsSectionGeneration:
                (BuildContext _, ZChatSettingsSlot _) =>
                    const Text('section-remplacée'),
          },
        ),
      );
      expect(find.text('section-remplacée'), findsOneWidget);
      expect(find.text(_fb(kZChatLabelResponseLength)), findsNothing);
      expect(find.text('Interrupteur hôte'), findsNothing);

      final ZChatSettingsController c2 = ZChatSettingsController();
      addTearDown(c2.dispose);
      await tester.pumpWidget(
        _sheet(
          controller: c2,
          entries: <ZChatSettingsEntry>[toggleEntry()],
          sectionBuilders: <String, ZChatSettingsTileBuilder>{
            kZChatSettingsSectionGeneration:
                (BuildContext _, ZChatSettingsSlot _) => null,
          },
        ),
      );
      expect(find.text(_fb(kZChatLabelResponseLength)), findsNothing);
      expect(find.text('Interrupteur hôte'), findsNothing);
      // Le reste de la feuille tient toujours debout.
      expect(find.text(_fb(kZChatLabelCapabilities)), findsOneWidget);
    });
  });

  group('🔴 EN-S — sections : injection, en-têtes, orphelines', () {
    testWidgets('une entrée SANS sectionId rejoint la section de génération, '
        'APRÈS les familles standard', (WidgetTester tester) async {
      final ZChatSettingsController c = ZChatSettingsController();
      addTearDown(c.dispose);
      await tester.pumpWidget(
        _sheet(
          controller: c,
          entries: <ZChatSettingsEntry>[
            ZChatSettingsEntry(
              id: 'e-t',
              title: const ZChatSettingsLabel.text('Interrupteur hôte'),
              control: ZChatToggleControl(value: false, onChanged: (bool _) {}),
            ),
          ],
        ),
      );
      final List<String> texts = renderedTexts(tester);
      final int reveal = texts.indexOf(_fb(kZChatLabelRevealThinking));
      final int hostTile = texts.indexOf('Interrupteur hôte');
      final int capabilities = texts.indexOf(_fb(kZChatLabelCapabilities));
      expect(reveal, greaterThanOrEqualTo(0));
      expect(hostTile, greaterThan(reveal),
          reason: '🔴 l\'entrée d\'hôte doit suivre les familles standard');
      expect(capabilities, greaterThan(hostTile),
          reason: '🔴 …et précéder la tuile de capacités (même section)');
    });

    testWidgets('l\'en-tête de section n\'existe QUE titré par l\'hôte — le '
        'socle n\'en rend aucun par défaut', (WidgetTester tester) async {
      final ZChatSettingsController c = ZChatSettingsController();
      addTearDown(c.dispose);
      await tester.pumpWidget(
        _sheet(
          controller: c,
          sections: const <ZChatSettingsSection>[
            ZChatSettingsSection(
              id: kZChatSettingsSectionGeneration,
              title: ZChatSettingsLabel.text('Réglages du tuteur'),
            ),
            ZChatSettingsSection(
              id: 'section-hote',
              title: ZChatSettingsLabel.text('Documents du cours'),
            ),
          ],
          entries: <ZChatSettingsEntry>[
            ZChatSettingsEntry(
              id: 'e-doc',
              sectionId: 'section-hote',
              title: const ZChatSettingsLabel.text('Document Un'),
              control: ZChatToggleControl(value: false, onChanged: (bool _) {}),
            ),
          ],
        ),
      );
      expect(find.text('Réglages du tuteur'), findsOneWidget);
      expect(find.text('Documents du cours'), findsOneWidget);
      // L'en-tête est un VRAI en-tête sémantique.
      expect(
        collectSemantics(
          tester,
          (SemanticsNode n) =>
              n.label == 'Documents du cours' &&
              n.flagsCollection.isHeader,
        ),
        hasLength(1),
      );
      // Section d'hôte titrée mais VIDE ⇒ absente, en-tête compris (AD-4).
      final ZChatSettingsController c2 = ZChatSettingsController();
      addTearDown(c2.dispose);
      await tester.pumpWidget(
        _sheet(
          controller: c2,
          sections: const <ZChatSettingsSection>[
            ZChatSettingsSection(
              id: 'section-vide',
              title: ZChatSettingsLabel.text('Section sans entrée'),
            ),
          ],
        ),
      );
      expect(find.text('Section sans entrée'), findsNothing);
    });

    testWidgets('une entrée à section ORPHELINE (jamais déclarée) est rendue '
        'quand même — jamais perdue en silence (AD-10)',
        (WidgetTester tester) async {
      final ZChatSettingsController c = ZChatSettingsController();
      addTearDown(c.dispose);
      await tester.pumpWidget(
        _sheet(
          controller: c,
          entries: <ZChatSettingsEntry>[
            ZChatSettingsEntry(
              id: 'e-orpheline',
              sectionId: 'section-inconnue',
              title: const ZChatSettingsLabel.text('Entrée orpheline'),
              control: ZChatToggleControl(value: false, onChanged: (bool _) {}),
            ),
          ],
        ),
      );
      expect(find.text('Entrée orpheline'), findsOneWidget);
    });
  });

  group('🔴 EN-T — kind `toggle` : geste + DEUX canaux + 48 dp', () {
    testWidgets('le tap bascule, l\'état est annoncé (`toggled`) ET visible '
        '(texte d\'état stylé CR-74)', (WidgetTester tester) async {
      final ZChatSettingsController c = ZChatSettingsController();
      addTearDown(c.dispose);
      bool? emitted;
      Widget mount(bool value) => _sheet(
        controller: c,
        entries: <ZChatSettingsEntry>[
          ZChatSettingsEntry(
            id: 'e-t',
            title: const ZChatSettingsLabel.text('Réflexion élargie'),
            subtitle: const ZChatSettingsLabel.text('Sous-titre du réglage'),
            control: ZChatToggleControl(
              value: value,
              onChanged: (bool v) => emitted = v,
            ),
          ),
        ],
      );
      await tester.pumpWidget(mount(false));
      // OFF : texte d'état « Désactivé », style AMBIANT.
      final TextStyle off =
          _painted(tester, find.text(_fb(kZChatLabelToggleOff)));
      expect(off.fontWeight, isNot(kZChatSettingsReferenceSelectedWeight));
      // Le geste PORTE, avec la bonne valeur.
      await tester.tap(find.text(_fb(kZChatLabelToggleOff)));
      expect(emitted, isTrue);
      // ON : deux canaux — drapeau sémantique ET emphase peinte.
      await tester.pumpWidget(mount(true));
      final TextStyle on =
          _painted(tester, find.text(_fb(kZChatLabelToggleOn)));
      expect(on.fontWeight, kZChatSettingsReferenceSelectedWeight,
          reason: '🔴 l\'état actif doit être VISIBLE (canal CR-74), pas '
              'seulement sémantique');
      expect(
        collectSemantics(
          tester,
          (SemanticsNode n) =>
              n.label.contains('Réflexion élargie') &&
              n.flagsCollection.isToggled == Tristate.isTrue,
        ),
        hasLength(1),
        reason: '🔴 l\'état actif doit être ANNONCÉ (drapeau toggled)',
      );
      // Géométrie RENDUE ≥ 48 dp — jamais les contraintes.
      final Size size = tester.getSize(
        find.ancestor(
          of: find.text(_fb(kZChatLabelToggleOn)),
          matching: find.byType(ConstrainedBox),
        ).first,
      );
      expect(size.height, greaterThanOrEqualTo(48));
    });
  });

  group('🔴 EN-N — kind `numberBounded` : bornes APPLIQUÉES (AD-10)', () {
    testWidgets('à la borne haute, « augmenter » est inerte et désactivé ; '
        '« diminuer » émet la valeur bornée', (WidgetTester tester) async {
      final ZChatSettingsController c = ZChatSettingsController();
      addTearDown(c.dispose);
      final List<int> emitted = <int>[];
      await tester.pumpWidget(
        _sheet(
          controller: c,
          entries: <ZChatSettingsEntry>[
            ZChatSettingsEntry(
              id: 'e-n',
              title: const ZChatSettingsLabel.text('Nombre de cartes'),
              control: ZChatNumberControl(
                value: 9,
                min: 1,
                max: 9,
                onChanged: emitted.add,
              ),
            ),
          ],
        ),
      );
      expect(find.text('9'), findsOneWidget);
      // À la borne : le geste « augmenter » N'ÉMET PAS.
      await tester.tap(
        find.text(_fb(kZChatLabelIncrease)),
        warnIfMissed: false,
      );
      expect(emitted, isEmpty,
          reason: '🔴 le legacy IFFD laissait passer (formatter mort) — ici '
              'la borne est réelle');
      // …et l'affordance est ANNONCÉE désactivée.
      expect(
        collectSemantics(
          tester,
          (SemanticsNode n) =>
              n.label == _fb(kZChatLabelIncrease) &&
              n.flagsCollection.isEnabled == Tristate.isFalse,
        ),
        hasLength(1),
      );
      await tester.tap(find.text(_fb(kZChatLabelDecrease)));
      expect(emitted, <int>[8]);
    });

    testWidgets('une valeur d\'hôte HORS bornes est écrêtée au rendu — jamais '
        'un throw', (WidgetTester tester) async {
      final ZChatSettingsController c = ZChatSettingsController();
      addTearDown(c.dispose);
      await tester.pumpWidget(
        _sheet(
          controller: c,
          entries: <ZChatSettingsEntry>[
            ZChatSettingsEntry(
              id: 'e-n',
              title: const ZChatSettingsLabel.text('Nombre de cartes'),
              control: ZChatNumberControl(
                value: 42,
                min: 1,
                max: 9,
                onChanged: (int _) {},
              ),
            ),
          ],
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('9'), findsOneWidget);
      expect(find.text('42'), findsNothing);
    });
  });

  group('🔴 EN-V — kind `navigation` : geste, valeur, glyphe d\'hôte', () {
    testWidgets('la tuile navigue au tap, montre la valeur courante et le '
        'glyphe de fin — cible ≥ 48 dp', (WidgetTester tester) async {
      final ZChatSettingsController c = ZChatSettingsController();
      addTearDown(c.dispose);
      int opened = 0;
      await tester.pumpWidget(
        _sheet(
          controller: c,
          entries: <ZChatSettingsEntry>[
            ZChatSettingsEntry(
              id: 'e-nav',
              title: const ZChatSettingsLabel.text('Domaine du tuteur'),
              control: ZChatNavigationControl(
                onTap: () => opened++,
                value: const ZChatSettingsLabel.text('Aucun choisi'),
                trailing: const Text('›', key: ValueKey<String>('chevron')),
              ),
            ),
          ],
        ),
      );
      expect(find.text('Aucun choisi'), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('chevron')), findsOneWidget);
      await tester.tap(find.text('Domaine du tuteur'));
      expect(opened, 1);
      final Size size = tester.getSize(
        find.ancestor(
          of: find.text('Domaine du tuteur'),
          matching: find.byType(ConstrainedBox),
        ).first,
      );
      expect(size.height, greaterThanOrEqualTo(48));
    });
  });

  group('🔴 EN-M — la coche d\'hôte suit le segment CHOISI', () {
    testWidgets('`selectionMark` n\'apparaît QUE devant le segment choisi — '
        'et bouge avec lui', (WidgetTester tester) async {
      final ZChatSettingsController c = ZChatSettingsController();
      addTearDown(c.dispose);
      Widget mount(String selectedKey) => _sheet(
        controller: c,
        entries: <ZChatSettingsEntry>[
          ZChatSettingsEntry(
            id: 'e-scale',
            title: const ZChatSettingsLabel.text('Niveau du tuteur'),
            control: ZChatScaleControl(
              selectionMark:
                  const Text('✓', key: ValueKey<String>('coche')),
              choices: <ZChatSettingsChoice>[
                for (final String k in <String>['debutant', 'avance'])
                  ZChatSettingsChoice(
                    label: ZChatSettingsLabel.text('Niveau $k'),
                    selected: k == selectedKey,
                    onTap: () {},
                  ),
              ],
            ),
          ),
        ],
      );
      await tester.pumpWidget(mount('debutant'));
      expect(find.byKey(const ValueKey<String>('coche')), findsOneWidget);
      // La coche est DANS la rangée du segment choisi.
      expect(
        find.ancestor(
          of: find.byKey(const ValueKey<String>('coche')),
          matching: find.ancestor(
            of: find.text('Niveau debutant'),
            matching: find.byType(Row),
          ).first,
        ),
        findsOneWidget,
      );
      // Elle SUIT la sélection.
      await tester.pumpWidget(mount('avance'));
      expect(
        find.ancestor(
          of: find.byKey(const ValueKey<String>('coche')),
          matching: find.ancestor(
            of: find.text('Niveau avance'),
            matching: find.byType(Row),
          ).first,
        ),
        findsOneWidget,
      );
    });
  });

  group('🔴 EN-G — grep NÉGATIF : le modèle ne rend rien', () {
    test('`z_chat_settings_entry.dart` n\'instancie AUCUN widget de rendu — '
        'ses littéraux sont des clés machine, pas des libellés', () {
      final List<String> lines = File(
        'lib/src/presentation/view/z_chat_settings_entry.dart',
      ).readAsLinesSync();
      expect(lines.length, greaterThan(100),
          reason: '🔴 GARDE VACUELLE : fichier introuvable ou vide');
      final List<String> offenders = <String>[
        for (int i = 0; i < lines.length; i++)
          // Le CODE seul — un commentaire qui cite `Semantics(` n'est pas un
          // rendu (le motif avait accusé une ligne de dartdoc, mesuré).
          if (!lines[i].trimLeft().startsWith('//') &&
              RegExp(r'\b(Text|RichText|Row|Column|Semantics|Padding)\(')
                  .hasMatch(lines[i]))
            '${i + 1}: ${lines[i].trim()}',
      ];
      expect(offenders, isEmpty,
          reason: '🔴 le MODÈLE s\'est mis à rendre : la voie de rendu unique '
              '(CR-LEX-78) est dans la feuille, pas ici.\n'
              '${offenders.join('\n')}');
    });
  });
}
