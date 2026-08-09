/// 🎯 CR-SELECT-SEAM (2026-08-09) — gardes de la **consommation** du seam
/// élargi et de la **chaîne de jetons**.
///
/// Cinq familles :
///
/// 1. **`field.leading`** — capacité qu'un lot précédent avait déclarée
///    inatteignable : elle l'était déjà. `null` ⇒ slot ABSENT (AD-4).
/// 2. **`isLoading` / `choiceBuilder`** — la règle d'inertie EXACTE de DODLP
///    (`choiceBuilder == null && (readOnly || isLoading)`).
/// 3. **AD-10 sur le chargeur asynchrone** — `Exception`, `Error` et
///    `Future` jamais terminée ⇒ rendu dégradé, jamais d'exception, jamais
///    d'écran bloqué.
/// 4. **AD-2 / SM-1** — un chargement en cours ne reconstruit pas le champ.
/// 5. **Chaîne `paramètre > jeton > référence`**, prouvée dans les DEUX sens,
///    plus la totalité de la conversion de palier (AD-10) et le plancher
///    AD-13 non abaissable **par le jeton**.
///
/// 🔴 **Anti-tautologie** : les attentes portent sur des **littéraux** (les
/// valeurs relevées chez DODLP) ou sur des valeurs posées par le test, jamais
/// sur la constante qui produit le rendu.
///
/// 🔴 **Anti-vacuité de jeton** : chaque garde de jeton affirme d'abord que la
/// valeur du jeton **diffère** de l'ambiante et de la référence.
@TestOn('vm')
library;

import 'dart:async';

import 'package:awesome_select/awesome_select.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_select/zcrud_select.dart';

const List<ZFieldChoice> _abc = <ZFieldChoice>[
  ZFieldChoice(value: 'a', label: 'Alpha'),
  ZFieldChoice(value: 'b', label: 'Bravo'),
];

ZSelectPresentation _presentation({
  bool multiple = false,
  bool readOnly = false,
  bool isLoading = false,
  bool searchable = false,
  Object? selected,
  ZSelectChoiceBuilder? choiceBuilder,
  ZSelectOptionsLoader? optionsLoader,
  ZFieldAdornment? leading,
  ValueChanged<Object?>? onChanged,
}) =>
    ZSelectPresentation(
      field: ZFieldSpec(
        name: 'f',
        type: EditionFieldType.select,
        label: 'Mon champ',
        choices: _abc,
        readOnly: readOnly,
        leading: leading,
      ),
      options: _abc,
      selected: selected,
      onChanged: onChanged ?? (_) {},
      multiple: multiple,
      searchable: searchable,
      readOnly: readOnly,
      isLoading: isLoading,
      label: 'Mon champ',
      choiceBuilder: choiceBuilder,
      optionsLoader: optionsLoader,
    );

/// Monte le présentateur **directement** sur une `ZSelectPresentation` — on
/// mesure ce que le présentateur fait de son DTO, sans passer par le dispatcher.
Widget _host(
  ZSelectPresentation p, {
  ZSelectTileSpec? spec,
  ZcrudTheme? token,
  ThemeData? theme,
}) {
  final presenter = ZSmartSelectPresenter(spec: spec);
  return MaterialApp(
    theme: theme,
    home: ZcrudScope(
      theme: token,
      child: Scaffold(
        body: Builder(builder: (ctx) => presenter.present(ctx, p)),
      ),
    ),
  );
}

/// Le `ListTile` du déclencheur (celui que porte le `Card` du présentateur).
final Finder _trigger = find.descendant(
  of: find.byType(Card),
  matching: find.byType(ListTile),
);

