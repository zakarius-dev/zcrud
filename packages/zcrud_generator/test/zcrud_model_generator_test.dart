// AC3/AC4/AC5/AC6/AC7/AC8 (AD-3/AD-10) : contrat du code émis par E2-5 sur le
// modèle de PREUVE `Article`/`Author`. Le `.g.dart` est produit par build_runner
// RÉEL (`melos run generate`) — ces tests asservissent son comportement.
//
// Pur-Dart (`dart test`) : le fixture importe `edition.dart` (surface pure), pas
// le barrel principal (Flutter via présentation E2-7).
import 'dart:io';

import 'package:test/test.dart';
import 'package:zcrud_core/edition.dart';

import 'models/article.dart';
import 'models/extensible_probe.dart';

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

    // AC1 (DW-ES14-1) : le registrar RÉELLEMENT ÉMIS SUR DISQUE par build_runner
    // câble la factory de DOMAINE — celle qui peuple les canaux hors-codegen
    // (`extra` AD-4, `extension`, `source`) — et NON `_$XxxFromMap` (codegen),
    // qui les détruisait sur la voie `registry.decode`.
    test('registrar généré : `fromMap: Xxx.fromMap` (domaine), PAS `_\$XxxFromMap`',
        () {
      final generated = File('test/models/article.g.dart').readAsStringSync();
      expect(generated, contains('fromMap: Article.fromMap,'));
      expect(generated, contains('fromMap: Author.fromMap,'));
      expect(generated, isNot(contains(r'fromMap: _$ArticleFromMap,')));
      expect(generated, isNot(contains(r'fromMap: _$AuthorFromMap,')));
      // Non-régression : `toMap`/`fieldSpecs` INCHANGÉS.
      expect(generated, contains('toMap: (value) => value.toMap(),'));
      expect(generated, contains(r'fieldSpecs: $ArticleFieldSpecs,'));
      // `_$XxxFromMap` reste ÉMIS (la factory de domaine le consomme, et les
      // sous-modèles en dépendent) : on ne l'a pas supprimé, on ne le CÂBLE plus.
      expect(generated, contains(r'Article _$ArticleFromMap('));
    });
  });

  // =========================================================================
  // 🔴 H1 (code-review ES-2.0) — GARDE EXÉCUTOIRE DW-ES14-1 : le registrar émis
  // pour une classe `ZExtensible` OBSERVE le POUVOIR de sa factory de domaine.
  //
  // Le contrat de BUILD ne juge qu'une FORME (signature + refus de la délégation
  // nue). `ProbeDropper` est précisément la factory impotente qu'il NE PEUT PAS
  // voir (corps ré-écrit à la main, `extra:` omis) : le build la laisse passer —
  // **c'est voulu**, sinon cette fixture prouverait la mauvaise règle (R2).
  // SEUL le garde runtime peut la faire rougir.
  //
  // C'est aussi le SEUL filet qui suive les packages PUBLIÉS : un consommateur
  // externe (DODLP, lex_douane) a le générateur mais PAS `reserved_keys_gate`.
  // =========================================================================
  group('H1 — garde runtime DW-ES14-1 : `extra` préservé, OBSERVÉ (pas présumé)',
      () {
    test('TÉMOIN : `ProbeKeeper` (conforme sur les 2 jambes) → register PASSE',
        () {
      final registry = ZcrudRegistry();
      expect(() => registerProbeKeeper(registry), returnsNormally);

      // …et le pouvoir est RÉEL : la clé hors-schéma survit au round-trip
      // REGISTRE de bout en bout (c'est la garantie centrale d'ES-2.0).
      final decoded = registry.decode(
        'probe_keeper',
        <String, dynamic>{'title': 't', 'zz_cle_inconnue': 'gardee'},
      );
      expect((decoded as ProbeKeeper).extra['zz_cle_inconnue'], 'gardee');
      expect(
        registry.encode('probe_keeper', decoded)['zz_cle_inconnue'],
        'gardee',
      );
    });

    // R2 — une fixture PAR JAMBE : chacune est conforme sur l'AUTRE jambe, donc
    // seule la jambe visée peut la faire rougir.
    test('MORD (jambe ENTRÉE) : `ProbeDropper` — `fromMap` laisse `extra` vide',
        () {
      final registry = ZcrudRegistry();
      expect(
        () => registerProbeDropper(registry),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('DW-ES14-1'),
              contains('ProbeDropper'),
              contains('NE PEUPLE PAS `extra`'),
              contains('DÉCODAGE'),
            ),
          ),
        ),
        reason: 'une factory de domaine qui laisse `extra` vide DOIT être '
            'refusée à l\'enregistrement : sinon `registry.decode` effacerait '
            'silencieusement toute clé métier hors-schéma (DW-ES14-1).',
      );
    });

    test('MORD (jambe SORTIE) : `ProbeEncodeDropper` — `toMap` n\'étale pas `extra`',
        () {
      final registry = ZcrudRegistry();
      expect(
        () => registerProbeEncodeDropper(registry),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('DW-ES14-1'),
              contains('ProbeEncodeDropper'),
              contains('NE LE RÉÉMET PAS'),
              contains('ENCODAGE'),
            ),
          ),
        ),
        reason: 'décoder `extra` correctement ne sert à RIEN si `toMap()` ne le '
            'réémet pas : le cycle lecture → écriture reste destructeur. Le '
            '`toMap()` GÉNÉRÉ n\'étale pas `extra` — une entité `ZExtensible` '
            'qui ne déclare pas le sien tombe exactement dans ce piège.',
      );
    });

    test('le garde n\'est émis QUE pour les classes `ZExtensible`', () {
      final probes = File('test/models/extensible_probe.g.dart').readAsStringSync();
      final article = File('test/models/article.g.dart').readAsStringSync();
      // Les 3 sondes sont `ZExtensible` → l'APPEL du garde est émis.
      expect(probes, contains(r'_$zRequireExtraPreserved<ProbeKeeper>'));
      expect(probes, contains(r'_$zRequireExtraPreserved<ProbeDropper>'));
      expect(probes, contains(r'_$zRequireExtraPreserved<ProbeEncodeDropper>'));
      // `Article`/`Author` n'ont aucun slot `extra` → AUCUN APPEL du garde (il
      // n'aurait rien à observer, et `value.extra` ne compilerait même pas).
      //
      // ⚠️ La DÉCLARATION du helper, elle, vit dans le fragment `_sharedHelpers`
      // et est émise dans toute bibliothèque (dédup. source_gen) : c'est l'APPEL
      // — le câblage réel — qui est conditionné, pas le texte du helper.
      expect(article, isNot(contains(r'_$zRequireExtraPreserved<Article>')));
      expect(article, isNot(contains(r'_$zRequireExtraPreserved<Author>')));
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
