/// AC5 — zéro couleur/libellé en dur, ≥ 48 dp, `Semantics`, RTL (SU-2,
/// NFR-SU3/4/5 — AD-13).
///
/// ⚠️ **Leçon D7 du code-review de su-1** : une assertion de thème ne discrimine
/// que si les couleurs candidates sont **volontairement distinctes**. Un test qui
/// compare la couleur rendue à une valeur que **plusieurs** branches produisent
/// passe **quelle que soit** la branche empruntée — il n'atteste rien. Les
/// couleurs de ce fichier sont donc choisies pour être mutuellement
/// distinguables, et la branche de repli est **réellement** empruntée
/// (`ZcrudTheme()` laisse ses slots à `null`).
library;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';

/// Couleurs **mutuellement distinctes** — aucune ne peut être confondue avec une
/// autre branche de résolution (leçon D7).
const Color _kSurface = Color(0xFF102030);
const Color _kPrimary = Color(0xFF405060);
const Color _kOnSurface = Color(0xFF708090);
const Color _kThemedLabel = Color(0xFFA0B0C0);

/// `ColorScheme` de test dont chaque rôle est identifiable à l'œil nu.
final ColorScheme _scheme = const ColorScheme.light().copyWith(
  surface: _kSurface,
  primary: _kPrimary,
  onSurface: _kOnSurface,
);

const ZFlashcard _qcm = ZFlashcard(
  question: 'Q',
  type: ZFlashcardType.multipleChoice,
  choices: <ZChoice>[
    ZChoice(content: 'Bon', isCorrect: true),
    ZChoice(content: 'Mauvais'),
  ],
);

/// QCM dont le bon choix est en **position 2** — jamais en tête.
///
/// ⚠️ Discriminant du finding D2 : avec le correct en position 1, un marqueur
/// sémantique **détaché** se lit malgré tout juste avant le bon choix — le
/// défaut resterait invisible. Le bon choix doit être ailleurs qu'en tête pour
/// que l'ASSOCIATION soit distinguable de la simple PRÉSENCE.
const ZFlashcard _qcmCorrectEnDeuxieme = ZFlashcard(
  question: 'Capitale du Togo ?',
  type: ZFlashcardType.multipleChoice,
  choices: <ZChoice>[
    ZChoice(content: 'Paris'),
    ZChoice(content: 'Lome', isCorrect: true),
    ZChoice(content: 'Accra'),
  ],
);

Future<void> _pump(
  WidgetTester tester, {
  ZFlashcard card = _qcm,
  ZcrudTheme? zTheme,
  TextDirection direction = TextDirection.ltr,
  VoidCallback? onEdit,
}) =>
    tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(colorScheme: _scheme),
        home: Directionality(
          textDirection: direction,
          child: ZcrudScope(
            theme: zTheme,
            child: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 400,
                  child: ZFlashcardReviewCard(card: card, onEdit: onEdit),
                ),
              ),
            ),
          ),
        ),
      ),
    );

Future<void> _reveal(WidgetTester tester) async {
  await tester.tap(find.byType(ZFlashcardReviewCard));
  await tester.pumpAndSettle();
}

/// Tous les nœuds sémantiques de [root], lui compris (parcours en profondeur).
List<SemanticsNode> _sousArbre(SemanticsNode root) {
  final nodes = <SemanticsNode>[root];
  root.visitChildren((SemanticsNode child) {
    nodes.addAll(_sousArbre(child));
    return true;
  });
  return nodes;
}

/// Le `Material` de la carte (le premier sous l'arbre de la carte).
Material _cardMaterial(WidgetTester tester) => tester.widget<Material>(
      find
          .descendant(
            of: find.byType(ZFlashcardReviewCard),
            matching: find.byType(Material),
          )
          .first,
    );

