/// Le chat s'aligne sur les références d'apparence du socle — lot Apparence D.
///
/// Ce que ce fichier prouve, et pourquoi chaque garde existe :
/// * **APPD-1** — `ZChatNotebookReference.busyPalette` est un **alias** de
///   `ZBusyPaletteReference.colors`, pas une copie identique à l'octet. La
///   garde est de SOURCE, et elle l'est par nécessité : Dart **canonicalise**
///   les listes `const`, donc deux recopies identiques à l'octet sont
///   `identical` — une garde d'identité d'instance serait verte sur la copie
///   qu'elle prétend interdire (mesuré : l'injection R3 correspondante n'a pas
///   rougi). Ce qui se mesure vraiment, c'est que le fichier du chat ne porte
///   plus les sept littéraux, et qu'il nomme la constante du socle.
/// * **APPD-2** — INERTIE ABSOLUE du défaut. Sous le profil de référence par
///   défaut, le skin résout **exactement** les mêmes couleurs qu'avant le lot,
///   et l'indicateur d'occupation monte le **même** cycle, au **même** tempo
///   (2 s), sur la **même** séquence. Les valeurs sont figées ici en toutes
///   lettres : une garde qui comparerait le rendu à lui-même resterait verte
///   si les deux côtés régressaient ensemble.
/// * **APPD-3** — le profil `neutral` obtient une SORTIE, et c'est tout ce
///   qu'il gagne : accents de référence remplacés par le rôle Material 3 de
///   l'hôte, séquence d'occupation ramenée à **une** teinte (donc aucune
///   animation), canaux non chromatiques des capacités **intacts**.
/// * **APPD-4** — le jeton de socle `ZcrudTheme.busyPalette` atteint le chat
///   et prime sur la référence, dans les deux profils ; le jeton de chat et le
///   paramètre de skin gardent leur préséance au-dessus de lui.
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/zcrud_core.dart';

import 'support/z_chat_fakes.dart';
import 'support/z_chat_render_harness.dart';
import 'support/z_chat_sources.dart';

/// Les sept teintes attendues, **écrites en toutes lettres** : la garde ne
/// compare pas la référence à elle-même.
const List<Color> _sept = <Color>[
  Color(0xFF2196F3),
  Color(0xFFF44336),
  Color(0xFFFFEB3B),
  Color(0xFFFF9800),
  Color(0xFF795548),
  Color(0xFF009688),
  Color(0xFF4CAF50),
];

/// Un `ColorScheme` **nommé**, pour que les valeurs neutres attendues soient
/// des littéraux vérifiables et non un calcul rejoué.
const ColorScheme _scheme = ColorScheme.light(
  primary: Color(0xFF102030),
  primaryContainer: Color(0xFF405060),
  onPrimaryContainer: Color(0xFF708090),
);

const IconData _icon = IconData(0xE9A0);

/// La surface contre laquelle l'indicateur mesure sa lisibilité. Le rendu ne
/// peint aucune teinte tant qu'aucune surface n'est connue (repli fermant du
/// paquet) : une garde qui l'omettrait mesurerait ce repli, pas la palette.
const Color _surface = Color(0xFFFFFFFF);

/// Le profil neutre, porté par un thème qui déclare aussi sa surface.
const ZcrudTheme _neutre = ZcrudTheme(
  referenceProfile: ZReferenceProfile.neutral,
  surfaceColor: _surface,
);

/// Monte [child] sous un `ColorScheme` connu, et — si [theme] est fourni — un
/// `ZcrudScope` qui porte les jetons du socle.
Widget _host(Widget child, {ZcrudTheme? theme}) {
  final Widget inner = theme == null
      ? child
      : ZcrudScope(theme: theme, child: child);
  return MaterialApp(
    theme: ThemeData(colorScheme: _scheme),
    home: Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(body: inner),
    ),
  );
}

