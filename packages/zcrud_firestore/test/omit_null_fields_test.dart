// CR DODLP « omit-null-fields » : hint `omitNullFields` de
// `FirebaseZRepositoryImpl` (symétrique de `timestampFields`).
//
// Contexte : en écriture fusionnée Firestore (`merge: true`), une clé absente
// laisse la valeur distante intacte, une clé présente à `null` l'EFFACE. Les
// moteurs legacy compactent (`compact(true)` récursif) ; `registry.encode`
// rend la map nulls compris. Le hint retire les clés nulles du CORPS de
// l'entité avant écriture.
//
// Prouve : (a) défaut `false` = contrat inchangé, les nulls sont écrits ;
// (b) `true` → clés nulles absentes du corps écrit, RÉCURSIVEMENT (sous-maps,
// maps dans des listes) ; (c) méta de sync (`is_deleted`, `updated_at`)
// JAMAIS retirée — y compris un `updated_at` verbatim null sur la voie
// writeMerged ; (d) round-trip de lecture intact.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_firestore/zcrud_firestore.dart';

// ───────────────────────── Modèle de test ─────────────────────────────────

/// Entité minimale à champs nullables et valeurs composées (sous-map, liste de
/// maps) — cible du retrait récursif des clés nulles.
class _Profile extends ZEntity {
  const _Profile({
    this.id,
    required this.name,
    this.nickname,
    this.address,
    this.contacts,
  });

  @override
  final String? id;
  final String name;
  final String? nickname;
  final Map<String, dynamic>? address;
  final List<Map<String, dynamic>>? contacts;

  static _Profile fromMap(Map<String, dynamic> map) => _Profile(
        id: map['id'] as String?,
        name: (map['name'] as String?) ?? '',
        nickname: map['nickname'] as String?,
        address: (map['address'] as Map?)?.cast<String, dynamic>(),
        contacts: (map['contacts'] as List?)
            ?.map((e) => (e as Map).cast<String, dynamic>())
            .toList(),
      );

  Map<String, dynamic> toMap() => <String, dynamic>{
        if (id != null) 'id': id,
        'name': name,
        'nickname': nickname,
        'address': address,
        'contacts': contacts,
      };
}

const String _kPath = 'profiles';

FirebaseZRepositoryImpl<_Profile> _repo(
  FakeFirebaseFirestore fs, {
  bool omitNullFields = false,
}) =>
    FirebaseZRepositoryImpl<_Profile>(
      firestore: fs,
      collectionPath: _kPath,
      kind: 'profile',
      fromMap: _Profile.fromMap,
      toMap: (p) => p.toMap(),
      omitNullFields: omitNullFields,
    );

Future<Map<String, dynamic>> _rawDoc(FakeFirebaseFirestore fs, String id) async {
  final snap = await fs.collection(_kPath).doc(id).get();
  expect(snap.exists, isTrue, reason: 'document $id attendu sur disque');
  return snap.data() ?? <String, dynamic>{};
}

