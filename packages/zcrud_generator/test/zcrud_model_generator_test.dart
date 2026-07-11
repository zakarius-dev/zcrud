// AC3/AC4/AC5/AC6/AC7/AC8 (AD-3/AD-10) : contrat du code émis par E2-5 sur le
// modèle de PREUVE `Article`/`Author`. Le `.g.dart` est produit par build_runner
// RÉEL (`melos run generate`) — ces tests asservissent son comportement.
//
// Pur-Dart (`dart test`) : le fixture importe `edition.dart` (surface pure), pas
// le barrel principal (Flutter via présentation E2-7).
import 'package:test/test.dart';
import 'package:zcrud_core/edition.dart';

import 'models/article.dart';

Article _sample() => Article(
      id: 'a1',
      title: 'Bonjour',
      subtitle: 'sous-titre',
      views: 5,
      rating: 4.5,
      published: true,
      status: ArticleStatus.published,
      createdAt: DateTime(2026, 7, 9, 10, 30),
      tags: const <String>['x', 'y'],
      author: const Author(name: 'Ann', email: 'ann@example.com'),
      coauthors: const <Author>[
        Author(name: 'Bob', email: 'bob@example.com'),
        Author(name: 'Cléo'),
      ],
    );

void main() {
  group('toMap — conventions de persistance (AC4)', () {
    test('clés snake_case, enum camelCase, date ISO-8601, sous-objet récursif',
        () {
      final map = _sample().toMap();
      expect(map['created_at'], '2026-07-09T10:30:00.000'); // clé snake + ISO
      expect(map['status'], 'published'); // enum .name camelCase
      expect(map['tags'], <String>['x', 'y']);
      expect(map['author'], isA<Map<String, dynamic>>());
      expect((map['author'] as Map)['name'], 'Ann');
    });
  });

  group('round-trip idempotent (AC8)', () {
    test('fromMap(toMap(x)) == x', () {
      final x = _sample();
      expect(Article.fromMap(x.toMap()), equals(x));
    });

    test('toMap(fromMap(m)) == m (map canonique)', () {
      final m = _sample().toMap();
      expect(Article.fromMap(m).toMap(), equals(m));
    });
  });

  group('fromMap défensif — AD-10 (AC3)', () {
    test('map vide {} → défauts sûrs, aucun throw', () {
      final a = Article.fromMap(<String, dynamic>{});
      expect(a.title, ''); // non-null sans défaut → valeur sûre
      expect(a.views, 0);
      expect(a.rating, 0.0);
      expect(a.published, isFalse);
      expect(a.status, ArticleStatus.draft); // defaultValue
      expect(a.tags, isEmpty);
      expect(a.author, isNull);
      expect(a.id, isNull);
      expect(a.createdAt, isNull);
    });

    test('enum inconnu → repli defaultValue (jamais byName nu)', () {
      expect(
        Article.fromMap(<String, dynamic>{'status': 'zzz-inconnu'}).status,
        ArticleStatus.draft,
      );
    });

    test('champ manquant → defaultValue du champ', () {
      // `status` absent → defaultValue draft.
      expect(Article.fromMap(<String, dynamic>{'title': 'T'}).status,
          ArticleStatus.draft);
    });

    test('sous-objet corrompu (non-map) → null, parent survit', () {
      final a = Article.fromMap(<String, dynamic>{
        'title': 'T',
        'author': 'pas une map',
      });
      expect(a.author, isNull);
      expect(a.title, 'T');
    });

    test('sous-objet tronqué (champ manquant) → parent + sous-objet survivent',
        () {
      final a = Article.fromMap(<String, dynamic>{
        'title': 'T',
        'author': <String, dynamic>{'email': 'x@y.z'}, // name manquant
      });
      expect(a.author, isNotNull);
      expect(a.author!.name, ''); // défaut sûr du sous-objet
      expect(a.author!.email, 'x@y.z');
    });

    test('sous-objet à clés NON-String → parent survit (H1, AD-10)', () {
      // Map<dynamic,dynamic> à clé `int` (Hive / doc forgé) : l'ancien
      // `Map<String,dynamic>.from(...)` jetait un _TypeError remontant au
      // parent. Le décodage défensif coerce les clés → le parent survit.
      final a = Article.fromMap(<String, dynamic>{
        'title': 'T',
        'author': <dynamic, dynamic>{1: 'x', 'name': 'y'},
      });
      expect(a.title, 'T'); // parent construit malgré la corruption
      expect(a.author, isNotNull); // coercion des clés → sous-objet récupéré
      expect(a.author!.name, 'y');
    });

    test('sous-objet à clés non-String irrécupérable → author null, parent OK',
        () {
      // Map à clé non-String sans champ exploitable : coercion en String puis
      // fromMap défensif → jamais de throw ; parent survit.
      final a = Article.fromMap(<String, dynamic>{
        'title': 'T',
        'author': <dynamic, dynamic>{1: 'x', 2: 'z'},
      });
      expect(a.title, 'T');
      expect(a.author, isNotNull);
      expect(a.author!.name, ''); // aucun `name` → défaut sûr du sous-objet
    });

    test('liste de sous-modèles round-trip (M2, listModel)', () {
      final x = _sample();
      final round = Article.fromMap(x.toMap());
      expect(round.coauthors, hasLength(2));
      expect(round.coauthors[0].name, 'Bob');
      expect(round.coauthors[1].name, 'Cléo');
      expect(round, equals(x));
    });

    test('liste de sous-modèles corrompue → parent survit, valides conservés '
        '(H1/M2, AD-10)', () {
      final a = Article.fromMap(<String, dynamic>{
        'title': 'T',
        'coauthors': <dynamic>[
          <String, dynamic>{'name': 'Ann'}, // valide
          'pas une map', // non-map → filtré
          <dynamic, dynamic>{1: 'x', 'name': 'Zed'}, // clés non-String → coercé
          42, // scalaire → filtré
          null, // null → filtré
        ],
      });
      expect(a.title, 'T'); // parent survit
      expect(a.coauthors.map((c) => c.name), <String>['Ann', 'Zed']);
    });

    test('int tolérant (int|String) — canonique §5', () {
      expect(Article.fromMap(<String, dynamic>{'views': '42'}).views, 42);
      expect(Article.fromMap(<String, dynamic>{'views': 'abc'}).views, 0);
      expect(Article.fromMap(<String, dynamic>{'views': 7}).views, 7);
    });

    test('liste avec éléments corrompus → filtrés (whereType)', () {
      final a = Article.fromMap(<String, dynamic>{
        'tags': <dynamic>['a', 5, 'b', null],
      });
      expect(a.tags, <String>['a', 'b']);
    });
  });

  group('copyWith à sentinelle — reset-null vs préservation (AC5)', () {
    test('copyWith() préserve le champ nullable', () {
      final x = _sample();
      expect(x.copyWith().subtitle, 'sous-titre');
    });

    test('copyWith(subtitle: null) remet le nullable à null', () {
      final x = _sample();
      expect(x.copyWith(subtitle: null).subtitle, isNull);
      // les autres champs restent inchangés
      expect(x.copyWith(subtitle: null).title, 'Bonjour');
    });

    test('copyWith(champ: valeur) modifie ce seul champ', () {
      final x = _sample();
      final y = x.copyWith(title: 'Nouveau');
      expect(y.title, 'Nouveau');
      expect(y.subtitle, 'sous-titre');
      expect(y.views, 5);
    });
  });

  group('ZFieldSpec[] projeté 1:1 + inférence de type (AC6)', () {
    ZFieldSpec byName(String n) =>
        $ArticleFieldSpecs.firstWhere((s) => s.name == n);

    test('projection complète (11 champs)', () {
      expect($ArticleFieldSpecs.map((s) => s.name), <String>[
        'id', 'title', 'subtitle', 'views', 'rating', 'published', 'status',
        'created_at', 'tags', 'author', 'coauthors',
      ]);
    });

    test('id → isId, type text', () {
      expect(byName('id').isId, isTrue);
      expect(byName('id').type, EditionFieldType.text);
    });

    test('inférence de type (int→integer, double→float, bool→boolean, '
        'enum→select, DateTime→dateTime, sous-modèle→subItems)', () {
      expect(byName('views').type, EditionFieldType.integer);
      expect(byName('rating').type, EditionFieldType.float);
      expect(byName('published').type, EditionFieldType.boolean);
      expect(byName('status').type, EditionFieldType.select);
      expect(byName('created_at').type, EditionFieldType.dateTime);
      expect(byName('author').type, EditionFieldType.subItems);
    });

    test('List<String> → multiple=true', () {
      expect(byName('tags').multiple, isTrue);
    });

    test('label + validators + searchable projetés', () {
      expect(byName('title').label, 'Titre');
      expect(byName('title').validators, hasLength(2));
      expect(byName('title').validators.first.kind, ZValidatorKind.required);
      expect(byName('published').searchable, isTrue);
    });

    test('defaultValue projeté (status → draft)', () {
      expect(byName('status').defaultValue, ArticleStatus.draft);
    });
  });

  group('register(ZcrudRegistry) généré (AC7/AC8)', () {
    test('register → encode/decode round-trip via le registre', () {
      final registry = ZcrudRegistry();
      registerArticle(registry);
      registerAuthor(registry);

      final x = _sample();
      expect(registry.encode('article', x), equals(x.toMap()));
      expect(registry.decode('article', x.toMap()), equals(x));
      expect(registry.isRegistered('author'), isTrue);
    });

    test('fieldSpecs enregistré via le slot additif', () {
      final registry = ZcrudRegistry();
      registerArticle(registry);
      expect(registry.fieldSpecsFor('article'), same($ArticleFieldSpecs));
    });

    test('kind inexistant → ZUnregisteredTypeError (AD-3)', () {
      final registry = ZcrudRegistry();
      registerArticle(registry);
      expect(() => registry.codecFor('inconnu'),
          throwsA(isA<ZUnregisteredTypeError>()));
    });
  });

  group('artefact neutre \$XxxTimestampFields — hint B14 (AC3/AC7)', () {
    test('champ persistAs:timestamp → clé persistée collectée (snake_case)', () {
      // `createdAt` est hinté `persistAs: ZPersistAs.timestamp` : sa clé
      // persistée snake_case `created_at` (identique à `toMap`) est collectée.
      expect($ArticleTimestampFields, <String>{'created_at'});
    });

    test('artefact = Set<String> NEUTRE (aucun type backend/core)', () {
      expect($ArticleTimestampFields, isA<Set<String>>());
      // Mêmes clés que toMap (contrat de clé persistée partagé).
      for (final key in $ArticleTimestampFields) {
        expect(_sample().toMap().containsKey(key), isTrue);
      }
    });

    test('modèle sans hint → ensemble VIDE émis (AC7, rétro-compat)', () {
      // `Author` ne déclare aucun `persistAs` ⇒ const <String>{}.
      expect($AuthorTimestampFields, isEmpty);
    });

    test('toMap reste ISO-8601 malgré le hint (conversion Firestore-only)', () {
      // Le hint n'affecte PAS `toMap` : le champ hinté reste String ISO ici ;
      // seul `zcrud_firestore` encode en Timestamp.
      expect(_sample().toMap()['created_at'], '2026-07-09T10:30:00.000');
    });
  });
}
