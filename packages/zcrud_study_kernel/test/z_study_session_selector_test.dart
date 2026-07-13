/// Tests de garde du noyau (ES-1.1, AC6) : `ZStudySessionSelector` opère sur le
/// port neutre `ZSessionCandidate` — **sans** dépendre de `zcrud_flashcard`.
///
/// Un candidat factice local au noyau prouve la réutilisabilité neutre : filtres
/// ET (dossier ∧ tags ∧ types opaques), plafond `count` (`null`/`0`/`<len`),
/// préservation de l'ordre et du type concret d'entrée.
library;

import 'package:test/test.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

/// Candidat de test PUR (aucune dépendance flashcard) — prouve la neutralité.
class _FakeCandidate implements ZSessionCandidate {
  const _FakeCandidate(
    this.label, {
    this.folderId,
    this.subFolderId,
    this.tagIds = const <String>[],
    this.typeKey = 'openQuestion',
  });

  final String label;

  @override
  final String? folderId;

  @override
  final String? subFolderId;

  @override
  final List<String> tagIds;

  @override
  final String typeKey;
}

List<String> _labels(List<_FakeCandidate> cs) =>
    cs.map((c) => c.label).toList();

void main() {
  group('Filtre dossier (AC6)', () {
    const cards = <_FakeCandidate>[
      _FakeCandidate('a', folderId: 'f1'),
      _FakeCandidate('b', folderId: 'f2'),
      _FakeCandidate('c', subFolderId: 'f1'),
      _FakeCandidate('d', folderId: 'other', subFolderId: 'x'),
    ];

    test('folderId null ⇒ pas de filtre', () {
      const sel = ZStudySessionSelector(ZStudySessionConfig());
      expect(_labels(sel.selectFrom(cards)), <String>['a', 'b', 'c', 'd']);
    });

    test('folderId cible couvre le dossier ET ses sous-dossiers', () {
      const sel = ZStudySessionSelector(ZStudySessionConfig(folderId: 'f1'));
      expect(_labels(sel.selectFrom(cards)), <String>['a', 'c']);
    });
  });

  group('Filtre tags (AC6)', () {
    const cards = <_FakeCandidate>[
      _FakeCandidate('a', tagIds: <String>['x', 'y']),
      _FakeCandidate('b', tagIds: <String>['z']),
      _FakeCandidate('c', tagIds: <String>['y']),
      _FakeCandidate('d'),
    ];

    test('intersection non vide', () {
      const sel = ZStudySessionSelector(
        ZStudySessionConfig(tagIds: <String>['y', 'q']),
      );
      expect(_labels(sel.selectFrom(cards)), <String>['a', 'c']);
    });
  });

  group('Filtre types (clés opaques — AC6)', () {
    const cards = <_FakeCandidate>[
      _FakeCandidate('a', typeKey: 'multipleChoice'),
      _FakeCandidate('b', typeKey: 'trueOrFalse'),
      _FakeCandidate('c', typeKey: 'openQuestion'),
    ];

    test('appartenance sur typeKey', () {
      const sel = ZStudySessionSelector(
        ZStudySessionConfig(
          types: <String>['multipleChoice', 'openQuestion'],
        ),
      );
      expect(_labels(sel.selectFrom(cards)), <String>['a', 'c']);
    });

    test('types vide ⇒ pas de filtre', () {
      const sel = ZStudySessionSelector(
        ZStudySessionConfig(types: <String>[]),
      );
      expect(_labels(sel.selectFrom(cards)), <String>['a', 'b', 'c']);
    });
  });

  group('Composition ET (AC6)', () {
    test('dossier ∧ tags ∧ types en ET', () {
      const cards = <_FakeCandidate>[
        _FakeCandidate('ok',
            folderId: 'f1', tagIds: <String>['x'], typeKey: 'multipleChoice'),
        _FakeCandidate('bad_folder',
            folderId: 'f2', tagIds: <String>['x'], typeKey: 'multipleChoice'),
        _FakeCandidate('bad_tag',
            folderId: 'f1', tagIds: <String>['z'], typeKey: 'multipleChoice'),
        _FakeCandidate('bad_type',
            folderId: 'f1', tagIds: <String>['x'], typeKey: 'trueOrFalse'),
      ];
      const sel = ZStudySessionSelector(
        ZStudySessionConfig(
          folderId: 'f1',
          tagIds: <String>['x'],
          types: <String>['multipleChoice'],
        ),
      );
      expect(_labels(sel.selectFrom(cards)), <String>['ok']);
    });
  });

  group('Plafond count + ordre (AC6)', () {
    const cards = <_FakeCandidate>[
      _FakeCandidate('a'),
      _FakeCandidate('b'),
      _FakeCandidate('c'),
      _FakeCandidate('d'),
    ];

    test('count null ⇒ illimité, ordre préservé', () {
      const sel = ZStudySessionSelector(ZStudySessionConfig());
      expect(_labels(sel.selectFrom(cards)), <String>['a', 'b', 'c', 'd']);
    });

    test('count tronque en préservant l\'ordre', () {
      const sel = ZStudySessionSelector(ZStudySessionConfig(count: 2));
      expect(_labels(sel.selectFrom(cards)), <String>['a', 'b']);
    });

    test('count <= 0 ⇒ vide', () {
      expect(
        const ZStudySessionSelector(ZStudySessionConfig(count: 0))
            .selectFrom(cards),
        isEmpty,
      );
    });

    test('selectFrom préserve le type concret d\'entrée', () {
      const sel = ZStudySessionSelector(ZStudySessionConfig());
      final out = sel.selectFrom(cards);
      expect(out, isA<List<_FakeCandidate>>());
    });

    test('matches n\'applique pas le plafond count', () {
      const sel = ZStudySessionSelector(ZStudySessionConfig(count: 0));
      expect(sel.matches(const _FakeCandidate('a')), isTrue);
    });
  });
}
