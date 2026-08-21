/// Gardes du **rendu de référence du Notebook** — lot γ, CR-IFFD-72.
///
/// Elles ne vérifient pas que les valeurs *sont* celles du legacy (c'est le
/// travail du relevé, cité ligne par ligne dans le dartdoc de chaque
/// constante) : elles vérifient que **les défauts du legacy ne sont pas
/// reproduits**, et que l'exception FR-26 reste tenue par ses trois conditions.
@TestOn('vm')
library;

import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/zcrud_core.dart';

import 'support/z_chat_sources.dart';

/// Luminance relative WCAG 2.x d'une couleur opaque.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) +
      0.7152 * channel(c.g) +
      0.0722 * channel(c.b);
}

/// Rapport de contraste WCAG entre deux couleurs opaques.
double _contrast(Color a, Color b) {
  final double la = _luminance(a);
  final double lb = _luminance(b);
  final double hi = math.max(la, lb);
  final double lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

const Color _lightSurface = Color(0xFFFFFFFF);
const Color _darkSurface = Color(0xFF121212);

/// Le fichier de référence, dé-commenté.
List<String> _referenceSource() =>
    stripped(libFile('view/z_chat_notebook_reference.dart'));

void main() {
  group('🔴 REF-G1 — le défaut d\'accessibilité du legacy n\'est PAS reproduit',
      () {
    test('le bouton d\'envoi de référence est ≥ 48 dp, pas les 40 du legacy',
        () {
      expect(ZChatNotebookReference.sendButtonSize, greaterThanOrEqualTo(48.0),
          reason: '🔴 IFFD envoie depuis un `SizedBox(width: 40, height: 40)` '
              '(`chatbot_conversation_screen.dart:3369-3372`). Porter cette '
              'valeur ferait entrer un défaut d\'accessibilité PAR LA PORTE DE '
              'LA RÉFÉRENCE — l\'endroit exact où plus personne ne le '
              'discuterait.');
    });

    test('…et c\'est LE MÊME plancher que celui du reste du paquet', () {
      // Deux planchers qui divergeraient seraient pires qu'un seul : un hôte
      // lirait 48 dans la référence et 56 dans le composer, sans savoir lequel
      // fait foi.
      expect(ZChatNotebookReference.sendButtonSize, kZChatMinTapTarget);
    });

    test('la valeur legacy (40) n\'est déclarée NULLE PART dans la référence',
        () {
      // Une constante `legacySendButtonSize = 40` « pour mémoire » serait
      // lisible, donc utilisable, donc utilisée.
      final List<String> offenders = <String>[
        for (final String l in _referenceSource())
          if (RegExp(r'^\s*static const double \w*[Ss]end\w*\s*=\s*40\b')
              .hasMatch(l))
            l.trim(),
      ];
      expect(offenders, isEmpty, reason: '🔴 la taille legacy est redevenue '
          'exprimable : $offenders');
    });

    test('🔬 contre-preuve — le détecteur SAIT voir la déclaration interdite',
        () {
      final RegExp re =
          RegExp(r'^\s*static const double \w*[Ss]end\w*\s*=\s*40\b');
      expect(re.hasMatch('  static const double legacySendButtonSize = 40;'),
          isTrue);
      expect(re.hasMatch('  static const double sendButtonSize = 48;'), isFalse);
    });
  });

  group('🔴 REF-G2 — AD-13 : rien de non directionnel dans la référence', () {
    test('toutes les marges de référence sont `EdgeInsetsDirectional`', () {
      final Map<String, EdgeInsetsGeometry> insets = <String, EdgeInsetsGeometry>{
        'composerPadding': ZChatNotebookReference.composerPadding,
        'counterBadgePadding': ZChatNotebookReference.counterBadgePadding,
        'toolsSheetPadding': ZChatNotebookReference.toolsSheetPadding,
        'toolTilePadding': ZChatNotebookReference.toolTilePadding,
      };
      expect(insets, isNotEmpty);
      for (final MapEntry<String, EdgeInsetsGeometry> e in insets.entries) {
        expect(e.value, isA<EdgeInsetsDirectional>(),
            reason: '🔴 `${e.key}` n\'est pas directionnel : l\'interface se '
                'casse en RTL (AD-13).');
      }
    });

    test('aucun décalage n\'est nommé `left`/`right` — le legacy en a CINQ', () {
      // Le relevé du volet B liste 5 sites non directionnels (`Positioned(
      // right:)` ×3, `BorderRadius.only(topLeft:/topRight:)` ×2). Les porter
      // sous leur nom d'origine conduirait tout hôte lecteur à les reproduire.
      final List<String> offenders = <String>[
        for (final String l in _referenceSource())
          if (RegExp(r'\b\w*(Left|Right)Inset\b|\b(left|right):').hasMatch(l))
            l.trim(),
      ];
      expect(offenders, isEmpty,
          reason: '🔴 nom ou paramètre NON directionnel dans la '
              'référence :\n${offenders.join('\n')}');
      // …et les noms directionnels attendus sont bien PRÉSENTS (non-vacuité :
      // une garde d'absence est verte sur un fichier vide).
      final String all = _referenceSource().join('\n');
      expect(all, contains('attachBadgeEndInset'));
      expect(all, contains('perMessageActionBadgeEndInset'));
    });
  });

  group('🔴 REF-G3 — l\'information ne passe JAMAIS par la seule couleur', () {
    test('chaque capacité porte DEUX canaux non chromatiques, non vides', () {
      final Map<String, ZChatNotebookCapabilityStyle> caps =
          ZChatNotebookReference.capabilities;
      expect(caps, hasLength(9),
          reason: '🔴 le relevé legacy dénombre 9 capacités teintées '
              '(mindmap, flashcards, histoire, humour, chat, résumé, '
              'élaboration, exemples, poème). Le premier relevé n\'en '
              'comptait que 5 : CR-IFFD-84 a établi que la table était '
              'INCOMPLÈTE, pas fermée.');
      for (final MapEntry<String, ZChatNotebookCapabilityStyle> e
          in caps.entries) {
        expect(e.value.generatedLabelKey, isNotEmpty,
            reason: '🔴 `${e.key}` n\'a plus de canal TEXTUEL : sa teinte '
                'redevient le seul signal.');
        expect(e.value.generatedLabelKey, isIn(kZChatLabelKeys),
            reason: '🔴 `${e.key}` porte une clé que l\'hôte ne peut pas '
                'alimenter — un canal textuel invisible n\'est pas un canal.');
        expect(e.value.generatedMarkSize, greaterThan(0),
            reason: '🔴 `${e.key}` n\'a plus de canal de FORME.');
      }
    });

    test('la clé d\'état « déjà généré » a un repli LISIBLE (convention du '
        'paquet)', () {
      // `kZChatLabelKeys` et `kZChatLabelFallbacks` sont assertés ÉGAUX EN
      // ENSEMBLE par la garde HIGH-1 : une clé sans repli rend la suite rouge.
      expect(kZChatLabelFallbacks[kZChatLabelGenerated], isNotNull);
      expect(kZChatLabelFallbacks[kZChatLabelGenerated], isNotEmpty);
    });

    test('🔴 …et le canal non chromatique n\'est PAS thémable', () {
      // Un jeton qui pourrait effacer le libellé ou la pastille rouvrirait le
      // défaut. `ZChatNotebookSkin` n'expose donc que l'accent.
      final String skin = stripped(libFile('view/z_chat_notebook_skin.dart'))
          .join('\n');
      expect(skin, contains('capabilityAccents'));
      expect(skin.contains('generatedLabelKey:'), isTrue,
          reason: '🔴 le skin ne recopie plus le canal textuel de la '
              'référence : une capacité surchargée le perdrait');
      expect(
        RegExp(r'this\.(generatedLabelKey|generatedMarkSize)').hasMatch(skin),
        isFalse,
        reason: '🔴 un canal NON CHROMATIQUE est devenu réglable : la teinte '
            'peut redevenir le seul signal.',
      );
    });
  });

  group('🔴 REF-G4 — thème sombre ET clair : la palette legacy est MESURÉE', () {
    test('le contraste WCAG de chaque teinte est celui qui est documenté', () {
      // Des constantes ⇒ des mesures reproductibles. Si une teinte change, ce
      // test rougit et impose de refaire la mesure — c'est le patron
      // `ZFlashcardCardReference` (« la garde recalcule ces luminances »).
      const Map<String, List<double>> attendu = <String, List<double>>{
        kZChatCapabilityMindmap: <double>[2.16, 8.69],
        kZChatCapabilityFlashcards: <double>[3.12, 6.00],
        kZChatCapabilityStory: <double>[3.67, 5.10],
        kZChatCapabilityHumour: <double>[1.22, 15.34],
        kZChatCapabilityClassroom: <double>[2.10, 8.92],
        // 🔴 Les quatre entrées de CR-IFFD-84. `poem` est la SEULE des neuf à
        // échouer en thème sombre et à tenir en clair : c'est elle qui prouve
        // que la correction de rendu doit savoir ÉCLAIRCIR, pas seulement
        // assombrir.
        kZChatCapabilitySummary: <double>[4.37, 4.29],
        kZChatCapabilityElaboration: <double>[2.78, 6.74],
        kZChatCapabilityExamples: <double>[4.35, 4.31],
        kZChatCapabilityPoem: <double>[6.31, 2.97],
      };
      for (final MapEntry<String, List<double>> e in attendu.entries) {
        final Color accent =
            ZChatNotebookReference.capabilities[e.key]!.accent;
        expect(_contrast(accent, _lightSurface), closeTo(e.value[0], 0.02),
            reason: '🔴 le contraste CLAIR de `${e.key}` a changé');
        expect(_contrast(accent, _darkSurface), closeTo(e.value[1], 0.02),
            reason: '🔴 le contraste SOMBRE de `${e.key}` a changé');
      }
      expect(_contrast(ZChatNotebookReference.toolAccentColor, _lightSurface),
          closeTo(2.16, 0.02));
    });

    test('🔴 le VERDICT : 6 des 11 teintes distinctes échouent — et surtout en '
        'thème CLAIR', () {
      // C'est ce qui rend les canaux non chromatiques obligatoires, et non
      // recommandés. Le legacy n'adapte rien au thème (3 occurrences de
      // `Brightness`, toutes commentées) — nous ne recolorons pas, nous
      // retirons à la couleur sa charge d'information.
      final Set<Color> teintes = <Color>{
        for (final ZChatNotebookCapabilityStyle s
            in ZChatNotebookReference.capabilities.values)
          s.accent,
        ZChatNotebookReference.toolAccentColor,
        ...ZChatNotebookReference.busyPalette,
      };
      expect(teintes, hasLength(11),
          reason: '🔴 le nombre de teintes DISTINCTES a changé : la table du '
              'dartdoc doit être refaite. (8 avant CR-IFFD-84 ; +3 seulement '
              'pour 4 entrées, `elaboration` réutilisant le vert #4CAF50 déjà '
              'porté par la palette d\'occupation.)');

      final List<Color> echouent = <Color>[
        for (final Color c in teintes)
          if (_contrast(c, _lightSurface) < 3.0 ||
              _contrast(c, _darkSurface) < 3.0)
            c,
      ];
      // 🔵 Si ce compte BAISSE, c'est une bonne nouvelle — mais elle doit être
      // requalifiée, pas ignorée : le dartdoc affirme un chiffre.
      expect(echouent, hasLength(6),
          reason: '🔴 la palette a été recolorée : re-mesurez et requalifiez '
              'le verdict du dartdoc. Vu en échec : $echouent');

      // 🔴 Le contre-intuitif, et c'est le cœur du verdict : le problème est
      // majoritairement en thème CLAIR.
      final int echecsClair = teintes
          .where((Color c) => _contrast(c, _lightSurface) < 3.0)
          .length;
      final int echecsSombre = teintes
          .where((Color c) => _contrast(c, _darkSurface) < 3.0)
          .length;
      expect(echecsClair, 4);
      // 🔴 Passé de 1 à 2 avec CR-IFFD-84 : le violet du poème (#9C27B0)
      // mesure 2.97 sur `#121212`. Le comptage sombre n'est donc PAS
      // décoratif — il désigne une teinte qui a besoin d'être ÉCLAIRCIE.
      expect(echecsSombre, 2);
      expect(echecsClair, greaterThan(echecsSombre),
          reason: '🔴 le verdict du dartdoc (« surtout en clair ») est faux.');

      // Le pire cas mesuré — le jaune « humour » sur surface claire.
      final double pire = teintes
          .map((Color c) => _contrast(c, _lightSurface))
          .reduce(math.min);
      expect(pire, lessThan(1.5),
          reason: '🔴 le pire cas legacy (1.22:1) a disparu : la table du '
              'dartdoc ment désormais.');
    });
  });

  group('🔴 REF-G5 — le fichier de référence est le SEUL porteur de couleurs',
      () {
    test('aucun autre fichier de `lib/` ne porte de littéral de couleur', () {
      // C'est la condition n°1 de l'exception FR-26 (centralisation). La garde
      // de pureté le vérifie déjà pour tout `lib/` ; on l'asserte ICI aussi,
      // depuis la famille concernée, pour que la propriété ne dépende pas d'un
      // fichier de test que personne ne relie à celui-ci.
      final List<String> offenders = <String>[];
      for (final MapEntry<String, List<String>> e in strippedLib().entries) {
        final String path = e.key.replaceAll(r'\', '/');
        if (path.endsWith('view/z_chat_notebook_reference.dart') ||
            // Lot K2 (arbitrage owner 2026-08-07) : la famille « composer » a
            // son PROPRE fichier de référence audité — même exception FR-26
            // encadrée, même exemption NOMINATIVE (miroir de
            // `_kColorExemptFiles` dans `z_chat_purity_test.dart`).
            path.endsWith('view/z_chat_composer_reference.dart')) {
          continue;
        }
        for (int i = 0; i < e.value.length; i++) {
          if (RegExp(r'\bColor\(0x|\bColors\.').hasMatch(e.value[i])) {
            offenders.add('${e.key}:${i + 1}');
          }
        }
      }
      expect(offenders, isEmpty,
          reason: '🔴 une couleur littérale vit hors du fichier de référence '
              'audité : la centralisation est rompue.\n'
              '${offenders.join('\n')}');
    });

    test('…et le fichier de référence en porte RÉELLEMENT (non-vacuité)', () {
      final int couleurs = _referenceSource()
          .where((String l) => l.contains('Color(0x'))
          .length;
      expect(couleurs, greaterThanOrEqualTo(12),
          reason: '🔴 seulement $couleurs couleur(s) : soit la référence a '
              'été vidée, soit l\'extracteur est cassé — dans les deux cas le '
              'test ci-dessus ne prouve plus rien.');
    });
  });

  group('🔴 REF-G6 — ce qui est délibérément ABSENT de la référence', () {
    test('aucune échelle de texte : le `TextScaler` legacy écrase l\'a11y', () {
      // `GptMarkdown(textScaler: TextScaler.linear(kIsWeb ? 1.15 : 1.1))`
      // (`:4243-4266`) IGNORE le réglage système de taille de texte. Le porter
      // aurait fait entrer un défaut d'accessibilité déguisé en « pixel près ».
      final String all = _referenceSource().join('\n');
      expect(all.contains('TextScaler'), isFalse,
          reason: '🔴 une échelle de texte figée est entrée dans la référence');
      expect(RegExp(r'textScale|bodyTextScale').hasMatch(all), isFalse);
    });

    test('la bulle de RÉPONSE n\'a pas de rayon inventé', () {
      // Le legacy ne pose `shape:` que sur la requête (`:3577-3579` vs
      // `:3586-3594`). Un rayon de réponse serait une valeur que personne n'a
      // mesurée.
      expect(ZChatNotebookReference.responseBubbleRadius, isNull);
      expect(ZChatNotebookReference.requestBubbleRadius,
          const Radius.circular(12));
    });

    test('aucun `TextStyle` complet — seulement des graisses et des corps', () {
      final String all = _referenceSource().join('\n');
      expect(all.contains('TextStyle('), isFalse,
          reason: '🔴 un style typographique complet fige la police et la '
              'couleur de l\'hôte (FR-26)');
      expect(ZChatNotebookReference.messageTitleWeight, FontWeight.w600);
    });
  });

  group('🔴 REF-G7 — HÔTE PASSIF : le skin est OPT-IN, aucune vue ne le monte',
      () {
    test('aucun fichier de `lib/` hors la référence et le skin ne les cite', () {
      // 🔴 C'est la garde d'additivité. Si un jour `ZChatConversationView` ou
      // `ZChatNotebookView` lisait la référence, tout hôte passif hériterait
      // du rendu IFFD sans l'avoir demandé — la définition même d'un défaut
      // qui bouge.
      // 🔴 ARBITRAGE CR-IFFD-84 (volet A, 2026-08-21) — le cardinal passe de
      // 2 à 4, délibérément. La CR établit que la référence et
      // `capabilityAccents` existaient SANS AUCUN consommateur (« offert, non
      // passé », vérifié par grep chez l'hôte comme ici) : le mécanisme
      // d'artefacts déclarés est leur premier lecteur, et il ne peut pas
      // l'être sans les citer.
      //
      // Ce que la garde protégeait — l'hôte PASSIF — reste protégé, mais par
      // deux mesures plus précises que ce grep :
      // 1. le rendu de référence n'est monté QUE si l'hôte déclare des
      //    artefacts (`artifacts.isEmpty ⇒ créneau inchangé`), mesuré en
      //    COMPTES ABSOLUS de widgets par le contre-témoin de
      //    `z_chat_cr84_artifacts_test.dart` ;
      // 2. la VUE relaie le skin, elle ne le construit ni ne le résout —
      //    asserté sur sa source par le test suivant.
      const Set<String> proprietaires = <String>{
        'view/z_chat_notebook_reference.dart',
        'view/z_chat_notebook_skin.dart',
        // Le consommateur du mécanisme d'artefacts : il RÉSOUT la chaîne
        // paramètre > jeton > référence, et lui seul.
        'view/z_chat_artifact_bar.dart',
        // La vue ne fait que TRANSPORTER le réglage jusqu'à la rangée.
        'view/z_chat_notebook_view.dart',
        // 🔴 ARBITRAGE CR-IFFD-84 (volet B, 2026-08-21) — le cardinal passe de
        // 4 à 5. La coquille de tuile a, comme la rangée d'artefacts, un
        // RÉSOLVEUR : `zChatTileShellStyleOf` arbitre paramètre > jeton >
        // référence pour le filet, la carte, la coiffe, l'horodatage et le
        // bouton de dépli. Il ne peut pas le faire sans citer la référence.
        //
        // Ce qui protège l'hôte passif ici n'est PAS ce grep, mais le fait
        // que le résolveur ne soit JAMAIS appelé sans déclaration :
        // 1. `ZChatMessageTile` ne l'invoque que si une coquille OU un sujet
        //    est déclaré — mesuré en COMPTES ABSOLUS de widgets par le
        //    contre-témoin de `z_chat_cr84_tile_shell_test.dart` ;
        // 2. ni la tuile ni la racine commune ne citent la référence — elles
        //    transportent un `ZChatTileShell?` nullable, asserté sur leur
        //    source par le test suivant.
        'view/z_chat_tile_shell.dart',
      };
      expect(proprietaires, hasLength(5),
          reason: '🔴 un fichier a été AJOUTÉ aux propriétaires du rendu de '
              'référence. Chaque entrée est un endroit de plus où un hôte '
              'passif peut se mettre à hériter du rendu IFFD : justifiez-la '
              'au point de déclaration et mettez ce compte à jour, '
              'délibérément.');
      final List<String> offenders = <String>[];
      for (final MapEntry<String, List<String>> e in strippedLib().entries) {
        final String p = e.key.replaceAll(r'\', '/');
        if (proprietaires.any(p.endsWith)) continue;
        for (int i = 0; i < e.value.length; i++) {
          if (RegExp(r'ZChatNotebook(Reference|Skin|Style|CapabilityStyle)')
              .hasMatch(e.value[i])) {
            offenders.add('${e.key}:${i + 1}: ${e.value[i].trim()}');
          }
        }
      }
      expect(offenders, isEmpty,
          reason: '🔴 le rendu de référence a été CÂBLÉ dans le socle : un '
              'hôte passif changerait d\'apparence sans réglage.\n'
              '${offenders.join('\n')}');
    });

    test('la TUILE et la RACINE COMMUNE ne CÂBLENT aucun rendu de référence',
        () {
      // 🔴 Ce sont les deux fichiers que TOUT hôte monte, notebook ou non.
      // Ils transportent la coquille (`ZChatTileShell?`, nullable) et rien
      // d'autre : ni référence lue, ni skin construit. Une valeur de
      // référence qui apparaîtrait ici serait héritée par un hôte qui n'a
      // rien déclaré — la définition exacte d'un défaut qui bouge.
      for (final String fichier in <String>[
        'view/z_chat_message_tile.dart',
        'view/z_chat_conversation_view.dart',
      ]) {
        final List<String> lignes = stripped(libFile(fichier));
        expect(
          lignes.any((String l) => l.contains('ZChatTileShell? shell')),
          isTrue,
          reason: '🔴 GARDE VACUELLE : `$fichier` ne transporte plus de '
              'coquille, la règle ne porte plus sur rien',
        );
        for (final RegExp interdit in <RegExp>[
          RegExp(r'ZChatNotebookReference\.'),
          RegExp(r'ZChatNotebookSkin'),
        ]) {
          expect(
            lignes.where(interdit.hasMatch),
            isEmpty,
            reason: '🔴 `${interdit.pattern}` dans `$fichier` : le rendu de '
                'référence y serait câblé, donc hérité par tout hôte — y '
                'compris celui qui ne déclare AUCUNE coquille.',
          );
        }
      }
      // 🔬 contre-preuve : les motifs SAVENT rougir sur leur témoin.
      expect(
        RegExp(r'ZChatNotebookReference\.')
            .hasMatch('  final r = ZChatNotebookReference.tileRadius;'),
        isTrue,
      );
      expect(
        RegExp(r'ZChatNotebookSkin')
            .hasMatch('  final ZChatNotebookSkin? skin;'),
        isTrue,
      );
    });

    test('la VUE RELAIE le skin — elle ne le CONSTRUIT ni ne le RÉSOUT', () {
      // 🔴 C'est ce qui remplace, pour ce fichier, le grep que l'arbitrage
      // ci-dessus a dû élargir. Porter un paramètre nullable est inoffensif ;
      // construire un skin par défaut, ou le résoudre, câblerait la référence
      // dans une vue que tout hôte monte.
      final List<String> lignes = stripped(
        libFile('view/z_chat_notebook_view.dart'),
      );
      expect(
        lignes.any((String l) => l.contains('ZChatNotebookSkin? skin')),
        isTrue,
        reason: '🔴 GARDE VACUELLE : le paramètre relayé a disparu, la règle '
            'ne porte plus sur rien',
      );
      for (final RegExp interdit in <RegExp>[
        RegExp(r'ZChatNotebookSkin\s*\('),
        RegExp(r'\.resolve\s*\('),
        RegExp(r'ZChatNotebookReference\.'),
      ]) {
        expect(
          lignes.where(interdit.hasMatch),
          isEmpty,
          reason: '🔴 `${interdit.pattern}` dans la VUE notebook : le rendu de '
              'référence y serait câblé, donc hérité par tout hôte — y '
              'compris celui qui ne déclare AUCUN artefact.',
        );
      }
      // 🔬 contre-preuve : les motifs SAVENT rougir sur leur témoin.
      expect(
        RegExp(r'ZChatNotebookSkin\s*\(')
            .hasMatch('  final s = const ZChatNotebookSkin();'),
        isTrue,
      );
      expect(
        RegExp(r'\.resolve\s*\(').hasMatch('  final st = skin.resolve(c);'),
        isTrue,
      );
    });

    testWidgets('le composer garde le défaut du THÈME, jamais la marge de '
        'référence', (WidgetTester tester) async {
      // Mesure sur l'arbre monté, pas sur la source : les deux valeurs
      // DIFFÈRENT (`formPadding` = all(12), référence = symmetric(h: 8)), donc
      // un câblage silencieux se verrait.
      expect(ZChatNotebookReference.composerPadding,
          isNot(const ZcrudTheme().formPadding));
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(
            data: const MediaQueryData(),
            child: ZChatComposer(
              controller: _inertController(),
              cursorColor: const Color(0xFF123456),
            ),
          ),
        ),
      );
      final Padding pad = tester.widget<Padding>(
        find.descendant(
          of: find.byType(ZChatComposer),
          matching: find.byType(Padding),
        ).first,
      );
      expect(pad.padding, const ZcrudTheme().formPadding);
      expect(pad.padding, isNot(ZChatNotebookReference.composerPadding));
    });
  });
}

/// Contrôleur inerte, juste assez pour monter le composer.
ZChatController _inertController() => ZChatController(
  streamPort: _InertPort(),
  actionExecutor: _InertExecutor(),
  confirm: (ZChatActionPlan _) async => true,
  newRequestId: () => 'r0',
  buildRequest: (ZChatDraft d) => ZChatGenerationRequest(
    style: ZChatGenerationStyle.converse,
    subject: d.text,
  ),
  conversationId: 'c1',
);

class _InertPort implements ZChatStreamPort {
  @override
  Stream<ZResult<ZChatStreamEvent>> stream(
    ZChatGenerationRequest request, {
    required ZChatRequestToken token,
  }) => const Stream<ZResult<ZChatStreamEvent>>.empty();
}

class _InertExecutor implements ZChatActionExecutor {
  static ZResult<T> _no<T>() =>
      Left<ZFailure, T>(const ZDomainFailure('inerte'));

  @override
  Future<ZResult<ZChatActionImpact>> estimateImpact(ZChatAction action) async =>
      _no<ZChatActionImpact>();

  @override
  Future<ZResult<List<String>>> editAndResend({
    required String messageId,
    required String newText,
  }) async => _no<List<String>>();

  @override
  Future<ZResult<List<String>>> regenerate({required String messageId}) async =>
      _no<List<String>>();

  @override
  Future<ZResult<List<String>>> softDeleteMessages({
    required String messageId,
    required bool cascadeToPair,
  }) async => _no<List<String>>();

  @override
  Future<ZResult<Unit>> cancelRequest(String requestId) async => _no<Unit>();

  @override
  Future<ZResult<String>> renderForCopy({
    required String messageId,
    required ZChatCopyFormat format,
  }) async => _no<String>();

  @override
  Future<ZResult<List<String>>> executeCustom(ZChatCustomAction action) async =>
      _no<List<String>>();
}
