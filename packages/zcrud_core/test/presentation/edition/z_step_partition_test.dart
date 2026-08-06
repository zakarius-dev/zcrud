/// **G1** — regroupement *data-driven inline* : `List<ZFieldSpec>` annotés →
/// `List<ZEditionStep>` ([zPartitionFieldsIntoSteps]).
///
/// 🔴 **Une garde qui n'assère que le NOMBRE d'étapes est faible** : elle reste
/// verte si les champs atterrissent dans la mauvaise étape, dans le mauvais
/// ordre, ou si deux étapes échangent leur titre. Cette suite assère donc la
/// **composition EXACTE** de chaque étape (titre, sous-titre, icône, liste
/// ordonnée des noms) — et le fait sur un cas où **l'ordre de déclaration
/// diffère de l'ordre des index**, le seul cas où « préserver l'ordre » a un
/// contenu observable.
///
/// La fonction est PURE : aucun `BuildContext`, aucun binding Flutter, aucun
/// `pumpWidget` — c'est un test unitaire nu, et c'est la preuve exécutable de
/// sa testabilité hors rendu.
@TestOn('vm')
library;

import 'package:flutter/material.dart' show IconData, Icons;
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

ZFieldSpec _f(String name, {ZFieldConfig? config}) =>
    ZFieldSpec(name: name, type: EditionFieldType.text, config: config);

ZFieldSpec _step(
  String name,
  int index, {
  String? title,
  String? subtitle,
  IconData? icon,
}) =>
    _f(
      name,
      config: ZStepFieldConfig(
        index: index,
        title: title,
        subtitle: subtitle,
        icon: icon,
      ),
    );

/// Composition observable d'une étape — c'est CE tuple que les tests comparent,
/// jamais un simple `steps.length`.
List<Object?> _shape(ZEditionStep s) =>
    <Object?>[s.title, s.subtitle, s.icon, s.fields];

