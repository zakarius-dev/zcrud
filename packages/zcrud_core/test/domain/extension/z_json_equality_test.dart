// ES-2.2b — `zJsonEquals`/`zJsonHash`/`zSanitizeExtra` (DW-ES22-3/DW-ES22-4).
//
// Aucun `dart:io` (AC14 / `gate:web` default-ON) : pur-Dart, exécutable en VM
// comme en web.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Deux instances INDÉPENDANTES du même JSON.
///
/// ⚠️ **Le deep-copy n'est pas cosmétique** : sans lui, les deux valeurs
/// partagent la **même** sous-`Map`, `identical` court-circuite la récursion et
/// une égalité **SUPERFICIELLE** paraîtrait **VERTE** — le « vert pour une
/// mauvaise raison » que cette story combat. Un littéral `const` est **pire
/// encore** (canonicalisé ⇒ `identical`).
Object? _deep(Object? v) => jsonDecode(jsonEncode(v));

void main() {
  group('zJsonEquals — égalité PROFONDE (DW-ES22-4)', () {
    test('scalaires', () {
      expect(zJsonEquals(1, 1), isTrue);
      expect(zJsonEquals('a', 'a'), isTrue);
      expect(zJsonEquals(null, null), isTrue);
      expect(zJsonEquals(1, 2), isFalse);
      expect(zJsonEquals(1, '1'), isFalse);
      expect(zJsonEquals(null, 0), isFalse);
    });

    test('Map IMBRIQUÉE : deux instances indépendantes sont ÉGALES', () {
      final payload = <String, dynamic>{
        'a': 1,
        'l': <dynamic>[
          1,
          <String, dynamic>{'b': 2},
        ],
      };
      final a = _deep(payload);
      final b = _deep(payload);
      // Le fait, d'abord : ce sont bien DEUX objets distincts (sinon le test
      // serait vacuellement vert par `identical`).
      expect(identical(a, b), isFalse);
      expect((a! as Map)['l'], isNot(same((b! as Map)['l'])));
      // Et l'`==` NATIF de Dart les dit DIFFÉRENTS — c'est exactement le défaut.
      expect(a == b, isFalse, reason: 'témoin : `==` natif est une identité.');

      expect(zJsonEquals(a, b), isTrue);
      expect(zJsonHash(a), zJsonHash(b));
    });

    test('List IMBRIQUÉE : ordre SIGNIFIANT', () {
      expect(
        zJsonEquals(<dynamic>[1, 2], <dynamic>[2, 1]),
        isFalse,
        reason: 'l\'ordre d\'une liste est signifiant.',
      );
      expect(
        zJsonHash(<dynamic>[1, 2]),
        isNot(zJsonHash(<dynamic>[2, 1])),
      );
    });

    test('Map : ordre des clés NON signifiant (equals ET hash)', () {
      final a = <String, dynamic>{'x': 1, 'y': 2};
      final b = <String, dynamic>{'y': 2, 'x': 1};
      expect(zJsonEquals(a, b), isTrue);
      expect(zJsonHash(a), zJsonHash(b));
    });

    test('MORD : une valeur imbriquée qui diffère en profondeur', () {
      final a = <String, dynamic>{
        'l': <dynamic>[
          <String, dynamic>{'b': 2},
        ],
      };
      final b = <String, dynamic>{
        'l': <dynamic>[
          <String, dynamic>{'b': 3},
        ],
      };
      expect(zJsonEquals(a, b), isFalse);
      expect(zJsonHash(a), isNot(zJsonHash(b)));
    });

    test('MORD : longueurs et clés différentes', () {
      expect(zJsonEquals(<String, dynamic>{'a': 1}, <String, dynamic>{}), isFalse);
      expect(
        zJsonEquals(<String, dynamic>{'a': 1}, <String, dynamic>{'b': 1}),
        isFalse,
        reason: 'même longueur, clé absente ⇒ FAUX (pas un lookup `null == null`).',
      );
      expect(zJsonEquals(<dynamic>[1], <dynamic>[1, 2]), isFalse);
    });

    test('une clé présente à `null` n\'est PAS une clé absente', () {
      expect(
        zJsonEquals(
          <String, dynamic>{'a': null},
          <String, dynamic>{'b': null},
        ),
        isFalse,
      );
    });

    test('Map vs List vs scalaire : types hétérogènes', () {
      expect(zJsonEquals(<String, dynamic>{}, <dynamic>[]), isFalse);
      expect(zJsonEquals(<dynamic>[], 0), isFalse);
    });
  });

  group('zSanitizeExtra — la garde partagée (DW-ES22-3)', () {
    test('dépouille les clés réservées et rend une Map NON MODIFIABLE', () {
      final out = zSanitizeExtra(
        <String, dynamic>{
          ZSyncMeta.kUpdatedAt: '1999-01-01T00:00:00.000Z',
          ZSyncMeta.kIsDeleted: true,
          'title': 'champ du schéma',
          'zz_inconnue': 'gardée',
        },
        <String>{'title', ...ZSyncMeta.reservedKeys},
      );

      expect(out.containsKey(ZSyncMeta.kUpdatedAt), isFalse);
      expect(out.containsKey(ZSyncMeta.kIsDeleted), isFalse);
      expect(out.containsKey('title'), isFalse);
      // AD-4 : on ne « passe pas la garde » en VIDANT `extra`.
      expect(out['zz_inconnue'], 'gardée');
      expect(
        () => out['x'] = 1,
        throwsUnsupportedError,
        reason: 'cohérence `ZExtensible` : `extra` est non modifiable.',
      );
    });

    test('ensemble réservé vide ⇒ passe-plat (mais toujours non modifiable)', () {
      final out = zSanitizeExtra(<String, dynamic>{'a': 1}, const <String>{});
      expect(out, <String, dynamic>{'a': 1});
      expect(() => out.clear(), throwsUnsupportedError);
    });

    test('idempotente (re-sanitiser une map déjà propre ne change rien)', () {
      const reserved = <String>{'title'};
      final once = zSanitizeExtra(
        <String, dynamic>{'title': 't', 'k': 'v'},
        reserved,
      );
      expect(zSanitizeExtra(once, reserved), equals(once));
    });
  });
}
