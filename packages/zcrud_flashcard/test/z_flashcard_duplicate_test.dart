// Tests de `zDuplicateFlashcardForEditing` (SU-8/AC13, FR-SU21, AD-45, D6).
//
// 🔴 Discipline « un défaut est un MOTIF » : le tableau D6 est parcouru **champ
// par champ, EN ENTIER** — jamais un échantillon. Un champ oublié à la
// duplication est une **perte muette de contenu** (la copie s'ouvre, l'utilisateur
// ne voit pas que son explication a disparu).
//
// 🔴 « À PROUVER, pas à supposer » : les deux dernières lignes du tableau (SRS et
// ordre non copiés) ne sont pas assérées par une affirmation de dartdoc mais par
// une **tentative réelle de jointure**.
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/domain.dart' show ZExtension;
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

/// Extension de test — slot AD-4 typé (prouve que `extension` est bien copié).
class _TestExtension extends ZExtension {
  const _TestExtension(this.note);

  final String note;

  @override
  int get formatVersion => 1;

  @override
  Map<String, dynamic> toJson() =>
      <String, dynamic>{'format_version': formatVersion, 'note': note};
}

/// Carte ORIGINALE : **tous** les champs peuplés, aucun laissé au défaut — sans
/// quoi un champ « copié » par accident (parce qu'il vaut son défaut des deux
/// côtés) passerait pour vérifié.
ZFlashcard _fullOriginal() => ZFlashcard(
      id: 'original-id',
      folderId: 'folder-1',
      subFolderId: 'sub-1',
      type: ZFlashcardType.multipleChoice,
      question: 'Question originale ?',
      answer: 'Réponse libre',
      isTrue: true,
      choices: const <ZChoice>[
        ZChoice(content: 'Choix A', isCorrect: true),
        ZChoice(content: 'Choix B'),
      ],
      explanation: 'Explication pédagogique',
      hint: 'Un indice',
      tagIds: const <String>['tag-1', 'tag-2'],
      isReadOnly: true, // carte PARTAGÉE : le cas d'usage même de FR-SU21
      createdAt: DateTime.utc(2020, 1, 1),
      updatedAt: DateTime.utc(2021, 6, 15),
      source: ZCustomSource('article', const <String, dynamic>{'ref': 'a-1'}),
      extension: const _TestExtension('slot typé'),
      extra: const <String, dynamic>{'custom': 'valeur inconnue du cœur'},
    );

