@Tags(<String>['reserved-keys'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:reserved_keys_gate/reserved_keys_gate.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Entité **volontairement fautive** (AC5 — contre-exemple mensonger PERMANENT).
///
/// Capture TOUT dans `extra` (y compris les clés réservées) et réémet
/// `is_deleted`/`updated_at` : c'est exactement le défaut des 2 findings HIGH
/// d'ES-1.3. Les assertions du harnais DOIVENT la rejeter — sans quoi elles
/// seraient tautologiquement vertes et ne prouveraient rien.
class _LyingEntity with ZExtensible {
  _LyingEntity.fromMap(Map<String, dynamic> map)
      : extra = Map<String, dynamic>.unmodifiable(map); // ⚠️ capture TOUT

  @override
  final Map<String, dynamic> extra;

  @override
  ZExtension? get extension => null;

  Map<String, dynamic> toMap() => <String, dynamic>{...extra}; // ⚠️ réémet TOUT
}

/// Entité **sans** slot `extra` (patron `ZChoice`) — sert à prouver que le saut
/// de (a)/(b) n'est toléré que lorsqu'il est **DÉCLARÉ** (L1).
class _NotExtensible {
  const _NotExtensible();
}

void main() {
  final registry = buildRegistry();

  group('AD-19.1.c — volet (A) comportemental : clés de sync réservées', () {
    // ---------------------------------------------------------------------
    // Cohérence du CÂBLAGE (anti-pourrissement, AC2) — un kind enregistré sans
    // corps de sonde ou sans décodeur de domaine produirait un trou silencieux.
    // ---------------------------------------------------------------------
    test('chaque kind enregistré a un corps de sonde ET un décodeur de domaine',
        () {
      final kinds = registry.kinds.toSet();
      expect(kinds, isNotEmpty, reason: 'kRegistrars est vide : gate muet.');
      expect(
        kinds.difference(kProbeBodies.keys.toSet()),
        isEmpty,
        reason: 'kind(s) enregistré(s) sans corps dans `kProbeBodies` '
            '(registrars.dart) — sonde muette = faux vert.',
      );
      expect(
        kinds.difference(kDomainDecoders.keys.toSet()),
        isEmpty,
        reason: 'kind(s) enregistré(s) sans décodeur dans `kDomainDecoders` '
            '(registrars.dart).',
      );
      // Sens inverse : entrée MORTE (corps/décodeur d'un kind disparu).
      expect(
        kProbeBodies.keys.toSet().difference(kinds),
        isEmpty,
        reason: 'corps de sonde ORPHELIN (kind non enregistré) — nettoyer '
            '`kProbeBodies`.',
      );
      expect(
        kDomainDecoders.keys.toSet().difference(kinds),
        isEmpty,
        reason: 'décodeur ORPHELIN (kind non enregistré) — nettoyer '
            '`kDomainDecoders`.',
      );
    });

    // ---------------------------------------------------------------------
    // (a)(b)(c)(d) sur CHAQUE kind enregistré — voie de DOMAINE (celle qui
    // peuple `extra` et où vit `_reservedKeys`), ré-encodage via le REGISTRE.
    // ---------------------------------------------------------------------
    for (final kind in kProbeBodies.keys) {
      test('$kind : sonde polluée → extra propre, encodage propre', () {
        final probe = buildProbe(kProbeBodies[kind]!);
        final entity = kDomainDecoders[kind]!(probe);
        final encoded = registry.encode(kind, entity);

        assertReservedKeysClean(
          label: kind,
          entity: entity,
          encoded: encoded,
          legacyMirrorAllowed: kLegacyUpdatedAtMirrors.contains(kind),
          // L1 : le saut de (a)/(b) est DÉCLARÉ, jamais silencieux.
          expectExtensible: !kNonExtensibleKinds.contains(kind),
        );
      });

      // Voie REGISTRE (`registry.decode`) : les registrars générés câblent
      // `_$ZXxxFromMap`, qui ne peuple PAS `extra` (canal hors-codegen) — (a)/(b)
      // y seraient respectivement vacuelles et intenables (cf. dartdoc de
      // `kDomainDecoders`, dette DW-ES14-1). On y exerce donc (c)/(d), qui
      // gardent tout leur sens : le `toMap` d'instance est bien celui du domaine.
      test('$kind : encodage via le registre ne réémet pas les clés de sync',
          () {
        final probe = buildProbe(kProbeBodies[kind]!);
        final entity = registry.decode(kind, probe);
        assertEncodedClean(
          label: '$kind#registry',
          encoded: registry.encode(kind, entity),
          legacyMirrorAllowed: kLegacyUpdatedAtMirrors.contains(kind),
        );
      });
    }

    // ---------------------------------------------------------------------
    // Entités `ZExtensible` HORS registre (ZMindmap/ZMindmapNode) — MÊMES
    // assertions, SANS allowlist.
    // ---------------------------------------------------------------------
    for (final probe in kManualProbes) {
      test('${probe.className} (sonde manuelle, hors registre) : mêmes assertions',
          () {
        final map = buildProbe(probe.body);
        final entity = probe.decode(map);
        assertReservedKeysClean(
          label: probe.className,
          entity: entity,
          encoded: probe.encode(entity),
          legacyMirrorAllowed: false, // aucune exception hors registre.
          expectExtensible: true, // sondées PARCE QU'elles portent un `extra`.
        );
      });
    }
  });

  group('AD-19.2 — allowlist legacy : VERROU + anti-inertie', () {
    test('VERROU : l\'ensemble est FIGÉ (toute croissance/réduction = ROUGE)',
        () {
      expect(
        kLegacyUpdatedAtMirrors,
        equals(<String>{'study_folder', 'flashcard'}),
        reason:
            'kLegacyUpdatedAtMirrors a changé. Élargir l\'allowlist est une '
            'DÉCISION D\'ARCHITECTURE (AD-19.2) : mettre à jour architecture.md '
            'et justifier en code-review — on ne « passe pas le gate » en y '
            'ajoutant discrètement son kind.',
      );
    });

    test('anti-inertie : chaque entrée correspond à un kind RÉELLEMENT enregistré',
        () {
      for (final kind in kLegacyUpdatedAtMirrors) {
        expect(
          registry.isRegistered(kind),
          isTrue,
          reason: 'entrée MORTE `$kind` dans kLegacyUpdatedAtMirrors : le kind '
              'n\'est plus enregistré — retirer l\'entrée.',
        );
      }
    });
  });

  group('L1 — anti-vacuité : le saut de (a)/(b) est DÉCLARÉ, jamais silencieux',
      () {
    test('`kNonExtensibleKinds` ne contient que des kinds RÉELLEMENT enregistrés',
        () {
      expect(
        kNonExtensibleKinds.difference(registry.kinds.toSet()),
        isEmpty,
        reason: 'entrée MORTE dans `kNonExtensibleKinds` : le kind n\'est plus '
            'enregistré — retirer l\'entrée (sinon la liste se fossilise et '
            'exempterait un jour une VRAIE entité de (a)/(b)).',
      );
    });

    test('MORD : entité NON-ZExtensible là où on en attendait une (vacuité)', () {
      // Simule un `kDomainDecoders` recâblé par erreur vers un type sans `extra` :
      // sans la garde, (a)/(b) auraient été SAUTÉES en silence — gate vert, zéro
      // protection.
      expect(
        () => assertExtraClean(
          label: 'kind_extensible_attendu',
          entity: const _NotExtensible(),
          expectExtensible: true,
        ),
        throwsA(isA<TestFailure>()),
        reason: 'un skip NON attendu de (a)/(b) doit être ROUGE, pas silencieux.',
      );
    });

    test('MORD : `kNonExtensibleKinds` PÉRIMÉE (l\'entité est devenue extensible)',
        () {
      final lying = _LyingEntity.fromMap(
        buildProbe(const <String, dynamic>{'id': 'x'}),
      );
      expect(
        () => assertExtraClean(
          label: 'kind_declare_non_extensible',
          entity: lying,
          expectExtensible: false,
        ),
        throwsA(isA<TestFailure>()),
        reason: 'une entité `ZExtensible` déclarée « non extensible » serait '
            'exemptée à tort de (a)/(b).',
      );
    });

    test('TOLÈRE le skip ATTENDU (ZChoice / flashcard_choice)', () {
      // Le seul cas légitime : le kind est DANS `kNonExtensibleKinds`.
      assertExtraClean(
        label: 'flashcard_choice',
        entity: const _NotExtensible(),
        expectExtensible: false,
      ); // ne throw pas
    });
  });

  group('AC5 — contre-exemple mensonger : le gate MORD', () {
    test('_LyingEntity échoue sur (a)/(b)/(c)/(d)', () {
      final lying = _LyingEntity.fromMap(
        buildProbe(const <String, dynamic>{'id': 'x'}),
      );

      expect(
        () => assertReservedKeysClean(
          label: '_LyingEntity',
          entity: lying,
          encoded: lying.toMap(),
          legacyMirrorAllowed: false,
          expectExtensible: true,
        ),
        throwsA(isA<TestFailure>()),
        reason: 'les assertions doivent MORDRE sur une entité fautive.',
      );

      // Portée MINIMALE de l'allowlist : même « legacy », (a) et (c) rejettent.
      expect(
        () => assertReservedKeysClean(
          label: '_LyingEntity#legacy',
          entity: lying,
          encoded: lying.toMap(),
          legacyMirrorAllowed: true,
          expectExtensible: true,
        ),
        throwsA(isA<TestFailure>()),
        reason: 'l\'allowlist ne couvre QUE (d) : (a)/(b)/(c) restent sans '
            'exception, miroirs legacy compris.',
      );
    });

    test('(a) mord : clé réservée capturée dans extra', () {
      final lying = _LyingEntity.fromMap(
        buildProbe(const <String, dynamic>{'id': 'x'}),
      );
      expect(lying.extra.containsKey(ZSyncMeta.kIsDeleted), isTrue);
      expect(
        () => assertExtraClean(
          label: '_LyingEntity',
          entity: lying,
          expectExtensible: true,
        ),
        throwsA(isA<TestFailure>()),
      );
    });

    test('(c) mord SANS exception, même sous allowlist legacy', () {
      expect(
        () => assertEncodedClean(
          label: '_encoded',
          encoded: <String, dynamic>{ZSyncMeta.kIsDeleted: true},
          legacyMirrorAllowed: true,
        ),
        throwsA(isA<TestFailure>()),
      );
    });

    test('(d) mord hors allowlist et TOLÈRE sous allowlist', () {
      expect(
        () => assertEncodedClean(
          label: '_encoded',
          encoded: <String, dynamic>{ZSyncMeta.kUpdatedAt: kProbeUpdatedAt},
          legacyMirrorAllowed: false,
        ),
        throwsA(isA<TestFailure>()),
      );
      assertEncodedClean(
        label: '_encoded#legacy',
        encoded: <String, dynamic>{ZSyncMeta.kUpdatedAt: kProbeUpdatedAt},
        legacyMirrorAllowed: true,
      ); // ne throw pas
    });

    test('anti-inertie : une entrée d\'allowlist qui n\'émet plus updated_at mord',
        () {
      expect(
        () => assertEncodedClean(
          label: '_encoded#dead',
          encoded: const <String, dynamic>{'title': 'x'},
          legacyMirrorAllowed: true,
        ),
        throwsA(isA<TestFailure>()),
      );
    });
  });
}
