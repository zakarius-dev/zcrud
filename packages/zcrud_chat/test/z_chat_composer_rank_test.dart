/// Les NEUF RANGS du composer — ce que ce fichier mesure.
///
/// Le contrat du lot n'est pas « il existe des créneaux de plus » : c'est
/// **l'ordre**. C'est le fait d'être DANS le cadre, à un rang précis, qui fait
/// qu'une vignette ajoutée pousse le champ vers le bas sans sortir de la
/// boîte. Un créneau au mauvais rang casse cette propriété sans casser une
/// seule compilation — d'où des gardes qui mesurent des RECTANGLES, jamais
/// des noms de widgets.
///
/// * **RNG-I** — INERTIE : aucun créneau neuf fourni ⇒ arbre ET géométrie
///   identiques à l'avant-lot, au pixel près. Vaut pour l'hôte passif.
/// * **RNG-O** — ORDRE : les neuf rangs montés ensemble se lisent 0…8 du haut
///   vers le bas, sans exception et sans égalité fortuite.
/// * **RNG-A** — ABSENCE : un créneau non fourni — ou dont le builder rend
///   `null` — n'intercale AUCUN nœud, pas même de taille nulle (AD-4).
/// * **RNG-G** — GRANULARITÉ : un créneau qui change ne reconstruit pas le
///   champ, ne perd ni le focus, ni le texte, ni la position du curseur.
/// * **RNG-L** — les deux seuls réglages de disposition : alignement de
///   l'envoi, placement de la bande.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';

import 'support/z_chat_fakes.dart';
import 'support/z_chat_render_harness.dart';

/// Couleur de curseur du TEST — le socle n'en invente aucune (FR-26).
const Color _cursor = Color(0xFF123456);

/// LE CADRE — la marge que le composer pose autour de ses rangs.
///
/// C'est ce nœud, et non le widget [ZChatComposer], qui matérialise la boîte :
/// un rang hissé au-dessus de lui resterait « dans le composer » tout en étant
/// SORTI de la boîte. Une garde ancrée sur le widget ne verrait pas la
/// différence — celle-ci si.
Finder _frameFinder() => find
    .descendant(of: find.byType(ZChatComposer), matching: find.byType(Padding))
    .first;

/// La `Column` DES RANGS — celle qui vit dans le cadre, jamais une autre.
Column _column(WidgetTester tester) => tester.widget<Column>(
  find.descendant(of: _frameFinder(), matching: find.byType(Column)).first,
);

/// Le rectangle du cadre.
Rect _frame(WidgetTester tester) => tester.getRect(_frameFinder());

/// Un créneau témoin, reconnaissable par sa clé et mesurable par sa boîte.
ZChatComposerSlotBuilder _mark(Key key) =>
    (BuildContext context, ZChatComposerSlot slot) =>
        SizedBox(key: key, width: 48, height: 12);

/// Un créneau dont le builder rend `null` — le second cas d'AD-4.
Widget? _nothing(BuildContext context, ZChatComposerSlot slot) => null;

/// Le rectangle rendu d'une clé, en coordonnées globales.
Rect _rect(WidgetTester tester, Key key) =>
    tester.getRect(find.byKey(key));

/// Le rectangle rendu du champ de saisie.
Rect _fieldRect(WidgetTester tester) =>
    tester.getRect(find.byType(EditableText));

const Key _kStatus = ValueKey<String>('rng-status');
const Key _kEditing = ValueKey<String>('rng-editing');
const Key _kProgress = ValueKey<String>('rng-progress');
const Key _kSuggestions = ValueKey<String>('rng-suggestions');
const Key _kAttachments = ValueKey<String>('rng-attachments');
const Key _kCapture = ValueKey<String>('rng-capture');
const Key _kLeading = ValueKey<String>('rng-leading');
const Key _kTrailing = ValueKey<String>('rng-trailing');
const Key _kTools = ValueKey<String>('rng-tools');
const Key _kCounter = ValueKey<String>('rng-counter');

/// La clé du composer lui-même — c'est LE CADRE, celui dont rien ne doit
/// sortir.
const Key _kComposer = ValueKey<String>('rng-frame');

