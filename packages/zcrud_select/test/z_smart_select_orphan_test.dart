/// 🎯 Gardes PORTEUSES du contrat **valeur hors catalogue** du présentateur
/// (`ZSmartSelectPresenter`).
///
/// **La régression défendue** : le rendu natif des familles à choix SIGNALE une
/// valeur persistée absente du catalogue (option synthétique désactivée sous le
/// libellé l10n `choiceUnresolved`) ; enrôler le présentateur le supplantait et
/// PERDAIT cet invariant — le champ affichait le placeholder (« paraît vide »)
/// alors que la valeur allait être SOUMISE.
///
/// 🔴 Anti-vacuité : chaque garde affirme les DEUX faces (la mention EST rendue
/// ET le placeholder NE l'est PAS), et l'étalon (valeur au catalogue) prouve
/// que le rendu antérieur ne bouge pas.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_select/zcrud_select.dart';

const List<ZFieldChoice> _abc = <ZFieldChoice>[
  ZFieldChoice(value: 'a', label: 'Alpha'),
  ZFieldChoice(value: 'b', label: 'Bravo'),
  ZFieldChoice(value: 'c', label: 'Charlie'),
];

/// Libellé de la table `en` de repli du cœur pour la clé `choiceUnresolved`
/// (aucune surcharge injectée dans les gardes qui l'emploient).
const String _enOrphanLabel = 'Option unavailable';

ZFieldSpec _spec(EditionFieldType type) => ZFieldSpec(
      name: 'f',
      type: type,
      label: 'Mon champ',
      choices: _abc,
    );

Widget _host({
  required Widget child,
  ZcrudLabels? labels,
}) {
  return MaterialApp(
    home: ZcrudScope(
      selectPresenter: const ZSmartSelectPresenter(),
      labels: labels,
      child: Scaffold(body: child),
    ),
  );
}

Widget _selectField(
  EditionFieldType type, {
  Object? value,
  required ValueChanged<Object?> onChanged,
  bool multiple = false,
}) =>
    ZSelectFieldWidget(
      field: _spec(type),
      value: value,
      onChanged: onChanged,
      multiple: multiple,
    );

/// Le déclencheur du présentateur (`ListTile` sous `Card`) — spécifique au
/// présentateur : le rendu natif n'a pas cette structure, la garde ROUGIT si
/// le présentateur n'est pas monté.
final Finder _trigger = find
    .descendant(of: find.byType(Card), matching: find.byType(ListTile))
    .first;

/// Remonte jusqu'au dossier portant `melos.yaml` (convention du dépôt : jamais
/// un `../` relatif nu, le répertoire courant dépend du lanceur).
Directory _repoRoot() {
  var dir = Directory.current;
  while (!File('${dir.path}/melos.yaml').existsSync()) {
    final parent = dir.parent;
    if (parent.path == dir.path) {
      fail('melos.yaml introuvable en remontant depuis ${Directory.current}');
    }
    dir = parent;
  }
  return dir;
}