void main() {
  // ══════════════════════════════════════════════════════════════════════════
  // 1. `field.leading` — atteignable depuis TOUJOURS, désormais consommé
  // ══════════════════════════════════════════════════════════════════════════

  group('🎯 SEAM-A — `field.leading` (parité `ListTile.leading` DODLP)', () {
    testWidgets(
      'sans ornement, le slot `leading` est ABSENT de l\'arbre (AD-4) — '
      'rendu antérieur strictement conservé',
      (tester) async {
        await tester.pumpWidget(_host(_presentation()));
        await tester.pumpAndSettle();
        expect(tester.widget<ListTile>(_trigger).leading, isNull);
      },
    );

    testWidgets(
      'avec un ornement `.icon`, le slot `leading` porte l\'icône RÉSOLUE',
      (tester) async {
        await tester.pumpWidget(_host(_presentation(
          leading: const ZFieldAdornment.icon('person'),
        )));
        await tester.pumpAndSettle();
        final ListTile tile = tester.widget<ListTile>(_trigger);
        expect(
          tile.leading,
          isNotNull,
          reason: '🔴 `field.leading` ignoré : c\'est la capacité que le lot '
              'précédent avait déclarée « non atteignable » alors qu\'elle '
              'l\'était (le DTO porte `field`).',
        );
        // Littéral : la table du cœur associe la clé neutre `person` à
        // `Icons.person_outline`. Ancré sur le SDK, pas sur notre constante.
        expect((tile.leading! as Icon).icon, Icons.person_outline);
      },
    );

    testWidgets(
      'AD-10 — une clé d\'icône INCONNUE ne lève pas : le slot est simplement '
      'absent',
      (tester) async {
        await tester.pumpWidget(_host(_presentation(
          leading: const ZFieldAdornment.icon('licorne-arc-en-ciel'),
        )));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(tester.widget<ListTile>(_trigger).leading, isNull);
      },
    );
  });

  // ══════════════════════════════════════════════════════════════════════════
  // 2. `isLoading` / `choiceBuilder` — règle d'inertie EXACTE de DODLP
  // ══════════════════════════════════════════════════════════════════════════

  group('🎯 SEAM-B — inertie du déclencheur (`choiceBuilder == null && '
      '(readOnly || isLoading)`)', () {
    testWidgets('hôte passif : ni readOnly ni isLoading ⇒ TAPABLE',
        (tester) async {
      await tester.pumpWidget(_host(_presentation()));
      await tester.pumpAndSettle();
      expect(tester.widget<ListTile>(_trigger).onTap, isNotNull);
    });

    testWidgets(
      '🔴 `isLoading: true` ⇒ déclencheur INERTE — c\'était irreproductible '
      'avant l\'élargissement du seam',
      (tester) async {
        await tester.pumpWidget(_host(_presentation(isLoading: true)));
        await tester.pumpAndSettle();
        final ListTile tile = tester.widget<ListTile>(_trigger);
        expect(
          tile.onTap,
          isNull,
          reason: '🔴 ouvrir un modal dont les options ne sont PAS chargées '
              'affiche une liste vide et fait croire qu\'il n\'y a rien.',
        );
        // Et l'annonce accessible suit : pas d'action `tap` sur le nœud.
        final SemanticsNode node = tester.getSemantics(
          find.bySemanticsLabel('Mon champ'),
        );
        expect(
          node.getSemanticsData().hasAction(SemanticsAction.tap),
          isFalse,
        );
      },
    );

    testWidgets(
      '🔴 un `choiceBuilder` RÉ-ACTIVE le tap même en lecture seule ET en '
      'chargement — la règle exacte de DODLP, pas sa version simplifiée',
      (tester) async {
        Widget builder(BuildContext c, ZSelectChoiceContext ctx) =>
            Text('opt:${ctx.choice.label}');

        // Cas 1 : chargement + builder.
        await tester.pumpWidget(_host(_presentation(
          isLoading: true,
          choiceBuilder: builder,
        )));
        await tester.pumpAndSettle();
        expect(tester.widget<ListTile>(_trigger).onTap, isNotNull);

        // Cas 2 : lecture seule + builder + une valeur (sans valeur, le tile
        // DISPARAÎT par parité `EmptyContainer` — ce n'est pas ce qu'on mesure).
        await tester.pumpWidget(_host(_presentation(
          readOnly: true,
          selected: 'a',
          choiceBuilder: builder,
        )));
        await tester.pumpAndSettle();
        expect(tester.widget<ListTile>(_trigger).onTap, isNotNull);

        // 🔴 Anti-vacuité : SANS builder, les deux cas sont bien INERTES.
        await tester.pumpWidget(_host(_presentation(
          readOnly: true,
          selected: 'a',
        )));
        await tester.pumpAndSettle();
        expect(tester.widget<ListTile>(_trigger).onTap, isNull);
      },
    );
  });

  // ══════════════════════════════════════════════════════════════════════════
  // 3. AD-10 — le chargeur asynchrone ne casse RIEN, quoi qu'il fasse
  // ══════════════════════════════════════════════════════════════════════════

  group('🎯 SEAM-C — AD-10 : chargeur asynchrone défaillant', () {
    testWidgets(
      '🔴 un chargeur qui lève une `Exception` (l\'échec NORMAL d\'une E/S en '
      'Dart, que le fork ne rattrape PAS) ⇒ liste vide, AUCUNE exception',
      (tester) async {
        var called = 0;
        await tester.pumpWidget(_host(_presentation(
          searchable: true,
          optionsLoader: (q) async {
            called++;
            throw Exception('réseau indisponible');
          },
        )));
        await tester.pumpAndSettle();
        await tester.tap(_trigger);
        await tester.pumpAndSettle();

        expect(called, greaterThan(0),
            reason: 'anti-vacuité : le chargeur a bien été appelé.');
        expect(
          tester.takeException(),
          isNull,
          reason: '🔴 `S2Choices.load` ne rattrape que `on Error` : sans notre '
              'enveloppe, une `Exception` remonte non capturée et laisse le '
              'modal figé sur son indicateur d\'attente.',
        );
        // L'issue de sortie existe : le modal reste fermable.
        expect(find.byType(SmartSelect<dynamic>), findsOneWidget);
      },
    );

    testWidgets(
      'un chargeur qui lève une `Error` ⇒ même rendu dégradé, aucune exception',
      (tester) async {
        await tester.pumpWidget(_host(_presentation(
          searchable: true,
          optionsLoader: (q) async => throw StateError('bug hôte'),
        )));
        await tester.pumpAndSettle();
        await tester.tap(_trigger);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '🔴 un chargeur qui NE SE TERMINE JAMAIS est abandonné au bout du délai '
      'de référence — sans lui, l\'attente serait DÉFINITIVE (le `finally` du '
      'fork ne s\'exécute jamais)',
      (tester) async {
        final completer = Completer<List<ZFieldChoice>>();
        await tester.pumpWidget(_host(_presentation(
          searchable: true,
          optionsLoader: (q) => completer.future,
        )));
        await tester.pumpAndSettle();
        await tester.tap(_trigger);
        await tester.pump();

        // Avant le délai : rien n'a explosé, l'attente est en cours.
        expect(tester.takeException(), isNull);

        // Après le délai : la `Future` est abandonnée, le rendu dégradé prend
        // la main. Littéral 31 s > la référence de 30 s.
        await tester.pump(const Duration(seconds: 31));
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: '🔴 le `TimeoutException` doit être rattrapé par notre '
              'enveloppe, pas remonter au framework.',
        );
        expect(completer.isCompleted, isFalse,
            reason: 'anti-vacuité : la `Future` de l\'hôte n\'a jamais rendu — '
                'c\'est bien le délai qui a débloqué la situation.');
      },
    );
  });

  // ══════════════════════════════════════════════════════════════════════════
  // 4. AD-2 / SM-1 — le chargement ne reconstruit pas le champ
  // ══════════════════════════════════════════════════════════════════════════

  group('🎯 SEAM-D — AD-2 / SM-1 : le chargement asynchrone reste CONFINÉ', () {
    testWidgets(
      '🔴 pendant tout le chargement, `onChanged` n\'est JAMAIS appelé et le '
      'déclencheur n\'est pas reconstruit : aucun rebuild de formulaire',
      (tester) async {
        final completer = Completer<List<ZFieldChoice>>();
        final List<Object?> written = <Object?>[];

        await tester.pumpWidget(_host(_presentation(
          searchable: true,
          selected: 'a',
          onChanged: written.add,
          optionsLoader: (q) => completer.future,
        )));
        await tester.pumpAndSettle();

        final Element before = tester.element(_trigger);

        await tester.tap(_trigger);
        await tester.pump();
        completer.complete(const <ZFieldChoice>[
          ZFieldChoice(value: 'z', label: 'Zoulou'),
        ]);
        await tester.pumpAndSettle();

        expect(
          written,
          isEmpty,
          reason: '🔴 charger des options n\'est PAS choisir : une écriture '
              'dans la tranche ferait rebâtir le formulaire pour un événement '
              'qui n\'appartient qu\'au modal (objectif produit n°1).',
        );
        // Le `ListTile` du déclencheur est le MÊME élément : il n'a été ni
        // remplacé ni recréé par le cycle de chargement.
        expect(identical(tester.element(_trigger), before), isTrue);
      },
    );
  });

  // ══════════════════════════════════════════════════════════════════════════
  // 5. Chaîne paramètre > jeton > référence
  // ══════════════════════════════════════════════════════════════════════════

  group('🎯 SEAM-E — chaîne `paramètre > jeton > référence`', () {
    /// Rayon effectif du `Card` du déclencheur.
    double _radiusOf(WidgetTester tester) {
      final Card card = tester.widget<Card>(find.byType(Card).first);
      final shape = card.shape! as RoundedRectangleBorder;
      return (shape.borderRadius.resolve(TextDirection.ltr).topLeft).x;
    }

    BorderSide _sideOf(WidgetTester tester) {
      final Card card = tester.widget<Card>(find.byType(Card).first);
      return (card.shape! as RoundedRectangleBorder).side;
    }

    testWidgets(
      'sans jeton ni paramètre ⇒ la RÉFÉRENCE (littéraux DODLP : rayon 12, '
      'bordure 1) — hôte passif immobile',
      (tester) async {
        await tester.pumpWidget(_host(_presentation()));
        await tester.pumpAndSettle();
        expect(_radiusOf(tester), 12);
        expect(_sideOf(tester).width, 1);
      },
    );

    testWidgets(
      '🔴 le JETON supplante la référence (rayon 12 → 28, bordure 1 → 5)',
      (tester) async {
        // Anti-vacuité : la valeur du jeton DIFFÈRE de la référence.
        expect(28, isNot(12));
        expect(5, isNot(1));
        await tester.pumpWidget(_host(
          _presentation(),
          token: const ZcrudTheme(
            selectTileRadius: 28,
            selectTileBorderWidth: 5,
          ),
        ));
        await tester.pumpAndSettle();
        expect(_radiusOf(tester), 28);
        expect(_sideOf(tester).width, 5);
      },
    );

    testWidgets(
      '🔴 le PARAMÈTRE supplante le jeton — priorité prouvée dans les DEUX '
      'sens (le jeton bat la référence, le paramètre bat le jeton)',
      (tester) async {
        await tester.pumpWidget(_host(
          _presentation(),
          token: const ZcrudTheme(selectTileRadius: 28),
          spec: const ZSelectTileSpec(cardRadius: 40),
        ));
        await tester.pumpAndSettle();
        expect(_radiusOf(tester), 40);
        // Anti-vacuité : les trois maillons portent trois valeurs DISTINCTES,
        // donc la garde discrimine réellement lequel a gagné.
        expect(<double>{40, 28, 12}, hasLength(3));
      },
    );

    testWidgets(
      '🔴 la COULEUR de bordure : jeton > rôle `outlineVariant` ; sans jeton, '
      'la teinte SUIT le thème (FR-26)',
      (tester) async {
        final ThemeData theme = ThemeData(
          colorScheme: const ColorScheme.light(outlineVariant: Color(0xFF123456)),
        );
        // Sans jeton : la bordure vaut le RÔLE.
        await tester.pumpWidget(_host(_presentation(), theme: theme));
        await tester.pumpAndSettle();
        expect(_sideOf(tester).color, const Color(0xFF123456));

        // Avec jeton : le jeton gagne. Anti-vacuité : il DIFFÈRE du rôle.
        expect(const Color(0xFFABCDEF), isNot(const Color(0xFF123456)));
        await tester.pumpWidget(_host(
          _presentation(),
          theme: theme,
          token: const ZcrudTheme(selectTileBorderColor: Color(0xFFABCDEF)),
        ));
        await tester.pumpAndSettle();
        expect(_sideOf(tester).color, const Color(0xFFABCDEF));
      },
    );

    testWidgets(
      '🔴 AD-13 : le plancher de 48 dp n\'est PAS abaissable par le JETON '
      '(nouveau chemin) — on mesure la CONTRAINTE, pas la taille rendue',
      (tester) async {
        await tester.pumpWidget(_host(
          _presentation(),
          token: const ZcrudTheme(selectTileMinHeight: 12),
        ));
        await tester.pumpAndSettle();
        final ConstrainedBox box = tester.widget<ConstrainedBox>(
          find
              .descendant(
                of: find.byType(Card),
                matching: find.byType(ConstrainedBox),
              )
              .first,
        );
        expect(
          box.constraints.minHeight,
          48,
          reason: '🔴 un jeton d\'app à 12 dp abaisserait la cible tactile de '
              'TOUS les sélecteurs sous le plancher AD-13.',
        );
        // Anti-vacuité : la valeur posée au jeton était bien SOUS le plancher.
        expect(12, lessThan(48));
      },
    );

    testWidgets('le jeton PEUT rehausser le plancher (48 → 72)',
        (tester) async {
      await tester.pumpWidget(_host(
        _presentation(),
        token: const ZcrudTheme(selectTileMinHeight: 72),
      ));
      await tester.pumpAndSettle();
      final ConstrainedBox box = tester.widget<ConstrainedBox>(
        find
            .descendant(
              of: find.byType(Card),
              matching: find.byType(ConstrainedBox),
            )
            .first,
      );
      expect(box.constraints.minHeight, 72);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // 6. Conversion TOTALE des paliers nommés (AD-10)
  // ══════════════════════════════════════════════════════════════════════════

  group('🎯 SEAM-F — conversion de palier TOTALE (AD-10)', () {
    test('un nom CONNU est converti', () {
      expect(zSelectChoiceStyleFromToken('chips'), ZSelectChoiceStyle.chips);
      expect(zSelectChoiceStyleFromToken('switches'),
          ZSelectChoiceStyle.switches);
      expect(zSelectModalShapeFromToken('fullPage'), ZSelectModalShape.fullPage);
    });

    test(
      '🔴 un nom INCONNU rend `null` SANS LEVER — un thème sérialisé depuis une '
      'version plus récente du socle ne doit pas casser le rendu',
      () {
        expect(zSelectChoiceStyleFromToken('carrousel-3d'), isNull);
        expect(zSelectModalShapeFromToken('hologramme'), isNull);
        expect(zSelectChoiceStyleFromToken(null), isNull);
        expect(zSelectModalShapeFromToken(null), isNull);
        // Anti-vacuité : la fonction SAIT convertir, elle ne rend pas `null`
        // pour tout.
        expect(zSelectChoiceStyleFromToken('radios'), isNotNull);
      },
    );

    testWidgets(
      '🔴 un jeton de palier INCONNU retombe sur la RÉFÉRENCE, sans exception '
      '— et un jeton CONNU change bien le rendu (anti-vacuité)',
      (tester) async {
        // Inconnu ⇒ référence mono = `radios` (littéral DODLP).
        await tester.pumpWidget(_host(
          _presentation(),
          token: const ZcrudTheme(selectMonoChoiceStyle: 'carrousel-3d'),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          tester.widget<SmartSelect<dynamic>>(
            find.byType(SmartSelect<dynamic>),
          ).choiceConfig.type,
          S2ChoiceType.radios,
        );

        // Connu ⇒ le jeton gagne.
        await tester.pumpWidget(_host(
          _presentation(),
          token: const ZcrudTheme(selectMonoChoiceStyle: 'chips'),
        ));
        await tester.pumpAndSettle();
        expect(
          tester.widget<SmartSelect<dynamic>>(
            find.byType(SmartSelect<dynamic>),
          ).choiceConfig.type,
          S2ChoiceType.chips,
        );
      },
    );
  });

  // ══════════════════════════════════════════════════════════════════════════
  // 7. `zSelectTileMetricsOf` — le porte-valeurs résolu, hors arbre de rendu
  // ══════════════════════════════════════════════════════════════════════════

  group('🎯 SEAM-G — `zSelectTileMetricsOf` exposé et cohérent', () {
    testWidgets('résout la chaîne complète et ne lève jamais', (tester) async {
      late ZSelectTileMetrics m;
      await tester.pumpWidget(MaterialApp(
        home: ZcrudScope(
          theme: const ZcrudTheme(
            selectDialogBreakpoint: 1234,
            selectModalShape: 'popupDialog',
          ),
          child: Builder(builder: (ctx) {
            m = zSelectTileMetricsOf(ctx);
            return const SizedBox.shrink();
          }),
        ),
      ));
      expect(m.dialogBreakpoint, 1234);
      expect(m.modalShape, ZSelectModalShape.popupDialog);
      // Les propriétés SANS jeton retombent sur la référence (littéraux DODLP).
      expect(m.chipSpacing, 6);
      expect(m.chipRunSpacing, 4);
      expect(m.chipFontSize, 12);
      expect(m.elevation, 0);
      expect(m.choicePageLimit, 20);
      // Anti-vacuité : la valeur du jeton DIFFÈRE de la référence (600).
      expect(1234, isNot(600));
    });

    testWidgets(
      '🔴 AD-13 : le plancher est CLAMPÉ DANS LES MÉTRIQUES elles-mêmes, pas '
      'seulement au rendu',
      (tester) async {
        // 🔴 Pourquoi cette garde EXISTE (leçon R3 de ce lot, injection I17) :
        // le déclencheur applique DÉJÀ un `math.max(48, …)` local. Une garde qui
        // ne mesure que la `ConstrainedBox` rendue reste donc VERTE même si le
        // clamp disparaît d'ici — chacun des deux clamps masque l'autre. Or
        // `zSelectTileMetricsOf` est PUBLIC : un hôte qui lit `minHeight` pour
        // dimensionner autre chose obtiendrait la valeur non clampée.
        late ZSelectTileMetrics sousPlancher;
        late ZSelectTileMetrics auDessus;
        await tester.pumpWidget(MaterialApp(
          home: ZcrudScope(
            theme: const ZcrudTheme(selectTileMinHeight: 12),
            child: Builder(builder: (ctx) {
              sousPlancher = zSelectTileMetricsOf(ctx);
              auDessus = zSelectTileMetricsOf(
                ctx,
                spec: const ZSelectTileSpec(minTileHeight: 96),
              );
              return const SizedBox.shrink();
            }),
          ),
        ));
        expect(
          sousPlancher.minHeight,
          48,
          reason: '🔴 un jeton à 12 dp a traversé la résolution : la valeur '
              'publiée aux hôtes est sous le plancher AD-13.',
        );
        // Anti-vacuité : la valeur demandée était bien SOUS le plancher, et la
        // résolution SAIT rehausser (elle ne rend pas 48 pour tout).
        expect(12, lessThan(48));
        expect(auDessus.minHeight, 96);
      },
    );
  });

  // ══════════════════════════════════════════════════════════════════════════
  // 8. Barre d'ACTIONS du modal + champ de recherche PERMANENT en multi
  // ══════════════════════════════════════════════════════════════════════════

  group('🎯 SEAM-H — barre d\'actions du modal (parité `_modalActionsBuilder`)',
      () {
    /// Ouvre le modal et rend la main une fois l'en-tête posé.
    Future<void> _openModal(WidgetTester tester) async {
      await tester.pumpAndSettle();
      await tester.tap(_trigger);
      await tester.pumpAndSettle();
    }

    // 🔴 Un test par montage : le modal du fork est une ROUTE. Rouvrir dans le
    // même `testWidgets` après un second `pumpWidget` taperait sur la barrière
    // de la première boîte de dialogue, restée empilée — la garde mesurerait
    // alors l'état d'AVANT (piège rencontré en écrivant ce lot).

    testWidgets(
      '🔴 MONO éditable SANS valeur : CONFIRMER et RECHERCHER présents, '
      'RÉINITIALISER ABSENT (action morte)',
      (tester) async {
        await tester.pumpWidget(_host(_presentation(searchable: true)));
        await _openModal(tester);
        expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
        expect(find.byIcon(Icons.search), findsOneWidget);
        expect(
          find.byIcon(Icons.block),
          findsNothing,
          reason: '🔴 proposer « réinitialiser » quand il n\'y a RIEN à '
              'réinitialiser est une action morte (parité DODLP : '
              '`state.selection?.choice != null`).',
        );
      },
    );

    testWidgets(
      '🔴 MONO éditable AVEC valeur : RÉINITIALISER apparaît',
      (tester) async {
        await tester.pumpWidget(
          _host(_presentation(searchable: true, selected: 'a')),
        );
        await _openModal(tester);
        expect(find.byIcon(Icons.block), findsOneWidget);
      },
    );

    testWidgets(
      '🔴 chaque action porte un TOOLTIP LOCALISÉ — les `IconButton` de DODLP '
      'n\'en ont aucun (un lecteur d\'écran annonce « bouton », sans plus)',
      (tester) async {
        await tester.pumpWidget(_host(_presentation(selected: 'a')));
        await _openModal(tester);
        // Littéraux de la table `en` du cœur (aucune locale injectée ici).
        expect(find.byTooltip('Confirm'), findsOneWidget);
        expect(find.byTooltip('Reset'), findsOneWidget);
      },
    );

    testWidgets(
      '🔴 RÉINITIALISER écrit `null` (mono) / la liste VIDE (multi) dans la '
      'tranche — jamais un `setState` de formulaire (AD-2/SM-1)',
      (tester) async {
        final List<Object?> written = <Object?>[];
        await tester.pumpWidget(_host(_presentation(
          selected: 'a',
          onChanged: written.add,
        )));
        await _openModal(tester);
        await tester.tap(find.byIcon(Icons.block));
        await tester.pumpAndSettle();
        expect(written, <Object?>[null]);

      },
    );

    testWidgets(
      '🔴 RÉINITIALISER en MULTI écrit la LISTE VIDE, jamais `null`',
      (tester) async {
        final List<Object?> written = <Object?>[];
        await tester.pumpWidget(_host(_presentation(
          multiple: true,
          selected: const <Object?>['a'],
          onChanged: written.add,
        )));
        await _openModal(tester);
        await tester.tap(find.byIcon(Icons.block));
        await tester.pumpAndSettle();
        expect(written, hasLength(1));
        expect(
          written.single,
          isEmpty,
          reason: '🔴 en multi la remise à zéro est une LISTE VIDE, jamais '
              '`null` (le type de la tranche ne doit pas changer).',
        );
      },
    );

    testWidgets(
      'LECTURE SEULE : aucune action d\'écriture (ni confirmer, ni '
      'réinitialiser) — seule la recherche subsiste',
      (tester) async {
        // 🔴 En lecture seule le déclencheur est INERTE : le seul chemin
        // d'ouverture du modal est celui de DODLP — un `choiceBuilder`, qui
        // ré-active le tap. C'est donc aussi ce cas-là qu'on mesure.
        await tester.pumpWidget(_host(_presentation(
          readOnly: true,
          selected: 'a',
          searchable: true,
          choiceBuilder: (c, ctx) => Text('opt:${ctx.choice.label}'),
        )));
        await _openModal(tester);
        expect(find.byIcon(Icons.check_circle_outline), findsNothing);
        expect(find.byIcon(Icons.block), findsNothing);
        // Anti-vacuité : le modal EST bien ouvert (la loupe y est, et le
        // builder de l'hôte a rendu ses options).
        expect(find.byIcon(Icons.search), findsOneWidget);
        expect(find.text('opt:Alpha'), findsOneWidget);
      },
    );

    testWidgets(
      '🔴 `showModalActions: false` rend la main au fork : plus de barre DODLP',
      (tester) async {
        await tester.pumpWidget(_host(
          _presentation(selected: 'a'),
          spec: const ZSelectTileSpec(showModalActions: false),
        ));
        await _openModal(tester);
        expect(find.byIcon(Icons.block), findsNothing);
      },
    );

    testWidgets(
      '🔴 MULTI searchable : le champ de RECHERCHE est rendu SOUS la barre et '
      'AVANT les options — pas une bascule (parité `_modalBuilder` DODLP)',
      (tester) async {
        await tester.pumpWidget(
          _host(_presentation(multiple: true, searchable: true)),
        );
        await _openModal(tester);

        final Finder field = find.byType(TextField);
        expect(
          field,
          findsOneWidget,
          reason: '🔴 en multi la recherche doit être IMMÉDIATEMENT visible : '
              'DODLP force son ouverture depuis `onModalOpen`.',
        );
        // Le titre du champ reste lisible — c'est ce que le mécanisme de DODLP
        // perdait (le filtre du fork REMPLACE le titre par la saisie).
        expect(find.text('Mon champ'), findsWidgets);
        // La loupe de bascule a disparu : elle n'aurait plus rien à basculer.
        expect(find.byIcon(Icons.search), findsOneWidget,
            reason: 'l\'icône restante est le `prefixIcon` du champ, pas une '
                'bascule.');
        expect(
          tester.widget<TextField>(field).decoration!.prefixIcon,
          isNotNull,
        );
        // 🔴 Le champ est AU-DESSUS de la liste d'options.
        expect(
          tester.getTopLeft(field).dy,
          lessThan(tester.getTopLeft(find.text('Alpha').first).dy),
        );
      },
    );

    testWidgets(
      '🔴 `choiceDivider` suit la règle EXACTE de DODLP '
      '(`field.choiceBuilder != null`) — et vaut donc FAUX pour un hôte passif',
      (tester) async {
        // Sans builder : `false`, qui est AUSSI le défaut du fork
        // (`S2ChoiceConfig.useDivider`) — l'hôte passif ne bouge pas.
        // 🔴 Les DEUX branches : `SmartSelect.single` et `.multiple` sont deux
        // sites d'appel distincts — une garde qui n'en mesure qu'un laisse
        // l'autre libre de dériver (mesuré : l'injection R3 sur la branche
        // multi restait VERTE tant que seule la branche mono était gardée).
        for (final bool multi in <bool>[false, true]) {
          // 🔴 Démontage explicite entre deux itérations : basculer `multiple`
          // sur le MÊME élément ferait réutiliser un `S2SingleState` pour un
          // `SmartSelect.multiple` et lèverait dans le fork. Ce n'est pas un
          // scénario réel (le dispatcher clé ses champs) — c'est un artefact du
          // test, qu'on neutralise au lieu de le maquiller.
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpWidget(_host(_presentation(multiple: multi)));
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<SmartSelect<dynamic>>(find.byType(SmartSelect<dynamic>))
                .choiceConfig
                .useDivider,
            isFalse,
            reason: '🔴 poser un séparateur sur le rendu NATIF des options du '
                'fork change le modal de tout hôte déjà en production '
                '(multiple=$multi).',
          );
        }
      },
    );

    testWidgets(
      'avec un `choiceBuilder`, le séparateur apparaît (anti-vacuité de la '
      'garde ci-dessus : la propriété N\'est pas constante)',
      (tester) async {
        for (final bool multi in <bool>[false, true]) {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpWidget(_host(_presentation(
            multiple: multi,
            choiceBuilder: (c, ctx) => Text('opt:${ctx.choice.label}'),
          )));
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<SmartSelect<dynamic>>(find.byType(SmartSelect<dynamic>))
                .choiceConfig
                .useDivider,
            isTrue,
            reason: 'multiple=$multi',
          );
        }
      },
    );

    testWidgets(
      'MONO searchable : la recherche reste une BASCULE (loupe), comme DODLP '
      '— anti-vacuité de la garde multi ci-dessus',
      (tester) async {
        await tester.pumpWidget(_host(_presentation(searchable: true)));
        await _openModal(tester);
        expect(
          find.byType(TextField),
          findsNothing,
          reason: '🔴 en mono, DODLP n\'affiche PAS le champ d\'emblée : '
              '`useFilter: true` pose une loupe.',
        );
        expect(find.byIcon(Icons.search), findsOneWidget);
      },
    );
  });
}
