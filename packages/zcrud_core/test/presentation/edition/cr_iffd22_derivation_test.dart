// CR-IFFD-22 — Dérivation DÉCLARATIVE « le champ B dérive du champ A ».
//
// Ce fichier prouve le MOTEUR (la valeur de la CR n'est pas la syntaxe) :
//   (a) SÉRIALISATION ASYNCHRONE — deux résolutions inversées : la SECONDE
//       sélection gagne, la première (périmée) est JETÉE ;
//   (b) `ifPristine` — une saisie manuelle n'est JAMAIS écrasée (vs `always`) ;
//   (c) GARDE DE CYCLE — un cycle reste exprimable, la propagation est COUPÉE ;
//   (d) AD-10 — une dérivation qui LÈVE n'écrit rien et ne casse pas la saisie ;
//   (e) cycle de vie — après `dispose`, plus AUCUN listener (aucune dérivation).
//
// Discipline R3 : chacune de ces gardes a été prouvée MORDANTE par injection de
// régression dans `lib/` (cf. rapport CR-IFFD-22).
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

ZFieldSpec _spec(String name, {ZDerivation? derived}) => ZFieldSpec(
      name: name,
      type: EditionFieldType.text,
      derivedFrom: derived,
    );

void main() {
  group('CR-IFFD-22 (a) — sérialisation des résolutions ASYNCHRONES', () {
    test('deux résolutions INVERSÉES : la SECONDE sélection gagne', () async {
      final gates = <String, Completer<Object?>>{
        'A': Completer<Object?>(),
        'B': Completer<Object?>(),
      };
      final controller = ZFormController(
        initialValues: const <String, Object?>{'src': null, 'dst': null},
      );
      addTearDown(controller.dispose);
      final engine = ZDerivationEngine(
        controller: controller,
        fields: <ZFieldSpec>[
          _spec('src'),
          _spec(
            'dst',
            derived: ZDerivation(
              sources: const <String>['src'],
              overwrite: ZDerivationOverwrite.always,
              value: (v) => gates[v['src']]!.future,
            ),
          ),
        ],
      );
      addTearDown(engine.dispose);

      // Sélection 1 (lente), puis sélection 2 (rapide) — rapprochées.
      controller.setValue('src', 'A');
      controller.setValue('src', 'B');

      // La 2e se résout D'ABORD.
      gates['B']!.complete('valeur-de-B');
      await Future<void>.delayed(Duration.zero);
      expect(controller.valueOf('dst'), 'valeur-de-B');

      // …puis la 1re, PÉRIMÉE : elle ne doit RIEN écraser.
      gates['A']!.complete('valeur-de-A');
      await Future<void>.delayed(Duration.zero);
      expect(
        controller.valueOf('dst'),
        'valeur-de-B',
        reason: 'la résolution périmée (jeton de génération obsolète) est jetée',
      );
    });

    test('le jeton est PAR CHAMP CIBLE (deux cibles ne s’invalident pas)',
        () async {
      final controller = ZFormController();
      addTearDown(controller.dispose);
      final gate1 = Completer<Object?>();
      final engine = ZDerivationEngine(
        controller: controller,
        fields: <ZFieldSpec>[
          _spec('src'),
          _spec(
            'd1',
            derived: ZDerivation(
              sources: const <String>['src'],
              overwrite: ZDerivationOverwrite.always,
              value: (v) => gate1.future,
            ),
          ),
          _spec(
            'd2',
            derived: ZDerivation(
              sources: const <String>['src'],
              overwrite: ZDerivationOverwrite.always,
              value: (v) async => 'd2:${v['src']}',
            ),
          ),
        ],
      );
      addTearDown(engine.dispose);

      controller.setValue('src', 'x');
      await Future<void>.delayed(Duration.zero);
      expect(controller.valueOf('d2'), 'd2:x');
      gate1.complete('d1:x');
      await Future<void>.delayed(Duration.zero);
      expect(controller.valueOf('d1'), 'd1:x');
    });
  });

  group('CR-IFFD-22 (b) — politique d’écrasement DÉCLARÉE', () {
    test('ifPristine — une saisie manuelle n’est PAS écrasée', () async {
      final controller = ZFormController();
      addTearDown(controller.dispose);
      final engine = ZDerivationEngine(
        controller: controller,
        fields: <ZFieldSpec>[
          _spec('src'),
          _spec(
            'dst',
            derived: ZDerivation(
              sources: const <String>['src'],
              overwrite: ZDerivationOverwrite.ifPristine,
              value: (v) async => 'dérivé:${v['src']}',
            ),
          ),
        ],
      );
      addTearDown(engine.dispose);

      // Vierge ⇒ la dérivation écrit.
      controller.setValue('src', 'a');
      await Future<void>.delayed(Duration.zero);
      expect(controller.valueOf('dst'), 'dérivé:a');
      expect(controller.isTouched('dst'), isFalse,
          reason: 'une écriture DÉRIVÉE ne rend pas le champ touché');

      // Saisie manuelle ⇒ le champ est GELÉ pour les dérivations suivantes.
      controller.setValue('dst', 'saisi à la main');
      expect(controller.isTouched('dst'), isTrue);
      controller.setValue('src', 'b');
      await Future<void>.delayed(Duration.zero);
      expect(controller.valueOf('dst'), 'saisi à la main');
    });

    test('always — écrase MÊME une saisie manuelle (parité legacy)', () async {
      final controller = ZFormController();
      addTearDown(controller.dispose);
      final engine = ZDerivationEngine(
        controller: controller,
        fields: <ZFieldSpec>[
          _spec('src'),
          _spec(
            'dst',
            derived: ZDerivation(
              sources: const <String>['src'],
              overwrite: ZDerivationOverwrite.always,
              value: (v) async => 'dérivé:${v['src']}',
            ),
          ),
        ],
      );
      addTearDown(engine.dispose);

      controller.setValue('dst', 'saisi à la main');
      controller.setValue('src', 'b');
      await Future<void>.delayed(Duration.zero);
      expect(controller.valueOf('dst'), 'dérivé:b');
    });

    test('reset/reseed/markPristine re-vierge le suivi « touché »', () {
      final controller = ZFormController(
        initialValues: const <String, Object?>{'a': 1},
      );
      addTearDown(controller.dispose);
      controller.setValue('a', 2);
      expect(controller.isTouched('a'), isTrue);
      controller.reset();
      expect(controller.isTouched('a'), isFalse);
      controller.setValue('a', 3);
      controller.markPristine();
      expect(controller.isTouched('a'), isFalse);
      controller.setValue('a', 4);
      controller.reseed(const <String, Object?>{'a': 9});
      expect(controller.isTouched('a'), isFalse);
    });
  });

  group('CR-IFFD-22 (c) — cycles : exprimables, signalés, COUPÉS', () {
    test('zDerivationCycles NOMME le cycle (pur, utilisable en release)', () {
      final cycles = zDerivationCycles(<ZFieldSpec>[
        _spec(
          'b',
          derived: ZDerivation(
            sources: const <String>['a'],
            overwrite: ZDerivationOverwrite.always,
            value: (v) async => v['a'],
          ),
        ),
        _spec(
          'a',
          derived: ZDerivation(
            sources: const <String>['b'],
            overwrite: ZDerivationOverwrite.always,
            value: (v) async => v['b'],
          ),
        ),
      ]);
      expect(cycles, hasLength(1));
      expect(cycles.single, <String>['a', 'b', 'a']);
    });

    test('aucun cycle ⇒ liste vide', () {
      expect(
        zDerivationCycles(<ZFieldSpec>[
          _spec('a'),
          _spec(
            'b',
            derived: ZDerivation(
              sources: const <String>['a'],
              overwrite: ZDerivationOverwrite.always,
              value: (v) async => v['a'],
            ),
          ),
        ]),
        isEmpty,
      );
    });

    test('la garde de RÉENTRANCE coupe la propagation (a⇄b)', () async {
      final calls = <String, int>{'a': 0, 'b': 0};
      // Filet de sécurité du TEST (pas du moteur) : au-delà de 20 appels, la
      // dérivation renvoie une CONSTANTE ⇒ `ValueNotifier` no-op ⇒ la boucle
      // s'arrête. Sans la garde du moteur, le compteur explose et l'assertion
      // ci-dessous ROUGIT (au lieu de figer la suite).
      Future<Object?> derive(String tag, Map<String, Object?> v) async {
        calls[tag] = calls[tag]! + 1;
        if (calls[tag]! > 20) return 'stop-$tag';
        return '$tag-${calls[tag]}';
      }

      final controller = ZFormController();
      addTearDown(controller.dispose);
      final engine = ZDerivationEngine(
        controller: controller,
        fields: <ZFieldSpec>[
          _spec(
            'b',
            derived: ZDerivation(
              sources: const <String>['a'],
              overwrite: ZDerivationOverwrite.always,
              value: (v) => derive('b', v),
            ),
          ),
          _spec(
            'a',
            derived: ZDerivation(
              sources: const <String>['b'],
              overwrite: ZDerivationOverwrite.always,
              value: (v) => derive('a', v),
            ),
          ),
        ],
      );
      addTearDown(engine.dispose);

      // Le cycle est SIGNALÉ, pas rejeté : le moteur s'est construit.
      expect(engine.cycles.single, <String>['a', 'b', 'a']);

      controller.setValue('a', 'saisie');
      for (var i = 0; i < 30; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(
        calls,
        <String, int>{'a': 1, 'b': 1},
        reason: 'chaque champ du cycle n’est dérivé qu’UNE fois par épisode',
      );
    });
  });

  group('CR-IFFD-22 (d) — AD-10 : une dérivation qui LÈVE ne casse rien', () {
    test('throw ASYNCHRONE ⇒ aucune écriture, valeur précédente conservée',
        () async {
      final controller = ZFormController(
        initialValues: const <String, Object?>{'dst': 'valeur initiale'},
      );
      addTearDown(controller.dispose);
      final engine = ZDerivationEngine(
        controller: controller,
        fields: <ZFieldSpec>[
          _spec('src'),
          _spec(
            'dst',
            derived: ZDerivation(
              sources: const <String>['src'],
              overwrite: ZDerivationOverwrite.always,
              value: (v) async => throw StateError('boum'),
            ),
          ),
        ],
      );
      addTearDown(engine.dispose);

      controller.setValue('src', 'x');
      await Future<void>.delayed(Duration.zero);
      expect(controller.valueOf('dst'), 'valeur initiale');
      // La saisie reste possible APRÈS l'échec.
      controller.setValue('dst', 'saisie après échec');
      expect(controller.valueOf('dst'), 'saisie après échec');
    });

    test('throw SYNCHRONE (avant tout await) ⇒ même repli', () async {
      final controller = ZFormController(
        initialValues: const <String, Object?>{'dst': 'init'},
      );
      addTearDown(controller.dispose);
      final engine = ZDerivationEngine(
        controller: controller,
        fields: <ZFieldSpec>[
          _spec('src'),
          _spec(
            'dst',
            derived: ZDerivation(
              sources: const <String>['src'],
              overwrite: ZDerivationOverwrite.always,
              // Lève AVANT de retourner un Future.
              value: (v) => throw StateError('boum sync'),
            ),
          ),
        ],
      );
      addTearDown(engine.dispose);
      controller.setValue('src', 'x');
      await Future<void>.delayed(Duration.zero);
      expect(controller.valueOf('dst'), 'init');
    });

    test('visible/bounds qui lèvent ⇒ état précédent conservé', () {
      final controller = ZFormController();
      addTearDown(controller.dispose);
      final engine = ZDerivationEngine(
        controller: controller,
        fields: <ZFieldSpec>[
          _spec('src'),
          _spec(
            'dst',
            derived: ZDerivation(
              sources: const <String>['src'],
              overwrite: ZDerivationOverwrite.always,
              visible: (v) => throw StateError('boum visible'),
              bounds: (v) => throw StateError('boum bounds'),
            ),
          ),
        ],
      );
      addTearDown(engine.dispose);
      controller.setValue('src', 'x');
      expect(engine.isVisible('dst'), isTrue);
      expect(controller.valueOf(ZDerivationChannels.minKey('dst')), isNull);
    });
  });

  group('CR-IFFD-22 (e) — cycle de vie : aucun listener fuité', () {
    test('après dispose, plus aucune dérivation n’est déclenchée', () async {
      var calls = 0;
      final controller = ZFormController();
      addTearDown(controller.dispose);
      final engine = ZDerivationEngine(
        controller: controller,
        fields: <ZFieldSpec>[
          _spec('src'),
          _spec(
            'dst',
            derived: ZDerivation(
              sources: const <String>['src'],
              overwrite: ZDerivationOverwrite.always,
              value: (v) async {
                calls++;
                return v['src'];
              },
            ),
          ),
        ],
      );

      controller.setValue('src', 'a');
      await Future<void>.delayed(Duration.zero);
      expect(calls, 1);

      engine.dispose();
      controller.setValue('src', 'b');
      await Future<void>.delayed(Duration.zero);
      expect(calls, 1, reason: 'listener retiré ⇒ aucune dérivation résiduelle');
      expect(controller.valueOf('dst'), 'a');
      // Idempotent, et le controller reste utilisable/disposable.
      engine.dispose();
    });

    test('une résolution EN VOL au moment du dispose n’écrit pas', () async {
      final gate = Completer<Object?>();
      final controller = ZFormController();
      addTearDown(controller.dispose);
      final engine = ZDerivationEngine(
        controller: controller,
        fields: <ZFieldSpec>[
          _spec('src'),
          _spec(
            'dst',
            derived: ZDerivation(
              sources: const <String>['src'],
              overwrite: ZDerivationOverwrite.always,
              value: (v) => gate.future,
            ),
          ),
        ],
      );
      controller.setValue('src', 'a');
      engine.dispose();
      gate.complete('tardif');
      await Future<void>.delayed(Duration.zero);
      expect(controller.valueOf('dst'), isNull);
    });
  });

  group('CR-IFFD-22 — cibles options / bounds / visible (canaux EXISTANTS)',
      () {
    test('options ⇒ tranche `choicesFromKey` (calculée dès l’attache)',
        () async {
      final controller = ZFormController(
        initialValues: const <String, Object?>{'pays': 'fr'},
      );
      addTearDown(controller.dispose);
      final engine = ZDerivationEngine(
        controller: controller,
        fields: <ZFieldSpec>[
          _spec('pays'),
          _spec(
            'ville',
            derived: ZDerivation(
              sources: const <String>['pays'],
              overwrite: ZDerivationOverwrite.always,
              options: (v) async => <ZFieldChoice>[
                ZFieldChoice(value: '${v['pays']}-1', label: 'Ville 1'),
              ],
            ),
          ),
        ],
      );
      addTearDown(engine.dispose);
      await Future<void>.delayed(Duration.zero);
      final options =
          controller.valueOf(ZDerivationChannels.optionsKey('ville'))!
              as List<ZFieldChoice>;
      expect(options.single.value, 'fr-1');

      controller.setValue('pays', 'be');
      await Future<void>.delayed(Duration.zero);
      final updated =
          controller.valueOf(ZDerivationChannels.optionsKey('ville'))!
              as List<ZFieldChoice>;
      expect(updated.single.value, 'be-1');
    });

    test('bounds ⇒ tranches min/max lues par ZValidatorSpec.minKey/maxKey', () {
      final controller = ZFormController();
      addTearDown(controller.dispose);
      final engine = ZDerivationEngine(
        controller: controller,
        fields: <ZFieldSpec>[
          _spec('base'),
          _spec(
            'quantite',
            derived: ZDerivation(
              sources: const <String>['base'],
              overwrite: ZDerivationOverwrite.always,
              bounds: (v) => ZFieldBounds(min: 1, max: (v['base'] as int?) ?? 0),
            ),
          ),
        ],
      );
      addTearDown(engine.dispose);
      controller.setValue('base', 42);
      expect(controller.valueOf(ZDerivationChannels.minKey('quantite')), 1);
      expect(controller.valueOf(ZDerivationChannels.maxKey('quantite')), 42);
    });

    test('la valeur n’est PAS dérivée à l’attache (donnée chargée préservée)',
        () async {
      final controller = ZFormController(
        initialValues: const <String, Object?>{'src': 'a', 'dst': 'persisté'},
      );
      addTearDown(controller.dispose);
      final engine = ZDerivationEngine(
        controller: controller,
        fields: <ZFieldSpec>[
          _spec('src'),
          _spec(
            'dst',
            derived: ZDerivation(
              sources: const <String>['src'],
              overwrite: ZDerivationOverwrite.always,
              value: (v) async => 'dérivé',
            ),
          ),
        ],
      );
      addTearDown(engine.dispose);
      await Future<void>.delayed(Duration.zero);
      expect(controller.valueOf('dst'), 'persisté');
    });

    test('les tranches compagnes sont identifiables (jamais une saisie)', () {
      expect(
        ZDerivationChannels.isDerivedChannel(
          ZDerivationChannels.optionsKey('x'),
        ),
        isTrue,
      );
      expect(ZDerivationChannels.isDerivedChannel('titre'), isFalse);
    });
  });
}