void main() {
  group('🎯 CONTRAT — valeur hors catalogue SIGNALÉE, jamais rendue vide', () {
    testWidgets(
        'mono : la tuile affiche la mention d\'indisponibilité, PAS le placeholder',
        (tester) async {
      await tester.pumpWidget(_host(
        child: _selectField(EditionFieldType.select,
            value: 'zzz-disparu', onChanged: (_) {}),
      ));
      // Résolution ASYNCHRONE de la sélection par le fork (premier frame).
      await tester.pumpAndSettle();
      // La mention EST rendue, dans le déclencheur…
      expect(
        find.descendant(of: _trigger, matching: find.text(_enOrphanLabel)),
        findsOneWidget,
      );
      // …le placeholder de l'état vide NE l'est PAS (le champ ne « paraît »
      // plus vide alors que la valeur sera soumise)…
      expect(find.text('Select'), findsNothing);
      // …et la clé technique brute n'apparaît nulle part.
      expect(find.textContaining('zzz-disparu'), findsNothing);
      expect(find.textContaining('choiceUnresolved'), findsNothing);
    });

    testWidgets(
        'la mention passe par la clé l10n du natif (surcharge `ZcrudScope.labels` honorée)',
        (tester) async {
      await tester.pumpWidget(_host(
        labels: ZcrudLabels(
            const <String, String>{'choiceUnresolved': 'Indisponible (hôte)'}),
        child: _selectField(EditionFieldType.select,
            value: 'zzz-disparu', onChanged: (_) {}),
      ));
      await tester.pumpAndSettle();
      // La surcharge par la clé du NATIF est honorée ⇒ le libellé ne vient pas
      // d'un littéral du présentateur.
      expect(find.text('Indisponible (hôte)'), findsOneWidget);
      expect(find.text(_enOrphanLabel), findsNothing);
    });

    testWidgets(
        'modal : l\'orphelin est LISTÉ, désactivé (non re-sélectionnable — parité native)',
        (tester) async {
      final changes = <Object?>[];
      await tester.pumpWidget(_host(
        child: _selectField(EditionFieldType.select,
            value: 'zzz-disparu', onChanged: changes.add),
      ));
      await tester.pumpAndSettle();
      await tester.tap(_trigger, warnIfMissed: false);
      await tester.pumpAndSettle();
      // La modal liste l'option synthétique (une occurrence DE PLUS que celle
      // de la tuile) ET les options réelles.
      expect(find.text(_enOrphanLabel), findsNWidgets(2));
      expect(find.text('Alpha'), findsOneWidget);
      // Désactivée — non re-sélectionnable (parité native : elle n'est plus
      // proposée). Assertion STRUCTURELLE : le fork rend une option mono en
      // `RadioListTile(key: ValueKey(valeur), onChanged: disabled ? null : …)`
      // (`choices_resolver.dart`, `radioBuilder`) — un `onChanged` nul est
      // l'état désactivé Material, projeté aussi dans l'arbre sémantique.
      // Mesuré : une garde par tap seul ne mordait PAS (le tap sur une option
      // re-sélectionnable ne notifie pas immédiatement en mono) — c'est ce
      // `onChanged` qui porte la preuve.
      final radio = tester.widget<RadioListTile<dynamic>>(
        find.byKey(const ValueKey<dynamic>('zzz-disparu')),
      );
      expect(radio.onChanged, isNull,
          reason: 'l\'option synthétique doit être désactivée : visible, '
              'jamais re-sélectionnable');
      // Et le tap reste sans écriture.
      await tester.tap(find.text(_enOrphanLabel).last, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(changes, isEmpty);
    });

    testWidgets(
        'ÉTALON — valeur au catalogue : rendu inchangé, aucune mention',
        (tester) async {
      await tester.pumpWidget(_host(
        child: _selectField(EditionFieldType.select,
            value: 'a', onChanged: (_) {}),
      ));
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: _trigger, matching: find.text('Alpha')),
        findsOneWidget,
      );
      expect(find.text(_enOrphanLabel), findsNothing);
      expect(find.text('Select'), findsNothing);
    });

    testWidgets(
        'multi : l\'orpheline est signalée PARMI les puces (les valeurs au '
        'catalogue gardent leur libellé)', (tester) async {
      await tester.pumpWidget(_host(
        child: _selectField(EditionFieldType.checkbox,
            value: const <Object?>['a', 'zzz-disparu'],
            multiple: true,
            onChanged: (_) {}),
      ));
      await tester.pumpAndSettle();
      // Deux puces : la valeur résolue ET la mention d'indisponibilité —
      // jamais le placeholder, jamais la clé brute.
      expect(
        find.descendant(of: _trigger, matching: find.text('Alpha')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: _trigger, matching: find.text(_enOrphanLabel)),
        findsOneWidget,
      );
      expect(find.text('Select'), findsNothing);
      expect(find.textContaining('zzz-disparu'), findsNothing);
    });
  });

  group('🎯 NON-DIVERGENCE — la clé l10n est CELLE du rendu natif', () {
    test('la jumelle du présentateur égale `zOrphanChoiceLabelKey` du cœur',
        () {
      final root = _repoRoot().path;
      final coreSrc = File(
              '$root/packages/zcrud_core/lib/src/presentation/edition/z_orphan_choice.dart')
          .readAsStringSync();
      final coreKey = RegExp(
              r"zOrphanChoiceLabelKey\s*=\s*'([^']+)'")
          .firstMatch(coreSrc);
      expect(coreKey, isNotNull,
          reason: 'zOrphanChoiceLabelKey introuvable dans la source du cœur');
      final presenterSrc = File(
              '$root/packages/zcrud_select/lib/src/presentation/z_smart_select_presenter.dart')
          .readAsStringSync();
      final selectKey = RegExp(
              r"_orphanChoiceLabelKey\s*=\s*'([^']+)'")
          .firstMatch(presenterSrc);
      expect(selectKey, isNotNull,
          reason: '_orphanChoiceLabelKey introuvable dans le présentateur');
      expect(selectKey!.group(1), coreKey!.group(1),
          reason: 'la clé du présentateur DOIT être celle du natif — toute '
              'divergence rend la surcharge hôte inopérante d\'un côté');
    });
  });
}
