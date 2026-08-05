/// **CR-IFFD-65** — le hub d'ajout de contenu au RENDU DE RÉFÉRENCE.
///
/// Les quatre griefs MESURÉS de la CR (groupement, identité par entrée, mise en
/// avant, forme réglable), plus les quatre points qu'elle déclarait « non
/// mesurés » et que ce lot MESURE : disposition multi-colonnes, facteur
/// d'échelle de texte, thème sombre, ordre des entrées à l'insertion.
///
/// 🔴 **Décision du propriétaire du socle (2026-08-05)** : le rendu legacy
/// devient le DÉFAUT — hauteur d'item de référence assumée, défilement attendu.
/// La densité d'AVANT reste atteignable par paramètre ET par jeton, et c'est
/// gardé ici (sans quoi la décision serait une perte sèche).
library;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_study/zcrud_study.dart';

const IconData kIconA = Icons.auto_awesome;
const IconData kIconB = Icons.add;
const IconData kIconC = Icons.upload_outlined;
const IconData kIconD = Icons.note_add_outlined;

const String kLabelA = 'ENTREE-A-XYZ';
const String kLabelB = 'ENTREE-B-XYZ';
const String kLabelC = 'ENTREE-C-XYZ';
const String kLabelD = 'ENTREE-D-XYZ';
const String kSectionA = 'SECTION-UNE-XYZ';
const String kSectionB = 'SECTION-DEUX-XYZ';
const String kBadge = 'MIS-EN-AVANT-XYZ';

ZContentHubEntry _entry(
  IconData icon,
  String label, {
  String? colorKey,
  String? badgeLabel,
  Color? tint,
}) => ZContentHubEntry(
  icon: icon,
  label: label,
  colorKey: colorKey,
  badgeLabel: badgeLabel,
  tint: tint,
  onTap: () {},
);

/// ⚠️ Le `MediaQuery` est posé **DANS** l'application : `MaterialApp` en
/// installe un depuis la vue, et un `MediaQuery` externe serait écrasé — la
/// garde d'échelle de texte serait alors VACANTE (elle mesurerait ×1 en croyant
/// mesurer ×3).
///
/// La largeur est imposée par un `SizedBox` (le `LayoutBuilder` du hub lit les
/// contraintes reçues, pas la taille de l'écran) ; la hauteur reste celle du
/// `Scaffold`, sans quoi le corps déborderait.
Widget _wrap(
  Widget child, {
  TextDirection dir = TextDirection.ltr,
  ThemeData? theme,
  Size size = const Size(400, 800),
  TextScaler scaler = TextScaler.noScaling,
  ZcrudTheme? tokens,
}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: theme,
  home: Builder(
    builder: (BuildContext context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: scaler),
      child: Directionality(
        textDirection: dir,
        child: ZcrudScope(
          theme: tokens,
          child: Scaffold(
            body: SizedBox(width: size.width, child: child),
          ),
        ),
      ),
    ),
  ),
);

/// Couleur RÉELLEMENT peinte du glyphe d'une entrée (repérée par son glyphe).
Color _glyphColor(WidgetTester tester, IconData icon) =>
    tester.widget<Icon>(find.byIcon(icon)).color!;

/// Fond RÉELLEMENT peint de la pastille d'une entrée.
Color _avatarSurface(WidgetTester tester, IconData icon) {
  final DecoratedBox box = tester.widget<DecoratedBox>(
    find
        .ancestor(of: find.byIcon(icon), matching: find.byType(DecoratedBox))
        .first,
  );
  return (box.decoration as BoxDecoration).color!;
}