/// Le style résolu par [skin] sous [theme], dans un hôte au `ColorScheme`
/// connu.
Future<ZChatNotebookStyle> _resolve(
  WidgetTester tester, {
  ZChatNotebookSkin skin = const ZChatNotebookSkin(),
  ZcrudTheme? theme,
}) async {
  late ZChatNotebookStyle out;
  await tester.pumpWidget(
    _host(
      Builder(
        builder: (BuildContext context) {
          out = skin.resolve(context);
          return const SizedBox.shrink();
        },
      ),
      theme: theme,
    ),
  );
  return out;
}

/// Monte un notebook portant **un** artefact qui déclare une occupation en
/// cours, et rend le cycle réellement monté.
Future<ZColorCycle> _mountBusy(
  WidgetTester tester, {
  ZcrudTheme? theme,
  ZChatNotebookSkin? skin,
}) async {
  final rig = buildController(
    initialMessages: <ZChatMessage>[
      assistant(<ZContentBlock>[const ZTextBlock(text: 'corps')]),
    ],
  );
  addTearDown(rig.controller.dispose);
  await tester.pumpWidget(
    _host(
      ZChatNotebookView(
        controller: rig.controller,
        skin: skin,
        artifacts: <ZChatArtifactSpec>[
          ZChatArtifactSpec(
            key: kZChatCapabilityMindmap,
            icon: _icon,
            label: 'Carte mentale',
            presence: (ZChatMessage _) => true,
            busy: (ZChatMessage _) => true,
          ),
        ],
      ),
      theme: theme,
    ),
  );
  return tester.widget<ZColorCycle>(find.byType(ZColorCycle));
}

