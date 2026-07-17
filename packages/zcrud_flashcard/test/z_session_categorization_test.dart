/// Catégorisation du sélecteur de session (SU-6 — AC7/AC8/AC13).
///
/// 🔴 **AC8 — l'O(1) est MESURÉ, pas affirmé.** Une sonde compte les **lectures
/// d'accesseurs** de l'état SRS ; la mesure tourne à **N=200 ET N=1600** et exige
/// `lectures <= 4N`. Une implémentation de référence **délibérément O(n²)**
/// (`firstWhere` par carte) est soumise à la **MÊME** assertion dans **CE**
/// fichier et **DOIT la dépasser** — sans quoi le compteur ne prouverait rien.
///
/// 🚫 **Aucun `Stopwatch`** : une mesure de temps est flaky en CI, et un `sleep`
/// la ferait passer. On compte des **opérations** — grandeur déterministe.
/// 🚫 `k` et `N` sont des **littéraux DU TEST**, jamais des constantes lues dans
/// le code de prod (leçon su-4 « 48 dp » : une assertion qui se compare à la
/// constante qu'elle vérifie est tautologique).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';

/// Compteur de lectures partagé par les sondes.
class _ReadCounter {
  int reads = 0;
}

/// 🔬 **LA SONDE** — un `ZRepetitionInfo` qui COMPTE les lectures de ses
/// accesseurs (`flashcardId`, `repetitions`, `nextReviewDate`, `lastQuality`).
///
/// Étend l'entité **RÉELLE** (jamais une copie) : elle traverse donc exactement
/// le même code de prod que l'état SRS authentique.
class _ProbeInfo extends ZRepetitionInfo {
  _ProbeInfo({
    required super.flashcardId,
    required super.folderId,
    required this.counter,
    super.repetitions,
    super.nextReviewDate,
    super.lastQuality,
  });

  final _ReadCounter counter;

  @override
  String get flashcardId {
    counter.reads++;
    return super.flashcardId;
  }

  @override
  int get repetitions {
    counter.reads++;
    return super.repetitions;
  }

  @override
  DateTime? get nextReviewDate {
    counter.reads++;
    return super.nextReviewDate;
  }

  @override
  int? get lastQuality {
    counter.reads++;
    return super.lastQuality;
  }
}

/// 🔬 **CONTRE-PREUVE — l'implémentation délibérément O(n²)** (AC8).
///
/// C'est le motif que `zCategorize` interdit : `firstWhere` **par carte** ⇒ un
/// balayage de la liste **pour chaque** carte. Soumise à la **même** assertion
/// `<= 4N`, elle **DOIT échouer** : c'est ce qui prouve que la sonde a du
/// **pouvoir discriminant**, et non qu'elle mesure du vent.
ZSessionCategories _categorizeQuadratic(
  Iterable<ZFlashcard> cards, {
  required List<ZRepetitionInfo> infos,
  required DateTime at,
}) {
  final neverLearned = <ZFlashcard>[];
  final due = <ZFlashcard>[];

  for (final card in cards) {
    // 🔴 LE DÉFAUT : O(n) PAR carte ⇒ O(n²) au total.
    final matches = infos.where((i) => i.flashcardId == card.id);
    final info = matches.isEmpty ? null : matches.first;

    if (info == null || info.repetitions == 0) {
      neverLearned.add(card);
      continue;
    }
    final next = info.nextReviewDate;
    if (next != null && !next.isAfter(at)) due.add(card);
  }
  return ZSessionCategories(neverLearned: neverLearned, due: due);
}

/// Construit `n` cartes + leurs sondes SRS (moitié apprises/dues).
({List<ZFlashcard> cards, List<ZRepetitionInfo> infos}) _corpus(
  int n,
  _ReadCounter counter,
  DateTime at,
) {
  final cards = <ZFlashcard>[];
  final infos = <ZRepetitionInfo>[];
  for (var i = 0; i < n; i++) {
    cards.add(ZFlashcard(id: 'c$i', folderId: 'f', question: 'q$i'));
    infos.add(
      _ProbeInfo(
        flashcardId: 'c$i',
        folderId: 'f',
        counter: counter,
        repetitions: i.isEven ? 0 : 3,
        nextReviewDate: at.subtract(Duration(days: i % 7)),
        lastQuality: 4,
      ),
    );
  }
  return (cards: cards, infos: infos);
}

