@Tags(<String>['serialization-compat'])
library;

/// CORPUS de rétro-compatibilité de sérialisation (E2-10, AD-10).
///
/// Exécuté par le slot de gate de merge `verify:serialization`
/// (`scripts/ci/verify_serialization.dart` → `dart test --tags
/// serialization-compat`). Complète — sans la dupliquer — l'amorce E2-5
/// (`serialization_compat_test.dart`, round-trip + 1 cas historique).
///
/// Deux voies exercées sur la MÊME source de vérité (`serialization_corpus`) :
/// - **voie codegen directe** (`Article.fromMap`) — AC2 ;
/// - **voie registre codegen** (`ZcrudRegistry.decode('article', …)`) — AC3.
/// Invariant universel des deux voies : le parent SURVIT toujours
/// (`returnsNormally`), + assertions ciblées de repli par famille.
///
/// Décision MEDIUM-1 (E2-6) : la voie ADAPTATEUR (`JsonSerializableAdapter`/
/// `ReflectableCodec`, dont le `fromMap` strict enregistré peut throw) est
/// DÉFÉRÉE à E5 (frontière repository / évolution additive du contrat gelé
/// `ZcrudRegistry` E2-3). Ici seule la voie CODEGEN est couverte — car son
/// `fromMap` généré est intrinsèquement défensif (AD-10 prouvé pour le chemin
/// canonique porté de lex_douane via le builder zcrud).
import 'package:test/test.dart';
import 'package:zcrud_core/edition.dart';

import 'models/article.dart';
import 'models/serialization_corpus.dart';