void main() {
  group('🔴 AC13/D6 — CE QUI EST COPIÉ (le contenu, champ par champ)', () {
    test('question / answer / isTrue / explanation / hint / type', () {
      final original = _fullOriginal();
      final copy = zDuplicateFlashcardForEditing(original);

      expect(copy.question, 'Question originale ?');
      expect(copy.answer, 'Réponse libre');
      expect(copy.isTrue, isTrue);
      expect(copy.explanation, 'Explication pédagogique',
          reason: 'perdre l\'explication = perte MUETTE de contenu pédagogique');
      expect(copy.hint, 'Un indice');
      expect(copy.type, ZFlashcardType.multipleChoice);
    });

    test('choices : contenu ET marqueur isCorrect (la paire reste soudée)', () {
      final copy = zDuplicateFlashcardForEditing(_fullOriginal());

      expect(copy.choices, isNotNull);
      expect(copy.choices!.length, 2);
      expect(copy.choices![0].content, 'Choix A');
      expect(copy.choices![0].isCorrect, isTrue,
          reason: '🔴 copier les libellés en perdant `isCorrect` rendrait le '
              'QCM INSOLUBLE — et un test qui n\'assère que `content` resterait '
              'VERT (défaut su-2)');
      expect(copy.choices![1].content, 'Choix B');
      expect(copy.choices![1].isCorrect, isFalse);
    });

    test('choices : copie DÉFENSIVE de la liste (pas l\'instance partagée)', () {
      final original = _fullOriginal();
      final copy = zDuplicateFlashcardForEditing(original);
      expect(identical(copy.choices, original.choices), isFalse,
          reason: 'partager l\'instance de LISTE ferait qu\'une mutation côté '
              'copie toucherait l\'original');
    });

    test('tagIds : copiés (classement du CONTENU, pas un état perso)', () {
      final original = _fullOriginal();
      final copy = zDuplicateFlashcardForEditing(original);
      expect(copy.tagIds, <String>['tag-1', 'tag-2']);
      expect(identical(copy.tagIds, original.tagIds), isFalse,
          reason: 'copie défensive de la liste');
    });

    test('folderId / subFolderId : la copie naît LÀ OÙ on l\'a dupliquée', () {
      final copy = zDuplicateFlashcardForEditing(_fullOriginal());
      expect(copy.folderId, 'folder-1');
      expect(copy.subFolderId, 'sub-1');
    });

    test('source : provenance FACTUELLE du contenu copié (AD-45 ne la bannit pas)', () {
      final copy = zDuplicateFlashcardForEditing(_fullOriginal());
      expect(copy.source?.kind, 'article',
          reason: 'AD-45 ne bannit que SRS + ordre ; l\'origine du CONTENU reste '
              'vraie après copie');
    });

    test('extension / extra : slots AD-4 préservés (jamais de perte muette)', () {
      final copy = zDuplicateFlashcardForEditing(_fullOriginal());
      expect(copy.extension, isA<_TestExtension>());
      expect((copy.extension! as _TestExtension).note, 'slot typé');
      expect(copy.extra['custom'], 'valeur inconnue du cœur',
          reason: 'perdre `extra` effacerait des données que le cœur ne '
              'comprend pas mais qu\'une app consommatrice exploite');
    });

    test('🔴 D6 — `extra` est copié EN PROFONDEUR (aucun aliasing imbriqué)', () {
      // Fixture NON scalaire : `extra` porte une LISTE et une MAP imbriquées —
      // le seul cas où une copie de surface (`Map.of`) fuit. Un fixture scalaire
      // passerait trivialement et NE POURRAIT PAS attraper l'aliasing.
      final original = ZFlashcard(
        id: 'x1',
        question: 'q',
        type: ZFlashcardType.openQuestion,
        isReadOnly: true, // carte PARTAGÉE : le cas d'usage d'AD-45
        extra: <String, dynamic>{
          'nested': <String>['a', 'b'],
          'meta': <String, dynamic>{'count': 1},
        },
      );
      final copy = zDuplicateFlashcardForEditing(original);

      // 🔴 Les sous-structures ne sont PAS la même instance.
      expect(identical(copy.extra['nested'], original.extra['nested']), isFalse,
          reason: '🔴 une LISTE imbriquée partagée ferait qu\'éditer la copie '
              'muterait la carte partagée en lecture seule (AD-45)');
      expect(identical(copy.extra['meta'], original.extra['meta']), isFalse,
          reason: '🔴 idem pour une MAP imbriquée');

      // 🔴 Éditer la copie NE TOUCHE PAS l'original (le geste qu'un appelant
      // ferait : la copie est éditable, il la modifie).
      (copy.extra['nested'] as List).add('MUTATED');
      (copy.extra['meta'] as Map)['count'] = 99;
      expect(original.extra['nested'], <String>['a', 'b'],
          reason: '🔴 la carte partagée garde sa liste intacte');
      expect((original.extra['meta'] as Map)['count'], 1,
          reason: '🔴 la carte partagée garde sa map intacte');
    });
  });

  group('🔴 AC13/D6 — CE QUI N\'EST JAMAIS COPIÉ', () {
    test('id → null (ÉPHÉMÈRE : la copie ne peut PAS écraser l\'original)', () {
      final copy = zDuplicateFlashcardForEditing(_fullOriginal());
      expect(copy.id, isNull,
          reason: '🔴 un id copié ferait que le commit ÉCRASERAIT la carte '
              'partagée d\'origine — défaut silencieux et destructeur');
    });

    test('isReadOnly → false (sinon la fonction serait MORTE)', () {
      final original = _fullOriginal();
      expect(original.isReadOnly, isTrue, reason: 'sanity : original partagé');

      final copy = zDuplicateFlashcardForEditing(original);
      expect(copy.isReadOnly, isFalse,
          reason: '🔴 AD-45 « remis à faux » : une copie encore en lecture '
              'seule rendrait « dupliquer POUR MODIFIER » morte sur son chemin '
              'documenté — et aucun test de contenu ne le verrait');
    });

    test('createdAt / updatedAt → null (les copier MENTIRAIT sur la provenance)', () {
      final copy = zDuplicateFlashcardForEditing(_fullOriginal());
      expect(copy.createdAt, isNull,
          reason: 'la copie n\'a PAS été créée en 2020 — le commit assignera');
      expect(copy.updatedAt, isNull);
    });
  });

  group('🔴 AC13 — L\'ORIGINAL N\'EST JAMAIS MUTÉ (AD-45)', () {
    test('tous les champs de l\'original sont intacts après duplication', () {
      final original = _fullOriginal();
      final before = _fullOriginal(); // instance de référence indépendante

      zDuplicateFlashcardForEditing(original);

      expect(original.id, before.id);
      expect(original.isReadOnly, before.isReadOnly,
          reason: '🔴 si la duplication « remettait à faux » l\'ORIGINAL, la '
              'carte partagée deviendrait éditable — fuite d\'AD-45');
      expect(original.createdAt, before.createdAt);
      expect(original.updatedAt, before.updatedAt);
      expect(original.question, before.question);
      expect(original.tagIds, before.tagIds);
      expect(original.choices!.length, before.choices!.length);
      expect(original.extra['custom'], before.extra['custom']);
    });

    test('muter la liste de la COPIE ne touche pas l\'original', () {
      final original = _fullOriginal();
      final copy = zDuplicateFlashcardForEditing(original);

      // La copie est éditable : simulons une édition réelle de ses tags.
      final copyTags = List<String>.of(copy.tagIds)..add('tag-3');
      expect(copyTags.length, 3);
      expect(original.tagIds.length, 2,
          reason: 'l\'original garde ses 2 tags');
    });
  });

  group('🔴 AC13/D6 — SRS et ORDRE non copiés : PROUVÉ, pas supposé', () {
    test('🔴 le SRS de l\'original n\'est PAS joignable à la copie', () {
      final original = _fullOriginal();
      final copy = zDuplicateFlashcardForEditing(original);

      // L'état SRS est une entité SÉPARÉE, indexée par `flashcardId`.
      final srsById = <String, ZRepetitionInfo>{
        'original-id': const ZRepetitionInfo(
          flashcardId: 'original-id',
          folderId: 'folder-1',
          repetitions: 12,
          interval: 30,
          easeFactor: 2.5,
          lastQuality: 5,
        ),
      };

      // L'original EST joignable — sinon le test ne prouverait rien (sonde).
      expect(srsById[original.id], isNotNull,
          reason: 'sonde : l\'original DOIT être joignable, sans quoi '
              '« la copie ne l\'est pas » serait vrai trivialement');
      expect(srsById[original.id]!.repetitions, 12);

      // 🔴 La copie ne l'est PAS : `id == null` ⇒ aucune clé de jointure.
      final copyId = copy.id;
      expect(copyId, isNull);
      // La tentative RÉELLE de jointure (le geste qu'un appelant ferait) :
      final joined = copyId == null ? null : srsById[copyId];
      expect(joined, isNull,
          reason: '🔴 AD-45 : la copie hérite d\'un historique de révision '
              'qu\'elle n\'a JAMAIS vécu ⇒ elle serait « maîtrisée » à la '
              'naissance et ne serait jamais révisée');
    });

    test('🔴 l\'ORDRE persisté ne contient PAS la copie', () {
      final original = _fullOriginal();
      final copy = zDuplicateFlashcardForEditing(original);

      // L'ordre est une entité SÉPARÉE indexant des IDS.
      final order = ZFolderContentsOrder(
        folderId: 'folder-1',
        sectionOrders: <String, List<String>>{
          zSectionKey(contentType: 'flashcards'): <String>['original-id'],
        },
      );

      final ids = order.orderFor(zSectionKey(contentType: 'flashcards'));
      expect(ids, contains('original-id'),
          reason: 'sonde : l\'original EST dans l\'ordre persisté');
      expect(ids, hasLength(1));
      expect(ids.contains(copy.id), isFalse,
          reason: '🔴 AD-45 : la copie n\'hérite d\'AUCUNE position — `id: null` '
              'la rend inatteignable par un ordre qui indexe des ids');
    });

    test('l\'ordre APPLIQUÉ place la copie en fin (nouvelle ⇒ appendée)', () {
      // Comportement réel et utile : la copie n'est pas « perdue », elle est
      // simplement NON ordonnée ⇒ `ZUnorderedPlacement.end` (AC12).
      final original = _fullOriginal();
      final copy = zDuplicateFlashcardForEditing(original);

      final ordered = applyOrder<ZFlashcard>(
        <ZFlashcard>[copy, original],
        <String>['original-id'],
        idOf: (c) => c.id ?? '',
      );

      expect(ordered.first.id, 'original-id',
          reason: 'l\'original garde sa position personnelle');
      expect(ordered.last.id, isNull,
          reason: 'la copie, non ordonnée, est APPENDÉE — jamais perdue, '
              'jamais insérée à la place de l\'original');
    });
  });

  group('AC13/AD-10 — robustesse : jamais de throw', () {
    test('carte MINIMALE (tous les optionnels null/défaut)', () {
      const minimal = ZFlashcard(question: 'Q');
      final copy = zDuplicateFlashcardForEditing(minimal);

      expect(copy.question, 'Q');
      expect(copy.id, isNull);
      expect(copy.answer, isNull);
      expect(copy.choices, isNull,
          reason: 'null reste null — inventer une liste vide changerait le '
              'type effectif de la carte');
      expect(copy.tagIds, isEmpty);
      expect(copy.isReadOnly, isFalse);
      expect(copy.extra, isEmpty);
    });

    test('carte DÉJÀ éphémère (id déjà null) ⇒ copie éphémère, aucun throw', () {
      const ephemeral = ZFlashcard(question: 'Q', id: null);
      final copy = zDuplicateFlashcardForEditing(ephemeral);
      expect(copy.id, isNull);
      expect(copy.question, 'Q');
    });

    test('dupliquer une DUPLICATION (idempotence de forme)', () {
      final once = zDuplicateFlashcardForEditing(_fullOriginal());
      final twice = zDuplicateFlashcardForEditing(once);

      expect(twice.id, isNull);
      expect(twice.isReadOnly, isFalse);
      expect(twice.createdAt, isNull);
      expect(twice.question, once.question);
      expect(twice.extra['custom'], 'valeur inconnue du cœur');
    });
  });
}
