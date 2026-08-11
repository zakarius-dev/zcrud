/// 🔴 Gardes de l'**élargissement du seam** `ZSelectPresentation`
/// (CR-SELECT-SEAM, 2026-08-09).
///
/// Ce que ces gardes doivent tenir :
///
/// 1. **strictement ADDITIF** — une construction du DTO sans les nouveaux
///    paramètres rend exactement l'ancien contrat, et un présentateur qui ignore
///    les nouveaux champs rend **le même arbre** qu'avant ;
/// 2. **alimentation RÉELLE** — `ZRelationFieldWidget` transmet son `_isLoading`
///    (c'était le vrai trou : l'état existait, il ne franchissait pas le seam) ;
/// 3. **neutralité (AD-1/AD-40)** — le fichier du seam n'importe rien d'autre
///    que Flutter + `zcrud_core`.
///
/// 🔴 **Anti-tautologie** : les attentes portent sur des littéraux et sur des
/// **comportements observés** (ce que le présentateur espion reçoit), jamais sur
/// une constante du code sous test.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

import '../../support/z_sources.dart' as sources;

/// Présentateur **espion** : n'affiche rien d'utile, mais retient la DERNIÈRE
/// `ZSelectPresentation` reçue et compte les appels. C'est la seule façon de
/// mesurer ce que les deux sites d'alimentation transmettent réellement.
class _SpyPresenter extends ZSelectPresenter {
  _SpyPresenter();

  final List<ZSelectPresentation> received = <ZSelectPresentation>[];

  ZSelectPresentation get last => received.last;

  @override
  Widget present(BuildContext context, ZSelectPresentation presentation) {
    received.add(presentation);
    return Text('spy:${presentation.options.length}');
  }
}

/// Source dynamique **contrôlée** : n'émet que sur ordre du test.
class _ManualSource implements ZRelationSource {
  final StreamController<List<ZFieldChoice>> _ctrl =
      StreamController<List<ZFieldChoice>>.broadcast();

  @override
  Stream<List<ZFieldChoice>> options(Map<String, Object?> filterContext) =>
      _ctrl.stream;

  void emit(List<ZFieldChoice> choices) => _ctrl.add(choices);
}

Widget _host(_SpyPresenter spy, Widget child) => MaterialApp(
      home: ZcrudScope(
        selectPresenter: spy,
        child: Scaffold(body: child),
      ),
    );

const ZFieldSpec _relationField = ZFieldSpec(
  name: 'partner',
  type: EditionFieldType.relation,
  label: 'Partenaire',
);

const ZFieldSpec _selectField = ZFieldSpec(
  name: 'state',
  type: EditionFieldType.select,
  label: 'État',
  choices: <ZFieldChoice>[
    ZFieldChoice(value: 'a', label: 'Alpha'),
    ZFieldChoice(value: 'b', label: 'Bravo'),
  ],
);

