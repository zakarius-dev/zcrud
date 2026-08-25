/// 🎯 CR-SELECT-GAPS (2026-08-09) — gardes des capacités que le DTO PORTAIT et
/// que le présentateur NE LISAIT PAS.
///
/// Classe de défaut visée (troisième occurrence en 24 h) : `crudHandler`, puis
/// l'indicateur « requis », puis ces cinq-ci. Le motif est constant — enrôler
/// `ZSmartSelectPresenter` **retirait** une capacité que le rendu natif offrait.
///
/// Cinq familles, chacune prouvée **dans les deux sens** (la donnée est là ⇒ le
/// rendu la porte ; la donnée est absente ⇒ le rendu est EXACTEMENT l'antérieur)
/// et **sur les deux branches** (`.single` ET `.multiple`, deux sites d'appel
/// distincts de `present()`) :
///
/// 1. **`field.hintText`** — texte de l'état vide (`InputDecoration.hintText`) ;
/// 2. **`field.helperText`** — ligne d'aide persistante, en SUS du sous-titre ;
/// 3. **`field.prefix` / `field.suffix`** — ornements internes, autour du contenu ;
/// 4. **`isLoading`** — reçu par le DTO et jamais AFFICHÉ (visuel + a11y) ;
/// 5. **`crudHandler.edit` / `.copy`** — que le natif de `relation` expose par
///    option (`_CrudRowActions`, DP-15) et que le présentateur perdait.
///
/// 🔴 **Anti-vacuité** : une garde de canal optionnel qui passerait aussi quand
/// le canal est absent ne mesure rien. Chaque propriété est donc affirmée
/// PRÉSENTE avec la donnée et ABSENTE sans elle.
///
/// 🔴 **Anti-tautologie** : les attentes portent sur des littéraux posés par le
/// test (`'Indice du champ'`, `'€'`) ou sur les libellés l10n **anglais** du
/// cœur (`'Select'`, `'Loading…'`), jamais sur la constante qui produit le rendu.
@TestOn('vm')
library;

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

/// Handler CRUD **espion** : enregistre les appels et rend l'option programmée.
class _SpyCrud extends ZRelationCrudHandler {
  _SpyCrud({this.result, this.throws = false});

  final ZFieldChoice? result;
  final bool throws;

  final List<String> calls = <String>[];

  @override
  Future<ZFieldChoice?> create(Map<String, Object?> context) async {
    calls.add('create');
    if (throws) throw StateError('boom');
    return result;
  }

  @override
  Future<ZFieldChoice?> edit(Object? value) async {
    calls.add('edit:$value');
    if (throws) throw StateError('boom');
    return result;
  }

  @override
  Future<ZFieldChoice?> copy(Object? value) async {
    calls.add('copy:$value');
    if (throws) throw StateError('boom');
    return result;
  }
}

ZSelectPresentation _presentation({
  bool multiple = false,
  bool readOnly = false,
  bool isLoading = false,
  Object? selected,
  String? hintText,
  String? helperText,
  ZFieldAdornment? prefix,
  ZFieldAdornment? suffix,
  ZRelationCrudHandler? crudHandler,
  ZSelectChoiceSecondaryBuilder? choiceSecondaryBuilder,
  ValueChanged<Object?>? onChanged,
}) =>
    ZSelectPresentation(
      field: ZFieldSpec(
        name: 'f',
        type: EditionFieldType.select,
        label: 'Mon champ',
        choices: _abc,
        readOnly: readOnly,
        hintText: hintText,
        helperText: helperText,
        prefix: prefix,
        suffix: suffix,
      ),
      options: _abc,
      selected: selected,
      onChanged: onChanged ?? (_) {},
      multiple: multiple,
      searchable: false,
      readOnly: readOnly,
      isLoading: isLoading,
      label: 'Mon champ',
      crudHandler: crudHandler,
      choiceSecondaryBuilder: choiceSecondaryBuilder,
    );

Widget _host(ZSelectPresentation p) {
  const presenter = ZSmartSelectPresenter();
  return MaterialApp(
    home: ZcrudScope(
      child: Scaffold(
        body: Builder(builder: (ctx) => presenter.present(ctx, p)),
      ),
    ),
  );
}