/// Un composer dont les NEUF rangs sont fournis, chacun par un témoin
/// mesurable. C'est le sujet de la garde d'ordre.
ZChatComposer _full(ZChatController controller) => ZChatComposer(
  key: _kComposer,
  controller: controller,
  cursorColor: _cursor,
  status: _mark(_kStatus),
  editingBanner: _mark(_kEditing),
  progress: _mark(_kProgress),
  suggestions: _mark(_kSuggestions),
  attachments: _mark(_kAttachments),
  capture: _mark(_kCapture),
  leading: _mark(_kLeading),
  trailing: _mark(_kTrailing),
  tools: _mark(_kTools),
  counter: _mark(_kCounter),
);


/// Un composer portant UN SEUL créneau neuf, désigné par son nom.
///
/// Le passage par un nom plutôt que par cinq tests recopiés est ce qui garantit
/// qu'aucun rang neuf n'échappe à la mesure : ajouter un rang sans l'inscrire
/// ici laisse la table de la garde incomplète, et cela se voit.
ZChatComposer _only(
  ZChatController controller,
  String rank,
  ZChatComposerSlotBuilder? builder,
) => ZChatComposer(
  key: _kComposer,
  controller: controller,
  cursorColor: _cursor,
  status: rank == 'status' ? builder : null,
  editingBanner: rank == 'editingBanner' ? builder : null,
  progress: rank == 'progress' ? builder : null,
  suggestions: rank == 'suggestions' ? builder : null,
  attachments: rank == 'attachments' ? builder : null,
  counter: rank == 'counter' ? builder : null,
);

/// Les six rangs neufs du lot, dans l'ordre du cadre.
const List<String> _newRanks = <String>[
  'status',
  'editingBanner',
  'progress',
  'suggestions',
  'attachments',
  'counter',
];