void main() {
  final at = DateTime(2026, 3, 29, 12);

  group('AC7 — les deux catégories, règles EXACTES', () {
    test('« jamais apprises » = repetitions == 0 (ordre d\'entrée préservé)', () {
      final cards = <ZFlashcard>[
        const ZFlashcard(id: 'a', folderId: 'f', question: 'a'),
        const ZFlashcard(id: 'b', folderId: 'f', question: 'b'),
        const ZFlashcard(id: 'c', folderId: 'f', question: 'c'),
      ];
      final srsById = zIndexSrsById(<ZRepetitionInfo>[
        const ZRepetitionInfo(flashcardId: 'a', folderId: 'f'),
        ZRepetitionInfo(
          flashcardId: 'b',
          folderId: 'f',
          repetitions: 2,
          nextReviewDate: at.add(const Duration(days: 3)),
        ),
        const ZRepetitionInfo(flashcardId: 'c', folderId: 'f'),
      ]);

      final result = zCategorize(cards, srsById: srsById, at: at);

      // Séquence ENTIÈRE (jamais `isNotEmpty`).
      expect(
        result.neverLearned.map((c) => c.id).toList(),
        equals(<String>['a', 'c']),
      );
      expect(result.due, isEmpty, reason: 'b est due dans 3 jours');
    });

    test('🔴 « à réviser » est triée par URGENCE : {J-5, J-1, J-3} → '
        '{J-5, J-3, J-1} (séquence ENTIÈRE)', () {
      final cards = <ZFlashcard>[
        const ZFlashcard(id: 'j5', folderId: 'f', question: 'j5'),
        const ZFlashcard(id: 'j1', folderId: 'f', question: 'j1'),
        const ZFlashcard(id: 'j3', folderId: 'f', question: 'j3'),
      ];
      final srsById = zIndexSrsById(<ZRepetitionInfo>[
        ZRepetitionInfo(
          flashcardId: 'j5',
          folderId: 'f',
          repetitions: 1,
          nextReviewDate: at.subtract(const Duration(days: 5)),
        ),
        ZRepetitionInfo(
          flashcardId: 'j1',
          folderId: 'f',
          repetitions: 1,
          nextReviewDate: at.subtract(const Duration(days: 1)),
        ),
        ZRepetitionInfo(
          flashcardId: 'j3',
          folderId: 'f',
          repetitions: 1,
          nextReviewDate: at.subtract(const Duration(days: 3)),
        ),
      ]);

      final result = zCategorize(cards, srsById: srsById, at: at);

      // 🔴 La plus EN RETARD d'abord — assertion sur la séquence entière.
      expect(
        result.due.map((c) => c.id).toList(),
        equals(<String>['j5', 'j3', 'j1']),
      );
    });

    test('🔴 le tri est STABLE : à échéance ÉGALE, l\'ordre d\'entrée est '
        'préservé (List.sort n\'est PAS stable en Dart)', () {
      final same = at.subtract(const Duration(days: 2));
      final cards = <ZFlashcard>[
        for (var i = 0; i < 12; i++)
          ZFlashcard(id: 'x$i', folderId: 'f', question: 'x$i'),
      ];
      final srsById = zIndexSrsById(<ZRepetitionInfo>[
        for (var i = 0; i < 12; i++)
          ZRepetitionInfo(
            flashcardId: 'x$i',
            folderId: 'f',
            repetitions: 1,
            nextReviewDate: same,
          ),
      ]);

      final result = zCategorize(cards, srsById: srsById, at: at);

      expect(
        result.due.map((c) => c.id).toList(),
        equals(<String>[for (var i = 0; i < 12; i++) 'x$i']),
        reason: '🔴 sans tri décoré par l\'index, l\'ordre serait non '
            'déterministe d\'un run à l\'autre',
      );
    });

    test('l\'échéance PILE à `at` est due (borne incluse)', () {
      final cards = <ZFlashcard>[
        const ZFlashcard(id: 'pile', folderId: 'f', question: 'p'),
      ];
      final srsById = zIndexSrsById(<ZRepetitionInfo>[
        ZRepetitionInfo(
          flashcardId: 'pile',
          folderId: 'f',
          repetitions: 1,
          nextReviewDate: at,
        ),
      ]);

      final result = zCategorize(cards, srsById: srsById, at: at);

      expect(result.due.map((c) => c.id).toList(), equals(<String>['pile']));
    });

    test('une échéance FUTURE d\'une seconde n\'est PAS due', () {
      final cards = <ZFlashcard>[
        const ZFlashcard(id: 'futur', folderId: 'f', question: 'f'),
      ];
      final srsById = zIndexSrsById(<ZRepetitionInfo>[
        ZRepetitionInfo(
          flashcardId: 'futur',
          folderId: 'f',
          repetitions: 1,
          nextReviewDate: at.add(const Duration(seconds: 1)),
        ),
      ]);

      final result = zCategorize(cards, srsById: srsById, at: at);

      expect(result.due, isEmpty);
      expect(result.neverLearned, isEmpty, reason: 'elle a DÉJÀ été apprise');
    });

    test('l\'instant `at` est un PARAMÈTRE : le même corpus rend un résultat '
        'différent selon `at` (AD-14)', () {
      final cards = <ZFlashcard>[
        const ZFlashcard(id: 'a', folderId: 'f', question: 'a'),
      ];
      final srsById = zIndexSrsById(<ZRepetitionInfo>[
        ZRepetitionInfo(
          flashcardId: 'a',
          folderId: 'f',
          repetitions: 1,
          nextReviewDate: DateTime(2026, 3, 29, 12),
        ),
      ]);

      expect(
        zCategorize(cards, srsById: srsById, at: DateTime(2026, 3, 28)).due,
        isEmpty,
        reason: 'la veille : pas encore due',
      );
      expect(
        zCategorize(cards, srsById: srsById, at: DateTime(2026, 3, 30)).due,
        hasLength(1),
        reason: 'le lendemain : due',
      );
    });
  });

  group('AC13 — robustesse : jamais de throw', () {
    test('dossier VIDE ⇒ deux listes vides', () {
      final result = zCategorize(
        const <ZFlashcard>[],
        srsById: const <String, ZRepetitionInfo>{},
        at: at,
      );
      expect(result.neverLearned, isEmpty);
      expect(result.due, isEmpty);
    });

    test('🔴 état SRS ABSENT pour une carte ⇒ « jamais vue » (repli, jamais '
        'de throw)', () {
      final cards = <ZFlashcard>[
        const ZFlashcard(id: 'orphan', folderId: 'f', question: 'o'),
      ];

      final result = zCategorize(
        cards,
        srsById: const <String, ZRepetitionInfo>{},
        at: at,
      );

      expect(result.neverLearned.map((c) => c.id).toList(),
          equals(<String>['orphan']));
      expect(result.due, isEmpty);
    });

    test('carte ÉPHÉMÈRE (id == null) ⇒ jamais vue, jamais de throw', () {
      final result = zCategorize(
        const <ZFlashcard>[ZFlashcard(folderId: 'f', question: 'sans id')],
        srsById: const <String, ZRepetitionInfo>{},
        at: at,
      );
      expect(result.neverLearned, hasLength(1));
    });

    test('carte apprise SANS nextReviewDate ⇒ ni due, ni jamais vue', () {
      final srsById = zIndexSrsById(<ZRepetitionInfo>[
        const ZRepetitionInfo(flashcardId: 'a', folderId: 'f', repetitions: 4),
      ]);

      final result = zCategorize(
        const <ZFlashcard>[ZFlashcard(id: 'a', folderId: 'f', question: 'a')],
        srsById: srsById,
        at: at,
      );

      expect(result.due, isEmpty);
      expect(result.neverLearned, isEmpty);
    });

    test('AUCUNE carte due ⇒ liste due vide (l\'hôte masquera l\'option)', () {
      final srsById = zIndexSrsById(<ZRepetitionInfo>[
        ZRepetitionInfo(
          flashcardId: 'a',
          folderId: 'f',
          repetitions: 1,
          nextReviewDate: at.add(const Duration(days: 10)),
        ),
      ]);

      final result = zCategorize(
        const <ZFlashcard>[ZFlashcard(id: 'a', folderId: 'f', question: 'a')],
        srsById: srsById,
        at: at,
      );

      expect(result.due, isEmpty);
    });

    test('zIndexSrsById : doublon de flashcardId ⇒ le DERNIER gagne, jamais '
        'de throw', () {
      final index = zIndexSrsById(<ZRepetitionInfo>[
        const ZRepetitionInfo(flashcardId: 'dup', folderId: 'f', repetitions: 1),
        const ZRepetitionInfo(flashcardId: 'dup', folderId: 'f', repetitions: 9),
      ]);

      expect(index, hasLength(1));
      expect(index['dup']!.repetitions, equals(9));
    });
  });

  group('🔴 AC8 — l\'O(1) par carte est MESURÉ (sonde de lectures)', () {
    // `k` et `N` sont des LITTÉRAUX DU TEST (jamais lus dans le code de prod).
    const k = 4;

    test('N=200 : les lectures d\'accesseurs restent <= 4N', () {
      const n = 200;
      final counter = _ReadCounter();
      final corpus = _corpus(n, counter, at);

      final srsById = zIndexSrsById(corpus.infos);
      zCategorize(corpus.cards, srsById: srsById, at: at);

      expect(
        counter.reads,
        lessThanOrEqualTo(k * n),
        reason: '🔴 O(n²) rendrait ~N² lectures (≈ ${n * n}) — soit '
            '${n * n ~/ (k * n)}× le budget de ${k * n}',
      );
      // 🔒 La sonde a RÉELLEMENT compté (une sonde débranchée rendrait 0 et
      // passerait le budget triomphalement).
      expect(counter.reads, greaterThan(0),
          reason: '🔴 sonde débranchée : la mesure ne prouverait RIEN');
    });

    test('N=1600 : le budget tient TOUJOURS (la croissance est LINÉAIRE)', () {
      const n = 1600;
      final counter = _ReadCounter();
      final corpus = _corpus(n, counter, at);

      final srsById = zIndexSrsById(corpus.infos);
      zCategorize(corpus.cards, srsById: srsById, at: at);

      expect(
        counter.reads,
        lessThanOrEqualTo(k * n),
        reason: '🔴 un coût quadratique exploserait ici (≈ ${n * n} lectures)',
      );
      expect(counter.reads, greaterThan(0));
    });

    test('🔬 la croissance est LINÉAIRE : 8× les cartes ⇒ ~8× les lectures '
        '(jamais 64×)', () {
      final c200 = _ReadCounter();
      final corpus200 = _corpus(200, c200, at);
      zCategorize(corpus200.cards, srsById: zIndexSrsById(corpus200.infos), at: at);

      final c1600 = _ReadCounter();
      final corpus1600 = _corpus(1600, c1600, at);
      zCategorize(corpus1600.cards,
          srsById: zIndexSrsById(corpus1600.infos), at: at);

      // 8× les cartes ⇒ facteur ~8 (linéaire), jamais ~64 (quadratique).
      final ratio = c1600.reads / c200.reads;
      expect(ratio, lessThan(16),
          reason: '🔴 ratio $ratio : la croissance n\'est PAS linéaire '
              '(${c200.reads} → ${c1600.reads} lectures)');
    });

    test('🔬 CONTRE-PREUVE — l\'implémentation O(n²) ÉCHOUE à la MÊME '
        'assertion (sans quoi la sonde ne prouverait RIEN)', () {
      const n = 200;
      final counter = _ReadCounter();
      final corpus = _corpus(n, counter, at);

      _categorizeQuadratic(corpus.cards, infos: corpus.infos, at: at);

      // 🔴 LE point : la référence quadratique DOIT DÉPASSER le budget que
      // `zCategorize` respecte. Si elle passait, le compteur mesurerait du vent.
      expect(
        counter.reads,
        greaterThan(k * n),
        reason: '🔴 la référence O(n²) tient dans le budget ${k * n} : la sonde '
            'est AVEUGLE et l\'assertion d\'AC8 ne prouve rien',
      );
    });

    test('🔬 CONTRE-PREUVE (suite) : les deux implémentations rendent le MÊME '
        'résultat — seul le COÛT diffère', () {
      // Sans ceci, la référence « O(n²) » pourrait être quadratique parce
      // qu'elle fait n'importe quoi, pas parce qu'elle cherche linéairement.
      const n = 40;
      final counter = _ReadCounter();
      final corpus = _corpus(n, counter, at);

      final fast =
          zCategorize(corpus.cards, srsById: zIndexSrsById(corpus.infos), at: at);
      final slow =
          _categorizeQuadratic(corpus.cards, infos: corpus.infos, at: at);

      expect(
        fast.neverLearned.map((c) => c.id).toList(),
        equals(slow.neverLearned.map((c) => c.id).toList()),
      );
      // (l'ordre de `due` diffère : `zCategorize` trie par urgence, la référence
      // naïve non — on compare donc les ENSEMBLES d'ids.)
      expect(
        fast.due.map((c) => c.id).toSet(),
        equals(slow.due.map((c) => c.id).toSet()),
      );
    });
  });
}