/// Le `ListTile` du déclencheur (celui que porte le `Card` du présentateur).
///
/// 🔴 Ancré sur la `Card` : sans cela le finder mordrait aussi les tuiles
/// d'OPTIONS du modal, qui restent montées derrière lui (piège rencontré).
final Finder _trigger = find.descendant(
  of: find.byType(Card),
  matching: find.byType(ListTile),
);

ListTile _tile(WidgetTester tester) => tester.widget<ListTile>(_trigger);

/// Étiquettes du résumé multi : les conteneurs peints DANS le `Wrap` du
/// sous-titre. La référence rend une étiquette compacte, pas un `Chip`
/// Material (dont le plancher de cible tactile imposerait 48 dp par valeur).
final Finder _summaryChips = find.descendant(
  of: find.descendant(of: _trigger, matching: find.byType(Wrap)),
  matching: find.byType(Container),
);

/// Tous les `Text` du sous-titre du tile, dans l'ordre de l'arbre.
List<String> _subtitleTexts(WidgetTester tester) => tester
    .widgetList<Text>(
      find.descendant(
        of: find.byWidget(_tile(tester).subtitle!),
        matching: find.byType(Text),
        matchRoot: true,
      ),
    )
    .map((t) => t.data ?? '')
    .toList(growable: false);

/// Le builder `secondary` réellement POSÉ par le présentateur, lu sur le widget.
///
/// 🔴 Sonde de CÂBLAGE, délibérément indépendante de l'ouverture du modal : une
/// garde qui passerait par un `tap` serait VACANTE dès que le tile est inerte
/// (lecture seule, chargement) — le modal ne s'ouvrirait pas et le `findsNothing`
/// serait vrai pour la mauvaise raison.
Object? _secondarySlot(WidgetTester tester, {required bool multiple}) {
  final w = tester.widget<SmartSelect<dynamic>>(find.byType(SmartSelect));
  return multiple ? w.multiBuilder?.choiceSecondary : w.singleBuilder?.choiceSecondary;
}

SemanticsData _semantics(WidgetTester tester) =>
    tester.getSemantics(find.bySemanticsLabel('Mon champ')).getSemanticsData();