void main() {
  group('🔴 APPD-1 — la palette d\'occupation du chat est un ALIAS du socle',
      () {
    test('la source NOMME la constante du socle, au lieu de la recopier', () {
      final String source =
          stripped(libFile('view/z_chat_notebook_reference.dart')).join('\n');
      expect(
        source.contains('busyPalette = ZBusyPaletteReference.colors;'),
        isTrue,
        reason: '🔴 la table du chat ne pointe plus vers la constante du '
            'socle : les deux séquences peuvent désormais diverger en '
            'silence, ce que l\'alias empêchait.',
      );
    });

    test('…et le BRUN du cycle, témoin nommé, a bien quitté ce fichier', () {
      // Grep NÉGATIF, sur un témoin choisi parce qu\'il n\'appartient QU\'à la
      // palette d\'occupation : le bleu et le vert du cycle sont aussi des
      // accents de capacité, les chercher ne prouverait rien.
      final String source =
          stripped(libFile('view/z_chat_notebook_reference.dart')).join('\n');
      expect(
        source.contains('0xFF795548'),
        isFalse,
        reason: '🔴 le brun du cycle est de retour dans le fichier du chat : '
            'la séquence y a été recopiée.',
      );
    });

    test('…et la constante rendue porte les SEPT teintes, dans l\'ordre', () {
      // Sans cette moitié, l\'alias serait « bien branché » sur une liste vide.
      expect(ZChatNotebookReference.busyPalette, _sept);
      expect(ZChatNotebookReference.busyPalette, ZBusyPaletteReference.colors);
    });
  });

  group('🔴 APPD-2 — INERTIE ABSOLUE du rendu par défaut', () {
    testWidgets('le skin par défaut résout EXACTEMENT les couleurs d\'avant',
        (WidgetTester tester) async {
      final ZChatNotebookStyle s = await _resolve(tester);
      expect(s.toolAccentColor, const Color(0xFFFF9800));
      expect(s.busyPalette, _sept);
      expect(s.neutralAccent, isNull,
          reason: '🔴 le profil par défaut n\'est plus `legacy` : la référence '
              'ne gagne plus le dernier maillon');
      // Les neuf accents de capacité, un par un — un `??` mal placé n\'en
      // déplacerait qu\'un seul.
      const Map<String, Color> attendus = <String, Color>{
        kZChatCapabilityMindmap: Color(0xFFFF9800),
        kZChatCapabilityFlashcards: Color(0xFF2196F3),
        kZChatCapabilityStory: Color(0xFF009688),
        kZChatCapabilityHumour: Color(0xFFFFEB3B),
        kZChatCapabilityClassroom: Color(0xFF8BC34A),
        kZChatCapabilitySummary: Color(0xFF607D8B),
      };
      for (final MapEntry<String, Color> e in attendus.entries) {
        expect(s.capability(e.key)?.accent, e.value,
            reason: '🔴 l\'accent de référence de `${e.key}` a bougé');
      }
    });

    testWidgets('l\'indicateur d\'occupation monte le MÊME cycle, au MÊME '
        'tempo', (WidgetTester tester) async {
      final ZColorCycle cycle = await _mountBusy(tester);
      expect(cycle.palette, _sept,
          reason: '🔴 la séquence peinte par défaut n\'est plus celle du '
              'relevé');
      expect(cycle.period, const Duration(seconds: 2),
          reason: '🔴 le tempo par défaut a changé : la référence du socle '
              'porte 2 100 ms (7 × 300), le legacy du chat 2 000 ms — les '
              'confondre fait défiler la palette à une autre vitesse');
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets(
        '🔴 le carnet garde sa référence quand le socle, lui, ne la garde pas',
        (WidgetTester tester) async {
      // Le défaut GLOBAL du socle est `neutral` : `zBusyPaletteOf` rend `null`
      // sans profil déclaré. Le carnet ne suit PAS ce défaut — il possède sa
      // propre référence et la garde. Sans cette garde, un futur « alignement »
      // sur le socle éteindrait tout l'écran de chat en silence.
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (BuildContext context) {
              expect(
                zBusyPaletteOf(context),
                isNull,
                reason: 'sonde cassée : le socle rend déjà sa référence sans '
                    'profil, la garde ci-dessous ne prouverait plus rien',
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final ZChatNotebookStyle sansJeton = await _resolve(tester);
      final ZChatNotebookStyle scopeMuet =
          await _resolve(tester, theme: const ZcrudTheme());
      expect(sansJeton.busyPalette, _sept);
      expect(
        scopeMuet.busyPalette,
        _sept,
        reason: '🔴 un ZcrudScope MUET éteint la séquence du carnet : le '
            'repli local a été remplacé par le repli global',
      );
      expect(scopeMuet.toolAccentColor, sansJeton.toolAccentColor);
      expect(scopeMuet.neutralAccent, isNull);

      // …et l'échappatoire reste ENTIÈRE : `neutral` DÉCLARÉ éteint bien.
      final ZChatNotebookStyle neutre = await _resolve(
        tester,
        theme: const ZcrudTheme(referenceProfile: ZReferenceProfile.neutral),
      );
      expect(neutre.busyPalette, isEmpty);
      expect(neutre.toolAccentColor, isNot(sansJeton.toolAccentColor));
    });
  });

  group('🔴 APPD-3 — le profil `neutral` : les rôles M3, et rien d\'inventé',
      () {
    testWidgets('les accents de référence cèdent au rôle de l\'hôte',
        (WidgetTester tester) async {
      final ZChatNotebookStyle s = await _resolve(
        tester,
        theme: _neutre,
      );
      expect(s.toolAccentColor, _scheme.onPrimaryContainer,
          reason: '🔴 l\'accent d\'outils reste la teinte de référence sous un '
              'profil qui l\'a précisément refusée');
      expect(s.toolAccentColor,
          isNot(ZChatNotebookReference.toolAccentColor));
      expect(s.neutralAccent, _scheme.onPrimaryContainer);
      expect(s.capability(kZChatCapabilityMindmap)?.accent,
          _scheme.onPrimaryContainer);
      expect(s.capability(kZChatCapabilityFlashcards)?.accent,
          _scheme.onPrimaryContainer);
    });

    testWidgets('…mais les canaux NON chromatiques des capacités survivent',
        (WidgetTester tester) async {
      final ZChatNotebookStyle neutre = await _resolve(
        tester,
        theme: _neutre,
      );
      final ZChatNotebookCapabilityStyle? ref =
          ZChatNotebookReference.capabilities[kZChatCapabilityMindmap];
      final ZChatNotebookCapabilityStyle? vu =
          neutre.capability(kZChatCapabilityMindmap);
      expect(vu?.generatedLabelKey, ref?.generatedLabelKey);
      expect(vu?.generatedMarkSize, ref?.generatedMarkSize);
    });

    testWidgets('la séquence d\'occupation devient UNE teinte `primary`, donc '
        'AUCUNE animation', (WidgetTester tester) async {
      final ZChatNotebookStyle s = await _resolve(
        tester,
        theme: _neutre,
      );
      expect(s.busyPalette, isEmpty,
          reason: '🔴 aucune séquence n\'est due sous un profil neutre : la '
              'palette résolue doit être VIDE, et l\'appelant peindre une '
              'teinte ambiante');

      final ZColorCycle cycle = await _mountBusy(
        tester,
        theme: _neutre,
      );
      expect(cycle.palette, <Color>[_scheme.primary],
          reason: '🔴 l\'indicateur ne retombe pas sur le rôle `primary` de '
              'l\'hôte');
      expect(tester.hasRunningAnimations, isFalse,
          reason: '🔴 une seule teinte ne s\'anime pas : un contrôleur tourne '
              'pour rien');
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('🔴 APPD-4 — le jeton de SOCLE atteint le chat, et sa préséance', () {
    const List<Color> jetonSocle = <Color>[Color(0xFF010101), Color(0xFF020202)];

    testWidgets('posé, il prime sur la référence — dans les DEUX profils',
        (WidgetTester tester) async {
      final ZChatNotebookStyle legacy = await _resolve(
        tester,
        theme: const ZcrudTheme(busyPalette: jetonSocle),
      );
      expect(legacy.busyPalette, jetonSocle);

      final ZChatNotebookStyle neutre = await _resolve(
        tester,
        theme: const ZcrudTheme(
          busyPalette: jetonSocle,
          referenceProfile: ZReferenceProfile.neutral,
        ),
      );
      expect(neutre.busyPalette, jetonSocle,
          reason: '🔴 un profil neutre efface la RÉFÉRENCE, jamais un jeton '
              'que l\'hôte a posé');
    });

    testWidgets('le jeton de CHAT le bat, et le paramètre bat les deux',
        (WidgetTester tester) async {
      const List<Color> jetonChat = <Color>[Color(0xFF030303)];
      const List<Color> parametre = <Color>[Color(0xFF040404)];

      final ZChatNotebookStyle parJetonChat = await _resolve(
        tester,
        theme: const ZcrudTheme(
          busyPalette: jetonSocle,
          chatBusyPalette: jetonChat,
        ),
      );
      expect(parJetonChat.busyPalette, jetonChat);

      final ZChatNotebookStyle parParametre = await _resolve(
        tester,
        skin: const ZChatNotebookSkin(busyPalette: parametre),
        theme: const ZcrudTheme(
          busyPalette: jetonSocle,
          chatBusyPalette: jetonChat,
        ),
      );
      expect(parParametre.busyPalette, parametre);
    });

    testWidgets('et il atteint le CYCLE réellement monté, pas seulement le '
        'style résolu', (WidgetTester tester) async {
      final ZColorCycle cycle = await _mountBusy(
        tester,
        theme: const ZcrudTheme(
          busyPalette: jetonSocle,
          surfaceColor: _surface,
        ),
      );
      expect(cycle.palette, jetonSocle);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