void main() {
  group('🔴 RNG-I — INERTIE : l\'hôte passif retrouve son arbre', () {
    testWidgets(
      'RNG-I1 — un composer construit SANS les paramètres du lot et un '
      'composer aux défauts explicites rendent la MÊME géométrie',
      (WidgetTester tester) async {
        final rig = buildController();
        addTearDown(rig.controller.dispose);

        await tester.pumpWidget(
          harness(
            ZChatComposer(
              controller: rig.controller,
              cursorColor: _cursor,
              capture: _mark(_kCapture),
              leading: _mark(_kLeading),
              trailing: _mark(_kTrailing),
              tools: _mark(_kTools),
            ),
          ),
        );
        final int before = _column(tester).children.length;
        // ABSOLU, pas relatif : une comparaison de deux arbres portant le
        // MÊME défaut ne verrait rien. Le cadre d'avant le lot a exactement
        // trois enfants — rang 5, ancre, rang 7.
        expect(
          before,
          3,
          reason: '🔴 le cadre d\'un hôte passif porte un enfant de plus : un '
              'rang non fourni s\'est matérialisé',
        );
        final Rect field = _fieldRect(tester);
        final Rect capture = _rect(tester, _kCapture);
        final Rect tools = _rect(tester, _kTools);
        final Rect leading = _rect(tester, _kLeading);
        final Rect trailing = _rect(tester, _kTrailing);

        await tester.pumpWidget(
          harness(
            ZChatComposer(
              // Les mêmes créneaux, plus TOUS les réglages du lot posés à
              // leur défaut : si un défaut avait dérivé, la géométrie
              // bougerait ici et nulle part ailleurs.
              controller: rig.controller,
              cursorColor: _cursor,
              capture: _mark(_kCapture),
              leading: _mark(_kLeading),
              trailing: _mark(_kTrailing),
              tools: _mark(_kTools),
              sendAlignment: ZChatComposerSendAlignment.bottom,
              bandPlacement: ZChatComposerBandPlacement.below,
              compact: false,
            ),
          ),
        );

        expect(
          _column(tester).children,
          hasLength(before),
          reason: '🔴 les défauts du lot ont changé le NOMBRE d\'enfants du '
              'cadre : l\'hôte passif ne retrouve pas son arbre',
        );
        expect(_fieldRect(tester), field,
            reason: '🔴 le CHAMP a bougé sous des réglages par défaut');
        expect(_rect(tester, _kCapture), capture,
            reason: '🔴 le rang 5 a bougé sous des réglages par défaut');
        expect(_rect(tester, _kTools), tools,
            reason: '🔴 le rang 7 a bougé sous des réglages par défaut');
        expect(_rect(tester, _kLeading), leading,
            reason: '🔴 le créneau de tête a bougé');
        expect(_rect(tester, _kTrailing), trailing,
            reason: '🔴 le créneau d\'envoi a bougé');
      },
    );

    testWidgets(
      'RNG-I2 — six builders qui rendent `null` laissent la géométrie '
      'IDENTIQUE à celle d\'un composer qui ne les a pas',
      (WidgetTester tester) async {
        final rig = buildController();
        addTearDown(rig.controller.dispose);

        await tester.pumpWidget(
          harness(
            ZChatComposer(
              controller: rig.controller,
              cursorColor: _cursor,
              capture: _mark(_kCapture),
              tools: _mark(_kTools),
            ),
          ),
        );
        final int before = _column(tester).children.length;
        // ABSOLU (cf. RNG-I1) : trois enfants, et pas un de plus.
        expect(
          before,
          3,
          reason: '🔴 le cadre porte un enfant de plus AVANT même que les '
              'builders `null` soient fournis',
        );
        final Rect field = _fieldRect(tester);
        final Rect capture = _rect(tester, _kCapture);
        final Rect tools = _rect(tester, _kTools);

        await tester.pumpWidget(
          harness(
            ZChatComposer(
              controller: rig.controller,
              cursorColor: _cursor,
              capture: _mark(_kCapture),
              tools: _mark(_kTools),
              status: _nothing,
              editingBanner: _nothing,
              progress: _nothing,
              suggestions: _nothing,
              attachments: _nothing,
              counter: _nothing,
            ),
          ),
        );

        expect(
          _column(tester).children,
          hasLength(before),
          reason: '🔴 un builder rendant `null` a matérialisé un nœud '
              '(AD-4 : absent, jamais un conteneur vide)',
        );
        expect(_fieldRect(tester), field,
            reason: '🔴 six créneaux vides ont déplacé le champ');
        expect(_rect(tester, _kCapture), capture,
            reason: '🔴 six créneaux vides ont déplacé le rang 5');
        expect(_rect(tester, _kTools), tools,
            reason: '🔴 six créneaux vides ont déplacé le rang 7');
      },
    );
  });

  group('🔴 RNG-O — ORDRE : les neuf rangs, de 0 à 8', () {
    testWidgets(
      'RNG-O1 — montés ENSEMBLE, ils se lisent du haut vers le bas dans '
      'l\'ordre canonique, et l\'ancre est au rang 6',
      (WidgetTester tester) async {
        final rig = buildController();
        addTearDown(rig.controller.dispose);
        await tester.pumpWidget(harness(_full(rig.controller)));

        expect(
          _column(tester).children,
          hasLength(9),
          reason: '🔴 les neuf rangs fournis ne donnent pas neuf enfants',
        );

        // Le rang 6 n'a pas de clé : c'est la `Row`, mesurée par son champ.
        final List<(String, Rect)> ranks = <(String, Rect)>[
          ('0 status', _rect(tester, _kStatus)),
          ('1 editingBanner', _rect(tester, _kEditing)),
          ('2 progress', _rect(tester, _kProgress)),
          ('3 suggestions', _rect(tester, _kSuggestions)),
          ('4 attachments', _rect(tester, _kAttachments)),
          ('5 capture', _rect(tester, _kCapture)),
          ('6 ancre', _fieldRect(tester)),
          ('7 tools', _rect(tester, _kTools)),
          ('8 counter', _rect(tester, _kCounter)),
        ];
        for (int i = 0; i + 1 < ranks.length; i++) {
          final (String lower, Rect a) = ranks[i];
          final (String upper, Rect b) = ranks[i + 1];
          // Deux assertions, pas une : `bottom <= top` seule passerait pour
          // deux rangs superposés de hauteur nulle.
          expect(
            a.bottom,
            lessThanOrEqualTo(b.top),
            reason: '🔴 le rang « $lower » CHEVAUCHE le rang « $upper » : '
                'l\'ordre du cadre est rompu',
          );
          expect(
            a.top,
            lessThan(b.top),
            reason: '🔴 le rang « $lower » n\'est pas AU-DESSUS du rang '
                '« $upper » : l\'ordre canonique 0…8 n\'est pas tenu',
          );
        }
      },
    );

    testWidgets(
      'RNG-O2 — le rang 4 POUSSE le champ vers le bas et rien ne sort du '
      'cadre : c\'est la propriété que le rang existe pour tenir',
      (WidgetTester tester) async {
        final rig = buildController();
        addTearDown(rig.controller.dispose);

        await tester.pumpWidget(
          harness(
            ZChatComposer(
              key: _kComposer,
              controller: rig.controller,
              cursorColor: _cursor,
              tools: _mark(_kTools),
            ),
          ),
        );
        final double fieldTopBefore = _fieldRect(tester).top;
        final double frameBefore = _frame(tester).height;

        const double grown = 40;
        await tester.pumpWidget(
          harness(
            ZChatComposer(
              key: _kComposer,
              controller: rig.controller,
              cursorColor: _cursor,
              tools: _mark(_kTools),
              attachments: (BuildContext context, ZChatComposerSlot slot) =>
                  const SizedBox(key: _kAttachments, height: grown),
            ),
          ),
        );

        final Rect frame = _frame(tester);
        final Rect strip = _rect(tester, _kAttachments);
        expect(
          _fieldRect(tester).top - fieldTopBefore,
          moreOrLessEquals(grown, epsilon: 0.5),
          reason: '🔴 une vignette ajoutée n\'a pas POUSSÉ le champ : le rang '
              '4 se superpose au lieu de s\'empiler',
        );
        expect(
          frame.height - frameBefore,
          moreOrLessEquals(grown, epsilon: 0.5),
          reason: '🔴 le CADRE n\'a pas absorbé la vignette : elle a débordé '
              'au lieu de pousser',
        );
        expect(
          frame.contains(strip.topLeft) && frame.contains(strip.bottomRight - const Offset(0.5, 0.5)),
          isTrue,
          reason: '🔴 la vignette est SORTIE de la boîte : le rang 4 n\'est '
              'pas dans le cadre, il est à côté',
        );
      },
    );
  });

  group('🔴 RNG-A — ABSENCE : AD-4, rang par rang', () {
    for (final String rank in _newRanks) {
      testWidgets(
        'RNG-A[$rank] — non fourni, ou builder rendant `null` : AUCUN nœud '
        'intercalé, pas même de taille nulle',
        (WidgetTester tester) async {
          final rig = buildController();
          addTearDown(rig.controller.dispose);

          // 1. Non fourni.
          await tester.pumpWidget(
            harness(_only(rig.controller, rank, null)),
          );
          expect(
            _column(tester).children,
            hasLength(1),
            reason: '🔴 le rang « $rank » non fourni occupe un enfant du '
                'cadre (AD-4 : absent, jamais un conteneur vide)',
          );
          expect(
            _column(tester).children.single,
            isA<Row>(),
            reason: '🔴 l\'unique enfant du cadre n\'est plus l\'ancre : le '
                'rang « $rank » a laissé un nœud à sa place',
          );

          // 2. Fourni, mais rendant `null` — le second cas d'AD-4, celui
          //    qu'un `SizedBox.shrink()` de complaisance ferait passer.
          await tester.pumpWidget(
            harness(_only(rig.controller, rank, _nothing)),
          );
          expect(
            _column(tester).children,
            hasLength(1),
            reason: '🔴 le rang « $rank » rendant `null` a matérialisé un '
                'nœud',
          );

          // 3. Fourni et rendant quelque chose : UN enfant de plus, et un
          //    seul. Sans ce troisième temps, une garde d'absence resterait
          //    verte sur un rang jamais monté.
          await tester.pumpWidget(
            harness(_only(rig.controller, rank, _mark(_kStatus))),
          );
          expect(
            _column(tester).children,
            hasLength(2),
            reason: '🔴 le rang « $rank » fourni n\'ajoute pas exactement un '
                'enfant : il n\'est pas monté, ou il est monté deux fois',
          );
          expect(
            find.byKey(_kStatus),
            findsOneWidget,
            reason: '🔴 le rang « $rank » est déclaré mais son contenu n\'est '
                'PAS dans l\'arbre',
          );
        },
      );
    }
  });

  group('🔴 RNG-G — GRANULARITÉ : un rang qui change ne touche pas le champ', () {
    testWidgets(
      'RNG-G1 — le rang 8 se remet à jour à CHAQUE frappe ; le champ n\'est '
      'PAS reconstruit et garde focus, texte et position du curseur',
      (WidgetTester tester) async {
        final rig = buildController();
        addTearDown(rig.controller.dispose);

        await tester.pumpWidget(
          harness(
            ZChatComposer(
              key: _kComposer,
              controller: rig.controller,
              cursorColor: _cursor,
              // Le compteur est le rang le plus exigeant du cadre : il
              // s'abonne au canal LE PLUS BAVARD du composer. S'abonner y est
              // légitime — le faire AU-DESSUS du champ ne l'est pas. Un rang
              // piloté par une tranche que le composer ne détient pas ne
              // pourrait pas distinguer les deux, et la garde serait inerte.
              counter: (BuildContext context, ZChatComposerSlot slot) =>
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: slot.controller.composer,
                    builder: (BuildContext c, TextEditingValue v, Widget? _) =>
                        SizedBox(
                          key: _kCounter,
                          height: 8 + v.text.length.toDouble(),
                        ),
                  ),
            ),
          ),
        );

        await tester.enterText(find.byType(EditableText), 'brouillon');
        await tester.pump();
        final FocusNode focus =
            tester.widget<EditableText>(find.byType(EditableText)).focusNode;
        focus.requestFocus();
        rig.controller.composer.selection =
            const TextSelection.collapsed(offset: 4);
        await tester.pump();
        expect(focus.hasFocus, isTrue,
            reason: 'préalable : le champ n\'a pas le focus');

        final EditableText before =
            tester.widget<EditableText>(find.byType(EditableText));
        final double rankBefore = _rect(tester, _kCounter).height;

        // Une frappe de plus, curseur maintenu là où il est.
        rig.controller.composer.value = const TextEditingValue(
          text: 'brouillons',
          selection: TextSelection.collapsed(offset: 4),
        );
        await tester.pump();

        // Contre-preuve d'abord : sans elle, tout ce qui suit serait vert
        // parce que RIEN n'a bougé.
        expect(
          _rect(tester, _kCounter).height,
          greaterThan(rankBefore),
          reason: 'préalable : le rang 8 n\'a pas réagi, la mesure est vide',
        );

        expect(
          identical(
            before,
            tester.widget<EditableText>(find.byType(EditableText)),
          ),
          isTrue,
          reason: '🔴 le champ a été RECONSTRUIT parce qu\'un rang a changé : '
              'l\'abonnement remonte AU-DESSUS du champ (SM-1)',
        );
        expect(focus.hasFocus, isTrue,
            reason: '🔴 le champ a PERDU LE FOCUS quand un rang a changé');
        expect(rig.controller.composer.text, 'brouillons',
            reason: '🔴 la saisie a été perdue quand un rang a changé');
        expect(
          rig.controller.composer.selection,
          const TextSelection.collapsed(offset: 4),
          reason: '🔴 le curseur a SAUTÉ quand un rang a changé',
        );
      },
    );
  });

  group('🔴 RNG-L — les deux réglages de disposition, et rien de plus', () {
    testWidgets(
      'RNG-L1 — `center` remonte l\'envoi sur la hauteur du champ ; `bottom` '
      'le laisse en bas',
      (WidgetTester tester) async {
        final rig = buildController();
        addTearDown(rig.controller.dispose);
        // Un champ HAUT : sans plusieurs lignes, les deux alignements
        // coïncideraient et la garde passerait sans rien mesurer.
        rig.controller.composer.text = 'a\nb\nc\nd';

        Future<Rect> pumpWith(ZChatComposerSendAlignment a) async {
          await tester.pumpWidget(
            harness(
              ZChatComposer(
                key: _kComposer,
                controller: rig.controller,
                cursorColor: _cursor,
                sendAlignment: a,
                trailing: _mark(_kTrailing),
              ),
            ),
          );
          // La CIBLE d'envoi — la boîte de 48 dp — et non le témoin
          // centré dedans : c'est elle que la `Row` aligne.
          return tester.getRect(
            find
                .ancestor(
                  of: find.byKey(_kTrailing),
                  matching: find.byType(ConstrainedBox),
                )
                .first,
          );
        }

        final Rect bottom = await pumpWith(ZChatComposerSendAlignment.bottom);
        final Rect centered = await pumpWith(ZChatComposerSendAlignment.center);
        final Rect field = _fieldRect(tester);

        expect(
          centered.center.dy,
          lessThan(bottom.center.dy),
          reason: '🔴 `center` n\'a pas remonté l\'envoi : l\'enum ne pilote '
              'pas l\'alignement transversal',
        );
        expect(
          centered.center.dy,
          moreOrLessEquals(field.center.dy, epsilon: 1),
          reason: '🔴 `center` ne centre pas l\'envoi SUR LE CHAMP',
        );
        expect(
          bottom.bottom,
          moreOrLessEquals(field.bottom, epsilon: 1),
          reason: '🔴 `bottom` ne pose plus la cible d\'envoi au bas du '
              'champ : le défaut a dérivé',
        );
        expect(
          bottom.center.dy,
          greaterThan(field.center.dy),
          reason: '🔴 `bottom` a cessé de suivre le BAS d\'un champ à '
              'plusieurs lignes',
        );
      },
    );

    testWidgets(
      'RNG-L2 — `above` fait passer la bande DEVANT l\'ancre, sans changer '
      'ni le nombre d\'enfants ni la place des rangs qui la précèdent',
      (WidgetTester tester) async {
        final rig = buildController();
        addTearDown(rig.controller.dispose);

        Future<void> pumpWith(ZChatComposerBandPlacement p) => tester.pumpWidget(
          harness(
            ZChatComposer(
              key: _kComposer,
              controller: rig.controller,
              cursorColor: _cursor,
              bandPlacement: p,
              capture: _mark(_kCapture),
              tools: _mark(_kTools),
              counter: _mark(_kCounter),
            ),
          ),
        );

        await pumpWith(ZChatComposerBandPlacement.below);
        expect(_column(tester).children, hasLength(4));
        expect(_rect(tester, _kTools).top,
            greaterThanOrEqualTo(_fieldRect(tester).bottom),
            reason: '🔴 le défaut `below` ne pose plus la bande sous l\'ancre');

        await pumpWith(ZChatComposerBandPlacement.above);
        expect(
          _column(tester).children,
          hasLength(4),
          reason: '🔴 `above` a changé le NOMBRE d\'enfants : ce n\'est plus '
              'un échange de rangs, c\'est un second arbre',
        );
        expect(
          _rect(tester, _kTools).bottom,
          lessThanOrEqualTo(_fieldRect(tester).top),
          reason: '🔴 `above` n\'a pas remonté la bande devant l\'ancre',
        );
        expect(
          _rect(tester, _kCapture).bottom,
          lessThanOrEqualTo(_rect(tester, _kTools).top),
          reason: '🔴 `above` a fait passer la bande devant le rang 5 : elle '
              'ne doit franchir que l\'ancre',
        );
        expect(
          _rect(tester, _kCounter).top,
          greaterThanOrEqualTo(_fieldRect(tester).bottom),
          reason: '🔴 `above` a emporté le rang 8 avec elle',
        );
      },
    );
  });
}