void main() {
  // ══════════════════════════════════════════════════════════════════════════
  // 1. `field.hintText` — le texte de l'ÉTAT VIDE
  // ══════════════════════════════════════════════════════════════════════════

  group('🎯 GAPS-A — `field.hintText` (placeholder du tile)', () {
    for (final multiple in <bool>[false, true]) {
      final branch = multiple ? '.multiple' : '.single';

      testWidgets(
        '$branch — SANS `hintText`, le placeholder reste la clé l10n `select` '
        '(hôte passif immobile)',
        (tester) async {
          await tester.pumpWidget(_host(_presentation(multiple: multiple)));
          await tester.pumpAndSettle();
          expect(_subtitleTexts(tester), <String>['Select']);
        },
      );

      testWidgets(
        '$branch — AVEC `hintText`, c\'est LUI qui s\'affiche, et la clé '
        'générique disparaît',
        (tester) async {
          await tester.pumpWidget(_host(_presentation(
            multiple: multiple,
            hintText: 'Indice du champ',
          )));
          await tester.pumpAndSettle();
          expect(
            _subtitleTexts(tester),
            <String>['Indice du champ'],
            reason: '🔴 le natif rend `field.hintText` dans '
                '`InputDecoration.hintText` : afficher « Select » à la place '
                'PERD l\'information dès que le champ déclare un indice.',
          );
        },
      );
    }

    testWidgets(
      'une valeur sélectionnée l\'emporte sur le `hintText` — un indice n\'est '
      'pas une valeur',
      (tester) async {
        await tester.pumpWidget(_host(_presentation(
          selected: 'a',
          hintText: 'Indice du champ',
        )));
        await tester.pumpAndSettle();
        expect(_subtitleTexts(tester), <String>['Alpha']);
      },
    );
  });

  // ══════════════════════════════════════════════════════════════════════════
  // 2. `isLoading` — REÇU par le DTO, jamais AFFICHÉ
  // ══════════════════════════════════════════════════════════════════════════

  group('🎯 GAPS-B — `isLoading` affiché et ANNONCÉ', () {
    for (final multiple in <bool>[false, true]) {
      final branch = multiple ? '.multiple' : '.single';

      testWidgets(
        '$branch — en chargement, le tile dit « Loading… » ; hors chargement il '
        'dit « Select » (anti-vacuité)',
        (tester) async {
          await tester.pumpWidget(_host(_presentation(
            multiple: multiple,
            isLoading: true,
          )));
          await tester.pumpAndSettle();
          expect(
            _subtitleTexts(tester),
            <String>['Loading…'],
            reason: '🔴 « je n\'ai pas encore les options » et « il n\'y a rien '
                'à choisir » ne doivent pas se lire pareil.',
          );

          await tester.pumpWidget(_host(_presentation(multiple: multiple)));
          await tester.pumpAndSettle();
          expect(_subtitleTexts(tester), <String>['Select']);
        },
      );
    }

    testWidgets(
      '🔴 AD-13 — le chargement a un canal NON VISUEL : il est annoncé comme '
      'valeur du nœud ; l\'état vide, lui, reste silencieux',
      (tester) async {
        await tester.pumpWidget(_host(_presentation(isLoading: true)));
        await tester.pumpAndSettle();
        expect(_semantics(tester).value, 'Loading…');

        // Anti-vacuité : sans chargement, l'état vide N'EST PAS annoncé.
        await tester.pumpWidget(_host(_presentation()));
        await tester.pumpAndSettle();
        expect(_semantics(tester).value, isEmpty);
      },
    );

    testWidgets(
      'le chargement l\'emporte sur le `hintText` — parité EXACTE du natif '
      '`relation` (`hintText: label(loading ? \'loading\' : \'select\')`)',
      (tester) async {
        await tester.pumpWidget(_host(_presentation(
          isLoading: true,
          hintText: 'Indice du champ',
        )));
        await tester.pumpAndSettle();
        expect(_subtitleTexts(tester), <String>['Loading…']);
      },
    );
  });

  // ══════════════════════════════════════════════════════════════════════════
  // 3. `field.helperText` — EN SUS du sous-titre, jamais À SA PLACE
  // ══════════════════════════════════════════════════════════════════════════

  group('🎯 GAPS-C — `field.helperText` (ligne d\'aide persistante)', () {
    testWidgets(
      'SANS aide, le sous-titre est le widget ANTÉRIEUR — aucune `Column` '
      'intercalée (AD-4)',
      (tester) async {
        await tester.pumpWidget(_host(_presentation(selected: 'a')));
        await tester.pumpAndSettle();
        expect(_tile(tester).subtitle, isA<Text>());
        expect(_semantics(tester).hint, isEmpty);
      },
    );

    testWidgets(
      '🔴 AVEC aide, la VALEUR reste rendue et l\'aide s\'ajoute EN DESSOUS — '
      'écraser le sous-titre aurait été une régression déguisée en correctif',
      (tester) async {
        await tester.pumpWidget(_host(_presentation(
          selected: 'a',
          helperText: 'Aide du champ',
        )));
        await tester.pumpAndSettle();
        expect(
          _subtitleTexts(tester),
          <String>['Alpha', 'Aide du champ'],
          reason: '🔴 l\'ordre compte : la valeur d\'abord, l\'aide ensuite — '
              'c\'est la place que Material donne au `helperText`.',
        );
      },
    );

    testWidgets(
      '🔴 `.multiple` — les PUCES restent rendues, l\'aide s\'ajoute sous elles',
      (tester) async {
        await tester.pumpWidget(_host(_presentation(
          multiple: true,
          selected: const <Object?>['a', 'b'],
          helperText: 'Aide du champ',
        )));
        await tester.pumpAndSettle();
        expect(_subtitleTexts(tester), <String>['Alpha', 'Bravo', 'Aide du champ']);
        expect(_summaryChips, findsNWidgets(2));
      },
    );

    testWidgets(
      '🔴 AD-13 — l\'aide est ANNONCÉE (`Semantics.hint`) : sous '
      '`excludeSemantics`, elle serait vue et jamais entendue',
      (tester) async {
        await tester.pumpWidget(_host(_presentation(
          selected: 'a',
          helperText: 'Aide du champ',
        )));
        await tester.pumpAndSettle();
        expect(_semantics(tester).hint, 'Aide du champ');
      },
    );
  });

  // ══════════════════════════════════════════════════════════════════════════
  // 4. `field.prefix` / `field.suffix` — ornements INTERNES
  // ══════════════════════════════════════════════════════════════════════════

  group('🎯 GAPS-D — ornements `prefix` / `suffix`', () {
    testWidgets(
      'SANS ornement, aucune `Row` n\'est intercalée dans le sous-titre (AD-4)',
      (tester) async {
        await tester.pumpWidget(_host(_presentation(selected: 'a')));
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byWidget(_tile(tester).subtitle!),
            matching: find.byType(Row),
            matchRoot: true,
          ),
          findsNothing,
        );
      },
    );

    testWidgets(
      '🔴 un `prefix` `.text` est RENDU avant la valeur et REPRIS dans '
      'l\'annonce — sinon « € » serait vu et jamais lu (AD-13)',
      (tester) async {
        await tester.pumpWidget(_host(_presentation(
          selected: 'a',
          prefix: const ZFieldAdornment.text('€'),
        )));
        await tester.pumpAndSettle();
        expect(_subtitleTexts(tester), <String>['€', 'Alpha']);
        expect(_semantics(tester).value, '€ Alpha');

        // Anti-vacuité : sans ornement, l'annonce est la valeur NUE.
        await tester.pumpWidget(_host(_presentation(selected: 'a')));
        await tester.pumpAndSettle();
        expect(_semantics(tester).value, 'Alpha');
      },
    );

    testWidgets(
      'un `suffix` `.text` est rendu APRÈS la valeur et repris en fin '
      'd\'annonce',
      (tester) async {
        await tester.pumpWidget(_host(_presentation(
          selected: 'a',
          suffix: const ZFieldAdornment.text('kg'),
        )));
        await tester.pumpAndSettle();
        expect(_subtitleTexts(tester), <String>['Alpha', 'kg']);
        expect(_semantics(tester).value, 'Alpha kg');
      },
    );

    testWidgets(
      'un ornement `.icon` est rendu mais reste DÉCORATIF — il n\'a pas de '
      'texte à annoncer, exactement comme dans le natif',
      (tester) async {
        await tester.pumpWidget(_host(_presentation(
          selected: 'a',
          suffix: const ZFieldAdornment.icon('money'),
        )));
        await tester.pumpAndSettle();
        expect(
          find.descendant(of: _trigger, matching: find.byIcon(Icons.attach_money)),
          findsOneWidget,
        );
        expect(_semantics(tester).value, 'Alpha');
      },
    );

    testWidgets(
      '🔴 AD-13 — les écarts d\'ornement sont DIRECTIONNELS (RTL)',
      (tester) async {
        await tester.pumpWidget(_host(_presentation(
          selected: 'a',
          prefix: const ZFieldAdornment.text('€'),
          suffix: const ZFieldAdornment.text('kg'),
        )));
        await tester.pumpAndSettle();
        final paddings = tester.widgetList<Padding>(
          find.descendant(
            of: find.byWidget(_tile(tester).subtitle!),
            matching: find.byType(Padding),
            matchRoot: true,
          ),
        );
        expect(paddings, isNotEmpty);
        for (final p in paddings) {
          expect(
            p.padding,
            isA<EdgeInsetsDirectional>(),
            reason: '🔴 un `EdgeInsets.only(left:/right:)` inverserait '
                'l\'ornement en RTL.',
          );
        }
      },
    );

    testWidgets(
      '`.multiple` — les ornements encadrent aussi les PUCES',
      (tester) async {
        await tester.pumpWidget(_host(_presentation(
          multiple: true,
          selected: const <Object?>['a'],
          prefix: const ZFieldAdornment.text('€'),
        )));
        await tester.pumpAndSettle();
        expect(_subtitleTexts(tester), <String>['€', 'Alpha']);
        expect(_semantics(tester).value, '€ Alpha');
      },
    );

    testWidgets(
      'ornement `.icon` de clé INCONNUE ⇒ slot omis, aucune exception (AD-10)',
      (tester) async {
        await tester.pumpWidget(_host(_presentation(
          selected: 'a',
          prefix: const ZFieldAdornment.icon('licorne-arc-en-ciel'),
        )));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(_subtitleTexts(tester), <String>['Alpha']);
      },
    );
  });

  // ══════════════════════════════════════════════════════════════════════════
  // 5. `crudHandler.edit` / `.copy` — que le natif de `relation` offre
  // ══════════════════════════════════════════════════════════════════════════

  group('🎯 GAPS-E — Modifier / Copier par option (parité `_CrudRowActions`)',
      () {
    Future<void> openModal(WidgetTester tester) async {
      await tester.tap(_trigger);
      await tester.pumpAndSettle();
    }

    for (final multiple in <bool>[false, true]) {
      final branch = multiple ? '.multiple' : '.single';

      testWidgets(
        '$branch — SANS `crudHandler`, aucune action par option '
        '(anti-vacuité + hôte passif)',
        (tester) async {
          await tester.pumpWidget(_host(_presentation(multiple: multiple)));
          await tester.pumpAndSettle();
          await openModal(tester);
          expect(find.byTooltip('Edit'), findsNothing);
          expect(find.byTooltip('Copy'), findsNothing);
        },
      );

      testWidgets(
        '🔴 $branch — AVEC `crudHandler`, CHAQUE option porte Modifier ET '
        'Copier — le natif de `relation` les offre, l\'enrôlement les perdait',
        (tester) async {
          await tester.pumpWidget(_host(_presentation(
            multiple: multiple,
            crudHandler: _SpyCrud(),
          )));
          await tester.pumpAndSettle();
          await openModal(tester);
          expect(find.byTooltip('Edit'), findsNWidgets(_abc.length));
          expect(find.byTooltip('Copy'), findsNWidgets(_abc.length));
        },
      );
    }

    testWidgets(
      '🔴 Modifier appelle `handler.edit(valeurDeLOption)` puis '
      'AUTO-SÉLECTIONNE le résultat (parité `_selectResult`)',
      (tester) async {
        final spy = _SpyCrud(
          result: const ZFieldChoice(value: 'z', label: 'Zoulou'),
        );
        final written = <Object?>[];
        await tester.pumpWidget(_host(_presentation(
          crudHandler: spy,
          onChanged: written.add,
        )));
        await tester.pumpAndSettle();
        await openModal(tester);
        // 🔴 Présence AFFIRMÉE d'abord : sans cela, un `.first` sur un finder
        // vide rougirait par `StateError` et non par assertion.
        expect(find.byTooltip('Edit'), findsWidgets);
        await tester.tap(find.byTooltip('Edit').first);
        await tester.pumpAndSettle();

        expect(spy.calls, <String>['edit:a']);
        expect(written, <Object?>['z']);
      },
    );

    testWidgets(
      'Copier appelle `handler.copy(valeurDeLOption)` et AJOUTE le résultat en '
      'multi (jamais un remplacement)',
      (tester) async {
        final spy = _SpyCrud(
          result: const ZFieldChoice(value: 'z', label: 'Zoulou'),
        );
        final written = <Object?>[];
        await tester.pumpWidget(_host(_presentation(
          multiple: true,
          selected: const <Object?>['a'],
          crudHandler: spy,
          onChanged: written.add,
        )));
        await tester.pumpAndSettle();
        await openModal(tester);
        expect(find.byTooltip('Copy'), findsWidgets);
        await tester.tap(find.byTooltip('Copy').first);
        await tester.pumpAndSettle();

        expect(spy.calls, <String>['copy:a']);
        expect(written, <Object?>[
          <Object?>['a', 'z']
        ]);
      },
    );

    testWidgets(
      '🔴 AD-10 — un handler qui LÈVE ne produit ni écriture ni exception',
      (tester) async {
        final spy = _SpyCrud(throws: true);
        final written = <Object?>[];
        await tester.pumpWidget(_host(_presentation(
          crudHandler: spy,
          onChanged: written.add,
        )));
        await tester.pumpAndSettle();
        await openModal(tester);
        // 🔴 Présence AFFIRMÉE d'abord : sans cela, un `.first` sur un finder
        // vide rougirait par `StateError` et non par assertion.
        expect(find.byTooltip('Edit'), findsWidgets);
        await tester.tap(find.byTooltip('Edit').first);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(spy.calls, <String>['edit:a']);
        expect(written, isEmpty);
      },
    );

    for (final multiple in <bool>[false, true]) {
      final branch = multiple ? '.multiple' : '.single';

      testWidgets(
        '🔴 $branch — un `choiceSecondaryBuilder` HÔTE l\'emporte : c\'est le '
        'même slot, et c\'est SA décision',
        (tester) async {
          await tester.pumpWidget(_host(_presentation(
            multiple: multiple,
            crudHandler: _SpyCrud(),
            choiceSecondaryBuilder: (ctx, c) => const Text('à-moi'),
          )));
          await tester.pumpAndSettle();
          await openModal(tester);
          expect(find.text('à-moi'), findsNWidgets(_abc.length));
          expect(find.byTooltip('Edit'), findsNothing);
        },
      );

      testWidgets(
        '🔴 $branch — champ en LECTURE SEULE ⇒ le slot d\'actions n\'est même '
        'pas CÂBLÉ (les trois — Créer, Modifier, Copier — suivent la règle)',
        (tester) async {
          await tester.pumpWidget(_host(_presentation(
            multiple: multiple,
            readOnly: true,
            selected: multiple ? const <Object?>['a'] : 'a',
            crudHandler: _SpyCrud(),
          )));
          await tester.pumpAndSettle();
          expect(
            _secondarySlot(tester, multiple: multiple),
            isNull,
            reason: '🔴 mesuré sur le CÂBLAGE, pas sur le rendu du modal : en '
                'lecture seule le tile est inerte, donc un `tap` n\'ouvrirait '
                'rien et la garde passerait pour la mauvaise raison.',
          );

          // Anti-vacuité : le même montage ÉDITABLE câble bien le slot.
          await tester.pumpWidget(_host(_presentation(
            multiple: multiple,
            selected: multiple ? const <Object?>['a'] : 'a',
            crudHandler: _SpyCrud(),
          )));
          await tester.pumpAndSettle();
          expect(_secondarySlot(tester, multiple: multiple), isNotNull);
        },
      );
    }
  });

  // ══════════════════════════════════════════════════════════════════════════
  // 6. FR-26 — aucun libellé codé en dur sur les chemins ajoutés
  // ══════════════════════════════════════════════════════════════════════════

  testWidgets(
    '🔴 FR-26 — les libellés des chemins ajoutés viennent de la l10n INJECTÉE, '
    'pas de la table du cœur',
    (tester) async {
      const presenter = ZSmartSelectPresenter();
      await tester.pumpWidget(
        MaterialApp(
          home: ZcrudScope(
            labels: ZcrudLabels(const <String, String>{
              'loading': 'ÇA CHARGE',
              'edit': 'RETOUCHER',
              'copy': 'DUPLIQUER',
            }),
            child: Scaffold(
              body: Builder(
                builder: (ctx) => presenter.present(
                  ctx,
                  _presentation(crudHandler: _SpyCrud()),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Chargement : le tile prend le libellé de l'hôte, jamais celui du cœur.
      await tester.pumpWidget(
        MaterialApp(
          home: ZcrudScope(
            labels: ZcrudLabels(const <String, String>{'loading': 'ÇA CHARGE'}),
            child: Scaffold(
              body: Builder(
                builder: (ctx) => presenter.present(
                  ctx,
                  _presentation(isLoading: true),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(_subtitleTexts(tester), <String>['ÇA CHARGE']);
      expect(find.text('Loading…'), findsNothing);
    },
  );

  testWidgets(
    '🔴 FR-26 — les infobulles Modifier / Copier viennent de la l10n INJECTÉE '
    '(un littéral anglais passerait inaperçu des gardes de présence)',
    (tester) async {
      const presenter = ZSmartSelectPresenter();
      await tester.pumpWidget(
        MaterialApp(
          home: ZcrudScope(
            labels: ZcrudLabels(const <String, String>{
              'edit': 'RETOUCHER',
              'copy': 'DUPLIQUER',
            }),
            child: Scaffold(
              body: Builder(
                builder: (ctx) => presenter.present(
                  ctx,
                  _presentation(crudHandler: _SpyCrud()),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(_trigger);
      await tester.pumpAndSettle();

      expect(find.byTooltip('RETOUCHER'), findsNWidgets(_abc.length));
      expect(find.byTooltip('DUPLIQUER'), findsNWidgets(_abc.length));
      expect(find.byTooltip('Edit'), findsNothing);
      expect(find.byTooltip('Copy'), findsNothing);
    },
  );
}