void main() {
  group('Corpus AD-10 — voie codegen directe (Article.fromMap)', () {
    // AC2 : invariant universel « le parent survit », itéré sur tout le corpus.
    for (final c in serializationCorpus) {
      test('[${c.family}] ${c.name} — le parent survit (returnsNormally)', () {
        expect(
          () => Article.fromMap(asTopLevelMap(c)),
          returnsNormally,
          reason: 'AD-10 : ${c.name} ne doit JAMAIS casser le parent',
        );
      });
    }

    // AC1 — assertions ciblées de repli, une par famille.

    test('(a) historique : champs récents absents → defaultValue', () {
      final a = Article.fromMap(asTopLevelMap(corpusCase(
          'historique_v_n_champ_ajoute_absent')));
      expect(a.id, 'a1');
      expect(a.title, 'Vieux'); // présent → conservé
      expect(a.subtitle, 'sub');
      expect(a.views, 0);
      expect(a.rating, 0.0);
      expect(a.published, isFalse);
      expect(a.status, ArticleStatus.draft);
      expect(a.createdAt, isNull);
      expect(a.tags, isEmpty);
      expect(a.author, isNull);
      expect(a.coauthors, isEmpty);
    });

    test('(b) tronqué : sous-objet author:{} → Author(name:"") (codegen '
        'défensif, PAS null) + coauthors non-Map filtrés', () {
      final a = Article.fromMap(
          asTopLevelMap(corpusCase('tronque_toplevel_et_sous_objet_vide')));
      expect(a.title, 'T');
      // Comportement OBSERVÉ : Author.fromMap est défensif → name:'' (pas null).
      expect(a.author, isNotNull);
      expect(a.author!.name, '');
      // coauthors: [{} → Author(''), 'bad' → null, 7 → null] → 1 conservé.
      expect(a.coauthors, hasLength(1));
      expect(a.coauthors.single.name, '');
    });

    test('(b) tronqué : author partiel {email} → name repli "", email '
        'conservé', () {
      final a = Article.fromMap(
          asTopLevelMap(corpusCase('sous_objet_author_sans_name')));
      expect(a.author, isNotNull);
      expect(a.author!.name, '');
      expect(a.author!.email, 'e@x.com');
    });

    test('(c) champs inconnus ignorés, champs connus décodés', () {
      final a = Article.fromMap(
          asTopLevelMap(corpusCase('futur_v_n1_champ_inconnu_ignore')));
      expect(a.title, 'X');
      expect(a.views, 5); // champ connu décodé normalement
      // Les clés __future_key__ / nested_future sont simplement ignorées.
    });

    test('(d) enums inconnus → repli draft, jamais de throw', () {
      for (final n in const ['enum_legacy_retire', 'enum_futur',
        'enum_non_string']) {
        final a = Article.fromMap(asTopLevelMap(corpusCase(n)));
        expect(a.status, ArticleStatus.draft, reason: n);
      }
    });

    test('(e) types faux : coercitions douces & replis', () {
      expect(Article.fromMap(asTopLevelMap(corpusCase('views_string_non_num')))
          .views, 0);
      expect(Article.fromMap(asTopLevelMap(corpusCase('views_string_num_coerce')))
          .views, 42); // coercition douce String→int
      expect(Article.fromMap(asTopLevelMap(corpusCase('rating_string_num_coerce')))
          .rating, 3.5);
      expect(Article.fromMap(asTopLevelMap(corpusCase('rating_string_non_num')))
          .rating, 0.0);
      expect(Article.fromMap(asTopLevelMap(corpusCase('tags_map_au_lieu_de_list')))
          .tags, isEmpty);
      expect(Article.fromMap(asTopLevelMap(corpusCase('coauthors_map_au_lieu_de_list')))
          .coauthors, isEmpty);
      expect(Article.fromMap(asTopLevelMap(corpusCase('published_non_bool')))
          .published, isFalse);
      expect(Article.fromMap(asTopLevelMap(corpusCase('author_non_map')))
          .author, isNull); // non-Map → _$asStringMap null → author null
      expect(Article.fromMap(asTopLevelMap(corpusCase('tags_liste_mixte')))
          .tags, <String>['a', 'b']); // whereType<String>
    });

    test('(f) clés non-String (régression H1) : coercition sans throw', () {
      // Clés int pures : coercées en '1'/'2', aucune 'name' → Author(name:'').
      final a1 = Article.fromMap(
          asTopLevelMap(corpusCase('author_cles_int_hive')));
      expect(a1.author, isNotNull);
      expect(a1.author!.name, '');
      // Clés mixtes : la clé valide 'name' est préservée malgré la clé int.
      final a2 = Article.fromMap(
          asTopLevelMap(corpusCase('author_cles_mixtes_avec_name')));
      expect(a2.author, isNotNull);
      expect(a2.author!.name, 'Bob');
    });

    test('(g) null partout → tous les champs prennent leur repli', () {
      final a = Article.fromMap(asTopLevelMap(corpusCase('null_partout')));
      expect(a.id, isNull);
      expect(a.title, ''); // requis → repli ''
      expect(a.subtitle, isNull);
      expect(a.views, 0);
      expect(a.rating, 0.0);
      expect(a.published, isFalse);
      expect(a.status, ArticleStatus.draft);
      expect(a.createdAt, isNull);
      expect(a.period, isNull);
      expect(a.tags, isEmpty);
      expect(a.author, isNull);
      expect(a.coauthors, isEmpty);
      expect(a.pinValue, isNull);
      expect(a.autoValue, isNull);
    });

    test('(i) fp-5-1 : pin/autocomplete neutres String — défensif AD-10 + '
        'round-trip (aucune nouvelle catégorie génératrice)', () {
      // Valeur non-`String` → repli `null` (catégorie `_Cat.stringType`), le
      // PARENT SURVIT (title conservé) — vrai test AD-10, pas returnsNormally.
      final pinKo = Article.fromMap(asTopLevelMap(corpusCase(
          'fp51_pin_non_string')));
      expect(pinKo.pinValue, isNull);
      expect(pinKo.title, 'ok', reason: 'AD-10 : le parent survit');

      final autoKo = Article.fromMap(asTopLevelMap(corpusCase(
          'fp51_auto_non_string_map')));
      expect(autoKo.autoValue, isNull);
      expect(autoKo.title, 'ok');

      // Champs absents → `null` (nullable), parent intact.
      final absent = Article.fromMap(asTopLevelMap(corpusCase(
          'fp51_pin_auto_absents')));
      expect(absent.pinValue, isNull);
      expect(absent.autoValue, isNull);
      expect(absent.title, 'ok');

      // Valeurs valides → décodées + round-trip idempotent (toMap → fromMap).
      final ok = Article.fromMap(asTopLevelMap(corpusCase(
          'fp51_pin_auto_valides')));
      expect(ok.pinValue, '1234');
      expect(ok.autoValue, 'foo');
      final round = Article.fromMap(ok.toMap());
      expect(round.pinValue, '1234');
      expect(round.autoValue, 'foo');
    });

    test('(h) ZDateRange corrompu (AD-47/AD-10) : period → null, parent survit', () {
      // Chaque forme de corruption (non-map, end absent, non-String, non-ISO,
      // start>end) retombe sur `null` SANS casser le parent (title conservé).
      for (final n in const <String>[
        'period_non_map',
        'period_end_absent',
        'period_non_string',
        'period_non_iso',
        'period_start_apres_end',
      ]) {
        final a = Article.fromMap(asTopLevelMap(corpusCase(n)));
        expect(a.period, isNull, reason: n);
        expect(a.title, 'T', reason: '$n : le parent survit');
      }
    });

    test('(h) ZDateRange valide : décodé + round-trip idempotent', () {
      final a =
          Article.fromMap(asTopLevelMap(corpusCase('period_valide_roundtrip')));
      expect(a.period, isNotNull);
      expect(a.period!.start, DateTime.parse('2026-01-01T00:00:00.000'));
      expect(a.period!.end, DateTime.parse('2026-01-31T00:00:00.000'));
      // toMap → fromMap idempotent sur le champ period.
      expect(Article.fromMap(a.toMap()).period, a.period);
    });

    test('sous-modèle Author.fromMap seul : défensif, name manquant → "" '
        '(comportement observé, non modifié)', () {
      expect(() => Author.fromMap(<String, dynamic>{}), returnsNormally);
      expect(Author.fromMap(<String, dynamic>{}).name, '');
      expect(Author.fromMap(<String, dynamic>{'name': 42}).name, '');
    });
  });

  group('Corpus AD-10 — voie registre codegen (ZcrudRegistry.decode)', () {
    // AC3 : la frontière registre est défensive POUR LES MODÈLES GÉNÉRÉS.
    late ZcrudRegistry registry;
    setUp(() {
      registry = ZcrudRegistry();
      registerArticle(registry);
    });

    for (final c in serializationCorpus) {
      test('[${c.family}] ${c.name} — decode() ne lève jamais', () {
        expect(
          () => registry.decode('article', asTopLevelMap(c)),
          returnsNormally,
          reason: 'AD-10 frontière registre codegen : ${c.name}',
        );
      });
    }

    test('decode renvoie bien un Article décodé défensivement', () {
      final decoded = registry.decode(
          'article', asTopLevelMap(corpusCase('null_partout')));
      expect(decoded, isA<Article>());
      expect((decoded as Article).title, '');
      expect(decoded.status, ArticleStatus.draft);
    });
  });
}