void main() {
  group('🔴 CR-IFFD-65 ① — GROUPEMENT sous intitulés INJECTÉS', () {
    testWidgets('les intitulés de section sont rendus, en en-tête a11y', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          ZContentHubSheet(
            sections: <ZContentHubSection>[
              ZContentHubSection(
                title: kSectionA,
                entries: <ZContentHubEntry>[_entry(kIconA, kLabelA)],
              ),
              ZContentHubSection(
                title: kSectionB,
                entries: <ZContentHubEntry>[_entry(kIconB, kLabelB)],
              ),
            ],
          ),
        ),
      );

      expect(find.text(kSectionA), findsOneWidget);
      expect(find.text(kSectionB), findsOneWidget);
      // L'intitulé est un EN-TÊTE, pas un texte décoratif.
      final Semantics header = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .firstWhere((s) => s.properties.label == kSectionA);
      expect(header.properties.header, isTrue);
    });

    testWidgets('AD-4 — `title: null` ⇒ AUCUN en-tête dans l\'arbre', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          ZContentHubSheet(
            sections: <ZContentHubSection>[
              ZContentHubSection(
                entries: <ZContentHubEntry>[_entry(kIconA, kLabelA)],
              ),
            ],
          ),
        ),
      );

      expect(
        find.byKey(ZContentHubSheet.sectionTitleKey),
        findsNothing,
        reason:
            '🔴 AD-4 : un intitulé absent est ABSENT DE L\'ARBRE — jamais un '
            'texte vide qui réserve de la place.',
      );
      expect(find.text(kLabelA), findsOneWidget);
    });

    testWidgets('AD-10 — `entries` ET `sections` coexistent, rien n\'est perdu', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          ZContentHubSheet(
            entries: <ZContentHubEntry>[_entry(kIconA, kLabelA)],
            sections: <ZContentHubSection>[
              ZContentHubSection(
                title: kSectionB,
                entries: <ZContentHubEntry>[_entry(kIconB, kLabelB)],
              ),
              // Section VIDE : elle ne laisserait qu'un intitulé orphelin.
              const ZContentHubSection(
                title: kSectionA,
                entries: <ZContentHubEntry>[],
              ),
            ],
          ),
        ),
      );

      expect(find.text(kLabelA), findsOneWidget);
      expect(find.text(kLabelB), findsOneWidget);
      expect(find.text(kSectionB), findsOneWidget);
      expect(
        find.text(kSectionA),
        findsNothing,
        reason: '🔴 une section VIDE ne doit pas laisser un intitulé orphelin.',
      );
    });
  });

  group('🔴 CR-IFFD-65 ② — IDENTITÉ VISUELLE par entrée', () {
    testWidgets('une pastille teintée est rendue, et la teinte INJECTÉE prime', (
      tester,
    ) async {
      const Color injected = Color(0xFF123456);
      await tester.pumpWidget(
        _wrap(
          ZContentHubSheet(
            entries: <ZContentHubEntry>[
              _entry(kIconA, kLabelA, tint: injected),
              _entry(kIconB, kLabelB),
            ],
          ),
        ),
      );

      expect(find.byKey(ZContentHubSheet.avatarKey), findsNWidgets(2));
      // La teinte injectée gouverne le fond de la pastille (composée à 10 %).
      final Color surfaceA = _avatarSurface(tester, kIconA);
      final Color surfaceB = _avatarSurface(tester, kIconB);
      expect(
        surfaceA,
        isNot(surfaceB),
        reason: '🔴 deux entrées d\'identités distinctes se ressemblent — '
            'c\'est exactement le grief ② de la CR.',
      );
    });

    testWidgets(
      '🔴 AD-13 — la couleur n\'est JAMAIS le seul canal : le libellé porte',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            ZContentHubSheet(
              // Palette VIDE : aucune identité chromatique du tout.
              accents: const <Color>[],
              entries: <ZContentHubEntry>[
                _entry(kIconA, kLabelA),
                _entry(kIconB, kLabelB),
              ],
            ),
          ),
        );

        // AD-10 — chaîne TOTALE : une palette vide ne fait PAS échouer le rendu.
        expect(tester.takeException(), isNull);
        // …et l'information reste intégralement lisible EN TEXTE.
        expect(find.text(kLabelA), findsOneWidget);
        expect(find.text(kLabelB), findsOneWidget);
        expect(find.byIcon(kIconA), findsOneWidget);
      },
    );

    testWidgets(
      '🔴 « non mesuré » n°4 — insérer un type AU MILIEU ne déplace AUCUNE '
      'teinte',
      (tester) async {
        Widget sheet(List<ZContentHubEntry> entries) =>
            _wrap(ZContentHubSheet(entries: entries));

        await tester.pumpWidget(
          sheet(<ZContentHubEntry>[
            _entry(kIconA, kLabelA, colorKey: 'a'),
            _entry(kIconB, kLabelB, colorKey: 'b'),
            _entry(kIconC, kLabelC, colorKey: 'c'),
          ]),
        );
        final Color before = _glyphColor(tester, kIconC);
        final Color beforeB = _glyphColor(tester, kIconB);

        // Une application insère un type AU MILIEU (l'horizon décrit par le
        // propriétaire d'IFFD : vidéo, audio, diagrammes…).
        await tester.pumpWidget(
          sheet(<ZContentHubEntry>[
            _entry(kIconA, kLabelA, colorKey: 'a'),
            _entry(kIconD, kLabelD, colorKey: 'd'),
            _entry(kIconB, kLabelB, colorKey: 'b'),
            _entry(kIconC, kLabelC, colorKey: 'c'),
          ]),
        );

        expect(
          _glyphColor(tester, kIconC),
          before,
          reason:
              '🔴 la teinte suivrait la POSITION : toutes les identités '
              'basculeraient quand une application ajoute un type. Elle doit '
              'suivre l\'IDENTITÉ (`colorKey`).',
        );
        expect(_glyphColor(tester, kIconB), beforeB);
      },
    );

    test('le créneau de teinte est DÉTERMINISTE et borné à la palette', () {
      for (final String seed in <String>['a', 'flashcards.ai', '', 'ZZZ-42']) {
        final int slot = zAccentSlot(seed, 6);
        expect(slot, inInclusiveRange(0, 5));
        expect(zAccentSlot(seed, 6), slot, reason: 'non déterministe');
      }
      // AD-10 — une palette vide ne fait jamais lever ni sortir des bornes.
      expect(zAccentSlot('x', 0), 0);
    });
  });

  group('🔴 CR-IFFD-65 ③ — MISE EN AVANT par un canal TEXTUEL', () {
    testWidgets('le badge est rendu EN TEXTE et annoncé avec le bouton', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          ZContentHubSheet(
            entries: <ZContentHubEntry>[
              _entry(kIconA, kLabelA, badgeLabel: kBadge),
              _entry(kIconB, kLabelB),
            ],
          ),
        ),
      );

      expect(find.text(kBadge), findsOneWidget);
      expect(find.byKey(ZContentHubSheet.badgeKey), findsOneWidget);

      // 🔴 Le canal est ACCESSIBLE : le libellé de mise en avant est fusionné
      // dans le nœud du bouton — c'est ce qui rend inutile le détournement de
      // `hint` que la CR déclarait avoir fait à contrecœur.
      final SemanticsHandle handle = tester.ensureSemantics();
      final SemanticsNode node = tester.getSemantics(
        find.byType(InkWell).first,
      );
      expect(node.label, contains(kLabelA));
      expect(
        node.label,
        contains(kBadge),
        reason:
            '🔴 un badge purement coloré ne serait pas lu ; la CR exige un '
            'canal TEXTUEL donc accessible.',
      );
      expect(node.flagsCollection.isButton, isTrue);
      // 🔴 …et l'entrée reste UN SEUL nœud : un badge en nœud FRÈRE serait
      // annoncé séparément du bouton, hors de son contexte.
      expect(
        node.childrenCount,
        0,
        reason:
            '🔴 le badge doit être FUSIONNÉ dans le nœud du bouton — un badge '
            'en nœud FRÈRE (`Semantics(container: true)`) serait annoncé '
            'séparément, hors du contexte de l\'action.',
      );
      handle.dispose();
    });

    testWidgets('AD-4 — `badgeLabel: null` ⇒ badge ABSENT de l\'arbre', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          ZContentHubSheet(
            entries: <ZContentHubEntry>[_entry(kIconA, kLabelA)],
          ),
        ),
      );
      expect(
        find.byKey(ZContentHubSheet.badgeKey),
        findsNothing,
        reason:
            '🔴 le legacy pose un `SizedBox.shrink()` inerte à la place — '
            'AD-4 interdit de le reproduire.',
      );
    });

    test('🔴 aucun défaut de constructeur LITTÉRAL pour un libellé', () {
      // Une entrée nue ne fabrique AUCUN texte : le socle ne connaît ni
      // « Recommandé » ni « Flashcards » (FR-26/NFR-S7).
      const ZContentHubEntry entry = ZContentHubEntry(
        icon: kIconA,
        label: kLabelA,
      );
      expect(entry.badgeLabel, isNull);
      expect(entry.hint, isNull);
      expect(const ZContentHubSection(entries: <ZContentHubEntry>[]).title,
          isNull);
    });
  });

  group('🔴 CR-IFFD-65 ④ — FORME réglable : paramètre > jeton > référence', () {
    testWidgets('le JETON déplace le rendu sans écraser le sous-arbre', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          ZContentHubSheet(
            entries: <ZContentHubEntry>[_entry(kIconA, kLabelA)],
          ),
          tokens: const ZcrudTheme(contentHubAvatarSize: 64),
        ),
      );
      expect(
        tester.getSize(find.byKey(ZContentHubSheet.avatarKey)).width,
        64,
        reason: '🔴 le jeton `contentHubAvatarSize` n\'atteint pas le rendu.',
      );
    });

    testWidgets('le PARAMÈTRE gagne sur le jeton', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ZContentHubSheet(
            avatarSize: 52,
            entries: <ZContentHubEntry>[_entry(kIconA, kLabelA)],
          ),
          tokens: const ZcrudTheme(contentHubAvatarSize: 64),
        ),
      );
      expect(
        tester.getSize(find.byKey(ZContentHubSheet.avatarKey)).width,
        52,
        reason: '🔴 priorité paramètre > jeton > référence.',
      );
    });

    testWidgets('sans réglage, la RÉFÉRENCE gouverne (40 dp)', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ZContentHubSheet(
            entries: <ZContentHubEntry>[_entry(kIconA, kLabelA)],
          ),
        ),
      );
      expect(
        tester.getSize(find.byKey(ZContentHubSheet.avatarKey)).width,
        ZContentHubReference.avatarSize,
      );
    });
  });

  group('🔴 Décision owner — la densité d\'AVANT reste ATTEIGNABLE', () {
    testWidgets(
      'défaut = rendu de RÉFÉRENCE (hauteur d\'item 112, chevron, pastille)',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            ZContentHubSheet(
              entries: <ZContentHubEntry>[_entry(kIconA, kLabelA)],
            ),
          ),
        );
        expect(find.byKey(ZContentHubSheet.chevronKey), findsOneWidget);
        expect(find.byKey(ZContentHubSheet.avatarKey), findsOneWidget);
        expect(
          tester.getSize(find.byType(InkWell)).height,
          greaterThanOrEqualTo(ZContentHubReference.itemExtent),
          reason:
              '🔴 la hauteur d\'item de RÉFÉRENCE est ASSUMÉE (décision du '
              'propriétaire, 2026-08-05) — le défilement est le comportement '
              'attendu.',
        );
      },
    );

    testWidgets('PARAMÈTRE `density: compact` ⇒ densité d\'avant restituée', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          ZContentHubSheet(
            density: ZContentHubDensity.compact,
            entries: <ZContentHubEntry>[_entry(kIconA, kLabelA)],
          ),
        ),
      );
      expect(find.byKey(ZContentHubSheet.chevronKey), findsNothing);
      expect(find.byKey(ZContentHubSheet.avatarKey), findsNothing);
      final double h = tester.getSize(find.byType(InkWell)).height;
      expect(h, greaterThanOrEqualTo(ZContentHubReference.minTapTarget));
      expect(
        h,
        lessThan(ZContentHubReference.itemExtent),
        reason:
            '🔴 l\'argument d\'ÉCHELLE de la CR (douze types ⇒ trois ou quatre '
            'écrans) reste vrai : la densité d\'avant DOIT rester atteignable.',
      );
      // …et l'information n'est pas perdue au passage.
      expect(find.text(kLabelA), findsOneWidget);
    });

    testWidgets('JETON `contentHubDensity: compact` ⇒ même restitution', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          ZContentHubSheet(
            entries: <ZContentHubEntry>[_entry(kIconA, kLabelA)],
          ),
          tokens: const ZcrudTheme(
            contentHubDensity: ZContentHubDensity.compact,
          ),
        ),
      );
      expect(find.byKey(ZContentHubSheet.chevronKey), findsNothing);
      expect(
        tester.getSize(find.byType(InkWell)).height,
        lessThan(ZContentHubReference.itemExtent),
        reason: '🔴 la densité doit être atteignable PAR JETON aussi, sans '
            'toucher au code de l\'hôte.',
      );
    });

    testWidgets('le PARAMÈTRE gagne sur le jeton pour la densité', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          ZContentHubSheet(
            density: ZContentHubDensity.comfortable,
            entries: <ZContentHubEntry>[_entry(kIconA, kLabelA)],
          ),
          tokens: const ZcrudTheme(
            contentHubDensity: ZContentHubDensity.compact,
          ),
        ),
      );
      expect(find.byKey(ZContentHubSheet.chevronKey), findsOneWidget);
    });
  });

  group('🔴 « non mesuré » n°1 — la GRILLE, mesurée dans les DEUX régimes', () {
    testWidgets('ÉTROIT (< 600) ⇒ UNE colonne', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ZContentHubSheet(
            entries: <ZContentHubEntry>[
              _entry(kIconA, kLabelA),
              _entry(kIconB, kLabelB),
            ],
          ),
          size: const Size(400, 800),
        ),
      );
      final Offset a = tester.getTopLeft(find.byIcon(kIconA));
      final Offset b = tester.getTopLeft(find.byIcon(kIconB));
      expect(a.dx, b.dx, reason: 'une colonne ⇒ même abscisse');
      expect(b.dy, greaterThan(a.dy));
    });

    testWidgets(
      '🔴 LARGE (≥ 600) ⇒ DEUX colonnes — mesuré dans le legacy, que la CR '
      'déclarait « non mesuré »',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            ZContentHubSheet(
              entries: <ZContentHubEntry>[
                _entry(kIconA, kLabelA),
                _entry(kIconB, kLabelB),
              ],
            ),
            size: const Size(800, 800),
          ),
        );
        final Offset a = tester.getTopLeft(find.byIcon(kIconA));
        final Offset b = tester.getTopLeft(find.byIcon(kIconB));
        expect(
          b.dx,
          greaterThan(a.dx),
          reason:
              '🔴 `_buildContentGrid` du legacy impose `crossAxisCount = 2` '
              'au-delà de 600 lp (l.376-377) — jamais une colonne unique.',
        );
        expect(a.dy, b.dy, reason: 'même rangée');
      },
    );

    testWidgets('la grille est RÉGLABLE (1 colonne imposée en large)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          ZContentHubSheet(
            gridCrossAxisCount: 1,
            entries: <ZContentHubEntry>[
              _entry(kIconA, kLabelA),
              _entry(kIconB, kLabelB),
            ],
          ),
          size: const Size(800, 800),
        ),
      );
      expect(
        tester.getTopLeft(find.byIcon(kIconA)).dx,
        tester.getTopLeft(find.byIcon(kIconB)).dx,
      );
    });

    testWidgets('la densité COMPACTE reste en une colonne, même en large', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          ZContentHubSheet(
            density: ZContentHubDensity.compact,
            entries: <ZContentHubEntry>[
              _entry(kIconA, kLabelA),
              _entry(kIconB, kLabelB),
            ],
          ),
          size: const Size(800, 800),
        ),
      );
      expect(
        tester.getTopLeft(find.byIcon(kIconA)).dx,
        tester.getTopLeft(find.byIcon(kIconB)).dx,
      );
    });
  });

  group('🔴 « non mesuré » n°2 — FACTEUR D\'ÉCHELLE DE TEXTE élevé', () {
    for (final double factor in <double>[1.0, 2.0, 3.0]) {
      testWidgets('×$factor — aucun débordement, en étroit comme en large', (
        tester,
      ) async {
        for (final Size size in <Size>[Size(400, 800), Size(800, 800)]) {
          await tester.pumpWidget(
            _wrap(
              ZContentHubSheet(
                sections: <ZContentHubSection>[
                  ZContentHubSection(
                    title: kSectionA,
                    entries: <ZContentHubEntry>[
                      _entry(kIconA, kLabelA, badgeLabel: kBadge),
                      _entry(kIconB, kLabelB),
                    ],
                  ),
                ],
              ),
              size: size,
              scaler: TextScaler.linear(factor),
            ),
          );
          expect(
            tester.takeException(),
            isNull,
            reason:
                '🔴 une cellule de grille a une hauteur IMPOSÉE : figée à 112, '
                'elle déborde dès que l\'utilisateur agrandit le texte '
                '(${size.width} lp × $factor).',
          );
        }
      });
    }
  });

  group('🔴 « non mesuré » n°2bis — la CELLULE suit le facteur d\'échelle', () {
    testWidgets(
      'en GRILLE, la hauteur de cellule croît avec le `TextScaler`',
      (tester) async {
        Future<double> hauteur(double factor) async {
          await tester.pumpWidget(
            _wrap(
              ZContentHubSheet(
                entries: <ZContentHubEntry>[_entry(kIconA, kLabelA)],
              ),
              size: const Size(800, 800),
              scaler: TextScaler.linear(factor),
            ),
          );
          return tester.getSize(find.byType(InkWell).first).height;
        }

        final double x1 = await hauteur(1);
        final double x2 = await hauteur(2);
        expect(x1, ZContentHubReference.itemExtent);
        expect(
          x2,
          greaterThan(x1),
          reason:
              '🔴 une cellule de grille a une hauteur IMPOSÉE : figée à 112, '
              'le contenu agrandi n\'a plus de place et se fait tronquer — '
              'l\'extent doit suivre le `TextScaler` ambiant.',
        );
      },
    );
  });

  group('🔴 « non mesuré » n°3 — THÈME SOMBRE (le legacy n\'adapte RIEN)', () {
    // 🔴 L'extrême est CHOISI par mode : une même couleur ne peut pas échouer
    // dans les deux luminosités (le jaune est illisible sur clair et très
    // lisible sur sombre). Une contre-preuve à couleur unique serait donc
    // verte pour rien dans l'un des deux modes.
    for (final ({String nom, ThemeData data, Color extreme}) mode in <({
      String nom,
      ThemeData data,
      Color extreme
    })>[
      (
        nom: 'clair',
        data: ThemeData.light(useMaterial3: true),
        extreme: Color(0xFFFFFF00),
      ),
      (
        nom: 'sombre',
        data: ThemeData.dark(useMaterial3: true),
        extreme: Color(0xFF0D0D0D),
      ),
    ]) {
      testWidgets(
        '${mode.nom} — le glyphe atteint le plancher 3.0:1 sur la pastille '
        'RÉELLEMENT peinte',
        (tester) async {
          // Une teinte EXTRÊME, que le legacy peindrait telle quelle.
          final Color extreme = mode.extreme;
          await tester.pumpWidget(
            _wrap(
              ZContentHubSheet(
                entries: <ZContentHubEntry>[
                  _entry(kIconA, kLabelA, tint: extreme),
                ],
              ),
              theme: mode.data,
            ),
          );

          final Color surface = _avatarSurface(tester, kIconA);
          final Color glyph = _glyphColor(tester, kIconA);
          expect(
            zContrastRatio(glyph, surface),
            greaterThanOrEqualTo(ZContentHubReference.minContrast),
            reason: '🔴 plancher WCAG 2.2 §1.4.11 non tenu en ${mode.nom}.',
          );
          // 🔴 CONTRE-PREUVE : la garde n'est PAS vacante — la teinte BRUTE
          // (ce que peint le legacy, sans branche de luminosité) échoue.
          expect(
            zContrastRatio(extreme, surface),
            lessThan(ZContentHubReference.minContrast),
            reason:
                '🔴 sonde cassée : si la teinte brute passait déjà, cette '
                'garde ne mesurerait rien.',
          );
        },
      );
    }

    testWidgets(
      'les SIX teintes de référence tiennent le plancher dans les deux '
      'luminosités',
      (tester) async {
        for (final ThemeData data in <ThemeData>[
          ThemeData.light(useMaterial3: true),
          ThemeData.dark(useMaterial3: true),
        ]) {
          for (final Color accent in ZContentHubReference.accents) {
            await tester.pumpWidget(
              _wrap(
                ZContentHubSheet(
                  entries: <ZContentHubEntry>[
                    _entry(kIconA, kLabelA, tint: accent),
                  ],
                ),
                theme: data,
              ),
            );
            expect(
              zContrastRatio(
                _glyphColor(tester, kIconA),
                _avatarSurface(tester, kIconA),
              ),
              greaterThanOrEqualTo(ZContentHubReference.minContrast),
              reason:
                  '🔴 teinte de référence illisible en '
                  '${data.brightness.name} : $accent',
            );
          }
        }
      },
    );

    testWidgets('le libellé de badge tient le plancher TEXTE (4.5:1)', (
      tester,
    ) async {
      for (final ThemeData data in <ThemeData>[
        ThemeData.light(useMaterial3: true),
        ThemeData.dark(useMaterial3: true),
      ]) {
        await tester.pumpWidget(
          _wrap(
            ZContentHubSheet(
              entries: <ZContentHubEntry>[
                _entry(kIconA, kLabelA, badgeLabel: kBadge),
              ],
            ),
            theme: data,
          ),
        );
        final BoxDecoration deco =
            tester
                    .widget<Container>(find.byKey(ZContentHubSheet.badgeKey))
                    .decoration!
                as BoxDecoration;
        final TextStyle style = tester.widget<Text>(find.text(kBadge)).style!;
        expect(
          zContrastRatio(style.color!, deco.color!),
          greaterThanOrEqualTo(ZContentHubReference.textMinContrast),
          reason:
              '🔴 le legacy peint `Colors.green.shade700` sur un vert à 10 % '
              'sans jamais mesurer, et n\'a AUCUNE branche de luminosité.',
        );
      }
    });
  });

  group('🔴 AD-13 — RTL, cibles tactiles, chevron', () {
    testWidgets(
      'le chevron de RÉFÉRENCE porte DÉJÀ `matchTextDirection` (mesuré dans '
      'le SDK) — le grief RTL contre le legacy est INFIRMÉ',
      (tester) async {
        expect(
          ZContentHubReference.chevronGlyph.matchTextDirection,
          isTrue,
          reason:
              '🔴 le widget `Icon` n\'a AUCUNE propriété '
              '`matchTextDirection` : elle vit sur `IconData`, et '
              '`Icons.arrow_forward_ios` la porte à `true`.',
        );
      },
    );

    testWidgets(
      'un chevron INJECTÉ sans `matchTextDirection` est retourné en RTL par '
      'le socle',
      (tester) async {
        // `Icons.star` ne porte PAS `matchTextDirection`.
        const IconData plat = Icons.star;
        expect(plat.matchTextDirection, isFalse, reason: 'sonde cassée');

        await tester.pumpWidget(
          _wrap(
            ZContentHubSheet(
              chevronGlyph: plat,
              entries: <ZContentHubEntry>[_entry(kIconA, kLabelA)],
            ),
            dir: TextDirection.rtl,
          ),
        );
        // 🔴 Clé DÉDIÉE, jamais `find.byType(Transform)` : la transition de
        // page de `MaterialApp` en pose un elle aussi — une garde qui le
        // compterait serait VERTE dans les deux directions, donc vacante.
        expect(
          find.byKey(ZContentHubSheet.chevronMirrorKey),
          findsOneWidget,
          reason:
              '🔴 l\'affordance pointerait à l\'envers en arabe — un défaut '
              'que la garde de SOURCE ne voit pas (elle ne scanne pas les '
              'propriétés d\'`Icon`).',
        );

        // …et en LTR, aucune transformation n'est posée.
        await tester.pumpWidget(
          _wrap(
            ZContentHubSheet(
              chevronGlyph: plat,
              entries: <ZContentHubEntry>[_entry(kIconA, kLabelA)],
            ),
          ),
        );
        expect(find.byKey(ZContentHubSheet.chevronMirrorKey), findsNothing);

        // …et le glyphe de RÉFÉRENCE n'a JAMAIS besoin du repli, même en RTL :
        // il porte déjà `matchTextDirection`, et c'est `Icon` qui le retourne.
        await tester.pumpWidget(
          _wrap(
            ZContentHubSheet(
              entries: <ZContentHubEntry>[_entry(kIconA, kLabelA)],
            ),
            dir: TextDirection.rtl,
          ),
        );
        expect(find.byKey(ZContentHubSheet.chevronMirrorKey), findsNothing);
        expect(find.byKey(ZContentHubSheet.chevronKey), findsOneWidget);
      },
    );

    testWidgets(
      '🔴 la pastille (40 dp) n\'est PAS une cible tactile indépendante',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            ZContentHubSheet(
              entries: <ZContentHubEntry>[_entry(kIconA, kLabelA)],
            ),
          ),
        );
        expect(
          find.byType(InkWell),
          findsOneWidget,
          reason:
              '🔴 toute la carte est UN SEUL `InkWell` (patron legacy) : une '
              'pastille actionnable isolément passerait sous les 48 dp '
              '(AD-13/NFR-S6).',
        );
        expect(
          tester.getSize(find.byType(InkWell)).height,
          greaterThanOrEqualTo(ZContentHubReference.minTapTarget),
        );
      },
    );

    testWidgets('en RTL le libellé reste ancré au bord de DÉBUT', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          ZContentHubSheet(
            entries: <ZContentHubEntry>[_entry(kIconA, kLabelA)],
          ),
          dir: TextDirection.rtl,
        ),
      );
      // La pastille est en fin d'axe visuel (droite) en RTL.
      expect(
        tester.getCenter(find.byKey(ZContentHubSheet.avatarKey)).dx,
        greaterThan(200),
        reason: '🔴 un inset non directionnel casserait l\'UI en arabe.',
      );
    });
  });

  group('🔴 AD-2/SM-1 — virtualisation, aucun état', () {
    testWidgets('200 entrées ⇒ toutes ne sont PAS construites', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ZContentHubSheet(
            entries: <ZContentHubEntry>[
              for (int i = 0; i < 200; i++)
                ZContentHubEntry(
                  icon: kIconA,
                  label: 'E-$i',
                  colorKey: 'k$i',
                  onTap: () {},
                ),
            ],
          ),
          size: const Size(400, 600),
        ),
      );
      final int monte = tester
          .widgetList(find.byKey(ZContentHubSheet.avatarKey))
          .length;
      expect(
        monte,
        lessThan(200),
        reason:
            '🔴 une liste matérialisée construit les 200 — `SliverList.builder` '
            'n\'en construit que le voisinage visible (AD-2/SM-1).',
      );
      expect(monte, greaterThan(0), reason: 'sonde cassée : rien n\'est monté');
    });
  });
}
