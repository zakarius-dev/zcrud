/// AC6 — plafond d'indices : LOCAL, propriétaire UNIQUE, appliqué EN DERNIER
/// sur la valeur RENDUE (AD-36).
///
/// Tests **PURS** (aucun widget) : `zApplyHintCeiling` est une fonction pure.
///
/// ⚠️ **Ces tests n'appellent JAMAIS une fonction locale de leur cru** (défaut D5
/// de su-1 : un test tautologique qui re-code la règle qu'il prétend vérifier
/// reste vert quoi qu'il arrive à la prod). Chaque `expect` traverse le VRAI
/// `zApplyHintCeiling` importé du barrel public.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';

void main() {
  const config = ZSrsConfig();

  group('AC6 — un cran de moins par indice', () {
    // Discriminant de la story : maxQuality=5, passThreshold=3 ⇒ plancher 2.
    // `raw` est volontairement la BORNE HAUTE : on mesure le plafond seul.
    test('hints=0 ⇒ 5 (aucune pénalité)', () {
      expect(zApplyHintCeiling(rawQuality: 5, hintsUsed: 0, config: config), 5);
    });

    test('hints=1 ⇒ 4 · hints=2 ⇒ 3 · hints=3 ⇒ 2 (un cran par indice)', () {
      expect(zApplyHintCeiling(rawQuality: 5, hintsUsed: 1, config: config), 4);
      expect(zApplyHintCeiling(rawQuality: 5, hintsUsed: 2, config: config), 3);
      expect(zApplyHintCeiling(rawQuality: 5, hintsUsed: 3, config: config), 2);
    });

    test('hints=9 ⇒ 2 — le PLANCHER tient (jamais de qualité négative)', () {
      // Sans plancher, 5 - 9 = -4 : une note hors échelle, et un apprenant
      // condamné au lapse pour avoir demandé de l'aide.
      expect(zApplyHintCeiling(rawQuality: 5, hintsUsed: 9, config: config), 2);
    });

    test(
      'hintsUsed NÉGATIF est traité comme 0 (AD-10, jamais d\'exception)',
      () {
        expect(
          zApplyHintCeiling(rawQuality: 5, hintsUsed: -3, config: config),
          5,
        );
      },
    );
  });

  group('AC6 — il PLAFONNE, il ne REMONTE JAMAIS (min, jamais max)', () {
    test(
      'raw=1, hints=3 ⇒ 1 (le plafond vaut 2 : la note basse est PRÉSERVÉE)',
      () {
        // 🔴 Discriminant R3-I6b : si `min` devenait `max`, ce cas rendrait 2 —
        // le plafond RÉCOMPENSERAIT une mauvaise réponse assistée d'indices.
        expect(
          zApplyHintCeiling(rawQuality: 1, hintsUsed: 3, config: config),
          1,
        );
      },
    );

    test('raw=0 (« Je ne sais pas »), hints=3 ⇒ 0 — le plafond est INERTE', () {
      expect(zApplyHintCeiling(rawQuality: 0, hintsUsed: 3, config: config), 0);
    });
  });

  group('AC6 — plancher DÉRIVÉ de passThreshold, jamais le littéral 2', () {
    test('passThreshold=4 ⇒ plancher 3 (et NON 2)', () {
      // 🔴 Discriminant R3-I6c (leçon D7 : rendre les valeurs DISCRIMINANTES).
      // Un plancher codé `2` en dur passerait tous les tests par défaut et ne
      // ROUGIRAIT QUE sur ce cas-ci.
      const c4 = ZSrsConfig(passThreshold: 4);
      expect(zHintCeilingFloor(config: c4), 3);
      expect(zApplyHintCeiling(rawQuality: 5, hintsUsed: 9, config: c4), 3);
    });

    test('passThreshold=3 (défaut) ⇒ plancher 2 — coïncide avec le PRD', () {
      expect(zHintCeilingFloor(config: config), 2);
    });

    test('floor: 0 demandé ⇒ REMONTÉ à 2 (AD-10 : dégrader, jamais throw)', () {
      const policy = ZHintPenaltyPolicy(floor: 0);
      expect(zHintCeilingFloor(config: config, policy: policy), 2);
      expect(
        zApplyHintCeiling(
          rawQuality: 5,
          hintsUsed: 9,
          config: config,
          policy: policy,
        ),
        2,
      );
    });

    test('floor: 4 demandé (PLUS HAUT que le dérivé) est RESPECTÉ', () {
      // Le plancher n'est remonté que s'il est trop BAS : une app qui veut être
      // plus clémente le peut.
      const policy = ZHintPenaltyPolicy(floor: 4);
      expect(zHintCeilingFloor(config: config, policy: policy), 4);
      expect(
        zApplyHintCeiling(
          rawQuality: 5,
          hintsUsed: 9,
          config: config,
          policy: policy,
        ),
        4,
      );
    });
  });

  group('AC6 — 🔒 GARDE ANTI-CONTOURNEMENT (AD-36)', () {
    test('port ⇒ 5 avec 3 indices ⇒ 2 (le port NE contourne PAS le plafond)', () {
      // AD-36 mot pour mot : « un port qui rend 10 indices ne contourne pas le
      // plafond ». Le port ne connaît AUCUNE pénalité (hintsUsed lui est
      // informatif) : c'est la couche locale qui plafonne, EN DERNIER.
      //
      // 🔴 Ce cas ROUGIT sur R3-I6d (oublier le plafond sur le chemin advisory) :
      // sans plafond, la suggestion 5 passerait telle quelle. C'est LA garde
      // anti-contournement RÉELLE — celle qui discrimine (cf. le test de
      // COMMUTATIVITÉ ci-dessous, qui documente pourquoi l'ORDRE, lui, ne
      // discrimine pas).
      const portSuggested = 5;
      final clamped = config.clampQuality(portSuggested);
      expect(
        zApplyHintCeiling(rawQuality: clamped, hintsUsed: 3, config: config),
        2,
      );
    });

    test('🔴 PORTEUR du clamp : port ⇒ -3 avec 0 indice ⇒ 0 '
        '(le cas HAUT « 9 ⇒ 5 » est MASQUÉ par le plafond — leçon D12)', () {
      // ⚠️ ÉCART MESURÉ vs le discriminant (1) d'AC2, consigné honnêtement.
      //
      // La story propose « port ⇒ 9 ⇒ cran 5 » comme preuve du clamp
      // (R3-I2 : « supprimer le clampQuality ⇒ ROUGIT »). **C'est FAUX, et
      // mesuré** : avec 0 indice, ceiling = max(5-0, 2) = 5, donc
      // min(9, 5) = 5 — le PLAFOND rend déjà 5 même SANS clamp. Le cas haut est
      // structurellement AVEUGLE : deux canaux se masquent l'un l'autre
      // (défaut D12 de su-2 — « chaque garde doit rougir SEULE »).
      //
      // Seule la BORNE BASSE discrimine : sans clamp, min(-3, 5) = **-3**,
      // une note HORS ÉCHELLE que le SRS ne sait pas servir. C'est donc CE test
      // qui porte la garde du clamp, et il est nommé pour qu'on ne le supprime
      // pas en croyant le cas haut suffisant.
      final clamped = config.clampQuality(-3);
      expect(clamped, 0, reason: 'clampQuality est la SEULE voie de clamp');
      expect(
        zApplyHintCeiling(rawQuality: clamped, hintsUsed: 0, config: config),
        0,
      );
    });

    test('🔬 INVARIANT porteur : le plafond ne descend JAMAIS sous `minQuality` '
        '⇒ c\'est CE qui rend l\'ordre clamp/plafond sûr', () {
      // ⚠️ ÉCART MESURÉ vs R3-I6, consigné honnêtement.
      //
      // La story prescrit : « appliquer le plafond AVANT le clamp du port ⇒ la
      // garde anti-contournement ROUGIT ». **Mesuré sur les 1144 combinaisons
      // atteignables (passThreshold ∈ {3,4} × minQuality ∈ {0,1} × hints 0..10 ×
      // raw -10..15) : 0 divergence.** Les deux ordres sont **commutatifs**, et
      // ce n'est pas un hasard : `min(clamp(x), c) == clamp(min(x, c))` DÈS LORS
      // QUE `c >= minQuality`. Écrire un test qui prétendrait « prouver l'ordre »
      // serait donc un test qui ne peut JAMAIS rougir — exactement le défaut que
      // su-1/su-2 ont démasqué.
      //
      // 🔴 **CORRECTION du code-review su-3** : ce test pinnait
      // `inInclusiveRange(minQuality, maxQuality)` en prétendant rougir « le jour
      // où le plafond dépasserait `maxQuality` ». **Les deux moitiés étaient
      // fausses** :
      //  1. la borne HAUTE ne peut **JAMAIS** échouer : `zApplyHintCeiling`
      //     termine par `math.min(rawQuality, ceiling)` et on passe
      //     `rawQuality: c.maxQuality` ⇒ le résultat est `<= maxQuality` **par
      //     construction du `min`**, quel que soit le vrai plafond. La moitié
      //     haute de l'assertion était **structurellement aveugle** ;
      //  2. et elle ne gardait rien d'utile : un plafond **au-dessus** de
      //     `maxQuality` (atteignable — `ZHintPenaltyPolicy(floor: 100)`, cf. le
      //     cas ci-dessous) ne casse **PAS** la commutativité — les deux ordres
      //     rendent alors `clamp(x)`.
      //
      // Seule la borne **BASSE** est load-bearing, et elle **discrimine**
      // réellement : retirer la remontée du plancher dans `zHintCeilingFloor`
      // ⇒ `used=10` ⇒ `min(5, -5) = -5` ⇒ **ROUGE**.
      for (final c in <ZSrsConfig>[
        const ZSrsConfig(),
        const ZSrsConfig(passThreshold: 4),
        const ZSrsConfig(minQuality: 1),
        const ZSrsConfig(minQuality: 1, passThreshold: 5),
      ]) {
        for (var used = 0; used <= 10; used++) {
          // `rawQuality: c.maxQuality` ⇒ la valeur rendue EST le plafond
          // (tant que celui-ci reste sous `maxQuality`).
          final ceiling = zApplyHintCeiling(
            rawQuality: c.maxQuality,
            hintsUsed: used,
            config: c,
          );
          expect(
            ceiling,
            greaterThanOrEqualTo(c.minQuality),
            reason:
                'plafond SOUS l\'échelle (used=$used, config=$c) ⇒ la '
                'commutativité clamp/plafond TOMBE et l\'ordre imposé '
                'redevient load-bearing',
          );
        }
      }
    });

    test('🔬 un plancher de politique HORS ÉCHELLE ne remonte JAMAIS la note '
        '(le `min` final borne, quoi qu\'annonce le plafond)', () {
      // Documente honnêtement le cas que l'ancienne borne haute prétendait
      // garder : `floor: 100` est **atteignable** (`zHintCeilingFloor` ne borne
      // le plancher que par le BAS) et produit un plafond réel de 100 — hors
      // échelle. Ce n'est pas un danger : `zApplyHintCeiling` PLAFONNE
      // (`math.min`), il ne remonte jamais. La note reste celle du clamp.
      const c = ZSrsConfig();
      const wild = ZHintPenaltyPolicy(floor: 100);
      for (var used = 0; used <= 10; used++) {
        expect(
          zApplyHintCeiling(
            rawQuality: c.maxQuality,
            hintsUsed: used,
            config: c,
            policy: wild,
          ),
          c.maxQuality,
          reason:
              'un plafond hors échelle ne doit ni remonter la note, ni la '
              'faire sortir de l\'échelle : le `min` final la borne',
        );
      }
    });
  });
}