void main() {
  group('AC5 — zéro couleur en dur : le thème est RÉELLEMENT consulté', () {
    testWidgets(
      'repli EMPRUNTÉ : ZcrudTheme() sans surfaceColor ⇒ la carte prend '
      'colorScheme.surface (et non une couleur en dur)',
      (tester) async {
        // `ZcrudTheme()` laisse `surfaceColor` à `null` ⇒ la branche `??` est
        // RÉELLEMENT empruntée. `_kSurface` est distinct de toutes les autres
        // couleurs du scheme : l'assertion ne peut pas passer par accident.
        await _pump(tester, zTheme: const ZcrudTheme());

        expect(_cardMaterial(tester).color, _kSurface,
            reason: 'la carte n\'utilise pas ZcrudTheme/Theme.of : une couleur '
                'est codée en dur (FR-26/NFR-SU4)');
      },
    );

    testWidgets(
      'CONTRE-PREUVE de la branche : un ZcrudTheme qui FOURNIT surfaceColor '
      'l\'emporte sur le repli',
      (tester) async {
        // Sans ce cas, le test ci-dessus resterait vert même si le widget
        // IGNORAIT `ZcrudTheme` et lisait toujours `Theme.of` : les deux
        // branches seraient indiscernables.
        await _pump(tester, zTheme: const ZcrudTheme(surfaceColor: _kThemedLabel));

        expect(_cardMaterial(tester).color, _kThemedLabel,
            reason: 'ZcrudTheme.surfaceColor est IGNORÉ : le thème injecté n\'a '
                'aucun pouvoir, seul Theme.of est lu');
      },
    );

    testWidgets(
      'le marquage du choix correct est THÉMATISÉ (jamais un vert en dur)',
      (tester) async {
        await _pump(tester, zTheme: const ZcrudTheme());
        await _reveal(tester);

        final marker = tester.widget<Icon>(find.byIcon(Icons.check_circle));
        expect(marker.color, _kOnSurface,
            reason: 'le marquage du bon choix porte une couleur en dur '
                '(ex. const Color(0xFF00AA00)) au lieu du thème');
      },
    );

    testWidgets(
      'le marqueur et le TEXTE du choix partagent le MÊME repli (jamais deux '
      'replis divergents dans la même Row)',
      (tester) async {
        // `_choiceRow` retombait sur `colorScheme.primary` tandis que le contenu
        // par défaut retombe sur `onSurface` : marqueur et texte de la MÊME
        // ligne s'affichaient de deux couleurs différentes, et `primary`
        // suggérait un élément interactif — que su-2 interdit (choix AFFICHÉS).
        await _pump(tester, zTheme: const ZcrudTheme());
        await _reveal(tester);

        final marker = tester.widget<Icon>(find.byIcon(Icons.check_circle));
        final text = tester.widget<Text>(find.text('Bon'));

        expect(marker.color, text.style?.color,
            reason: 'le marqueur et le texte de son choix divergent de couleur : '
                'deux replis concurrents (`?? primary` vs `?? onSurface`)');
      },
    );

    testWidgets('le marquage du choix correct suit le ZcrudTheme injecté',
        (tester) async {
      await _pump(tester, zTheme: const ZcrudTheme(labelColor: _kThemedLabel));
      await _reveal(tester);

      final marker = tester.widget<Icon>(find.byIcon(Icons.check_circle));
      expect(marker.color, _kThemedLabel);
    });
  });

  group('AC5 — canal NON-COLORÉ du choix correct (AD-13)', () {
    testWidgets(
      'le bon choix est trouvable SANS lire une couleur (icône + Semantics)',
      (tester) async {
        await _pump(tester, zTheme: const ZcrudTheme());
        await _reveal(tester);

        // (1) Canal ICÔNE — perceptible par un daltonien.
        expect(find.byIcon(Icons.check_circle), findsOneWidget,
            reason: 'aucune icône : le bon choix ne serait signalé QUE par la '
                'couleur — invisible à un daltonien (AD-13)');

        // (2) Canal SÉMANTIQUE — perceptible par un lecteur d'écran.
        expect(find.bySemanticsLabel(RegExp('Bonne réponse')), findsOneWidget,
            reason: 'aucune sémantique : le bon choix serait invisible à un '
                'lecteur d\'écran');
      },
    );

    testWidgets(
      '🔴 D2 — le marqueur est ASSOCIÉ à SON choix (et non au premier venu)',
      (tester) async {
        // ⚠️ Le test de PRÉSENCE ci-dessus ne prouve RIEN sur l'association :
        // avec `explicitChildNodes: true` et une `Row` non fusionnée, le
        // marqueur devient un nœud AUTONOME. Le lecteur d'écran lit alors
        // « Paris » → « Bonne réponse » → « Lome » et attache le marqueur à
        // PARIS — le choix FAUX. L'utilisateur non-voyant apprend une erreur.
        final handle = tester.ensureSemantics();
        await _pump(tester, zTheme: const ZcrudTheme(), card: _qcmCorrectEnDeuxieme);
        await _reveal(tester);

        final node = tester.getSemantics(find.bySemanticsLabel(RegExp('Bonne réponse')));

        expect(node.label, contains('Lome'),
            reason: 'le marqueur « Bonne réponse » est un nœud AUTONOME : il '
                'n\'est associé à AUCUN choix. Un lecteur d\'écran l\'attache '
                'au choix voisin dans l\'ordre de lecture — ici le FAUX.');
        expect(node.label, isNot(contains('Paris')),
            reason: 'le marqueur est associé au MAUVAIS choix (Paris)');
        expect(node.label, isNot(contains('Accra')),
            reason: 'le marqueur est associé au MAUVAIS choix (Accra)');

        handle.dispose();
      },
    );

    testWidgets(
      'CONTRE-PREUVE — la fusion ne noie PAS le marqueur : les choix FAUX '
      'restent des nœuds distincts, sans marqueur',
      (tester) async {
        // Garde-fou du fix D2 : fusionner TROP (au niveau de la face) ferait
        // retomber le marqueur dans le blob illisible que
        // `explicitChildNodes: true` avait précisément supprimé.
        final handle = tester.ensureSemantics();
        await _pump(tester, zTheme: const ZcrudTheme(), card: _qcmCorrectEnDeuxieme);
        await _reveal(tester);

        final faux = tester.getSemantics(find.bySemanticsLabel(RegExp('^Paris')));
        expect(faux.label, isNot(contains('Bonne réponse')),
            reason: 'un choix FAUX porte le marqueur : le canal n\'informe plus '
                'de rien (tout serait « bonne réponse »)');

        handle.dispose();
      },
    );

    testWidgets('les mauvais choix ne portent PAS le marqueur de bonne réponse',
        (tester) async {
      await _pump(tester, zTheme: const ZcrudTheme());
      await _reveal(tester);

      // Discriminant : si TOUS les choix portaient le marqueur, le canal
      // n'informerait de rien.
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
    });

    testWidgets(
      '🔴 D9 — le marqueur n\'est PAS dimensionné par un token d\'ESPACEMENT',
      (tester) async {
        // `size: theme.gapL` faisait piloter la taille du SEUL canal visuel
        // discriminant par un token d'espacement (seul cas du repo) : une app
        // réglant `gapL: 8` rétrécissait le `check_circle` à 8 dp — AD-13 perdu
        // pour un daltonien, sans qu'aucun test ne s'en aperçoive.
        await _pump(tester, zTheme: const ZcrudTheme(gapL: 8));
        await _reveal(tester);

        final size = tester.getSize(find.byIcon(Icons.check_circle));
        expect(size.height, greaterThanOrEqualTo(24.0),
            reason: 'le marqueur suit un token d\'ESPACEMENT (gapL) : régler '
                'les marges d\'une app écrase le canal non-coloré d\'AD-13');
        expect(size.width, greaterThanOrEqualTo(24.0));
      },
    );
  });

  group('AC5 — cibles tactiles ≥ 48 dp', () {
    testWidgets(
      'la carte (cible de révélation) mesure au moins 48 dp — SANS que le '
      'harnais ne le lui impose',
      (tester) async {
        // ⚠️ Ce cas mesurait la carte sous un `SizedBox(width: 400)` : la
        // largeur venait du HARNAIS, pas du widget — l'assertion était
        // TAUTOLOGIQUE (verte même sans aucune contrainte minimale dans le
        // code). Ici la carte est posée sous des contraintes LÂCHES : sa taille
        // est celle qu'elle se donne, et `< 200` prouve qu'elle est bien
        // INTRINSÈQUE (un « Q » seul mesure ~12 dp).
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(colorScheme: _scheme),
            home: const ZcrudScope(
              theme: ZcrudTheme(),
              child: Scaffold(
                body: Center(
                  child: ZFlashcardReviewCard(card: ZFlashcard(question: 'Q')),
                ),
              ),
            ),
          ),
        );

        final size = tester.getSize(find.byType(ZFlashcardReviewCard));
        expect(size.width, greaterThanOrEqualTo(48.0),
            reason: 'la cible de révélation est plus étroite que 48 dp (AD-13)');
        expect(size.height, greaterThanOrEqualTo(48.0),
            reason: 'la cible de révélation est plus basse que 48 dp (AD-13)');
        expect(size.width, lessThan(200.0),
            reason: 'la carte est dimensionnée par le HARNAIS et non par ses '
                'propres contraintes : la mesure ci-dessus ne prouve rien');
      },
    );

    testWidgets('l\'action d\'édition mesure au moins 48 × 48 dp',
        (tester) async {
      await _pump(tester, zTheme: const ZcrudTheme(), onEdit: () {});

      final size = tester.getSize(find.byKey(ZFlashcardReviewCard.editActionKey));
      expect(size.width, greaterThanOrEqualTo(48.0),
          reason: 'cible tactile trop étroite (AD-13)');
      expect(size.height, greaterThanOrEqualTo(48.0),
          reason: 'cible tactile trop basse (AD-13)');
    });
  });

  group('AC5 — Semantics explicites', () {
    testWidgets('l\'action porte un libellé sémantique l10n', (tester) async {
      await _pump(tester, zTheme: const ZcrudTheme(), onEdit: () {});
      expect(find.bySemanticsLabel('Modifier'), findsOneWidget);
    });

    testWidgets(
      'l\'état révélé est ANNONCÉ sémantiquement (pas qu\'un effet visuel)',
      (tester) async {
        final handle = tester.ensureSemantics();
        await _pump(tester, zTheme: const ZcrudTheme());

        expect(
          find.bySemanticsLabel('Afficher la réponse'),
          findsOneWidget,
          reason: 'la carte n\'annonce pas qu\'elle est révélable',
        );

        // Face QUESTION : la sémantique doit le dire.
        var node = tester.getSemantics(find.bySemanticsLabel('Afficher la réponse'));
        expect(node.value, 'Question');

        await _reveal(tester);

        // Face RÉPONSE : la VALEUR sémantique a changé — c'est ce qui rend la
        // révélation perceptible sans la voir.
        //
        // ⚠️ Le nœud est désormais cherché par le libellé de la face RÉPONSE :
        // le chercher par « Afficher la réponse » sur les DEUX faces (ce que
        // faisait ce test) rendait la garde D7 incapable de rougir, puisque le
        // libellé constant était précisément le défaut à détecter.
        node = tester.getSemantics(find.bySemanticsLabel('Masquer la réponse'));
        expect(node.value, 'Réponse',
            reason: 'l\'état révélé n\'est pas annoncé : un lecteur d\'écran ne '
                'saurait pas que la réponse est affichée');

        handle.dispose();
      },
    );

    testWidgets(
      '🔴 D7 — le libellé du TOGGLE décrit ce que le tap FAIT (il masque, une '
      'fois la réponse affichée)',
      (tester) async {
        // Un libellé constant annonce « Afficher la réponse » sur une réponse
        // DÉJÀ affichée : faux dans 50 % des états. Un utilisateur non-voyant
        // s'entend proposer d'afficher ce qu'il vient d'afficher, et n'a aucun
        // moyen de savoir que le contrôle masque.
        final handle = tester.ensureSemantics();
        await _pump(tester, zTheme: const ZcrudTheme());

        expect(find.bySemanticsLabel('Masquer la réponse'), findsNothing,
            reason: 'la face QUESTION annonce « Masquer » alors que le tap '
                'AFFICHE');

        await _reveal(tester);

        expect(find.bySemanticsLabel('Masquer la réponse'), findsOneWidget,
            reason: 'face RÉPONSE : le tap MASQUE, mais le libellé annonce '
                'encore « Afficher la réponse » — annonce fausse');
        expect(find.bySemanticsLabel('Afficher la réponse'), findsNothing);

        handle.dispose();
      },
    );

    testWidgets(
      '🔴 D8 — AUCUN nœud tappable ANONYME ne double la révélation nommée',
      (tester) async {
        // L'`InkWell` de la carte exposait un second nœud tappable sans nom
        // (`label: ""`, `actions: tap`) : TalkBack annonce « bouton » sans dire
        // lequel, en doublon du nœud nommé de la face.
        final handle = tester.ensureSemantics();
        await _pump(tester, zTheme: const ZcrudTheme());

        final anonymesTappables = _sousArbre(
          tester.getSemantics(find.byType(ZFlashcardReviewCard)),
        )
            .where((SemanticsNode n) =>
                n.label.isEmpty &&
                n.getSemanticsData().hasAction(SemanticsAction.tap))
            .toList();

        expect(anonymesTappables, isEmpty,
            reason: 'nœud tappable ANONYME : un lecteur d\'écran annonce un '
                'contrôle sans nom qui duplique « Afficher la réponse »');

        handle.dispose();
      },
    );
  });

  group('AC5 — RTL (AD-13)', () {
    // La garde de SOURCE (`z_flashcard_rtl_guard_test.dart`) interdit les
    // variantes non directionnelles ; ce cas prouve en plus que la carte se
    // CONSTRUIT réellement dans les deux directions.
    for (final direction in TextDirection.values) {
      testWidgets('la carte se construit en ${direction.name} sans exception',
          (tester) async {
        await _pump(tester, zTheme: const ZcrudTheme(), direction: direction);
        expect(tester.takeException(), isNull);
        expect(find.text('Q'), findsOneWidget);

        await _reveal(tester);
        expect(tester.takeException(), isNull);
        expect(find.byIcon(Icons.check_circle), findsOneWidget);
      });
    }
  });

  group('AC5 — zéro libellé en dur : le seam l10n est consulté', () {
    testWidgets(
      'un ZcrudScope.labels injecté REMPLACE le fallback (preuve que les '
      'libellés passent par label(context, key, fallback:))',
      (tester) async {
        // Discriminant réel : si le widget écrivait « Aucune réponse » en dur,
        // la table injectée n'aurait aucun effet et ce test rougirait.
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(colorScheme: _scheme),
            home: ZcrudScope(
              labels: ZcrudLabels(<String, String>{
                'zcrud.flashcard.noAnswer': 'RIEN À DIRE',
              }),
              child: const Scaffold(
                body: Center(
                  child: SizedBox(
                    width: 400,
                    child: ZFlashcardReviewCard(
                      card: ZFlashcard(question: 'Q'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await _reveal(tester);

        expect(find.text('RIEN À DIRE'), findsOneWidget,
            reason: 'le libellé de repli est codé EN DUR : la table l10n '
                'injectée n\'a aucun pouvoir (NFR-SU4)');
        expect(find.text('Aucune réponse'), findsNothing);
      },
    );
  });
}