void main() {
  group('omitNullFields — défaut false : contrat inchangé (nulls émis)', () {
    test('save écrit les clés nulles telles quelles sur disque', () async {
      final fs = FakeFirebaseFirestore();
      final repo = _repo(fs); // défaut : omitNullFields absent ⇒ false

      final res = await repo.save(const _Profile(id: 'p1', name: 'Ada'));
      expect(res.isRight(), isTrue);

      final raw = await _rawDoc(fs, 'p1');
      // Les clés nulles sont PRÉSENTES (clé à null ≠ clé absente : en
      // `merge: true` ailleurs dans le parc, la première EFFACE).
      expect(raw.containsKey('nickname'), isTrue);
      expect(raw['nickname'], isNull);
      expect(raw.containsKey('address'), isTrue);
      expect(raw['address'], isNull);
    });
  });

  group('omitNullFields: true — les clés nulles sont retirées du corps', () {
    test('save : clé nulle de premier niveau ABSENTE du document écrit',
        () async {
      final fs = FakeFirebaseFirestore();
      final repo = _repo(fs, omitNullFields: true);

      final res = await repo.save(const _Profile(id: 'p1', name: 'Ada'));
      expect(res.isRight(), isTrue);

      final raw = await _rawDoc(fs, 'p1');
      expect(raw.containsKey('nickname'), isFalse,
          reason: 'clé nulle retirée avant écriture (compact legacy)');
      expect(raw.containsKey('address'), isFalse);
      expect(raw.containsKey('contacts'), isFalse);
      expect(raw['name'], 'Ada');
      expect(raw['id'], 'p1'); // le corps porte toujours son id logique
    });

    test('retrait RÉCURSIF : sous-map compactée, maps de liste compactées, '
        'éléments de liste nuls CONSERVÉS', () async {
      final fs = FakeFirebaseFirestore();
      final repo = _repo(fs, omitNullFields: true);

      await repo.save(const _Profile(
        id: 'p2',
        name: 'Grace',
        address: <String, dynamic>{
          'city': 'Lomé',
          'zip': null, // ← entrée nulle de sous-map : retirée
          'geo': <String, dynamic>{'lat': 6.1, 'lng': null}, // ← 2e niveau
        },
        contacts: <Map<String, dynamic>>[
          <String, dynamic>{'kind': 'tel', 'value': null}, // ← map DANS liste
        ],
      ));

      final raw = await _rawDoc(fs, 'p2');
      final address = (raw['address'] as Map).cast<String, dynamic>();
      expect(address.containsKey('zip'), isFalse);
      expect(address['city'], 'Lomé');
      final geo = (address['geo'] as Map).cast<String, dynamic>();
      expect(geo.containsKey('lng'), isFalse);
      expect(geo['lat'], 6.1);
      final contact =
          ((raw['contacts'] as List).single as Map).cast<String, dynamic>();
      expect(contact.containsKey('value'), isFalse);
      expect(contact['kind'], 'tel');
    });

    test('méta de sync JAMAIS retirée : is_deleted/updated_at présents après '
        'save', () async {
      final fs = FakeFirebaseFirestore();
      final repo = _repo(fs, omitNullFields: true);

      await repo.save(const _Profile(id: 'p3', name: 'Alan'));
      final raw = await _rawDoc(fs, 'p3');
      expect(raw['is_deleted'], isFalse);
      expect(raw['updated_at'], isA<String>()); // ISO-8601, hors périmètre
    });

    test('writeMerged : corps compacté, méta verbatim préservée — un '
        'updated_at null DÉLIBÉRÉ reste écrit (jamais compacté)', () async {
      final fs = FakeFirebaseFirestore();
      final repo = _repo(fs, omitNullFields: true);

      final res = await repo.writeMerged(ZSyncEntry<_Profile>(
        entity: const _Profile(id: 'p4', name: 'Edsger'),
        meta: const ZSyncMeta(updatedAt: null, isDeleted: true),
      ));
      expect(res.isRight(), isTrue);

      final raw = await _rawDoc(fs, 'p4');
      // Corps compacté…
      expect(raw.containsKey('nickname'), isFalse);
      // …mais la méta est écrite VERBATIM, y compris le null délibéré :
      // la retirer casserait le contrat « méta préservée » du merge LWW.
      expect(raw.containsKey('updated_at'), isTrue);
      expect(raw['updated_at'], isNull);
      expect(raw['is_deleted'], isTrue); // tombstone verbatim
    });

    test('round-trip : getById restitue l\'entité (clés absentes relues null)',
        () async {
      final fs = FakeFirebaseFirestore();
      final repo = _repo(fs, omitNullFields: true);

      await repo.save(const _Profile(id: 'p5', name: 'Barbara'));
      final got = await repo.getById('p5');
      got.fold((f) => fail('gauche: $f'), (p) {
        expect(p.name, 'Barbara');
        expect(p.nickname, isNull);
        expect(p.address, isNull);
      });
    });
  });
}