void main() {
  group('cas dégénérés — la fonction est TOTALE', () {
    test('liste vide ⇒ partition vide, aucune exception', () {
      final ZStepPartition p = zPartitionFieldsIntoSteps(const <ZFieldSpec>[]);
      expect(p.steps, isEmpty);
      expect(p.unassigned, isEmpty);
      expect(p.isEmpty, isTrue);
    });

    test('AUCUN champ annoté ⇒ zéro étape (aucune étape fabriquée)', () {
      final ZStepPartition p = zPartitionFieldsIntoSteps(<ZFieldSpec>[
        _f('a'),
        _f('b', config: const ZTextConfig(maxLines: 3)),
      ]);
      expect(p.steps, isEmpty, reason: 'l\'hôte rend son formulaire tel quel');
      // 🔴 Les champs ne sont PAS perdus en silence — c'est le défaut mesuré
      // côté DODLP (`dynamic_stepper.dart` ne collecte que `stepIndex != null`).
      expect(p.unassigned, <String>['a', 'b']);
    });

    test('un SEUL champ annoté ⇒ une étape d\'un champ', () {
      final ZStepPartition p =
          zPartitionFieldsIntoSteps(<ZFieldSpec>[_step('solo', 4, title: 't')]);
      expect(p.steps.length, 1);
      expect(_shape(p.steps.single), <Object?>['t', null, null, <String>['solo']]);
    });

    test('champs annotés ET non annotés : la perte est RENDUE VISIBLE', () {
      final ZStepPartition p = zPartitionFieldsIntoSteps(<ZFieldSpec>[
        _f('avant'),
        _step('dedans', 0),
        _f('apres'),
      ]);
      expect(p.steps.single.fields, <String>['dedans']);
      expect(p.unassigned, <String>['avant', 'apres']);
    });
  });

  group('ordre — clés et déclaration', () {
    test('index NON CONTIGUS (0, 2, 5) ⇒ 3 étapes, composition exacte', () {
      final ZStepPartition p = zPartitionFieldsIntoSteps(<ZFieldSpec>[
        _step('a', 5, title: 'cinq'),
        _step('b', 0, title: 'zero'),
        _step('c', 2, title: 'deux'),
      ]);
      expect(p.steps.map(_shape), <List<Object?>>[
        <Object?>['zero', null, null, <String>['b']],
        <Object?>['deux', null, null, <String>['c']],
        <Object?>['cinq', null, null, <String>['a']],
      ]);
    });

    test('index NÉGATIF : accepté et ordonné avant 0 (jamais rejeté)', () {
      final ZStepPartition p = zPartitionFieldsIntoSteps(<ZFieldSpec>[
        _step('zero', 0, title: 'z'),
        _step('avant', -3, title: 'a'),
        _step('tres_avant', -10, title: 'ta'),
      ]);
      expect(p.steps.map((ZEditionStep s) => s.title),
          <String>['ta', 'a', 'z']);
      expect(p.steps.map((ZEditionStep s) => s.fields),
          <List<String>>[
            <String>['tres_avant'],
            <String>['avant'],
            <String>['zero'],
          ]);
      expect(p.unassigned, isEmpty);
    });

    test(
        '🔴 l\'ordre de DÉCLARATION est préservé DANS l\'étape — sur un cas où '
        'il diffère de l\'ordre des index', () {
      // Déclaration entrelacée : 1, 0, 1, 0, 1. Une implémentation qui trierait
      // par index à l'intérieur d'une étape, ou qui repartirait des clés,
      // rendrait un autre ordre — et un simple `steps.length == 2` ne le
      // verrait pas.
      //
      // 🔴 Les noms sont choisis pour que l'ordre ALPHABÉTIQUE soit l'INVERSE
      // strict de l'ordre de déclaration, dans chaque étape. Mesuré : avec des
      // noms accidentellement triés (`f0, f2, f4…`), l'injection R3 « trier les
      // champs de l'étape » restait VERTE — la garde regardait à côté.
      final ZStepPartition p = zPartitionFieldsIntoSteps(<ZFieldSpec>[
        _step('zoulou', 1, title: 'ETAPE-UN'),
        _step('yankee', 0, title: 'ETAPE-ZERO'),
        _step('mike', 1),
        _step('bravo', 0),
        _step('alpha', 1),
      ]);
      expect(p.steps.map(_shape), <List<Object?>>[
        <Object?>[
          'ETAPE-ZERO',
          null,
          null,
          <String>['yankee', 'bravo'],
        ],
        <Object?>[
          'ETAPE-UN',
          null,
          null,
          <String>['zoulou', 'mike', 'alpha'],
        ],
      ]);
      // Contre-preuve explicite : l'ordre rendu N'EST PAS l'ordre alphabétique.
      expect(p.steps[1].fields, isNot(<String>['alpha', 'mike', 'zoulou']));
      // Et l'étape rendue en PREMIER est bien celle de clé 0, alors qu'elle a
      // été DÉCLARÉE en second : le tri s'applique aux étapes, pas aux champs.
      expect(p.steps.first.title, 'ETAPE-ZERO');
    });

    test('deux clés, dix champs : chaque champ atterrit dans SA étape', () {
      // Noms DÉCROISSANTS (`f9 … f0`) déclarés dans cet ordre : l'ordre rendu
      // ne peut donc pas être confondu avec un ordre alphabétique.
      final List<ZFieldSpec> fields = <ZFieldSpec>[
        for (int i = 9; i >= 0; i--) _step('f$i', i.isEven ? 0 : 1),
      ];
      final ZStepPartition p = zPartitionFieldsIntoSteps(fields);
      expect(p.steps.length, 2);
      expect(p.steps[0].fields, <String>['f8', 'f6', 'f4', 'f2', 'f0']);
      expect(p.steps[1].fields, <String>['f9', 'f7', 'f5', 'f3', 'f1']);
    });
  });

  group('métadonnées — le PREMIER non-null gagne', () {
    test('titre/sous-titre/icône se complètent sans s\'effacer', () {
      final ZStepPartition p = zPartitionFieldsIntoSteps(<ZFieldSpec>[
        _step('a', 0),
        _step('b', 0, title: 'TITRE'),
        _step('c', 0, subtitle: 'SOUS'),
        _step('d', 0, icon: Icons.abc),
        // Ceux-là arrivent APRÈS : ils ne doivent rien écraser.
        _step('e', 0, title: 'IGNORE', subtitle: 'IGNORE', icon: Icons.ac_unit),
      ]);
      expect(_shape(p.steps.single), <Object?>[
        'TITRE',
        'SOUS',
        Icons.abc,
        <String>['a', 'b', 'c', 'd', 'e'],
      ]);
    });

    test('TITRES ABSENTS partout ⇒ chaîne vide (aucun littéral fabriqué)', () {
      // DODLP fabrique `'Étape ${i + 1}'` ; le reproduire injecterait un
      // littéral français codé en dur dans le cœur (l10n). L'indicateur
      // `numbered` affiche « k/N » de toute façon.
      final ZStepPartition p = zPartitionFieldsIntoSteps(<ZFieldSpec>[
        _step('a', 0),
        _step('b', 7),
      ]);
      expect(p.steps.map((ZEditionStep s) => s.title), <String>['', '']);
    });

    test('titleFallback reçoit la CLÉ et la POSITION (elles diffèrent)', () {
      final List<List<int>> vus = <List<int>>[];
      final ZStepPartition p = zPartitionFieldsIntoSteps(
        <ZFieldSpec>[_step('a', 0), _step('b', 2), _step('c', 5)],
        titleFallback: (int index, int position) {
          vus.add(<int>[index, position]);
          return 'k=$index p=$position';
        },
      );
      expect(vus, <List<int>>[
        <int>[0, 0],
        <int>[2, 1],
        <int>[5, 2],
      ]);
      expect(p.steps.map((ZEditionStep s) => s.title),
          <String>['k=0 p=0', 'k=2 p=1', 'k=5 p=2']);
    });

    test('titleFallback n\'est PAS appelé quand un titre existe', () {
      int appels = 0;
      final ZStepPartition p = zPartitionFieldsIntoSteps(
        <ZFieldSpec>[_step('a', 0, title: 'VRAI')],
        titleFallback: (int i, int p) {
          appels++;
          return 'REPLI';
        },
      );
      expect(appels, 0);
      expect(p.steps.single.title, 'VRAI');
    });
  });

  group('AD-10 — totalité face au code de l\'hôte', () {
    test('un `titleFallback` qui LÈVE ne casse pas la partition', () {
      final ZStepPartition p = zPartitionFieldsIntoSteps(
        <ZFieldSpec>[_step('a', 0), _step('b', 1, title: 'ok')],
        titleFallback: (int i, int p) => throw StateError('boom'),
      );
      expect(p.steps.map((ZEditionStep s) => s.title), <String>['', 'ok']);
    });

    test('un `stepOf` qui LÈVE ⇒ champ traité comme non annoté', () {
      final ZStepPartition p = zPartitionFieldsIntoSteps(
        <ZFieldSpec>[_f('explosif'), _f('sain')],
        stepOf: (ZFieldSpec f) => f.name == 'explosif'
            ? throw StateError('boom')
            : const ZStepFieldConfig(index: 0, title: 'T'),
      );
      expect(p.unassigned, <String>['explosif']);
      expect(_shape(p.steps.single),
          <Object?>['T', null, null, <String>['sain']]);
    });

    test('les listes rendues sont NON MODIFIABLES', () {
      final ZStepPartition p =
          zPartitionFieldsIntoSteps(<ZFieldSpec>[_step('a', 0), _f('b')]);
      expect(() => p.steps.add(const ZEditionStep(title: 'x', fields: <String>[])),
          throwsUnsupportedError);
      expect(() => p.unassigned.add('x'), throwsUnsupportedError);
      expect(() => p.steps.single.fields.add('x'), throwsUnsupportedError);
    });
  });

  group('canal `stepOf` — la sortie de secours du slot exclusif', () {
    test('un champ gardant sa `ZTextConfig` peut quand même être annoté', () {
      // 🔴 MESURÉ : `ZFieldSpec.config` est un slot UNIQUE. Un champ texte qui
      // porte `ZTextConfig` ne peut pas porter en plus `ZStepFieldConfig` —
      // c'est ce que ce canal résout, sans occuper le slot.
      const ZFieldSpec texte = ZFieldSpec(
        name: 'commentaire',
        type: EditionFieldType.multiline,
        config: ZTextConfig(maxLines: 5),
      );
      final ZStepPartition p = zPartitionFieldsIntoSteps(
        <ZFieldSpec>[texte, _f('autre')],
        stepOf: (ZFieldSpec f) => f.name == 'commentaire'
            ? const ZStepFieldConfig(index: 0, title: 'notes')
            : null,
      );
      expect(_shape(p.steps.single),
          <Object?>['notes', null, null, <String>['commentaire']]);
      expect(p.unassigned, <String>['autre']);
      // La config de type du champ est intacte : rien n'a été consommé.
      expect((texte.config! as ZTextConfig).maxLines, 5);
    });

    test('`stepOf` fourni PRIME sur l\'annotation portée par `config`', () {
      final ZStepPartition p = zPartitionFieldsIntoSteps(
        <ZFieldSpec>[_step('a', 0, title: 'PAR-CONFIG')],
        stepOf: (ZFieldSpec f) => const ZStepFieldConfig(index: 9, title: 'PAR-SEAM'),
      );
      expect(_shape(p.steps.single),
          <Object?>['PAR-SEAM', null, null, <String>['a']]);
    });
  });

  group('pureté', () {
    test('deux appels sur la MÊME entrée rendent la même composition', () {
      final List<ZFieldSpec> fields = <ZFieldSpec>[
        _step('b', 1, title: 'B'),
        _step('a', 0, title: 'A'),
        _f('libre'),
      ];
      final ZStepPartition p1 = zPartitionFieldsIntoSteps(fields);
      final ZStepPartition p2 = zPartitionFieldsIntoSteps(fields);
      expect(p1.steps.map(_shape).toList(), p2.steps.map(_shape).toList());
      expect(p1.unassigned, p2.unassigned);
    });

    test('l\'entrée n\'est pas mutée', () {
      final List<ZFieldSpec> fields = <ZFieldSpec>[
        _step('a', 0),
        _step('b', 1),
      ];
      final List<String> avant =
          fields.map((ZFieldSpec f) => f.name).toList();
      zPartitionFieldsIntoSteps(fields);
      expect(fields.map((ZFieldSpec f) => f.name).toList(), avant);
      expect(fields.length, 2);
    });
  });

  group('ZStepFieldConfig — valeur', () {
    test('égalité structurelle et hashCode', () {
      const ZStepFieldConfig a = ZStepFieldConfig(index: 1, title: 't');
      const ZStepFieldConfig b = ZStepFieldConfig(index: 1, title: 't');
      const ZStepFieldConfig c = ZStepFieldConfig(index: 2, title: 't');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });

    test('c\'est bien un `ZFieldConfig` (canal existant, pas un parallèle)', () {
      expect(const ZStepFieldConfig(index: 0), isA<ZFieldConfig>());
    });
  });
}