void main() {
  group('CR-SELECT-SEAM — élargissement ADDITIF de `ZSelectPresentation`', () {
    // ══════════════════════════════════════════════════════════════════════
    // 1. ADDITIVITÉ — les défauts restituent l'ancien contrat
    // ══════════════════════════════════════════════════════════════════════

    test(
      'SEAM-1 — construit SANS les nouveaux paramètres, le DTO porte des '
      'défauts INERTES : `false` / `null` / `null` / `null`',
      () {
        final ZSelectPresentation p = ZSelectPresentation(
          field: _selectField,
          options: const <ZFieldChoice>[],
          selected: null,
          onChanged: (_) {},
          multiple: false,
          searchable: false,
          readOnly: false,
        );
        expect(
          p.isLoading,
          isFalse,
          reason: '🔴 un défaut `true` ferait passer TOUT présentateur fidèle '
              'en état d\'attente pour un hôte qui n\'a rien demandé.',
        );
        expect(p.choiceBuilder, isNull);
        expect(p.choiceSecondaryBuilder, isNull);
        expect(p.optionsLoader, isNull);
      },
    );

    // ══════════════════════════════════════════════════════════════════════
    // 2. ALIMENTATION RÉELLE — c'est ici qu'était le trou
    // ══════════════════════════════════════════════════════════════════════

    testWidgets(
      'SEAM-2 — `relation` transmet son `isLoading` : VRAI avant la 1ʳᵉ '
      'émission de la source, FAUX après',
      (tester) async {
        final spy = _SpyPresenter();
        final source = _ManualSource();
        await tester.pumpWidget(_host(
          spy,
          ZRelationFieldWidget(
            field: _relationField,
            value: null,
            onChanged: (_) {},
            source: source,
          ),
        ));

        expect(
          spy.last.isLoading,
          isTrue,
          reason: '🔴 la source n\'a RIEN émis : le présentateur doit pouvoir '
              'distinguer « pas encore chargé » de « aucune option ». C\'est '
              'exactement la distinction que le seam ne permettait pas.',
        );
        // Anti-vacuité : à cet instant `options` est vide AUSSI — la garde ne
        // mesurerait rien si `isLoading` se contentait de recopier
        // `options.isEmpty`.
        expect(spy.last.options, isEmpty);

        source.emit(const <ZFieldChoice>[
          ZFieldChoice(value: 'x', label: 'Xylo'),
        ]);
        await tester.pump();

        expect(spy.last.isLoading, isFalse);
        expect(spy.last.options, hasLength(1));

        // 🔴 Et l'inverse discriminant : une émission VIDE n'est PAS un
        // chargement. Sans cela, `isLoading` pourrait n'être qu'un alias de
        // `options.isEmpty` et la garde ci-dessus serait tautologique.
        source.emit(const <ZFieldChoice>[]);
        // Deux `pump` : le premier draine la microtâche de livraison du flux
        // (diffusion), le second reconstruit. Un seul laisserait la garde
        // mesurer l'ÉTAT PRÉCÉDENT — c'est-à-dire rien.
        await tester.pump();
        await tester.pump();
        expect(spy.last.isLoading, isFalse);
        expect(spy.last.options, isEmpty);
      },
    );

    testWidgets(
      'SEAM-3 — `select` NE PRÉTEND PAS charger : `isLoading` reste faux '
      '(ses choix sont résolus synchronement)',
      (tester) async {
        final spy = _SpyPresenter();
        await tester.pumpWidget(_host(
          spy,
          ZSelectFieldWidget(
            field: _selectField,
            value: null,
            onChanged: (_) {},
          ),
        ));
        expect(spy.last.isLoading, isFalse);
        expect(spy.last.options, hasLength(2));
      },
    );

    testWidgets(
      'SEAM-4 — les deux sites transmettent `choiceBuilder`, '
      '`choiceSecondaryBuilder` et `optionsLoader` reçus en paramètre',
      (tester) async {
        Widget builder(BuildContext c, ZSelectChoiceContext ctx) =>
            Text('opt:${ctx.choice.label}');
        Widget? secondary(BuildContext c, ZSelectChoiceContext ctx) =>
            const Icon(Icons.edit);
        Future<List<ZFieldChoice>> loader(ZSelectOptionsQuery q) async =>
            const <ZFieldChoice>[];

        final spySelect = _SpyPresenter();
        await tester.pumpWidget(_host(
          spySelect,
          ZSelectFieldWidget(
            field: _selectField,
            value: null,
            onChanged: (_) {},
            choiceBuilder: builder,
            choiceSecondaryBuilder: secondary,
            optionsLoader: loader,
          ),
        ));
        expect(identical(spySelect.last.choiceBuilder, builder), isTrue);
        expect(
          identical(spySelect.last.choiceSecondaryBuilder, secondary),
          isTrue,
        );
        expect(identical(spySelect.last.optionsLoader, loader), isTrue);

        final spyRelation = _SpyPresenter();
        await tester.pumpWidget(_host(
          spyRelation,
          ZRelationFieldWidget(
            field: _relationField,
            value: null,
            onChanged: (_) {},
            choiceBuilder: builder,
            choiceSecondaryBuilder: secondary,
            optionsLoader: loader,
          ),
        ));
        expect(identical(spyRelation.last.choiceBuilder, builder), isTrue);
        expect(
          identical(spyRelation.last.choiceSecondaryBuilder, secondary),
          isTrue,
        );
        expect(identical(spyRelation.last.optionsLoader, loader), isTrue);
      },
    );

    testWidgets(
      'SEAM-5 — RÉTRO-COMPAT du rendu NATIF : les nouveaux paramètres, seuls, '
      'ne changent RIEN quand aucun présentateur n\'est injecté',
      (tester) async {
        Widget builder(BuildContext c, ZSelectChoiceContext ctx) =>
            const SizedBox.shrink();
        Future<List<ZFieldChoice>> loader(ZSelectOptionsQuery q) async =>
            const <ZFieldChoice>[];

        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: ZSelectFieldWidget(
              field: _selectField,
              value: 'a',
              onChanged: (_) {},
              choiceBuilder: builder,
              choiceSecondaryBuilder: builder,
              optionsLoader: loader,
            ),
          ),
        ));
        // Le rendu natif reste le `DropdownButtonFormField` d'avant.
        expect(find.byType(DropdownButtonFormField<Object?>), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    // ══════════════════════════════════════════════════════════════════════
    // 3. NEUTRALITÉ DES TYPES AJOUTÉS (AD-1 / AD-40)
    // ══════════════════════════════════════════════════════════════════════

    test(
      'SEAM-6 — 🔴 le fichier du seam n\'importe QUE Flutter + du `zcrud_core` '
      'relatif : aucun type de satellite, aucun `S2*` (scan de source)',
      () {
        final File f = File(
          'lib/src/presentation/edition/z_select_presenter.dart',
        );
        expect(f.existsSync(), isTrue,
            reason: 'chemin RELATIF : `flutter test` se lance depuis le '
                'dossier du paquet (convention `melos exec`).');
        final List<String> imports = f
            .readAsLinesSync()
            .where((l) => l.trimLeft().startsWith('import '))
            .toList(growable: false);
        expect(imports, isNotEmpty, reason: 'anti-vacuité du scan.');
        for (final String line in imports) {
          final bool ok = line.contains("'package:flutter/") ||
              line.contains("'../") ||
              line.contains("'./") ||
              !line.contains('package:');
          expect(
            ok,
            isTrue,
            reason: '🔴 import interdit dans le seam : $line — le cœur ne '
                'dépend d\'AUCUN satellite (AD-1, CORE OUT = 0).',
          );
          expect(line.contains('awesome_select'), isFalse);
        }
        // 🔴 Et aucune mention d'un type du fork dans le CODE (le dartdoc peut
        // en parler, le code non). Dépouillement PARTAGÉ (support/z_sources) :
        // il retire AUSSI les commentaires de FIN de ligne — un `// cf. S2Choice`
        // accroché à une ligne de code ne doit pas faire rougir la garde.
        final List<String> code = sources.strippedLines(f);
        for (final String line in code) {
          expect(
            RegExp(r'\bS2[A-Z]').hasMatch(line),
            isFalse,
            reason: '🔴 un type `S2*` a franchi la frontière : $line',
          );
        }
        // Anti-vacuité du filtre de commentaires : le fichier PARLE bien de S2
        // dans son dartdoc, donc un scan qui ne filtrerait pas passerait au
        // rouge — la garde mesure donc bien le code.
        expect(
          f.readAsStringSync().contains('S2ChoiceLoaderInfo'),
          isTrue,
          reason: 'le dartdoc mentionne le type du fork (motivation de la '
              'neutralité) : si cette ligne rougit, le scan ci-dessus est '
              'devenu vacant.',
        );
      },
    );
  });
}
